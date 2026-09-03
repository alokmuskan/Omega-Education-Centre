# Omega Education Centre ERP — Implementation Plan

> A structured, phased roadmap to transform the ERP from its current state into a production-grade, sellable product. Each phase has clear milestones, deliverables, dependencies, and acceptance criteria.

---

## How to Read This Plan

- **Phases** are sequential — each phase builds on the previous one.
- **Weeks** assume 1 developer working full-time. Adjust timelines for team size.
- **Dependencies** must be resolved before starting a task.
- **Acceptance Criteria** define "done" for each task.
- Cross-reference with [improvements_analysis.md](improvements_analysis.md) for full details on each item.

---

## Phase Overview

| Phase | Focus | Duration | Items Covered |
|-------|-------|----------|---------------|
| **Phase 1** | Critical Security & Platform Fixes | Weeks 1–2 | P0-01 to P0-06 |
| **Phase 2** | Core Sellable Features | Weeks 3–6 | P1-01 to P1-09 |
| **Phase 3** | Polish & Differentiation | Weeks 7–10 | P2-01 to P2-12 |
| **Phase 4** | Architecture & Quality | Weeks 11–14 | P3-01 to P3-13 |
| **Phase 5** | Pre-Launch Hardening | Weeks 15–16 | Final QA, signing, release |

**Total estimated timeline: 16 weeks (4 months)**

---

## Phase 1: Critical Security & Platform Fixes (Weeks 1–2)

> **Goal:** Make the app secure, compliant, and functional on all platforms.
> **Blocker:** Nothing can be sold until this phase is complete.

---

### Week 1: Security Foundations

#### Day 1–2: Data Encryption at Rest (P0-03)

**Task:** Encrypt the SQLite database using SQLCipher.

**Steps:**
1. Add `sqflite_sqlcipher` dependency to `pubspec.yaml` (replaces `sqflite`).
2. Modify `DatabaseHelper._initDatabase()` to use encrypted database with a device-derived key.
3. Generate encryption key from device identifiers using `flutter_secure_storage`.
4. Test database migration: existing unencrypted DB → encrypted DB.
5. Ensure backup/restore works with encrypted database.

**Dependencies:** None
**Deliverables:**
- Updated `database_helper.dart` with encryption
- Migration path for existing installations
- Backup files are also encrypted

**Acceptance Criteria:**
- [ ] Database file is unreadable when copied from device
- [ ] Existing data migrates seamlessly to encrypted format
- [ ] Backup and restore work with encrypted databases
- [ ] No performance degradation > 5% on read/write operations

---

#### Day 2–3: Session Timeout & Auto-Logout (P0-04)

**Task:** Implement automatic session expiry after inactivity.

**Steps:**
1. Add `lastActivityTimestamp` to `SharedPreferences` on every user interaction.
2. Add `WidgetsBindingObserver` in `AppStartupWrapper` to track app lifecycle.
3. On `AppLifecycleState.resumed`, check if elapsed time > threshold (default 15 min).
4. If expired: clear session, navigate to login with message.
5. Add configurable timeout duration in Institute Settings.
6. Show warning dialog 2 minutes before auto-logout.

**Dependencies:** None
**Deliverables:**
- Updated `app_session.dart` with timeout logic
- Updated `app.dart` lifecycle observer
- Settings screen with timeout configuration

**Acceptance Criteria:**
- [ ] Session expires after 15 minutes of inactivity (configurable)
- [ ] Warning dialog appears 2 minutes before expiry
- [ ] User is redirected to login on expiry
- [ ] Activity (tap, scroll, navigation) resets the timer
- [ ] Timer persists across app background/foreground transitions

---

#### Day 3–4: Brute-Force Protection (P0-05)

**Task:** Implement login rate limiting and account lockout.

**Steps:**
1. Create `LoginAttemptTracker` utility class.
2. Store failed attempt count and last attempt timestamp in `SharedPreferences`.
3. Lockout rules: 5 failures → 5 min lock, 10 → 30 min, 15 → 1 hour.
4. Update `AuthRepository.login()` to check lockout before attempting auth.
5. Update `LoginScreen` to show remaining attempts and lockout timer.
6. Reset counter on successful login.

**Dependencies:** None
**Deliverables:**
- New `lib/shared/utils/login_attempt_tracker.dart`
- Updated `auth_repository.dart`
- Updated `login_screen.dart` with lockout UI

**Acceptance Criteria:**
- [ ] Login blocked after 5 failed attempts for 5 minutes
- [ ] Lockout duration increases progressively
- [ ] Lockout timer displayed on login screen
- [ ] Counter resets on successful login
- [ ] Lockout state survives app restart

---

#### Day 4–5: Password Strength Requirements (P0-06)

**Task:** Enforce stronger password policies.

**Steps:**
1. Update minimum length from 4 to 8 characters in all password validators.
2. Add complexity requirements: 1 uppercase, 1 lowercase, 1 digit.
3. Create `PasswordStrengthIndicator` widget (weak/fair/strong/very strong).
4. Add indicator to login screen password field and change password dialog.
5. Update `changePassword()` and `adminResetPassword()` validation.
6. Add password strength check to onboarding wizard (Phase 2).

**Dependencies:** None
**Deliverables:**
- New `lib/shared/widgets/password_strength_indicator.dart`
- Updated validators in `auth_repository.dart` and `login_screen.dart`

**Acceptance Criteria:**
- [ ] Passwords must be 8+ characters
- [ ] Must contain uppercase, lowercase, and digit
- [ ] Strength indicator shows real-time feedback
- [ ] Weak passwords rejected with clear error message
- [ ] All password entry points enforce the same rules

---

### Week 2: Platform & Credential Fixes

#### Day 6–7: Remove Hardcoded Credentials (P0-02)

**Task:** Eliminate hardcoded Supabase credentials from source code.

