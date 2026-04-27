#include "wizardry_core.h"

#include <ctype.h>
#include <dirent.h>
#include <errno.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>

enum {
  JSONRPC_OK = 0,
  JSONRPC_PARSE_ERROR = -32700,
  JSONRPC_INVALID_REQUEST = -32600,
  JSONRPC_METHOD_NOT_FOUND = -32601,
  JSONRPC_INVALID_PARAMS = -32602,
  JSONRPC_INTERNAL_ERROR = -32603
};

typedef struct strbuf {
  char *data;
  size_t len;
  size_t cap;
} strbuf;

typedef struct sidecar_entry {
  char key[256];
  char value[2048];
} sidecar_entry;

static int safe_copy(char *dst, size_t dst_size, const char *src) {
  size_t src_len;

  if (!dst || !src || dst_size == 0) {
    return -1;
  }

  src_len = strlen(src);
  if (src_len >= dst_size) {
    return -1;
  }

  memcpy(dst, src, src_len + 1);
  return 0;
}

static const char *skip_ws(const char *p) {
  while (p && *p && isspace((unsigned char)*p)) {
    p++;
  }
  return p;
}

static int sb_init(strbuf *sb, size_t initial_cap) {
  if (!sb || initial_cap == 0) {
    return -1;
  }

  sb->data = (char *)malloc(initial_cap);
  if (!sb->data) {
    return -1;
  }

  sb->data[0] = '\0';
  sb->len = 0;
  sb->cap = initial_cap;
  return 0;
}

static void sb_free(strbuf *sb) {
  if (!sb) {
    return;
  }

  free(sb->data);
  sb->data = NULL;
  sb->len = 0;
  sb->cap = 0;
}

static int sb_reserve(strbuf *sb, size_t extra) {
  size_t needed;
  size_t new_cap;
  char *new_data;

  if (!sb || !sb->data) {
    return -1;
  }

  needed = sb->len + extra + 1;
  if (needed <= sb->cap) {
    return 0;
  }

  new_cap = sb->cap;
  while (new_cap < needed) {
    if (new_cap > ((size_t)-1) / 2) {
      return -1;
    }
    new_cap *= 2;
  }

  new_data = (char *)realloc(sb->data, new_cap);
  if (!new_data) {
    return -1;
  }

  sb->data = new_data;
  sb->cap = new_cap;
  return 0;
}

static int sb_append_n(strbuf *sb, const char *text, size_t n) {
  if (!sb || !text) {
    return -1;
  }

  if (sb_reserve(sb, n) != 0) {
    return -1;
  }

  memcpy(sb->data + sb->len, text, n);
  sb->len += n;
  sb->data[sb->len] = '\0';
  return 0;
}

static int sb_append(strbuf *sb, const char *text) {
  if (!text) {
    return -1;
  }

  return sb_append_n(sb, text, strlen(text));
}

static int sb_appendf(strbuf *sb, const char *fmt, ...) {
  va_list ap;
  va_list ap2;
  int n;

  if (!sb || !fmt) {
    return -1;
  }

  va_start(ap, fmt);
  va_copy(ap2, ap);
  n = vsnprintf(NULL, 0, fmt, ap);
  va_end(ap);

  if (n < 0) {
    va_end(ap2);
    return -1;
  }

  if (sb_reserve(sb, (size_t)n) != 0) {
    va_end(ap2);
    return -1;
  }

  if (vsnprintf(sb->data + sb->len, sb->cap - sb->len, fmt, ap2) < 0) {
    va_end(ap2);
    return -1;
  }

  va_end(ap2);
  sb->len += (size_t)n;
  return 0;
}

static int json_unescape(const char *in, char *out, size_t out_size) {
  size_t oi;

  if (!in || !out || out_size == 0) {
    return -1;
  }

  oi = 0;
  while (*in) {
    char ch = *in;

    if (ch == '\\') {
      in++;
      if (!*in) {
        return -1;
      }

      switch (*in) {
        case 'b': ch = '\b'; break;
        case 'f': ch = '\f'; break;
        case 'n': ch = '\n'; break;
        case 'r': ch = '\r'; break;
        case 't': ch = '\t'; break;
        case '"': ch = '"'; break;
        case '\\': ch = '\\'; break;
        case '/': ch = '/'; break;
        case 'u': {
          unsigned long code = 0;
          int i;

          for (i = 0; i < 4; i++) {
            unsigned char hx = (unsigned char)in[1 + i];
            code <<= 4;
            if (hx >= '0' && hx <= '9') {
              code |= (unsigned long)(hx - '0');
            } else if (hx >= 'a' && hx <= 'f') {
              code |= (unsigned long)(hx - 'a' + 10);
            } else if (hx >= 'A' && hx <= 'F') {
              code |= (unsigned long)(hx - 'A' + 10);
            } else {
              return -1;
            }
          }

          if (code >= 0xD800 && code <= 0xDBFF) {
            unsigned long low = 0;

            if (in[5] != '\\' || in[6] != 'u') {
              return -1;
            }

            for (i = 0; i < 4; i++) {
              unsigned char hx = (unsigned char)in[7 + i];
              low <<= 4;
              if (hx >= '0' && hx <= '9') {
                low |= (unsigned long)(hx - '0');
              } else if (hx >= 'a' && hx <= 'f') {
                low |= (unsigned long)(hx - 'a' + 10);
              } else if (hx >= 'A' && hx <= 'F') {
                low |= (unsigned long)(hx - 'A' + 10);
              } else {
                return -1;
              }
            }

            if (low < 0xDC00 || low > 0xDFFF) {
              return -1;
            }

            code = 0x10000 + (((code - 0xD800) << 10) | (low - 0xDC00));
          } else if (code >= 0xDC00 && code <= 0xDFFF) {
            return -1;
          }

          if (code == 0) {
            return -1;
          }

          if (code <= 0x7F) {
            if (oi + 1 >= out_size) {
              return -1;
            }
            out[oi++] = (char)code;
          } else if (code <= 0x7FF) {
            if (oi + 2 >= out_size) {
              return -1;
            }
            out[oi++] = (char)(0xC0 | ((code >> 6) & 0x1F));
            out[oi++] = (char)(0x80 | (code & 0x3F));
          } else if (code <= 0xFFFF) {
            if (oi + 3 >= out_size) {
              return -1;
            }
            out[oi++] = (char)(0xE0 | ((code >> 12) & 0x0F));
            out[oi++] = (char)(0x80 | ((code >> 6) & 0x3F));
            out[oi++] = (char)(0x80 | (code & 0x3F));
          } else if (code <= 0x10FFFF) {
            if (oi + 4 >= out_size) {
              return -1;
            }
            out[oi++] = (char)(0xF0 | ((code >> 18) & 0x07));
            out[oi++] = (char)(0x80 | ((code >> 12) & 0x3F));
            out[oi++] = (char)(0x80 | ((code >> 6) & 0x3F));
            out[oi++] = (char)(0x80 | (code & 0x3F));
          } else {
            return -1;
          }

          in += code > 0xFFFF ? 11 : 5;
          continue;
        }
        default:
          return -1;
      }
    }

    if (oi + 1 >= out_size) {
      return -1;
    }

    out[oi++] = ch;
    in++;
  }

  out[oi] = '\0';
  return 0;
}

