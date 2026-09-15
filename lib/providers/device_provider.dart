import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
// lib/providers/device_provider.dart
// MQTT-based device provider — no Firestore polling, no feedback loop.
// App publishes commands to MQTT, ESP32 executes and publishes back state.

import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/device_model.dart';
import '../models/schedule_model.dart';
import '../services/mqtt_service.dart';
import '../services/firestore_service.dart';
import '../services/notification_service.dart';
import '../services/fcm_push_service.dart';
import '../core/constants.dart';

class DeviceProvider extends ChangeNotifier {
  final MqttService       _mqtt;
  final FirestoreService  _firestore;

  DeviceModel _device = DeviceModel.initial();
  DeviceModel get device => _device;

  String? _error;
  String? get error => _error;

    bool _filterReminderActive = false;

  // Subscriptions
  StreamSubscription<Map<String,dynamic>>? _stateSub;
  StreamSubscription<Map<String,dynamic>>? _telemetrySub;
  StreamSubscription<String>? _statusSub;
  StreamSubscription<DateTime?>? _filterSub;
  StreamSubscription<Map<String,dynamic>?>? _scheduleSub;

  // Stale-timer: if MQTT goes silent, declare offline after 30s
  Timer? _staleTimer;
  static const int _staleThresholdSeconds = 30;

  bool _initializing = true; // Grace period - don't show red while MQTT connecting

  DeviceProvider(this._mqtt, this._firestore) {
    _loadCachedState();
    _bindMqttStreams();
    _bindFilter();
    _bindSchedule();
    // Allow 8 seconds for MQTT retained messages to arrive before showing offline
    Future.delayed(const Duration(seconds: 8), () {
      _initializing = false;
      notifyListeners();
    });
  }

  // ─────────────────────────────────────────
  // MQTT BINDINGS
  // ─────────────────────────────────────────
  static const String _keyCachedState = 'cached_device_state';
  static const String _keyCachedTelemetry = 'cached_device_telemetry';

