# Supabase Setup Guide — Omega Education Centre ERP

> This guide is written **specifically for this project's codebase** based on a full analysis of all source files.
> Follow every step in order. Do NOT skip steps.

---

## 🗺️ What You'll Set Up

| Step | What | Where |
|------|------|--------|
| 1 | Create Supabase Account & Project | supabase.com |
| 2 | Run `schema.sql` — Create all 20 tables | Supabase SQL Editor |
| 3 | Run `rls_policies.sql` — Enable security | Supabase SQL Editor |
| 4 | Run the migration script | Supabase SQL Editor |
| 5 | Configure Authentication settings | Supabase Dashboard |
| 6 | Get your API keys | Supabase Dashboard |
| 7 | Add `supabase_flutter` to Flutter | `pubspec.yaml` |
| 8 | Initialize Supabase in `main.dart` | Flutter code |
| 9 | Wire credentials into `backend_config.dart` | Flutter code |
| 10 | Test & Verify | App + Supabase Dashboard |

---

## STEP 1 — Create Your Supabase Account & Project

1. Open your browser and go to **[https://supabase.com](https://supabase.com)**
2. Click **"Start your project"** → Sign up with GitHub or email.
3. After logging in, click **"New Project"**.
4. Fill in the details exactly as follows:

   | Field | Value |
   |-------|-------|
   | **Organization** | (your personal org or create one) |
   | **Project Name** | `Omega Education Centre ERP` |
   | **Database Password** | Choose a **strong password** — save it in a password manager |
   | **Region** | `ap-south-1` (Mumbai) — closest for India |
   | **Plan** | Free tier is fine to start |

5. Click **"Create new project"**.
6. ⏳ Wait 2–3 minutes for the project to provision. You'll see a loading spinner. Do NOT refresh.

---

## STEP 2 — Run the Database Schema (`schema.sql`)

This creates all **20 PostgreSQL tables** the app uses.

1. In your Supabase Dashboard, look at the **left sidebar**.
2. Click **"SQL Editor"** (icon looks like `</>`).
3. Click **"+ New query"** (top right of the editor).
4. Now open this file on your computer:
   ```
   d:\User\Desktop\Omega\omega-education-centre-erp\04_Flutter_Project\omega_education_centre\supabase\schema.sql
   ```
5. **Select all** the content (Ctrl+A) and **Copy** (Ctrl+C).
6. Back in the Supabase SQL Editor, **paste** (Ctrl+V) into the query window.
7. Click the green **"Run"** button (or press `Ctrl+Enter`).
8. ✅ You should see: `Success. No rows returned` — this is correct.

**What this creates:**
`organisations`, `users`, `admins`, `teachers`, `students`, `fees`, `fee_payments`, `fee_installments`, `student_attendance`, `teacher_attendance`, `teacher_payments`, `teacher_pay_rate_history`, `tests`, `test_subjects`, `test_results`, `daily_class_records`, `timetable_entries`, `notices`, `notice_reads`, `devices`

> [!CAUTION]
> If you see any error in red, **do NOT proceed**. Check that you copied the complete file and paste again in a fresh query window.

---

## STEP 3 — Run the RLS Security Policies (`rls_policies.sql`)

This enables Row Level Security so each user only sees their own organisation's data.

1. In the SQL Editor, click **"+ New query"** again (don't reuse the previous tab).
2. Open this file on your computer:
   ```
   d:\User\Desktop\Omega\omega-education-centre-erp\04_Flutter_Project\omega_education_centre\supabase\rls_policies.sql
   ```
3. Copy the entire content and paste it into the new query window.
4. Click **"Run"**.
5. ✅ You should see: `Success. No rows returned`

**What this enforces:**
- Admins see all data within their organisation only
- Teachers see only their own profile, attendance & class records
- Students see only their own fees, attendance & test results
- Device registration is scoped to the logged-in user

---

## STEP 4 — Run the Migration Script (Seed Default Organisation)

This creates the default organisation record and repairs/recreates RLS helper functions.

1. In the SQL Editor, click **"+ New query"** again.
2. Open this file on your computer:
   ```
   d:\User\Desktop\Omega\omega-education-centre-erp\04_Flutter_Project\omega_education_centre\supabase\migrations\20260827000000_repair_auth_rls_functions.sql
   ```
3. Copy and paste the entire content into the query window.
4. Click **"Run"**.
5. ✅ You should see: `Success. 1 row affected` (for the organisation insert).

**What this does:**
- Inserts the default organisation: `ORG_OMEGA_DEFAULT` → `"Omega Education Centre"`
- Recreates the 3 helper functions: `current_org_id()`, `current_user_role()`, `current_user_ref_id()`
- Grants execute permissions to authenticated users

---

## STEP 5 — Configure Authentication Settings

The app uses **internal email identities** like `9498@omega.internal` for authentication, so you must disable email confirmation.

1. In the Supabase Dashboard left sidebar, click **"Authentication"**.
2. Click **"Providers"** in the sub-menu.
3. Click on **"Email"** provider.
4. Make these changes:

   | Setting | Value | Why |
   |---------|-------|-----|
   | **Confirm email** | 🔴 **OFF** (Disable) | Internal `@omega.internal` emails don't actually exist — no confirmation needed |
   | **Secure email change** | 🟢 **ON** (Enable) | Security best practice |

5. Click **"Save"**.

---

## STEP 6 — Get Your API Credentials

1. In the Supabase Dashboard left sidebar, click **"Project Settings"** (gear icon at bottom).
2. Click **"API"** in the sub-menu.
3. Copy these two values and save them somewhere safe:

   | Key | Where to find | What to save |
   |-----|---------------|--------------|
   | **Project URL** | Under "Project URL" | `https://xxxxxxxxxx.supabase.co` |
   | **anon public key** | Under "Project API keys" → `anon` row | The long JWT string |

> [!CAUTION]
> NEVER copy the `service_role` key into your Flutter app. Only the `anon` key goes in the app.

---

## STEP 7 — Add `supabase_flutter` Package to Flutter

Currently, your `pubspec.yaml` does NOT have the Supabase Flutter SDK. You need to add it.

1. Open the file:
   ```
   d:\User\Desktop\Omega\omega-education-centre-erp\04_Flutter_Project\omega_education_centre\pubspec.yaml
   ```
2. Find the `dependencies:` section (around line 30).
3. Add `supabase_flutter` right after `http: ^1.2.0`:

   ```yaml
   dependencies:
     flutter:
       sdk: flutter
     cupertino_icons: ^1.0.8
     sqflite: ^2.4.2
     path: ^1.9.1
     shared_preferences: ^2.3.5
     intl: ^0.20.2
     pointycastle: ^3.9.1
     crypto: ^3.0.3
     pdf: ^3.11.1
     printing: ^5.13.2
     excel: ^4.0.6
     path_provider: ^2.1.5
     share_plus: ^10.1.4
     open_filex: ^4.5.0
     archive: ^3.6.1
     image_picker: ^1.1.2
     file_picker: 10.0.0
     http: ^1.2.0
     supabase_flutter: ^2.9.0   # ← ADD THIS LINE
   ```

4. Save the file.
5. Open a terminal, navigate to the Flutter project folder, and run:
   ```powershell
   cd "d:\User\Desktop\Omega\omega-education-centre-erp\04_Flutter_Project\omega_education_centre"
   flutter pub get
   ```
6. ✅ Should complete with no errors. 

---

## STEP 8 — Initialize Supabase in `main.dart`

Open the file:
```
d:\User\Desktop\Omega\omega-education-centre-erp\04_Flutter_Project\omega_education_centre\lib\main.dart
```

Replace the **entire file** with this updated version:

```dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app.dart';
import 'features/backup/services/backup_service.dart';
import 'shared/config/backend_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load Supabase credentials from local SQLite settings (or defaults)
  await BackendConfig.loadSettingsFromDb();

  // Initialize Supabase Flutter SDK if credentials are configured
  if (BackendConfig.isBackendConfigured) {
    await Supabase.initialize(
      url: BackendConfig.supabaseUrl!,
      anonKey: BackendConfig.supabaseAnonKey!,
    );
  }

  // Run automatic daily backup asynchronously on startup
  BackupService().runAutomaticDailyBackup();

  runApp(const App());
}
```

> [!NOTE]
> The app is **offline-first** — if Supabase credentials are not available, the app still works using local SQLite. The `if (BackendConfig.isBackendConfigured)` guard ensures this.

---

## STEP 9 — Wire Your Credentials into `backend_config.dart`

Open the file:
```
d:\User\Desktop\Omega\omega-education-centre-erp\04_Flutter_Project\omega_education_centre\lib\shared\config\backend_config.dart
```

Find these two lines (around lines 11 and 17) and replace the placeholder values with your **real credentials from Step 6**:

```dart
// BEFORE (placeholder values):
static const String defaultProductionUrl = 'https://blipqkeaqjyockqprqsi.supabase.co';
static String? supabaseAnonKey = 'sb_publishable_SIy4fugozVmYZwCtUhWwSQ_wc_wTzqQ';

// AFTER (your real values):
static const String defaultProductionUrl = 'https://YOUR_PROJECT_ID.supabase.co';
static String? supabaseAnonKey = 'YOUR_ANON_PUBLIC_KEY_HERE';
```

> [!IMPORTANT]
> Replace `YOUR_PROJECT_ID` with your actual Supabase project ID (the part before `.supabase.co`)
> Replace `YOUR_ANON_PUBLIC_KEY_HERE` with the full `anon` key you copied in Step 6.

---

## STEP 10 — Verify Tables Were Created

1. In Supabase Dashboard, click **"Table Editor"** in the left sidebar.
2. You should see all **20 tables** listed:
   - `organisations`, `users`, `admins`, `teachers`, `students`
   - `fees`, `fee_payments`, `fee_installments`
   - `student_attendance`, `teacher_attendance`
   - `teacher_payments`, `teacher_pay_rate_history`
   - `tests`, `test_subjects`, `test_results`
   - `daily_class_records`, `timetable_entries`
   - `notices`, `notice_reads`, `devices`

3. Click the **`organisations`** table and verify the seed row exists:
   - `org_code`: `ORG_OMEGA_DEFAULT`
   - `name`: `Omega Education Centre`

---

## STEP 11 — Run the Flutter App

```powershell
cd "d:\User\Desktop\Omega\omega-education-centre-erp\04_Flutter_Project\omega_education_centre"
flutter run
```

The app should launch. Since it's offline-first, it will work even before Supabase sync features are fully wired. Supabase initialization happens silently in the background.

---

## ✅ Final Checklist

- [ ] Supabase project created (Mumbai region)
- [ ] `schema.sql` executed — 20 tables created ✓
- [ ] `rls_policies.sql` executed — RLS enabled ✓
- [ ] Migration script executed — default org seeded ✓
- [ ] Email confirmation turned **OFF** in Auth settings ✓
- [ ] Project URL & anon key copied securely ✓
- [ ] `supabase_flutter: ^2.9.0` added to `pubspec.yaml` ✓
- [ ] `flutter pub get` run successfully ✓
- [ ] `main.dart` updated with Supabase initialization ✓
- [ ] `backend_config.dart` updated with real credentials ✓
- [ ] Tables visible in Table Editor ✓
- [ ] Seed org row `ORG_OMEGA_DEFAULT` exists ✓
- [ ] App runs without errors ✓

---

## 🔐 Security Reminders

> [!WARNING]
> - The `supabase_flutter` anon key IS safe to include in Flutter app code — it's the public key.
> - NEVER add the `service_role` key anywhere in the Flutter codebase.
> - The `.gitignore` already exists — make sure `backend_config.dart` doesn't accidentally hold production keys if you push to a public repo. Consider moving keys to a `.env` file for production.

---

## ❓ Common Issues & Fixes

| Issue | Fix |
|-------|-----|
| SQL Editor shows red error on schema.sql | Open a fresh query tab, paste again, ensure full file was copied |
| `flutter pub get` fails | Check Flutter SDK is installed: `flutter doctor` |
| App crashes on start | Ensure `supabase_flutter` is in `pubspec.yaml` and `flutter pub get` was run |
| Tables not visible in Table Editor | Refresh the page; wait 30s after running SQL |
| Auth not working | Verify email confirmation is turned OFF in Auth → Providers → Email |
| `isBackendConfigured` returns false | Check both `supabaseUrl` and `supabaseAnonKey` are set in `backend_config.dart` |