static int json_escape(const char *in, char *out, size_t out_size) {
  size_t oi;

  if (!in || !out || out_size == 0) {
    return -1;
  }

  oi = 0;
  while (*in) {
    const char *esc = NULL;
    char ch = *in;

    switch (ch) {
      case '"': esc = "\\\""; break;
      case '\\': esc = "\\\\"; break;
      case '\b': esc = "\\b"; break;
      case '\f': esc = "\\f"; break;
      case '\n': esc = "\\n"; break;
      case '\r': esc = "\\r"; break;
      case '\t': esc = "\\t"; break;
      default: break;
    }

    if (esc) {
      size_t elen = strlen(esc);
      if (oi + elen >= out_size) {
        return -1;
      }
      memcpy(out + oi, esc, elen);
      oi += elen;
    } else {
      if ((unsigned char)ch < 0x20) {
        int n;
        if (oi + 6 >= out_size) {
          return -1;
        }
        n = snprintf(out + oi, out_size - oi, "\\u%04x", (unsigned char)ch);
        if (n != 6) {
          return -1;
        }
        oi += 6;
      } else if (oi + 1 >= out_size) {
        return -1;
      } else {
        out[oi++] = ch;
      }
    }

    in++;
  }

  out[oi] = '\0';
  return 0;
}

static const char *skip_json_string_token(const char *p) {
  if (!p || *p != '"') {
    return NULL;
  }

  p++;
  while (*p) {
    if (*p == '\\') {
      p++;
      if (!*p) {
        return NULL;
      }
      p++;
      continue;
    }
    if (*p == '"') {
      return p + 1;
    }
    p++;
  }

  return NULL;
}

static const char *skip_json_value_token(const char *p) {
  p = skip_ws(p);
  if (!p || !*p) {
    return NULL;
  }

  if (*p == '"') {
    return skip_json_string_token(p);
  }

  if (*p == '{' || *p == '[') {
    const char *q = p;
    int depth = 0;
    int in_string = 0;
    int escaped = 0;

    while (*q) {
      if (in_string) {
        if (escaped) {
          escaped = 0;
        } else if (*q == '\\') {
          escaped = 1;
        } else if (*q == '"') {
          in_string = 0;
        }
      } else if (*q == '"') {
        in_string = 1;
      } else if (*q == '{' || *q == '[') {
        depth++;
      } else if (*q == '}' || *q == ']') {
        depth--;
        if (depth == 0) {
          return q + 1;
        }
        if (depth < 0) {
          return NULL;
        }
      }
      q++;
    }

    return NULL;
  }

  while (*p && *p != ',' && *p != '}' && *p != ']') {
    p++;
  }

  return p;
}

static int key_span_matches(const char *start, const char *end, const char *field) {
  const char *p;
  size_t field_len;

  if (!start || !end || !field || end < start) {
    return 0;
  }

  for (p = start; p < end; p++) {
    if (*p == '\\') {
      return 0;
    }
  }

  field_len = strlen(field);
  return (size_t)(end - start) == field_len && memcmp(start, field, field_len) == 0;
}

static int find_json_object_value(const char *json,
                                  const char *field,
                                  const char **value_start,
                                  const char **value_end) {
  const char *p;

  if (!json || !field || !value_start || !value_end) {
    return -1;
  }

  p = skip_ws(json);
  if (!p || *p != '{') {
    return -1;
  }

  p++;
  while (1) {
    const char *key_start;
    const char *key_after;
    const char *key_end;
    const char *start;
    const char *end;

    p = skip_ws(p);
    if (!p || !*p) {
      return -1;
    }
    if (*p == '}') {
      return -1;
    }
    if (*p != '"') {
      return -1;
    }

    key_start = p + 1;
    key_after = skip_json_string_token(p);
    if (!key_after) {
      return -1;
    }
    key_end = key_after - 1;

    p = skip_ws(key_after);
    if (!p || *p != ':') {
      return -1;
    }

    start = skip_ws(p + 1);
    end = skip_json_value_token(start);
    if (!start || !end) {
      return -1;
    }

    if (key_span_matches(key_start, key_end, field)) {
      *value_start = start;
      *value_end = end;
      return 0;
    }

    p = skip_ws(end);
    if (!p || !*p) {
      return -1;
    }
    if (*p == ',') {
      p++;
      continue;
    }
    if (*p == '}') {
      return -1;
    }
    return -1;
  }
}

static int extract_json_string_value(const char *json,
                                     const char *field,
                                     char *out,
                                     size_t out_size) {
  const char *start;
  const char *end;
  size_t len;

  if (!json || !field || !out || out_size == 0) {
    return -1;
  }

  if (find_json_object_value(json, field, &start, &end) != 0) {
    return -1;
  }

  if (!start || *start != '"') {
    return -1;
  }

  end = skip_json_string_token(start);
  if (!end) {
    return -1;
  }

  start++;
  end--;
  len = (size_t)(end - start);
  if (len >= out_size) {
    return -1;
  }

  memcpy(out, start, len);
  out[len] = '\0';
  return 0;
}

static int extract_json_object_value(const char *json,
                                     const char *field,
                                     char *out,
                                     size_t out_size) {
  const char *start;
  const char *end;
  size_t len;

  if (!json || !field || !out || out_size == 0) {
    return -1;
  }

  if (find_json_object_value(json, field, &start, &end) != 0) {
    return -1;
  }

  if (!start || *start != '{') {
    return -1;
  }

  len = (size_t)(end - start);
  if (len >= out_size) {
    return -1;
  }

  memcpy(out, start, len);
  out[len] = '\0';
  return 0;
}

static int extract_json_raw_value(const char *json,
                                  const char *field,
                                  char *out,
                                  size_t out_size) {
  const char *start;
  const char *end;
  size_t len;

  if (!json || !field || !out || out_size == 0) {
    return -1;
  }

  if (find_json_object_value(json, field, &start, &end) != 0) {
    return -1;
  }

  while (end > start && isspace((unsigned char)*(end - 1))) {
    end--;
  }

  len = (size_t)(end - start);
  if (len >= out_size) {
    return -1;
  }

  memcpy(out, start, len);
  out[len] = '\0';
  return 0;
}

static int extract_json_raw_id(const char *json, char *id_out, size_t id_out_size) {
  if (!json || !id_out || id_out_size == 0) {
    return -1;
  }

  if (extract_json_raw_value(json, "id", id_out, id_out_size) != 0) {
    return safe_copy(id_out, id_out_size, "null");
  }

  return 0;
}

