# Wire CRM

Wire CRM is a Laravel backoffice/portal that now also exposes a JSON API for a companion Flutter mobile application.

The web portal remains the primary backoffice interface.
The mobile app lives in [`flutter_app`](./flutter_app) and consumes the Laravel API only.
No direct database connection is used by Flutter.

## Current Modules

- Dashboard
- Clients
- Projects
- Quotes
- Products
- Invoices
- Finance
- Company
- Settings
- Interventions
- Wallets
- Authentication and passkeys

## Architecture

- Laravel: web portal, business rules, validation, PDF/doc generation, API
- Laravel Sanctum: token authentication for mobile/API access
- Inertia + Vue: backoffice UI
- Flutter: mobile app for Android and iOS in `flutter_app`

API routes are defined in [routes/api.php](./routes/api.php).
Web routes remain in [routes/web.php](./routes/web.php) and [routes/auth.php](./routes/auth.php).

## Run The Laravel Portal

Requirements:

- PHP 8.3+
- Composer
- Node.js + npm
- MySQL or MariaDB

Install dependencies:

```bash
composer install
npm install
```

Create and configure your environment:

```bash
cp .env.example .env
php artisan key:generate
```

Run migrations:

```bash
php artisan migrate
```

Start the application:

```bash
php artisan serve
npm run dev
```

Portal URLs:

- Web portal: `http://127.0.0.1:8000`
- Login: `http://127.0.0.1:8000/login`

## Run The API

The API is served by the same Laravel application.

Authentication:

- `POST /api/v1/auth/login`
- `POST /api/v1/auth/logout`
- `GET /api/v1/me`

The mobile app authenticates with Sanctum personal access tokens.

Start the API with the same Laravel server:

```bash
php artisan serve
```

Base URL example:

```text
http://127.0.0.1:8000/api/v1
```

List API routes:

```bash
php artisan route:list --path=api --except-vendor
```

## Run The Flutter App

Requirements:

- Flutter SDK
- Android Studio and/or Xcode

Install Flutter dependencies:

```bash
cd flutter_app
flutter pub get
```

Run on a device or simulator:

```bash
flutter run
```

Notes for local API access:

- Android emulator usually needs `http://10.0.2.2:8000/api/v1`
- iOS simulator usually works with `http://127.0.0.1:8000/api/v1`

The login screen lets you define the API base URL before authenticating.

## Validation

Flutter validation:

```bash
cd flutter_app
flutter analyze
flutter test
```

Laravel/API validation:

```bash
php artisan route:list --path=api --except-vendor
```

Portal smoke test:

```bash
curl -I http://127.0.0.1:8000/login
```

## Testing Notes

The default Laravel test suite in this repository currently depends on SQLite for the test environment.
If the `pdo_sqlite` PHP extension is not installed, several default auth/profile feature tests will fail before application logic is exercised.

There is also a default example test that expects `/` to return `200`, while this project redirects guests to `/login`.

## Security

Before committing or deploying:

- do not commit `.env`
- do not commit passwords, API tokens, or secrets
- review generated files and local caches
- make sure production credentials are injected through environment variables
