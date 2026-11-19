# Installation Guide

This guide walks you through setting up Ludo Royale from a clean clone to
a running app on Android, iOS, or Web.

---

## 1. Prerequisites

| Tool                | Version    | Why                                        |
|---------------------|------------|--------------------------------------------|
| **Flutter**         | 3.13+      | Build & run the mobile/web client          |
| **Dart**            | 3.0+       | Bundled with Flutter                       |
| **PHP**             | 7.4+       | Run the REST API backend (CLI server)     |
| **MySQL**           | 5.7+       | Database (MariaDB 10.4+ also works)        |
| **XAMPP**           | 8.0+       | Recommended one-click Apache + MySQL stack |
| **Android Studio**  | Hedgehog+  | Android SDK + emulator                     |
| **Git**             | any recent | Clone the repo                             |
| **curl + jq**       | any        | Smoke-test the API                         |

### OS-specific notes

* **Windows**: install XAMPP, then add `C:\xampp\php` to your `PATH`.
* **macOS**: `brew install php` (PHP 8.x is fine), or use XAMPP.
* **Linux**: `sudo apt install php-cli php-mysql` (Debian/Ubuntu).

Verify versions:

```bash
flutter --version    # Flutter 3.13+, Dart 3.0+
php --version        # PHP 7.4+
mysql --version      # MySQL 5.7+ or MariaDB 10.4+
```

---

## 2. Step 1 — Clone the project

```bash
git clone https://github.com/your-org/LUDO-ROYALE.git
cd LUDO-ROYALE
```

You should see three top-level directories:

```
LUDO-ROYALE/
├── backend/          # PHP REST API
├── database/         # ludo_royale.sql (schema + seed)
├── documentation/    # this file and siblings
└── flutter_app/      # Flutter client
```

---

## 3. Step 2 — Database setup

### Option A: phpMyAdmin (recommended for XAMPP users)

1. Start **XAMPP Control Panel** → click **Start** next to **Apache** and **MySQL**.
2. Open your browser to <http://localhost/phpmyadmin>.
3. Click the **Import** tab in the top navigation.
4. Click **Choose File** and select `database/ludo_royale.sql`
   (in the cloned project).
5. Leave the format as **SQL** and click **Go**.

The script will:
- Drop the `ludo_royale` database if it exists
- Create a fresh `ludo_royale` database with `utf8mb4_unicode_ci`
- Create all **15 tables** with foreign keys and indexes
- Seed the `daily_rewards` ladder (7 days)
- Insert a demo admin user

### Option B: MySQL CLI

```bash
mysql -u root -p < database/ludo_royale.sql
```

### Option C: XAMPP shell (Linux/macOS XAMPP install)

```bash
/opt/lampp/bin/mysql -u root < database/ludo_royale.sql
```

### Verify the import

```sql
USE ludo_royale;
SHOW TABLES;                       -- 15 rows expected
SELECT COUNT(*) FROM daily_rewards; -- 7
SELECT username, email FROM users; -- 'admin' / 'admin@ludoroyale.local'
```

### Demo credentials

After import, a demo admin user is available:

| Field      | Value                     |
|------------|---------------------------|
| Username   | `admin`                   |
| Password   | `admin123`                |
| Email      | `admin@ludoroyale.local`  |
| Auth token | `demo-admin-token-1234567890` |
| Coins      | 99999                     |
| Gems       | 999                       |

> ⚠️ **Remove the demo user before deploying to production.**

---

## 4. Step 3 — Backend setup

The PHP backend is a single front controller (`backend/public/index.php`)
with no Composer dependencies required (the `composer.json` is included
for PSR-4 convenience only).

### Option A: PHP built-in server (recommended for development)

```bash
cd backend
php -S 0.0.0.0:8000 -t public
```

This serves `public/` at port `8000` on all interfaces. You should see:

```
[Mon Jan 15 14:00:00 2025] PHP 8.2.0 Development Server (http://0.0.0.0:8000) started
```

### Option B: XAMPP htdocs

Copy (or symlink) the `backend/` folder into XAMPP's `htdocs/`:

```bash
# Linux/macOS XAMPP
ln -s "$(pwd)/backend" /opt/lampp/htdocs/ludo-royale-backend

# Windows XAMPP (run in cmd as administrator)
mklink /D C:\xampp\htdocs\ludo-royale-backend C:\path\to\LUDO-ROYALE\backend
```

The API is then reachable at <http://localhost/ludo-royale-backend/public/>.

### Option C: Apache vhost (production)

```apache
<VirtualHost *:80>
    ServerName api.ludoroyale.local
    DocumentRoot /var/www/LUDO-ROYALE/backend/public
    <Directory /var/www/LUDO-ROYALE/backend/public>
        AllowOverride All
        Require all granted
        FallbackResource /index.php
    </Directory>
</VirtualHost>
```

### Database credentials

Edit `backend/config/app.php` directly, or — preferred — set environment
variables before starting the server:

```bash
export DB_HOST=127.0.0.1
export DB_PORT=3306
export DB_NAME=ludo_royale
export DB_USER=root
export DB_PASS=        # XAMPP default is empty
export JWT_SECRET=$(openssl rand -hex 32)
export APP_ENV=development
export APP_DEBUG=true

cd backend
php -S 0.0.0.0:8000 -t public
```

