#include "wizardry_core.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

static int event_count = 0;
static char last_event[64];

static void on_event(const char *event_name, const char *payload, void *user_data) {
  (void)payload;
  (void)user_data;
  event_count++;
  if (event_name) {
    snprintf(last_event, sizeof(last_event), "%s", event_name);
  }
}

static int contains(const char *haystack, const char *needle) {
  return strstr(haystack, needle) != NULL;
}

static int run_rpc(wizardry_core *core, const char *request, char *response, size_t response_size) {
  if (wizardry_core_rpc(core, request, response, response_size) != 0) {
    fprintf(stderr, "rpc failure for request: %s\n", request);
    return -1;
  }
  return 0;
}

int main(void) {
  wizardry_core core;
  char response[16384];
  char sidecar_path[2048];
  char tmp_template[] = "/tmp/wizardry-core-test-XXXXXX";
  char outside_template[] = "/tmp/wizardry-core-outside-XXXXXX";
  char *vault_dir;
  char *outside_dir;

  if (wizardry_core_init(&core) != 0) {
    fprintf(stderr, "core init failed\n");
    return 1;
  }

  if (wizardry_core_subscribe(&core, on_event, NULL) != 0) {
    fprintf(stderr, "subscribe failed\n");
    return 1;
  }

  vault_dir = mkdtemp(tmp_template);
  if (!vault_dir) {
    fprintf(stderr, "mkdtemp failed\n");
    return 1;
  }
  outside_dir = mkdtemp(outside_template);
  if (!outside_dir) {
    fprintf(stderr, "outside mkdtemp failed\n");
    return 1;
  }

  if (run_rpc(&core,
              "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"core.ping\"}",
              response,
              sizeof(response)) != 0) {
    return 1;
  }

  if (!contains(response, "\"result\"") || !contains(response, "\"ok\":true")) {
    fprintf(stderr, "unexpected ping response: %s\n", response);
    return 1;
  }

  if (run_rpc(&core,
              "{\"jsonrpc\":\"2\\u002e0\",\"id\":101,\"method\":\"core.\\u0070ing\"}",
              response,
              sizeof(response)) != 0) {
    return 1;
  }

  if (!contains(response, "\"result\"") || !contains(response, "\"ok\":true")) {
    fprintf(stderr, "escaped jsonrpc/method response failed: %s\n", response);
    return 1;
  }

  {
    char invalid_method[] = "{\"jsonrpc\":\"2.0\",\"id\":102,\"method\":\"core\n.ping\"}";
    if (run_rpc(&core, invalid_method, response, sizeof(response)) != 0) {
      return 1;
    }
    if (!contains(response, "\"error\"")) {
      fprintf(stderr, "raw control character in JSON string was accepted: %s\n", response);
      return 1;
    }
  }

  {
    char req[4096];
    snprintf(req,
             sizeof(req),
             "{\"jsonrpc\":\"2.0\",\"id\":2,\"method\":\"vault.mount\",\"params\":{\"path\":\"%s\"}}",
             vault_dir);
    if (run_rpc(&core, req, response, sizeof(response)) != 0) {
      return 1;
    }
  }

  if (!contains(response, "\"mounted\":true")) {
    fprintf(stderr, "unexpected vault.mount response: %s\n", response);
    return 1;
  }

  if (event_count < 1 || strcmp(last_event, "vaultMounted") != 0) {
    fprintf(stderr, "expected vaultMounted event\n");
    return 1;
  }

  if (run_rpc(&core,
              "{\"jsonrpc\":\"2.0\",\"id\":3,\"method\":\"doc.write\",\"params\":{\"path\":\"notes/one.md\",\"content\":\"hello\\nworld\"}}",
              response,
              sizeof(response)) != 0) {
    return 1;
  }

  if (!contains(response, "\"written\":true")) {
    fprintf(stderr, "unexpected doc.write response: %s\n", response);
    return 1;
  }

  if (run_rpc(&core,
              "{\"jsonrpc\":\"2.0\",\"id\":4,\"method\":\"doc.read\",\"params\":{\"path\":\"notes/one.md\"}}",
              response,
              sizeof(response)) != 0) {
    return 1;
  }

  if (!contains(response, "\"path\":\"notes/one.md\"") ||
      !contains(response, "hello\\nworld")) {
    fprintf(stderr, "unexpected doc.read response: %s\n", response);
    return 1;
  }

  {
    char control_path[4096];
    unsigned char raw_content[32];
    FILE *fp;
    size_t i;

    snprintf(control_path, sizeof(control_path), "%s/notes/control.md", vault_dir);
    memcpy(raw_content, "controls:", 9);
    for (i = 9; i < sizeof(raw_content); i++) {
      raw_content[i] = 1;
    }

    fp = fopen(control_path, "wb");
    if (!fp) {
      fprintf(stderr, "failed to create control character fixture\n");
      return 1;
    }
    if (fwrite(raw_content, 1, sizeof(raw_content), fp) != sizeof(raw_content)) {
      fclose(fp);
      fprintf(stderr, "failed to write control character fixture\n");
      return 1;
    }
    fclose(fp);

    if (run_rpc(&core,
                "{\"jsonrpc\":\"2.0\",\"id\":404,\"method\":\"doc.read\",\"params\":{\"path\":\"notes/control.md\"}}",
                response,
                sizeof(response)) != 0) {
      return 1;
    }

    if (!contains(response, "\"content\":\"controls:\\u0001\\u0001\\u0001")) {
      fprintf(stderr, "doc.read failed to escape dense control characters: %s\n", response);
      return 1;
    }
  }

  {
    char nul_path[4096];
    unsigned char raw_content[] = {'b', 'e', 'f', 'o', 'r', 'e', 0, 'a', 'f', 't', 'e', 'r'};
    FILE *fp;

    snprintf(nul_path, sizeof(nul_path), "%s/notes/nul-existing.md", vault_dir);
    fp = fopen(nul_path, "wb");
    if (!fp) {
      fprintf(stderr, "failed to create existing NUL fixture\n");
      return 1;
    }
    if (fwrite(raw_content, 1, sizeof(raw_content), fp) != sizeof(raw_content)) {
      fclose(fp);
      fprintf(stderr, "failed to write existing NUL fixture\n");
      return 1;
    }
    fclose(fp);

    if (run_rpc(&core,
                "{\"jsonrpc\":\"2.0\",\"id\":405,\"method\":\"doc.read\",\"params\":{\"path\":\"notes/nul-existing.md\"}}",
                response,
                sizeof(response)) != 0) {
      return 1;
    }

    if (!contains(response, "\"content\":\"before\\u0000after\"")) {
      fprintf(stderr, "doc.read truncated existing NUL content: %s\n", response);
      return 1;
    }
  }

  if (run_rpc(&core,
              "{\"jsonrpc\":\"2.0\",\"id\":5,\"method\":\"doc.list\",\"params\":{\"path\":\"notes\"}}",
              response,
              sizeof(response)) != 0) {
    return 1;
  }

  if (!contains(response, "notes/one.md")) {
    fprintf(stderr, "unexpected doc.list response: %s\n", response);
    return 1;
  }

  {
    char link_path[4096];
    char outside_file[4096];
    char outside_link[4096];
    char req[4096];

    snprintf(link_path, sizeof(link_path), "%s/escape", vault_dir);
    snprintf(outside_file, sizeof(outside_file), "%s/pwned.md", outside_dir);
    if (symlink(outside_dir, link_path) != 0) {
      fprintf(stderr, "failed to create escape symlink\n");
      return 1;
    }

    if (run_rpc(&core,
                "{\"jsonrpc\":\"2.0\",\"id\":601,\"method\":\"doc.write\",\"params\":{\"path\":\"escape/pwned.md\",\"content\":\"outside\"}}",
                response,
                sizeof(response)) != 0) {
      return 1;
    }

    if (!contains(response, "\"error\"") || access(outside_file, F_OK) == 0) {
      fprintf(stderr, "doc.write escaped vault through symlink: %s\n", response);
      return 1;
    }

    snprintf(outside_file, sizeof(outside_file), "%s/secret.md", outside_dir);
    {
      FILE *fp = fopen(outside_file, "wb");
      if (!fp) {
        fprintf(stderr, "failed to create outside secret\n");
        return 1;
      }
      fputs("secret", fp);
      fclose(fp);
    }

    snprintf(outside_link, sizeof(outside_link), "%s/notes/outside-link.md", vault_dir);
    if (symlink(outside_file, outside_link) != 0) {
      fprintf(stderr, "failed to create outside file symlink\n");
      return 1;
    }

    if (run_rpc(&core,
                "{\"jsonrpc\":\"2.0\",\"id\":602,\"method\":\"doc.read\",\"params\":{\"path\":\"notes/outside-link.md\"}}",
                response,
                sizeof(response)) != 0) {
      return 1;
    }

    if (!contains(response, "\"error\"")) {
      fprintf(stderr, "doc.read escaped vault through symlink: %s\n", response);
      return 1;
    }

    snprintf(req,
             sizeof(req),
             "{\"jsonrpc\":\"2.0\",\"id\":603,\"method\":\"doc.list\",\"params\":{\"path\":\"notes\"}}");
    if (run_rpc(&core, req, response, sizeof(response)) != 0) {
      return 1;
    }

    if (contains(response, "outside-link.md")) {
      fprintf(stderr, "doc.list exposed symlinked outside doc: %s\n", response);
      return 1;
    }
  }

  if (run_rpc(&core,
              "{\"jsonrpc\":\"2.0\",\"id\":501,\"method\":\"doc.write\",\"params\":{\"path\":\"notes/out-of-scope.md\"},\"content\":\"not in params\"}",
              response,
              sizeof(response)) != 0) {
    return 1;
  }

  if (!contains(response, "\"error\"")) {
    fprintf(stderr, "doc.write accepted content outside params object: %s\n", response);
    return 1;
  }

  if (run_rpc(&core,
              "{\"jsonrpc\":\"2.0\",\"id\":502,\"method\":\"doc.write\",\"params\":{\"path\":\"notes/escapes.md\",\"content\":\"a\\bb\\fc\"}}",
              response,
              sizeof(response)) != 0) {
    return 1;
  }

  if (!contains(response, "\"written\":true")) {
    fprintf(stderr, "unexpected escape doc.write response: %s\n", response);
    return 1;
  }

  if (run_rpc(&core,
              "{\"jsonrpc\":\"2.0\",\"id\":503,\"method\":\"doc.read\",\"params\":{\"path\":\"notes/escapes.md\"}}",
              response,
              sizeof(response)) != 0) {
    return 1;
  }

  if (!contains(response, "a\\bb\\fc")) {
    fprintf(stderr, "doc.read did not preserve backspace/formfeed escapes: %s\n", response);
    return 1;
  }

  if (run_rpc(&core,
              "{\"jsonrpc\":\"2.0\",\"id\":504,\"method\":\"doc.write\",\"params\":{\"path\":\"notes/unicode.md\",\"content\":\"snowman=\\u2603\"}}",
              response,
              sizeof(response)) != 0) {
    return 1;
  }

  if (!contains(response, "\"written\":true")) {
    fprintf(stderr, "unexpected unicode doc.write response: %s\n", response);
    return 1;
  }

  if (run_rpc(&core,
              "{\"jsonrpc\":\"2.0\",\"id\":505,\"method\":\"doc.read\",\"params\":{\"path\":\"notes/unicode.md\"}}",
              response,
              sizeof(response)) != 0) {
    return 1;
  }

  if (!contains(response, "snowman=\xE2\x98\x83")) {
    fprintf(stderr, "doc.read did not decode unicode escape: %s\n", response);
    return 1;
  }

  if (run_rpc(&core,
              "{\"jsonrpc\":\"2.0\",\"id\":506,\"method\":\"doc.write\",\"params\":{\"path\":\"notes/surrogate.md\",\"content\":\"emoji=\\uD83D\\uDE00\"}}",
              response,
              sizeof(response)) != 0) {
    return 1;
  }

  if (!contains(response, "\"written\":true")) {
    fprintf(stderr, "unexpected surrogate doc.write response: %s\n", response);
    return 1;
  }

  if (run_rpc(&core,
              "{\"jsonrpc\":\"2.0\",\"id\":507,\"method\":\"doc.read\",\"params\":{\"path\":\"notes/surrogate.md\"}}",
              response,
              sizeof(response)) != 0) {
    return 1;
  }

  if (!contains(response, "emoji=\xF0\x9F\x98\x80")) {
    fprintf(stderr, "doc.read did not decode unicode surrogate pair: %s\n", response);
    return 1;
  }

  if (run_rpc(&core,
              "{\"jsonrpc\":\"2.0\",\"id\":508,\"method\":\"doc.write\",\"params\":{\"path\":\"notes/nul.md\",\"content\":\"bad\\u0000value\"}}",
              response,
              sizeof(response)) != 0) {
    return 1;
  }

  if (!contains(response, "\"error\"")) {
    fprintf(stderr, "doc.write accepted embedded NUL content: %s\n", response);
    return 1;
  }

  if (run_rpc(&core,
              "{\"jsonrpc\":\"2.0\",\"id\":509,\"method\":\"doc.write\",\"params\":{\"shadow\":{\"path\":\"notes/nested.md\",\"content\":\"nested content\"}}}",
              response,
              sizeof(response)) != 0) {
    return 1;
  }

  if (!contains(response, "\"error\"")) {
    fprintf(stderr, "doc.write accepted nested-only params.path/content: %s\n", response);
    return 1;
  }

  if (run_rpc(&core,
              "{\"jsonrpc\":\"2.0\",\"id\":510,\"method\":\"doc.write\",\"params\":{\"shadow\":{\"path\":\"notes/wrong.md\"},\"path\":\"notes/right.md\",\"content\":\"right content\"}}",
              response,
              sizeof(response)) != 0) {
    return 1;
  }

  if (!contains(response, "\"written\":true")) {
    fprintf(stderr, "unexpected nested shadow doc.write response: %s\n", response);
    return 1;
  }

  if (run_rpc(&core,
              "{\"jsonrpc\":\"2.0\",\"id\":511,\"method\":\"doc.read\",\"params\":{\"path\":\"notes/right.md\"}}",
              response,
              sizeof(response)) != 0) {
    return 1;
  }

  if (!contains(response, "right content")) {
    fprintf(stderr, "doc.write ignored top-level params.path after nested path: %s\n", response);
    return 1;
  }

  if (run_rpc(&core,
              "{\"jsonrpc\":\"2.0\",\"id\":512,\"method\":\"doc.read\",\"params\":{\"path\":\"notes/wrong.md\"}}",
              response,
              sizeof(response)) != 0) {
    return 1;
  }

  if (!contains(response, "\"error\"")) {
    fprintf(stderr, "doc.write used nested params.path before top-level path: %s\n", response);
    return 1;
  }

  if (run_rpc(&core,
              "{\"jsonrpc\":\"2.0\",\"id\":513,\"params\":{\"method\":\"core.ping\"}}",
              response,
              sizeof(response)) != 0) {
    return 1;
  }

  if (!contains(response, "\"error\"")) {
    fprintf(stderr, "rpc accepted method inside params without top-level method: %s\n", response);
    return 1;
  }

  if (run_rpc(&core,
              "{\"params\":{\"jsonrpc\":\"2.0\",\"method\":\"core.ping\"},\"id\":514}",
              response,
              sizeof(response)) != 0) {
    return 1;
  }

  if (!contains(response, "\"error\"")) {
    fprintf(stderr, "rpc accepted jsonrpc/method inside params without top-level fields: %s\n", response);
    return 1;
  }

  if (run_rpc(&core,
              "{\"jsonrpc\":\"2.0\",\"id\":6,\"method\":\"meta.set\",\"params\":{\"path\":\"notes/one.md\",\"key\":\"user.tag\",\"value\":\"alpha\"}}",
              response,
              sizeof(response)) != 0) {
    return 1;
  }

  if (!contains(response, "\"set\":true")) {
    fprintf(stderr, "unexpected meta.set response: %s\n", response);
    return 1;
  }

  if (run_rpc(&core,
              "{\"jsonrpc\":\"2.0\",\"id\":7,\"method\":\"meta.get\",\"params\":{\"path\":\"notes/one.md\",\"key\":\"user.tag\"}}",
              response,
              sizeof(response)) != 0) {
    return 1;
  }

  if (!contains(response, "\"found\":true") || !contains(response, "\"value\":\"alpha\"")) {
    fprintf(stderr, "unexpected meta.get(key) response: %s\n", response);
    return 1;
  }

  if (run_rpc(&core,
              "{\"jsonrpc\":\"2.0\",\"id\":8,\"method\":\"meta.get\",\"params\":{\"path\":\"notes/one.md\"}}",
              response,
              sizeof(response)) != 0) {
    return 1;
  }

  if (!contains(response, "\"xattrs\"") || !contains(response, "\"user.tag\":\"alpha\"")) {
    fprintf(stderr, "unexpected meta.get(all) response: %s\n", response);
    return 1;
  }

  if (run_rpc(&core,
              "{\"jsonrpc\":\"2.0\",\"id\":9,\"method\":\"meta.unset\",\"params\":{\"path\":\"notes/one.md\",\"key\":\"user.tag\"}}",
              response,
              sizeof(response)) != 0) {
    return 1;
  }

  if (!contains(response, "\"unset\":true")) {
    fprintf(stderr, "unexpected meta.unset response: %s\n", response);
    return 1;
  }

  if (run_rpc(&core,
              "{\"jsonrpc\":\"2.0\",\"id\":10,\"method\":\"meta.get\",\"params\":{\"path\":\"notes/one.md\",\"key\":\"user.tag\"}}",
              response,
              sizeof(response)) != 0) {
    return 1;
  }

  if (!contains(response, "\"found\":false")) {
    fprintf(stderr, "unexpected meta.get(after unset) response: %s\n", response);
    return 1;
  }

  if (run_rpc(&core,
              "{\"jsonrpc\":\"2.0\",\"id\":11,\"method\":\"txn.begin\"}",
              response,
              sizeof(response)) != 0) {
    return 1;
  }

  if (run_rpc(&core,
              "{\"jsonrpc\":\"2.0\",\"id\":12,\"method\":\"txn.commit\"}",
              response,
              sizeof(response)) != 0) {
    return 1;
  }

  if (!contains(response, "\"committed\":true")) {
    fprintf(stderr, "unexpected txn.commit response: %s\n", response);
    return 1;
  }

  if (strcmp(last_event, "txnCommitted") != 0) {
    fprintf(stderr, "expected txnCommitted event\n");
    return 1;
  }

  if (run_rpc(&core,
              "{\"jsonrpc\":\"2.0\",\"id\":13,\"method\":\"doc.delete\",\"params\":{\"path\":\"notes/one.md\"}}",
              response,
              sizeof(response)) != 0) {
    return 1;
  }

  if (!contains(response, "\"deleted\":true")) {
    fprintf(stderr, "unexpected doc.delete response: %s\n", response);
    return 1;
  }

  {
    char deleted_path[4096];
    snprintf(deleted_path, sizeof(deleted_path), "%s/notes/one.md", vault_dir);
    if (access(deleted_path, F_OK) == 0) {
      fprintf(stderr, "doc.delete did not remove file\n");
      return 1;
    }
  }

  {
    char doc_path[4096];
    snprintf(doc_path, sizeof(doc_path), "%s/notes/one.md", vault_dir);
    if (wizardry_sidecar_path(doc_path, sidecar_path, sizeof(sidecar_path)) != 0) {
      fprintf(stderr, "sidecar path failed\n");
      return 1;
    }

    if (!contains(sidecar_path, ".xattr.json")) {
      fprintf(stderr, "unexpected sidecar path: %s\n", sidecar_path);
      return 1;
    }
  }

  if (wizardry_core_shutdown(&core) != 0) {
    fprintf(stderr, "shutdown failed\n");
    return 1;
  }

  {
    char cleanup_cmd[4096];
    snprintf(cleanup_cmd, sizeof(cleanup_cmd), "rm -rf '%s'", vault_dir);
    (void)system(cleanup_cmd);
    snprintf(cleanup_cmd, sizeof(cleanup_cmd), "rm -rf '%s'", outside_dir);
    (void)system(cleanup_cmd);
  }

  printf("wizardry-core tests passed\n");
  return 0;
}
