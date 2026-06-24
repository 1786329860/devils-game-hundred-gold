# Dedicated Multiplayer Server

The online mode uses a server-authoritative two-player WebSocket service.

- Public matchmaking and six-character private room codes.
- Guest identity with a cryptographically random resume token.
- Two-phase sealed turns: intent, insight, optional reading/revision, final lock.
- All hands, diamonds, contracts, gold, penalties, amnesia, and outcomes are validated server-side.
- Ninety-second reconnect window followed by an automatic forfeit.
- SQLite WAL persistence for player and completed-match records.
- Docker health check and bounded JSON logs.

Production endpoint: `wss://tucao.aixiaolv.icu/ws`  
Health endpoint: `https://tucao.aixiaolv.icu/health`

## 1.1.1 Hotfix

Fixes a server-side disconnect during online round resolution when a player wins
the round. The online winner code now uses player indexes (`0` and `1`) while
keeping draw as `3` for Godot UI compatibility.

Deployment files intentionally contain no server credentials. `tools/server_admin.py`
reads SSH credentials from environment variables.