**Steps:**
1. Create first-run setup screen (`lib/features/onboarding/backend_setup_screen.dart`).
2. On first launch, prompt admin to enter Supabase URL and anon key.
3. Store credentials in `app_settings` table (already supported by `BackendConfig.loadSettingsFromDb()`).
4. Remove `defaultProductionUrl` and `defaultProductionUrl` from `backend_config.dart`.
5. Update `BackendConfig` to only load from database (no hardcoded fallback).
6. Add validation: test connection before saving.

**Dependencies:** None
**Deliverables:**
- New `backend_setup_screen.dart`
- Updated `backend_config.dart` (no hardcoded values)
- First-run detection logic

**Acceptance Criteria:**
- [ ] No Supabase URLs or keys in source code
- [ ] First-run screen prompts for backend configuration
- [ ] Credentials stored in encrypted `app_settings` table
- [ ] Connection tested before saving
- [ ] App works fully offline if backend is not configured

---

#### Day 8–10: Fix Web Platform (P0-01)

**Task:** Make the entire app functional on web.

**Steps:**

**Sub-task 1: Data Source Abstraction (foundation)**
1. Create abstract interfaces:
   - `lib/core/data_sources/student_data_source.dart`
   - `lib/core/data_sources/teacher_data_source.dart`
   - `lib/core/data_sources/attendance_data_source.dart`
   - etc. (one per entity)
2. Create SQLite implementations (move existing repository logic).
3. Create Supabase REST implementations for web.

**Sub-task 2: Authentication on Web**
1. Modify `AuthRepository.login()` to support Supabase Auth for Teacher/Student on web.
2. Remove the `kIsWeb` rejection for non-admin users.
3. Use Supabase Auth for all roles on web (Admin, Teacher, Student).

**Sub-task 3: Dashboard on Web**
1. Replace `kIsWeb` short-circuit in `dashboard_screen.dart` with data source call.
2. Dashboard loads data from Supabase on web, SQLite on native.
3. Teacher and Student dashboards also work on web.

**Sub-task 4: Sync Engine on Web**
1. Remove `kIsWeb` early return in `SyncEngine.syncAll()`.
2. On web, sync reads/writes go directly to Supabase (no local queue needed).

**Dependencies:** None (but data source abstraction makes this cleaner)
**Deliverables:**
- New `lib/core/data_sources/` directory with interfaces and implementations
- Updated auth, dashboard, and sync files
- Web builds fully functional

**Acceptance Criteria:**
- [ ] Admin can log in on web and see real data
- [ ] Teacher can log in on web and see their dashboard
- [ ] Student can log in on web and see their dashboard
- [ ] All CRUD operations work on web
- [ ] No `kIsWeb` checks in feature code (moved to data source layer)

---

#### Day 10: Audit Previous Fixes

**Task:** Review and test all Phase 1 changes.

**Steps:**
1. Run `flutter analyze` — zero errors.
2. Run `flutter test` — all existing tests pass.
3. Manual testing on Android, web, and Windows.
4. Security review: verify encryption, session timeout, lockout.
5. Create Phase 1 test report.

**Acceptance Criteria:**
- [ ] All 32 existing tests pass
- [ ] `flutter analyze` returns zero errors
- [ ] App works on Android, Web, Windows
- [ ] Security features verified manually

---

## Phase 2: Core Sellable Features (Weeks 3–6)

> **Goal:** Build the features that clients explicitly ask for and will pay for.
> **Prerequisite:** Phase 1 complete.

---

### Week 3: Onboarding & Parent Portal Foundation

#### Day 11–13: Onboarding Wizard (P1-06)

**Task:** Create first-run setup wizard for new installations.

**Steps:**
1. Create `lib/features/onboarding/onboarding_screen.dart` with PageView.
2. Step 1: Institute profile (name, address, phone, email, director name).
3. Step 2: Board selection (multi-select chips from `AppConstants.boards`).
4. Step 3: Class selection (multi-select chips from `AppConstants.classes`).
4. Step 4: Admin account creation (username, password with strength indicator).
5. Step 5: Optional Supabase connection (skip for offline-only).
6. Store `onboarding_completed` flag in `app_settings`.
7. In `AppStartupWrapper`, check flag and route to onboarding if not completed.
8. Add "Reset Onboarding" option in Institute Settings (for demo purposes).

**Dependencies:** P0-06 (password strength indicator)
**Deliverables:**
- New `lib/features/onboarding/` module (4 files)
- Updated `app.dart` startup logic
- Updated `institute_settings_screen.dart`

**Acceptance Criteria:**
- [ ] Wizard runs on first app launch
- [ ] All steps are skippable except Step 1 and Step 4
- [ ] Progress indicator shows current step
- [ ] Data saved to `app_settings` and institute profile
- [ ] Wizard does not run again after completion
- [ ] "Reset Onboarding" works from settings

---

#### Day 13–15: Parent Portal (P1-01)

**Task:** Build parent-facing view for student data.

**Steps:**
1. Create `lib/features/parent_portal/` module structure.
2. Parent login: link via student's `mobile` or `fatherName` + student's `rollNo`.
3. Parent dashboard with tabs: Attendance, Fees, Results, Notices.
4. Read-only views — no data modification.
5. Web version (responsive design).
6. Optional: FCM notifications for fee dues.

**Dependencies:** P0-01 (web platform fix)
**Deliverables:**
- New `lib/features/parent_portal/` module (8+ files)
- Parent login flow
- Parent dashboard (web + mobile)

**Acceptance Criteria:**
- [ ] Parent can log in using student's mobile + roll number
- [ ] Parent sees child's attendance percentage and history
- [ ] Parent sees fee dues and payment history
- [ ] Parent sees latest exam results
- [ ] Parent sees relevant notices
- [ ] Parent cannot modify any data
- [ ] Works on both web and mobile

