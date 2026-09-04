-- ============================================================
-- EMERGENCY RECOVERY PROCEDURES
-- ============================================================
-- Run these ONLY when locked out of the admin panel.
-- These bypass normal authentication.
-- ============================================================

-- ─── RECOVERY 1: Find your admin user ID ───────────────────
-- Run this FIRST to get your actual user ID

SELECT id, email, email_confirmed_at, created_at, last_sign_in_at
FROM auth.users
WHERE email = 'alokraj1319@gmail.com';

-- Copy the UUID value from the 'id' column above
-- Then use it in RECOVERY 2 below

-- ─── RECOVERY 2: Reset admin password ──────────────────────
-- Replace 'YOUR_ACTUAL_UUID_HERE' with the UUID from RECOVERY 1

-- Example: If the UUID from above is 'a1b2c3d4-e5f6-7890-abcd-ef1234567890'
-- Then run:
--
-- UPDATE auth.users
-- SET encrypted_password = crypt('NewPassword123!', gen_salt('bf')),
--     updated_at = now()
-- WHERE id = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890';

-- ─── RECOVERY 3: Create emergency admin (if all else fails) ─

CREATE EXTENSION IF NOT EXISTS pgcrypto;

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
  'emergency@omega.recovery',
  crypt('TempRecovery@2026!', gen_salt('bf')),
  now(),
  now(),
  now(),
  '',
  '',
  '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"role": "admin", "display_name": "Emergency Admin"}'::jsonb
);

INSERT INTO admin_accounts (username, displayName, passwordHash)
VALUES ('emergency@omega.recovery', 'Emergency Admin', 'TempRecovery@2026!')
ON CONFLICT (username) DO NOTHING;

-- Login with: emergency@omega.recovery / TempRecovery@2026!
-- After recovering, DELETE this emergency user:
-- DELETE FROM auth.users WHERE email = 'emergency@omega.recovery';
-- DELETE FROM admin_accounts WHERE username = 'emergency@omega.recovery';

-- ─── RECOVERY 4: Check all admin accounts ──────────────────

SELECT
  aa.id,
  aa.username,
  aa.displayName,
  aa.isActive,
  aa.createdAt
FROM admin_accounts aa
ORDER BY aa.createdAt DESC;

-- ─── RECOVERY 5: Check all Supabase Auth users ─────────────

SELECT
  id,
  email,
  email_confirmed_at,
  created_at,
  last_sign_in_at
FROM auth.users
ORDER BY created_at DESC;
