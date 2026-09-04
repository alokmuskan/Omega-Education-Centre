-- ============================================================
-- Omega Education Centre ERP — Supabase Schema
-- ============================================================
-- Run this in: Supabase Dashboard → SQL Editor
-- ============================================================

-- ─── 1. ORGANISATIONS (multi-tenant) ────────────────────────
CREATE TABLE IF NOT EXISTS organisations (
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

-- Seed default organisation
INSERT INTO organisations (name, code) VALUES ('Omega Education Centre', 'ORG_OMEGA_DEFAULT')
ON CONFLICT (code) DO NOTHING;

-- ─── 2. ADMIN ACCOUNTS ──────────────────────────────────────
CREATE TABLE IF NOT EXISTS admin_accounts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  username TEXT UNIQUE NOT NULL,
  displayName TEXT,
  passwordHash TEXT,
  orgId UUID REFERENCES organisations(id) DEFAULT (SELECT id FROM organisations WHERE code = 'ORG_OMEGA_DEFAULT'),
  isActive BOOLEAN DEFAULT true,
  createdAt TIMESTAMPTZ DEFAULT now(),
  updatedAt TIMESTAMPTZ DEFAULT now()
);

-- ─── 3. USERS (general auth table) ──────────────────────────
CREATE TABLE IF NOT EXISTS users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  userId TEXT UNIQUE NOT NULL,
  username TEXT UNIQUE NOT NULL,
  displayName TEXT,
  role TEXT NOT NULL DEFAULT 'student',
  orgId UUID REFERENCES organisations(id) DEFAULT (SELECT id FROM organisations WHERE code = 'ORG_OMEGA_DEFAULT'),
  isActive BOOLEAN DEFAULT true,
  createdAt TIMESTAMPTZ DEFAULT now(),
  updatedAt TIMESTAMPTZ DEFAULT now()
);

-- ─── 4. TEACHERS ────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS teachers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  username TEXT UNIQUE NOT NULL,
  name TEXT NOT NULL,
  phone TEXT,
  subjects TEXT, -- JSON array of subjects
  qualifications TEXT,
  experience TEXT,
  payPerHour REAL DEFAULT 0.0,
  joinDate TEXT,
  address TEXT,
  emergencyContact TEXT,
  notes TEXT,
  orgId UUID REFERENCES organisations(id) DEFAULT (SELECT id FROM organisations WHERE code = 'ORG_OMEGA_DEFAULT'),
  isActive BOOLEAN DEFAULT true,
  createdAt TIMESTAMPTZ DEFAULT now(),
  updatedAt TIMESTAMPTZ DEFAULT now()
);

-- ─── 5. STUDENTS ────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS students (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  username TEXT UNIQUE NOT NULL,
  name TEXT NOT NULL,
  fatherName TEXT,
  phone TEXT,
  altPhone TEXT,
  studentClass TEXT,
  board TEXT,
  subjects TEXT, -- JSON array
  admissionDate TEXT,
  courseFee REAL DEFAULT 0.0,
  address TEXT,
  emergencyContact TEXT,
  notes TEXT,
  photoPath TEXT,
  orgId UUID REFERENCES organisations(id) DEFAULT (SELECT id FROM organisations WHERE code = 'ORG_OMEGA_DEFAULT'),
  isActive BOOLEAN DEFAULT true,
  createdAt TIMESTAMPTZ DEFAULT now(),
  updatedAt TIMESTAMPTZ DEFAULT now()
);

-- ─── 6. STUDENT ATTENDANCE ──────────────────────────────────
CREATE TABLE IF NOT EXISTS student_attendance (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  studentId UUID REFERENCES students(id) ON DELETE CASCADE,
  date TEXT NOT NULL, -- YYYY-MM-DD
  status TEXT NOT NULL DEFAULT 'Present', -- Present, Absent, Late, Leave
  checkInTime TEXT,
  checkOutTime TEXT,
  markedBy TEXT,
  notes TEXT,
  orgId UUID REFERENCES organisations(id) DEFAULT (SELECT id FROM organisations WHERE code = 'ORG_OMEGA_DEFAULT'),
  createdAt TIMESTAMPTZ DEFAULT now()
);