---

### Week 4: Sync Engine & Notifications

#### Day 16–19: Complete Sync Engine (P1-02)

**Task:** Extend cloud sync to all 17 remaining tables.

**Steps:**

**Batch 1 (Day 16–17): Financial tables**
1. Add sync for `fees`, `fee_payments`, `fee_installments`.
2. Implement append-only sync for payments (never overwrite).
3. Add conflict resolution: fee plans use last-write-wins.

**Batch 2 (Day 17–18): Attendance & Academic**
1. Add sync for `student_attendance`, `teacher_attendance`.
2. Add sync for `tests`, `test_subjects`, `test_results`.
3. Add sync for `daily_class_records`, `timetable_entries`.

**Batch 3 (Day 18–19): Remaining tables**
1. Add sync for `teacher_payments`, `teacher_pay_rate_history`.
2. Add sync for `notices`, `notice_reads`.
3. Add sync for `app_settings` (institute profile).
4. Update PostgreSQL schema (`supabase/schema.sql`) with new tables.

**Dependencies:** P0-01 (web platform)
**Deliverables:**
- Updated `sync_engine.dart` with all entity sync methods
- Updated `supabase/schema.sql` with all tables
- Sync status indicators per module

**Acceptance Criteria:**
- [ ] All 20 tables sync between devices
- [ ] Fee payments recorded on Device A appear on Device B within 30 seconds
- [ ] Attendance syncs bidirectionally
- [ ] No data loss during sync conflicts
- [ ] Sync queue processes correctly when offline → online transition

---

#### Day 19–21: Push Notifications (P1-03)

**Task:** Implement Firebase Cloud Messaging for proactive alerts.

**Steps:**
1. Add `firebase_messaging` and `flutter_local_notifications` to `pubspec.yaml`.
2. Create `NotificationService` with FCM token management.
3. Store FCM tokens in `devices` table (already exists in Supabase schema).
4. Create Supabase Edge Functions for:
   - Fee due reminders (daily check, send 7 days before due date).
   - Exam result publication alerts.
   - Urgent notice broadcasts.
5. Create in-app notification center (list, mark as read, delete).
6. Add notification preferences in settings.

**Dependencies:** P1-02 (sync engine — for `devices` table)
**Deliverables:**
- New `lib/shared/services/notification_service.dart`
- New `lib/features/notifications/` module
- Supabase Edge Functions (3 functions)
- Notification settings screen

**Acceptance Criteria:**
- [ ] FCM token registered on app start
- [ ] Fee due reminders sent automatically
- [ ] Exam result notifications sent to parents
- [ ] Urgent notices trigger push notifications
- [ ] In-app notification center shows all notifications
- [ ] Users can toggle notification types on/off

---

### Week 5: Analytics & Reports

#### Day 22–25: Analytics Dashboard (P1-04)

**Task:** Build management analytics with charts and trends.

**Steps:**
1. Create `lib/features/analytics/` module.
2. Add `fl_chart` package for charts.
3. Build screens:
   - Fee Collection Trend (line chart, monthly view).
   - Attendance Trend (bar chart, class-wise).
   - Teacher Performance (hours taught, classes conducted).
   - Class Comparison (multi-class metrics side by side).
4. Add date range selector (month, quarter, year, custom).
5. Export charts to PDF.
6. Add analytics entry point to admin dashboard.

**Dependencies:** P1-02 (sync engine — for complete data)
**Deliverables:**
- New `lib/features/analytics/` module (6+ files)
- 4 analytics screens with charts
- PDF export of analytics

**Acceptance Criteria:**
- [ ] Fee collection trend shows monthly data for current year
- [ ] Attendance trend shows class-wise breakdown
- [ ] Teacher performance shows hours and classes
- [ ] Date range filter works correctly
- [ ] Charts are interactive (tap to see details)
- [ ] Analytics export to PDF works

---

#### Day 25–27: Audit Trail (P1-09)

**Task:** Implement immutable audit logging for financial transactions.

**Steps:**
1. Create `audit_log` table in SQLite (add migration v19).
2. Create `audit_log` table in Supabase schema.
3. Create `AuditService` with methods: `log()`, `query()`, `export()`.
4. Add audit logging to:
   - Fee payments (create, void)
   - Salary payments (create)
   - Student admission, deletion, deactivation
   - Teacher addition, deactivation
   - Settings changes
   - Login/logout events
5. Create audit log viewer (filterable by date, action, entity).
6. Export audit log to CSV/PDF.

**Dependencies:** P1-02 (sync engine)
**Deliverables:**
- New `lib/shared/services/audit_service.dart`
- Database migration v19
- Audit log viewer screen
- Export functionality

**Acceptance Criteria:**
- [ ] Every financial transaction has an audit record
- [ ] Audit records include: actor, timestamp, device, action, old/new values
- [ ] Audit log is append-only (no updates or deletes)
- [ ] Audit log viewer filters by date range, action type, entity
- [ ] Audit log exports to CSV and PDF

---

### Week 6: Messaging & Bulk Import

#### Day 28–30: SMS/WhatsApp Integration (P1-08)

**Task:** Implement automated messaging for fee reminders.

**Steps:**
1. Integrate MSG91 SMS gateway (India-focused, cheap, reliable).
2. Create `MessagingService` with methods: `sendSms()`, `sendBulk()`.
3. Create message template system (customizable per message type).
4. Implement automated triggers:
   - Fee due: 7 days before, on due date, 7 days after.
   - Attendance: daily absence alert to parent.
   - Exam results: on publication.
5. Add message delivery status tracking.
6. WhatsApp Business API integration (optional, separate phase).

**Dependencies:** P1-03 (notifications), P1-02 (sync)
**Deliverables:**
- New `lib/shared/services/messaging_service.dart`
- Message template management screen
- Automated trigger scheduler
- Delivery status tracking

