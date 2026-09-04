# Omega Education Centre ERP — Improvements Analysis

> A comprehensive audit of every gap, missing feature, and improvement needed to transform this project from an internal tool into a production-grade, sellable SaaS product for coaching centres across India.

---

## Audit Summary

| Category | Total Items | P0 (Critical) ✅ | P1 (High) ✅ | P2 (Medium) | P3 (Low) |
|----------|-------------|----------------|-----------|-------------|----------|
| Platform & Infrastructure | 6 | 2 ✅ | 1 ✅ | 1 | 2 |
| Security & Compliance | 7 | 3 ✅ | 2 ✅ | 1 | 1 |
| Sync & Data | 3 | 1 ✅ | 2 ✅ | 0 | 0 |
| Features (Client-Requested) | 11 | 0 | 4 ✅ | 3 ✅ | 2 |
| UI/UX & Polish | 6 | 0 | 0 | 4 ✅ | 2 |
| Architecture & Code Quality | 4 | 0 | 0 | 0 | 4 |
| Testing & QA | 3 | 0 | 0 | 1 | 2 |
| **Totals** | **40** | **6/6 ✅** | **9/9 ✅** | **8/12** | **13** |

---

## Priority Definitions

| Priority | Meaning | Timeline |
|----------|---------|----------|
| 🔴 **P0** | Critical — App is broken, insecure, or non-compliant. Blocks any sale. | Must fix before first client deployment |
| 🟠 **P1** | High — Missing features clients explicitly ask for. Blocks deal closure. | Within first 4 weeks of active development |
| 🟡 **P2** | Medium — Expected in a polished product. Differentiator from competitors. | Within 8 weeks |
| 🟢 **P3** | Low — Nice-to-have. Improves maintainability and long-term scalability. | Within 12 weeks |

---

## 🔴 P0 — Critical (6 Items)

These must be fixed before selling to any client. The app is either broken, insecure, or legally non-compliant without them.

---

### P0-01: Web Platform is Non-Functional

**Area:** Platform & Infrastructure
**File(s):** `lib/features/authentication/repository/auth_repository.dart`, `lib/features/dashboard/dashboard_screen.dart`

**Current State:**
- Teachers and Students **cannot log in on web** — the auth repository returns an error for all non-admin users when `kIsWeb` is true.
- The Admin dashboard on web renders **all metrics as zero** — the `_loadDashboardData()` method short-circuits when `kIsWeb` is true, setting everything to empty lists and zero counts.
- The `SyncEngine` skips all operations on web (`kIsWeb` check).

