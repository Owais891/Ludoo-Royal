# API Documentation

The Ludo Royale backend exposes a JSON REST API served by a single-file
PHP front controller (`backend/public/index.php`). All endpoints are
stateless — authentication is via a Bearer token returned by `/auth/login`
or `/auth/register`.

---

## 1. Conventions

### Base URL

| Environment            | Base URL                       |
|------------------------|--------------------------------|
| Android emulator       | `http://10.0.2.2:8000`        |
| Web (Chrome)           | `http://localhost:8000`        |
| Physical device (LAN)  | `http://192.168.1.5:8000`      |
| Production             | `https://api.ludoroyale.com`   |

The base URL is stored in `AppConfig.apiBaseUrl` (SharedPreferences) and
is editable from the in-app Settings screen.

### Authentication header

All endpoints **except** `/auth/register`, `/auth/login`,
`/auth/forgot-password`, and `/auth/reset-password` require:

```
Authorization: Bearer <token>
Content-Type: application/json
Accept: application/json
```

Tokens are 64-character hex strings issued on login/register and are
valid for 24 hours (`token_expires`).

### Standard response envelope

**Success** (any 2xx status):

```json
{
  "success": true,
  "message": "OK",
  "data": { /* payload */ }
}
```

**Error** (4xx / 5xx):

```json
{
  "success": false,
  "message": "Invalid credentials.",
  "errors": {
    "password": ["password must be at least 6 characters."]
  }
}
```

The `errors` object is omitted when there are no field-level errors.

### HTTP status codes used

| Code | Meaning                            |
|------|------------------------------------|
| 200  | OK                                  |
| 201  | Created (register, create match)   |
| 204  | No Content (OPTIONS preflight)     |
| 400  | Bad request (wrong state, etc.)    |
| 401  | Unauthorized (missing/expired token)|
| 403  | Forbidden (not your turn, banned)   |
| 404  | Not Found (match/room/user)        |
| 409  | Conflict (duplicate, already joined)|
| 422  | Validation failed                  |
| 429  | Rate limited (default 120/min)     |
| 500  | Server error                       |

### CORS

CORS is enabled for all origins by default (`allowed_origins = ['*']`).
Preflight `OPTIONS` requests return `204 No Content` automatically. The
allowed methods are `GET, POST, PUT, DELETE, OPTIONS`. Allowed headers:
`Content-Type, Authorization, X-Requested-With`.

---

## 2. Authentication Flow

```
1. POST /auth/register (or /auth/login)
   ↓
   Response: { data: { user: {...}, token: "abcdef..." } }

2. Store token in SharedPreferences (AppConfig.authToken)

3. Subsequent requests include:
   Authorization: Bearer abcdef...

4. POST /auth/logout
   ↓
   Server clears auth_token; client clears local state.
```

The Flutter `ApiClient` automatically injects the bearer header from
`AppConfig.authToken`. If the server returns 401, the app's router will
redirect to `/login` on the next navigation.

---

## 3. Endpoints by Module

### 3.1 Auth

#### POST /auth/register

Create a new account. Also creates the linked `user_profiles`,
`player_stats`, and `wallets` rows in a transaction.

**Request body**
```json
{
  "full_name": "Ada Lovelace",
  "username": "ada",
  "email": "ada@example.com",
  "password": "secret123",
  "confirm_password": "secret123"
}
```

**Validation rules**
- `full_name` required, ≤ 100 chars
- `username` required, 3–50 chars, unique
- `email` required, valid email, unique
- `password` ≥ 6 chars, must match `confirm_password`

**Response 201**
```json
{
  "success": true,
  "message": "Registration successful",
  "data": {
    "user": {
      "id": 12,
      "full_name": "Ada Lovelace",
      "username": "ada",
      "email": "ada@example.com",
      "avatar_url": null,
      "player_level": 1,
      "experience": 0,
      "total_matches": 0,
      "total_wins": 0,
      "total_losses": 0,
      "total_captures": 0,
      "coins": 500,
      "gems": 10,
      "win_rate": 0.0
    },
    "token": "9f3c1b8a4d2e5f7c8b1a2d3e4f5c6b7a8d9e0f1c2b3a4d5e6f7c8b9a0d1e2f3c"
  }
}
```