**Acceptance Criteria:**
- [ ] SMS sent for fee due reminders automatically
- [ ] Templates are customizable by admin
- [ ] Delivery status tracked per message
- [ ] Bulk SMS works for class-wide announcements
- [ ] Message logs visible in audit trail

---

#### Day 30–32: Bulk CSV Import/Export (P1-07)

**Task:** Enable bulk data import via CSV files.

**Steps:**
1. Add `csv` package to `pubspec.yaml`.
2. Create `CsvImportService` with validation.
3. Create import screens:
   - Student import (template: name, father_name, mobile, class, board, roll_no).
   - Teacher import (template: name, mobile, subject, qualification, pay_rate).
4. CSV template download (generate sample CSV).
5. Pre-import validation report (errors, warnings, duplicates).
6. Duplicate detection (by mobile number or roll number).
7. Import summary (X imported, Y skipped, Z errors).
8. Export existing data to CSV.

**Dependencies:** None
**Deliverables:**
- New `lib/shared/services/csv_import_service.dart`
- Import screens for students and teachers
- CSV template generator
- Export functionality

**Acceptance Criteria:**
- [ ] CSV template downloadable from app
- [ ] Import validates all rows before committing
- [ ] Duplicate detection works (by mobile or roll number)
- [ ] Import summary shows counts and errors
- [ ] Export generates valid CSV files
- [ ] Works for 500+ records without timeout

---

#### Day 32: Phase 2 Review & Testing

**Task:** Test all Phase 2 features end-to-end.

**Steps:**
1. Run all existing tests — ensure no regressions.
2. Manual testing of all new features.
3. Web testing of parent portal.
4. Sync testing across 2 devices.
5. Performance testing with 500 students, 50 teachers.

**Acceptance Criteria:**
- [ ] All existing tests pass
- [ ] All new features tested manually
- [ ] No crashes during normal usage
- [ ] Sync completes within 30 seconds for full dataset

---

## Phase 3: Polish & Differentiation (Weeks 7–10)

> **Goal:** Make the app feel like a premium product. These features differentiate you from basic tools.
> **Prerequisite:** Phase 2 complete.

---

### Week 7: UI/UX Polish

#### Day 33–35: Dark Mode (P2-01)

**Task:** Add dark theme support.

**Steps:**
1. Create `AppTheme.darkTheme` using Material 3 dark color scheme.
2. Derive dark colors from the existing blue/indigo primary palette.
3. Add theme toggle in Institute Settings.
4. Persist preference in `SharedPreferences`.
5. Default to system theme preference.
6. Test all screens in dark mode — fix any contrast issues.

**Deliverables:**
- Updated `app_theme.dart` with dark theme
- Theme toggle in settings
- All screens tested in dark mode

**Acceptance Criteria:**
- [ ] Dark mode toggle works
- [ ] All text is readable in dark mode
- [ ] All cards, dialogs, and inputs look correct
- [ ] Theme persists across app restarts
- [ ] System theme respected as default

---

#### Day 35–37: Localization — Hindi + English (P2-02)

**Task:** Add Hindi language support.

**Steps:**
1. Set up Flutter's `localizations` with ARB files.
2. Extract all user-facing strings to `app_en.arb`.
3. Translate to Hindi in `app_hi.arb`.
4. Add language selector in Settings.
5. Persist language preference.
6. Test all screens in Hindi — fix layout issues (Hindi text is longer).

**Deliverables:**
- New `lib/l10n/` directory with ARB files
- Language selector in settings
- All screens tested in Hindi

**Acceptance Criteria:**
- [ ] Language switch works without app restart
- [ ] All user-facing strings translated
- [ ] Hindi text does not overflow or clip
- [ ] Language persists across restarts
- [ ] RTL support not needed (Hindi is LTR)

---

#### Day 37–38: Skeleton Loading States (P2-04)

**Task:** Replace spinners with shimmer skeleton screens.

**Steps:**
1. Add `shimmer` package to `pubspec.yaml`.
2. Create skeleton widgets:
   - `SkeletonCard` (rectangle with shimmer).
   - `SkeletonListTile` (avatar + two lines).
   - `SkeletonDashboard` (grid of cards).
3. Replace `CircularProgressIndicator` in:
   - Dashboard (admin, teacher, student).
   - Student list.
   - Teacher list.
   - Fee dashboard.
4. Add fade-in animation when data loads.

**Deliverables:**
- New `lib/shared/widgets/skeleton/` directory
- Updated loading states across all screens

**Acceptance Criteria:**
- [ ] Skeleton shown during data loading
- [ ] Smooth transition from skeleton to real content
- [ ] No layout shift during transition
- [ ] Skeleton matches the layout of the actual content

---

#### Day 38–39: Empty State Illustrations (P2-05)

**Task:** Add illustrations and CTAs to empty states.

**Steps:**
1. Create or source SVG illustrations for common empty states.
2. Create `EmptyState` widget with: illustration, title, description, CTA button.
3. Replace plain text empty states in:
   - Student list ("No students yet")
   - Teacher list ("No teachers yet")
   - Fee dashboard ("No fee records")
   - Attendance ("No attendance records")
   - Tests ("No tests created")
   - Notices ("No notices published")

**Deliverables:**
- New `lib/shared/widgets/empty_state.dart`
- Updated empty states across all screens

**Acceptance Criteria:**
- [ ] Every empty state has an illustration
- [ ] CTA button navigates to the relevant action
- [ ] Illustrations are consistent in style
- [ ] Empty states are helpful, not confusing

---

### Week 8: Student-Facing Features

#### Day 39–41: Student ID Card Generation (P2-06)

**Task:** Generate printable student ID cards.

