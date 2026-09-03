# Development Guide — Omega Education Centre ERP

> Everything you need to know to run, build, test, and contribute to this Flutter project.

---

## Prerequisites

| Tool | Minimum Version | Notes |
|------|----------------|-------|
| **Flutter SDK** | 3.12.2+ | Required. The installed version on this machine is 3.47.2. |
| **Dart SDK** | 3.12.2+ | Bundled with Flutter SDK. |
| **Android Studio** or **VS Code** | Latest stable | With Flutter/Dart extensions installed. |
| **Chrome** | Latest | For web development (`flutter run -d chrome`). |
| **Git** | Latest | For version control. |

### Verify your setup

```bash
flutter doctor
```

Fix any issues reported. On this machine the known status is:

- ✅ Flutter SDK, Windows, Chrome, Network
- ⚠️ Android toolchain — Android SDK is present but license acceptance is pending. Run:
  ```bash
  flutter doctor --android-licenses
  ```
- ❌ Visual Studio — required only for Windows desktop builds. Download from [visualstudio.microsoft.com](https://visualstudio.microsoft.com/downloads/) with the "Desktop development with C++" workload.

---

## Quick Start

```bash
# 1. Clone the repository
git clone <repository-url>
cd omega_education_centre

# 2. Install dependencies
flutter pub get

# 3. Run the app
flutter run
```

The app works **fully offline** by default using local SQLite. No cloud setup is required to get started.

---

## Running the App

### Auto-detect device

```bash
flutter run
```

### Run on a specific platform

```bash
# Android emulator or connected device
flutter run -d android

# Chrome browser
flutter run -d chrome

# Windows desktop (requires Visual Studio)
flutter run -d windows

# macOS desktop (requires Xcode)
flutter run -d macos

# List all available devices
flutter devices
```

### Hot Reload & Hot Restart

- **Hot Reload** (`r`): Injects changes without losing app state. Fast iteration for UI tweaks.
- **Hot Restart** (`R`): Restarts the app from scratch. Use when state or initialisation logic changes.

### Run without code generation

```bash
# Skip DDC compilation (faster startup, larger bundle)
flutter run --no-track-widget-creation
```

---

## Building the App

### Android

```bash
# Debug APK (default, installable on devices/emulators)
flutter build apk --debug

# Release APK (optimised, for distribution)
flutter build apk --release

# App Bundle (for Google Play Store)
flutter build appbundle --release
```

Output paths:
- APK: `build/app/outputs/flutter-apk/app-debug.apk` / `app-release.apk`
- AAB: `build/app/outputs/bundle/release/app-release.aab`

### Web

```bash
flutter build web --release
```

Output path: `build/web/` (can be deployed to any static host).

### Windows Desktop

```bash
flutter build windows --release
```

Output path: `build/windows/x64/runner/Release/`

### macOS Desktop

```bash
flutter build macos --release
```

---

## Testing

### Run all tests

```bash
flutter test
```

### Run specific test suites

```bash
flutter test test/authentication/
flutter test test/attendance/
flutter test test/fees/
flutter test test/backend/
flutter test test/backup/
flutter test test/class_register/
flutter test test/dashboard/
flutter test test/notices/
flutter test test/salary/
flutter test test/settings/
flutter test test/students/
flutter test test/teachers/
flutter test test/tests_results/
flutter test test/timetable/
flutter test test/integration/
```

### Run a single test file

```bash
flutter test test/teachers/teacher_system_test.dart
```

### Run with coverage report

```bash
flutter test --coverage

# View the coverage report (requires lcov)
genhtml coverage/lcov.info -o coverage/html
# Open coverage/html/index.html in a browser
```

### Run integration tests

```bash
flutter test test/integration/
```

> **Note:** Tests use `sqflite_common_ffi` for desktop SQLite emulation. No Android emulator is required to run tests.

---

## Code Quality & Analysis

### Static analysis

```bash
flutter analyze
```

This runs the Dart analyzer with the rules defined in `analysis_options.yaml` (uses `flutter_lints`).

### Lint configuration

The project uses the recommended lint set from `flutter_lints`. Lint rules are configured in `analysis_options.yaml`:

```yaml
# Currently enabled: full flutter_lints/flutter.yaml set
# Platform directories (android/, ios/, web/, windows/, macos/, linux/, build/) are excluded from analysis.
```

### Format code

```bash
dart format lib/ test/ --set-exit-if-changed
```

---

## Database

The app uses **SQLite** via `sqflite` with **versioned migrations** (currently at v18). The database file is stored locally on the device as `omega_education.db`.

### Key files

| File | Purpose |
|------|---------|
| `lib/core/database/database_helper.dart` | Singleton `DatabaseHelper` — handles creation, migrations, and table definitions. |

### Schema version history

| Version | Migration |
|---------|-----------|
| v1 | Initial `students` table |
| v2 | Adds `teachers`, `attendance`, `fees`, `tests`, `users` (9 new tables) |
| v3 | Extends fees with payment method, adds `fee_installments` |
| v4 | Adds `updatedAt` to `teachers` |
| v5 | Adds `remarks`/timestamps to attendance tables |
| v6 | Extends `teacher_payments` with year, payment method, timestamps |
| v7 | Creates `teacher_pay_rate_history` |
| v8 | Multi-subject test support with `test_subjects` |
| v9 | Recreates `tests` table to fix NOT NULL constraint |
| v10 | Recreates `test_results` table to fix UNIQUE constraint |
| v11 | Creates `daily_class_records` |
| v12 | Creates `timetable_entries` and `notices` |
| v13 | Adds `notice_reads`, extends timetable and notices |
| v14 | Extends `fee_payments` with receipt number |
| v15 | Adds `profilePhotoPath` to students and teachers |
| v16 | Creates `app_settings` key-value store |
| v17 | Non-destructive notices table column repair |
| v18 | Creates `sync_queue` table, adds sync columns |

### Adding a new migration

1. Increment the `version` number in `_initDatabase()`.
2. Add a new `if (oldVersion < N)` block in `_onUpgrade()`.
3. Never delete data — use `ALTER TABLE` or safe table recreation.
4. Use `try { ... } catch (_) {}` for optional column additions.

### Cloud Backend (Optional — Supabase)

The app supports optional cloud sync with **Supabase** (PostgreSQL + Auth + RLS). See [Supabase Setup Guide](supabase_setup_guide.md) for full instructions.

**SQL files** are in the `supabase/` directory:

| File | Purpose |
|------|---------|
| `supabase/schema.sql` | Creates all 20 PostgreSQL tables |
| `supabase/rls_policies.sql` | Row Level Security policies |
| `supabase/migrations/` | Migration scripts (seed data, RLS functions) |

---

## Project Structure

```
lib/
├── main.dart                        # App entry point (Supabase init, backup, run)
├── app/
│   └── app.dart                     # MaterialApp, theme, startup wrapper
├── core/
│   └── database/
│       └── database_helper.dart     # SQLite singleton, v18 migrations
├── features/                        # Feature-first modules
│   ├── attendance/                  # Student & teacher attendance
│   ├── authentication/              # Login, session, auth repository
│   ├── backup/                      # Backup, restore, disaster recovery
│   ├── class_register/              # Daily class records
│   ├── dashboard/                   # Admin, teacher & student dashboards
│   ├── fees/                        # Fee plans, payments, receipts
│   ├── notices/                     # Announcements & read status
│   ├── salary/                      # Teacher salary & payments
│   ├── settings/                    # Institute configuration
│   ├── splash/                      # Splash screen
│   ├── students/                    # Student CRUD & profiles
│   ├── teachers/                    # Teacher CRUD & profiles
│   ├── tests/                       # Exams, results & report exports
│   └── timetable/                   # Class scheduling
└── shared/                          # Cross-cutting concerns
    ├── config/                      # Backend configuration
    ├── constants/                   # App-wide constants
    ├── services/                    # Sync engine, Supabase auth
    ├── themes/                      # Material 3 theme
    ├── utils/                       # Session, password, photo helpers
    └── widgets/                     # Shared reusable widgets
```

### Architecture patterns

- **Feature-first organisation** — each feature is self-contained under `lib/features/`.
- **State management** — `StatefulWidget` + `ValueNotifier`. No external state management library (no Provider, Riverpod, Bloc, etc.).
- **Repository pattern** — data access is abstracted through repository classes.
- **Singleton pattern** — `DatabaseHelper`, `SyncEngine`, and `AppSession` are singletons.

---

## Common Development Tasks

### Install / update dependencies

```bash
flutter pub get                # Install dependencies
flutter pub upgrade            # Upgrade within constraints
flutter pub upgrade --major-versions  # Upgrade to latest major versions
flutter pub outdated           # Check for outdated packages
```

### Generate app icons

```bash
dart run flutter_launcher_icons
```

Configured in `pubspec.yaml` to use `assets/logo/app_icon.png`.

### Check available devices

```bash
flutter devices
flutter emulators
```

---

## Backup & Restore

- **Automatic backup** runs on every app startup via `BackupService().runAutomaticDailyBackup()`.
- **Manual backup** is available from the Settings screen.
- The SQLite database file (`omega_education.db`) can be exported and imported.

---

## Security Notes

- **Admin auth** — handled by Supabase Auth (no local password storage).
- **Teacher/Student auth** — PBKDF2 salted password hashing locally.
- **Profile photos** — stored locally on device only, never uploaded to cloud.
- **Service role keys** — NEVER included in Flutter app code (only `anon` key).
- **`backend_config.dart`** — gitignored. Contains Supabase credentials. Never commit this file.

---

## Troubleshooting

| Issue | Solution |
|-------|----------|
| `flutter pub get` fails | Run `flutter doctor` to check SDK installation. |
| Android build fails | Accept SDK licenses: `flutter doctor --android-licenses` |
| Windows build fails | Install Visual Studio with "Desktop development with C++" workload. |
| App crashes on startup | Ensure `flutter pub get` was run. Check `lib/main.dart` and Supabase init. |
| Tests fail with SQLite errors | Tests use `sqflite_common_ffi`. Ensure desktop FFI is available (Windows/macOS/Linux). |
| Hot reload not working | Try Hot Restart (`R`). If persists, `flutter clean && flutter pub get` then `flutter run`. |
| Build cache issues | Run `flutter clean` then `flutter pub get` and rebuild. |
| "No device found" | Run `flutter devices`. Start an emulator or connect a device. For web: `flutter run -d chrome`. |
| Supabase sync not working | Verify `backend_config.dart` has valid credentials. See [Supabase Setup Guide](supabase_setup_guide.md). |

---

## Useful Commands Reference

```bash
# Full clean build cycle
flutter clean
flutter pub get
flutter run

# Analyse code
flutter analyze

# Run all tests
flutter test

# Build release APK
flutter build apk --release

# Build web
flutter build web --release

# Check Flutter installation
flutter doctor -v

# Upgrade Flutter SDK
flutter upgrade
```
