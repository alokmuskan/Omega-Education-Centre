# Omega Education Centre ERP

A comprehensive, offline-first ERP system for educational centres built with **Flutter** and **Supabase**. Designed for coaching centres, tuition centres, and small educational institutions in India.

## Overview

Omega Education Centre ERP manages the complete lifecycle of an educational institution — from student admissions and teacher management to fee collection, exam results, and daily class operations. The system supports **three user roles** (Admin, Teacher, Student) with role-based access control and works **fully offline** with optional cloud sync.

---

## Key Features

### 🎨 UI/UX & Experience
- **Dark Mode** — Full light/dark theme with Material 3 dynamic colors
- **Skeleton Loading** — Smooth shimmer placeholders while data loads
- **Empty State Illustrations** — Friendly icons and CTAs when lists are empty
- **Localization** — English and Hindi (हिन्दी) support with instant switching
- **Analytics Dashboard** — Real-time charts and insights for attendance, fees, and performance

### 🔐 Authentication & Security
- **Biometric Authentication** — Fingerprint/face login after first password login
- **Session Management** — Auto-lock, session timeout, and secure token storage
- **Role-Based Access** — Admin, Teacher, Student with granular permissions
- **Data Encryption** — SQLCipher encrypted database at rest
- **Audit Trail** — Complete action logging for compliance

### 👩‍🎓 Student Management
- Student admission with class, board, and roll number assignment
- Profile management with photo support
- **Student ID Card** — PDF generation with photo, details, and institute letterhead
- **Transfer Certificate** — Formal TC generation with customizable reason and remarks
- Attendance tracking with daily status (Present/Absent/Late/Leave)
- Fee status tracking and payment history

### 👨‍🏫 Teacher Management
- Teacher profiles with subject specialization and qualification
- Hourly pay rate tracking with historical rate changes
- Attendance logging with hours worked
- Salary calculation and payment recording
- **Multi-Subject Assignment** — Teachers can be assigned to multiple subjects

### 💰 Fee Management
- Flexible fee plans: Monthly or Installment-based
- Payment recording with receipt generation (PDF)
- Student-wise and centre-wide fee due summaries
- Fee installment scheduling
- **Payment Gateway** — Online payment integration support

### 📝 Examinations & Results
- Multi-subject test creation with configurable max/pass marks
- Student-wise result entry per subject
- Class results with grade computation
- Export to PDF, Excel, and DOCX formats

### 📅 Academic Calendar
- **Holiday Management** — Add/edit recurring holidays with calendar markers
- **Event Management** — Exams, PTMs, Annual Day, Sports events with priority levels
- **Term Tracking** — Academic year terms with date ranges
- **Visual Calendar** — Month grid with holiday (red) and event (orange) markers

### 📚 Homework & Assignments
- **Assignment Creation** — Teachers assign homework with class, subject, priority, due date
- **Submission Tracking** — Per-student status (Pending/Submitted/Late/Excused)
- **Overdue Detection** — Automatic late marking after due date
- **Class Filter** — Filter homework by class

### 📋 Daily Class Register
- Log daily teaching activities (class, subject, topic, duration)
- Teacher and batch assignment
- Review and edit past records

### 🗓️ Timetable
- Class scheduling with period-wise entries
- Board and class-wise filtering

### 📢 Notices & Announcements
- Centre-wide or board-targeted notices
- Priority levels (Urgent, Important, General)
- Read status tracking per user
- **Push Notifications** — Real-time alerts via FCM/APNs

### 🏢 Batch Management
- **Create Batches** — Name, class, board, timing, teacher, max capacity
- **Student Assignment** — Checkbox-based add/remove from batches
- **Capacity Tracking** — Visual indicators for batch fullness

### 🏢 Multi-Branch Support
- **Branch Management** — Create and manage multiple institute branches
- **Branch Details** — Address, phone, email, manager information
- **Soft Delete** — Deactivate branches without data loss

### 🔑 Subscription & Licensing
- **License Tiers** — Free, Trial (14-day), Standard, Premium
- **Feature Gating** — Enable/disable features based on license tier
- **License Activation** — Enter license key to unlock features
- **Trial Management** — One-tap 14-day trial with full access

### 💾 Backup & Restore
- Full local SQLite database backup
- Export/import backup files
- Automatic daily backup on app startup
- Disaster recovery with organisation identity service

### ☁️ Cloud Sync (Optional)
- Supabase PostgreSQL central database
- Bidirectional sync for students, teachers, and users
- Offline-first: app works without backend configuration
- JWT-based authentication for Admin; local SQLite for Teacher/Student

---

## Tech Stack

| Layer | Technology |
|-------|------------|
| **Frontend** | Flutter 3.12+ with Material 3 |
| **Local DB** | SQLite via `sqflite` + SQLCipher encryption (23 tables, versioned migrations) |
| **Cloud Backend** | Supabase (PostgreSQL + Auth + RLS) |
| **Auth** | Supabase Auth (Admin) + PBKDF2 local hashing (Teacher/Student) + Biometric (local_auth) |
| **Export** | PDF (`pdf` + `printing`), Excel (`excel`), DOCX (custom generator) |
| **Notifications** | Firebase Cloud Messaging (FCM) + Local notifications |
| **State** | StatefulWidget + ChangeNotifier (localization, theme, services) |

---

## Project Structure