**Impact:** Half the app is non-functional on web. Clients will try the web version first (it's easier to access). A demo on web will show a blank dashboard.

**Fix:**
1. Replace the `kIsWeb` short-circuits with a proper data source abstraction.
2. For web, use Supabase REST API directly (skip SQLite) for all read/write operations.
3. Ensure Teacher/Student login works on web via Supabase Auth.
4. Render dashboard data from Supabase on web.

---

### P0-02: Supabase Credentials Hardcoded in Source Code

**Area:** Security & Compliance
**File:** `lib/shared/config/backend_config.dart`

**Current State:**
```dart
static const String defaultProductionUrl = 'https://kujbdqyhlfxyeximralc.supabase.co';
static String? supabaseAnonKey = 'sb_publishable_hfMkgN3EdR_Zr8wsY1OvYQ_aY-S6saG';
```

The Supabase project URL and anon key are hardcoded. While `backend_config.dart` is gitignored, the URL is predictable and the key is a public key. Any attacker can enumerate Supabase projects from the URL pattern.

**Impact:** Security vulnerability. Also, every new client deployment requires editing source code.

**Fix:**
1. Move credentials to a runtime configuration mechanism (e.g., `--dart-define` at build time, or a setup wizard that writes to `app_settings`).
2. Never ship default production credentials in source code.
3. Add a first-run setup screen where the admin enters their Supabase URL and key.

---

### P0-03: No Data Encryption at Rest

**Area:** Security & Compliance
**File:** `lib/core/database/database_helper.dart`

**Current State:**
The SQLite database (`omega_education.db`) is stored as a plain file on the device. If a phone is stolen or the file is extracted via ADB, all data is readable — student names, phone numbers, fee amounts, attendance records, passwords (though hashed).

**Impact:** Violates India's Digital Personal Data Protection Act (DPDP) 2023, which requires "reasonable security safeguards" for personal data. This is student PII including names, phone numbers, addresses, and financial records of minors.

**Fix:**
1. Use `sqflite_sqlcipher` (SQLCipher-based SQLite) for encrypted database storage.
2. Encrypt the database with a device-derived key.
3. Ensure backup files are also encrypted.

---

### P0-04: No Session Timeout / Auto-Logout

**Area:** Security & Compliance
**File:** `lib/shared/utils/app_session.dart`, `lib/app/app.dart`

**Current State:**
If an admin walks away from the app with the session active, the session persists indefinitely. The `restorePersistedSession()` method restores sessions from `SharedPreferences` without any expiry check.

**Impact:** On shared devices (common in coaching centres), an unattended session means anyone can access the admin panel, view financial data, or modify student records.

**Fix:**
1. Add a session timestamp to `SharedPreferences` on every login and activity.
2. Implement an `AppLifecycleState` listener that checks elapsed time when the app resumes.
3. Auto-logout after 15 minutes of inactivity (configurable).
4. Show a warning dialog before auto-logout.

---

### P0-05: No Brute-Force Login Protection

**Area:** Security & Compliance
**File:** `lib/features/authentication/repository/auth_repository.dart`

**Current State:**
The login method has no rate limiting. An attacker can try unlimited password combinations. The only protection is the password itself.

**Impact:** Weak passwords (common in coaching centres) can be brute-forced. Combined with the 4-character minimum, this is exploitable.

**Fix:**
1. Implement lockout after 5 failed attempts (5-minute cooldown).
2. Implement progressive lockout: 5 attempts → 5 min, 10 attempts → 30 min, 15 attempts → 1 hour.
3. Store failed attempt count in `SharedPreferences` or `app_settings` table.
4. Show remaining attempts and lockout timer on the login screen.

---

### P0-06: Minimum Password Length is 4 Characters

**Area:** Security & Compliance
**File:** `lib/features/authentication/repository/auth_repository.dart`, `lib/features/authentication/login/login_screen.dart`

**Current State:**
```dart
if (value.length < 4) {
  return "Password must be at least 4 characters";
}
```

**Impact:** 4-character passwords can be cracked in seconds. This is unacceptable for an app handling financial transactions and student PII.

**Fix:**
1. Increase minimum password length to 8 characters.
2. Add complexity requirements: at least one uppercase, one lowercase, one digit.
3. Update the login screen validator and the `changePassword` / `adminResetPassword` methods.
4. Add a password strength indicator on the password creation screen.

---

## 🟠 P1 — High Priority (9 Items)

These are the features and fixes that clients explicitly ask for. Without them, you cannot close deals.

---

### P1-01: Parent/Guardian Portal

**Area:** Features (Client-Requested)
**File(s):** New feature module `lib/features/parent_portal/`

**Current State:**
No parent-facing functionality exists. Parents have no way to view their child's data.

**Impact:** This is the #1 feature coaching centre owners ask for. Parents want to track attendance, fees, and results remotely. Without this, you're competing with Excel spreadsheets.

**What to Build:**
1. Parent login (linked to student record via `fatherName`/`mobile`).
2. Parent dashboard showing: child's attendance %, fee dues, latest exam results, notices.
3. Read-only view — parents cannot modify data.
4. Web and mobile access.
5. Optional: push notifications for fee dues and exam results.

---

### P1-02: Complete Cloud Sync Engine

**Area:** Sync & Data
**File:** `lib/shared/services/sync_engine.dart`

**Current State:**
The sync engine only syncs 3 tables: `students`, `teachers`, `users`. The following are NOT synced:

| Module | Synced? | Tables Affected |
|--------|---------|-----------------|
| Fee Management | ❌ | `fees`, `fee_payments`, `fee_installments` |
| Student Attendance | ❌ | `student_attendance` |
| Teacher Attendance | ❌ | `teacher_attendance` |
| Tests & Results | ❌ | `tests`, `test_subjects`, `test_results` |
| Teacher Salary | ❌ | `teacher_payments`, `teacher_pay_rate_history` |
| Notices | ❌ | `notices`, `notice_reads` |
| Timetable | ❌ | `timetable_entries` |
| Daily Class Records | ❌ | `daily_class_records` |

**Impact:** Multi-device usage is broken. If a fee payment is recorded on Device A, it won't appear on Device B. This defeats the purpose of cloud sync.

**Fix:**
1. Add sync support for all 17 remaining tables.
2. Implement conflict resolution strategy (last-write-wins for most, append-only for payments).
3. Extend the `SyncEngine` with entity-specific sync methods.
4. Add sync status indicators per module.

---

### P1-03: Push Notifications (FCM) ✅ DONE

**Area:** Features (Client-Requested)
**File(s):** `lib/shared/services/push_notification_service.dart`, `lib/shared/services/notification_service.dart`, `lib/shared/screens/notification_center_screen.dart`, `lib/features/settings/screens/notification_preferences_screen.dart`, `lib/main.dart`

**Current State:**
✅ Firebase Cloud Messaging (FCM) integration implemented via `PushNotificationService`.
✅ In-app notification center with read/unread status, swipe-to-delete, type-based icons.
✅ Notification preferences screen (per user, per type: fee reminders, exam alerts, attendance, general notices).
✅ FCM token management with automatic refresh and local persistence.
✅ Background message handler for notifications received when app is in background/terminated.
✅ Graceful degradation — app works without Firebase (push disabled, in-app notifications still work).
✅ Topic subscription support for class-specific and role-based notifications.
✅ Push status indicator in notification center.

**Remaining:**
- Server-side notification triggers (Supabase Edge Functions for automated fee reminders, exam alerts).
- Firebase project setup (`firebase_options.dart`, `google-services.json`, `GoogleService-Info.plist`).

**What was Built:**
1. `PushNotificationService` — FCM initialization, token management, foreground/background message handling, topic subscriptions.
2. `NotificationService` — In-app notifications with FCM integration, read/unread tracking.
3. `NotificationCenterScreen` — UI with FCM status badge, notification list, swipe-to-delete.
4. `NotificationPreferencesScreen` — Per-user, per-type notification preferences.
5. `main.dart` — Firebase initialization with graceful fallback, background handler registration.

---

### P1-04: Analytics & Reports Dashboard

**Area:** Features (Client-Requested)
**File(s):** New screen `lib/features/analytics/`

**Current State:**
The dashboard shows only today's snapshot. No historical trends, no charts, no exportable reports.

**Impact:** Management needs trend data to make decisions. "How are fee collections trending?" "Which class has the worst attendance?" — these questions cannot be answered.

**What to Build:**
1. Monthly/yearly fee collection trend chart.
2. Attendance trend analysis (class-wise, student-wise).
3. Teacher performance metrics (hours taught, classes conducted).
4. Class-wise comparison reports.
5. Export to PDF and Excel.
6. Date range selector for all analytics.

---

### P1-05: Online Fee Payment Gateway

**Area:** Features (Client-Requested)
**File(s):** New module `lib/features/payments/`

**Current State:**
Fee payments are recorded manually (cash/UPI noted in text). No actual payment processing.

**Impact:** Coaching centres process hundreds of fee payments. Manual recording is error-prone and doesn't provide receipts to parents.

**What to Build:**
1. Razorpay or PhonePe integration for UPI/card/net-banking payments.
2. Automated receipt generation on successful payment.
3. Payment status tracking (pending, successful, failed, refunded).
4. Parent-facing payment portal (web).
5. Admin dashboard for payment reconciliation.

---

### P1-06: Onboarding Wizard

**Area:** Features (Client-Requested)
**File(s):** New screen `lib/features/onboarding/`

**Current State:**
New installations see a login screen with no guidance. The admin must manually configure everything.

**Impact:** First-time users are lost. High drop-off rate. Support burden increases.

**What to Build:**
1. First-run setup wizard (3-5 steps):
   - Step 1: Institute name, address, phone, email.
   - Step 2: Select boards (CBSE, BSEB, ICSE, etc.).
   - Step 3: Select classes (1-12, Foundation, etc.).
   - Step 4: Create admin account.
   - Step 5: (Optional) Connect Supabase for cloud sync.
2. Progress indicator and ability to skip steps.
3. Store completion status so wizard runs only once.
4. Generate sample data option (5 students, 2 teachers, 1 class record) for demo.

---

### P1-07: Bulk CSV Import/Export

**Area:** Features (Client-Requested)
**File(s):** New service `lib/shared/services/csv_import_service.dart`

**Current State:**
Students and teachers must be added one at a time via forms.

**Impact:** A coaching centre migrating from Excel has 200+ students. Adding them one by one is impractical. This is a deal-breaker for migration.

**What to Build:**
1. CSV import for students (name, father name, mobile, class, board, roll no).
2. CSV import for teachers (name, mobile, subject, qualification, pay rate).
3. CSV template download (sample file).
4. Validation and error reporting before import.
5. Duplicate detection (by mobile or roll number).
6. Export existing data to CSV.

---

### P1-08: SMS/WhatsApp Integration for Fee Reminders

**Area:** Features (Client-Requested)
**File(s):** New service `lib/shared/services/messaging_service.dart`

**Current State:**
No messaging capability. Fee reminders require manual phone calls.

**Impact:** Coaching centres lose revenue because parents forget to pay. Automated reminders significantly improve collection rates.

**What to Build:**
1. SMS gateway integration (MSG91 or Twilio for India).
2. Automated fee due reminders (7 days before, on due date, 7 days after).
3. Template management (customizable messages).
4. WhatsApp Business API integration (optional, higher cost).
5. Message delivery status tracking.

---

### P1-09: Audit Trail for Financial Transactions

**Area:** Security & Compliance
**File(s):** New table `audit_log`, new service `lib/shared/services/audit_service.dart`

**Current State:**
Fee payments are append-only (good), but there's no record of who initiated the payment, when, or from which device. Teacher salary payments have no audit trail.

**Impact:** For financial accountability, every transaction needs an immutable record of the actor, timestamp, and device. Essential for any coaching centre with multiple admins.

**What to Build:**
1. New `audit_log` table (action, entity_type, entity_id, actor, timestamp, device_id, old_value, new_value).
2. Audit logging for: fee payments, salary payments, student admission/deletion, teacher addition/deactivation, settings changes.
3. Audit log viewer for admin (filterable by date, action, entity).
4. Audit log export to CSV/PDF.

---

## 🟡 P2 — Medium Priority (12 Items)

These are expected in a polished product. They differentiate you from basic tools.

---

### P2-01: Dark Mode ✅ DONE

**Area:** UI/UX & Polish
**File(s):** `lib/shared/themes/app_theme.dart`, `lib/shared/services/theme_service.dart`, `lib/app/app.dart`, `lib/main.dart`, `lib/features/settings/screens/institute_settings_screen.dart`

**What was Built:**
1. `AppTheme.darkTheme` with full Material 3 dark color scheme (scaffold, cards, inputs, dialogs, buttons, chips, dividers).
2. Theme toggle in Settings → Display tab (System / Light / Dark radio cards).
3. `ThemeService` persists theme preference in SharedPreferences.
4. System theme preference as default for new installs.
5. `AnimatedBuilder` in app.dart for live theme switching.
6. Dark mode variants for fee status badges.

---

### P2-02: Localization (Hindi + English) ✅ DONE

**Area:** UI/UX & Polish
**File(s):** `lib/l10n/app_translations.dart` (new), `lib/shared/services/localization_service.dart` (new), `lib/app/app.dart`, `lib/main.dart`, `lib/features/settings/screens/institute_settings_screen.dart`

**What was Built:**
1. `AppTranslations` class with 100+ translated strings across 15 categories (Navigation, Auth, Dashboard, Students, Teachers, Attendance, Fees, Tests, Notices, Homework, Calendar, Salary, Settings, Batches, Messages).
2. `AppTranslationsDelegate` for Flutter's localization system.
3. `LocalizationService` with SharedPreferences persistence.
4. Language selector in Settings → Display tab (English/Hindi radio cards).
5. `MaterialApp` configured with `locale`, `supportedLocales`, `localizationsDelegates`.
6. Live language switching via `AnimatedBuilder`.

**Note:** Screen migration to use `AppTranslations.of(context)` is incremental — infrastructure is complete.

---

### P2-03: Biometric Authentication

**Area:** Security & Compliance
**File:** `lib/features/authentication/`

**Current State:**
No fingerprint/face unlock support.

**What to Build:**
1. Add `local_auth` package.
2. Optional biometric login for returning users (after first password login).
3. Biometric preference toggle in settings.
4. Fall back to password if biometric fails.

---

### P2-04: Skeleton Loading States ✅ DONE

**Area:** UI/UX & Polish
**File(s):** `lib/shared/widgets/skeleton_widgets.dart` (new), `pubspec.yaml`, + 8 screen files

**What was Built:**
1. `SkeletonWidgets` class with 8 reusable widgets: `pageSkeleton`, `gridSkeleton`, `listTileSkeleton`, `cardSkeleton`, `statCardSkeleton`, `textSkeleton`, `chipRowSkeleton`, `tableRowSkeleton`.
2. `shimmer` package added for animated loading effects.
3. Replaced `CircularProgressIndicator` in 8 key screens: admin dashboard, teacher dashboard, student dashboard, student list, teacher list, fee dashboard, analytics dashboard, salary dashboard.
4. All skeletons respect dark mode (darker greys in dark theme).

---

### P2-05: Empty State Illustrations ✅ DONE

**Area:** UI/UX & Polish
**File(s):** `lib/shared/widgets/empty_state_widget.dart` (new), + 6 screen files

**What was Built:**
1. `EmptyStateWidget` with icon, title, subtitle, CTA button, dark mode support.
2. 10 preset constructors: `.noStudents()`, `.noTeachers()`, `.noNotices()`, `.noTests()`, `.noTimetable()`, `.noFeeRecords()`, `.noAttendance()`, `.noSalaryRecords()`, `.noAuditLogs()`, `.noSearchResults()`.
3. Replaced plain text empty states in 6 screens: student list, teacher list, notices, tests, timetable, salary dashboard.
4. CTA buttons navigate to the relevant "add/create" screen.

---

### P2-06: Student ID Card Generation

**Area:** Features (Client-Requested)
**File(s):** New service `lib/features/students/services/id_card_service.dart`

**Current State:**
No ID card generation.

**What to Build:**
1. Template-based ID card generator (front/back).
2. Include: photo, name, class, roll number, board, institute logo, emergency contact.
3. Export as PDF (printable on card stock).
4. Bulk generation (all students in a class).
5. Customizable template (colors, fields).

---

### P2-07: Academic Calendar

**Area:** Features (Client-Requested)
**File(s):** New module `lib/features/academic_calendar/`

**Current State:**
No concept of academic calendar, holidays, or term dates.

**What to Build:**
1. Holiday management (add/edit/delete holidays).
2. Term dates (Term 1, Term 2, etc.).
3. Event management (annual day, parent-teacher meeting, etc.).
4. Calendar view with color-coded events.
5. Integration with timetable (holidays affect scheduling).

---

### P2-08: Homework/Assignment Tracking

**Area:** Features (Client-Requested)
**File(s):** New module `lib/features/homework/`

**Current State:**
Homework is a text field in `daily_class_records`. No dedicated tracking.

**What to Build:**
1. Homework assignment screen (teacher sets homework per class/subject).
2. Due date tracking.
3. Student submission status (submitted/not submitted).
4. Parent view of pending homework.
5. Homework reminder notifications.

---

### P2-09: Multi-Branch Support

**Area:** Features (Client-Requested)
**File(s):** New module `lib/features/branches/`, schema changes

**Current State:**
Single-institute only. No concept of branches.

**What to Build:**
1. Branch entity (name, address, phone, manager).
2. Branch-level data isolation (each branch sees only its data).
3. Central admin view across all branches.
4. Cross-branch reports.
5. Branch switching for admin users.

---

### P2-10: Subscription/License System

**Area:** Features (Client-Requested)
**File(s):** New service `lib/shared/services/license_service.dart`

**Current State:**
No licensing mechanism. Anyone can use the app indefinitely.

**What to Build:**
1. License key generation and validation.
2. Feature gating (free tier: basic features, paid tier: full features).
3. Trial period (14-30 days).
4. Expiry handling and renewal reminders.
5. Online license validation via Supabase.

---

### P2-11: Batch/Schedule Management

**Area:** Features (Client-Requested)
**File(s):** New entity in `lib/features/batches/`

**Current State:**
Batches are free-text fields. No structured batch management.

**What to Build:**
1. Batch entity (name, timing, teacher, class, board).
2. Batch-wise student assignment.
3. Batch-wise timetable.
4. Batch-wise attendance.
5. Batch-wise fee plans.

---

### P2-12: Transfer Certificate / Migration Certificate

**Area:** Features (Client-Requested)
**File(s):** New service `lib/features/students/services/certificate_service.dart`

**Current State:**
No certificate generation.

**What to Build:**
1. Transfer Certificate (TC) template.
2. Migration Certificate template.
3. Auto-populate from student data.
4. PDF export with institute letterhead.
5. Certificate number tracking.

---

## 🟢 P3 — Low Priority (13 Items)

These improve maintainability, scalability, and long-term product health.

---

### P3-01: State Management Migration (Riverpod/Bloc)

**Area:** Architecture & Code Quality
**File(s):** All feature files

**Current State:**
All state is managed via `StatefulWidget` + `setState()`. Business logic is mixed with UI code. Dashboard files are 500+ lines.

**What to Build:**
1. Introduce Riverpod for dependency injection and state management.
2. Migrate one feature at a time (start with attendance, then fees).
3. Separate business logic into providers/controllers.
4. Make business logic testable without widget tests.

---

### P3-02: CI/CD Pipeline (GitHub Actions)

**Area:** Architecture & Code Quality
**File(s):** `.github/workflows/`

**Current State:**
No automated builds, tests, or deployments.

**What to Build:**
1. GitHub Actions workflow for PR: `flutter analyze` + `flutter test`.
2. Build workflow: Android APK/AAB, web, Windows.
3. Automated version bumping.
4. Release workflow with signed APK.

---

### P3-03: Crash Reporting (Sentry/Crashlytics)

**Area:** Architecture & Code Quality
**File(s):** `lib/main.dart`, new `lib/shared/services/crash_reporting_service.dart`

**Current State:**
No crash reporting. If the app crashes in production, you'll never know.

**What to Build:**
1. Integrate Sentry or Firebase Crashlytics.
2. Add `FlutterError.onError` handler.
3. Add `PlatformDispatcher.instance.onError` handler.
4. Custom context (user role, app version, device info).
5. Performance monitoring (slow frames, memory usage).

---

### P3-04: Data Source Abstraction Layer

**Area:** Architecture & Code Quality
**File(s):** New `lib/core/data_sources/`

**Current State:**
`kIsWeb` checks are scattered across the codebase. No abstraction between SQLite (native) and Supabase (web).

**What to Build:**
1. Abstract data source interfaces for each entity.
2. SQLite implementation for native platforms.
3. Supabase REST implementation for web.
4. Dependency injection to select the right implementation.
5. Eliminate all `kIsWeb` checks from feature code.

---

### P3-05: API Abstraction Layer

**Area:** Architecture & Code Quality
**File(s):** New `lib/shared/api/`

**Current State:**
All Supabase calls are raw HTTP in `sync_engine.dart`. No API abstraction.

**What to Build:**
1. API client abstraction (interface + implementation).
2. Supabase REST client implementation.
3. Request/response models.
4. Error handling and retry logic.
5. Make it possible to swap Supabase for Firebase or a custom backend.

---

### P3-06: Comprehensive Widget Tests

**Area:** Testing & QA
**File(s):** `test/widget/` (new directory)

**Current State:**
Zero widget tests. All 32 test files are unit/repository tests.

**What to Build:**
1. Login screen widget test (form validation, error states).
2. Dashboard widget test (renders data correctly).
3. Student list widget test (search, filter, empty state).
4. Fee payment dialog widget test (validation, submission).
5. Settings screen widget test.

---

### P3-07: Golden Tests for Visual Regression

**Area:** Testing & QA
**File(s):** `test/golden/` (new directory)

**Current State:**
No visual regression tests.

**What to Build:**
1. Golden tests for key screens (login, dashboard, student list).
2. Run golden tests in CI/CD.
3. Update goldens when design changes intentionally.

---

### P3-08: Integration Tests (Flutter Driver)

**Area:** Testing & QA
**File(s):** `integration_test/` (new directory)

**Current State:**
The file `test/integration/erp_integration_regression_test.dart` is a unit-level test, not a true Flutter integration test.

**What to Build:**
1. End-to-end test: login → add student → record attendance → record fee payment.
2. End-to-end test: login → create test → enter results → export report.
3. Run on real devices/emulators.
4. Add to CI/CD pipeline.

---

### P3-09: Library/Book Management

**Area:** Features (Client-Requested)
**File(s):** New module `lib/features/library/`

**What to Build:**
1. Book inventory management.
2. Issue/return tracking.
3. Fine calculation for overdue books.
4. Student-wise borrowing history.

---

### P3-10: Transport/Bus Tracking

**Area:** Features (Client-Requested)
**File(s):** New module `lib/features/transport/`

**What to Build:**
1. Route management.
2. Vehicle and driver information.
3. Student-route assignment.
4. Basic GPS tracking integration (optional).

---

### P3-11: Multi-Language Report Cards

**Area:** Features (Client-Requested)
**File(s):** `lib/features/tests/reports/`

**What to Build:**
1. Report card template in Hindi.
2. Language selector for report generation.
3. Support for regional language names.

---

### P3-12: Accessibility (a11y)

**Area:** UI/UX & Polish
**File(s):** All widget files

**What to Build:**
1. Add `Semantics` labels to all interactive elements.
2. Support dynamic text scaling.
3. Add high contrast mode.
4. Ensure color is not the only differentiator (add icons/text labels).
5. Test with screen readers (TalkBack on Android).

---

### P3-13: High-Contrast Mode

**Area:** UI/UX & Polish
**File:** `lib/shared/themes/app_theme.dart`

**What to Build:**
1. Create `AppTheme.highContrastTheme`.
2. Toggle in accessibility settings.
3. Increase text contrast ratios to WCAG AAA.

---

## Existing Issues from Previous Development

These are issues found in the existing code that need attention:

---

### EXISTING-01: Dashboard Files Are Too Large

**File:** `lib/features/dashboard/dashboard_screen.dart` (500+ lines)

The admin dashboard widget mixes data loading, state management, and UI rendering in a single file. This makes it hard to maintain and test.

**Fix:** Extract data loading into a separate service/provider. Break the UI into smaller widgets.

---

### EXISTING-02: Duplicate Logout Logic

**File(s):** `lib/features/dashboard/teacher_dashboard_screen.dart`, `lib/features/dashboard/student_dashboard_screen.dart`

The `_logout()` method is duplicated in both dashboards with identical code.

**Fix:** Extract to a shared utility function in `lib/shared/utils/`.

---

### EXISTING-03: Inconsistent Error Handling

**File(s):** Multiple screen files

Some screens catch errors and show SnackBars, others silently swallow errors with empty `catch (_) {}` blocks.

**Fix:** Implement a consistent error handling strategy with a global error handler and user-facing error dialogs.

---

### EXISTING-04: Debug Print Statements in Production Code

**File(s):** `lib/shared/services/sync_engine.dart`, `lib/features/authentication/repository/auth_repository.dart`, `lib/shared/services/supabase_auth_service.dart`

Over 50 `print()` statements wrapped in `kDebugMode` checks. While they don't execute in release builds, they clutter the code and can accidentally be left without the guard.

**Fix:** Replace with a proper logging framework (e.g., `logging` package or `logger`).

---

### EXISTING-05: AppConstants Has Hardcoded Lists

**File:** `lib/shared/constants/app_constants.dart`

Boards, classes, and subjects are hardcoded. There's no way for an admin to add custom boards or subjects from the app (except through Master Data, which is separate).

**Fix:** Master Data should be the single source of truth. Remove hardcoded lists from `AppConstants` and load from the database instead.

---

## Appendix: File Inventory

### Files That Need Modification

| File | Changes Needed |
|------|---------------|
| `lib/shared/config/backend_config.dart` | Remove hardcoded credentials |
| `lib/core/database/database_helper.dart` | Add encryption support |
| `lib/shared/services/sync_engine.dart` | Extend to all tables |
| `lib/features/authentication/repository/auth_repository.dart` | Add rate limiting, password strength |
| `lib/features/authentication/login/login_screen.dart` | Add biometric, password strength indicator |
| `lib/shared/utils/app_session.dart` | Add session timeout |
| `lib/app/app.dart` | Add lifecycle observer for timeout |
| `lib/shared/themes/app_theme.dart` | Add dark theme, high contrast |
| `lib/shared/constants/app_constants.dart` | Migrate to database-driven lists |
| `lib/main.dart` | Add crash reporting, notifications |
| `lib/features/dashboard/dashboard_screen.dart` | Extract into smaller widgets |
| `lib/features/dashboard/teacher_dashboard_screen.dart` | Extract logout, add refresh |
| `lib/features/dashboard/student_dashboard_screen.dart` | Extract logout, add refresh |
| `pubspec.yaml` | Add new dependencies |

### New Files to Create

| Path | Purpose |
|------|---------|
| `lib/features/parent_portal/` | Parent portal feature module |
| `lib/features/analytics/` | Analytics dashboard |
| `lib/features/onboarding/` | First-run setup wizard |
| `lib/features/academic_calendar/` | Holidays and events |
| `lib/features/homework/` | Homework tracking |
| `lib/features/branches/` | Multi-branch support |
| `lib/features/batches/` | Batch management |
| `lib/features/library/` | Library management |
| `lib/features/transport/` | Transport tracking |
| `lib/features/payments/` | Online payment gateway |
| `lib/shared/services/notification_service.dart` | In-app + push notifications |
| `lib/shared/services/messaging_service.dart` | SMS/WhatsApp |
| `lib/shared/services/audit_service.dart` | Audit trail |
| `lib/shared/services/push_notification_service.dart` | FCM push notifications ✅ |
| `lib/shared/services/theme_service.dart` | Dark mode persistence ✅ |
| `lib/shared/widgets/skeleton_widgets.dart` | Shimmer loading skeletons ✅ |
| `lib/shared/widgets/empty_state_widget.dart` | Empty state illustrations ✅ |
| `lib/shared/services/crash_reporting_service.dart` | Crash reporting |
| `lib/shared/services/license_service.dart` | Subscription system |
| `lib/shared/services/csv_import_service.dart` | CSV import/export |
| `lib/core/data_sources/` | Data source abstraction |
| `lib/shared/api/` | API abstraction |
| `lib/l10n/` | Localization files |
| `lib/shared/utils/logout_util.dart` | Shared logout logic |
| `.github/workflows/` | CI/CD pipelines |
| `integration_test/` | Integration tests |
| `test/widget/` | Widget tests |
| `test/golden/` | Golden tests |

---

*Document generated from full codebase analysis — September 2026*
