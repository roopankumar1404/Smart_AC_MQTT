import 'services/background_service.dart';
// lib/main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'core/app.dart';
import 'services/auth_service.dart';
import 'services/mqtt_service.dart';
import 'services/firestore_service.dart';
import 'services/notification_service.dart';
import 'providers/device_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/navigation_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/weather_provider.dart';
import 'providers/connectivity_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await NotificationService().init();
  try {
    await initializeBackgroundService();
  } catch (e) {
    debugPrint('[BackgroundService] init error: $e');
  }

  final mqttService = MqttService();
  await mqttService.connect();
  final firestoreService = FirestoreService();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: mqttService),
        Provider.value(value: firestoreService),
        Provider(create: (_) => AuthService()),
        ChangeNotifierProxyProvider<MqttService, DeviceProvider>(
          create: (ctx) => DeviceProvider(mqttService, firestoreService),
          update: (ctx, mqtt, prev) => prev ?? DeviceProvider(mqtt, firestoreService),
        ),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => NavigationProvider()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider(create: (_) => WeatherProvider()),
        ChangeNotifierProvider(create: (_) => ConnectivityProvider()),
      ],
      child: const SmartAcApp(),
    ),
  );
}