```
lib/
├── main.dart                      # App entry point
├── app/
│   └── app.dart                   # MaterialApp, theme, localization, startup wrapper
├── core/
│   ├── core.dart                  # Barrel export
│   └── database/
│       └── database_helper.dart   # SQLite singleton, migrations (v1→v23)
├── features/                      # Feature-first modules
│   ├── academic_calendar/         # Holidays, events, terms
│   ├── analytics/                 # Charts, metrics, insights
│   ├── attendance/                # Student & teacher attendance
│   ├── authentication/            # Login, auth, session management
│   ├── backup/                    # Backup, restore, disaster recovery
│   ├── batches/                   # Batch/schedule management
│   ├── branches/                  # Multi-branch support
│   ├── class_register/            # Daily class records
│   ├── dashboard/                 # Admin, teacher & student dashboards
│   ├── fees/                      # Fee plans, payments, receipts
│   ├── homework/                  # Assignment tracking & submissions
│   ├── notices/                   # Announcements & read status
│   ├── onboarding/                # First-run setup wizard
│   ├── payments/                  # Payment gateway integration
│   ├── salary/                    # Teacher salary & payments
│   ├── settings/                  # Institute configuration
│   ├── splash/                    # Splash screen
│   ├── students/                  # Student CRUD, profiles, ID cards, TCs
│   ├── teachers/                  # Teacher CRUD & profiles
│   ├── tests/                     # Exams, results & report exports
│   └── timetable/                 # Class scheduling
├── l10n/
│   └── app_translations.dart      # English & Hindi translations (100+ strings)
└── shared/                        # Cross-cutting concerns
    ├── shared.dart                # Barrel export
    ├── config/                    # Backend configuration
    ├── constants/                 # App-wide constants
    ├── models/                    # License model
    ├── screens/                   # License, notification center
    ├── services/                  # Biometric, localization, license, SMS, push notifications, sync
    ├── themes/                    # Light & dark Material 3 themes
    ├── utils/                     # Session, password, photo helpers
    └── widgets/                   # Shared reusable widgets
```

---

## Getting Started

### Prerequisites

- **Flutter SDK** ^3.12.2
- **Dart SDK** ^3.12.2
- **Android Studio** or **VS Code** with Flutter extension
- **Chrome** (for web development)

### Installation

```bash
# Clone the repository
git clone <repository-url>
cd omega_education_centre

# Install dependencies
flutter pub get

# Run the app
flutter run
```

### Running on Specific Platforms

```bash
# Android
flutter run -d android

# Web
flutter run -d chrome

# Windows
flutter run -d windows

# macOS
flutter run -d macos
```

### Cloud Backend Setup (Optional)

The app works fully offline by default. To enable cloud sync:

1. Create a Supabase project at [supabase.com](https://supabase.com)
2. Follow the [Supabase Setup Guide](docs/supabase_setup_guide.md) to configure the database
3. Update `lib/shared/config/backend_config.dart` with your credentials

---

## Testing

```bash
# Run all tests
flutter test

# Run specific test suites
flutter test test/authentication/
flutter test test/backend/
flutter test test/fees/
flutter test test/attendance/

# Run with coverage
flutter test --coverage
```

---

## Database

The app uses **SQLite** (with SQLCipher encryption) with **23 tables** and versioned migrations (v1 → v23). Key tables:

| Table | Purpose |
|-------|---------|
| `students` | Student profiles and admission data |
| `teachers` | Teacher profiles and employment data |
| `student_attendance` | Daily student attendance records |
| `teacher_attendance` | Daily teacher attendance with hours worked |
| `fees` | Fee plans (monthly/installment) |
| `fee_payments` | Payment ledger (append-only) |
| `fee_installments` | Expected payment schedule |
| `tests` | Exam/test definitions |
| `test_subjects` | Subject-wise max/pass marks |
| `test_results` | Student marks per subject |
| `teacher_payments` | Salary payment records |
| `teacher_pay_rate_history` | Historical pay rate tracking |
| `daily_class_records` | Daily class register entries |
| `timetable_entries` | Class schedule |
| `notices` | Centre announcements |
| `notice_reads` | Read status per user |
| `users` | Local user accounts (RBAC) |
| `sync_queue` | Offline sync queue |
| `holidays` | Academic holidays |
| `academic_events` | Academic events (exams, PTMs, etc.) |
| `academic_terms` | Academic year terms |
| `homework` | Assignment definitions |
| `homework_submissions` | Student homework submission status |
| `batches` | Batch/schedule definitions |
| `batch_students` | Batch-student junction |
| `branches` | Multi-branch information |

---

## Documentation

Detailed documentation is available in the [`docs/`](docs/) folder:

- [Development Guide](docs/development_guide.md) — How to run, build, test, and contribute
- [Improvements Analysis](docs/improvements_analysis.md) — Full audit of all 40 improvements needed
- [Implementation Plan](docs/implementation_plan.md) — Phased 16-week roadmap to production
- [Supabase Setup Guide](docs/supabase_setup_guide.md) — Full backend setup instructions

---

## Security

- **Admin authentication** is managed by Supabase Auth (no local password storage)
- **Teacher/Student authentication** uses PBKDF2 salted password hashing locally
- **Biometric authentication** via `local_auth` (fingerprint/face)
- **Row Level Security (RLS)** enforced on all Supabase tables
- **SQLCipher encryption** for database at rest
- **Profile photos** are stored locally only — never uploaded to the cloud
- **Service role keys** are never included in the Flutter app
- **Audit trail** for all data modifications

---

## Implementation Status

| Priority | Items | Status |
|----------|-------|--------|
| **P0 (Critical)** | 6 items | ✅ 6/6 Complete |
| **P1 (High)** | 9 items | ✅ 9/9 Complete |
| **P2 (Medium)** | 12 items | ✅ 12/12 Complete |
| **P3 (Low)** | 13 items | ⏳ Pending |

**Total: 27/40 improvements complete** — The app has evolved from a basic internal tool to a **production-grade, sellable SaaS product**.

---

## License

Private — Omega Education Centre