-- ─── 7. TEACHER ATTENDANCE ──────────────────────────────────
CREATE TABLE IF NOT EXISTS teacher_attendance (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  teacherId UUID REFERENCES teachers(id) ON DELETE CASCADE,
  date TEXT NOT NULL, -- YYYY-MM-DD
  status TEXT DEFAULT 'Present',
  checkInTime TEXT,
  checkOutTime TEXT,
  hoursWorked REAL DEFAULT 0.0,
  notes TEXT,
  orgId UUID REFERENCES organisations(id) DEFAULT (SELECT id FROM organisations WHERE code = 'ORG_OMEGA_DEFAULT'),
  createdAt TIMESTAMPTZ DEFAULT now()
);

-- ─── 8. DAILY CLASS RECORDS ─────────────────────────────────
CREATE TABLE IF NOT EXISTS daily_class_records (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  date TEXT NOT NULL, -- YYYY-MM-DD
  startTime TEXT,
  endTime TEXT,
  studentClass TEXT,
  batch TEXT,
  subject TEXT,
  topic TEXT,
  durationMinutes INTEGER DEFAULT 0,
  teacherId UUID REFERENCES teachers(id),
  notes TEXT,
  orgId UUID REFERENCES organisations(id) DEFAULT (SELECT id FROM organisations WHERE code = 'ORG_OMEGA_DEFAULT'),
  createdAt TIMESTAMPTZ DEFAULT now(),
  updatedAt TIMESTAMPTZ DEFAULT now()
);

-- ─── 9. FEES ────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS fees (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  studentId UUID REFERENCES students(id) ON DELETE CASCADE,
  studentName TEXT,
  studentClass TEXT,
  courseFee REAL DEFAULT 0.0,
  dueDate TEXT,
  status TEXT DEFAULT 'Pending', -- Pending, Paid, Partial, Overdue
  academicYear TEXT,
  orgId UUID REFERENCES organisations(id) DEFAULT (SELECT id FROM organisations WHERE code = 'ORG_OMEGA_DEFAULT'),
  createdAt TIMESTAMPTZ DEFAULT now(),
  updatedAt TIMESTAMPTZ DEFAULT now()
);

-- ─── 10. FEE PAYMENTS ───────────────────────────────────────
CREATE TABLE IF NOT EXISTS fee_payments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  feeId UUID REFERENCES fees(id) ON DELETE CASCADE,
  studentId UUID REFERENCES students(id),
  amountPaid REAL DEFAULT 0.0,
  paymentDate TEXT,
  paymentMethod TEXT, -- Cash, UPI, Bank Transfer, etc.
  receiptNumber TEXT,
  notes TEXT,
  orgId UUID REFERENCES organisations(id) DEFAULT (SELECT id FROM organisations WHERE code = 'ORG_OMEGA_DEFAULT'),
  createdAt TIMESTAMPTZ DEFAULT now()
);

-- ─── 11. FEE INSTALLMENTS ───────────────────────────────────
CREATE TABLE IF NOT EXISTS fee_installments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  feeId UUID REFERENCES fees(id) ON DELETE CASCADE,
  installmentNumber INTEGER,
  amount REAL DEFAULT 0.0,
  dueDate TEXT,
  status TEXT DEFAULT 'Pending',
  orgId UUID REFERENCES organisations(id) DEFAULT (SELECT id FROM organisations WHERE code = 'ORG_OMEGA_DEFAULT'),
  createdAt TIMESTAMPTZ DEFAULT now()
);

-- ─── 12. TEACHER PAYMENTS ───────────────────────────────────
CREATE TABLE IF NOT EXISTS teacher_payments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  teacherId UUID REFERENCES teachers(id) ON DELETE CASCADE,
  amount REAL DEFAULT 0.0,
  year INTEGER,
  month INTEGER,
  paymentDate TEXT,
  paymentMethod TEXT,
  notes TEXT,
  orgId UUID REFERENCES organisations(id) DEFAULT (SELECT id FROM organisations WHERE code = 'ORG_OMEGA_DEFAULT'),
  createdAt TIMESTAMPTZ DEFAULT now()
);

-- ─── 13. TEACHER PAY RATE HISTORY ───────────────────────────
CREATE TABLE IF NOT EXISTS teacher_pay_rate_history (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  teacherId UUID REFERENCES teachers(id) ON DELETE CASCADE,
  oldRate REAL,
  newRate REAL,
  effectiveDate TEXT,
  changedBy TEXT,
  orgId UUID REFERENCES organisations(id) DEFAULT (SELECT id FROM organisations WHERE code = 'ORG_OMEGA_DEFAULT'),
  createdAt TIMESTAMPTZ DEFAULT now()
);