static int extract_params_string(const char *json,
                                 const char *field,
                                 char *out,
                                 size_t out_size) {
  char raw[8192];
  char scoped_params[8192];

  if (!json || !field || !out || out_size == 0) {
    return -1;
  }

  if (extract_json_object_value(json, "params", scoped_params, sizeof(scoped_params)) != 0) {
    return -1;
  }
  if (extract_json_string_value(scoped_params, field, raw, sizeof(raw)) != 0) {
    return -1;
  }

  return json_unescape(raw, out, out_size);
}

static int emit_event_payload_path(wizardry_core *core, const char *event_name, const char *path) {
  char escaped[WIZARDRY_CORE_PATH_MAX * 2 + 8];
  char payload[WIZARDRY_CORE_PATH_MAX * 2 + 32];

  if (!core || !event_name || !path) {
    return -1;
  }

  if (json_escape(path, escaped, sizeof(escaped)) != 0) {
    return -1;
  }

  if (snprintf(payload, sizeof(payload), "{\"path\":\"%s\"}", escaped) < 0) {
    return -1;
  }

  core->event_seq++;
  if (core->event_cb) {
    core->event_cb(event_name, payload, core->event_user_data);
  }

  return 0;
}

static int write_success(char *buf,
                         size_t buf_size,
                         const char *id_raw,
                         const char *result_json) {
  int n;

  n = snprintf(buf,
               buf_size,
               "{\"jsonrpc\":\"2.0\",\"id\":%s,\"result\":%s}",
               id_raw,
               result_json);

  if (n < 0 || (size_t)n >= buf_size) {
    return -1;
  }
  return 0;
}

static int write_error(char *buf,
                       size_t buf_size,
                       const char *id_raw,
                       int code,
                       const char *message) {
  int n;

  n = snprintf(buf,
               buf_size,
               "{\"jsonrpc\":\"2.0\",\"id\":%s,\"error\":{\"code\":%d,\"message\":\"%s\"}}",
               id_raw,
               code,
               message);

  if (n < 0 || (size_t)n >= buf_size) {
    return -1;
  }
  return 0;
}

static int path_segment_is_parent_ref(const char *segment, size_t len) {
  return len == 2 && segment[0] == '.' && segment[1] == '.';
}

static int is_safe_relative_path(const char *path) {
  const char *p;
  const char *seg_start;

  if (!path) {
    return 0;
  }

  if (path[0] == '\0') {
    return 1;
  }

  if (path[0] == '/') {
    return 0;
  }

  seg_start = path;
  p = path;
  while (1) {
    if (*p == '/' || *p == '\0') {
      size_t seg_len = (size_t)(p - seg_start);
      if (path_segment_is_parent_ref(seg_start, seg_len)) {
        return 0;
      }

      if (*p == '\0') {
        break;
      }

      seg_start = p + 1;
    }

    p++;
  }

  return 1;
}

static int resolve_vault_path(const wizardry_core *core,
                              const char *relative,
                              char *absolute,
                              size_t absolute_size) {
  int n;

  if (!core || !absolute || absolute_size == 0) {
    return -1;
  }

  if (!core->mounted_vault[0]) {
    return -1;
  }

  if (!relative) {
    relative = "";
  }

  if (!is_safe_relative_path(relative)) {
    return -1;
  }

  if (!relative[0]) {
    return safe_copy(absolute, absolute_size, core->mounted_vault);
  }

  n = snprintf(absolute, absolute_size, "%s/%s", core->mounted_vault, relative);
  if (n < 0 || (size_t)n >= absolute_size) {
    return -1;
  }

  return 0;
}

static int path_is_inside_vault(const wizardry_core *core, const char *absolute) {
  size_t vault_len;

  if (!core || !core->mounted_vault[0] || !absolute) {
    return 0;
  }

  vault_len = strlen(core->mounted_vault);
  if (strcmp(absolute, core->mounted_vault) == 0) {
    return 1;
  }

  return strncmp(absolute, core->mounted_vault, vault_len) == 0 &&
         absolute[vault_len] == '/';
}

static int validate_vault_target_path(const wizardry_core *core,
                                      const char *absolute,
                                      int must_exist) {
  char resolved[WIZARDRY_CORE_PATH_MAX * 2];
  char parent[WIZARDRY_CORE_PATH_MAX * 2];
  char *slash;

  if (!core || !absolute || !absolute[0]) {
    return -1;
  }

  if (realpath(absolute, resolved)) {
    return path_is_inside_vault(core, resolved) ? 0 : -1;
  }

  if (must_exist) {
    return -1;
  }

  if (safe_copy(parent, sizeof(parent), absolute) != 0) {
    return -1;
  }

  while (1) {
    slash = strrchr(parent, '/');
    if (!slash) {
      return -1;
    }

    if (slash == parent) {
      parent[1] = '\0';
    } else {
      *slash = '\0';
    }

    if (realpath(parent, resolved)) {
      return path_is_inside_vault(core, resolved) ? 0 : -1;
    }

    if (slash == parent) {
      return -1;
    }
  }
}

static int ensure_parent_dirs(const char *path) {
  char tmp[WIZARDRY_CORE_PATH_MAX * 2];
  char *p;

  if (!path) {
    return -1;
  }

  if (safe_copy(tmp, sizeof(tmp), path) != 0) {
    return -1;
  }

  p = strrchr(tmp, '/');
  if (!p) {
    return 0;
  }

  *p = '\0';
  if (!tmp[0]) {
    return 0;
  }

  for (p = tmp + 1; *p; p++) {
    if (*p == '/') {
      *p = '\0';
      if (mkdir(tmp, 0755) != 0 && errno != EEXIST) {
        return -1;
      }
      *p = '/';
    }
  }

  if (mkdir(tmp, 0755) != 0 && errno != EEXIST) {
    return -1;
  }

  return 0;
}

static int read_file_to_string(const char *path, char **out, size_t *out_len) {
  FILE *fp;
  strbuf sb;
  char chunk[2048];
  size_t n;

  if (!path || !out) {
    return -1;
  }

  fp = fopen(path, "rb");
  if (!fp) {
    return -1;
  }

  if (sb_init(&sb, 4096) != 0) {
    fclose(fp);
    return -1;
  }

  while ((n = fread(chunk, 1, sizeof(chunk), fp)) > 0) {
    if (sb_append_n(&sb, chunk, n) != 0) {
      sb_free(&sb);
      fclose(fp);
      return -1;
    }
  }

  if (ferror(fp)) {
    sb_free(&sb);
    fclose(fp);
    return -1;
  }

  fclose(fp);

  *out = sb.data;
  if (out_len) {
    *out_len = sb.len;
  }
  return 0;
}

static int write_string_to_file(const char *path, const char *data) {
  FILE *fp;
  size_t len;

  if (!path || !data) {
    return -1;
  }

  fp = fopen(path, "wb");
  if (!fp) {
    return -1;
  }

  len = strlen(data);
  if (len > 0 && fwrite(data, 1, len, fp) != len) {
    fclose(fp);
    return -1;
  }

  fclose(fp);
  return 0;
}

