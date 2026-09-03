-- ==============================================================================
-- OMEGA EDUCATION CENTRE ERP — CENTRAL SUPABASE POSTGRESQL SCHEMA (PHASE 26)
-- Target Platform: Supabase PostgreSQL
-- Features: Multi-tenant Organisation Isolation, UUID Keys, Soft Delete,
--           Revision Counters, Device Registration, Append-Only Financial Logs
-- ==============================================================================

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ── 1. ORGANISATIONS ──────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS organisations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    org_code VARCHAR(64) UNIQUE NOT NULL,
    name VARCHAR(255) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ── 2. USERS ──────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organisation_id UUID NOT NULL REFERENCES organisations(id) ON DELETE CASCADE,
    username VARCHAR(100) NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    role VARCHAR(32) NOT NULL CHECK (role IN ('Admin', 'Teacher', 'Student')),
    reference_id UUID,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    version INT NOT NULL DEFAULT 1,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMPTZ,
    UNIQUE (organisation_id, username)
);

CREATE INDEX idx_users_org_role ON users (organisation_id, role);
CREATE INDEX idx_users_username ON users (username);

-- ── 3. ADMINS ─────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS admins (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organisation_id UUID NOT NULL REFERENCES organisations(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    email VARCHAR(255),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (organisation_id, user_id)
);

-- ── 4. TEACHERS ───────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS teachers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organisation_id UUID NOT NULL REFERENCES organisations(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    mobile VARCHAR(15) NOT NULL,
    subjects TEXT NOT NULL, -- Comma-separated or JSON list (e.g. Mathematics, Physics)
    qualification VARCHAR(255),
    pay_per_hour NUMERIC(10, 2) NOT NULL DEFAULT 300.00,
    joining_date DATE NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    version INT NOT NULL DEFAULT 1,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMPTZ,
    UNIQUE (organisation_id, mobile)
);

CREATE INDEX idx_teachers_org ON teachers (organisation_id);

-- ── 5. STUDENTS ───────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS students (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organisation_id UUID NOT NULL REFERENCES organisations(id) ON DELETE CASCADE,
    roll_no INT NOT NULL,
    name VARCHAR(255) NOT NULL,
    father_name VARCHAR(255) NOT NULL,
    mother_name VARCHAR(255),
    mobile VARCHAR(15) NOT NULL,
    dob DATE,
    address TEXT,
    student_class VARCHAR(64) NOT NULL,
    board VARCHAR(64) NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    version INT NOT NULL DEFAULT 1,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMPTZ,
    UNIQUE (organisation_id, roll_no)
);

CREATE INDEX idx_students_org_class ON students (organisation_id, student_class);

-- ── 6. FEES ───────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS fees (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organisation_id UUID NOT NULL REFERENCES organisations(id) ON DELETE CASCADE,
    student_id UUID NOT NULL REFERENCES students(id) ON DELETE CASCADE,
    amount NUMERIC(10, 2) NOT NULL,
    due_date DATE,
    status VARCHAR(32) NOT NULL DEFAULT 'Pending',
    payment_method VARCHAR(64) NOT NULL DEFAULT 'Installments',
    course_fee NUMERIC(10, 2),
    monthly_amount NUMERIC(10, 2),
    payment_due_day INT,
    start_month VARCHAR(32),
    duration_months INT,
    remarks TEXT,
    version INT NOT NULL DEFAULT 1,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMPTZ
);

CREATE INDEX idx_fees_student ON fees (student_id);

-- ── 7. FEE PAYMENTS (APPEND-ONLY TRANSACTION LOG) ─────────────────────────────
CREATE TABLE IF NOT EXISTS fee_payments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organisation_id UUID NOT NULL REFERENCES organisations(id) ON DELETE CASCADE,
    fee_id UUID NOT NULL REFERENCES fees(id) ON DELETE CASCADE,
    receipt_no VARCHAR(100) NOT NULL,
    amount NUMERIC(10, 2) NOT NULL,
    payment_date TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    payment_method VARCHAR(64) NOT NULL,
    transaction_id VARCHAR(100),
    remarks TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (organisation_id, receipt_no)
);

CREATE INDEX idx_fee_payments_fee ON fee_payments (fee_id);

-- ── 8. FEE INSTALLMENTS ───────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS fee_installments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organisation_id UUID NOT NULL REFERENCES organisations(id) ON DELETE CASCADE,
    fee_id UUID NOT NULL REFERENCES fees(id) ON DELETE CASCADE,
    installment_number INT NOT NULL,
    amount NUMERIC(10, 2) NOT NULL,
    due_date DATE NOT NULL,
    status VARCHAR(32) NOT NULL DEFAULT 'Pending',
    paid_amount NUMERIC(10, 2) NOT NULL DEFAULT 0.00,
    paid_date DATE,
    version INT NOT NULL DEFAULT 1,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ── 9. STUDENT ATTENDANCE ─────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS student_attendance (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organisation_id UUID NOT NULL REFERENCES organisations(id) ON DELETE CASCADE,
    student_id UUID NOT NULL REFERENCES students(id) ON DELETE CASCADE,
    date DATE NOT NULL,
    status VARCHAR(32) NOT NULL CHECK (status IN ('Present', 'Absent', 'Late')),
    student_class VARCHAR(64) NOT NULL,
    remarks TEXT,
    version INT NOT NULL DEFAULT 1,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (organisation_id, student_id, date)
);

CREATE INDEX idx_student_attendance_date ON student_attendance (organisation_id, date);

