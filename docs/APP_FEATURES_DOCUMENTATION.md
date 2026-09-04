# 🎓 Omega Education Centre — ERP Application

## Complete Feature Documentation

> **Version:** 1.0.0  
> **Platform:** Android, iOS, Web, Windows, macOS, Linux  
> **Architecture:** Offline-first with optional cloud sync (Supabase)  
> **Built with:** Flutter (Dart), SQLite (local), Supabase (cloud)

---

## 📋 Table of Contents

1. [App Overview](#app-overview)
2. [First-Time Setup (Onboarding)](#first-time-setup)
3. [Authentication & Security](#authentication--security)
4. [Admin Dashboard](#admin-dashboard)
5. [Student Management](#student-management)
6. [Teacher Management](#teacher-management)
7. [Attendance System](#attendance-system)
8. [Fee Management](#fee-management)
9. [Salary Management](#salary-management)
10. [Examinations & Results](#examinations--results)
11. [Daily Class Register](#daily-class-register)
12. [Notices & Announcements](#notices--announcements)
13. [Timetable](#timetable)
14. [Academic Calendar](#academic-calendar)
15. [Batches & Groups](#batches--groups)
16. [Branches (Multi-Location)](#branches)
17. [Library Management](#library-management)
18. [Transport Management](#transport-management)
19. [Homework Management](#homework-management)
20. [Parent Portal](#parent-portal)
21. [Analytics Dashboard](#analytics-dashboard)
22. [Backup & Restore](#backup--restore)
23. [Institute Settings](#institute-settings)
24. [Audit Trail](#audit-trail)
25. [Reporting & Export](#reporting--export)
26. [Offline & Sync Architecture](#offline--sync-architecture)
27. [Localization (Hindi/English)](#localization)
28. [Theme & UI](#theme--ui)
29. [Testing & Quality](#testing--quality)

---

## App Overview

Omega Education Centre ERP is a **complete school/coaching centre management system** designed for Indian educational institutions. It handles every aspect of running a coaching centre — from student admissions to fee collection, teacher salary payments, exam results, and day-to-day class management.

### Who Is This For?

| User | What They Do |
|------|-------------|
| **Admin / Director** | Full control — manages everything from the admin dashboard |
| **Teachers** | Can view their schedule, mark attendance, enter test results |
| **Students** | Can view their attendance, results, fee status |
| **Parents** | Can monitor their child's attendance, fees, and results (via Parent Portal) |

### Key Design Principles

- **Offline-first**: Works without internet on Android (SQLite database)
- **Cloud-ready**: Optional Supabase integration for multi-device sync and web access
- **Hybrid mode**: Android app works offline, web app works online
- **No data lock-in**: Data is stored locally; you own your data

---

## First-Time Setup

When the app is opened for the first time, a **5-step onboarding wizard** guides the administrator through setup:

### Step 1: Institute Information
- Institute name (e.g., "ABC Coaching Centre")
- Address
- Phone number
- Email address (optional)

### Step 2: Board Selection
Select which education boards your institute follows:
- CBSE (Central Board of Secondary Education)
- BSEB (Bihar School Examination Board)
- ICSE (Indian Certificate of Secondary Education)
- State Board
- IGCSE / IB / Other

### Step 3: Class Selection
Select which classes your institute teaches:
- Nursery, LKG, UKG
- Classes 1–12
- Foundation, Dropper

### Step 4: Admin Account Creation
- Set a strong admin password
- Password is stored locally (encrypted in SQLite)
- Login uses the email address entered in Step 1

### Step 5: Cloud Sync (Optional)
- Enter Supabase Project URL and Anon Key
- **Leave blank** to run fully offline — no internet required
- Can be configured later in Settings

> **Note:** Step 5 is completely optional. The app works perfectly without Supabase on Android.

---

## Authentication & Security

### Login System
- Email + password authentication
- Supports Supabase Auth (online) or local SQLite (offline)
- Admin accounts managed in `admin_accounts` table
- Teacher/Student accounts with role-based access

### Security Features

| Feature | Description |
|---------|------------|
| **Password Strength Validation** | Minimum 8 characters, checks for uppercase, lowercase, numbers, special chars |
| **Password Encryption** | Passwords encrypted with AES-256-CBC before storage |
| **Login Attempt Tracking** | Failed attempts tracked; account lockout after multiple failures |
| **Session Timeout** | Configurable auto-logout after inactivity (default: 30 minutes) |
| **Biometric Authentication** | Fingerprint/Face ID support on Android (via `local_auth`) |
| **Auto-Logout Dialog** | Warning shown before session expires, with option to extend |

### Role-Based Access Control

| Role | Permissions |
|------|------------|
| **Admin** | Full access to all features — students, teachers, fees, salary, settings, backup |
| **Teacher** | View own schedule, mark attendance, enter test results |
| **Student** | View own attendance, results, fee status |
| **Parent** | View child's attendance, results, fees (via Parent Portal) |

### Session Management
- Session data stored in `AppSession` (singleton)
- Current user role, username, and permissions tracked
- On app restart, session is restored from local storage
- Explicit logout clears all session data

---

## Admin Dashboard

The admin dashboard is the **home screen** after login. It provides a real-time overview of the entire institute:

### Today's Overview (Summary Cards)
| Card | Shows |
|------|-------|
| **Active Students** | Total enrolled students who are currently active |
| **Active Teachers** | Total teachers currently on staff |
| **Classes Today** | Number of classes conducted today |
| **Teacher Hours Today** | Total hours worked by all teachers today |

### Attendance Breakdown
- **Student Attendance**: Present / Absent / Late / Leave counts for today
- **Teacher Attendance**: How many teachers have recorded attendance vs total

### Center Dues Summary
- **Fee Dues**: Total outstanding fees from all students (₹)
- **Salary Dues**: Total pending salary for all teachers (current month) (₹)

### Academic Activity
- Classes conducted today (with link to Class Register)
- Recent notices published (with link to Notices)
- Recent examinations (with link to Tests)

### Today's Conducted Classes
List of today's classes with:
- Class & batch
- Subject
- Teacher name
- Topic covered
- Duration
- Start time

### Recent Examinations
- Test title, class, type, and date

### Recent Notice Feed
- Notice title, target audience (Students/Teachers/All), and publish date

### Quick Actions Grid (17 tiles)
Quick access to all major modules:
1. Students
2. Teachers
3. Attendance
4. Notices
5. Results
6. Salary
7. Class Register
8. Fees & Dues
9. Backup & Restore
10. Institute Config
11. Audit Log
12. License
13. Branches
14. Batches
15. Academic Calendar
16. Analytics
17. Library
18. Transport

---

## Student Management

### Student List Screen
- **Search**: Real-time search by student name, admission number, or parent name
- **Filter by Board**: CBSE, BSEB, ICSE, All
- **Filter by Class**: 1–12, Foundation, Dropper, All
- **Student count** displayed in app bar
- **Pull-to-refresh** to reload data

### Add Student (New Admission)
Form fields:
- **Personal**: Full name, date of birth, gender
- **Academic**: Board, class, section, admission number
- **Contact**: Parent/guardian name, phone, email, address
- **Medical**: Blood group, allergies, medical notes
- **Transport**: Route, vehicle, pickup/drop points (if transport module enabled)
- **Fee Plan**: Assign fee structure during admission
- **Profile Photo**: Capture from camera or pick from gallery

### Student Details Screen
- Complete student profile with all information
- **Attendance history** (month-wise, with percentage)
- **Fee status** (total fees, paid, due)
- **Test results** (all exam results)
- **Edit student** information
- **Deactivate/Reactivate** student

### Student ID Card
- **Auto-generated** ID card with student photo
- Includes: Name, class, admission number, institute name, address
- **PDF export** and share functionality
- Uses institute logo and branding

### Transfer Certificate (TC)
- **Auto-generated** TC document
- Includes: Student details, duration of study, conduct, result
- **PDF export** and share
- Uses institute letterhead and logo

### CSV Import
- Bulk import students from CSV/Excel file
- Maps columns to student fields
- Validates data before import
- Shows import summary (success/failed counts)

---

## Teacher Management

### Teacher List Screen
- **Search**: Real-time search by teacher name, subject, or employee ID
- **Filter by Subject**: Mathematics, Science, Physics, Chemistry, English, Hindi, etc.
- **Filter by Status**: Active / Inactive / All
- **Teacher count** displayed in app bar
- **Pull-to-refresh**

### Add Teacher
Form fields:
- **Personal**: Full name, date of birth, gender
- **Professional**: Subjects taught, qualification, experience
- **Contact**: Phone, email, address
- **Employment**: Employee ID, join date, salary structure
- **Bank Details**: Account number, IFSC code (for salary payments)
- **Profile Photo**: Camera or gallery

### Teacher Details Screen
- Complete teacher profile
- **Attendance history** (days worked, hours)
- **Salary history** (payments made, pending)
- **Subject assignment** (which classes/subjects they teach)
- **Edit/Deactivate** teacher

---

## Attendance System

### Student Attendance
- **Date picker** to select attendance date
- **Class/Batch filter** to show specific students
- **Mark attendance** for each student: Present, Absent, Late, Leave
- **Bulk actions**: Mark all Present / Mark all Absent
- **Visual indicators**: Green (present), Red (absent), Orange (late), Grey (leave)
- **Save** attendance to database
- **Cannot mark** attendance for future dates (validated)

### Teacher Attendance
- **Date picker** to select attendance date
- **Hours worked** input for each teacher
- **Mark status**: Present, Absent, Late, Leave
- **Hours validation**: Cannot exceed 24 hours per day
- **Used for salary calculation** (hours × rate)

### Attendance History
- **Student Attendance History**: Month-wise view with percentage
- **Teacher Attendance History**: Days worked, total hours
- **Filterable** by date range
- **Color-coded** calendar view

### Attendance Percentage Calculation
- **Formula**: (Present + Late) / Total Recorded Days × 100
- **Pass threshold**: Configurable (default 35%)
- **Displayed** on student profile and reports

---

## Fee Management

### Fee Dashboard (Admin)
- **Total collected** this month
- **Total outstanding** across all students
- **Fee collection trend** (graph)
- **Recent payments** list

### Fee Plan Setup
- **Create fee plans** for different classes/boards
- **Components**: Tuition, Lab, Library, Transport, etc.
- **Installment support**: Monthly, Quarterly, Half-yearly, Annual
- **Late fee rules**: Configurable grace period and penalty

### Student Fee Details
- **Fee breakdown**: Total fees by component
- **Payment history**: All payments made with date and mode
- **Outstanding balance**: Remaining amount
- **Installment status**: Which installments are paid/pending

### Record Payment
- **Amount** input
- **Payment mode**: Cash, UPI, Bank Transfer, Cheque
- **Receipt number**: Auto-generated or manual
- **Notes**: Optional payment notes
- **Auto-updates** student fee status

### Fee Receipt
- **Auto-generated** receipt with:
  - Student name, class, admission number
  - Fee breakdown
  - Amount paid, payment mode, date
  - Institute name, logo, address
- **PDF export** and share

---

## Salary Management

### Salary Dashboard
- **Total salary paid** this month
- **Total pending** salary
- **Teacher-wise breakdown**

### Salary Calculation
- **Based on**: Hours worked × hourly rate
- **Rate history**: Track rate changes over time
- **Monthly summary**: Days worked, total hours, earned salary

### Teacher Payments
- **Record salary payment** for a teacher
- **Payment modes**: Cash, UPI, Bank Transfer
- **Payment history**: All past payments with dates
- **Running balance**: Earned - Paid = Pending

### Salary Reports
- **Monthly salary sheet** for all teachers
- **Individual teacher** salary statement
- **Year-wise** salary summary

---

## Examinations & Results

### Test Management
- **Create test**: Name, type (Unit Test/Mid-term/Final/Weekly), class, date
- **Subject selection**: Add multiple subjects per test
- **Maximum marks** per subject
- **Pass marks** per subject

### Enter Results
- **Student-wise** or **subject-wise** entry
- **Marks entry** for each student in each subject
- **Auto-calculated**: Total, percentage, grade
- **Grade system**: A+ (90+), A (75+), B (60+), C (45+), D (35+), F (<35)
- **Pass/Fail** determination

### Results Dashboard
- **Class results**: Rank-wise list of students
- **Subject analysis**: Average, highest, lowest marks
- **Pass/Fail ratio**
- **Top performers** list

### Student Result History
- **All tests** a student has appeared in
- **Trend**: Performance over time
- **Subject-wise** breakdown

### Report Export (PDF, Excel, DOCX)
- **PDF Report**: Class results with institute branding
- **Excel Export**: Raw data for further analysis
- **DOCX Report**: Word format for printing
- **Individual student** report cards
- **Includes**: Institute logo, student photo, marks, grades, remarks

---

## Daily Class Register

### Class Record Entry
- **Date** (defaults to today)
- **Class & Batch**: Which class and batch was taught
- **Subject**: What subject was covered
- **Topic**: Specific topic taught
- **Teacher**: Which teacher conducted the class
- **Duration**: How long the class lasted (minutes)
- **Start time**: When the class started
- **Notes**: Optional notes about the class

### Class Register View
- **Day-wise** list of all classes conducted
- **Filterable** by date, class, subject, teacher
- **Today's classes** shown on dashboard

---

## Notices & Announcements

### Create Notice
- **Title**: Notice headline
- **Content**: Full notice text
- **Priority**: Normal, Important, Urgent
- **Target**: All, Students, Teachers, Parents
- **Publish date**: When the notice goes live
- **Expiry date**: When the notice expires (optional)
- **Attachments**: Support for file attachments

### Notice Management
- **List of all notices** with priority indicators
- **Edit/Delete** existing notices
- **Archive** old notices
- **Read status** tracking (who has read the notice)

### Notice Board (Students/Teachers)
- **Filtered view** based on user role
- **Priority sorting**: Urgent first
- **Mark as read** functionality

---

## Timetable

### Timetable Management
- **Create entries** for each class/batch
- **Day-wise** schedule (Monday–Saturday)
- **Time slots**: Start time, end time
- **Subject, Teacher, Room** assignment
- **Conflict detection**: Prevents overlapping entries

### Timetable View
- **Weekly view**: All classes for the week
- **Day filter**: Show specific day
- **Class filter**: Show specific class

---

## Academic Calendar

### Calendar View
- **Monthly grid** with current month display
- **Navigate** between months with arrows

### Events
- **Add Holiday**: Pick date → red dot appears on calendar
- **Add Event**: Pick type (Exam, Event, Workshop, etc.) → colored marker
- **Event types**: Exam (orange), Holiday (red), Event (blue), Meeting (green)

### Event Details
- **Tap a day** with markers → detail bottom sheet shows holidays/events
- **Edit/Delete** events

---

## Batches & Groups

### Batch Management
- **Create batches** with name, class, timing, subject
- **Assign students** to batches (checkbox selection)
- **Student count** on each batch card
- **Add/Remove** students dynamically

### Batch Operations
- **Edit batch** details (timing, subject)
- **Delete batch** (students unassigned, not deleted)
- **Filter** by class

---

## Branches

### Multi-Location Support
- **Create branches** with name, address, phone
- **Each branch** can have its own settings
- **Switch between branches** (future: data isolation per branch)

---

## Library Management

### Book Management
- **Add books**: Title, author, ISBN, category, quantity
- **Book categories**: Textbook, Reference, Fiction, Non-fiction, etc.
- **Stock tracking**: Total copies, available, issued

### Book Issue/Return
- **Issue book** to student/teacher
- **Return book** with due date tracking
- **Overdue alerts**: Highlight books past due date
- **Issue history**: Who borrowed what and when

---

## Transport Management

### Route Management
- **Create routes** with name, pickup points, timing
- **Assign vehicles** to routes
- **Track distance** and estimated time

### Vehicle Management
- **Add vehicles**: Registration number, type, capacity
- **Driver details**: Name, phone, license
- **Maintenance tracking**

### Student Transport Assignment
- **Assign students** to routes
- **Pickup/drop points** per student
- **Transport fee** calculation

---

## Homework Management

### Homework Assignment
- **Create homework**: Subject, description, due date
- **Assign to class/batch** or individual students
- **Priority levels**

### Submission Tracking
- **Students submit** homework (mark as done)
- **Teacher views** submissions
- **Completion status** per student

---

## Parent Portal

### Parent Login
- **Separate login** for parents
- **Linked to student** account
- **View only** — no edit permissions

### Parent Dashboard
- **Child's attendance** (percentage, history)
- **Fee status** (paid, pending)
- **Test results** (all exams)
- **Notices** targeted to parents
- **Class schedule** (timetable)

---

## Analytics Dashboard

### Key Metrics
- **Student enrollment** trends
- **Attendance patterns** (daily/weekly/monthly)
- **Fee collection** trends
- **Teacher utilization** (hours worked)
- **Exam performance** averages

### Visual Charts
- **Bar charts** for attendance
- **Line graphs** for fee collection trends
- **Pie charts** for student demographics

---

## Backup & Restore

### Backup System
- **Full database backup** as JSON file
- **Organisation identity** embedded in backup
- **Recovery code** for disaster recovery
- **Auto-backup** on startup (configurable)

### Restore System
- **Import backup** from file
- **Organisation verification**: Ensures backup belongs to this institute
- **Recovery code verification**: Prevents unauthorized restores
- **Complete data restore**: Students, teachers, attendance, fees, everything

### Organisation Identity
- **Unique org ID** generated during onboarding
- **Backup metadata** includes org name and ID
- **Recovery code** for emergency access

---

## Institute Settings

### Profile Settings
- Institute name, address, phone, email
- Principal/Director name
- Academic year
- Logo path (for reports and ID cards)

### Display Settings
- **Language**: English / Hindi (हिन्दी)
- **Theme**: Light mode / Dark mode
- **Date format**: DD/MM/YYYY, MM/DD/YYYY, YYYY-MM-DD

### Security Settings
- **Change password**
- **Auto-logout timeout**: 15 min, 30 min, 1 hour, 2 hours
- **Biometric login** toggle

### Notification Preferences
- **Push notifications** toggle
- **In-app notifications** toggle
- **Fee reminder** notifications
- **Attendance alerts**

### Master Data
- **Manage boards**: Add/remove education boards
- **Manage classes**: Add/remove classes
- **Manage subjects**: Add/remove subjects
- **Payment modes**: Add/remove payment options

---

## Audit Trail

### What Gets Logged
- **Login/Logout** events
- **Data modifications**: Create, Update, Delete
- **Settings changes**
- **Backup/Restore** operations
- **Fee payments**

### Audit Log Screen
- **Chronological list** of all actions
- **Filterable** by date, action type, user
- **Details**: Who, what, when, old value, new value

---

## Reporting & Export

### Available Exports

| Report | Format | Contents |
|--------|--------|----------|
| **Student List** | CSV, PDF | All students with details |
| **Attendance Report** | PDF | Daily/monthly attendance summary |
| **Fee Report** | PDF, Excel | Collection and outstanding summary |
| **Salary Report** | PDF | Monthly salary statement |
| **Test Results** | PDF, Excel, DOCX | Class-wise or student-wise results |
| **ID Card** | PDF | Student/Teacher ID card |
| **Transfer Certificate** | PDF | Student TC |
| **Fee Receipt** | PDF | Individual payment receipt |

### Report Features
- **Institute branding** (logo, name, address) on all reports
- **Date range** filtering
- **Class/Board** filtering
- **Share** via WhatsApp, Email, etc.

---

## Offline & Sync Architecture

### How It Works

```
┌─────────────────────────────────────────────────┐
│              ANDROID APP                         │
│                                                  │
│  ┌──────────┐    ┌──────────┐    ┌──────────┐  │
│  │  SQLite   │◄──►│   Sync   │◄──►│ Supabase │  │
│  │  (Local)  │    │  Engine  │    │  (Cloud) │  │
│  └──────────┘    └──────────┘    └──────────┘  │
│                                                  │
│  • Works offline    • Pushes changes when online │
│  • Fast reads       • Pulls remote changes      │
│  • No login needed  • Login required for web     │
└─────────────────────────────────────────────────┘
```

### Data Source Selection
- **Android/iOS**: SQLite (local database)
- **Web**: Supabase REST API (cloud database)
- **Automatic detection**: `DataSourceFactory` picks the right source

### Sync Engine
- **Background sync**: Runs on app startup and periodically
- **Conflict resolution**: Last-write-wins
- **Queue system**: Changes queued when offline, synced when online
- **Status indicator**: Shows sync status in dashboard header

### Platform Behavior

| Platform | Database | Login | Sync | Offline |
|----------|----------|-------|------|---------|
| **Android** | SQLite | Optional | Auto | ✅ Full |
| **iOS** | SQLite | Optional | Auto | ✅ Full |
| **Web** | Supabase | Required | Real-time | ❌ Needs internet |
| **Desktop** | SQLite | Optional | Auto | ✅ Full |

---

## Localization

### Supported Languages
- **English** (default)
- **Hindi** (हिन्दी)

### What Gets Translated
- Navigation labels
- Button text
- Form labels
- Error messages
- Dashboard text

### How to Switch
- **Settings** → **Display** → **Language** → Select English or Hindi
- Preference persists across app restarts

---

## Theme & UI

### Light Mode (Default)
- Clean white background
- Blue primary color (#0D47A1)
- Material Design 3 styling

### Dark Mode
- Dark background
- Lighter grey tones for cards
- Maintains readability

### UI Components
- **Skeleton loading**: Shimmer effect while data loads
- **Empty states**: Custom illustrations when lists are empty
- **Pull-to-refresh** on all list screens
- **Responsive layout**: Works on phone, tablet, and desktop
- **Bottom navigation** on mobile, sidebar on desktop

---

## Testing & Quality

### Test Coverage

| Category | Tests | Description |
|----------|-------|-------------|
| **Widget Tests** | 17 | UI components render correctly |
| **Golden Tests** | 6 | Visual regression testing |
| **Unit Tests** | 30+ | Business logic verification |
| **Integration Tests** | 1 | End-to-end workflow testing |
| **Backend Tests** | 20+ | Database, auth, sync engine |

### Test Categories
- **Authentication**: Login, logout, session persistence, role mapping
- **Student Management**: CRUD operations, search, filter
- **Teacher Management**: CRUD, subject assignment, salary
- **Attendance**: Mark, history, percentage calculation
- **Fee System**: Plan creation, payment recording, receipt generation
- **Test Results**: Mark entry, grade calculation, report generation
- **Backup/Restore**: Backup creation, restore, organisation verification
- **Sync Engine**: Offline/online sync, conflict resolution

---

## Technical Architecture

### Project Structure

```
lib/
├── main.dart                    # App entry point
├── app/                         # App widget and routing
├── core/                        # Database, data sources
│   ├── database/                # SQLite helper (27+ tables)
│   └── data_sources/            # SQLite & Supabase data sources
├── features/                    # Feature modules (18 features)
│   ├── academic_calendar/       # Calendar events & holidays
│   ├── analytics/               # Dashboard analytics
│   ├── attendance/              # Student & teacher attendance
│   ├── audit/                   # Audit trail logging
│   ├── authentication/          # Login, auth, session
│   ├── backup/                  # Backup, restore, recovery
│   ├── batches/                 # Student batch management
│   ├── branches/                # Multi-location support
│   ├── class_register/          # Daily class records
│   ├── dashboard/               # Admin dashboard
│   ├── fees/                    # Fee management
│   ├── homework/                # Homework assignment
│   ├── library/                 # Book management
│   ├── notices/                 # Announcements
│   ├── onboarding/              # First-run setup wizard
│   ├── parent_portal/           # Parent access
│   ├── payments/                # Payment gateway
│   ├── salary/                  # Teacher salary
│   ├── settings/                # Institute configuration
│   ├── splash/                  # Splash screen
│   ├── students/                # Student management
│   ├── teachers/                # Teacher management
│   ├── tests/                   # Exams & results
│   ├── timetable/               # Class schedule
│   └── transport/               # Transport management
├── shared/                      # Shared utilities
│   ├── api/                     # API clients
│   ├── config/                  # Backend configuration
│   ├── constants/               # App constants
│   ├── models/                  # Shared models
│   ├── providers/               # Riverpod providers
│   ├── screens/                 # Shared screens
│   ├── services/                # Shared services (12+)
│   ├── themes/                  # App themes
│   ├── utils/                   # Utility classes
│   └── widgets/                 # Reusable widgets
└── l10n/                        # Localization strings
```

### Database Tables (27+)

| Table | Purpose |
|-------|---------|
| `organisations` | Institute identity |
| `admin_accounts` | Admin user accounts |
| `users` | All users (admin, teacher, student) |
| `students` | Student master data |
| `teachers` | Teacher master data |
| `student_attendance` | Daily student attendance |
| `teacher_attendance` | Daily teacher attendance & hours |
| `daily_class_records` | Class register entries |
| `batches` | Student batch/group definitions |
| `batch_students` | Student-batch assignments |
| `timetable` | Weekly class schedule |
| `fees` | Fee structures |
| `fee_payments` | Payment transactions |
| `fee_installments` | Installment schedules |
| `teacher_payments` | Salary payment records |
| `teacher_pay_rate_history` | Hourly rate changes |
| `tests` | Test/exam definitions |
| `test_subjects` | Subjects per test |
| `test_results` | Student marks per subject |
| `notices` | Announcements |
| `notifications` | In-app notifications |
| `calendar_events` | Academic calendar events |
| `app_settings` | Key-value settings store |
| `audit_trail` | Action audit log |
| `analytics_events` | Analytics tracking |
| `sms_log` | SMS sending log |
| `sync_log` | Sync operation log |

### Key Services (12+)

| Service | Purpose |
|---------|---------|
| `SyncEngine` | Background data sync |
| `AnalyticsService` | Event tracking |
| `AuditService` | Action logging |
| `BiometricService` | Fingerprint/Face ID |
| `CrashReportingService` | Error capture |
| `CSVExportService` | Export to CSV |
| `CSVImportService` | Import from CSV |
| `LicenseService` | License validation |
| `LocalizationService` | Language switching |
| `NotificationService` | In-app notifications |
| `PushNotificationService` | FCM push notifications |
| `SMSService` | SMS sending |
| `SupabaseAuthService` | Cloud authentication |
| `ThemeService` | Light/dark mode |

---

## Summary: What You Can Do With This App

### For a Coaching Centre Owner:
✅ Manage 500+ students across multiple classes and boards  
✅ Track daily attendance (students and teachers)  
✅ Collect fees with receipts and installment tracking  
✅ Pay teacher salaries based on hours worked  
✅ Create and grade exams with result reports  
✅ Send notices to students, teachers, and parents  
✅ Generate ID cards and transfer certificates  
✅ Export reports as PDF, Excel, or Word  
✅ Backup and restore all data  
✅ Work offline on Android — no internet needed  
✅ Access from multiple devices with cloud sync (optional)  
✅ Run on web browser for desktop access (optional)  

### For Teachers:
✅ View their daily schedule  
✅ Mark student attendance  
✅ Enter exam marks  
✅ View their salary history  

### For Students/Parents:
✅ View attendance and fee status  
✅ Check exam results  
✅ Receive notices and announcements  

---

*Last updated: September 2026*  
*Documentation generated for Omega Education Centre ERP v1.0.0*
