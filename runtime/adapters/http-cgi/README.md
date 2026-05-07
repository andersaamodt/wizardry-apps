# HTTP CGI Adapter

This adapter maps hosted web requests to the same JSON-RPC core surface used by desktop/mobile bridges.

## Endpoints

- `POST /cgi/wizardry-core-api` for JSON-RPC calls
- `GET /cgi/wizardry-core-api?stream=events` for SSE events

## Notes

- Hosted web remains shell-reference semantics first in v1.
- HTTP is treated as adapter transport, not canonical API contract.