static int has_markdown_extension(const char *name) {
  const char *dot;

  if (!name) {
    return 0;
  }

  dot = strrchr(name, '.');
  if (!dot) {
    return 0;
  }

  return strcmp(dot, ".md") == 0 || strcmp(dot, ".markdown") == 0;
}

static int parse_json_string_token(const char **cursor, char *out, size_t out_size) {
  const char *p;
  size_t oi;

  if (!cursor || !*cursor || !out || out_size == 0) {
    return -1;
  }

  p = *cursor;
  if (*p != '"') {
    return -1;
  }

  p++;
  oi = 0;
  while (*p && *p != '"') {
    char ch = *p;

    if (ch == '\\') {
      p++;
      if (!*p) {
        return -1;
      }
      switch (*p) {
        case 'n': ch = '\n'; break;
        case 'r': ch = '\r'; break;
        case 't': ch = '\t'; break;
        case '"': ch = '"'; break;
        case '\\': ch = '\\'; break;
        case '/': ch = '/'; break;
        default: ch = *p; break;
      }
    }

    if (oi + 1 >= out_size) {
      return -1;
    }

    out[oi++] = ch;
    p++;
  }

  if (*p != '"') {
    return -1;
  }

  out[oi] = '\0';
  *cursor = p + 1;
  return 0;
}

static int load_sidecar_entries(const char *doc_path,
                                sidecar_entry *entries,
                                size_t entries_max,
                                size_t *count_out) {
  char json[16384];
  size_t json_len;
  const char *xattrs;
  const char *p;
  size_t count;

  if (!doc_path || !entries || !count_out) {
    return -1;
  }

  *count_out = 0;

  if (wizardry_sidecar_read(doc_path, json, sizeof(json), &json_len) != 0) {
    return 0;
  }

  if (json_len == 0) {
    return 0;
  }

  xattrs = strstr(json, "\"xattrs\"");
  if (!xattrs) {
    return 0;
  }

  p = strchr(xattrs, '{');
  if (!p) {
    return -1;
  }

  p++;
  count = 0;
  while (1) {
    p = skip_ws(p);
    if (!p || !*p) {
      return -1;
    }

    if (*p == '}') {
      break;
    }

    if (count >= entries_max) {
      return -1;
    }

    if (parse_json_string_token(&p, entries[count].key, sizeof(entries[count].key)) != 0) {
      return -1;
    }

    p = skip_ws(p);
    if (*p != ':') {
      return -1;
    }

    p++;
    p = skip_ws(p);
    if (parse_json_string_token(&p, entries[count].value, sizeof(entries[count].value)) != 0) {
      return -1;
    }

    count++;

    p = skip_ws(p);
    if (*p == ',') {
      p++;
      continue;
    }

    if (*p == '}') {
      break;
    }

    return -1;
  }

  *count_out = count;
  return 0;
}

static int save_sidecar_entries(const char *doc_path,
                                sidecar_entry *entries,
                                size_t count) {
  strbuf sb;
  size_t i;

  if (!doc_path || !entries) {
    return -1;
  }

  if (sb_init(&sb, 512) != 0) {
    return -1;
  }

  if (sb_append(&sb, "{\"version\":\"1\",\"docPath\":\"") != 0) {
    sb_free(&sb);
    return -1;
  }

  {
    char escaped_doc[WIZARDRY_CORE_PATH_MAX * 2 + 32];
    if (json_escape(doc_path, escaped_doc, sizeof(escaped_doc)) != 0) {
      sb_free(&sb);
      return -1;
    }
    if (sb_append(&sb, escaped_doc) != 0 || sb_append(&sb, "\",\"xattrs\":{") != 0) {
      sb_free(&sb);
      return -1;
    }
  }

  for (i = 0; i < count; i++) {
    char escaped_key[sizeof(entries[i].key) * 2 + 8];
    char escaped_value[sizeof(entries[i].value) * 2 + 8];

    if (json_escape(entries[i].key, escaped_key, sizeof(escaped_key)) != 0 ||
        json_escape(entries[i].value, escaped_value, sizeof(escaped_value)) != 0) {
      sb_free(&sb);
      return -1;
    }

    if (i > 0 && sb_append(&sb, ",") != 0) {
      sb_free(&sb);
      return -1;
    }

    if (sb_appendf(&sb, "\"%s\":\"%s\"", escaped_key, escaped_value) != 0) {
      sb_free(&sb);
      return -1;
    }
  }

  if (sb_append(&sb, "}}") != 0) {
    sb_free(&sb);
    return -1;
  }

  if (wizardry_sidecar_write(doc_path, sb.data, sb.len) != 0) {
    sb_free(&sb);
    return -1;
  }

  sb_free(&sb);
  return 0;
}

static ssize_t find_sidecar_entry(sidecar_entry *entries, size_t count, const char *key) {
  size_t i;

  if (!entries || !key) {
    return -1;
  }

  for (i = 0; i < count; i++) {
    if (strcmp(entries[i].key, key) == 0) {
      return (ssize_t)i;
    }
  }

  return -1;
}

static int validate_vault_sidecar_path(const wizardry_core *core, const char *doc_path) {
  char sidecar_path[WIZARDRY_CORE_PATH_MAX * 2 + 32];

  if (wizardry_sidecar_path(doc_path, sidecar_path, sizeof(sidecar_path)) != 0) {
    return -1;
  }

  return validate_vault_target_path(core, sidecar_path, 0);
}

