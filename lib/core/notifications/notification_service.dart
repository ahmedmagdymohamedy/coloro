import 'dart:math';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'notification_content.dart';

/// Local reminders + Firebase Cloud Messaging.
///
/// Two reminders are kept alive at all times, both anchored to the last time
/// the player opened the app:
///
///   * `+24h` — the daily nudge
///   * `+7d`  — the win-back, only ever seen by someone who drifted away
///
/// Every open cancels and re-arms both, so an active player never receives
/// either one. That is the whole point: the reminders exist to catch someone
/// who stopped, not to pester someone who is still playing.
///
/// Nothing here ever throws. A player with notifications denied, an
/// unconfigured platform or no Play Services still gets a working game.
class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  static const _channelId = 'coloro_reminders';
  static const _channelName = 'Game reminders';
  static const _channelDescription =
      'Occasional reminders to come back and finish a picture.';

  // Fixed IDs so re-arming is a cancel + schedule on the same slot rather
  // than an ever-growing pile of pending notifications.
  static const _idDaily = 1;
  static const _idWeekly = 2;

  static const _dailyDelay = Duration(hours: 24);
  static const _weeklyDelay = Duration(days: 7);

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  final Random _rnd = Random();

  bool _ready = false;

  /// Scheduling and permissions only exist on the two mobile platforms.
  bool get supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  /// Safe to call before Firebase is ready and on any platform.
  Future<void> init() async {
    if (_ready || !supported) return;
    try {
      tzdata.initializeTimeZones();

      // Every Darwin request* flag defaults to true, which would pop the iOS
      // permission dialog here — at first launch, with no context. They are
      // all forced off so the only prompt comes from the level 3 soft-ask.
      const settings = InitializationSettings(
        android: AndroidInitializationSettings('ic_stat_notify'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      );
      await _plugin.initialize(settings: settings);

      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(
            const AndroidNotificationChannel(
              _channelId,
              _channelName,
              description: _channelDescription,
              importance: Importance.high,
            ),
          );

      _ready = true;
    } catch (e) {
      debugPrint('Notifications unavailable ($e) — reminders disabled.');
    }
  }

  /// Whether the OS will actually display anything we post.
  Future<bool> hasPermission() async {
    if (!supported) return false;
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        final android = _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
        return await android?.areNotificationsEnabled() ?? false;
      }
      final settings =
          await FirebaseMessaging.instance.getNotificationSettings();
      return _granted(settings.authorizationStatus);
    } catch (_) {
      return false;
    }
  }

  /// Shows the real OS prompt. Call this only after the player has agreed to
  /// the in-game explainer — an OS dialog fired cold is the fastest way to a
  /// permanent denial.
  ///
  /// Returns whether notifications ended up enabled.
  Future<bool> requestPermission() async {
    if (!supported) return false;
    try {
      var granted = false;
      if (defaultTargetPlatform == TargetPlatform.android) {
        final android = _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
        granted = await android?.requestNotificationsPermission() ?? false;
      } else {
        // On iOS this single call both asks the user and registers with APNs,
        // so console pushes can reach the device. Asking through the local
        // notifications plugin instead would leave FCM unregistered.
        final settings = await FirebaseMessaging.instance.requestPermission();
        granted = _granted(settings.authorizationStatus);
      }
      // Start the 24h clock from the moment of the grant, not the next open.
      if (granted) await rescheduleReminders();
      return granted;
    } catch (e) {
      debugPrint('Notification permission request failed: $e');
      return false;
    }
  }

  /// Cancels both reminders and re-arms them relative to now. Called on every
  /// launch and every resume, so the timers always measure "time since the
  /// player last looked at the game".
  Future<void> rescheduleReminders() async {
    if (!_ready || !supported) return;
    // Scheduling before the grant would silently drop both notifications, and
    // they would never be re-armed until the next open.
    if (!await hasPermission()) return;
    try {
      await _plugin.cancel(id: _idDaily);
      await _plugin.cancel(id: _idWeekly);

      final copy = NotificationContent.pickPair(_rnd);
      await _schedule(_idDaily, _dailyDelay, copy.daily);
      await _schedule(_idWeekly, _weeklyDelay, copy.weekly);
    } catch (e) {
      debugPrint('Could not schedule reminders: $e');
    }
  }

  Future<void> _schedule(int id, Duration delay, ReminderCopy copy) {
    return _plugin.zonedSchedule(
      id: id,
      title: copy.title,
      body: copy.body,
      scheduledDate: tz.TZDateTime.now(tz.local).add(delay),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      // Inexact deliberately: a reminder does not need to land on the exact
      // second, and exact alarms would cost us the SCHEDULE_EXACT_ALARM
      // permission plus Play Console justification.
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  /// Registers with FCM so "send to all users" from the Firebase console
  /// reaches this device. Console campaigns target the app directly, so no
  /// topic subscription is needed.
  Future<void> syncPushRegistration() async {
    if (!supported) return;
    try {
      final token = await FirebaseMessaging.instance.getToken();
      debugPrint('FCM registered: ${token == null ? 'no token' : 'ok'}');
    } catch (e) {
      debugPrint('FCM registration failed: $e');
    }
  }

  static bool _granted(AuthorizationStatus status) =>
      status == AuthorizationStatus.authorized ||
      status == AuthorizationStatus.provisional;
}
