-- ==============================================================================
-- OMEGA EDUCATION CENTRE ERP — ROW LEVEL SECURITY (RLS) POLICIES (PHASE 32)
-- Target Platform: Supabase PostgreSQL
-- Enforces: Organisation Isolation, Multi-Admin Access, Teacher Data Isolation,
--           Student Data Isolation, Device Binding Security
-- ==============================================================================

-- Enable RLS on all central ERP tables
ALTER TABLE public.organisations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.admins ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.teachers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.students ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.fees ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.fee_payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.fee_installments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.student_attendance ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.teacher_attendance ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.teacher_payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.teacher_pay_rate_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.test_subjects ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.test_results ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.daily_class_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.timetable_entries ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notices ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notice_reads ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.devices ENABLE ROW LEVEL SECURITY;

-- ── 1. HELPER FUNCTIONS FOR SECURITY CLAIMS (SECURITY DEFINER) ────────────────

CREATE OR REPLACE FUNCTION public.current_org_id() 
RETURNS UUID AS $$
  SELECT organisation_id FROM public.users WHERE id = auth.uid() LIMIT 1;
$$ LANGUAGE SQL STABLE SECURITY DEFINER SET search_path = public;

CREATE OR REPLACE FUNCTION public.current_user_role() 
RETURNS TEXT AS $$
  SELECT role FROM public.users WHERE id = auth.uid() LIMIT 1;
$$ LANGUAGE SQL STABLE SECURITY DEFINER SET search_path = public;

CREATE OR REPLACE FUNCTION public.current_user_ref_id() 
RETURNS UUID AS $$
  SELECT reference_id FROM public.users WHERE id = auth.uid() LIMIT 1;
$$ LANGUAGE SQL STABLE SECURITY DEFINER SET search_path = public;

-- Grant execution privileges on helper functions to authenticated role
GRANT EXECUTE ON FUNCTION public.current_org_id() TO authenticated;
GRANT EXECUTE ON FUNCTION public.current_user_role() TO authenticated;
GRANT EXECUTE ON FUNCTION public.current_user_ref_id() TO authenticated;

-- ── 2. ORGANISATION ISOLATION POLICIES ───────────────────────────────────────

-- Admins can read & write all data within their organisation
DROP POLICY IF EXISTS admin_all_organisations ON public.organisations;
CREATE POLICY admin_all_organisations ON public.organisations
  FOR ALL TO authenticated USING (id = public.current_org_id());

DROP POLICY IF EXISTS admin_all_users ON public.users;
CREATE POLICY admin_all_users ON public.users
  FOR ALL TO authenticated USING (organisation_id = public.current_org_id() AND public.current_user_role() = 'Admin');

DROP POLICY IF EXISTS admin_all_admins ON public.admins;
CREATE POLICY admin_all_admins ON public.admins
  FOR ALL TO authenticated USING (organisation_id = public.current_org_id() AND public.current_user_role() = 'Admin');

DROP POLICY IF EXISTS admin_all_teachers ON public.teachers;
CREATE POLICY admin_all_teachers ON public.teachers
  FOR ALL TO authenticated USING (organisation_id = public.current_org_id() AND public.current_user_role() = 'Admin');

DROP POLICY IF EXISTS admin_all_students ON public.students;
CREATE POLICY admin_all_students ON public.students
  FOR ALL TO authenticated USING (organisation_id = public.current_org_id() AND public.current_user_role() = 'Admin');

DROP POLICY IF EXISTS admin_all_fees ON public.fees;
CREATE POLICY admin_all_fees ON public.fees
  FOR ALL TO authenticated USING (organisation_id = public.current_org_id() AND public.current_user_role() = 'Admin');

DROP POLICY IF EXISTS admin_all_fee_payments ON public.fee_payments;
CREATE POLICY admin_all_fee_payments ON public.fee_payments
  FOR ALL TO authenticated USING (organisation_id = public.current_org_id() AND public.current_user_role() = 'Admin');

DROP POLICY IF EXISTS admin_all_fee_installments ON public.fee_installments;
CREATE POLICY admin_all_fee_installments ON public.fee_installments
  FOR ALL TO authenticated USING (organisation_id = public.current_org_id() AND public.current_user_role() = 'Admin');

DROP POLICY IF EXISTS admin_all_student_attendance ON public.student_attendance;
CREATE POLICY admin_all_student_attendance ON public.student_attendance
  FOR ALL TO authenticated USING (organisation_id = public.current_org_id() AND public.current_user_role() = 'Admin');

DROP POLICY IF EXISTS admin_all_teacher_attendance ON public.teacher_attendance;
CREATE POLICY admin_all_teacher_attendance ON public.teacher_attendance
  FOR ALL TO authenticated USING (organisation_id = public.current_org_id() AND public.current_user_role() = 'Admin');

DROP POLICY IF EXISTS admin_all_teacher_payments ON public.teacher_payments;
CREATE POLICY admin_all_teacher_payments ON public.teacher_payments
  FOR ALL TO authenticated USING (organisation_id = public.current_org_id() AND public.current_user_role() = 'Admin');

DROP POLICY IF EXISTS admin_all_tests ON public.tests;
CREATE POLICY admin_all_tests ON public.tests
  FOR ALL TO authenticated USING (organisation_id = public.current_org_id() AND public.current_user_role() = 'Admin');

DROP POLICY IF EXISTS admin_all_test_results ON public.test_results;
CREATE POLICY admin_all_test_results ON public.test_results
  FOR ALL TO authenticated USING (organisation_id = public.current_org_id() AND public.current_user_role() = 'Admin');

DROP POLICY IF EXISTS admin_all_daily_class_records ON public.daily_class_records;
CREATE POLICY admin_all_daily_class_records ON public.daily_class_records
  FOR ALL TO authenticated USING (organisation_id = public.current_org_id() AND public.current_user_role() = 'Admin');

