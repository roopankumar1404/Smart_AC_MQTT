import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import '../firebase_options.dart';
import '../core/constants.dart';

/// Top-level background handler for FCM push notifications when app is killed or in background.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (_) {}

  final notification = message.notification;
  if (notification != null) {
    final service = NotificationService();
    await service.init();
    await service.showCustomNotification(
      title: notification.title ?? 'Smart AC Alert ❄️',
      body: notification.body ?? 'Status update received',
    );
  } else if (message.data.isNotEmpty) {
    final title = message.data['title'] ?? 'Smart AC Alert ❄️';
    final body = message.data['body'] ?? 'AC status change received';
    final service = NotificationService();
    await service.init();
    await service.showCustomNotification(
      title: title,
      body: body,
    );
  }
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  bool _initialized = false;
  bool get isInitialized => _initialized;

  static const int acOnNotificationId = 1001;
  static const int filterReminderNotificationId = 2001;

  static const String channelAcId = 'ac_status_channel';
  static const String channelAcName = 'AC Status Updates';
  static const String channelAcDesc =
      'Notifications for AC power state changes';

  static const String channelFilterId = 'filter_reminder_channel';
  static const String channelFilterName = 'Filter Clean Reminders';
  static const String channelFilterDesc =
      'Periodic reminders to clean the AC filter';

  Future<void> init() async {
    if (kIsWeb || _initialized) return;

    // Initialize Timezone database for background scheduled alarms
    tz.initializeTimeZones();

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      settings,
      onDidReceiveNotificationResponse: (response) {
        // Notification tapped action
      },
    );

    // Create high-priority notification channels explicitly for Android
    try {
      final androidPlugin = _notifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        const channelAc = AndroidNotificationChannel(
          channelAcId,
          channelAcName,
          description: channelAcDesc,
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
        );
        const channelFilter = AndroidNotificationChannel(
          channelFilterId,
          channelFilterName,
          description: channelFilterDesc,
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
        );
        await androidPlugin.createNotificationChannel(channelAc);
        await androidPlugin.createNotificationChannel(channelFilter);
      }
    } catch (_) {}

    await requestPermissions();

    // Firebase Messaging (Push Notifications) configuration
    try {
      await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      // Subscribe device to AC alerts push topic
      await _messaging.subscribeToTopic('ac_alerts');

      try {
        final token = await _messaging.getToken();
        debugPrint('🔑 FCM REGISTRATION TOKEN: $token');
        if (token != null) {
          await FirebaseFirestore.instance
              .collection(AppConstants.collectionDevices)
              .doc(AppConstants.deviceId)
              .set({'fcmToken': token}, SetOptions(merge: true));
        }
      } catch (e) {
        debugPrint('FCM Token Error: $e');
      }

      // Foreground message listener
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        if (message.notification != null) {
          showCustomNotification(
            title: message.notification!.title ?? 'Smart AC Alert ❄️',
            body: message.notification!.body ?? 'AC Status update',
          );
        }
      });
    } catch (_) {}

    _initialized = true;
  }

  Future<bool> requestPermissions() async {
    if (kIsWeb) return true;
    try {
      final androidPlugin = _notifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        await androidPlugin.requestNotificationsPermission();
        await androidPlugin.requestExactAlarmsPermission();
      }

      final iosPlugin = _notifications
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>();
      if (iosPlugin != null) {
        await iosPlugin.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
      }
    } catch (_) {}
    return true;
  }

  /// Show custom notification banner
  Future<void> showCustomNotification({
    required String title,
    required String body,
  }) async {
    if (kIsWeb) return;
    const androidDetails = AndroidNotificationDetails(
      channelAcId,
      channelAcName,
      channelDescription: channelAcDesc,
      importance: Importance.max,
      priority: Priority.max,
      visibility: NotificationVisibility.public,
      category: AndroidNotificationCategory.alarm,
      fullScreenIntent: true,
      playSound: true,
      enableVibration: true,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentSound: true,
      presentBadge: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      acOnNotificationId,
      title,
      body,
      details,
    );
  }

  /// Show immediate notification when AC is turned on
  Future<void> showAcOnNotification() async {
    if (kIsWeb) return;
    await showCustomNotification(
      title: 'AC Power Alert ❄️',
      body: 'AC has been turned on',
    );
  }

  /// Schedule background-resilient periodic notification for filter clean reminder (every 3 hours)
  Future<void> startFilterCleanReminder({int intervalHours = 3}) async {
    if (kIsWeb) return;
    const androidDetails = AndroidNotificationDetails(
      channelFilterId,
      channelFilterName,
      channelDescription: channelFilterDesc,
      importance: Importance.max,
      priority: Priority.max,
      visibility: NotificationVisibility.public,
      category: AndroidNotificationCategory.reminder,
      fullScreenIntent: true,
      playSound: true,
      enableVibration: true,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentSound: true,
      presentBadge: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    // Trigger immediate alert first
    await _notifications.show(
      filterReminderNotificationId,
      'Filter Clean Reminder 🧹',
      'Filter clean reminder: Limit reached! Please clean filter and reset in app.',
      details,
    );

    // Schedule periodic reminder every 3 hours that runs at the OS level even when app is closed
    try {
      await _notifications.periodicallyShowWithDuration(
        filterReminderNotificationId,
        'Filter Clean Reminder 🧹',
        'Filter clean reminder: Please clean the filter and reset in app.',
        Duration(hours: intervalHours),
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    } catch (_) {
      await _notifications.periodicallyShow(
        filterReminderNotificationId,
        'Filter Clean Reminder 🧹',
        'Filter clean reminder: Please clean the filter and reset in app.',
        RepeatInterval.hourly,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    }
  }

  /// Cancel the repeating filter clean notification after reset
  Future<void> cancelFilterReminder() async {
    if (kIsWeb) return;
    await _notifications.cancel(filterReminderNotificationId);
  }

  /// Cancel all notifications
  Future<void> cancelAll() async {
    if (kIsWeb) return;
    await _notifications.cancelAll();
  }
}