### Smoke test the backend

```bash
# Should return 401 JSON (no token sent)
curl -s http://localhost:8000/profile | jq

# Expected response:
# {
#   "success": false,
#   "message": "Unauthorized. Invalid or expired token."
# }

# Login with the demo admin
curl -s -X POST http://localhost:8000/auth/login \
  -H 'Content-Type: application/json' \
  -d '{"login":"admin","password":"admin123"}' | jq

# Use the demo token to fetch the profile
curl -s http://localhost:8000/profile \
  -H 'Authorization: Bearer demo-admin-token-1234567890' | jq
```

If the JSON output looks correct, the backend is ready.

---

## 5. Step 4 — Flutter app setup

```bash
cd flutter_app
flutter pub get
```

This installs all dependencies listed in `pubspec.yaml` (Riverpod, go_router,
http, sqflite, shared_preferences, confetti, vibration, audioplayers,
flutter_animate, google_fonts, etc.).

### Configure the API URL

The base URL is stored in `AppConfig.apiBaseUrl` (SharedPreferences) and
defaults to `http://10.0.2.2:8000` (the Android emulator's alias for the
host machine's `localhost`).

You have **two ways** to change it:

1. **In-app**: launch the app → Settings → edit "API Base URL". The
   change is persisted immediately.
2. **Source code** (useful for first-run defaults): edit
   `lib/core/storage/app_config.dart`:

```dart
// flutter_app/lib/core/storage/app_config.dart
static String get apiBaseUrl =>
    prefs.getString(_kApiBaseUrl) ?? 'http://10.0.2.2:8000';
//                                            ^^^^^^^^^^^^^^^^^^^^^^^^
//                                  Replace with your URL for other targets.
```

### Which URL to use?

| Target                          | API URL                          |
|---------------------------------|----------------------------------|
| Android emulator                | `http://10.0.2.2:8000`          |
| iOS simulator (same machine)    | `http://localhost:8000`          |
| Web (Chrome)                    | `http://localhost:8000`         |
| Physical Android/iOS device     | `http://<your-LAN-IP>:8000`     |

To find your LAN IP:

```bash
# macOS / Linux
ipconfig getifaddr en0    # or: hostname -I

# Windows
ipconfig
# Look for "IPv4 Address" under your active adapter, e.g. 192.168.1.5
```

The device and the dev machine must be on the **same Wi-Fi network**.

### Android network security (HTTP cleartext)

Android 9+ blocks cleartext HTTP by default. The project's
`android/app/src/main/AndroidManifest.xml` already permits cleartext
traffic via `android:usesCleartextTraffic="true"`. For production, switch
to HTTPS and remove this attribute.

---

## 6. Step 5 — Run the app

### Android / iOS

```bash
# Make sure an emulator/device is connected
flutter devices

# Run on the currently selected device
flutter run

# Run on a specific device id
flutter run -d <device-id>
```

Hot reload: press `r` in the terminal. Hot restart: press `R`.

### Web

```bash
flutter run -d chrome
```

For the web target, `sqflite_common_ffi_web` is used to provide
SQLite support in the browser.

---

## 7. Step 6 — Build for release

### Android APK

```bash
flutter build apk --release
# Output: build/app/outputs/flutter-apk/app-release.apk
```

For per-ABI splits (smaller download size):

```bash
flutter build apk --release --split-per-abi
```

### Android App Bundle (for Play Store)

```bash
flutter build appbundle --release
# Output: build/app/outputs/bundle/release/app-release.aab
```

### Web

```bash
flutter build web --release
# Output: build/web/
```

Deploy the contents of `build/web/` to any static host (Firebase Hosting,
GitHub Pages, Netlify, Nginx).

### iOS (requires macOS + Xcode)

```bash
flutter build ios --release
cd ios
pod install
open Runner.xcworkspace
# In Xcode: select a team, then Product → Archive
```

---

## 8. Troubleshooting

### 8.1 CORS errors in the web client

**Symptom**: the browser console shows
`Access to fetch at 'http://localhost:8000/...' from origin 'http://localhost:5000' has been blocked by CORS policy`.

**Fix**: the backend already handles CORS in `backend/config/cors.php`,
but if you customized `allowed_origins` to restrict to specific domains,
make sure your Flutter web origin is in the list. For development,
`['*']` works. For production, set:

```php
'allowed_origins' => ['https://app.ludoroyale.com'],
```

### 8.2 Connection refused / SocketException

**Symptom**: the Flutter app shows "Connection refused" or hangs on
login.

**Causes & fixes**:

1. **Backend not running** → start it:
   ```bash
   cd backend && php -S 0.0.0.0:8000 -t public
   ```
2. **Wrong API URL on a physical device** → use the LAN IP, not
   `localhost` or `10.0.2.2`. Use the in-app Settings screen to change
   the URL.
3. **Firewall blocking port 8000** → on macOS, allow incoming for the
   `php` binary in *System Settings → Network → Firewall*. On Windows,
   open port 8000 in Windows Defender Firewall.
4. **Android emulator using `localhost`** → use `http://10.0.2.2:8000`
   instead. `localhost` in the emulator refers to the emulator itself,
   not your dev machine.

### 8.3 Database connection errors

**Symptom**: the API returns
```json
{ "success": false, "error": "Database connection failed: SQLSTATE[HY000] [2002] Connection refused" }
```

**Fixes**:

1. **MySQL not running** → start XAMPP MySQL, or:
   ```bash
   sudo systemctl start mysql
   # or
   brew services start mysql
   ```
2. **Wrong credentials** → set `DB_USER` / `DB_PASS` env vars, or edit
   `backend/config/app.php`:
   ```php
   'database' => [
       'host' => '127.0.0.1',
       'port' => 3306,
       'name' => 'ludo_royale',
       'user' => 'root',
       'pass' => '',     // ← set this to your MySQL password
       'charset' => 'utf8mb4',
   ],
   ```
3. **Database not imported** → re-run `mysql -u root -p < database/ludo_royale.sql`
   and verify with `SHOW TABLES;`.
4. **`127.0.0.1` vs `localhost`** → on some systems `localhost` resolves
   to a Unix socket; `127.0.0.1` forces TCP. Try both.

### 8.4 SQLite errors in the Flutter app

**Symptom**: `MissingPluginException` for `sqflite` or
`SqflitePluginException(database_path, ...)`.

**Fixes**:

* Run `flutter clean && flutter pub get` after switching branches.
* For **web**, make sure `sqflite_common_ffi_web` is initialized —
  it is automatically loaded via the dependency, but call
  `await databaseFactoryFfiWeb.sqfliteFfiWebInit()` once in `main()`
  if you see issues.
* For **desktop** (Linux/Windows/macOS debug), use `sqflite_common_ffi`:
  ```yaml
  dependencies:
    sqflite_common_ffi: ^2.3.0
  ```

### 8.5 "401 Unauthorized" on every authenticated request

**Causes**:

1. **Token expired** (24h TTL) → log in again to receive a fresh token.
2. **Token not set** in `AppConfig` → check that the login flow
   completed without error and `AppConfig.authToken` is not null.
3. **Banned user** (`is_banned = 1`) → in the database:
   ```sql
   UPDATE users SET is_banned = 0 WHERE username = 'admin';
   ```

### 8.6 Build errors with Flutter

```bash
# Clear caches and rebuild
flutter clean
flutter pub get
flutter pub upgrade

# If the issue is with generated code (riverpod_generator / json_serializable):
dart run build_runner build --delete-conflicting-outputs
```

### 8.7 PHP errors: "Class Database not found"

The backend relies on autoloading. If you're not using Composer (the
default), the `public/index.php` script manually `require_once`s every
class file. If you moved files around, make sure the relative paths
inside `index.php` still resolve. Or run:

