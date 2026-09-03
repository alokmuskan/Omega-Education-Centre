-- ==============================================================================
-- OMEGA EDUCATION CENTRE ERP — CENTRAL REPAIR & RLS MIGRATION (PHASE 32)
-- Target Platform: Supabase PostgreSQL
-- ==============================================================================

-- 1. Ensure central organisation exists
INSERT INTO public.organisations (id, org_code, name, created_at, updated_at)
VALUES (
  '00000000-0000-0000-0000-000000000001'::uuid,
  'ORG_OMEGA_DEFAULT',
  'Omega Education Centre',
  now(),
  now()
)
ON CONFLICT (org_code) DO UPDATE
SET name = EXCLUDED.name, updated_at = now();

-- 2. Helper Functions using auth.uid() and SECURITY DEFINER
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

GRANT EXECUTE ON FUNCTION public.current_org_id() TO authenticated;
GRANT EXECUTE ON FUNCTION public.current_user_role() TO authenticated;
GRANT EXECUTE ON FUNCTION public.current_user_ref_id() TO authenticated;

-- 3. Enable RLS
ALTER TABLE public.organisations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.students ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.teachers ENABLE ROW LEVEL SECURITY;

-- 4. RLS Policies
DROP POLICY IF EXISTS admin_all_organisations ON public.organisations;
CREATE POLICY admin_all_organisations ON public.organisations
  FOR ALL TO authenticated USING (id = public.current_org_id());

DROP POLICY IF EXISTS admin_all_users ON public.users;
CREATE POLICY admin_all_users ON public.users
  FOR ALL TO authenticated USING (organisation_id = public.current_org_id() AND public.current_user_role() = 'Admin');

DROP POLICY IF EXISTS admin_all_students ON public.students;
CREATE POLICY admin_all_students ON public.students
  FOR ALL TO authenticated USING (organisation_id = public.current_org_id() AND public.current_user_role() = 'Admin');

DROP POLICY IF EXISTS admin_all_teachers ON public.teachers;
CREATE POLICY admin_all_teachers ON public.teachers
  FOR ALL TO authenticated USING (organisation_id = public.current_org_id() AND public.current_user_role() = 'Admin');
