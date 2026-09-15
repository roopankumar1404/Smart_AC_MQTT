// lib/services/background_service.dart
//
// Background service that keeps monitoring AC state via Firestore snapshots
// even when the Flutter app is closed or cleared from Recent Apps.

import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../firebase_options.dart';
import '../core/constants.dart';
import 'notification_service.dart';
import 'fcm_push_service.dart';

/// Initializes and starts the persistent Foreground Service
Future<void> initializeBackgroundService() async {
  final service = FlutterBackgroundService();

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStartBackgroundService,
      autoStart: true,
      isForegroundMode: true,
      notificationChannelId: NotificationService.channelAcId,
      initialNotificationTitle: 'Smart AC Monitor',
      initialNotificationContent: 'Monitoring AC status in background',
      foregroundServiceNotificationId: 888,
    ),
    iosConfiguration: IosConfiguration(
      autoStart: true,
      onForeground: onStartBackgroundService,
      onBackground: onIosBackground,
    ),
  );
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  return true;
}

@pragma('vm:entry-point')
void onStartBackgroundService(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (_) {}

  await NotificationService().init();

  const keyLastAcOn = 'bg_last_ac_on';

  // Listen to Firestore device doc directly in background
  FirebaseFirestore.instance
      .collection(AppConstants.collectionDevices)
      .doc(AppConstants.deviceId)
      .snapshots()
      .listen((snap) async {
    if (snap.exists && snap.data() != null) {
      final data = snap.data()!;
      final bool isAcOn = data['acOn'] == true;
      final prefs = await SharedPreferences.getInstance();
      final storedAcOn = prefs.getBool(keyLastAcOn);

      // Trigger notification when AC turns ON (e.g. via physical remote)
      if (storedAcOn != null && !storedAcOn && isAcOn) {
        await NotificationService().showAcOnNotification();
        try {
          await FcmPushService().sendAcOnNotification();
        } catch (_) {}
      }
      await prefs.setBool(keyLastAcOn, isAcOn);
    }
  });

  if (service is AndroidServiceInstance) {
    service.on('setAsForeground').listen((event) {
      service.setAsForegroundService();
    });

    service.on('setAsBackground').listen((event) {
      service.setAsBackgroundService();
    });
  }

  service.on('stopService').listen((event) {
    service.stopSelf();
  });
}