static int handle_doc_list(wizardry_core *core,
                           const char *request_json,
                           const char *id_raw,
                           char *response_json,
                           size_t response_size) {
  char logical_dir[WIZARDRY_CORE_PATH_MAX];
  char abs_dir[WIZARDRY_CORE_PATH_MAX * 2];
  DIR *dir;
  struct dirent *entry;
  strbuf result;
  int first;

  logical_dir[0] = '\0';
  (void)extract_params_string(request_json, "path", logical_dir, sizeof(logical_dir));

  if (resolve_vault_path(core, logical_dir, abs_dir, sizeof(abs_dir)) != 0) {
    return write_error(response_json,
                       response_size,
                       id_raw,
                       JSONRPC_INVALID_PARAMS,
                       "doc.list requires mounted vault and safe params.path");
  }

  if (validate_vault_target_path(core, abs_dir, 1) != 0) {
    return write_error(response_json,
                       response_size,
                       id_raw,
                       JSONRPC_INVALID_PARAMS,
                       "doc.list path is not readable");
  }

  dir = opendir(abs_dir);
  if (!dir) {
    return write_error(response_json,
                       response_size,
                       id_raw,
                       JSONRPC_INVALID_PARAMS,
                       "doc.list path is not readable");
  }

  if (sb_init(&result, 512) != 0) {
    closedir(dir);
    return write_error(response_json,
                       response_size,
                       id_raw,
                       JSONRPC_INTERNAL_ERROR,
                       "allocation failure");
  }

  if (sb_append(&result, "{\"docs\":[") != 0) {
    sb_free(&result);
    closedir(dir);
    return write_error(response_json,
                       response_size,
                       id_raw,
                       JSONRPC_INTERNAL_ERROR,
                       "allocation failure");
  }

  first = 1;
  while ((entry = readdir(dir)) != NULL) {
    char abs_item[WIZARDRY_CORE_PATH_MAX * 2];
    char rel_item[WIZARDRY_CORE_PATH_MAX * 2];
    char escaped_rel[WIZARDRY_CORE_PATH_MAX * 4];
    struct stat st;

    if (strcmp(entry->d_name, ".") == 0 || strcmp(entry->d_name, "..") == 0) {
      continue;
    }

    if (!has_markdown_extension(entry->d_name)) {
      continue;
    }

    if (snprintf(abs_item, sizeof(abs_item), "%s/%s", abs_dir, entry->d_name) < 0) {
      continue;
    }

    if (validate_vault_target_path(core, abs_item, 1) != 0) {
      continue;
    }

    if (stat(abs_item, &st) != 0 || !S_ISREG(st.st_mode)) {
      continue;
    }

    if (logical_dir[0]) {
      if (snprintf(rel_item, sizeof(rel_item), "%s/%s", logical_dir, entry->d_name) < 0) {
        continue;
      }
    } else {
      if (safe_copy(rel_item, sizeof(rel_item), entry->d_name) != 0) {
        continue;
      }
    }

    if (json_escape(rel_item, escaped_rel, sizeof(escaped_rel)) != 0) {
      continue;
    }

    if (!first && sb_append(&result, ",") != 0) {
      sb_free(&result);
      closedir(dir);
      return write_error(response_json,
                         response_size,
                         id_raw,
                         JSONRPC_INTERNAL_ERROR,
                         "allocation failure");
    }

    if (sb_appendf(&result, "\"%s\"", escaped_rel) != 0) {
      sb_free(&result);
      closedir(dir);
      return write_error(response_json,
                         response_size,
                         id_raw,
                         JSONRPC_INTERNAL_ERROR,
                         "allocation failure");
    }

    first = 0;
  }

  closedir(dir);

  if (sb_append(&result, "]}") != 0) {
    sb_free(&result);
    return write_error(response_json,
                       response_size,
                       id_raw,
                       JSONRPC_INTERNAL_ERROR,
                       "allocation failure");
  }

  if (write_success(response_json, response_size, id_raw, result.data) != 0) {
    sb_free(&result);
    return write_error(response_json,
                       response_size,
                       id_raw,
                       JSONRPC_INTERNAL_ERROR,
                       "response too large");
  }

  sb_free(&result);
  return 0;
}

static int handle_doc_read(wizardry_core *core,
                           const char *request_json,
                           const char *id_raw,
                           char *response_json,
                           size_t response_size) {
  char logical_path[WIZARDRY_CORE_PATH_MAX];
  char abs_path[WIZARDRY_CORE_PATH_MAX * 2];
  char escaped_path[WIZARDRY_CORE_PATH_MAX * 2 + 8];
  char *content;
  char *result;
  size_t content_len;
  size_t result_cap;
  size_t escaped_cap;

  if (extract_params_string(request_json, "path", logical_path, sizeof(logical_path)) != 0 ||
      !logical_path[0] ||
      resolve_vault_path(core, logical_path, abs_path, sizeof(abs_path)) != 0) {
    return write_error(response_json,
                       response_size,
                       id_raw,
                       JSONRPC_INVALID_PARAMS,
                       "doc.read requires mounted vault and params.path");
  }

  if (validate_vault_target_path(core, abs_path, 1) != 0) {
    return write_error(response_json,
                       response_size,
                       id_raw,
                       JSONRPC_INVALID_PARAMS,
                       "doc.read path is not readable");
  }

  if (read_file_to_string(abs_path, &content, &content_len) != 0) {
    return write_error(response_json,
                       response_size,
                       id_raw,
                       JSONRPC_INVALID_PARAMS,
                       "doc.read path is not readable");
  }

  if (json_escape(logical_path, escaped_path, sizeof(escaped_path)) != 0) {
    free(content);
    return write_error(response_json,
                       response_size,
                       id_raw,
                       JSONRPC_INTERNAL_ERROR,
                       "path escaping failed");
  }

  escaped_cap = content_len * 2 + 8;
  if (escaped_cap < 32) {
    escaped_cap = 32;
  }

  result_cap = escaped_cap + strlen(escaped_path) + 64;
  result = (char *)malloc(result_cap);
  if (!result) {
    free(content);
    return write_error(response_json,
                       response_size,
                       id_raw,
                       JSONRPC_INTERNAL_ERROR,
                       "allocation failure");
  }

  {
    char *escaped_content = (char *)malloc(escaped_cap);
    if (!escaped_content) {
      free(content);
      free(result);
      return write_error(response_json,
                         response_size,
                         id_raw,
                         JSONRPC_INTERNAL_ERROR,
                         "allocation failure");
    }

    if (json_escape(content, escaped_content, escaped_cap) != 0) {
      free(content);
      free(escaped_content);
      free(result);
      return write_error(response_json,
                         response_size,
                         id_raw,
                         JSONRPC_INTERNAL_ERROR,
                         "content escaping failed");
    }

    if (snprintf(result,
                 result_cap,
                 "{\"path\":\"%s\",\"content\":\"%s\"}",
                 escaped_path,
                 escaped_content) < 0) {
      free(content);
      free(escaped_content);
      free(result);
      return write_error(response_json,
                         response_size,
                         id_raw,
                         JSONRPC_INTERNAL_ERROR,
                         "response formatting failed");
    }

    free(escaped_content);
  }

  free(content);

  if (write_success(response_json, response_size, id_raw, result) != 0) {
    free(result);
    return write_error(response_json,
                       response_size,
                       id_raw,
                       JSONRPC_INTERNAL_ERROR,
                       "response too large");
  }

  free(result);
  return 0;
}

static int handle_doc_write(wizardry_core *core,
                            const char *request_json,
                            const char *id_raw,
                            char *response_json,
                            size_t response_size) {
  char logical_path[WIZARDRY_CORE_PATH_MAX];
  char abs_path[WIZARDRY_CORE_PATH_MAX * 2];
  char content[8192];

  if (extract_params_string(request_json, "path", logical_path, sizeof(logical_path)) != 0 ||
      !logical_path[0] ||
      resolve_vault_path(core, logical_path, abs_path, sizeof(abs_path)) != 0) {
    return write_error(response_json,
                       response_size,
                       id_raw,
                       JSONRPC_INVALID_PARAMS,
                       "doc.write requires mounted vault and params.path");
  }

  if (extract_params_string(request_json, "content", content, sizeof(content)) != 0) {
    return write_error(response_json,
                       response_size,
                       id_raw,
                       JSONRPC_INVALID_PARAMS,
                       "doc.write requires params.content");
  }

  if (validate_vault_target_path(core, abs_path, 0) != 0 ||
      ensure_parent_dirs(abs_path) != 0 ||
      validate_vault_target_path(core, abs_path, 0) != 0 ||
      write_string_to_file(abs_path, content) != 0) {
    return write_error(response_json,
                       response_size,
                       id_raw,
                       JSONRPC_INTERNAL_ERROR,
                       "doc.write failed");
  }

  emit_event_payload_path(core, "docChanged", logical_path);
  emit_event_payload_path(core, "cardUpdated", logical_path);

  return write_success(response_json, response_size, id_raw, "{\"written\":true}");
}

