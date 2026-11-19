# Architecture

This document describes the end-to-end architecture of **Ludo Royale** — the
layered design, the game engine, the online/offline execution modes, and the
database model. It is intended for contributors who need to understand how the
Flutter client, the PHP REST API, and the MySQL database fit together.

---

## 1. High-Level Overview

Ludo Royale is a **client–server** application with three independently
deployable components:

| Layer            | Technology                                | Responsibility |
|------------------|-------------------------------------------|----------------|
| **Client**       | Flutter (Dart) + Riverpod                 | UI, local game engine, offline persistence |
| **API Server**   | Core PHP (PDO, prepared statements)      | Auth, game orchestration, server-authoritative moves, wallet |
| **Database**     | MySQL 5.7+ / MariaDB 10.4+ (InnoDB)       | 15 normalized tables, FK constraints, JSON columns |

The client and server each ship a copy of the **same game engine logic**
(`GameEngine` class), so the same rules can run locally for offline play and
remotely for online play. The two implementations are intentionally kept in
sync — when you change rules in one, update the other.

---

## 2. Layered Architecture

```
┌──────────────────────────────────────────────────────────────────────┐
│                         FLUTTER APP (client)                         │
│                                                                      │
│   ┌────────────────────────────────────────────────────────────┐     │
│   │  UI Layer (Widgets & Screens)                              │     │
│   │  • LudoBoardPainter  • LudoDice  • LudoToken               │     │
│   │  • GameBoardScreen   • WalletScreen  • LeaderboardScreen   │     │
│   └─────────────────────────────┬──────────────────────────────┘     │
│                                 │                                    │
│   ┌─────────────────────────────▼──────────────────────────────┐     │
│   │  State Layer (Riverpod providers)                          │     │
│   │  • GameSessionController (ChangeNotifier)                  │     │
│   │  • Providers for auth, wallet, leaderboard                 │     │
│   └─────────────────────────────┬──────────────────────────────┘     │
│                                 │                                    │
│   ┌─────────────────────────────▼──────────────────────────────┐     │
│   │  Service Layer (Dart services)                             │     │
│   │  • AuthService      • OnlineGameService                    │     │
│   │  • WalletService    • LeaderboardService                   │     │
│   │  • RewardService    • HistoryService                       │     │
│   └─────────────────────────────┬──────────────────────────────┘     │
│                                 │                                    │
│   ┌─────────────────────────────▼──────────────────────────────┐     │
│   │  Domain Layer (engine, rules, entities)                    │     │
│   │  • GameEngine   • RuleValidator   • LudoAI                  │     │
│   │  • Board, Token, Player, Move, GameEvent, MatchStats       │     │
│   │  • GameStateSnapshot                                        │     │
│   └─────────────────────────────┬──────────────────────────────┘     │
│                                 │                                    │
│   ┌─────────────────────────────▼──────────────────────────────┐     │
│   │  Data Layer (HTTP + SQLite)                               │     │
│   │  • ApiClient (http)  → JSON REST                            │     │
│   │  • LocalDatabase (sqflite) → snapshots                     │     │
│   │  • AppConfig (shared_preferences)                          │     │
│   └────────────────────────────────────────────────────────────┘     │
└─────────────────────────────────┬────────────────────────────────────┘
                                  │  HTTPS / HTTP (JSON)
                                  ▼
┌──────────────────────────────────────────────────────────────────────┐
│                          PHP BACKEND                                 │
│                                                                      │
│   ┌────────────────────────────────────────────────────────────┐     │
│   │  public/index.php  (front controller + router)             │     │
│   │  • scans routes/*.php  • CORS  • AuthMiddleware             │     │
│   └─────────────────────────────┬──────────────────────────────┘     │
│                                 │                                    │
│   ┌─────────────────────────────▼──────────────────────────────┐     │
│   │  Route handlers (routes/*.php)                             │     │
│   │  auth, profile, game, multiplayer, leaderboard,             │     │
│   │  rewards, history, wallet                                   │     │
│   └─────────────────────────────┬──────────────────────────────┘     │
│                                 │                                    │
│   ┌─────────────────────────────▼──────────────────────────────┐     │
│   │  Services (business logic)                                 │     │
│   │  • AuthService     • GameService    • WalletService         │     │
│   │  • RewardService   • MultiplayerService                     │     │
│   │  • DiceService (random_int)         • GameEngine (rules)    │     │
│   └─────────────────────────────┬──────────────────────────────┘     │
│                                 │                                    │
│   ┌─────────────────────────────▼──────────────────────────────┐     │
│   │  Data Access (PDO prepared statements)                      │     │
│   │  Database::connection() (singleton)                         │     │
│   └─────────────────────────────┬──────────────────────────────┘     │
└─────────────────────────────────┬────────────────────────────────────┘
                                  │  SQL (InnoDB, utf8mb4)
                                  ▼
┌──────────────────────────────────────────────────────────────────────┐
│                          MySQL DATABASE                              │
│   15 normalized tables with FK constraints, JSON columns,           │
│   append-only ledger, unique per-day reward claim constraint.        │
└──────────────────────────────────────────────────────────────────────┘
```