**Errors** — `409` username/email already exists; `422` validation failed.

---

#### POST /auth/login

Authenticate by username **or** email. Returns a fresh token.

**Request body**
```json
{
  "login": "ada",
  "password": "secret123"
}
```

**Response 200**
```json
{
  "success": true,
  "message": "Login successful",
  "data": {
    "user": { "id": 12, "username": "ada", "..." : "..." },
    "token": "9f3c1b8a4d2e5f7c8b1a2d3e4f5c6b7a8d9e0f1c2b3a4d5e6f7c8b9a0d1e2f3c"
  }
}
```

**Errors** — `401` invalid credentials; `403` account banned.

---

#### POST /auth/logout  🔒

Invalidates the current token. No request body required.

**Response 200**
```json
{ "success": true, "message": "Logged out", "data": null }
```

---

#### POST /auth/forgot-password

Trigger a password reset. Always returns `sent` regardless of whether
the email exists (to prevent email enumeration). In development the
`reset_token` is returned in the response for testing convenience.

**Request body**
```json
{ "email": "ada@example.com" }
```

**Response 200**
```json
{
  "success": true,
  "message": "Reset email sent",
  "data": {
    "status": "sent",
    "reset_token": "a1b2c3d4e5f6..."
  }
}
```

---

#### POST /auth/reset-password

Reset the password using a token from `/auth/forgot-password`. Tokens
expire after 1 hour.

**Request body**
```json
{
  "token": "a1b2c3d4e5f6...",
  "password": "newpassword123"
}
```

**Response 200**
```json
{ "success": true, "message": "Password reset successful", "data": null }
```

**Errors** — `400` invalid/expired token; `422` password < 6 chars.

---

### 3.2 Profile

#### GET /profile  🔒

Returns the current user's full profile (auth user + profile + stats +
wallet).

**Response 200**
```json
{
  "success": true,
  "message": "OK",
  "data": {
    "id": 12,
    "full_name": "Ada Lovelace",
    "username": "ada",
    "email": "ada@example.com",
    "avatar_url": null,
    "is_online": true,
    "last_login_at": "2025-01-15 14:32:11",
    "player_level": 7,
    "experience": 1240,
    "country_code": "GB",
    "bio": "Ludo enthusiast.",
    "total_matches": 42,
    "total_wins": 28,
    "total_losses": 14,
    "total_captures": 73,
    "coins": 1850,
    "gems": 22,
    "win_rate": 66.67
  }
}
```

---

#### PUT /profile/update  🔒

Updates the user's display fields. All fields are optional — only
provided fields are touched.

**Request body** (any subset of)
```json
{
  "full_name": "Ada Lovelace-Smith",
  "avatar_url": "https://cdn.example.com/ada.png",
  "country_code": "GB",
  "bio": "Now playing Ludo Royale daily."
}
```

**Validation rules**
- `full_name` ≤ 100
- `avatar_url` ≤ 255
- `country_code` ≤ 5
- `bio` ≤ 255

**Response 200** — same shape as `GET /profile`.

---

### 3.3 Game (online matches)

All game endpoints require authentication. Match operations use
`SELECT ... FOR UPDATE` to serialise concurrent requests.

#### POST /game/create  🔒

Create a new match. The caller becomes seat 0 (red) and is automatically
marked `is_ready = 1`.

**Request body**
```json
{
  "mode": "classic",
  "max_players": 4,
  "entry_fee": 50
}
```

| Param         | Type | Required | Notes |
|---------------|------|----------|-------|
| `mode`        | string | no  | One of `classic`, `quick`, `private`, `offline_ai`, `local` (default `classic`) |
| `max_players` | int    | no  | 2..4, default 4 |
| `entry_fee`   | int    | no  | Default 0 |

**Response 201** — full match payload (see `GET /game/state`).

---

#### POST /game/join  🔒

Join an existing match by ID. Seat/color is assigned automatically.

**Request body**
```json
{ "match_id": 42 }
```

**Response 200** — full match payload.

**Errors** — `404` not found; `400` match full / not joinable; `409` already joined.