```bash
cd backend
composer dump-autoload
```

### 8.8 "Could not find the Dart SDK" or "Flutter not in PATH"

Install Flutter from <https://docs.flutter.dev/get-started/install> and
add it to your PATH. Verify with `flutter doctor`:

```bash
flutter doctor -v
```

Fix all items reported with ✗ before continuing.

---

## 9. Development Workflow

### Run everything together (3 terminals)

**Terminal 1 — MySQL** (already running via XAMPP).

**Terminal 2 — PHP backend**:
```bash
cd backend
php -S 0.0.2.2:8000 -t public
```

**Terminal 3 — Flutter app**:
```bash
cd flutter_app
flutter run
```

### Hot reload

* Flutter: press `r` (hot reload) or `R` (hot restart) in Terminal 3.
* PHP: changes take effect on the next request — no restart needed.

### Logs

* Backend logs: `backend/storage/logs/app-YYYY-MM-DD.log`
* Rate-limit files: `backend/storage/logs/ratelimit_*.json`
* Flutter logs: `flutter logs` or in the run terminal.

---

## 10. Production Checklist

Before deploying to production:

- [ ] Remove the demo admin user (`DELETE FROM users WHERE username = 'admin'`).
- [ ] Set `APP_ENV=production` and `APP_DEBUG=false`.
- [ ] Set a strong `JWT_SECRET` (≥ 32 bytes).
- [ ] Restrict `cors.allowed_origins` to your actual domains.
- [ ] Put the PHP server behind Apache/Nginx with HTTPS (Let's Encrypt).
- [ ] Use a dedicated MySQL user with limited privileges (not `root`).
- [ ] Enable daily backups of the `ludo_royale` database.
- [ ] Add a Redis-backed rate limiter (replace `RateLimit::check` file cache).
- [ ] Strip `android:usesCleartextTraffic="true"` and switch the API URL to HTTPS.
- [ ] Run `flutter build apk --release` (or `appbundle`) for distribution.

---

## 11. Next Steps

* Read the [Architecture overview](./architecture.md) to understand the
  engine's online/offline execution modes.
* Skim the [API documentation](./api-documentation.md) for the full
  endpoint reference.
* Consult the [Database design](./database-design.md) for table schemas
  and example queries.