### 2.1 Layer responsibilities

* **UI Layer** renders the board, dice and tokens and forwards user input
  (tap-to-roll, tap-to-move) to the controller.
* **State Layer** holds the reactive game session via Riverpod's
  `ChangeNotifierProvider.family`. UI never mutates engine state directly.
* **Service Layer** is the boundary for all REST calls; each service wraps
  an `ApiClient` and returns typed Dart models.
* **Domain Layer** contains the pure game engine — no Flutter, no HTTP.
  This makes it unit-testable in isolation.
* **Data Layer** handles raw transport: `http` for online,
  `sqflite` for offline persistence, `shared_preferences` for config.
* **Backend Services** encapsulate all write logic. Routes are thin
  handlers that validate input, delegate to a service, and format JSON.
* **Database** is the single source of truth for users, matches, wallets,
  and reward ladders.

---

## 3. Game Engine Design

The `GameEngine` is **UI-independent** and exists in two parallel
implementations:

* `flutter_app/lib/features/game/domain/engine/game_engine.dart` (Dart)
* `backend/services/GameEngine.php` (PHP)

Both expose the same logical operations:

| Operation                    | Dart                                | PHP                          |
|------------------------------|-------------------------------------|------------------------------|
| Initial token state          | `Player._initialTokens`             | `GameEngine::initialState`  |
| List legal moves            | `RuleValidator.getValidMoves`      | `GameEngine::getValidMoves` |
| Apply a move                | `GameEngine.moveToken`              | `GameEngine::applyMove`     |
| Detect capture             | `RuleValidator.checkCapture`        | `GameEngine::checkCapture`  |
| Win detection              | `RuleValidator.checkWin`            | `GameEngine::checkWin`       |
| Turn rotation             | `PlayerColor.next(active)`          | `GameEngine::nextSeat`      |

### 3.1 Core entities

All entities live under `flutter_app/lib/features/game/domain/entities/`.

| Entity              | File                       | Purpose |
|---------------------|----------------------------|---------|
| `PlayerColor`       | `player_color.dart`        | Enum `red | green | yellow | blue`, seat index helpers |
| `Token`             | `token.dart`               | A single token: `position = -1` (base), `0..51` (outer), `52..56` (home path), `57` (home) |
| `Player`            | `player.dart`              | Color + 4 tokens + `isAI`, `aiLevel`, `finalRank`, `captures` |
| `Board`             | `board.dart`               | Static geometry — 52-cell outer track, 6-cell home paths, safe cells, start positions |
| `Move`              | `move.dart`                | Describes one legal move + whether it captures |
| `GameEvent`         | `game_event.dart`          | Audit / animation event (`diceRolled`, `capture`, `win`, …) |
| `MatchStats`        | `match_stats.dart`         | Aggregates: turns, captures, sixes/ones rolled, winner |
| `GameStateSnapshot` | `game_state_snapshot.dart` | Serializable full state for save/restore & client↔server sync |

### 3.2 Rule centralisation