---

#### POST /game/roll-dice  🔒

Server-authoritative dice roll. The server generates the dice value with
`random_int(1, 6)`, validates the player is the current seat, persists
the dice to `game_states.dice_value`, and returns the list of legal
token indices the player can move.

**Request body**
```json
{ "match_id": 42 }
```

**Response 200**
```json
{
  "success": true,
  "message": "OK",
  "data": {
    "dice": 6,
    "six_counter": 1,
    "valid_moves": [0, 2],
    "forfeit": false
  }
}
```

If the player rolls three sixes in a row, the turn is forfeited:

```json
{
  "data": {
    "dice": 6,
    "six_counter": 3,
    "valid_moves": [],
    "forfeit": true,
    "reason": "Three consecutive sixes - turn forfeited."
  }
}
```

**Errors** — `400` match not active / cannot roll now; `403` not your turn / not in match.

---

#### POST /game/move-token  🔒

Apply a token move. The server re-validates legality and detects captures,
extra turns, and wins.

**Request body**
```json
{
  "match_id": 42,
  "token_index": 0
}
```

**Response 200** — full match payload (see `GET /game/state`).

**Errors** — `400` no move pending / illegal move; `403` not your turn.

---

#### GET /game/state  🔒

Fetch the full authoritative match state. The Flutter client polls
this every 1.5s during an active online match.

**Query params**

| Param       | Type | Required |
|-------------|------|----------|
| `match_id`  | int  | yes      |

**Response 200**
```json
{
  "success": true,
  "message": "OK",
  "data": {
    "id": 42,
    "code": "ABCD1234",
    "mode": "classic",
    "max_players": 4,
    "status": "active",
    "winner_id": null,
    "host_id": 12,
    "entry_fee": 50,
    "prize_pool": 200,
    "turn_number": 7,
    "current_player": 1,
    "six_counter": 0,
    "started_at": "2025-01-15 14:35:00",
    "finished_at": null,
    "players": [
      {
        "id": 101,
        "match_id": 42,
        "user_id": 12,
        "player_color": "red",
        "seat": 0,
        "is_ai": 0,
        "is_ready": 1,
        "is_connected": 1,
        "final_rank": null,
        "captures": 2,
        "username": "ada",
        "avatar_url": null
      }
    ],
    "state": {
      "match_id": 42,
      "current_player": 1,
      "dice_value": null,
      "phase": "rolling",
      "turn_number": 7,
      "six_counter": 0,
      "tokens_json": {
        "red":    [0, -1, 5, 57],
        "green":  [-1, -1, -1, -1],
        "yellow": [13, -1, -1, -1],
        "blue":   [-1, -1, -1, -1]
      },
      "version": 14,
      "updated_at": "2025-01-15 14:36:42"
    }
  }
}
```

---

#### POST /game/pause  🔒

Host-only. Sets match status to `paused`. Other players cannot roll.

**Request body**
```json
{ "match_id": 42 }
```

---

#### POST /game/resume  🔒

Host-only. Sets match status back to `active`.

**Request body**
```json
{ "match_id": 42 }
```

---

#### POST /game/finish  🔒

Force-finish a match (used when only one player remains). Writes the
`game_history` row, updates player stats, and credits the winner's wallet
with `prize_pool` coins.

**Request body**
```json
{ "match_id": 42 }
```

---

### 3.4 Multiplayer (private rooms)

Private rooms are a thin wrapper around a `matches` row with a 6-char
shareable code.

#### POST /multiplayer/create-room  🔒

Create a new private room. Underlying match is created with status
`waiting`.

**Request body**
```json
{
  "mode": "classic",
  "max_players": 4
}
```

**Response 201**
```json
{
  "success": true,
  "message": "Room created",
  "data": {
    "id": 7,
    "room_code": "K7PQ9X",
    "host_id": 12,
    "max_players": 4,
    "mode": "classic",
    "status": "open",
    "match_id": 42,
    "match_status": "waiting",
    "participants": [
      { "seat": 0, "player_color": "red", "is_ready": 1,
        "user_id": 12, "username": "ada", "avatar_url": null }
    ]
  }
}
```