-- ─── 14. TESTS ──────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS tests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  studentClass TEXT,
  subject TEXT,
  totalMarks REAL DEFAULT 0.0,
  passingMarks REAL DEFAULT 0.0,
  testDate TEXT,
  testType TEXT, -- Unit Test, Mid-term, Final, etc.
  description TEXT,
  orgId UUID REFERENCES organisations(id) DEFAULT (SELECT id FROM organisations WHERE code = 'ORG_OMEGA_DEFAULT'),
  createdAt TIMESTAMPTZ DEFAULT now(),
  updatedAt TIMESTAMPTZ DEFAULT now()
);

-- ─── 15. TEST SUBJECTS ──────────────────────────────────────
CREATE TABLE IF NOT EXISTS test_subjects (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  testId UUID REFERENCES tests(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  totalMarks REAL DEFAULT 0.0,
  passingMarks REAL DEFAULT 0.0,
  orgId UUID REFERENCES organisations(id) DEFAULT (SELECT id FROM organisations WHERE code = 'ORG_OMEGA_DEFAULT'),
  createdAt TIMESTAMPTZ DEFAULT now()
);

-- ─── 16. TEST RESULTS ───────────────────────────────────────
CREATE TABLE IF NOT EXISTS test_results (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  testId UUID REFERENCES tests(id) ON DELETE CASCADE,
  studentId UUID REFERENCES students(id) ON DELETE CASCADE,
  studentName TEXT,
  totalObtained REAL DEFAULT 0.0,
  percentage REAL DEFAULT 0.0,
  grade TEXT,
  remarks TEXT,
  orgId UUID REFERENCES organisations(id) DEFAULT (SELECT id FROM organisations WHERE code = 'ORG_OMEGA_DEFAULT'),
  createdAt TIMESTAMPTZ DEFAULT now(),
  updatedAt TIMESTAMPTZ DEFAULT now()
);

-- ─── 17. NOTICES ────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS notices (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title TEXT NOT NULL,
  content TEXT,
  type TEXT DEFAULT 'General', -- General, Urgent, Event, Holiday
  targetAudience TEXT DEFAULT 'All', -- All, Students, Teachers, Parents
  isActive BOOLEAN DEFAULT true,
  orgId UUID REFERENCES organisations(id) DEFAULT (SELECT id FROM organisations WHERE code = 'ORG_OMEGA_DEFAULT'),
  createdAt TIMESTAMPTZ DEFAULT now(),
  updatedAt TIMESTAMPTZ DEFAULT now()
);

-- ─── 18. BATCHES ────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS batches (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  studentClass TEXT,
  startTime TEXT,
  endTime TEXT,
  days TEXT, -- JSON array: ["Monday","Wednesday"]
  teacherId UUID REFERENCES teachers(id),
  maxStudents INTEGER DEFAULT 30,
  orgId UUID REFERENCES organisations(id) DEFAULT (SELECT id FROM organisations WHERE code = 'ORG_OMEGA_DEFAULT'),
  isActive BOOLEAN DEFAULT true,
  createdAt TIMESTAMPTZ DEFAULT now(),
  updatedAt TIMESTAMPTZ DEFAULT now()
);

-- ─── 19. BATCH-STUDENT MAPPING ──────────────────────────────
CREATE TABLE IF NOT EXISTS batch_students (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  batchId UUID REFERENCES batches(id) ON DELETE CASCADE,
  studentId UUID REFERENCES students(id) ON DELETE CASCADE,
  orgId UUID REFERENCES organisations(id) DEFAULT (SELECT id FROM organisations WHERE code = 'ORG_OMEGA_DEFAULT'),
  createdAt TIMESTAMPTZ DEFAULT now(),
  UNIQUE(batchId, studentId)
);

-- ─── 20. TIMETABLE ──────────────────────────────────────────
CREATE TABLE IF NOT EXISTS timetable (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  dayOfWeek TEXT NOT NULL, -- Monday, Tuesday, etc.
  startTime TEXT NOT NULL,
  endTime TEXT,
  studentClass TEXT,
  batch TEXT,
  subject TEXT,
  teacherId UUID REFERENCES teachers(id),
  room TEXT,
  orgId UUID REFERENCES organisations(id) DEFAULT (SELECT id FROM organisations WHERE code = 'ORG_OMEGA_DEFAULT'),
  isActive BOOLEAN DEFAULT true,
  createdAt TIMESTAMPTZ DEFAULT now()
);

-- ─── 21. CALENDAR EVENTS ────────────────────────────────────
CREATE TABLE IF NOT EXISTS calendar_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title TEXT NOT NULL,
  date TEXT NOT NULL, -- YYYY-MM-DD
  type TEXT DEFAULT 'Event', -- Event, Holiday, Exam
  description TEXT,
  orgId UUID REFERENCES organisations(id) DEFAULT (SELECT id FROM organisations WHERE code = 'ORG_OMEGA_DEFAULT'),
  createdAt TIMESTAMPTZ DEFAULT now()
);

