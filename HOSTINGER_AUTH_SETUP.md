# SehatRoute login/register — Hostinger setup

Use this architecture:

```text
Flutter app  →  HTTPS Node.js API  →  MySQL
```

Do not connect Flutter directly to MySQL. A direct connection would expose the database username and password inside the APK.

## 1. Create the MySQL database

In Hostinger hPanel:

1. Create a MySQL database and database user.
2. Give that user access to the database.
3. Open phpMyAdmin for the database.
4. Import `backend/database.sql`.

The import creates the `users` table. User passwords are stored only as bcrypt hashes.

## 2. Create the Node.js application

Create a Node.js application in Hostinger and use Node.js 20 or newer.

Upload the contents of the `backend` folder as the application files. The application entry file is:

```text
server.js
```

Install packages and start the server:

```bash
npm install
npm start
```

If hPanel has separate fields, set the startup file to `server.js` and use its Restart button after every server change.

## 3. Add environment variables

Copy the names from `backend/.env.example` into Hostinger's environment-variable section. Example:

```env
NODE_ENV=production
PORT=3000

DB_HOST=your_hostinger_mysql_host
DB_PORT=3306
DB_NAME=your_database_name
DB_USER=your_database_user
DB_PASSWORD=your_database_password
DB_CONNECTION_LIMIT=10

JWT_SECRET=put_a_long_random_secret_here_at_least_32_characters
JWT_EXPIRES_IN=7d

CLIENT_ORIGINS=https://your-flutter-web-domain.com
```

Notes:

- Generate a fresh, random `JWT_SECRET`; do not reuse your MySQL password.
- Do not upload a real `.env` file to GitHub or share its values in chat.
- `CLIENT_ORIGINS` is a comma-separated list. It is needed for Flutter Web. Android/iOS requests do not send a browser origin.
- Hostinger may inject `PORT` automatically. If it does, keep the injected value.

## 4. Connect an HTTPS domain

Connect an API domain or subdomain to the Node.js application, for example:

```text
https://api.yourdomain.com
```

Enable SSL. Then open this URL to confirm both Node.js and MySQL are working:

```text
https://api.yourdomain.com/health
```

Expected result:

```json
{"success":true,"service":"sehatroute-auth-api","database":"connected"}
```

## 5. Run the Flutter app

From the Flutter project folder in PowerShell:

```powershell
flutter clean
flutter pub get
flutter run --dart-define=API_BASE_URL=https://api.yourdomain.com/api
```

For a release APK:

```powershell
flutter build apk --release --dart-define=API_BASE_URL=https://api.yourdomain.com/api
```

Replace `api.yourdomain.com` with the real Hostinger API domain. Do not use `localhost` on a physical Android phone.

## 6. Android internet permission

After generating the Android platform with `flutter create --platforms=android .`, confirm that `android/app/src/main/AndroidManifest.xml` contains this line above `<application>`:

```xml
<uses-permission android:name="android.permission.INTERNET" />
```

Use Android `minSdk` 23 or higher because the app stores the JWT in encrypted secure storage.

## Included API routes

| Method | Route | Purpose |
| --- | --- | --- |
| `GET` | `/health` | Server/database check |
| `POST` | `/api/auth/register` | Create account and return JWT |
| `POST` | `/api/auth/login` | Verify password and return JWT |
| `GET` | `/api/auth/me` | Return the logged-in user |

The Flutter login and sign-up tabs already call these routes. The signed-in user's name/email appear in the profile menu, the JWT survives app restarts in secure storage, and Logout clears it.

## Quick API test (optional)

After deployment, PowerShell can test registration:

```powershell
$body = @{ name = "Test User"; email = "test@example.com"; password = "StrongPass123" } | ConvertTo-Json
Invoke-RestMethod -Method Post -Uri "https://api.yourdomain.com/api/auth/register" -ContentType "application/json" -Body $body
```

Use a new email each time. Delete test accounts later from phpMyAdmin if they are not needed.