  Future<void> _loadCachedState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_keyCachedState);
      if (raw != null) {
        final Map<String, dynamic> data = jsonDecode(raw);
        _device = _device.applyState(data);
      }
      final rawTelemetry = prefs.getString(_keyCachedTelemetry);
      if (rawTelemetry != null) {
        final Map<String, dynamic> data = jsonDecode(rawTelemetry);
        // Do not load old systemUptimeSeconds from disk cache; uptime must come live
        data.remove('systemUptimeSeconds');

        // Validate that cached telemetry is strictly from today
        final todayStr = DateTime.now().toIso8601String().substring(0, 10);
        final cachedDate = data['cache_date'] as String?;
        final ts = data['ts'] as String?;

        final bool isFromToday = (cachedDate == todayStr) && (ts != null && ts.startsWith(todayStr));
        if (!isFromToday) {
          // Stale cache from a previous day - reset daily cumulative metrics to 0
          data['todayRunningMinutes'] = 0.0;
          data['todayEnergyKwh'] = 0.0;
          data['estimatedCostToday'] = 0.0;
          // Purge stale telemetry cache so it never resurfaces
          await prefs.remove(_keyCachedTelemetry);
        }
        _device = _device.applyTelemetry(data);
      }
      notifyListeners();
    } catch (_) {}
  }

  Future<void> _saveCachedState(Map<String, dynamic> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyCachedState, jsonEncode(data));
    } catch (_) {}
  }

  Future<void> _saveCachedTelemetry(Map<String, dynamic> data) async {
    try {
      final todayStr = DateTime.now().toIso8601String().substring(0, 10);
      final String? ts = data['ts'] as String?;
      if (ts != null && !ts.startsWith(todayStr)) {
        return; // Never persist a packet from a previous day to disk cache
      }
      final prefs = await SharedPreferences.getInstance();
      data['cache_date'] = todayStr;
      await prefs.setString(_keyCachedTelemetry, jsonEncode(data));
    } catch (_) {}
  }

  void _bindMqttStreams() {
    // State topic — AC control state
    _stateSub = _mqtt.stateStream.listen((data) {
      final bool wasOn = _device.acOn;
      _device = _device.applyState(data);
      _saveCachedState(data);
      // AC turned ON (from physical remote or any source) -> send FCM push
      if (!wasOn && _device.acOn) {
        FcmPushService().sendAcOnNotification();
        NotificationService().showAcOnNotification(); // also show local if app is open
      }
      _resetStaleTimer();
      notifyListeners();
    });

    // Telemetry topic — sensor data every 10s
    _telemetrySub = _mqtt.telemetryStream.listen((data) {
      final String? ts = data['ts'] as String?;
      final todayStr = DateTime.now().toIso8601String().substring(0, 10);
      if (ts != null && !ts.startsWith(todayStr)) {
        // Discard daily cumulative metrics from a previous day's packet
        data['todayRunningMinutes'] = 0.0;
        data['todayEnergyKwh'] = 0.0;
        data['estimatedCostToday'] = 0.0;
      }
      _device = _device.applyTelemetry(data);
      _saveCachedTelemetry(data);
      _resetStaleTimer();
      notifyListeners();
    });

    // Status topic — LWT online/offline
    _statusSub = _mqtt.statusStream.listen((status) {
      final online = status == 'online';
      _device = _device.copyWith(esp32Online: online, deviceMqttOnline: online);
      if (!online) _staleTimer?.cancel();
      notifyListeners();
    });
  }

  void _resetStaleTimer() {
    _staleTimer?.cancel();
    _staleTimer = Timer(const Duration(seconds: _staleThresholdSeconds), () {
      // No telemetry for 30s — mark offline
      _device = _device.copyWith(esp32Online: false, wifiOnline: false);
      notifyListeners();
    });
  }

  // ─────────────────────────────────────────
  // PUBLISH COMMANDS (no Firestore write for controls)
  // ─────────────────────────────────────────

  void _publish(Map<String,dynamic> cmd) {
    _mqtt.publishCommand(cmd);
  }

  // Power
  void togglePower() {
    final newOn = !_device.acOn;
    _device = _device.copyWith(acOn: newOn);
    notifyListeners();
    _publish({'acOn': newOn, 'targetTemp': _device.targetTemp,
      'currentMode': _device.currentMode, 'fanSpeed': _device.fanSpeed});
  }

  void turnOn()  { if (!_device.acOn) togglePower(); }
  void turnOff() { if (_device.acOn)  togglePower(); }

  // Temperature
  Future<void> setTargetTemp(int temp) async {
    final clamped = temp.clamp(AppConstants.minTargetTemp, AppConstants.maxTargetTemp);
    final hadHcOrDc = _device.hcMode || _device.dcMode;
    _device = _device.copyWith(targetTemp: clamped, hcMode: false, dcMode: false);
    notifyListeners();
    final cmd = <String, dynamic>{
      'targetTemp': clamped,
      'acOn': _device.acOn,
      'currentMode': _device.currentMode,
      'fanSpeed': _device.fanSpeed,
    };
    if (hadHcOrDc) {
      cmd['hcMode'] = false;
      cmd['dcMode'] = false;
    }
    _publish(cmd);
  }

  Future<void> incrementTemp() => setTargetTemp(_device.targetTemp + 1);
  Future<void> decrementTemp() => setTargetTemp(_device.targetTemp - 1);

  // Fan Speed
  Future<void> setFanSpeed(String speed) async {
    if (!AppConstants.fanSpeeds.contains(speed)) return;
    final hadHcOrDc = _device.hcMode || _device.dcMode;
    _device = _device.copyWith(fanSpeed: speed, hcMode: false, dcMode: false);
    notifyListeners();
    final cmd = <String, dynamic>{
      'fanSpeed': speed,
      'acOn': _device.acOn,
      'targetTemp': _device.targetTemp,
      'currentMode': _device.currentMode,
    };
    if (hadHcOrDc) {
      cmd['hcMode'] = false;
      cmd['dcMode'] = false;
    }
    _publish(cmd);
  }

  // Mode
  Future<void> setMode(String mode) async {
    if (!AppConstants.acModes.contains(mode)) return;
    final hadHcOrDc = _device.hcMode || _device.dcMode;
    _device = _device.copyWith(currentMode: mode, hcMode: false, dcMode: false);
    notifyListeners();
    final cmd = <String, dynamic>{
      'currentMode': mode,
      'acOn': _device.acOn,
      'targetTemp': _device.targetTemp,
      'fanSpeed': _device.fanSpeed,
    };
    if (hadHcOrDc) {
      cmd['hcMode'] = false;
      cmd['dcMode'] = false;
    }
    _publish(cmd);
  }

  // Swing
  Future<void> setSwingOff() async {
    _device = _device.copyWith(swingMode: 'off', swingPosition: 0);
    notifyListeners();
    _publish({'swingMode': 'off', 'swingPosition': 0});
  }

  Future<void> setSwingAuto() async {
    _device = _device.copyWith(swingMode: 'auto', swingPosition: 0);
    notifyListeners();
    _publish({'swingMode': 'auto', 'swingPosition': 0});
  }

  Future<void> setSwingPosition(int position) async {
    final clamped = position.clamp(1, AppConstants.swingPositionCount);
    _device = _device.copyWith(swingMode: 'fixed', swingPosition: clamped);
    notifyListeners();
    _publish({'swingMode': 'fixed', 'swingPosition': clamped});
  }

  // Sleep
  Future<void> setSleepHours(int hours) async {
    final clamped = hours.clamp(1, 7);
    _device = _device.copyWith(sleepActive: true, sleepTimerHours: clamped);
    notifyListeners();
    _publish({'sleepActive': true, 'sleepTimerHours': clamped});
  }

  Future<void> cancelSleep() async {
    _device = _device.copyWith(sleepActive: false, sleepTimerHours: 0);
    notifyListeners();
    _publish({'sleepActive': false, 'sleepTimerHours': 0});
  }

  // Light
  Future<void> toggleLight() async {
    final newVal = !_device.lightOn;
    _device = _device.copyWith(lightOn: newVal);
    notifyListeners();
    _publish({'lightOn': newVal});
  }

  // Mute
  Future<void> toggleMute() async {
    final newVal = !_device.mute;
    _device = _device.copyWith(mute: newVal);
    notifyListeners();
    _publish({'mute': newVal});
  }

  // HC Mode
  Future<void> toggleHcMode() async {
    final newVal = !_device.hcMode;
    _device = _device.copyWith(hcMode: newVal, dcMode: false);
    notifyListeners();
    _publish({'hcMode': newVal, 'dcMode': false});
  }

  // DC Mode
  Future<void> toggleDcMode() async {
    final newVal = !_device.dcMode;
    _device = _device.copyWith(dcMode: newVal, hcMode: false);
    notifyListeners();
    _publish({'dcMode': newVal, 'hcMode': false});
  }

  // Turbo (stub — not implemented in firmware yet)
  Future<void> toggleTurbo() async {}

  // ESP32 system commands (via Firestore, not MQTT)
  Future<void> restartEsp32() async {
    try { await _firestore.requestEspRestart(); } catch (e) { _error = e.toString(); notifyListeners(); }
  }

  Future<void> factoryReset() async {
    try { await _firestore.requestFactoryReset(); } catch (e) { _error = e.toString(); notifyListeners(); }
  }

  Future<void> refresh() async {
    _initializing = true;
    notifyListeners();
    if (!_mqtt.isConnected) {
      await _mqtt.connect();
    } else {
      _mqtt.publishCommand({'cmd': 'refresh'});
    }
    Future.delayed(const Duration(seconds: 4), () {
      if (_initializing) {
        _initializing = false;
        notifyListeners();
      }
    });
  }

  // ─────────────────────────────────────────
  // ONLINE / HEALTH
  // ─────────────────────────────────────────
  bool get isEsp32ActuallyOnline => _initializing || (_device.esp32Online && !_device.isStale(_staleThresholdSeconds));
  bool get isWifiActuallyOnline  => _device.wifiOnline  && !_device.isStale(_staleThresholdSeconds);
  bool get isFullyOnline         => isWifiActuallyOnline && isEsp32ActuallyOnline;

  int get healthScore {
    int score = 0;
    if (isWifiActuallyOnline)  score += 34;
    if (isEsp32ActuallyOnline) score += 33;
    if (!_device.isStale(_staleThresholdSeconds)) score += 33;
    return score;
  }

  // ─────────────────────────────────────────
  // FILTER
  // ─────────────────────────────────────────
  DateTime? _filterLastReset;
  DateTime? get filterLastReset => _filterLastReset;

  void _bindFilter() {
    _filterSub = _firestore.lastFilterResetStream().listen((resetDate) {
      _filterLastReset = resetDate;
      notifyListeners();
    });
  }

  Future<void> resetFilter([int? intervalDays]) async {
    await _firestore.resetFilterTimer();
    _filterReminderActive = false;
    await NotificationService().cancelFilterReminder();
    final interval = intervalDays ?? AppConstants.filterResetIntervalDays;
    _mqtt.publishCommand({
      'filter': {
        'action': 'reset',
        'intervalDays': interval,
        'resetTs': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      }
    });
    notifyListeners();
  }

  void checkFilterNotifications(int intervalDays) {
    if (isFilterOverdue(intervalDays)) {
      if (!_filterReminderActive) {
        _filterReminderActive = true;
        NotificationService().startFilterCleanReminder(intervalHours: 3);
        FcmPushService().sendFilterCleanReminder();
      }
    } else {
      if (_filterReminderActive) { _filterReminderActive = false; NotificationService().cancelFilterReminder(); }
    }
  }

  int filterDaysRemaining(int intervalDays) => _firestore.daysUntilFilterDue(_filterLastReset, intervalDays);
  DateTime? filterNextDueDate(int intervalDays) {
    if (_filterLastReset == null) return null;
    return _filterLastReset!.add(Duration(days: intervalDays));
  }
  bool isFilterOverdue(int intervalDays) => _filterLastReset != null && filterDaysRemaining(intervalDays) <= 0;
  bool get isLongRunAlert => _device.acOn && _device.todayRunningMinutes >= 480;

  // ─────────────────────────────────────────
  // SCHEDULE
  // ─────────────────────────────────────────
  ScheduleModel _schedule = ScheduleModel.initial();
  ScheduleModel get schedule => _schedule;

  void _bindSchedule() {
    _scheduleSub = _firestore.scheduleStream().listen((data) {
      _schedule = data == null ? ScheduleModel.initial() : ScheduleModel.fromMap(data);
      notifyListeners();
    });
  }

  Future<void> _pushSchedule() async {
    try {
      await _firestore.setSchedule(_schedule.toMap());
      // Instantly deliver schedule to ESP32 over MQTT
      _mqtt.publishCommand({
        'schedule': _schedule.toMap(),
      });
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> setScheduleOnEnabled(bool enabled)  async { _schedule=_schedule.copyWith(onEnabled: enabled);  notifyListeners(); await _pushSchedule(); }
  Future<void> setScheduleOffEnabled(bool enabled) async { _schedule=_schedule.copyWith(offEnabled: enabled); notifyListeners(); await _pushSchedule(); }
  Future<void> setScheduleOnTime(String time)  async { _schedule=_schedule.copyWith(onTime: time);  notifyListeners(); await _pushSchedule(); }
  Future<void> setScheduleOffTime(String time) async { _schedule=_schedule.copyWith(offTime: time); notifyListeners(); await _pushSchedule(); }

  // ─────────────────────────────────────────
  // DISPOSE
  // ─────────────────────────────────────────
  @override
  void dispose() {
    _staleTimer?.cancel();
    _stateSub?.cancel();
    _telemetrySub?.cancel();
    _statusSub?.cancel();
    _filterSub?.cancel();
    _scheduleSub?.cancel();
    super.dispose();
  }
}