static int handle_doc_delete(wizardry_core *core,
                             const char *request_json,
                             const char *id_raw,
                             char *response_json,
                             size_t response_size) {
  char logical_path[WIZARDRY_CORE_PATH_MAX];
  char abs_path[WIZARDRY_CORE_PATH_MAX * 2];
  char sidecar_path[WIZARDRY_CORE_PATH_MAX * 2 + 32];

  if (extract_params_string(request_json, "path", logical_path, sizeof(logical_path)) != 0 ||
      !logical_path[0] ||
      resolve_vault_path(core, logical_path, abs_path, sizeof(abs_path)) != 0) {
    return write_error(response_json,
                       response_size,
                       id_raw,
                       JSONRPC_INVALID_PARAMS,
                       "doc.delete requires mounted vault and params.path");
  }

  if (validate_vault_target_path(core, abs_path, 1) != 0) {
    return write_error(response_json,
                       response_size,
                       id_raw,
                       JSONRPC_INVALID_PARAMS,
                       "doc.delete failed (path missing?)");
  }

  if (unlink(abs_path) != 0) {
    return write_error(response_json,
                       response_size,
                       id_raw,
                       JSONRPC_INVALID_PARAMS,
                       "doc.delete failed (path missing?)");
  }

  if (wizardry_sidecar_path(abs_path, sidecar_path, sizeof(sidecar_path)) == 0) {
    unlink(sidecar_path);
  }

  emit_event_payload_path(core, "docChanged", logical_path);
  emit_event_payload_path(core, "cardUpdated", logical_path);

  return write_success(response_json, response_size, id_raw, "{\"deleted\":true}");
}

static int handle_meta_get(wizardry_core *core,
                           const char *request_json,
                           const char *id_raw,
                           char *response_json,
                           size_t response_size) {
  char logical_path[WIZARDRY_CORE_PATH_MAX];
  char abs_path[WIZARDRY_CORE_PATH_MAX * 2];
  char key[256];
  sidecar_entry entries[128];
  size_t count;

  if (extract_params_string(request_json, "path", logical_path, sizeof(logical_path)) != 0 ||
      !logical_path[0] ||
      resolve_vault_path(core, logical_path, abs_path, sizeof(abs_path)) != 0) {
    return write_error(response_json,
                       response_size,
                       id_raw,
                       JSONRPC_INVALID_PARAMS,
                       "meta.get requires mounted vault and params.path");
  }

  if (validate_vault_target_path(core, abs_path, 0) != 0 ||
      validate_vault_sidecar_path(core, abs_path) != 0) {
    return write_error(response_json,
                       response_size,
                       id_raw,
                       JSONRPC_INVALID_PARAMS,
                       "meta.get requires mounted vault and params.path");
  }

  if (load_sidecar_entries(abs_path, entries, 128, &count) != 0) {
    return write_error(response_json,
                       response_size,
                       id_raw,
                       JSONRPC_INTERNAL_ERROR,
                       "meta.get sidecar parse failure");
  }

  if (extract_params_string(request_json, "key", key, sizeof(key)) == 0) {
    ssize_t idx = find_sidecar_entry(entries, count, key);
    char escaped_key[sizeof(key) * 2 + 8];

    if (json_escape(key, escaped_key, sizeof(escaped_key)) != 0) {
      return write_error(response_json,
                         response_size,
                         id_raw,
                         JSONRPC_INTERNAL_ERROR,
                         "meta.get key escape failure");
    }

    if (idx >= 0) {
      char escaped_value[sizeof(entries[0].value) * 2 + 8];
      char result[sizeof(entries[0].value) * 2 + 512];

      if (json_escape(entries[idx].value, escaped_value, sizeof(escaped_value)) != 0) {
        return write_error(response_json,
                           response_size,
                           id_raw,
                           JSONRPC_INTERNAL_ERROR,
                           "meta.get value escape failure");
      }

      if (snprintf(result,
                   sizeof(result),
                   "{\"found\":true,\"key\":\"%s\",\"value\":\"%s\"}",
                   escaped_key,
                   escaped_value) < 0) {
        return write_error(response_json,
                           response_size,
                           id_raw,
                           JSONRPC_INTERNAL_ERROR,
                           "meta.get response failure");
      }

      return write_success(response_json, response_size, id_raw, result);
    }

    {
      char result[1024];
      if (snprintf(result,
                   sizeof(result),
                   "{\"found\":false,\"key\":\"%s\",\"value\":null}",
                   escaped_key) < 0) {
        return write_error(response_json,
                           response_size,
                           id_raw,
                           JSONRPC_INTERNAL_ERROR,
                           "meta.get response failure");
      }
      return write_success(response_json, response_size, id_raw, result);
    }
  }

  {
    strbuf result;
    size_t i;

    if (sb_init(&result, 512) != 0) {
      return write_error(response_json,
                         response_size,
                         id_raw,
                         JSONRPC_INTERNAL_ERROR,
                         "allocation failure");
    }

    if (sb_append(&result, "{\"xattrs\":{") != 0) {
      sb_free(&result);
      return write_error(response_json,
                         response_size,
                         id_raw,
                         JSONRPC_INTERNAL_ERROR,
                         "allocation failure");
    }

    for (i = 0; i < count; i++) {
      char escaped_key[sizeof(entries[i].key) * 2 + 8];
      char escaped_value[sizeof(entries[i].value) * 2 + 8];

      if (json_escape(entries[i].key, escaped_key, sizeof(escaped_key)) != 0 ||
          json_escape(entries[i].value, escaped_value, sizeof(escaped_value)) != 0) {
        sb_free(&result);
        return write_error(response_json,
                           response_size,
                           id_raw,
                           JSONRPC_INTERNAL_ERROR,
                           "meta.get escape failure");
      }

      if (i > 0 && sb_append(&result, ",") != 0) {
        sb_free(&result);
        return write_error(response_json,
                           response_size,
                           id_raw,
                           JSONRPC_INTERNAL_ERROR,
                           "allocation failure");
      }

      if (sb_appendf(&result, "\"%s\":\"%s\"", escaped_key, escaped_value) != 0) {
        sb_free(&result);
        return write_error(response_json,
                           response_size,
                           id_raw,
                           JSONRPC_INTERNAL_ERROR,
                           "allocation failure");
      }
    }

    if (sb_append(&result, "}}") != 0) {
      sb_free(&result);
      return write_error(response_json,
                         response_size,
                         id_raw,
                         JSONRPC_INTERNAL_ERROR,
                         "allocation failure");
    }

    if (write_success(response_json, response_size, id_raw, result.data) != 0) {
      sb_free(&result);
      return write_error(response_json,
                         response_size,
                         id_raw,
                         JSONRPC_INTERNAL_ERROR,
                         "response too large");
    }

    sb_free(&result);
  }

  return 0;
}