**Steps:**
1. Create `IdCardService` using the `pdf` package.
2. Template: front (photo, name, class, roll, board, institute logo), back (address, emergency contact).
3. Single student generation.
4. Bulk generation (all students in a class).
5. Export as PDF (printable on card stock).
6. Share via `share_plus`.

**Deliverables:**
- New `lib/features/students/services/id_card_service.dart`
- ID card generation screen
- Bulk generation option

**Acceptance Criteria:**
- [ ] ID card generated with correct student data
- [ ] Institute logo and name included
- [ ] Photo included (or placeholder if no photo)
- [ ] PDF is print-ready (correct dimensions)
- [ ] Bulk generation works for entire class

---

#### Day 41–43: Transfer Certificate (P2-12)

**Task:** Generate Transfer and Migration certificates.

**Steps:**
1. Create `CertificateService` using the `pdf` package.
2. TC template: institute letterhead, student details, reason for transfer, date, signature line.
3. Auto-populate from student data.
4. Admin can add custom remarks.
5. PDF export with institute branding.
6. Certificate number tracking (auto-increment).

**Deliverables:**
- New `lib/features/students/services/certificate_service.dart`
- TC generation screen
- Certificate number registry

**Acceptance Criteria:**
- [ ] TC generated with correct student data
- [ ] Institute letterhead and branding included
- [ ] Certificate number is unique and sequential
- [ ] PDF is print-ready
- [ ] Certificate history viewable in student details

---

#### Day 43–45: Academic Calendar (P2-07)

**Task:** Build holiday and event management.

**Steps:**
1. Create `academic_calendar` table (migration v20).
2. Create CRUD screens for holidays and events.
3. Calendar view with color-coded entries.
4. Integration with timetable (holidays disable scheduled classes).
5. Export calendar to PDF.

**Deliverables:**
- New `lib/features/academic_calendar/` module
- Database migration v20
- Calendar view screen

**Acceptance Criteria:**
- [ ] Holidays can be added, edited, deleted
- [ ] Events can be created with date, title, description
- [ ] Calendar view shows all entries
- [ ] Holidays marked on timetable view
- [ ] Calendar exportable to PDF

---

### Week 9: Batch Management & Homework

#### Day 45–47: Batch Management (P2-11)

**Task:** Implement structured batch management.

**Steps:**
1. Create `batches` table (migration v21).
2. Batch entity: name, timing, teacher, class, board, max capacity.
3. Batch CRUD screens.
4. Student-batch assignment (many-to-many).
5. Batch-wise timetable view.
6. Batch-wise attendance.

**Deliverables:**
- New `lib/features/batches/` module
- Database migration v21
- Batch management screens

**Acceptance Criteria:**
- [ ] Batches can be created with timing and teacher
- [ ] Students can be assigned to batches
- [ ] Timetable viewable per batch
- [ ] Attendance recordable per batch
- [ ] Batch capacity enforcement (warning, not blocking)

---

#### Day 47–49: Homework Tracking (P2-08)

**Task:** Build homework assignment and tracking system.

**Steps:**
1. Create `homework` table (migration v22).
2. Teacher assigns homework: class, subject, description, due date.
3. Student/parent view of pending homework.
4. Submission status tracking (submitted/not submitted/late).
5. Homework reminder notifications.
6. Integration with daily class register.

**Deliverables:**
- New `lib/features/homework/` module
- Database migration v22
- Teacher assignment screen
- Student/parent homework view

**Acceptance Criteria:**
- [ ] Teacher can assign homework with due date
- [ ] Students see pending homework list
- [ ] Parents see homework on parent portal
- [ ] Submission status tracked
- [ ] Overdue homework highlighted

---

### Week 10: Subscription, Multi-Branch & Batch

#### Day 49–51: Subscription/License System (P2-10)

**Task:** Implement licensing for monetization.

**Steps:**
1. Create `LicenseService` with online validation.
2. License tiers: Free (basic), Pro (full features), Enterprise (multi-branch).
3. Trial period: 30 days full features.
4. Feature gating based on license tier.
5. Expiry handling with renewal reminders.
6. License key entry in settings.

**Deliverables:**
- New `lib/shared/services/license_service.dart`
- License validation screen
- Feature gating middleware

**Acceptance Criteria:**
- [ ] License key validates online
- [ ] Feature gating works per tier
- [ ] Trial period enforced (30 days)
- [ ] Expiry reminder shown 7 days before
- [ ] Expired license locks premium features

---

#### Day 51–53: Multi-Branch Support (P2-09)

**Task:** Enable multi-branch data isolation.

**Steps:**
1. Create `branches` table (migration v23).
2. Branch entity: name, address, phone, manager, is_active.
3. Add `branch_id` foreign key to all major tables.
4. Branch-level data isolation (RLS policies in Supabase).
5. Central admin view across all branches.
6. Branch switching for admin users.
7. Cross-branch reports.

**Deliverables:**
- New `lib/features/branches/` module
- Database migration v23
- Branch management screens
- Updated RLS policies

**Acceptance Criteria:**
- [ ] Branches can be created and managed
- [ ] Data is isolated per branch
- [ ] Central admin can view all branches
- [ ] Branch switching works seamlessly
- [ ] Reports can be generated per branch or cross-branch

---

#### Day 53–55: Batch/Schedule Integration (P2-11 continued)

**Task:** Integrate batch management with timetable and attendance.

**Steps:**
1. Link timetable entries to batches.
2. Link attendance records to batches.
3. Batch-wise fee plans.
4. Batch-wise reports.
5. Update all screens that reference batches.

**Deliverables:**
- Updated timetable, attendance, and fee modules
- Batch integration across all features

**Acceptance Criteria:**
- [ ] Timetable entries are batch-aware
- [ ] Attendance is recordable per batch
- [ ] Fee plans can be set per batch
- [ ] Reports can be filtered by batch

---

