# Development room server

Run from the project root with `.\tool.ps1 server` on Windows, or `dart server/main.dart` using an installed Dart SDK and this project's package configuration.

Environment variables: `HOST` defaults to `127.0.0.1`; `PORT` defaults to `8787`.

Endpoints:

- `GET /health`
- `POST /rooms` with `{ "players": 2 }`
- `POST /rooms/CODE/join` with `{}`
- `GET /rooms/CODE`
- `POST /rooms/CODE/moves` with `{ "move": "h:0:0", "revision": 1 }`
- `POST /rooms/CODE/restart` with `{ "revision": 25 }`

Create/join returns a private session token. Authenticated endpoints require `Authorization: Bearer TOKEN`. Never share or log the token. Room codes can be shared with invited players.

This is a local prototype: in-memory rooms, no account system, one-second client polling, permissive development CORS, and no distributed storage or production rate limiting. Use TLS and add operational protections before exposing this server publicly.
