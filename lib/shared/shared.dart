/// Shared module barrel export.
///
/// Central entry point for all shared infrastructure: config, constants,
/// services, themes, utilities, and reusable widgets.
library;

// ── Config ──────────────────────────────────────────────────────────────────
export 'config/backend_config.dart';

// ── Constants ───────────────────────────────────────────────────────────────
export 'constants/app_constants.dart';

// ── Services ────────────────────────────────────────────────────────────────
export 'services/supabase_auth_service.dart';
export 'services/supabase_health_service.dart';
export 'services/sync_engine.dart';
export 'services/sync_queue_repository.dart';

// ── Themes ──────────────────────────────────────────────────────────────────
export 'themes/app_theme.dart';

// ── Utilities ───────────────────────────────────────────────────────────────
export 'utils/app_session.dart';
export 'utils/attendance_date_validator.dart';
export 'utils/password_util.dart';
export 'utils/profile_photo_helper.dart';

// ── Widgets ─────────────────────────────────────────────────────────────────
export 'widgets/academic_activity_card.dart';
export 'widgets/change_password_dialog.dart';
export 'widgets/profile_photo_widget.dart';
export 'widgets/sync_status_widget.dart';