static int handle_meta_set(wizardry_core *core,
                           const char *request_json,
                           const char *id_raw,
                           char *response_json,
                           size_t response_size) {
  char logical_path[WIZARDRY_CORE_PATH_MAX];
  char abs_path[WIZARDRY_CORE_PATH_MAX * 2];
  char key[256];
  char value[2048];
  sidecar_entry entries[128];
  size_t count;
  ssize_t idx;

  if (extract_params_string(request_json, "path", logical_path, sizeof(logical_path)) != 0 ||
      !logical_path[0] ||
      resolve_vault_path(core, logical_path, abs_path, sizeof(abs_path)) != 0) {
    return write_error(response_json,
                       response_size,
                       id_raw,
                       JSONRPC_INVALID_PARAMS,
                       "meta.set requires mounted vault and params.path");
  }

  if (extract_params_string(request_json, "key", key, sizeof(key)) != 0 ||
      extract_params_string(request_json, "value", value, sizeof(value)) != 0) {
    return write_error(response_json,
                       response_size,
                       id_raw,
                       JSONRPC_INVALID_PARAMS,
                       "meta.set requires params.key and params.value");
  }

  if (validate_vault_target_path(core, abs_path, 0) != 0 ||
      validate_vault_sidecar_path(core, abs_path) != 0) {
    return write_error(response_json,
                       response_size,
                       id_raw,
                       JSONRPC_INVALID_PARAMS,
                       "meta.set requires mounted vault and params.path");
  }

  if (load_sidecar_entries(abs_path, entries, 128, &count) != 0) {
    return write_error(response_json,
                       response_size,
                       id_raw,
                       JSONRPC_INTERNAL_ERROR,
                       "meta.set sidecar parse failure");
  }

  idx = find_sidecar_entry(entries, count, key);
  if (idx >= 0) {
    if (safe_copy(entries[idx].value, sizeof(entries[idx].value), value) != 0) {
      return write_error(response_json,
                         response_size,
                         id_raw,
                         JSONRPC_INVALID_PARAMS,
                         "meta.set value too large");
    }
  } else {
    if (count >= 128) {
      return write_error(response_json,
                         response_size,
                         id_raw,
                         JSONRPC_INTERNAL_ERROR,
                         "meta.set sidecar capacity reached");
    }

    if (safe_copy(entries[count].key, sizeof(entries[count].key), key) != 0 ||
        safe_copy(entries[count].value, sizeof(entries[count].value), value) != 0) {
      return write_error(response_json,
                         response_size,
                         id_raw,
                         JSONRPC_INVALID_PARAMS,
                         "meta.set key/value too large");
    }

    count++;
  }

  if (save_sidecar_entries(abs_path, entries, count) != 0) {
    return write_error(response_json,
                       response_size,
                       id_raw,
                       JSONRPC_INTERNAL_ERROR,
                       "meta.set sidecar write failure");
  }

  emit_event_payload_path(core, "tagSetChanged", logical_path);
  return write_success(response_json, response_size, id_raw, "{\"set\":true}");
}

static int handle_meta_unset(wizardry_core *core,
                             const char *request_json,
                             const char *id_raw,
                             char *response_json,
                             size_t response_size) {
  char logical_path[WIZARDRY_CORE_PATH_MAX];
  char abs_path[WIZARDRY_CORE_PATH_MAX * 2];
  char key[256];
  sidecar_entry entries[128];
  size_t count;
  ssize_t idx;

  if (extract_params_string(request_json, "path", logical_path, sizeof(logical_path)) != 0 ||
      !logical_path[0] ||
      resolve_vault_path(core, logical_path, abs_path, sizeof(abs_path)) != 0) {
    return write_error(response_json,
                       response_size,
                       id_raw,
                       JSONRPC_INVALID_PARAMS,
                       "meta.unset requires mounted vault and params.path");
  }

  if (extract_params_string(request_json, "key", key, sizeof(key)) != 0) {
    return write_error(response_json,
                       response_size,
                       id_raw,
                       JSONRPC_INVALID_PARAMS,
                       "meta.unset requires params.key");
  }

  if (validate_vault_target_path(core, abs_path, 0) != 0 ||
      validate_vault_sidecar_path(core, abs_path) != 0) {
    return write_error(response_json,
                       response_size,
                       id_raw,
                       JSONRPC_INVALID_PARAMS,
                       "meta.unset requires mounted vault and params.path");
  }

  if (load_sidecar_entries(abs_path, entries, 128, &count) != 0) {
    return write_error(response_json,
                       response_size,
                       id_raw,
                       JSONRPC_INTERNAL_ERROR,
                       "meta.unset sidecar parse failure");
  }

  idx = find_sidecar_entry(entries, count, key);
  if (idx >= 0) {
    size_t i;
    for (i = (size_t)idx; i + 1 < count; i++) {
      entries[i] = entries[i + 1];
    }
    count--;

    if (save_sidecar_entries(abs_path, entries, count) != 0) {
      return write_error(response_json,
                         response_size,
                         id_raw,
                         JSONRPC_INTERNAL_ERROR,
                         "meta.unset sidecar write failure");
    }
  }

  emit_event_payload_path(core, "tagSetChanged", logical_path);
  return write_success(response_json, response_size, id_raw, "{\"unset\":true}");
}

int wizardry_core_init(wizardry_core *core) {
  if (!core) {
    return -1;
  }

  memset(core, 0, sizeof(*core));
  return 0;
}

int wizardry_core_shutdown(wizardry_core *core) {
  if (!core) {
    return -1;
  }

  core->tx_open = 0;
  core->event_cb = NULL;
  core->event_user_data = NULL;
  return 0;
}

int wizardry_core_mount_vault(wizardry_core *core, const char *path) {
  char resolved[WIZARDRY_CORE_PATH_MAX * 2];
  struct stat st;

  if (!core || !path || path[0] == '\0') {
    return -1;
  }

  if (!realpath(path, resolved) ||
      stat(resolved, &st) != 0 ||
      !S_ISDIR(st.st_mode) ||
      safe_copy(core->mounted_vault, sizeof(core->mounted_vault), resolved) != 0) {
    return -1;
  }

  emit_event_payload_path(core, "vaultMounted", core->mounted_vault);
  return 0;
}

int wizardry_core_subscribe(wizardry_core *core, wizardry_event_callback cb, void *user_data) {
  if (!core || !cb) {
    return -1;
  }

  core->event_cb = cb;
  core->event_user_data = user_data;
  return 0;
}

int wizardry_core_unsubscribe(wizardry_core *core) {
  if (!core) {
    return -1;
  }

  core->event_cb = NULL;
  core->event_user_data = NULL;
  return 0;
}