---

#### POST /multiplayer/join-room  🔒

**Request body**
```json
{ "room_code": "K7PQ9X" }
```

`room_code` is case-insensitive (server uppercases it). Min length 4.

**Response 200** — same shape as `create-room`.

**Errors** — `404` room not found; `400` room no longer open / full.

---

#### GET /multiplayer/room-status  🔒

Poll the room's participants and underlying match status. Used by the
lobby screen to detect when the host starts the match.

**Query params**

| Param        | Type   | Required |
|--------------|--------|----------|
| `room_code`  | string | yes      |

**Response 200** — same shape as `create-room`, with updated participants.

---

#### POST /multiplayer/leave-room  🔒

Removes the calling user from the room's match. The host is **not**
transferred — leaving as the host closes the room implicitly on the
next status check.

**Request body**
```json
{ "room_code": "K7PQ9X" }
```

**Response 200**
```json
{ "success": true, "message": "OK", "data": { "left": true } }
```

---

### 3.5 Leaderboard

#### GET /leaderboard  🔒

Returns top players ranked by `total_wins DESC, win_rate DESC, total_captures DESC`.
Banned users are excluded.

**Query params**

| Param    | Type | Default | Notes |
|----------|------|---------|-------|
| `limit`  | int  | 100     | Clamped to 5..500 |

**Response 200**
```json
{
  "success": true,
  "message": "OK",
  "data": {
    "players": [
      {
        "id": 12,
        "username": "ada",
        "avatar_url": null,
        "total_matches": 42,
        "total_wins": 28,
        "total_losses": 14,
        "total_captures": 73,
        "player_level": 7,
        "win_rate": 66.67
      }
    ]
  }
}
```

---

### 3.6 Rewards

#### GET /rewards/daily  🔒

Returns the current daily-reward status for the authenticated user and
the 30 most recent claims.

**Response 200**
```json
{
  "success": true,
  "message": "OK",
  "data": {
    "status": {
      "claimed_today": false,
      "current_streak": 2,
      "next_streak": 3,
      "next_reward": { "day": 3, "reward_type": "gem", "amount": 2, "is_active": 1 },
      "can_claim": true
    },
    "history": [
      { "id": 88, "user_id": 12, "claim_date": "2025-01-14",
        "streak_day": 2, "reward_type": "coin", "amount": 200 }
    ]
  }
}
```

---

#### POST /rewards/claim  🔒

Claim today's reward. The unique constraint `uniq_user_claim_day` makes
double-claiming impossible — a second call returns `409`.

**Response 200**
```json
{
  "success": true,
  "message": "Reward claimed",
  "data": {
    "claimed": true,
    "streak": 3,
    "reward": { "day": 3, "reward_type": "gem", "amount": 2, "is_active": 1 },
    "balance": { "coins": 1850, "gems": 24 }
  }
}
```

**Errors** — `409` already claimed today.

---

### 3.7 History

#### GET /history  🔒

Returns matches the current user has participated in (finished or
abandoned).

**Query params**

| Param    | Type | Default | Notes |
|----------|------|---------|-------|
| `limit`  | int  | 50      | Clamped to 5..200 |

**Response 200**
```json
{
  "success": true,
  "message": "OK",
  "data": {
    "history": [
      {
        "id": 14,
        "match_id": 42,
        "winner_id": 12,
        "mode": "classic",
        "player_count": 4,
        "total_turns": 27,
        "total_captures": 8,
        "duration_sec": 945,
        "created_at": "2025-01-15 14:50:33",
        "code": "ABCD1234",
        "winner_name": "ada",
        "players": [
          { "user_id": 12, "player_color": "red", "seat": 0,
            "username": "ada", "final_rank": 1, "captures": 4 }
        ]
      }
    ]
  }
}
```

---

### 3.8 Wallet

#### GET /wallet  🔒

Returns the user's coin + gem balances.

**Response 200**
```json
{
  "success": true,
  "message": "OK",
  "data": { "coins": 1850, "gems": 22 }
}
```

---

#### GET /wallet/transactions  🔒

Returns the most recent wallet ledger entries (newest first).

**Query params**

