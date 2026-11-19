# Database Design

This document describes the MySQL schema that backs Ludo Royale — the 15
normalized tables, their fields, indexes, foreign keys, relationships, and
the example queries the application uses.

* **Engine**: InnoDB (required for transactions and FK enforcement)
* **Charset / Collation**: `utf8mb4` / `utf8mb4_unicode_ci` (full Unicode incl. emoji)
* **Schema file**: [`database/ludo_royale.sql`](../database/ludo_royale.sql)
* **Database name**: `ludo_royale`

---

## 1. Table Overview

| # | Table                  | Purpose |
|---|------------------------|---------|
| 1 | `users`                | Authentication accounts (username/email/password_hash/token) |
| 2 | `user_profiles`        | Display info: avatar, country, bio, level, XP |
| 3 | `player_stats`         | Aggregated match stats per user |
| 4 | `wallets`              | Coin + gem balances (one row per user) |
| 5 | `wallet_transactions`  | Append-only ledger of every credit/debit |
| 6 | `matches`              | Match metadata: code, mode, status, host, prize |
| 7 | `match_players`        | Per-match seat assignment (color, seat, AI flag) |
| 8 | `game_states`          | Authoritative JSON snapshot of an active match |
| 9 | `game_moves`           | Move-by-move audit log |
| 10 | `game_history`        | Summary row written when a match finishes |
| 11 | `friendships`         | Bidirectional friend links |
| 12 | `private_rooms`        | Private play rooms with a shareable code |
| 13 | `daily_rewards`       | 7-day reward ladder configuration |
| 14 | `reward_claims`       | Per-user daily claim log |
| 15 | `notifications`        | User notifications (in-app inbox) |

---

## 2. ER-Style Relationship Map

```
                              ┌───────────┐
                              │   users   │
                              │  (PK id)  │
                              └─────┬─────┘
                ┌──────────┬─────────┼─────────┬───────────┬──────────────┐
                │          │         │         │           │              │
        ┌───────▼──────┐ ┌──▼────────┐ ┌──▼──────────┐ ┌──▼─────────┐ ┌──▼──────────────┐
        │ user_profiles│ │player_stats│ │   wallets   │ │ friendships│ │ reward_claims   │
        │   PK user_id │ │ PK user_id │ │  PK user_id │ │  PK id     │ │  PK id          │
        └──────────────┘ └────────────┘ └──────┬──────┘ └────────────┘ │  UQ (user,date)  │
                                              │                         └──────────────────┘
                                              │
                                     ┌────────▼────────┐
                                     │wallet_transactions│
                                     │  PK id            │
                                     │  FK user_id       │
                                     └─────────────────┘

        ┌────────────────────────────┐         ┌─────────────────┐
        │          matches           │◄────────│  private_rooms │
        │ PK id, UQ code, FK host_id │         │  FK host_id    │
        │ FK winner_id (SET NULL)    │         │  FK match_id    │
        └──────┬──────────┬───────────┘         └─────────────────┘
               │          │
       ┌───────▼────┐  ┌──▼─────────┐  ┌────────────────┐  ┌────────────────┐
       │match_players│  │ game_states │  │   game_moves   │  │  game_history  │
       │ PK id       │  │ PK match_id │  │   PK id        │  │ PK id          │
       │ FK match_id │  │ FK match_id │  │   FK match_id  │  │ UQ match_id    │
       │ FK user_id  │  │ tokens_json │  │                │  │ FK match_id    │
       │ UQ(m,seat)  │  └─────────────┘  └────────────────┘  │ FK winner_id   │
       │ UQ(m,color) │                                        └────────────────┘
       └─────────────┘

        ┌─────────────────────┐
        │   notifications     │
        │ PK id, FK user_id   │
        └─────────────────────┘

        ┌─────────────────────┐
        │   daily_rewards     │  ← static config, no FK
        │ PK day (1..7)       │
        └─────────────────────┘
```

**Key relationships:**

* `users (1) ─── (1) user_profiles` — 1:1, profile PK is also FK.
* `users (1) ─── (1) player_stats` — 1:1, aggregated counters.
* `users (1) ─── (1) wallets` — 1:1, single balance row.
* `users (1) ─── (N) wallet_transactions` — append-only ledger.
* `users (1) ─── (N) matches` (as host or winner) — `host_id` CASCADE,
  `winner_id` SET NULL.
