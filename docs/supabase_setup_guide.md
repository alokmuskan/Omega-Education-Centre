# Omega Education Centre — Supabase Setup & Recovery Guide

## Table of Contents

1. [Supabase Project Setup](#1-supabase-project-setup)
2. [Database Schema](#2-database-schema)
3. [Admin Account Setup](#3-admin-account-setup)
4. [Environment Configuration](#4-environment-configuration)
5. [Login Guide](#5-login-guide)
6. [Database Tables Reference](#6-database-tables-reference)
7. [Emergency Recovery Procedures](#7-emergency-recovery-procedures)
8. [Troubleshooting](#8-troubleshooting)
9. [SQL Files Reference](#9-sql-files-reference)

---

## 1. Supabase Project Setup

### Create Account
1. Go to [https://supabase.com](https://supabase.com)
2. Click **"Start your project"**
3. Sign in with **GitHub**

### Create Project
1. Click **"New Project"**
2. Fill in:
   - **Organization**: Create new → `Omega Education Centre`
   - **Project name**: `omega-education-centre`
   - **Database password**: Choose a strong password (**SAVE THIS!**)
   - **Region**: `ap-south-1 (Mumbai)`
3. Click **"Create new project"**
4. Wait 2-3 minutes

### Disable Email Confirmation
1. Left sidebar → **Authentication** → **Providers**
2. Find **Email** provider → Turn OFF **"Confirm email"**
3. Click **"Save"**

### Get API Credentials
1. Left sidebar → **Settings** (gear icon) → **API**
2. Copy:
   - **Project URL**: `https://xxxxxxxx.supabase.co`
   - **anon public key**: `eyJhbGciOiJIUzI1NiIs...`

---

## 2. Database Schema

### Run Schema SQL
1. Go to **SQL Editor** → **New query**
2. Open file: `supabase/migrations/000_clean_reset.sql`
3. Copy ALL content → Paste into SQL Editor
4. Click **"Run"**
5. Wait for **"Success. No rows returned"**

**This creates 27 tables with:**
- Indexes for fast queries
- Row Level Security (RLS) policies
- Realtime for live updates
- Default organisation and settings

### Tables Created

| Category | Tables |
|----------|--------|
| Core | `organisations`, `admin_accounts`, `users` |
| People | `students`, `teachers` |
| Attendance | `student_attendance`, `teacher_attendance` |
| Classes | `daily_class_records`, `batches`, `batch_students`, `timetable` |
| Finance | `fees`, `fee_payments`, `fee_installments`, `teacher_payments`, `teacher_pay_rate_history` |
| Academics | `tests`, `test_subjects`, `test_results` |
| Communication | `notices`, `notifications`, `sms_log` |
| Calendar | `calendar_events` |
| System | `app_settings`, `audit_trail`, `analytics_events`, `sync_log` |

---

## 3. Admin Account Setup

### Method A: SQL (Recommended)
1. Go to **SQL Editor** → **New query**
2. Open file: `supabase/migrations/002_seed_admin.sql`
3. Copy ALL content → Paste into SQL Editor
4. Click **"Run"**

### Method B: Manual UI (If SQL Fails)
1. Left sidebar → **Authentication** → **Users**
2. Click **"Add user"** → **"Create new user"**
3. Fill in:
   - **Email**: `alokraj1319@gmail.com`
   - **Password**: `Alok@2006`
   - **Auto Confirm Email**: ✅ CHECK THIS BOX
4. Click **"Create user"**
5. Then run this SQL:
   ```sql
   INSERT INTO admin_accounts (username, displayName, passwordHash)
   VALUES ('alokraj1319@gmail.com', 'Alok', 'Alok@2006')
   ON CONFLICT (username) DO NOTHING;
   ```

### Verify Setup
```sql
-- Check auth user
SELECT id, email, email_confirmed_at FROM auth.users WHERE email = 'alokraj1319@gmail.com';

-- Check admin profile
SELECT id, username, displayName, isActive FROM admin_accounts;
```

---

## 4. Environment Configuration

### Create .env File
Create `.env` in your project root:

```
SUPABASE_URL=https://xxxxxxxx.supabase.co
SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIs...
ORG_CODE=ORG_OMEGA_DEFAULT
```

**⚠️ NEVER commit .env to git** — it's already in `.gitignore`.

---

## 5. Login Guide

### Credentials

| Field | Value |
|-------|-------|
| **Username** | `alokraj1319@gmail.com` |
| **Password** | `Alok@2006` |

### How Auth Works
```
You enter: alokraj1319@gmail.com / Alok@2006
         ↓
CentralAuthService detects '@' → uses email as-is
         ↓
Supabase Auth: POST /auth/v1/token
  { email: "alokraj1319@gmail.com", password: "Alok@2006" }
         ↓
  ✅ Login successful!
```

---

## 6. Database Tables Reference

### Core Tables

#### organisations
Multi-tenant organisation data.
```sql
CREATE TABLE organisations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL DEFAULT 'Omega Education Centre',
  code TEXT UNIQUE NOT NULL DEFAULT 'ORG_OMEGA_DEFAULT',
  address TEXT,
  phone TEXT,
  email TEXT,
  timezone TEXT DEFAULT 'Asia/Kolkata',
  createdAt TIMESTAMPTZ DEFAULT now(),
  updatedAt TIMESTAMPTZ DEFAULT now()
);
```

#### admin_accounts
Admin user profiles.
```sql
CREATE TABLE admin_accounts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  username TEXT UNIQUE NOT NULL,
  displayName TEXT,
  passwordHash TEXT,
  orgId UUID REFERENCES organisations(id),
  isActive BOOLEAN DEFAULT true,
  createdAt TIMESTAMPTZ DEFAULT now(),
  updatedAt TIMESTAMPTZ DEFAULT now()
);
```

#### users
General user accounts (teachers, students).
```sql
CREATE TABLE users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  userId TEXT UNIQUE NOT NULL,
  username TEXT UNIQUE NOT NULL,
  displayName TEXT,
  role TEXT NOT NULL DEFAULT 'student',
  orgId UUID REFERENCES organisations(id),
  isActive BOOLEAN DEFAULT true,
  createdAt TIMESTAMPTZ DEFAULT now(),
  updatedAt TIMESTAMPTZ DEFAULT now()
);
```

### People Tables

#### students
```sql
CREATE TABLE students (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  username TEXT UNIQUE NOT NULL,
  name TEXT NOT NULL,
  fatherName TEXT,
  phone TEXT,
  altPhone TEXT,
  studentClass TEXT,
  board TEXT,
  subjects TEXT,
  admissionDate TEXT,
  courseFee REAL DEFAULT 0.0,
  address TEXT,
  emergencyContact TEXT,
  notes TEXT,
  photoPath TEXT,
  orgId UUID REFERENCES organisations(id),
  isActive BOOLEAN DEFAULT true,
  createdAt TIMESTAMPTZ DEFAULT now(),
  updatedAt TIMESTAMPTZ DEFAULT now()
);
```

#### teachers
```sql
CREATE TABLE teachers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  username TEXT UNIQUE NOT NULL,
  name TEXT NOT NULL,
  phone TEXT,
  subjects TEXT,
  qualifications TEXT,
  experience TEXT,
  payPerHour REAL DEFAULT 0.0,
  joinDate TEXT,
  address TEXT,
  emergencyContact TEXT,
  notes TEXT,
  orgId UUID REFERENCES organisations(id),
  isActive BOOLEAN DEFAULT true,
  createdAt TIMESTAMPTZ DEFAULT now(),
  updatedAt TIMESTAMPTZ DEFAULT now()
);
```

### Attendance Tables

#### student_attendance
```sql
CREATE TABLE student_attendance (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  studentId UUID REFERENCES students(id) ON DELETE CASCADE,
  date TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'Present',
  checkInTime TEXT,
  checkOutTime TEXT,
  markedBy TEXT,
  notes TEXT,
  orgId UUID REFERENCES organisations(id),
  createdAt TIMESTAMPTZ DEFAULT now()
);
```

#### teacher_attendance
```sql
CREATE TABLE teacher_attendance (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  teacherId UUID REFERENCES teachers(id) ON DELETE CASCADE,
  date TEXT NOT NULL,
  status TEXT DEFAULT 'Present',
  checkInTime TEXT,
  checkOutTime TEXT,
  hoursWorked REAL DEFAULT 0.0,
  notes TEXT,
  orgId UUID REFERENCES organisations(id),
  createdAt TIMESTAMPTZ DEFAULT now()
);
```

### Class Tables

#### daily_class_records
```sql
CREATE TABLE daily_class_records (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  date TEXT NOT NULL,
  startTime TEXT,
  endTime TEXT,
  studentClass TEXT,
  batch TEXT,
  subject TEXT,
  topic TEXT,
  durationMinutes INTEGER DEFAULT 0,
  teacherId UUID REFERENCES teachers(id),
  notes TEXT,
  orgId UUID REFERENCES organisations(id),
  createdAt TIMESTAMPTZ DEFAULT now(),
  updatedAt TIMESTAMPTZ DEFAULT now()
);
```

### Finance Tables

#### fees
```sql
CREATE TABLE fees (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  studentId UUID REFERENCES students(id) ON DELETE CASCADE,
  studentName TEXT,
  studentClass TEXT,
  courseFee REAL DEFAULT 0.0,
  dueDate TEXT,
  status TEXT DEFAULT 'Pending',
  academicYear TEXT,
  orgId UUID REFERENCES organisations(id),
  createdAt TIMESTAMPTZ DEFAULT now(),
  updatedAt TIMESTAMPTZ DEFAULT now()
);
```

#### fee_payments
```sql
CREATE TABLE fee_payments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  feeId UUID REFERENCES fees(id) ON DELETE CASCADE,
  studentId UUID REFERENCES students(id),
  amountPaid REAL DEFAULT 0.0,
  paymentDate TEXT,
  paymentMethod TEXT,
  receiptNumber TEXT,
  notes TEXT,
  orgId UUID REFERENCES organisations(id),
  createdAt TIMESTAMPTZ DEFAULT now()
);
```

### Academic Tables

#### tests
```sql
CREATE TABLE tests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  studentClass TEXT,
  subject TEXT,
  totalMarks REAL DEFAULT 0.0,
  passingMarks REAL DEFAULT 0.0,
  testDate TEXT,
  testType TEXT,
  description TEXT,
  orgId UUID REFERENCES organisations(id),
  createdAt TIMESTAMPTZ DEFAULT now(),
  updatedAt TIMESTAMPTZ DEFAULT now()
);
```

---

## 7. Emergency Recovery Procedures

### ⚠️ IMPORTANT: Save these in a password manager!

### Recovery 1: Find User ID
```sql
SELECT id, email FROM auth.users WHERE email = 'alokraj1319@gmail.com';
```

### Recovery 2: Reset Password
Replace `YOUR_UUID_HERE` with the UUID from Recovery 1:
```sql
UPDATE auth.users
SET encrypted_password = crypt('NewPassword123!', gen_salt('bf')),
    updated_at = now()
WHERE id = 'YOUR_UUID_HERE';
```

### Recovery 3: Create Emergency Admin
If all admin accounts are broken:
```sql
CREATE EXTENSION IF NOT EXISTS pgcrypto;

INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, created_at, updated_at,
  confirmation_token, recovery_token,
  raw_app_meta_data, raw_user_meta_data
) VALUES (
  '00000000-0000-0000-0000-000000000000',
  gen_random_uuid(), 'authenticated', 'authenticated',
  'emergency@omega.recovery',
  crypt('TempRecovery@2026!', gen_salt('bf')),
  now(), now(), now(), '', '',
  '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"role": "admin", "display_name": "Emergency Admin"}'::jsonb
);

INSERT INTO admin_accounts (username, displayName, passwordHash)
VALUES ('emergency@omega.recovery', 'Emergency Admin', 'TempRecovery@2026!')
ON CONFLICT (username) DO NOTHING;
```

**Login with:** `emergency@omega.recovery` / `TempRecovery@2026!`

**After recovering, DELETE emergency user:**
```sql
DELETE FROM auth.users WHERE email = 'emergency@omega.recovery';
DELETE FROM admin_accounts WHERE username = 'emergency@omega.recovery';
```

### Recovery 4: Disable RLS Temporarily
If RLS policies are blocking all access:
```sql
ALTER TABLE organisations DISABLE ROW LEVEL SECURITY;
ALTER TABLE admin_accounts DISABLE ROW LEVEL SECURITY;
ALTER TABLE users DISABLE ROW LEVEL SECURITY;
ALTER TABLE teachers DISABLE ROW LEVEL SECURITY;
ALTER TABLE students DISABLE ROW LEVEL SECURITY;
ALTER TABLE student_attendance DISABLE ROW LEVEL SECURITY;
ALTER TABLE teacher_attendance DISABLE ROW LEVEL SECURITY;
ALTER TABLE daily_class_records DISABLE ROW LEVEL SECURITY;
ALTER TABLE fees DISABLE ROW LEVEL SECURITY;
ALTER TABLE fee_payments DISABLE ROW LEVEL SECURITY;
ALTER TABLE notices DISABLE ROW LEVEL SECURITY;
ALTER TABLE tests DISABLE ROW LEVEL SECURITY;
ALTER TABLE test_results DISABLE ROW LEVEL SECURITY;
ALTER TABLE app_settings DISABLE ROW LEVEL SECURITY;
```

**⚠️ Re-enable after fixing:**
```sql
ALTER TABLE organisations ENABLE ROW LEVEL SECURITY;
ALTER TABLE admin_accounts ENABLE ROW LEVEL SECURITY;
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE teachers ENABLE ROW LEVEL SECURITY;
ALTER TABLE students ENABLE ROW LEVEL SECURITY;
ALTER TABLE student_attendance ENABLE ROW LEVEL SECURITY;
ALTER TABLE teacher_attendance ENABLE ROW LEVEL SECURITY;
ALTER TABLE daily_class_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE fees ENABLE ROW LEVEL SECURITY;
ALTER TABLE fee_payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE notices ENABLE ROW LEVEL SECURITY;
ALTER TABLE tests ENABLE ROW LEVEL SECURITY;
ALTER TABLE test_results ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_settings ENABLE ROW LEVEL SECURITY;
```

### Recovery 5: Check All Admin Accounts
```sql
SELECT id, username, displayName, isActive, createdAt
FROM admin_accounts
ORDER BY createdAt DESC;
```

### Recovery 6: Check All Auth Users
```sql
SELECT id, email, email_confirmed_at, created_at, last_sign_in_at
FROM auth.users
ORDER BY created_at DESC;
```

---

## 8. Troubleshooting

### Problem: "Invalid login credentials"
**Solution:**
1. Verify email confirmation is disabled (Auth → Providers → Email)
2. Check user exists: `SELECT * FROM auth.users WHERE email = 'your@email.com';`
3. If not, create user via UI (Auth → Users → Add user)
4. Create admin profile: `INSERT INTO admin_accounts (username, displayName, passwordHash) VALUES ('your@email.com', 'Your Name', 'your_password');`

### Problem: "Table doesn't exist"
**Solution:**
1. Run `000_clean_reset.sql` in SQL Editor
2. Wait for "Success. No rows returned"

### Problem: "RLS policy violation"
**Solution:**
1. Check RLS is enabled: `SELECT tablename FROM pg_tables WHERE schemaname = 'public';`
2. Check policies exist: `SELECT * FROM pg_policies WHERE schemaname = 'public';`
3. If needed, temporarily disable RLS (see Recovery 4)

### Problem: "Supabase connection failed"
**Solution:**
1. Check `.env` file has correct URL and key
2. Verify project is running: Go to Supabase Dashboard → Check project status
3. Test connection: Run a simple query in SQL Editor

### Problem: "Email confirmation required"
**Solution:**
1. Go to Auth → Providers → Email
2. Turn OFF "Confirm email"
3. Save changes

---

## 9. SQL Files Reference

| File | Purpose | When to Run |
|------|---------|-------------|
| `000_clean_reset.sql` | Complete schema setup | First time or to reset database |
| `002_seed_admin.sql` | Create admin user | After running 000_clean_reset.sql |
| `003_emergency_recovery.sql` | Recovery procedures | Only when locked out (keep in password manager) |

### Execution Order
1. `000_clean_reset.sql` → Creates all tables
2. `002_seed_admin.sql` → Creates admin account
3. `003_emergency_recovery.sql` → Keep in password manager, run only when needed

---

## Quick Reference Card

| Item | Value |
|------|-------|
| **Supabase Dashboard** | https://supabase.com/dashboard |
| **Login Username** | `alokraj1319@gmail.com` |
| **Login Password** | `Alok@2006` |
| **Project URL** | `https://xxxxxxxx.supabase.co` (your value) |
| **Anon Key** | `eyJhbGci...` (your value) |
| **Recovery SQL** | Saved in your password manager |

---

## Security Notes

1. **Never commit .env to git** — it contains sensitive credentials
2. **Save recovery SQL in password manager** — not in code repository
3. **Use strong passwords** — especially for Supabase project and admin accounts
4. **Regular backups** — Supabase provides automatic backups, but consider manual exports
5. **Monitor access** — Check `audit_trail` table regularly for suspicious activity

---

*Last updated: September 2026*
*Project: Omega Education Centre ERP*
