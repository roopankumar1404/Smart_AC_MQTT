// lib/services/fcm_push_service.dart

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:googleapis_auth/auth_io.dart';

class FcmPushService {
  static final FcmPushService _instance = FcmPushService._internal();
  factory FcmPushService() => _instance;
  FcmPushService._internal();

  static const _serviceAccountJson = {
    "type": "service_account",
    "project_id": "smart-ac-iot",
    "private_key_id": "***",
    "private_key": r"-----BEGIN PRIVATE KEY-----\n***\n-----END PRIVATE KEY-----\n",
    "client_email": "***@smart-ac-iot.iam.gserviceaccount.com",
    "client_id": "***",
    "auth_uri": "https://accounts.google.com/o/oauth2/auth",
    "token_uri": "https://oauth2.googleapis.com/token",
    "auth_provider_x509_cert_url": "https://www.googleapis.com/oauth2/v1/certs",
    "client_x509_cert_url": "https://www.googleapis.com/robot/v1/metadata/x509/firebase-adminsdk-fbsvc%40smart-ac-iot.iam.gserviceaccount.com",
    "universe_domain": "googleapis.com"
  };

  /// Shared helper to send an FCM v1 push notification
  Future<void> _sendPush({
    required String title,
    required String body,
    required String channelId,
  }) async {
    try {
      final accountCredentials =
          ServiceAccountCredentials.fromJson(_serviceAccountJson);
      const scopes = ['https://www.googleapis.com/auth/firebase.messaging'];

      final client = await clientViaServiceAccount(accountCredentials, scopes);

      final url = Uri.parse(
          'https://fcm.googleapis.com/v1/projects/smart-ac-iot/messages:send');

      final payload = jsonEncode({
        'message': {
          'topic': 'ac_alerts',
          'notification': {
            'title': title,
            'body': body,
          },
          'android': {
            'priority': 'HIGH',
            'notification': {
              'channel_id': channelId,
              'sound': 'default',
            },
          },
        },
      });

      final response = await client.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: payload,
      );

      debugPrint('🚀 FCM Push [$title]: ${response.statusCode}');
      client.close();
    } catch (e) {
      debugPrint('❌ FCM Push Error [$title]: $e');
    }
  }

  /// Triggers push notification when AC is turned ON
  Future<void> sendAcOnNotification() => _sendPush(
        title: 'AC Power Alert ❄️',
        body: 'Smart AC has been turned ON',
        channelId: 'ac_status_channel',
      );

  /// Triggers push notification for filter clean reminder
  Future<void> sendFilterCleanReminder() => _sendPush(
        title: 'Filter Clean Reminder 🧹',
        body:
            'Your AC filter cleaning is overdue! Please clean the filter and reset in the app.',
        channelId: 'filter_reminder_channel',
      );
}