* `matches (1) ─── (N) match_players` — seat/color unique per match.
* `matches (1) ─── (1) game_states` — authoritative snapshot.
* `matches (1) ─── (N) game_moves` — audit log.
* `matches (1) ─── (1) game_history` — finished-match summary (`UQ match_id`).
* `private_rooms (1) ─── (1) matches` — room wraps a single match.
* `users (N) ─── (N) users` (via `friendships`) — friend graph with
  `pending/accepted/blocked` status.

---

## 3. Table-by-Table Reference

### 3.1 `users` — Authentication accounts

| Column            | Type             | Null | Default | Notes |
|-------------------|------------------|------|---------|-------|
| `id`              | BIGINT UNSIGNED  | NO   | AUTO    | Primary key |
| `full_name`       | VARCHAR(100)     | NO   |         | Display name |
| `username`        | VARCHAR(50)      | NO   |         | Unique login handle |
| `email`           | VARCHAR(150)     | NO   |         | Unique, used for reset |
| `password_hash`   | VARCHAR(255)     | NO   |         | bcrypt hash via `password_hash()` |
| `avatar_url`      | VARCHAR(255)     | YES  | NULL    | |
| `auth_token`      | VARCHAR(128)     | YES  | NULL    | Bearer token (unique) |
| `token_expires`   | DATETIME         | YES  | NULL    | 24h after issue |
| `reset_token`     | VARCHAR(128)     | YES  | NULL    | Password reset token |
| `reset_expires`   | DATETIME         | YES  | NULL    | 1h after issue |
| `is_online`       | TINYINT(1)       | NO   | 0       | Bumped by `AuthMiddleware` |
| `is_banned`       | TINYINT(1)       | NO   | 0       | Banned users can't login |
| `last_login_at`   | DATETIME         | YES  | NULL    | |
| `last_seen_at`    | DATETIME         | YES  | NULL    | Updated on every authed request |
| `created_at`      | DATETIME         | NO   | NOW     | |
| `updated_at`      | DATETIME         | NO   | NOW ON UPDATE | |

**Indexes / Constraints:**
- `PRIMARY KEY (id)`
- `UNIQUE uniq_username (username)`
- `UNIQUE uniq_email (email)`
- `UNIQUE uniq_auth_token (auth_token)`
- `KEY idx_reset_token (reset_token)`
- `KEY idx_is_online (is_online)`

### 3.2 `user_profiles` — Player display / bio info

| Column          | Type            | Null | Default | Notes |
|-----------------|-----------------|------|---------|-------|
| `user_id`       | BIGINT UNSIGNED | NO   |         | PK + FK→users.id |
| `avatar_url`    | VARCHAR(255)    | YES  | NULL    | Per-profile override |
| `country_code`  | VARCHAR(5)       | YES  | NULL    | ISO 3166-1 alpha-2 |
| `bio`           | VARCHAR(255)    | YES  | NULL    | Free text |
| `player_level`  | INT UNSIGNED    | NO   | 1       | Derived from XP in future |
| `experience`    | INT UNSIGNED    | NO   | 0       | XP points |
| `updated_at`    | DATETIME        | NO   | NOW ON UPDATE | |

**Constraints:** `PK (user_id)`, `FK fk_profile_user → users.id ON DELETE CASCADE`

### 3.3 `player_stats` — Aggregated match stats

| Column                | Type            | Default | Notes |
|-----------------------|-----------------|---------|-------|
| `user_id`             | BIGINT UNSIGNED |         | PK + FK→users.id |
| `total_matches`       | INT UNSIGNED    | 0       | wins + losses |
| `total_wins`          | INT UNSIGNED    | 0       | |
| `total_losses`        | INT UNSIGNED    | 0       | |
| `total_captures`      | INT UNSIGNED    | 0       | Cumulative captures |
| `total_captured`      | INT UNSIGNED    | 0       | Cumulative times captured |
| `total_dice_rolls`    | INT UNSIGNED    | 0       | |
| `best_win_streak`     | INT UNSIGNED    | 0       | All-time best |
| `current_win_streak`  | INT UNSIGNED    | 0       | Reset on loss |
| `updated_at`          | DATETIME        | NOW ON UPDATE | |

**Constraints:** `PK (user_id)`, `FK fk_stats_user → users.id ON DELETE CASCADE`

### 3.4 `wallets` — Coin / gem balances

| Column       | Type            | Default | Notes |
|--------------|-----------------|---------|-------|
| `user_id`    | BIGINT UNSIGNED |         | PK + FK→users.id |
| `coins`      | BIGINT          | 500     | Starting bonus |
| `gems`       | BIGINT          | 10      | Premium currency |
| `updated_at` | DATETIME        | NOW ON UPDATE | |

