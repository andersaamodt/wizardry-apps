#ifndef WIZARDRY_CORE_H
#define WIZARDRY_CORE_H

#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

#define WIZARDRY_CORE_PATH_MAX 1024

typedef void (*wizardry_event_callback)(const char *event_name, const char *json_payload, void *user_data);

typedef struct wizardry_core {
  char mounted_vault[WIZARDRY_CORE_PATH_MAX];
  int tx_open;
  unsigned long tx_id;
  unsigned long event_seq;
  wizardry_event_callback event_cb;
  void *event_user_data;
} wizardry_core;

int wizardry_core_init(wizardry_core *core);
int wizardry_core_shutdown(wizardry_core *core);
int wizardry_core_mount_vault(wizardry_core *core, const char *path);
int wizardry_core_subscribe(wizardry_core *core, wizardry_event_callback cb, void *user_data);
int wizardry_core_unsubscribe(wizardry_core *core);

/*
 * Handles JSON-RPC 2.0 requests for v1 methods:
 * core.ping, vault.mount, vault.info, doc.list, doc.read, doc.write,
 * doc.delete, meta.get, meta.set, meta.unset, txn.begin, txn.commit, txn.rollback
 */
int wizardry_core_rpc(wizardry_core *core,
                      const char *request_json,
                      char *response_json,
                      size_t response_size);

/* Sidecar helpers for platforms without xattrs. */
int wizardry_sidecar_path(const char *doc_path, char *sidecar_path, size_t sidecar_path_size);
int wizardry_sidecar_read(const char *doc_path, char *json_buf, size_t json_buf_size, size_t *json_len);
int wizardry_sidecar_write(const char *doc_path, const char *json_buf, size_t json_len);

#ifdef __cplusplus
}
#endif

#endif
