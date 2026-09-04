-- ============================================================
-- Omega Education Centre ERP — CLEAN RESET
-- ============================================================
-- WARNING: This drops ALL existing tables and re-creates them.
-- Only run this on a fresh/development database.
-- Run in: Supabase Dashboard → SQL Editor
-- ============================================================

-- ─── DROP ALL EXISTING TABLES (in correct order for FKs) ───
DROP TABLE IF EXISTS audit_trail CASCADE;
DROP TABLE IF EXISTS analytics_events CASCADE;
DROP TABLE IF EXISTS sms_log CASCADE;
DROP TABLE IF EXISTS sync_log CASCADE;
DROP TABLE IF EXISTS notifications CASCADE;
DROP TABLE IF EXISTS calendar_events CASCADE;
DROP TABLE IF EXISTS timetable CASCADE;
DROP TABLE IF EXISTS batch_students CASCADE;
DROP TABLE IF EXISTS batches CASCADE;
DROP TABLE IF EXISTS notices CASCADE;
DROP TABLE IF EXISTS test_results CASCADE;
DROP TABLE IF EXISTS test_subjects CASCADE;
DROP TABLE IF EXISTS tests CASCADE;
DROP TABLE IF EXISTS teacher_pay_rate_history CASCADE;
DROP TABLE IF EXISTS teacher_payments CASCADE;
DROP TABLE IF EXISTS fee_installments CASCADE;
DROP TABLE IF EXISTS fee_payments CASCADE;
DROP TABLE IF EXISTS fees CASCADE;
DROP TABLE IF EXISTS daily_class_records CASCADE;
DROP TABLE IF EXISTS teacher_attendance CASCADE;
DROP TABLE IF EXISTS student_attendance CASCADE;
DROP TABLE IF EXISTS students CASCADE;
DROP TABLE IF EXISTS teachers CASCADE;
DROP TABLE IF EXISTS users CASCADE;
DROP TABLE IF EXISTS admin_accounts CASCADE;
DROP TABLE IF EXISTS app_settings CASCADE;
DROP TABLE IF EXISTS organisations CASCADE;

-- Also drop any tables from previous schema attempts
DROP TABLE IF EXISTS books CASCADE;
DROP TABLE IF EXISTS book_issues CASCADE;
DROP TABLE IF EXISTS vehicles CASCADE;
DROP TABLE IF EXISTS transport_routes CASCADE;
DROP TABLE IF EXISTS transport_vehicles CASCADE;
DROP TABLE IF EXISTS transport_students CASCADE;

-- ════════════════════════════════════════════════════════════
-- CREATE ALL TABLES
-- ════════════════════════════════════════════════════════════

-- ─── 1. ORGANISATIONS ──────────────────────────────────────
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

INSERT INTO organisations (name, code) VALUES ('Omega Education Centre', 'ORG_OMEGA_DEFAULT');

-- ─── 2. ADMIN ACCOUNTS ─────────────────────────────────────
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

-- ─── 3. USERS ──────────────────────────────────────────────
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

-- ─── 4. TEACHERS ───────────────────────────────────────────
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

-- ─── 5. STUDENTS ───────────────────────────────────────────
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

-- ─── 6. STUDENT ATTENDANCE ─────────────────────────────────
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

-- ─── 7. TEACHER ATTENDANCE ─────────────────────────────────
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

-- ─── 8. DAILY CLASS RECORDS ────────────────────────────────
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

-- ─── 9. FEES ───────────────────────────────────────────────
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

-- ─── 10. FEE PAYMENTS ──────────────────────────────────────
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

-- ─── 11. FEE INSTALLMENTS ──────────────────────────────────
CREATE TABLE fee_installments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  feeId UUID REFERENCES fees(id) ON DELETE CASCADE,
  installmentNumber INTEGER,
  amount REAL DEFAULT 0.0,
  dueDate TEXT,
  status TEXT DEFAULT 'Pending',
  orgId UUID REFERENCES organisations(id),
  createdAt TIMESTAMPTZ DEFAULT now()
);

-- ─── 12. TEACHER PAYMENTS ──────────────────────────────────
CREATE TABLE teacher_payments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  teacherId UUID REFERENCES teachers(id) ON DELETE CASCADE,
  amount REAL DEFAULT 0.0,
  year INTEGER,
  month INTEGER,
  paymentDate TEXT,
  paymentMethod TEXT,
  notes TEXT,
  orgId UUID REFERENCES organisations(id),
  createdAt TIMESTAMPTZ DEFAULT now()
);

