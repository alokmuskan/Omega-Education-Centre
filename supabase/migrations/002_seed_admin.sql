-- ============================================================
-- Seed Admin User for Omega Education Centre
-- ============================================================
-- Run AFTER:
--   1. Running 000_clean_reset.sql
--   2. Disabling email confirmation in Auth → Providers → Email
--
-- OPTION A: Run this SQL in Supabase Dashboard → SQL Editor
-- OPTION B: Create user manually via UI (see instructions below)
-- ============================================================

-- ─── OPTION A: SQL Method ──────────────────────────────────

-- Enable pgcrypto if not already enabled (needed for crypt())
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- Create Supabase Auth user
INSERT INTO auth.users (
  instance_id,
  id,
  aud,
  role,
  email,
  encrypted_password,
  email_confirmed_at,
  created_at,
  updated_at,
  confirmation_token,
  recovery_token,
  raw_app_meta_data,
  raw_user_meta_data
) VALUES (
  '00000000-0000-0000-0000-000000000000',
  gen_random_uuid(),
  'authenticated',
  'authenticated',
  'alokraj1319@gmail.com',
  crypt('Alok@2006', gen_salt('bf')),
  now(),
  now(),
  now(),
  '',
  '',
  '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"role": "admin", "display_name": "Alok"}'::jsonb
);

-- Create admin_accounts profile
INSERT INTO admin_accounts (username, displayName, passwordHash)
VALUES ('alokraj1319@gmail.com', 'Alok', 'Alok@2006')
ON CONFLICT (username) DO NOTHING;

-- Verify
SELECT id, email, email_confirmed_at FROM auth.users WHERE email = 'alokraj1319@gmail.com';
SELECT id, username, displayName, isActive FROM admin_accounts;


-- ============================================================
-- OPTION B: Manual UI Method (if SQL above fails)
-- ============================================================
-- If the SQL gives errors, do this instead:
--
-- 1. Left sidebar → Click "Authentication"
-- 2. Click "Users" tab
-- 3. Click "Add user" button (top right)
-- 4. Select "Create new user"
-- 5. Fill in:
--    - Email: alokraj1319@gmail.com
--    - Password: Alok@2006
--    - Auto Confirm Email: ✅ CHECK THIS BOX
-- 6. Click "Create user"
-- 7. Then run this SQL for the profile:
--
--    INSERT INTO admin_accounts (username, displayName, passwordHash)
--    VALUES ('alokraj1319@gmail.com', 'Alok', 'Alok@2006')
--    ON CONFLICT (username) DO NOTHING;
-- ============================================================