**Constraints:** `PK (user_id)`, `FK fk_wallet_user → users.id ON DELETE CASCADE`

### 3.5 `wallet_transactions` — Append-only ledger

| Column          | Type            | Null | Notes |
|-----------------|-----------------|------|-------|
| `id`            | BIGINT UNSIGNED | NO   | AUTO PK |
| `user_id`       | BIGINT UNSIGNED | NO   | FK→users.id |
| `type`          | ENUM('credit','debit') | NO | |
| `currency`      | ENUM('coin','gem')     | NO | |
| `amount`        | BIGINT          | NO   | Always positive |
| `balance_after` | BIGINT          | NO   | Snapshot after this tx |
| `reason`        | VARCHAR(50)     | NO   | e.g. `match_win`, `daily_reward`, `entry_fee` |
| `reference_id`  | VARCHAR(80)     | YES  | e.g. `match_42`, `reward_day_3` |
| `created_at`    | DATETIME        | NO   | NOW |

**Indexes:** `PK (id)`, `KEY idx_wallet_user (user_id)`, `KEY idx_wallet_ref (reference_id)`,
`FK fk_tx_user → users.id ON DELETE CASCADE`

### 3.6 `matches` — Game match metadata

| Column            | Type            | Default | Notes |
|-------------------|-----------------|---------|-------|
| `id`              | BIGINT UNSIGNED | AUTO    | PK |
| `code`            | VARCHAR(12)     |         | Unique shareable code (8 chars) |
| `mode`            | ENUM('classic','quick','private','offline_ai','local') | 'classic' | |
| `max_players`     | TINYINT UNSIGNED | 4      | 2..4 |
| `status`          | ENUM('waiting','active','paused','finished','abandoned') | 'waiting' | |
| `winner_id`       | BIGINT UNSIGNED | NULL    | FK→users.id, SET NULL on delete |
| `host_id`         | BIGINT UNSIGNED |         | FK→users.id, CASCADE |
| `entry_fee`       | INT UNSIGNED    | 0       | Coins paid to join |
| `prize_pool`       | INT UNSIGNED   | 0       | entry_fee × max_players |
| `turn_number`     | INT UNSIGNED    | 0       | Increments per turn |
| `current_player`  | TINYINT UNSIGNED | 0       | Seat index of active player |
| `six_counter`     | TINYINT UNSIGNED | 0      | Resets at 3 (forfeit rule) |
| `started_at`      | DATETIME        | NULL    | Set when match becomes `active` |
| `finished_at`     | DATETIME        | NULL    | Set on `finish` |
| `created_at`      | DATETIME        | NOW     | |
| `updated_at`      | DATETIME        | NOW ON UPDATE | |

**Indexes:** `PK (id)`, `UQ uniq_match_code (code)`, `KEY idx_match_status`,
`KEY idx_match_host`, `KEY idx_match_winner`, `FK fk_match_host`, `FK fk_match_winner`

### 3.7 `match_players` — Players participating in a match

| Column          | Type            | Default | Notes |
|-----------------|-----------------|---------|-------|
| `id`            | BIGINT UNSIGNED | AUTO    | PK |
| `match_id`      | BIGINT UNSIGNED |         | FK→matches.id |
| `user_id`       | BIGINT UNSIGNED | NULL    | FK→users.id (NULL for pure AI) |
| `player_color`  | ENUM('red','green','yellow','blue') | | |
| `seat`          | TINYINT UNSIGNED |        | 0..3, matches `current_player` |
| `is_ai`         | TINYINT(1)      | 0       | 1 for AI bots |
| `ai_level`      | ENUM('easy','medium','hard') | NULL | |
| `is_ready`      | TINYINT(1)      | 0       | Lobby ready flag |
| `is_connected`  | TINYINT(1)      | 1       | Online indicator |
| `final_rank`    | TINYINT UNSIGNED | NULL   | 1 = winner, NULL = unfinished |
| `final_score`   | INT             | 0       | Optional score |
| `captures`      | INT UNSIGNED   | 0       | Per-match capture count |
| `joined_at`     | DATETIME        | NOW     | |

**Indexes:** `PK (id)`, `UQ uniq_match_seat (match_id, seat)`,
`UQ uniq_match_color (match_id, player_color)`, `KEY idx_mp_user`,
`FK fk_mp_match CASCADE`, `FK fk_mp_user CASCADE`