-- ─── 13. TEACHER PAY RATE HISTORY ──────────────────────────
CREATE TABLE teacher_pay_rate_history (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  teacherId UUID REFERENCES teachers(id) ON DELETE CASCADE,
  oldRate REAL,
  newRate REAL,
  effectiveDate TEXT,
  changedBy TEXT,
  orgId UUID REFERENCES organisations(id),
  createdAt TIMESTAMPTZ DEFAULT now()
);

-- ─── 14. TESTS ─────────────────────────────────────────────
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

-- ─── 15. TEST SUBJECTS ─────────────────────────────────────
CREATE TABLE test_subjects (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  testId UUID REFERENCES tests(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  totalMarks REAL DEFAULT 0.0,
  passingMarks REAL DEFAULT 0.0,
  orgId UUID REFERENCES organisations(id),
  createdAt TIMESTAMPTZ DEFAULT now()
);

-- ─── 16. TEST RESULTS ──────────────────────────────────────
CREATE TABLE test_results (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  testId UUID REFERENCES tests(id) ON DELETE CASCADE,
  studentId UUID REFERENCES students(id) ON DELETE CASCADE,
  studentName TEXT,
  totalObtained REAL DEFAULT 0.0,
  percentage REAL DEFAULT 0.0,
  grade TEXT,
  remarks TEXT,
  orgId UUID REFERENCES organisations(id),
  createdAt TIMESTAMPTZ DEFAULT now(),
  updatedAt TIMESTAMPTZ DEFAULT now()
);

-- ─── 17. NOTICES ───────────────────────────────────────────
CREATE TABLE notices (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title TEXT NOT NULL,
  content TEXT,
  type TEXT DEFAULT 'General',
  targetAudience TEXT DEFAULT 'All',
  isActive BOOLEAN DEFAULT true,
  orgId UUID REFERENCES organisations(id),
  createdAt TIMESTAMPTZ DEFAULT now(),
  updatedAt TIMESTAMPTZ DEFAULT now()
);

-- ─── 18. BATCHES ───────────────────────────────────────────
CREATE TABLE batches (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  studentClass TEXT,
  startTime TEXT,
  endTime TEXT,
  days TEXT,
  teacherId UUID REFERENCES teachers(id),
  maxStudents INTEGER DEFAULT 30,
  orgId UUID REFERENCES organisations(id),
  isActive BOOLEAN DEFAULT true,
  createdAt TIMESTAMPTZ DEFAULT now(),
  updatedAt TIMESTAMPTZ DEFAULT now()
);

-- ─── 19. BATCH-STUDENT MAPPING ─────────────────────────────
CREATE TABLE batch_students (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  batchId UUID REFERENCES batches(id) ON DELETE CASCADE,
  studentId UUID REFERENCES students(id) ON DELETE CASCADE,
  orgId UUID REFERENCES organisations(id),
  createdAt TIMESTAMPTZ DEFAULT now(),
  UNIQUE(batchId, studentId)
);

-- ─── 20. TIMETABLE ─────────────────────────────────────────
CREATE TABLE timetable (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  dayOfWeek TEXT NOT NULL,
  startTime TEXT NOT NULL,
  endTime TEXT,
  studentClass TEXT,
  batch TEXT,
  subject TEXT,
  teacherId UUID REFERENCES teachers(id),
  room TEXT,
  orgId UUID REFERENCES organisations(id),
  isActive BOOLEAN DEFAULT true,
  createdAt TIMESTAMPTZ DEFAULT now()
);

-- ─── 21. CALENDAR EVENTS ───────────────────────────────────
CREATE TABLE calendar_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title TEXT NOT NULL,
  date TEXT NOT NULL,
  type TEXT DEFAULT 'Event',
  description TEXT,
  orgId UUID REFERENCES organisations(id),
  createdAt TIMESTAMPTZ DEFAULT now()
);

-- ─── 22. NOTIFICATIONS ─────────────────────────────────────
CREATE TABLE notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  userId TEXT NOT NULL,
  title TEXT NOT NULL,
  message TEXT,
  type TEXT DEFAULT 'info',
  isRead BOOLEAN DEFAULT false,
  actionUrl TEXT,
  orgId UUID REFERENCES organisations(id),
  createdAt TIMESTAMPTZ DEFAULT now()
);

-- ─── 23. SMS LOG ───────────────────────────────────────────
CREATE TABLE sms_log (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  recipientPhone TEXT,
  recipientName TEXT,
  message TEXT,
  status TEXT DEFAULT 'sent',
  orgId UUID REFERENCES organisations(id),
  createdAt TIMESTAMPTZ DEFAULT now()
);

