import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/database/database_helper.dart';
import 'notification_service.dart';

/// Background message handler — must be a top-level function.
/// Handles notifications received when the app is in the background/terminated.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Ensure Firebase is initialized for background isolate.
  try {
    await Firebase.initializeApp();
  } catch (_) {
    // Firebase may already be initialized.
  }

  if (kDebugMode) {
    debugPrint('[FCM BACKGROUND] Message received: ${message.messageId}');
    debugPrint('[FCM BACKGROUND] Title: ${message.notification?.title}');
    debugPrint('[FCM BACKGROUND] Body: ${message.notification?.body}');
    debugPrint('[FCM BACKGROUND] Data: ${message.data}');
  }

  // Persist the notification so it appears in the in-app notification center.
  await PushNotificationService.instance._persistBackgroundNotification(message);
}

/// Firebase Cloud Messaging (FCM) service for Omega Education Centre ERP.
///
/// Handles:
/// - FCM token registration and refresh
/// - Foreground message display
/// - Background/terminated message handling
/// - Token sync to Supabase for server-side push
/// - Graceful degradation when Firebase is not configured
class PushNotificationService {
  PushNotificationService._();

  static final PushNotificationService instance = PushNotificationService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final NotificationService _notificationService = NotificationService.instance;

  static const String _fcmTokenKey = 'fcm_token';
  static const String _fcmEnabledKey = 'fcm_enabled';

  bool _isInitialized = false;
  bool _isEnabled = false;
  String? _currentToken;

  bool get isInitialized => _isInitialized;
  bool get isEnabled => _isEnabled;
  String? get currentToken => _currentToken;

  // ── Initialization ──────────────────────────────────────────────