### 3.8 `game_states` — Authoritative snapshot

| Column            | Type            | Default | Notes |
|-------------------|-----------------|---------|-------|
| `match_id`        | BIGINT UNSIGNED |         | PK + FK→matches.id |
| `current_player`  | TINYINT UNSIGNED | 0      | |
| `dice_value`      | TINYINT UNSIGNED | NULL   | NULL when waiting to roll |
| `phase`           | ENUM('waiting','rolling','moving','finished') | 'waiting' | |
| `turn_number`     | INT UNSIGNED    | 0       | |
| `six_counter`     | TINYINT UNSIGNED | 0      | |
| `tokens_json`     | JSON            |         | `{ "red":[-1,-1,-1,-1], "green":[...], ... }` |
| `version`         | INT UNSIGNED    | 1       | Bumped on every UPDATE (optimistic concurrency) |
| `updated_at`      | DATETIME        | NOW ON UPDATE | |

**Constraints:** `PK (match_id)`, `FK fk_state_match → matches.id CASCADE`

### 3.9 `game_moves` — Move-by-move audit log

| Column         | Type             | Null | Notes |
|----------------|------------------|------|-------|
| `id`           | BIGINT UNSIGNED  | NO   | AUTO PK |
| `match_id`     | BIGINT UNSIGNED  | NO   | FK→matches.id |
| `player_seat`  | TINYINT UNSIGNED | NO   | |
| `move_type`    | ENUM('roll','move','capture','extra_turn','forfeit','win') | NO | |
| `dice_value`   | TINYINT UNSIGNED | YES  | Set for `roll` and `move` |
| `token_index`  | TINYINT UNSIGNED | YES  | Which of the 4 tokens moved |
| `from_pos`     | SMALLINT         | YES  | -1 = base |
| `to_pos`       | SMALLINT         | YES  | 57 = home |
| `extra_data`   | JSON             | YES  | e.g. `{ captured: "green", captured_tokens: [2] }` |
| `created_at`   | DATETIME         | NO   | NOW |

**Indexes:** `PK (id)`, `KEY idx_moves_match (match_id)`,
`FK fk_moves_match → matches.id CASCADE`

### 3.10 `game_history` — Finished match summary

| Column             | Type            | Notes |
|--------------------|-----------------|-------|
| `id`               | BIGINT UNSIGNED | AUTO PK |
| `match_id`         | BIGINT UNSIGNED | UQ + FK→matches.id |
| `winner_id`        | BIGINT UNSIGNED | NULL, FK→users.id SET NULL |
| `mode`             | VARCHAR(20)     | |
| `player_count`     | TINYINT UNSIGNED | |
| `total_turns`      | INT UNSIGNED   | |
| `total_captures`   | INT UNSIGNED   | |
| `duration_sec`     | INT UNSIGNED   | `finished_at - started_at` |
| `players_json`     | JSON            | Full player list (incl. AI) |
| `created_at`       | DATETIME       | NOW |

**Constraints:** `PK (id)`, `UQ uniq_history_match (match_id)`,
`KEY idx_history_winner`, `FK fk_history_match`, `FK fk_history_winner`

### 3.11 `friendships` — Friend links

| Column       | Type            | Notes |
|--------------|-----------------|-------|
| `id`         | BIGINT UNSIGNED | AUTO PK |
| `user_id`    | BIGINT UNSIGNED | FK→users.id |
| `friend_id`  | BIGINT UNSIGNED | FK→users.id |
| `status`     | ENUM('pending','accepted','blocked') | Default `pending` |
| `created_at` | DATETIME        | NOW |
| `updated_at` | DATETIME        | NOW ON UPDATE |

**Indexes:** `PK (id)`, `UQ uniq_friendship_pair (user_id, friend_id)`,
`KEY idx_friend_status (friend_id, status)`, both FKs CASCADE.

### 3.12 `private_rooms` — Private play rooms

| Column        | Type            | Notes |
|---------------|-----------------|-------|
| `id`          | BIGINT UNSIGNED | AUTO PK |
| `room_code`   | VARCHAR(12)     | UQ, 6 chars |
| `host_id`     | BIGINT UNSIGNED | FK→users.id CASCADE |
| `max_players` | TINYINT UNSIGNED | Default 4 |
| `mode`        | VARCHAR(20)     | Default `'classic'` |
| `status`      | ENUM('open','started','closed') | Default `open` |
| `match_id`    | BIGINT UNSIGNED | FK→matches.id SET NULL |
| `created_at`  | DATETIME        | NOW |
| `updated_at`  | DATETIME        | NOW ON UPDATE |