-- ── 10. TEACHER ATTENDANCE ────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS teacher_attendance (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organisation_id UUID NOT NULL REFERENCES organisations(id) ON DELETE CASCADE,
    teacher_id UUID NOT NULL REFERENCES teachers(id) ON DELETE CASCADE,
    date DATE NOT NULL,
    status VARCHAR(32) NOT NULL CHECK (status IN ('Present', 'Absent', 'Half Day')),
    hours_worked NUMERIC(5, 2) NOT NULL DEFAULT 0.00,
    remarks TEXT,
    version INT NOT NULL DEFAULT 1,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (organisation_id, teacher_id, date)
);

-- ── 11. TEACHER PAYMENTS (APPEND-ONLY SALARY LOG) ────────────────────────────
CREATE TABLE IF NOT EXISTS teacher_payments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organisation_id UUID NOT NULL REFERENCES organisations(id) ON DELETE CASCADE,
    teacher_id UUID NOT NULL REFERENCES teachers(id) ON DELETE CASCADE,
    amount NUMERIC(10, 2) NOT NULL,
    payment_date DATE NOT NULL,
    month VARCHAR(20) NOT NULL,
    year INT NOT NULL,
    payment_method VARCHAR(64) NOT NULL DEFAULT 'Cash',
    remarks TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ── 12. TEACHER PAY RATE HISTORY ──────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS teacher_pay_rate_history (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organisation_id UUID NOT NULL REFERENCES organisations(id) ON DELETE CASCADE,
    teacher_id UUID NOT NULL REFERENCES teachers(id) ON DELETE CASCADE,
    pay_per_hour NUMERIC(10, 2) NOT NULL,
    effective_date DATE NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ── 13. TESTS ─────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS tests (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organisation_id UUID NOT NULL REFERENCES organisations(id) ON DELETE CASCADE,
    title VARCHAR(255) NOT NULL,
    date DATE NOT NULL,
    max_marks NUMERIC(10, 2) NOT NULL,
    pass_marks NUMERIC(10, 2) NOT NULL,
    student_class VARCHAR(64) NOT NULL,
    board VARCHAR(64) NOT NULL,
    test_type VARCHAR(64) NOT NULL,
    academic_year VARCHAR(32) NOT NULL,
    version INT NOT NULL DEFAULT 1,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMPTZ
);

-- ── 14. TEST SUBJECTS ─────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS test_subjects (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organisation_id UUID NOT NULL REFERENCES organisations(id) ON DELETE CASCADE,
    test_id UUID NOT NULL REFERENCES tests(id) ON DELETE CASCADE,
    subject_name VARCHAR(100) NOT NULL,
    max_marks NUMERIC(10, 2) NOT NULL,
    pass_marks NUMERIC(10, 2) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ── 15. TEST RESULTS ──────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS test_results (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organisation_id UUID NOT NULL REFERENCES organisations(id) ON DELETE CASCADE,
    test_id UUID NOT NULL REFERENCES tests(id) ON DELETE CASCADE,
    student_id UUID NOT NULL REFERENCES students(id) ON DELETE CASCADE,
    test_subject_id UUID NOT NULL REFERENCES test_subjects(id) ON DELETE CASCADE,
    marks_obtained NUMERIC(10, 2) NOT NULL DEFAULT 0.00,
    is_absent BOOLEAN NOT NULL DEFAULT FALSE,
    remarks TEXT,
    version INT NOT NULL DEFAULT 1,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (test_id, student_id, test_subject_id)
);

-- ── 16. DAILY CLASS RECORDS ───────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS daily_class_records (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organisation_id UUID NOT NULL REFERENCES organisations(id) ON DELETE CASCADE,
    teacher_id UUID NOT NULL REFERENCES teachers(id) ON DELETE CASCADE,
    date DATE NOT NULL,
    class_name VARCHAR(64) NOT NULL,
    subject VARCHAR(100) NOT NULL,
    topics_covered TEXT NOT NULL,
    homework_assigned TEXT,
    remarks TEXT,
    version INT NOT NULL DEFAULT 1,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ── 17. TIMETABLE ENTRIES ─────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS timetable_entries (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organisation_id UUID NOT NULL REFERENCES organisations(id) ON DELETE CASCADE,
    class_name VARCHAR(64) NOT NULL,
    subject VARCHAR(100) NOT NULL,
    teacher_id UUID NOT NULL REFERENCES teachers(id) ON DELETE CASCADE,
    day_of_week VARCHAR(20) NOT NULL,
    start_time VARCHAR(20) NOT NULL,
    end_time VARCHAR(20) NOT NULL,
    room_number VARCHAR(50),
    period_number INT,
    version INT NOT NULL DEFAULT 1,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ── 18. NOTICES ───────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS notices (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organisation_id UUID NOT NULL REFERENCES organisations(id) ON DELETE CASCADE,
    title VARCHAR(255) NOT NULL,
    content TEXT NOT NULL,
    publish_date DATE NOT NULL,
    target_role VARCHAR(32) NOT NULL DEFAULT 'All',
    target_class VARCHAR(64),
    target_board VARCHAR(64),
    is_published BOOLEAN NOT NULL DEFAULT TRUE,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    version INT NOT NULL DEFAULT 1,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ── 19. NOTICE READ RECEIPTS ─────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS notice_reads (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organisation_id UUID NOT NULL REFERENCES organisations(id) ON DELETE CASCADE,
    notice_id UUID NOT NULL REFERENCES notices(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    read_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (notice_id, user_id)
);

-- ── 20. DEVICE REGISTRATION TABLE ──────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS devices (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organisation_id UUID NOT NULL REFERENCES organisations(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    device_identifier VARCHAR(255) NOT NULL,
    device_name VARCHAR(255),
    device_type VARCHAR(64), -- e.g. Android, iOS, Windows
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    registered_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    last_seen_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    revoked_at TIMESTAMPTZ,
    UNIQUE (organisation_id, user_id, device_identifier)
);

CREATE INDEX idx_devices_user ON devices (user_id);
