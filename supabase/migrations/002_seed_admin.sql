-- ============================================================
-- Seed Admin User for Omega Education Centre
-- ============================================================
-- Run AFTER disabling email confirmation in Auth → Providers → Email
-- Run in: Supabase Dashboard → SQL Editor
-- ============================================================

-- Method 1: Create via Supabase Auth RPC (recommended)
-- This creates the auth user that the app authenticates against
SELECT signup(
  'admin@omega.internal',
  'admin123',
  '{"role": "admin", "display_name": "Administrator"}'::jsonb
);

-- Method 2: Create via Supabase Auth Admin API (if Method 1 doesn't work)
-- Uncomment below and run from SQL Editor:
-- INSERT INTO auth.users (
--   instance_id,
--   id,
--   aud,
--   role,
--   email,
--   encrypted_password,
--   email_confirmed_at,
--   created_at,
--   updated_at,
--   confirmation_token,
--   recovery_token
-- ) VALUES (
--   '00000000-0000-0000-0000-000000000000',
--   gen_random_uuid(),
--   'authenticated',
--   'authenticated',
--   'admin@omega.internal',
--   crypt('admin123', gen_salt('bf')),
--   now(),
--   now(),
--   now(),
--   '',
--   ''
-- );

-- Also create the admin_accounts record (for app profile data)
INSERT INTO admin_accounts (username, displayName, passwordHash)
VALUES ('admin', 'Administrator', 'admin123')
ON CONFLICT (username) DO NOTHING;

-- Verify it worked
SELECT id, username, displayName, isActive FROM admin_accounts WHERE username = 'admin';