**Indexes:** `PK (id)`, `UQ uniq_room_code`, `KEY idx_room_host`,
`KEY idx_room_status`, `FK fk_room_host`, `FK fk_room_match`.

### 3.13 `daily_rewards` — Reward ladder config

| Column        | Type            | Default | Notes |
|---------------|-----------------|---------|-------|
| `day`         | TINYINT UNSIGNED |         | PK (1..7) |
| `reward_type` | ENUM('coin','gem') | 'coin' | |
| `amount`      | INT UNSIGNED    |         | |
| `is_active`   | TINYINT(1)      | 1       | 0 = disabled |
| `updated_at`  | DATETIME        | NOW ON UPDATE | |

Seed data: `100c, 200c, 2g, 400c, 600c, 5g, 1000c`.

### 3.14 `reward_claims` — Per-user claim log

| Column         | Type            | Notes |
|----------------|-----------------|-------|
| `id`           | BIGINT UNSIGNED | AUTO PK |
| `user_id`      | BIGINT UNSIGNED | FK→users.id |
| `claim_date`   | DATE            | UTC date |
| `streak_day`   | TINYINT UNSIGNED | 1..7 (wraps) |
| `reward_type`  | ENUM('coin','gem') | |
| `amount`       | INT UNSIGNED   | |
| `created_at`   | DATETIME        | NOW |

**Indexes:** `PK (id)`, `UQ uniq_user_claim_day (user_id, claim_date)`
— this unique constraint is what prevents double-claiming, `KEY idx_claim_user`,
`FK fk_claim_user CASCADE`.

### 3.15 `notifications` — User notifications

| Column       | Type            | Notes |
|--------------|-----------------|-------|
| `id`         | BIGINT UNSIGNED | AUTO PK |
| `user_id`    | BIGINT UNSIGNED | FK→users.id |
| `type`       | VARCHAR(40)     | e.g. `match_invite`, `reward`, `system` |
| `title`      | VARCHAR(150)    | |
| `body`       | VARCHAR(500)    | |
| `is_read`    | TINYINT(1)      | Default 0 |
| `extra`      | JSON            | Optional payload |
| `created_at` | DATETIME        | NOW |

**Indexes:** `PK (id)`, `KEY idx_notif_user_read (user_id, is_read)`,
`FK fk_notif_user CASCADE`.

---

## 4. Example Queries Used by the App

### 4.1 Load user (joined profile + stats + wallet)

Used by `AuthService::loadUser()` and the `GET /profile` endpoint:

```sql
SELECT u.id, u.full_name, u.username, u.email, u.avatar_url,
       u.is_online, u.last_login_at,
       p.player_level, p.experience, p.country_code, p.bio,
       s.total_matches, s.total_wins, s.total_losses, s.total_captures,
       w.coins, w.gems
  FROM users u
  LEFT JOIN user_profiles p ON p.user_id = u.id
  LEFT JOIN player_stats  s ON s.user_id = u.id
  LEFT JOIN wallets       w ON w.user_id = u.id
 WHERE u.id = :id;
```

### 4.2 Leaderboard (top winners with win rate)

Used by `GET /leaderboard`:

```sql
SELECT u.id, u.username, u.avatar_url,
       COALESCE(s.total_matches, 0) AS total_matches,
       COALESCE(s.total_wins, 0)     AS total_wins,
       COALESCE(s.total_losses, 0)   AS total_losses,
       COALESCE(s.total_captures, 0) AS total_captures,
       COALESCE(p.player_level, 1)  AS player_level,
       (CASE WHEN s.total_matches > 0
             THEN ROUND((s.total_wins / s.total_matches) * 100, 2)
             ELSE 0 END) AS win_rate
  FROM users u
  LEFT JOIN player_stats  s ON s.user_id = u.id
  LEFT JOIN user_profiles p ON p.user_id = u.id
 WHERE u.is_banned = 0
 ORDER BY total_wins DESC, win_rate DESC, total_captures DESC
 LIMIT :l;
```

### 4.3 Transaction-safe wallet update (lock + adjust + log)

Used by `WalletService::adjust()`. The `FOR UPDATE` lock prevents
double-spending under concurrent requests:

