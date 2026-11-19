# Ludo Royale - Backend (Core PHP REST API)

Server-side REST API for Ludo Royale. Provides authentication, server-authoritative
gameplay, multiplayer rooms, wallet, daily rewards, leaderboard and match history.

## Requirements

- PHP 7.4+ (8.x recommended)
- MySQL 5.7+ or MariaDB 10.4+
- Composer (optional - for phpunit tests only)

## Installation

### Option A: Built-in PHP server (development)

```bash
cd backend
cp .env.example .env
# Edit .env with your DB credentials
php -S 0.0.0.0:8000 -t public
```

The API is now at `http://localhost:8000`.

### Option B: XAMPP / Apache

1. Copy this `backend/` directory to `htdocs/ludo-royale-backend/`
2. Make sure `mod_rewrite` is enabled in Apache
3. Edit `.env` with your DB credentials
4. Visit `http://localhost/ludo-royale-backend/public/`

### Option C: Nginx + PHP-FPM

```nginx
server {
    listen 8000;
    root /var/www/ludo-royale/backend/public;
    index index.php;

    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }

    location ~ \.php$ {
        fastcgi_pass unix:/run/php/php8.1-fpm.sock;
        fastcgi_index index.php;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
    }
}
```

## Database

Import `../database/ludo_royale.sql` via phpMyAdmin or:

```bash
mysql -u root -p < ../database/ludo_royale.sql
```

## Smoke Test

```bash
php tests/smoke_test.php
```

Expected output: `All smoke tests passed.`

## Folder Structure

```
backend/
├── public/
│   ├── index.php             # Front controller & route dispatcher
│   └── .htaccess             # Apache rewrite rules
├── config/
│   ├── app.php               # App + DB config
│   ├── database.php          # PDO singleton
│   └── cors.php              # CORS handler
├── routes/                   # Route definitions per module
│   ├── api.php
│   ├── auth.php
│   ├── profile.php
│   ├── game.php
│   ├── multiplayer.php
│   ├── leaderboard.php
│   ├── rewards.php
│   ├── wallet.php
│   └── history.php
├── services/                 # Business logic
│   ├── AuthService.php
│   ├── GameService.php
│   ├── GameEngine.php        # Server-authoritative rules
│   ├── DiceService.php       # random_int() dice roller
│   ├── MultiplayerService.php
│   ├── RewardService.php
│   └── WalletService.php
├── middleware/
│   ├── AuthMiddleware.php
│   └── RateLimit.php
├── validators/
│   └── Validator.php
├── helpers/
│   └── functions.php         # Global helpers (json_response, gen_token, ...)
├── storage/
│   ├── avatars/
│   └── logs/
├── tests/
│   └── smoke_test.php
├── .env.example
└── composer.json
```

## API Documentation

See `/documentation/api-documentation.md` for the full endpoint reference.