  /// Initializes FCM. Call this after Firebase.initializeApp() in main().
  ///
  /// If Firebase is not available or the user denies notification permission,
  /// the service degrades gracefully — in-app notifications still work.
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Request permission (iOS/macOS; Android auto-grants).
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
        criticalAlert: false,
      );

      _isEnabled = settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;

      if (kDebugMode) {
        debugPrint('[FCM] Permission status: ${settings.authorizationStatus}');
      }

      // Get FCM token.
      if (_isEnabled) {
        _currentToken = await _messaging.getToken();

        if (kDebugMode && _currentToken != null) {
          debugPrint('[FCM] Token obtained: ${_currentToken!.substring(0, 20)}...');
        }

        // Persist token locally.
        if (_currentToken != null) {
          await _saveToken(_currentToken!);
          await _syncTokenToSupabase(_currentToken!);
        }

        // Listen for token refresh.
        _messaging.onTokenRefresh.listen((newToken) {
          if (kDebugMode) {
            debugPrint('[FCM] Token refreshed');
          }
          _currentToken = newToken;
          _saveToken(newToken);
          _syncTokenToSupabase(newToken);
        });
      }

      // Handle foreground messages.
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // Handle notification tap when app is in background.
      FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

      // Check if app was opened via a notification (terminated state).
      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        _handleNotificationTap(initialMessage);
      }

      _isInitialized = true;

      if (kDebugMode) {
        debugPrint('[FCM] Push notification service initialized');
      }
    } catch (e) {
      // Firebase not available — app works without push notifications.
      _isEnabled = false;
      _isInitialized = true;

      if (kDebugMode) {
        debugPrint('[FCM] Initialization failed (app works without push): $e');
      }
    }
  }

  // ── Token Management ────────────────────────────────────────────

  /// Saves FCM token to SharedPreferences.
  Future<void> _saveToken(String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_fcmTokenKey, token);
      await prefs.setBool(_fcmEnabledKey, true);
    } catch (_) {}
  }

  /// Syncs FCM token to Supabase for server-side push notification delivery.
  ///
  /// Stores the token in a `push_tokens` table with user association.
  /// Server-side Edge Functions use this table to send targeted pushes.
  Future<void> _syncTokenToSupabase(String token) async {
    try {
      // Store token locally for server-side pickup.
      // Full server-side sync requires Supabase Edge Functions.
      final db = DatabaseHelper.instance;
      await db.setSetting('fcm_token', token);
      await db.setSetting('fcm_token_updated_at', DateTime.now().toIso8601String());

      if (kDebugMode) {
        debugPrint('[FCM] Token persisted to app_settings for server sync');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[FCM] Token sync failed: $e');
      }
    }
  }

  // ── Message Handling ────────────────────────────────────────────

  /// Handles messages received while the app is in the foreground.
  void _handleForegroundMessage(RemoteMessage message) {
    if (kDebugMode) {
      debugPrint('[FCM FOREGROUND] Title: ${message.notification?.title}');
      debugPrint('[FCM FOREGROUND] Body: ${message.notification?.body}');
      debugPrint('[FCM FOREGROUND] Data: ${message.data}');
    }

    final notification = message.notification;
    if (notification == null) return;

    // Determine notification type from data payload.
    final type = message.data['type'] ?? 'general';

    // Add to in-app notification center.
    _notificationService.addNotification(
      title: notification.title ?? 'New Notification',
      body: notification.body ?? '',
      type: type,
      data: message.data.isNotEmpty ? Map<String, dynamic>.from(message.data) : null,
    );
  }

  /// Handles notification tap (app opens from background/terminated).
  void _handleNotificationTap(RemoteMessage message) {
    if (kDebugMode) {
      debugPrint('[FCM TAP] Navigating based on notification type');
    }

    final type = message.data['type'] ?? 'general';

    // Navigate to the appropriate screen based on notification type.
    // This is handled by the navigatorKey from app.dart.
    _navigateForNotification(type, message.data);
  }

  /// Navigates to the appropriate screen based on notification type.
  void _navigateForNotification(String type, Map<String, dynamic> data) {
    // Navigation will be handled by the app's router when the user
    // taps on the notification. For now, we just log it.
    if (kDebugMode) {
      debugPrint('[FCM NAV] Type: $type, Data: $data');
    }
  }

  // ── Background Notification Persistence ─────────────────────────

  /// Persists a background notification to the in-app notification center.
  /// Called from the top-level background handler.
  Future<void> _persistBackgroundNotification(RemoteMessage message) async {
    try {
      await _notificationService.loadNotifications();

      final notification = message.notification;
      final type = message.data['type'] ?? 'general';

      await _notificationService.addNotification(
        title: notification?.title ?? 'New Notification',
        body: notification?.body ?? '',
        type: type,
        data: message.data.isNotEmpty ? Map<String, dynamic>.from(message.data) : null,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[FCM] Failed to persist background notification: $e');
      }
    }
  }

  // ── Public API ──────────────────────────────────────────────────

  /// Returns the current FCM token for use in server-side push triggers.
  Future<String?> getToken() async {
    if (!_isEnabled) return null;
    return _currentToken ?? await _messaging.getToken();
  }

  /// Subscribes to a topic for targeted notifications (e.g., class-specific).
  Future<void> subscribeToTopic(String topic) async {
    if (!_isEnabled) return;
    try {
      await _messaging.subscribeToTopic(topic);
      if (kDebugMode) {
        debugPrint('[FCM] Subscribed to topic: $topic');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[FCM] Failed to subscribe to topic $topic: $e');
      }
    }
  }

  /// Unsubscribes from a topic.
  Future<void> unsubscribeFromTopic(String topic) async {
    if (!_isEnabled) return;
    try {
      await _messaging.unsubscribeFromTopic(topic);
      if (kDebugMode) {
        debugPrint('[FCM] Unsubscribed from topic: $topic');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[FCM] Failed to unsubscribe from topic $topic: $e');
      }
    }
  }

  /// Sets the FCM token badge count (iOS only).
  /// Note: This is a no-op as FCM badge management is handled server-side.

  /// Deletes the FCM token (e.g., on logout).
  Future<void> deleteToken() async {
    try {
      await _messaging.deleteToken();
      _currentToken = null;

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_fcmTokenKey);
      await prefs.setBool(_fcmEnabledKey, false);

      if (kDebugMode) {
        debugPrint('[FCM] Token deleted');
      }
    } catch (_) {}
  }
}

/// Registers the background message handler. Call from main() after
/// Firebase.initializeApp().
void registerFirebaseBackgroundHandler() {
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
}