All rule checks live in `RuleValidator` (Dart) and the static methods on
`GameEngine` (PHP). The UI **never** decides whether a move is legal — it
calls `getValidMoves()` and only highlights tokens whose index appears in the
returned list. This makes cheating via a modified client impossible in
online mode (the server rejects any move it didn't validate).

Rules enforced:

* Roll a **6** to leave base (`Token.position == -1` requires `dice == 6`).
* Tokens turn into the colored **home path** after passing the color's
  `homeEntry` index on the 52-cell loop.
* A token reaching exactly `57` is **home**; overshooting is illegal.
* **Safe cells** `[0, 8, 13, 21, 26, 34, 39, 47]` and the entire home path
  cannot be captured.
* **Capture**: landing on a single opponent token sends it back to base.
  Two opponent tokens on the same cell form a **block** and cannot be
  captured.
* **Extra turn** is granted on a dice value of `6` or on a capture.
* **Three consecutive sixes** forfeit the turn (`threeSixesForfeit` event).
* **Win** = all 4 tokens of a color are at position `57`.

---

## 4. Server-Authoritative Online Mode

Online matches are **server-authoritative**. The client never rolls dice or
decides moves; it only forwards requests and renders server state.

### 4.1 Turn lifecycle

```
Client (Flutter)                 Server (PHP)                    Database
─────────────────                ───────────────────             ──────────
POST /game/roll-dice   ────────► GameService::rollDice
                                 ├─ SELECT FOR UPDATE matches
                                 ├─ verify seat == current_player
                                 ├─ DiceService::roll() (random_int)
                                 ├─ GameEngine::getValidMoves()
                                 ├─ UPDATE game_states SET dice_value, phase
                                 ├─ INSERT INTO game_moves (type='roll')
                                 └─ handle 3-sixes forfeit ◄────
                                              │
   { dice, valid_moves, six_counter }  ◄──────┘
        │
        │ user picks a token
        ▼
POST /game/move-token  ────────► GameService::moveToken
                                 ├─ SELECT FOR UPDATE matches + game_states
                                 ├─ GameEngine::applyMove()  (validates again)
                                 ├─ detect capture → reset opponent tokens
                                 ├─ UPDATE game_states.tokens_json
                                 ├─ INSERT INTO game_moves (type='move'|'capture')
                                 ├─ if win → mark final_rank, maybe finishMatch
                                 └─ advanceTurn (extra turn or next seat)
                                              │
   { match, state, players }     ◄────────────┘
```

### 4.2 Polling model

There is no WebSocket in this release. The client polls
`GET /game/state?match_id=...` **every 1.5 seconds** while a match is
active. Each poll returns the full match payload (players, tokens JSON,
phase, dice value, current player) so the UI can render the opponent's
move as soon as it lands.

The `GameSessionController.applyServerState()` method replaces the local
engine's state with the server's authoritative snapshot, keeping animation
state (`displayDice`, `movableTokenIndices`) in sync.

### 4.3 Concurrency safety

All mutating endpoints open a transaction and lock the relevant rows
with `SELECT ... FOR UPDATE` on both `matches` and `game_states`. This
serialises concurrent requests from different players and prevents
race conditions on the dice value and turn rotation.

---

## 5. Offline & Local Modes

The same `GameEngine` runs locally for offline games. Modes supported:

| Mode            | Config enum     | Description |
|-----------------|-----------------|-------------|
| Play with Computer | `GameMode.offlineAI` | 1 human vs 1–3 AI bots |
| Local Multiplayer  | `GameMode.local`     | 2–4 humans share one device |
| Quick Match (offline) | `GameMode.quick`  | Same engine, faster UI |

### 5.1 Persistence

After every move, `GameSessionController._persist()` calls
`LocalDatabase.saveMatchSnapshot()` which writes a JSON snapshot of the
`GameStateSnapshot` into the SQLite table `local_matches`. This lets the
app restore unfinished matches on the next launch
(`LocalDatabase.loadUnfinishedMatches()`).

Three local tables exist:

```sql
local_matches(match_id TEXT PRIMARY KEY, mode, status, snapshot_json, created_at, updated_at)
local_history(id INTEGER PK, match_id, mode, winner, player_count, total_turns, ...)
cache_kv(k TEXT PRIMARY KEY, v, updated_at)
```

### 5.2 AI auto-play

When it is an AI player's turn (`Player.isAI == true`), the controller
schedules `rollDice()` after 700 ms, then `_aiMove()` after the dice lands.
`LudoAI.chooseMove()` picks a token index using one of three strategies:

* **easy** — uniformly random over legal moves.
* **medium** — prefers captures → releasing tokens from base → most advanced token.
* **hard** — adds look-ahead: prefers home-path entries, safe cells, and
  avoids landing within 6 cells of an opponent.

---

## 6. Database Design

15 normalized tables, all InnoDB + `utf8mb4_unicode_ci`. See
[`database-design.md`](./database-design.md) for the full field reference.
Key design decisions:

1. **Separation of concerns** — `users` (auth), `user_profiles` (display),
   `player_stats` (aggregates), `wallets` (balance) are kept separate so
   writes to one don't lock the others.
2. **Append-only ledger** — `wallet_transactions` records every coin/gem
   movement with `balance_after` so the wallet state is fully auditable.
3. **JSON columns for flex fields** — `game_states.tokens_json`,
   `game_moves.extra_data`, `game_history.players_json`,
   `notifications.extra` all use native MySQL `JSON` type.
4. **Unique constraints** prevent double-claiming rewards
   (`uniq_user_claim_day`) and duplicate seats in a match
   (`uniq_match_seat`, `uniq_match_color`).
5. **Cascading deletes** — every FK is `ON DELETE CASCADE` (except
   `winner_id` references which are `SET NULL`) so deleting a user
   cleans up their matches, stats, wallet, and notifications atomically.

---

## 7. Authentication & Security

* Passwords hashed with `password_hash()` using `PASSWORD_BCRYPT`
  (cost 10). Plaintext passwords are **never** stored.
* On login/register the server issues a 64-char hex token
  (`gen_token(64)` using `random_bytes`) and stores it in
  `users.auth_token` with a 24-hour expiry (`token_expires`).
* The Flutter client persists the token in `shared_preferences` and sends
  it as `Authorization: Bearer <token>` on every request via `ApiClient`.
* `AuthMiddleware::requireUser()` loads the user from the token and
  rejects (HTTP 401) if the token is missing, expired, or the user is
  banned.
* **Rate limiting** is provided by `RateLimit::check()` (default 120
  requests / 60s), backed by a file cache. For production, swap in Redis
  or APCu.
* **CORS** is configured in `config/cors.php` — the default
  `allowed_origins = ['*']` is permissive for development; restrict in
  production.
* **PDO prepared statements** are used everywhere (`prepare()` +
  `execute()` with named parameters); `PDO::ATTR_EMULATE_PREPARES` is
  `false` to guarantee real server-side prepared statements.

---

## 8. Routing

The PHP front controller (`public/index.php`) scans every file in
`backend/routes/` and merges them into one big `["METHOD /path" => handler]`
array. Path parameters use `{name}` placeholders and are exposed via
`$GLOBALS['route_params']`. There is no external router dependency — the
dispatcher is ~80 lines of vanilla PHP.

On the Flutter side, `go_router` (`app_router.dart`) defines all screens
and guards. Public routes (`/splash`, `/login`, `/register`, `/forgot`,
`/reset`, `/onboarding`) are accessible without auth; everything else
redirects to `/login` if `AppConfig.isLoggedIn` is false.

---

## 9. Cross-Cutting Concerns

### 9.1 Error format

All errors use the same JSON shape:

```json
{
  "success": false,
  "message": "Invalid credentials.",
  "errors": { "password": ["password must be at least 6 characters."] }
}
```

The `errors` object is optional and only present when field-level
validation messages exist (produced by `Validator`).

### 9.2 Logging

`log_event($channel, $message, $context)` writes JSON-encoded lines to
`backend/storage/logs/app-YYYY-MM-DD.log`. The file-based rate limiter
also writes to that directory.

### 9.3 Theming & UX

* `flutter_app/lib/core/theme/app_theme.dart` provides the dark,
  gradient-heavy Material 3 theme.
* `flutter_animate` powers dice & token transitions.
* `confetti` fires on win; `vibration` provides haptic feedback on
  captures and rolls; `audioplayers` plays SFX.

---

## 10. Deployment Topology

```
┌─────────────────────────────┐         ┌──────────────────────────┐
│  Mobile / Web client        │         │  PHP CLI server          │
│  (Flutter)                  │ ◄─────► │  php -S 0.0.0.0:8000     │
│                             │  JSON   │  -t public               │
└─────────────────────────────┘         │                          │
                                        │  Or: XAMPP htdocs/       │
                                        │  ludo-royale-backend/    │
                                        └────────────┬─────────────┘
                                                     │ PDO
                                                     ▼
                                        ┌──────────────────────────┐
                                        │  MySQL / MariaDB         │
                                        │  database: ludo_royale   │
                                        └──────────────────────────┘
```

* **Local dev (Android emulator)**: client → `http://10.0.2.2:8000`
  (the emulator's alias for the host machine's `localhost`).
* **Local dev (web)**: client → `http://localhost:8000`.
* **Physical device**: client → `http://<LAN-IP>:8000`
  (e.g. `http://192.168.1.5:8000`). Both device and dev machine must be
  on the same Wi-Fi.

---

## 11. Related Documents

* [Database Design](./database-design.md) — full table-by-table reference.
* [API Documentation](./api-documentation.md) — every endpoint with
  sample request/response payloads.
* [Installation Guide](./installation-guide.md) — step-by-step setup
  from clone to running app.