-- ─── 22. NOTIFICATIONS ──────────────────────────────────────
CREATE TABLE IF NOT EXISTS notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  userId TEXT NOT NULL,
  title TEXT NOT NULL,
  message TEXT,
  type TEXT DEFAULT 'info', -- info, warning, success, error
  isRead BOOLEAN DEFAULT false,
  actionUrl TEXT,
  orgId UUID REFERENCES organisations(id) DEFAULT (SELECT id FROM organisations WHERE code = 'ORG_OMEGA_DEFAULT'),
  createdAt TIMESTAMPTZ DEFAULT now()
);

-- ─── 23. SMS LOG ────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS sms_log (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  recipientPhone TEXT,
  recipientName TEXT,
  message TEXT,
  status TEXT DEFAULT 'sent', -- sent, delivered, failed
  orgId UUID REFERENCES organisations(id) DEFAULT (SELECT id FROM organisations WHERE code = 'ORG_OMEGA_DEFAULT'),
  createdAt TIMESTAMPTZ DEFAULT now()
);

-- ─── 24. ANALYTICS EVENTS ───────────────────────────────────
CREATE TABLE IF NOT EXISTS analytics_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  eventType TEXT NOT NULL,
  eventData TEXT, -- JSON
  userId TEXT,
  orgId UUID REFERENCES organisations(id) DEFAULT (SELECT id FROM organisations WHERE code = 'ORG_OMEGA_DEFAULT'),
  createdAt TIMESTAMPTZ DEFAULT now()
);

-- ─── 25. AUDIT TRAIL ────────────────────────────────────────
CREATE TABLE IF NOT EXISTS audit_trail (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  action TEXT NOT NULL,
  entityType TEXT,
  entityId UUID,
  userId TEXT,
  userName TEXT,
  oldValue TEXT, -- JSON
  newValue TEXT, -- JSON
  orgId UUID REFERENCES organisations(id) DEFAULT (SELECT id FROM organisations WHERE code = 'ORG_OMEGA_DEFAULT'),
  createdAt TIMESTAMPTZ DEFAULT now()
);

-- ─── 26. APP SETTINGS (key-value store) ─────────────────────
CREATE TABLE IF NOT EXISTS app_settings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  key TEXT UNIQUE NOT NULL,
  value TEXT,
  orgId UUID REFERENCES organisations(id) DEFAULT (SELECT id FROM organisations WHERE code = 'ORG_OMEGA_DEFAULT'),
  updatedAt TIMESTAMPTZ DEFAULT now()
);

-- Seed default settings
INSERT INTO app_settings (key, value) VALUES
  ('school_name', 'Omega Education Centre'),
  ('school_board', 'CBSE'),
  ('timezone', 'Asia/Kolkata'),
  ('currency', 'INR')
ON CONFLICT (key) DO NOTHING;

-- ─── 27. SYNC LOG (track sync operations) ───────────────────
CREATE TABLE IF NOT EXISTS sync_log (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  entityType TEXT NOT NULL,
  action TEXT NOT NULL, -- push, pull, conflict
  recordId UUID,
  status TEXT DEFAULT 'success', -- success, error, conflict
  errorMessage TEXT,
  orgId UUID REFERENCES organisations(id) DEFAULT (SELECT id FROM organisations WHERE code = 'ORG_OMEGA_DEFAULT'),
  createdAt TIMESTAMPTZ DEFAULT now()
);