#### Day 55: Phase 3 Review & Testing

**Task:** Comprehensive testing of all Phase 3 features.

**Steps:**
1. Run all existing tests.
2. Manual testing of all new features.
3. UI/UX review (dark mode, Hindi, skeletons, empty states).
4. Performance testing with realistic data volumes.
5. Cross-platform testing (Android, Web, Windows).

**Acceptance Criteria:**
- [ ] All existing tests pass
- [ ] All new features functional
- [ ] No UI glitches in dark mode
- [ ] Hindi text renders correctly
- [ ] Performance acceptable (< 2s screen load)

---

## Phase 4: Architecture & Quality (Weeks 11–14)

> **Goal:** Improve code quality, testability, and long-term maintainability.
> **Prerequisite:** Phase 3 complete.

---

### Week 11: State Management & Architecture

#### Day 56–59: State Management Migration (P3-01)

**Task:** Introduce Riverpod for dependency injection and state management.

**Steps:**
1. Add `flutter_riverpod` to `pubspec.yaml`.
2. Create providers for:
   - Database helper (singleton).
   - repositories (Student, Teacher, Fee, etc.).
   - services (SyncEngine, NotificationService, etc.).
3. Migrate one feature at a time (start with Attendance module).
4. Convert `StatefulWidget` to `ConsumerWidget`.
5. Extract business logic into providers/controllers.
6. Repeat for Fees, then Tests, then remaining modules.

**Deliverables:**
- Riverpod providers for all services and repositories
- Migrated feature modules (at least 3 core modules)
- Business logic testable without widgets

**Acceptance Criteria:**
- [ ] Riverpod providers compile without errors
- [ ] Migrated features work identically to before
- [ ] Business logic is testable via provider overrides
- [ ] No `setState()` in migrated code
- [ ] Performance is same or better

---

#### Day 59–61: Data Source Abstraction (P3-04)

**Task:** Complete the data source abstraction started in Phase 1.

**Steps:**
1. Create abstract interfaces for all entities.
2. Move SQLite implementations from repositories to data sources.
3. Create Supabase REST implementations.
4. Use Riverpod to inject the correct implementation.
5. Eliminate all remaining `kIsWeb` checks from feature code.

**Deliverables:**
- Complete `lib/core/data_sources/` directory
- Updated repositories to use data sources
- No `kIsWeb` in feature code

**Acceptance Criteria:**
- [ ] All entities have abstract data source interfaces
- [ ] SQLite and Supabase implementations exist
- [ ] Correct implementation injected based on platform
- [ ] Zero `kIsWeb` checks in `lib/features/`

---

### Week 12: API Layer & Logging

#### Day 61–63: API Abstraction Layer (P3-05)

**Task:** Create a clean API abstraction over Supabase REST calls.

**Steps:**
1. Create `lib/shared/api/api_client.dart` interface.
2. Create `SupabaseApiClient` implementation.
3. Add request/response models for all entities.
4. Add error handling and retry logic.
5. Add request logging (in debug mode).
6. Make it possible to swap Supabase for Firebase or custom backend.

**Deliverables:**
- New `lib/shared/api/` directory
- API client interface and implementation
- Request/response models

**Acceptance Criteria:**
- [ ] All Supabase calls go through the API layer
- [ ] Error handling is consistent
- [ ] Retry logic works for transient failures
- [ ] API layer is testable with mocks

---

#### Day 63–65: Logging Framework (replacing print statements)

**Task:** Replace debug print statements with proper logging.

**Steps:**
1. Add `logging` package to `pubspec.yaml`.
2. Create `Log` utility class with levels: debug, info, warning, error.
3. Replace all `print()` statements with `Log` calls.
4. Add log levels: debug (dev only), info (always), warning (always), error (always).
5. Add log file output option for production debugging.

**Deliverables:**
- New `lib/shared/utils/log.dart`
- Updated all files with print statements
- Log configuration in main.dart

**Acceptance Criteria:**
- [ ] Zero `print()` statements in codebase
- [ ] All logging uses the `Log` utility
- [ ] Log levels are appropriate
- [ ] Logs are suppressible in release builds

---

### Week 13: Testing Infrastructure

#### Day 65–67: Widget Tests (P3-06)

**Task:** Add widget tests for critical screens.

**Steps:**
1. Create `test/widget/` directory.
2. Write tests for:
   - Login screen (form validation, error states, loading state).
   - Dashboard (renders data, shows correct role-based content).
   - Student list (search, filter, empty state).
   - Fee payment dialog (validation, submission).
   - Settings screen (loads data, saves correctly).
3. Use `mockito` for mocking repositories and services.

**Deliverables:**
- New `test/widget/` directory with 5+ test files
- Mock implementations for key services

**Acceptance Criteria:**
- [ ] Widget tests compile and pass
- [ ] Login form validation tested
- [ ] Dashboard renders for each role
- [ ] Search and filter work in tests
- [ ] No flaky tests

---

#### Day 67–69: Integration Tests (P3-08)

**Task:** Add end-to-end Flutter integration tests.

**Steps:**
1. Create `integration_test/` directory.
2. Write test: Login → Add Student → Record Attendance → Record Fee Payment.
3. Write test: Login → Create Test → Enter Results → Export Report.
4. Write test: Login → Add Teacher → Record Teacher Attendance → Record Salary Payment.
5. Run on real devices/emulators.
6. Add to CI/CD pipeline (Phase 5).

**Deliverables:**
- New `integration_test/` directory with 3+ test files
- Test runner configuration

**Acceptance Criteria:**
- [ ] Integration tests pass on Android emulator
- [ ] Tests cover full user workflows
- [ ] Tests are deterministic (no flakiness)
- [ ] Tests run in < 5 minutes

---

### Week 14: CI/CD & Crash Reporting

#### Day 69–71: CI/CD Pipeline (P3-02)

