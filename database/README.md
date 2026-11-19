# Ludo Royale Database

## Overview
This file defines the complete MySQL schema for Ludo Royale. It creates the database `ludo_royale` and all 15 normalized tables with proper foreign keys, indexes, unique constraints, and a 7-day daily reward ladder.

## Import Instructions (XAMPP / phpMyAdmin)

### Option A: phpMyAdmin (GUI)
1. Open `http://localhost/phpmyadmin`
2. Click **Import** in the top menu
3. Choose file `database/ludo_royale.sql`
4. Click **Go** — the database and tables are created automatically.

### Option B: MySQL CLI
```bash
mysql -u root -p < database/ludo_royale.sql
```

### Option C: XAMPP shell
```bash
/opt/lampp/bin/mysql -u root < database/ludo_royale.sql
```

## Tables
1. `users` — auth accounts
2. `user_profiles` — bio / level / xp
3. `player_stats` — aggregated win/loss/captures
4. `wallets` — coin / gem balances
5. `wallet_transactions` — append-only ledger
6. `matches` — game match metadata
7. `match_players` — participants per match (color, seat, AI flag)
8. `game_states` — authoritative match snapshot (JSON tokens)
9. `game_moves` — move-by-move audit log
10. `game_history` — finished match summary
11. `friendships` — friend links
12. `private_rooms` — private play rooms
13. `daily_rewards` — 7-day reward ladder config
14. `reward_claims` — per-user claim log (unique per day)
15. `notifications` — user notifications

## Demo User
A demo user `admin` / `admin123` is created with a token `demo-admin-token-1234567890`. **Remove in production.**
