#include "wizardry_core.h"

#include <stdio.h>
#include <string.h>

int main(void) {
  wizardry_core core;
  char request[16384];
  char response[32768];

  if (wizardry_core_init(&core) != 0) {
    fprintf(stderr, "rpc_session: core init failed\n");
    return 1;
  }

  while (fgets(request, sizeof(request), stdin) != NULL) {
    size_t len = strlen(request);
    if (len > 0 && request[len - 1] == '\n') {
      request[len - 1] = '\0';
    }

    if (request[0] == '\0') {
      continue;
    }

    if (wizardry_core_rpc(&core, request, response, sizeof(response)) != 0) {
      fprintf(stderr, "rpc_session: rpc call failed\n");
      wizardry_core_shutdown(&core);
      return 1;
    }

    puts(response);
  }

  if (wizardry_core_shutdown(&core) != 0) {
    fprintf(stderr, "rpc_session: core shutdown failed\n");
    return 1;
  }

  return 0;
}