| Param    | Type | Default | Notes |
|----------|------|---------|-------|
| `limit`  | int  | 50      | Clamped to 5..200 |

**Response 200**
```json
{
  "success": true,
  "message": "OK",
  "data": {
    "transactions": [
      {
        "id": 992,
        "user_id": 12,
        "type": "credit",
        "currency": "coin",
        "amount": 200,
        "balance_after": 1850,
        "reason": "match_win",
        "reference_id": "match_42",
        "created_at": "2025-01-15 14:50:33"
      },
      {
        "id": 987,
        "user_id": 12,
        "type": "credit",
        "currency": "gem",
        "amount": 2,
        "balance_after": 22,
        "reason": "daily_reward",
        "reference_id": "reward_day_3",
        "created_at": "2025-01-15 09:01:11"
      }
    ]
  }
}
```

---

## 4. Endpoint Summary

| Method | Path                            | Auth | Module      |
|--------|---------------------------------|------|-------------|
| POST   | `/auth/register`                | —    | Auth        |
| POST   | `/auth/login`                   | —    | Auth        |
| POST   | `/auth/logout`                  | 🔒   | Auth        |
| POST   | `/auth/forgot-password`         | —    | Auth        |
| POST   | `/auth/reset-password`          | —    | Auth        |
| GET    | `/profile`                      | 🔒   | Profile     |
| PUT    | `/profile/update`               | 🔒   | Profile     |
| POST   | `/game/create`                  | 🔒   | Game        |
| POST   | `/game/join`                    | 🔒   | Game        |
| POST   | `/game/roll-dice`               | 🔒   | Game        |
| POST   | `/game/move-token`              | 🔒   | Game        |
| GET    | `/game/state`                   | 🔒   | Game        |
| POST   | `/game/pause`                   | 🔒   | Game        |
| POST   | `/game/resume`                  | 🔒   | Game        |
| POST   | `/game/finish`                  | 🔒   | Game        |
| POST   | `/multiplayer/create-room`      | 🔒   | Multiplayer |
| POST   | `/multiplayer/join-room`        | 🔒   | Multiplayer |
| GET    | `/multiplayer/room-status`      | 🔒   | Multiplayer |
| POST   | `/multiplayer/leave-room`       | 🔒   | Multiplayer |
| GET    | `/leaderboard`                  | 🔒   | Leaderboard |
| GET    | `/rewards/daily`                | 🔒   | Rewards     |
| POST   | `/rewards/claim`                | 🔒   | Rewards     |
| GET    | `/history`                      | 🔒   | History     |
| GET    | `/wallet`                       | 🔒   | Wallet      |
| GET    | `/wallet/transactions`          | 🔒   | Wallet      |

Total: **25 endpoints**.

---

## 5. Rate Limiting

The default rate limit (defined in `config/app.php`) is **120 requests
per 60 seconds** per client IP. Exceeding it returns:

```json
{
  "success": false,
  "message": "Too many requests. Please slow down.",
  "errors": null
}
```

with HTTP status `429`. The limiter uses a file-based sliding window in
`backend/storage/logs/`. For production, swap in Redis or APCu via the
`RateLimit` class.

---

## 6. Quick Smoke Test

After starting the PHP server (see [Installation Guide](./installation-guide.md)):

```bash
# 1. Ping an authenticated endpoint without a token → 401
curl -s http://localhost:8000/profile | jq
# { "success": false, "message": "Unauthorized. Invalid or expired token." }

# 2. Login as the demo admin (created by ludo_royale.sql)
curl -s -X POST http://localhost:8000/auth/login \
  -H 'Content-Type: application/json' \
  -d '{"login":"admin","password":"admin123"}' | jq

# 3. Use the returned token
export TOKEN="demo-admin-token-1234567890"
curl -s http://localhost:8000/profile \
  -H "Authorization: Bearer $TOKEN" | jq

# 4. Check the leaderboard
curl -s "http://localhost:8000/leaderboard?limit=10" \
  -H "Authorization: Bearer $TOKEN" | jq

# 5. Check wallet
curl -s http://localhost:8000/wallet \
  -H "Authorization: Bearer $TOKEN" | jq
```
