// lib/providers/settings_provider.dart
//
// Local, on-device app preferences (NOT synced via Firestore).
// Currently: Room Name, Notifications, and the Filter reminder
// interval (in days) - all editable directly from the Dashboard,
// since there's no separate Settings screen in this app.

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants.dart';

class SettingsProvider extends ChangeNotifier {
  static const _keyRoomName = 'settings_room_name';
  static const _keyNotificationsEnabled = 'settings_notifications_enabled';
  static const _keyFilterIntervalDays = 'settings_filter_interval_days';

  SettingsProvider() {
    _load();
  }

  bool _isLoaded = false;
  bool get isLoaded => _isLoaded;

  String _roomName = AppConstants.roomName;
  String get roomName => _roomName;

  bool _notificationsEnabled = true;
  bool get notificationsEnabled => _notificationsEnabled;

  int _filterIntervalDays = AppConstants.filterResetIntervalDays;
  int get filterIntervalDays => _filterIntervalDays;

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _roomName = prefs.getString(_keyRoomName) ?? AppConstants.roomName;
    _notificationsEnabled = prefs.getBool(_keyNotificationsEnabled) ?? true;
    _filterIntervalDays = prefs.getInt(_keyFilterIntervalDays) ??
        AppConstants.filterResetIntervalDays;
    _isLoaded = true;
    notifyListeners();
  }

  Future<void> setRoomName(String value) async {
    _roomName = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyRoomName, value);
  }

  Future<void> setNotificationsEnabled(bool value) async {
    _notificationsEnabled = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyNotificationsEnabled, value);
  }

  Future<void> setFilterIntervalDays(int days) async {
    final clamped = days.clamp(1, 365);
    _filterIntervalDays = clamped;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyFilterIntervalDays, clamped);
  }

  Future<void> resetToDefaults() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyRoomName);
    await prefs.remove(_keyNotificationsEnabled);
    await prefs.remove(_keyFilterIntervalDays);
    _roomName = AppConstants.roomName;
    _notificationsEnabled = true;
    _filterIntervalDays = AppConstants.filterResetIntervalDays;
    notifyListeners();
  }
}