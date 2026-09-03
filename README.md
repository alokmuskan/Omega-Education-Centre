# Omega Education Centre ERP

A comprehensive, offline-first ERP system for educational centres built with **Flutter** and **Supabase**. Designed for coaching centres, tuition centres, and small educational institutions in India.

## Overview

Omega Education Centre ERP manages the complete lifecycle of an educational institution — from student admissions and teacher management to fee collection, exam results, and daily class operations. The system supports **three user roles** (Admin, Teacher, Student) with role-based access control and works **fully offline** with optional cloud sync.

## Key Features

### Student Management
- Student admission with class, board, and roll number assignment
- Profile management with photo support
- Attendance tracking with daily status (Present/Absent/Late/Leave)
- Fee status tracking and payment history

### Teacher Management
- Teacher profiles with subject specialization and qualification
- Hourly pay rate tracking with historical rate changes
- Attendance logging with hours worked
- Salary calculation and payment recording

### Fee Management
- Flexible fee plans: Monthly or Installment-based
- Payment recording with receipt generation (PDF)
- Student-wise and centre-wide fee due summaries
- Fee installment scheduling

### Examinations & Results
- Multi-subject test creation with configurable max/pass marks
- Student-wise result entry per subject
- Class results with grade computation
- Export to PDF, Excel, and DOCX formats

### Daily Class Register
- Log daily teaching activities (class, subject, topic, duration)
- Teacher and batch assignment
- Review and edit past records

### Timetable
- Class scheduling with period-wise entries
- Board and class-wise filtering

### Notices & Announcements
- Centre-wide or board-targeted notices
- Priority levels (Urgent, Important, General)
- Read status tracking per user

### Backup & Restore
- Full local SQLite database backup
- Export/import backup files
- Automatic daily backup on app startup
- Disaster recovery with organisation identity service

### Cloud Sync (Optional)
- Supabase PostgreSQL central database
- Bidirectional sync for students, teachers, and users
- Offline-first: app works without backend configuration
- JWT-based authentication for Admin; local SQLite for Teacher/Student

## Tech Stack

| Layer | Technology |
|-------|------------|
| **Frontend** | Flutter 3.12+ with Material 3 |
| **Local DB** | SQLite via `sqflite` (19 tables, versioned migrations) |
| **Cloud Backend** | Supabase (PostgreSQL + Auth + RLS) |
| **Auth** | Supabase Auth (Admin) + PBKDF2 local hashing (Teacher/Student) |
| **Export** | PDF (`pdf` + `printing`), Excel (`excel`), DOCX (custom generator) |
| **State** | StatefulWidget + ValueNotifier (no external state management) |

## Project Structure

```
lib/
├── main.dart                      # App entry point
├── app/
│   └── app.dart                   # MaterialApp, theme, startup wrapper
├── core/
│   ├── core.dart                  # Barrel export
│   └── database/
│       └── database_helper.dart   # SQLite singleton, migrations (v1→v18)
├── features/                      # Feature-first modules
│   ├── attendance/                # Student & teacher attendance
│   ├── authentication/            # Login, auth, session management
│   ├── backup/                    # Backup, restore, disaster recovery
│   ├── class_register/            # Daily class records
│   ├── dashboard/                 # Admin, teacher & student dashboards
│   ├── fees/                      # Fee plans, payments, receipts
│   ├── notices/                   # Announcements & read status
│   ├── salary/                    # Teacher salary & payments
│   ├── settings/                  # Institute configuration
│   ├── splash/                    # Splash screen
│   ├── students/                  # Student CRUD & profiles
│   ├── teachers/                  # Teacher CRUD & profiles
│   ├── tests/                     # Exams, results & report exports
│   └── timetable/                 # Class scheduling
└── shared/                        # Cross-cutting concerns
    ├── shared.dart                # Barrel export
    ├── config/                    # Backend configuration
    ├── constants/                 # App-wide constants
    ├── services/                  # Sync engine, Supabase auth
    ├── themes/                    # Material 3 theme
    ├── utils/                     # Session, password, photo helpers
    └── widgets/                   # Shared reusable widgets
```

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

## Database

The app uses **SQLite** with **19 tables** and versioned migrations (v1 → v18). Key tables:

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

## Documentation

Detailed documentation is available in the [`docs/`](docs/) folder:

- [Development Guide](docs/development_guide.md) — How to run, build, test, and contribute
- [Improvements Analysis](docs/improvements_analysis.md) — Full audit of all 40 improvements needed
- [Implementation Plan](docs/implementation_plan.md) — Phased 16-week roadmap to production
- [Supabase Setup Guide](docs/supabase_setup_guide.md) — Full backend setup instructions

## Security

- **Admin authentication** is managed by Supabase Auth (no local password storage)
- **Teacher/Student authentication** uses PBKDF2 salted password hashing locally
- **Row Level Security (RLS)** enforced on all Supabase tables
- **Profile photos** are stored locally only — never uploaded to the cloud
- **Service role keys** are never included in the Flutter app

## License

Private — Omega Education Centre
