-- ============================================================
-- Seed Admin User for Omega Education Centre
-- ============================================================
-- Run AFTER:
--   1. Running 000_clean_reset.sql
--   2. Disabling email confirmation in Auth → Providers → Email
-- Run in: Supabase Dashboard → SQL Editor
-- ============================================================

-- Create Supabase Auth user with real email
SELECT signup(
  'alokraj1319@gmail.com',
  'Alok@2006',
  '{"role": "admin", "display_name": "Alok"}'::jsonb
);

-- Create the admin_accounts profile record
INSERT INTO admin_accounts (username, displayName, passwordHash)
VALUES ('Alok', 'Alok', 'Alok@2006')
ON CONFLICT (username) DO NOTHING;

-- Also create a backup 'admin' user (for backward compatibility)
SELECT signup(
  'admin@omega.internal',
  'admin123',
  '{"role": "admin", "display_name": "Administrator"}'::jsonb
);

INSERT INTO admin_accounts (username, displayName, passwordHash)
VALUES ('admin', 'Administrator', 'admin123')
ON CONFLICT (username) DO NOTHING;

-- Verify it worked
SELECT id, username, displayName, isActive FROM admin_accounts;