**Task:** Set up automated builds and tests.

**Steps:**
1. Create `.github/workflows/pr_check.yml`:
   - Trigger on PR to main.
   - Run `flutter analyze`.
   - Run `flutter test`.
   - Run widget tests.
2. Create `.github/workflows/build.yml`:
   - Trigger on tag push (v*).
   - Build Android APK (debug + release).
   - Build web.
   - Build Windows.
3. Create `.github/workflows/release.yml`:
   - Trigger on GitHub release.
   - Build signed AAB.
   - Upload to Play Console (optional).

**Deliverables:**
- 3 GitHub Actions workflow files
- Build scripts for all platforms

**Acceptance Criteria:**
- [ ] PR checks run automatically
- [ ] Build artifacts generated on tag push
- [ ] Release workflow builds signed APK/AAB
- [ ] All workflows pass consistently

---

#### Day 71–73: Crash Reporting (P3-03)

**Task:** Integrate Sentry for crash reporting and performance monitoring.

**Steps:**
1. Add `sentry_flutter` to `pubspec.yaml`.
2. Initialize Sentry in `main.dart` with DSN.
3. Add `FlutterError.onError` handler.
4. Add `PlatformDispatcher.instance.onError` handler.
5. Add custom context: user role, app version, device info.
6. Add performance monitoring (screen load times).
7. Create Sentry dashboard for monitoring.

**Deliverables:**
- New `lib/shared/services/crash_reporting_service.dart`
- Updated `main.dart` with Sentry initialization
- Sentry dashboard configuration

**Acceptance Criteria:**
- [ ] Crashes reported to Sentry automatically
- [ ] Custom context attached to reports
- [ ] Performance metrics tracked
- [ ] No PII in crash reports (passwords, tokens excluded)

---

#### Day 73–75: Remaining Accessibility (P3-12, P3-13)

**Task:** Add accessibility support.

**Steps:**
1. Add `Semantics` labels to all interactive elements.
2. Support dynamic text scaling.
3. Add high contrast mode toggle.
4. Ensure color is not the only differentiator (add icons/text).
5. Test with TalkBack on Android.

**Deliverables:**
- Updated widgets with Semantics labels
- High contrast theme
- Accessibility settings

**Acceptance Criteria:**
- [ ] All buttons and inputs have semantic labels
- [ ] Text scales with system font size
- [ ] High contrast mode available
- [ ] Status indicators use color + icon + text
- [ ] Screen reader can navigate the app

---

## Phase 5: Pre-Launch Hardening (Weeks 15–16)

> **Goal:** Final QA, signing, documentation, and release preparation.
> **Prerequisite:** Phases 1–4 complete.

---

### Week 15: Quality Assurance

#### Day 76–77: Comprehensive Testing

**Task:** Run all tests and fix any remaining issues.

**Steps:**
1. Run `flutter analyze` — zero errors.
2. Run `flutter test` — all tests pass.
3. Run widget tests — all pass.
4. Run integration tests — all pass.
5. Manual testing checklist:
   - [ ] Login (Admin, Teacher, Student) on Android, Web, Windows.
   - [ ] All CRUD operations.
   - [ ] Fee payment flow end-to-end.
   - [ ] Attendance recording and viewing.
   - [ ] Test creation and result entry.
   - [ ] Report export (PDF, Excel, DOCX).
   - [ ] Backup and restore.
   - [ ] Sync across 2 devices.
   - [ ] Dark mode on all screens.
   - [ ] Hindi language on all screens.
   - [ ] Parent portal on web.
   - [ ] Notifications received.
   - [ ] Audit trail records.
   - [ ] Session timeout works.
   - [ ] Brute-force lockout works.

**Acceptance Criteria:**
- [ ] Zero analyzer errors
- [ ] All tests pass
- [ ] All manual test cases pass
- [ ] No crashes during normal usage
- [ ] Performance: all screens load in < 2 seconds

---

#### Day 77–78: Performance Testing

**Task:** Test with realistic data volumes.

**Steps:**
1. Seed database with:
   - 500 students
   - 50 teachers
   - 1000 fee payment records
   - 2000 attendance records
   - 50 test results
2. Measure screen load times.
3. Measure sync time.
4. Measure backup/restore time.
5. Identify and fix bottlenecks.

**Acceptance Criteria:**
- [ ] Student list loads in < 1 second with 500 students
- [ ] Dashboard loads in < 2 seconds
- [ ] Sync completes in < 30 seconds for full dataset
- [ ] Backup completes in < 10 seconds
- [ ] No memory leaks

---

#### Day 78–79: Security Audit

**Task:** Final security review.

**Steps:**
1. Verify encryption is active and working.
2. Verify session timeout functions correctly.
3. Verify brute-force lockout works.
4. Verify no credentials in source code.
5. Verify RLS policies in Supabase are correct.
6. Verify audit trail is complete.
7. Run OWASP Mobile Top 10 checklist.

**Acceptance Criteria:**
- [ ] All security features verified
- [ ] No hardcoded secrets
- [ ] RLS policies enforce data isolation
- [ ] Audit trail is complete and immutable
- [ ] OWASP checklist passed

---

### Week 16: Release Preparation

#### Day 80–81: App Store Preparation

**Task:** Prepare for Android Play Store release.

**Steps:**
1. Generate release keystore (or use existing).
2. Update `android/app/build.gradle.kts` with release signing config.
3. Update `applicationId` from `com.example.omega_education_centre` to your domain.
4. Generate app icon for all densities.
5. Create Play Store listing:
   - App title, description, screenshots.
   - Privacy policy.
   - Content rating questionnaire.
6. Generate signed AAB.
7. Upload to Play Console (internal testing track).

**Deliverables:**
- Signed release AAB
- Play Store listing
- Privacy policy