-- ============================================================
-- INDEXES for performance
-- ============================================================
CREATE INDEX IF NOT EXISTS idx_students_class ON students(studentClass);
CREATE INDEX IF NOT EXISTS idx_students_active ON students(isActive);
CREATE INDEX IF NOT EXISTS idx_teachers_active ON teachers(isActive);
CREATE INDEX IF NOT EXISTS idx_attendance_date ON student_attendance(date);
CREATE INDEX IF NOT EXISTS idx_attendance_student ON student_attendance(studentId);
CREATE INDEX IF NOT EXISTS idx_teacher_attendance_date ON teacher_attendance(date);
CREATE INDEX IF NOT EXISTS idx_class_records_date ON daily_class_records(date);
CREATE INDEX IF NOT EXISTS idx_fees_student ON fees(studentId);
CREATE INDEX IF NOT EXISTS idx_fee_payments_fee ON fee_payments(feeId);
CREATE INDEX IF NOT EXISTS idx_test_results_test ON test_results(testId);
CREATE INDEX IF NOT EXISTS idx_test_results_student ON test_results(studentId);
CREATE INDEX IF NOT EXISTS idx_notices_active ON notices(isActive);
CREATE INDEX IF NOT EXISTS idx_timetable_day ON timetable(dayOfWeek);
CREATE INDEX IF NOT EXISTS idx_calendar_date ON calendar_events(date);
CREATE INDEX IF NOT EXISTS idx_notifications_user ON notifications(userId);
CREATE INDEX IF NOT EXISTS idx_sync_log_entity ON sync_log(entityType);
CREATE INDEX IF NOT EXISTS idx_audit_trail_entity ON audit_trail(entityType, entityId);

-- ============================================================
-- ROW LEVEL SECURITY (RLS)
-- ============================================================
-- Enable RLS on all tables
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
ALTER TABLE fee_installments ENABLE ROW LEVEL SECURITY;
ALTER TABLE teacher_payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE teacher_pay_rate_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE tests ENABLE ROW LEVEL SECURITY;
ALTER TABLE test_subjects ENABLE ROW LEVEL SECURITY;
ALTER TABLE test_results ENABLE ROW LEVEL SECURITY;
ALTER TABLE notices ENABLE ROW LEVEL SECURITY;
ALTER TABLE batches ENABLE ROW LEVEL SECURITY;
ALTER TABLE batch_students ENABLE ROW LEVEL SECURITY;
ALTER TABLE timetable ENABLE ROW LEVEL SECURITY;
ALTER TABLE calendar_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE sms_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE analytics_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_trail ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE sync_log ENABLE ROW LEVEL SECURITY;

-- ─── PERMISSIVE POLICIES (allow anon key for now) ───────────
-- These policies allow the anon key (used by the app) to read/write.
-- Tighten these policies for production with proper auth checks.

DO $$
DECLARE
  t TEXT;
  tables TEXT[] := ARRAY[
    'organisations', 'admin_accounts', 'users', 'teachers', 'students',
    'student_attendance', 'teacher_attendance', 'daily_class_records',
    'fees', 'fee_payments', 'fee_installments', 'teacher_payments',
    'teacher_pay_rate_history', 'tests', 'test_subjects', 'test_results',
    'notices', 'batches', 'batch_students', 'timetable', 'calendar_events',
    'notifications', 'sms_log', 'analytics_events', 'audit_trail',
    'app_settings', 'sync_log'
  ];
BEGIN
  FOREACH t IN ARRAY tables LOOP
    -- Allow all operations with anon key (for development)
    EXECUTE format(
      'CREATE POLICY "Allow all for anon" ON %I FOR ALL USING (true) WITH CHECK (true)',
      t
    );
  END LOOP;
END $$;

-- ============================================================
-- REALTIME (enable for tables that need live updates)
-- ============================================================
ALTER PUBLICATION supabase_realtime ADD TABLE notifications;
ALTER PUBLICATION supabase_realtime ADD TABLE student_attendance;
ALTER PUBLICATION supabase_realtime ADD TABLE teacher_attendance;
ALTER PUBLICATION supabase_realtime ADD TABLE notices;

-- ============================================================
-- Done! All tables created with RLS and indexes.
-- ============================================================