DROP POLICY IF EXISTS admin_all_notices ON public.notices;
CREATE POLICY admin_all_notices ON public.notices
  FOR ALL TO authenticated USING (organisation_id = public.current_org_id() AND public.current_user_role() = 'Admin');

-- ── 3. TEACHER ISOLATION POLICIES ─────────────────────────────────────────────

-- Teachers can view their own teacher profile
DROP POLICY IF EXISTS teacher_read_own_profile ON public.teachers;
CREATE POLICY teacher_read_own_profile ON public.teachers
  FOR SELECT TO authenticated USING (organisation_id = public.current_org_id() AND id = public.current_user_ref_id() AND public.current_user_role() = 'Teacher');

-- Teachers can view & insert their own attendance
DROP POLICY IF EXISTS teacher_own_attendance ON public.teacher_attendance;
CREATE POLICY teacher_own_attendance ON public.teacher_attendance
  FOR ALL TO authenticated USING (organisation_id = public.current_org_id() AND teacher_id = public.current_user_ref_id() AND public.current_user_role() = 'Teacher');

-- Teachers can view their own salary payments
DROP POLICY IF EXISTS teacher_read_own_payments ON public.teacher_payments;
CREATE POLICY teacher_read_own_payments ON public.teacher_payments
  FOR SELECT TO authenticated USING (organisation_id = public.current_org_id() AND teacher_id = public.current_user_ref_id() AND public.current_user_role() = 'Teacher');

-- Teachers can view students in their organisation
DROP POLICY IF EXISTS teacher_read_students ON public.students;
CREATE POLICY teacher_read_students ON public.students
  FOR SELECT TO authenticated USING (organisation_id = public.current_org_id() AND public.current_user_role() = 'Teacher');

-- Teachers can record & view student attendance
DROP POLICY IF EXISTS teacher_student_attendance ON public.student_attendance;
CREATE POLICY teacher_student_attendance ON public.student_attendance
  FOR ALL TO authenticated USING (organisation_id = public.current_org_id() AND public.current_user_role() = 'Teacher');

-- Teachers can record daily class records for their classes
DROP POLICY IF EXISTS teacher_daily_class_records ON public.daily_class_records;
CREATE POLICY teacher_daily_class_records ON public.daily_class_records
  FOR ALL TO authenticated USING (organisation_id = public.current_org_id() AND teacher_id = public.current_user_ref_id() AND public.current_user_role() = 'Teacher');

-- Teachers can view published notices
DROP POLICY IF EXISTS teacher_read_notices ON public.notices;
CREATE POLICY teacher_read_notices ON public.notices
  FOR SELECT TO authenticated USING (organisation_id = public.current_org_id() AND is_published = TRUE AND (target_role = 'All' OR target_role = 'Teacher') AND public.current_user_role() = 'Teacher');

-- ── 4. STUDENT ISOLATION POLICIES ─────────────────────────────────────────────

-- Students can read ONLY their own student profile
DROP POLICY IF EXISTS student_read_own_profile ON public.students;
CREATE POLICY student_read_own_profile ON public.students
  FOR SELECT TO authenticated USING (organisation_id = public.current_org_id() AND id = public.current_user_ref_id() AND public.current_user_role() = 'Student');

-- Students can read ONLY their own attendance
DROP POLICY IF EXISTS student_read_own_attendance ON public.student_attendance;
CREATE POLICY student_read_own_attendance ON public.student_attendance
  FOR SELECT TO authenticated USING (organisation_id = public.current_org_id() AND student_id = public.current_user_ref_id() AND public.current_user_role() = 'Student');

-- Students can read ONLY their own test results
DROP POLICY IF EXISTS student_read_own_results ON public.test_results;
CREATE POLICY student_read_own_results ON public.test_results
  FOR SELECT TO authenticated USING (organisation_id = public.current_org_id() AND student_id = public.current_user_ref_id() AND public.current_user_role() = 'Student');

-- Students can read ONLY their own fee plans & receipts
DROP POLICY IF EXISTS student_read_own_fees ON public.fees;
CREATE POLICY student_read_own_fees ON public.fees
  FOR SELECT TO authenticated USING (organisation_id = public.current_org_id() AND student_id = public.current_user_ref_id() AND public.current_user_role() = 'Student');

DROP POLICY IF EXISTS student_read_own_fee_installments ON public.fee_installments;
CREATE POLICY student_read_own_fee_installments ON public.fee_installments
  FOR SELECT TO authenticated USING (
    organisation_id = public.current_org_id() AND
    public.current_user_role() = 'Student' AND
    fee_id IN (SELECT id FROM public.fees WHERE student_id = public.current_user_ref_id())
  );

-- Students can view published notices targeted to them
DROP POLICY IF EXISTS student_read_notices ON public.notices;
CREATE POLICY student_read_notices ON public.notices
  FOR SELECT TO authenticated USING (
    organisation_id = public.current_org_id() AND
    is_published = TRUE AND
    (target_role = 'All' OR target_role = 'Student') AND
    public.current_user_role() = 'Student'
  );

-- ── 5. DEVICE REGISTRATION POLICIES ───────────────────────────────────────────

DROP POLICY IF EXISTS user_read_own_devices ON public.devices;
CREATE POLICY user_read_own_devices ON public.devices
  FOR SELECT TO authenticated USING (organisation_id = public.current_org_id() AND user_id = auth.uid());

DROP POLICY IF EXISTS user_insert_own_device ON public.devices;
CREATE POLICY user_insert_own_device ON public.devices
  FOR INSERT TO authenticated WITH CHECK (organisation_id = public.current_org_id() AND user_id = auth.uid());