**Acceptance Criteria:**
- [ ] Signed AAB builds successfully
- [ ] App installs on physical device
- [ ] Play Store listing complete
- [ ] Privacy policy published

---

#### Day 81–82: Documentation & Handoff

**Task:** Finalize all documentation.

**Steps:**
1. Update `README.md` with final setup instructions.
2. Update `docs/development_guide.md` with new architecture.
3. Create `docs/api_documentation.md` (Supabase schema, endpoints).
4. Create `docs/deployment_guide.md` (build, sign, release).
5. Create `docs/user_manual.md` (end-user guide for admin/teacher/student).
6. Create `docs/parent_portal_guide.md` (guide for parents).

**Deliverables:**
- 6 documentation files
- Updated existing docs

**Acceptance Criteria:**
- [ ] All docs are accurate and up-to-date
- [ ] User manual covers all features
- [ ] Deployment guide is step-by-step
- [ ] Parent guide is simple and clear

---

#### Day 82–83: Bug Fixes & Final Polish

**Task:** Fix any remaining issues found during QA.

**Steps:**
1. Address all bug reports from testing.
2. Final UI polish (spacing, alignment, colors).
3. Final performance optimization.
4. Code review of all new code.
5. Merge all feature branches to main.

**Acceptance Criteria:**
- [ ] Zero known bugs
- [ ] UI is consistent across all screens
- [ ] Code review completed
- [ ] All changes merged to main

---

#### Day 83–85: Release v1.0

**Task:** Final release.

**Steps:**
1. Tag release: `git tag v1.0.0`.
2. Build final signed APK and AAB.
3. Build web version.
4. Build Windows version.
5. Upload to Play Console (internal → closed → open testing).
6. Deploy web version.
7. Announce to first client.

**Deliverables:**
- v1.0.0 release artifacts
- Play Store submission
- Web deployment
- Client handoff

**Acceptance Criteria:**
- [ ] v1.0.0 tagged in git
- [ ] APK and AAB built and signed
- [ ] Web version deployed
- [ ] First client onboarded

---

## Appendix: Dependency Graph

```
Phase 1 (Security & Platform)
├── P0-03 (Encryption) ──────────────────────┐
├── P0-04 (Session Timeout) ─────────────────┤
├── P0-05 (Brute-Force) ─────────────────────┤
├── P0-06 (Password Strength) ───────────────┤
├── P0-02 (Remove Credentials) ──────────────┤
└── P0-01 (Web Platform) ────────────────────┤
                                             │
Phase 2 (Sellable Features)                  │
├── P1-06 (Onboarding) ←── P0-06 ───────────┤
├── P1-01 (Parent Portal) ←── P0-01 ────────┤
├── P1-02 (Sync Engine) ←── P0-01 ──────────┤
├── P1-03 (Notifications) ←── P1-02 ────────┤
├── P1-04 (Analytics) ←── P1-02 ────────────┤
├── P1-09 (Audit Trail) ←── P1-02 ──────────┤
├── P1-08 (SMS/WhatsApp) ←── P1-03, P1-02 ─┤
└── P1-07 (CSV Import) ─────────────────────┤
                                             │
Phase 3 (Polish)                             │
├── P2-01 (Dark Mode) ──────────────────────┤
├── P2-02 (Hindi) ──────────────────────────┤
├── P2-04 (Skeletons) ──────────────────────┤
├── P2-05 (Empty States) ───────────────────┤
├── P2-06 (ID Cards) ───────────────────────┤
├── P2-12 (Transfer Cert) ──────────────────┤
├── P2-07 (Academic Calendar) ───────────────┤
├── P2-11 (Batch Mgmt) ─────────────────────┤
├── P2-08 (Homework) ←── P2-11 ─────────────┤
├── P2-10 (License) ────────────────────────┤
└── P2-09 (Multi-Branch) ←── P2-10 ─────────┤
                                             │
Phase 4 (Architecture)                       │
├── P3-01 (State Mgmt) ─────────────────────┤
├── P3-04 (Data Sources) ←── P3-01 ─────────┤
├── P3-05 (API Layer) ←── P3-04 ────────────┤
├── P3-06 (Widget Tests) ←── P3-01 ─────────┤
├── P3-08 (Integration Tests) ←── P3-01 ────┤
├── P3-02 (CI/CD) ──────────────────────────┤
├── P3-03 (Crash Reporting) ────────────────┤
└── P3-12, P3-13 (Accessibility) ───────────┤
                                             │
Phase 5 (Launch) ←── ALL ABOVE ─────────────┘
```

---

## Appendix: Weekly Milestone Summary

| Week | Milestone | Key Deliverable |
|------|-----------|-----------------|
| 1 | Security foundations | Encrypted DB, session timeout, lockout, strong passwords |
| 2 | Platform fixes | Credentials removed, web platform functional |
| 3 | Onboarding + Parent portal | First-run wizard, parent login and dashboard |
| 4 | Sync + Notifications | All tables sync, FCM push notifications |
| 5 | Analytics + Audit | Charts and trends, audit trail |
| 6 | Messaging + Bulk import | SMS integration, CSV import/export |
| 7 | UI polish | Dark mode, Hindi, skeletons, empty states |
| 8 | Student features | ID cards, transfer certificates, academic calendar |
| 9 | Batch + Homework | Batch management, homework tracking |
| 10 | License + Multi-branch | Subscription system, multi-branch support |
| 11 | State management | Riverpod migration, data source abstraction |
| 12 | API + Logging | API layer, logging framework |
| 13 | Testing | Widget tests, integration tests |
| 14 | CI/CD + Monitoring | GitHub Actions, Sentry crash reporting |
| 15 | QA | Comprehensive testing, performance, security audit |
| 16 | Release | App Store submission, documentation, v1.0.0 |

---

*Document generated from full codebase analysis — September 2026*