-- ─── 24. ANALYTICS EVENTS ──────────────────────────────────
CREATE TABLE analytics_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  eventType TEXT NOT NULL,
  eventData TEXT,
  userId TEXT,
  orgId UUID REFERENCES organisations(id),
  createdAt TIMESTAMPTZ DEFAULT now()
);

-- ─── 25. AUDIT TRAIL ───────────────────────────────────────
CREATE TABLE audit_trail (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  action TEXT NOT NULL,
  entityType TEXT,
  entityId UUID,
  userId TEXT,
  userName TEXT,
  oldValue TEXT,
  newValue TEXT,
  orgId UUID REFERENCES organisations(id),
  createdAt TIMESTAMPTZ DEFAULT now()
);

-- ─── 26. APP SETTINGS ──────────────────────────────────────
CREATE TABLE app_settings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  key TEXT UNIQUE NOT NULL,
  value TEXT,
  orgId UUID REFERENCES organisations(id),
  updatedAt TIMESTAMPTZ DEFAULT now()
);

INSERT INTO app_settings (key, value) VALUES
  ('school_name', 'Omega Education Centre'),
  ('school_board', 'CBSE'),
  ('timezone', 'Asia/Kolkata'),
  ('currency', 'INR');

-- ─── 27. SYNC LOG ──────────────────────────────────────────
CREATE TABLE sync_log (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  entityType TEXT NOT NULL,
  action TEXT NOT NULL,
  recordId UUID,
  status TEXT DEFAULT 'success',
  errorMessage TEXT,
  orgId UUID REFERENCES organisations(id),
  createdAt TIMESTAMPTZ DEFAULT now()
);

-- ════════════════════════════════════════════════════════════
-- INDEXES
-- ════════════════════════════════════════════════════════════
CREATE INDEX idx_students_class ON students(studentClass);
CREATE INDEX idx_students_active ON students(isActive);
CREATE INDEX idx_teachers_active ON teachers(isActive);
CREATE INDEX idx_attendance_date ON student_attendance(date);
CREATE INDEX idx_attendance_student ON student_attendance(studentId);
CREATE INDEX idx_teacher_attendance_date ON teacher_attendance(date);
CREATE INDEX idx_class_records_date ON daily_class_records(date);
CREATE INDEX idx_fees_student ON fees(studentId);
CREATE INDEX idx_fee_payments_fee ON fee_payments(feeId);
CREATE INDEX idx_test_results_test ON test_results(testId);
CREATE INDEX idx_test_results_student ON test_results(studentId);
CREATE INDEX idx_notices_active ON notices(isActive);
CREATE INDEX idx_timetable_day ON timetable(dayOfWeek);
CREATE INDEX idx_calendar_date ON calendar_events(date);
CREATE INDEX idx_notifications_user ON notifications(userId);
CREATE INDEX idx_sync_log_entity ON sync_log(entityType);
CREATE INDEX idx_audit_trail_entity ON audit_trail(entityType, entityId);

-- ════════════════════════════════════════════════════════════
-- ROW LEVEL SECURITY (RLS)
-- ════════════════════════════════════════════════════════════
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

-- Permissive policies for development (anon key can read/write everything)
DO $$
DECLARE
  t TEXT;
  tables_list TEXT[] := ARRAY[
    'organisations', 'admin_accounts', 'users', 'teachers', 'students',
    'student_attendance', 'teacher_attendance', 'daily_class_records',
    'fees', 'fee_payments', 'fee_installments', 'teacher_payments',
    'teacher_pay_rate_history', 'tests', 'test_subjects', 'test_results',
    'notices', 'batches', 'batch_students', 'timetable', 'calendar_events',
    'notifications', 'sms_log', 'analytics_events', 'audit_trail',
    'app_settings', 'sync_log'
  ];
BEGIN
  FOREACH t IN ARRAY tables_list LOOP
    EXECUTE format(
      'CREATE POLICY "Allow all for anon" ON %I FOR ALL USING (true) WITH CHECK (true)',
      t
    );
  END LOOP;
END $$;

-- ════════════════════════════════════════════════════════════
-- REALTIME
-- ════════════════════════════════════════════════════════════
ALTER PUBLICATION supabase_realtime ADD TABLE notifications;
ALTER PUBLICATION supabase_realtime ADD TABLE student_attendance;
ALTER PUBLICATION supabase_realtime ADD TABLE teacher_attendance;
ALTER PUBLICATION supabase_realtime ADD TABLE notices;

-- ════════════════════════════════════════════════════════════
-- DONE! 27 tables, indexes, RLS, and realtime configured.
-- ════════════════════════════════════════════════════════════
