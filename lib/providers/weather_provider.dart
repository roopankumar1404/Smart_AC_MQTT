// lib/providers/weather_provider.dart
//
// Fetches real-time weather for Avadi, Tamil Nadu (this AC's fixed
// physical location) using Open-Meteo's free forecast API - no API
// key needed. Refreshes periodically. Location is intentionally
// hardcoded: the AC is a stationary home appliance, not something
// that travels, so there's nothing here that needs to be editable.

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class WeatherProvider extends ChangeNotifier {
  // Avadi, Tamil Nadu, India
  static const double _latitude = 13.1147;
  static const double _longitude = 80.1069;

  double? _temperature;
  double? get temperature => _temperature;

  String? _condition;
  String? get condition => _condition;

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  Timer? _timer;

  WeatherProvider() {
    _fetch();
    _timer = Timer.periodic(const Duration(minutes: 15), (_) => _fetch());
  }

  Future<void> refresh() => _fetch();

  Future<void> _fetch() async {
    // Only show the loading spinner on the very first fetch - after
    // that, keep showing the last good reading while a refresh runs
    // quietly in the background.
    _isLoading = _temperature == null;
    notifyListeners();

    try {
      final uri = Uri.parse(
        'https://api.open-meteo.com/v1/forecast'
        '?latitude=$_latitude&longitude=$_longitude'
        '&current=temperature_2m,weather_code',
      );
      final response =
          await http.get(uri).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final current = data['current'] as Map<String, dynamic>?;
        if (current != null) {
          _temperature = (current['temperature_2m'] as num).toDouble();
          final code = (current['weather_code'] as num).toInt();
          _condition = _describeWeatherCode(code);
        }
      }
    } catch (_) {
      // Network hiccup - keep showing the last known good reading
      // instead of blanking the UI out.
    }

    _isLoading = false;
    notifyListeners();
  }

  String _describeWeatherCode(int code) {
    if (code == 0) return 'Clear Sky';
    if (code == 1) return 'Mainly Clear';
    if (code == 2) return 'Partly Cloudy';
    if (code == 3) return 'Overcast';
    if (code == 45 || code == 48) return 'Foggy';
    if (code >= 51 && code <= 57) return 'Drizzle';
    if (code >= 61 && code <= 67) return 'Rain';
    if (code >= 71 && code <= 77) return 'Snow';
    if (code >= 80 && code <= 82) return 'Rain Showers';
    if (code >= 85 && code <= 86) return 'Snow Showers';
    if (code >= 95) return 'Thunderstorm';
    return 'Cloudy';
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}