```sql
START TRANSACTION;

-- Lock the wallet row so concurrent debits block
SELECT coins, gems FROM wallets
  WHERE user_id = :u
  FOR UPDATE;

-- Apply the delta
UPDATE wallets SET coins = :new_coins
  WHERE user_id = :u;

-- Append to the ledger with the resulting balance
INSERT INTO wallet_transactions
  (user_id, type, currency, amount, balance_after, reason, reference_id)
VALUES
  (:u, 'credit', 'coin', :amt, :new_coins, 'match_win', 'match_42');

COMMIT;
```

If the rollback path is hit (e.g. insufficient funds), `ROLLBACK` cancels
both the UPDATE and the INSERT atomically.

### 4.4 Daily reward claim (idempotent via unique constraint)

Used by `RewardService::claim()`. The `UQ uniq_user_claim_day` index
makes the insert fail if the user has already claimed today:

```sql
-- 1. Resolve the user's current streak (today / yesterday / reset)
SELECT * FROM reward_claims
  WHERE user_id = :u
  ORDER BY claim_date DESC
  LIMIT 2;

-- 2. Load the configured reward for the upcoming streak day
SELECT * FROM daily_rewards
  WHERE day = :streak_day AND is_active = 1;

-- 3. INSERT the claim — the unique constraint is the safety net
INSERT INTO reward_claims
  (user_id, claim_date, streak_day, reward_type, amount)
VALUES
  (:u, CURDATE(), :streak_day, 'coin', 200);
-- → Duplicate entry error if already claimed today
```

### 4.5 Match history for the current user

Used by `GET /history`:

```sql
SELECT h.*, m.code, u.username AS winner_name
  FROM game_history h
  JOIN matches        m  ON m.id = h.match_id
  JOIN match_players  mp ON mp.match_id = h.match_id AND mp.user_id = :u
  LEFT JOIN users      u  ON u.id = h.winner_id
 ORDER BY h.created_at DESC
 LIMIT :l;
```

### 4.6 Load a full match payload

Used by `GameService::loadMatch()`:

```sql
-- match metadata
SELECT * FROM matches WHERE id = :m;

-- players (with username + avatar)
SELECT mp.*, u.username, u.avatar_url
  FROM match_players mp
  LEFT JOIN users u ON u.id = mp.user_id
 WHERE mp.match_id = :m
 ORDER BY mp.seat;

-- authoritative game state
SELECT * FROM game_states WHERE match_id = :m;
```

---

## 5. Migration / Import Instructions

### Option A — phpMyAdmin (GUI, recommended for XAMPP users)

1. Start XAMPP → start **Apache** and **MySQL**.
2. Open `http://localhost/phpmyadmin`.
3. Click **Import** in the top navigation.
4. Choose file `database/ludo_royale.sql`.
5. Leave format as **SQL** and click **Go**.
   - The script drops the DB if it exists, recreates it with `utf8mb4`,
     creates all 15 tables, seeds `daily_rewards`, and inserts the demo
     admin user.

### Option B — MySQL CLI

```bash
mysql -u root -p < database/ludo_royale.sql
```

### Option C — XAMPP shell (Linux/macOS XAMPP)

```bash
/opt/lampp/bin/mysql -u root < database/ludo_royale.sql
```

### Option D — Docker

```bash
docker exec -i some-mariadb mysql -uroot -psecret < database/ludo_royale.sql
```

### Verifying the import

```sql
USE ludo_royale;
SHOW TABLES;                       -- should list 15 tables
SELECT COUNT(*) FROM daily_rewards; -- should return 7
SELECT username FROM users;         -- should return 'admin'
```

### Seed / Demo data

After import, the following seed rows are present:

* `daily_rewards`: 7 rows (the 7-day reward ladder).
* `users`: 1 demo admin — `username = admin`, `password = admin123`,
  `auth_token = demo-admin-token-1234567890`.
* Linked `user_profiles`, `player_stats`, and `wallets` rows for the
  admin (level 99, 99999 coins, 999 gems, 50 matches / 35 wins).

> ⚠️ **Remove the demo admin user before deploying to production.**

---

## 6. Backup & Maintenance

```bash
# Dump the full schema + data
mysqldump -u root -p --single-transaction --routines ludo_royale > backup.sql

# Restore
mysql -u root -p ludo_royale < backup.sql

# Optimize all tables (run weekly in low-traffic windows)
mysql -u root -p -e "USE ludo_royale; OPTIMIZE TABLE users, wallets, matches, game_states, game_moves;"
```

Recommended retention for `wallet_transactions` and `game_moves`:
archive rows older than 90 days to a cold-storage table to keep the
active indexes small.