int wizardry_core_rpc(wizardry_core *core,
                      const char *request_json,
                      char *response_json,
                      size_t response_size) {
  char method[64];
  char id_raw[128];

  if (!core || !request_json || !response_json || response_size == 0) {
    return -1;
  }

  if (extract_json_raw_id(request_json, id_raw, sizeof(id_raw)) != 0) {
    safe_copy(id_raw, sizeof(id_raw), "null");
  }

  if (extract_json_string_value(request_json, "jsonrpc", method, sizeof(method)) != 0 ||
      strcmp(method, "2.0") != 0) {
    return write_error(response_json,
                       response_size,
                       id_raw,
                       JSONRPC_INVALID_REQUEST,
                       "jsonrpc must be 2.0");
  }

  if (extract_json_string_value(request_json, "method", method, sizeof(method)) != 0) {
    return write_error(response_json,
                       response_size,
                       id_raw,
                       JSONRPC_INVALID_REQUEST,
                       "method is required");
  }

  if (strcmp(method, "core.ping") == 0) {
    return write_success(response_json,
                         response_size,
                         id_raw,
                         "{\"ok\":true,\"engine\":\"wizardry-core\",\"version\":\"0.1.0\"}");
  }

  if (strcmp(method, "vault.mount") == 0) {
    char path[WIZARDRY_CORE_PATH_MAX];
    if (extract_params_string(request_json, "path", path, sizeof(path)) != 0 ||
        wizardry_core_mount_vault(core, path) != 0) {
      return write_error(response_json,
                         response_size,
                         id_raw,
                         JSONRPC_INVALID_PARAMS,
                         "vault.mount requires params.path");
    }

    return write_success(response_json,
                         response_size,
                         id_raw,
                         "{\"mounted\":true}");
  }

  if (strcmp(method, "vault.info") == 0) {
    char escaped_path[WIZARDRY_CORE_PATH_MAX * 2 + 8];
    char result[WIZARDRY_CORE_PATH_MAX * 2 + 96];
    const char *path = core->mounted_vault[0] ? core->mounted_vault : "";

    if (json_escape(path, escaped_path, sizeof(escaped_path)) != 0) {
      return write_error(response_json,
                         response_size,
                         id_raw,
                         JSONRPC_INTERNAL_ERROR,
                         "vault.info path escape failure");
    }

    if (snprintf(result,
                 sizeof(result),
                 "{\"mounted\":%s,\"path\":\"%s\"}",
                 core->mounted_vault[0] ? "true" : "false",
                 escaped_path) < 0) {
      return write_error(response_json,
                         response_size,
                         id_raw,
                         JSONRPC_INTERNAL_ERROR,
                         "vault.info formatting failure");
    }

    return write_success(response_json, response_size, id_raw, result);
  }

  if (strcmp(method, "doc.list") == 0) {
    return handle_doc_list(core, request_json, id_raw, response_json, response_size);
  }

  if (strcmp(method, "doc.read") == 0) {
    return handle_doc_read(core, request_json, id_raw, response_json, response_size);
  }

  if (strcmp(method, "doc.write") == 0) {
    return handle_doc_write(core, request_json, id_raw, response_json, response_size);
  }

  if (strcmp(method, "doc.delete") == 0) {
    return handle_doc_delete(core, request_json, id_raw, response_json, response_size);
  }

  if (strcmp(method, "meta.get") == 0) {
    return handle_meta_get(core, request_json, id_raw, response_json, response_size);
  }

  if (strcmp(method, "meta.set") == 0) {
    return handle_meta_set(core, request_json, id_raw, response_json, response_size);
  }

  if (strcmp(method, "meta.unset") == 0) {
    return handle_meta_unset(core, request_json, id_raw, response_json, response_size);
  }

  if (strcmp(method, "txn.begin") == 0) {
    if (core->tx_open) {
      return write_error(response_json,
                         response_size,
                         id_raw,
                         JSONRPC_INVALID_REQUEST,
                         "transaction already open");
    }
    core->tx_open = 1;
    core->tx_id++;
    return write_success(response_json,
                         response_size,
                         id_raw,
                         "{\"opened\":true}");
  }

  if (strcmp(method, "txn.commit") == 0) {
    char payload[96];
    if (!core->tx_open) {
      return write_error(response_json,
                         response_size,
                         id_raw,
                         JSONRPC_INVALID_REQUEST,
                         "no open transaction");
    }

    core->tx_open = 0;
    snprintf(payload, sizeof(payload), "{\"txId\":%lu}", core->tx_id);
    core->event_seq++;
    if (core->event_cb) {
      core->event_cb("txnCommitted", payload, core->event_user_data);
    }
    return write_success(response_json,
                         response_size,
                         id_raw,
                         "{\"committed\":true}");
  }

  if (strcmp(method, "txn.rollback") == 0) {
    if (!core->tx_open) {
      return write_error(response_json,
                         response_size,
                         id_raw,
                         JSONRPC_INVALID_REQUEST,
                         "no open transaction");
    }

    core->tx_open = 0;
    return write_success(response_json,
                         response_size,
                         id_raw,
                         "{\"rolledBack\":true}");
  }

  return write_error(response_json,
                     response_size,
                     id_raw,
                     JSONRPC_METHOD_NOT_FOUND,
                     "method not found");
}

int wizardry_sidecar_path(const char *doc_path, char *sidecar_path, size_t sidecar_path_size) {
  int n;

  if (!doc_path || !sidecar_path || sidecar_path_size == 0 || doc_path[0] == '\0') {
    return -1;
  }

  n = snprintf(sidecar_path, sidecar_path_size, "%s.xattr.json", doc_path);
  if (n < 0 || (size_t)n >= sidecar_path_size) {
    return -1;
  }

  return 0;
}

int wizardry_sidecar_read(const char *doc_path, char *json_buf, size_t json_buf_size, size_t *json_len) {
  char path[WIZARDRY_CORE_PATH_MAX + 32];
  FILE *fp;
  size_t n;

  if (!doc_path || !json_buf || json_buf_size == 0) {
    return -1;
  }

  if (wizardry_sidecar_path(doc_path, path, sizeof(path)) != 0) {
    return -1;
  }

  fp = fopen(path, "rb");
  if (!fp) {
    return -1;
  }

  n = fread(json_buf, 1, json_buf_size - 1, fp);
  fclose(fp);
  json_buf[n] = '\0';

  if (json_len) {
    *json_len = n;
  }

  return 0;
}

int wizardry_sidecar_write(const char *doc_path, const char *json_buf, size_t json_len) {
  char path[WIZARDRY_CORE_PATH_MAX + 32];
  FILE *fp;

  if (!doc_path || !json_buf) {
    return -1;
  }

  if (wizardry_sidecar_path(doc_path, path, sizeof(path)) != 0) {
    return -1;
  }

  if (ensure_parent_dirs(path) != 0) {
    return -1;
  }

  fp = fopen(path, "wb");
  if (!fp) {
    return -1;
  }

  if (json_len > 0 && fwrite(json_buf, 1, json_len, fp) != json_len) {
    fclose(fp);
    return -1;
  }

  fclose(fp);
  return 0;
}
