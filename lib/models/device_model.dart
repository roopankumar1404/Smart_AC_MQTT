// lib/models/device_model.dart
// Full device state — merged from MQTT state + telemetry topics.

class DeviceModel {
  // AC Control State (from state topic)
  final bool   acOn;
  final int    targetTemp;
  final String fanSpeed;
  final String swingMode;
  final int    swingPosition;
  final bool   sleepActive;
  final int    sleepTimerHours;
  final bool   lightOn;
  final bool   mute;
  final bool   hcMode;
  final bool   dcMode;
  final String currentMode;

  // Telemetry (from telemetry topic)
  final double temperature;
  final double humidity;
  final double powerWatts;
  final double voltage;
  final double current;
  final double frequency;
  final double powerFactor;
  final double todayEnergyKwh;
  final double todayRunningMinutes;
  final double estimatedCostToday;
  final double systemUptimeSeconds;
  final bool   wifiOnline;
  final bool   mqttOnline;
  final bool   esp32Online;
  final bool   tempSensorOnline;
  final bool   humiditySensorOnline;
  final bool   energyMeterOnline;
  final bool   irBlasterOnline;
  final String sessionBootTime;
  final String bootReason;
  final int    rebootCountToday;

  // Derived from MQTT LWT
  final bool   deviceMqttOnline; // from status topic

  // Timing
  final DateTime? lastSeen;

  const DeviceModel({
    this.acOn            = false,
    this.targetTemp      = 24,
    this.fanSpeed        = 'Auto',
    this.swingMode       = 'off',
    this.swingPosition   = 0,
    this.sleepActive     = false,
    this.sleepTimerHours = 0,
    this.lightOn         = true,
    this.mute            = false,
    this.hcMode          = false,
    this.dcMode          = false,
    this.currentMode     = 'Cool',
    this.temperature     = 0,
    this.humidity        = 0,
    this.powerWatts      = 0,
    this.voltage         = 0,
    this.current         = 0,
    this.frequency       = 0,
    this.powerFactor     = 0,
    this.todayEnergyKwh  = 0,
    this.todayRunningMinutes = 0,
    this.estimatedCostToday  = 0,
    this.systemUptimeSeconds = 0,
    this.wifiOnline      = false,
    this.mqttOnline      = false,
    this.esp32Online     = false,
    this.tempSensorOnline    = false,
    this.humiditySensorOnline= false,
    this.energyMeterOnline   = false,
    this.irBlasterOnline     = false,
    this.sessionBootTime = '',
    this.bootReason      = 'Power On',
    this.rebootCountToday= 0,
    this.deviceMqttOnline= false,
    this.lastSeen,
  });

  factory DeviceModel.initial() => DeviceModel(lastSeen: null);

  /// Apply state JSON (from MQTT state topic)
  DeviceModel applyState(Map<String,dynamic> s) {
    return copyWith(
      acOn:             s['acOn']           as bool?   ?? acOn,
      currentMode:      s['currentMode']    as String? ?? currentMode,
      targetTemp:       (s['targetTemp']    as num?)?.toInt() ?? targetTemp,
      fanSpeed:         s['fanSpeed']       as String? ?? fanSpeed,
      swingMode:        s['swingMode']      as String? ?? swingMode,
      swingPosition:    (s['swingPosition'] as num?)?.toInt() ?? swingPosition,
      sleepActive:      s['sleepActive']    as bool?   ?? sleepActive,
      sleepTimerHours:  (s['sleepTimerHours'] as num?)?.toInt() ?? sleepTimerHours,
      lightOn:          s['lightOn']        as bool?   ?? lightOn,
      mute:             s['mute']           as bool?   ?? mute,
      hcMode:           s['hcMode']         as bool?   ?? hcMode,
      dcMode:           s['dcMode']         as bool?   ?? dcMode,
      esp32Online:      true,
      deviceMqttOnline: true,
      lastSeen:         DateTime.now(),
    );
  }

  /// Apply telemetry JSON (from MQTT telemetry topic)
  DeviceModel applyTelemetry(Map<String,dynamic> t) {
    return copyWith(
      temperature:          (t['temperature']         as num?)?.toDouble() ?? temperature,
      humidity:             (t['humidity']             as num?)?.toDouble() ?? humidity,
      powerWatts:           (t['powerWatts']           as num?)?.toDouble() ?? powerWatts,
      voltage:              (t['voltage']              as num?)?.toDouble() ?? voltage,
      current:              (t['current']              as num?)?.toDouble() ?? current,
      frequency:            (t['frequency']            as num?)?.toDouble() ?? frequency,
      powerFactor:          (t['powerFactor']          as num?)?.toDouble() ?? powerFactor,
      todayEnergyKwh:       (t['todayEnergyKwh']       as num?)?.toDouble() ?? todayEnergyKwh,
      todayRunningMinutes:  (t['todayRunningMinutes']  as num?)?.toDouble() ?? todayRunningMinutes,
      estimatedCostToday:   (t['estimatedCostToday']   as num?)?.toDouble() ?? estimatedCostToday,
      systemUptimeSeconds:  (t['systemUptimeSeconds']  as num?)?.toDouble() ?? systemUptimeSeconds,
      wifiOnline:           t['wifiOnline']            as bool? ?? wifiOnline,
      mqttOnline:           t['mqttOnline']            as bool? ?? mqttOnline,
      esp32Online:          t['esp32Online']           as bool? ?? esp32Online,
        tempSensorOnline:     t['tempSensorOnline']      as bool? ?? tempSensorOnline,
        humiditySensorOnline: t['humiditySensorOnline'] as bool? ?? humiditySensorOnline,
      energyMeterOnline:    t['energyMeterOnline']     as bool? ?? energyMeterOnline,
      sessionBootTime:      t['sessionBootTime']       as String? ?? sessionBootTime,
      bootReason:           t['bootReason']            as String? ?? bootReason,
      rebootCountToday:     (t['rebootCountToday']     as num?)?.toInt() ?? rebootCountToday,
      lastSeen:             DateTime.now(),
    );
  }

  bool isStale(int thresholdSeconds) {
    if (lastSeen == null) return true;
    return DateTime.now().difference(lastSeen!).inSeconds > thresholdSeconds;
  }

  String lastUpdatedLabel() {
    if (lastSeen == null) return 'Never updated';
    final diff = DateTime.now().difference(lastSeen!);
    if (diff.inSeconds < 60) return 'Updated ${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return 'Updated ${diff.inMinutes}m ago';
    return 'Updated ${diff.inHours}h ago';
  }

  String uptimeLabel() {
    if (systemUptimeSeconds <= 0 || !esp32Online) return 'Offline';
    final s = systemUptimeSeconds.toInt();
    final d = s ~/ 86400; final h = (s % 86400) ~/ 3600; final m = (s % 3600) ~/ 60; final sec = s % 60;
    if (d > 0) return '${d}d ${h}h ${m}m';
    if (h > 0) return '${h}h ${m}m';
    if (m > 0) return '${m}m ${sec}s';
    return '${sec}s';
  }

  String sleepLabel() {
    if (!sleepActive || sleepTimerHours <= 0) return 'Off';
    return '${sleepTimerHours}h active';
  }

  String formattedBootTime() {
    if (sessionBootTime.isEmpty) return '-';
    try {
      final dt = DateTime.parse(sessionBootTime).toLocal();
      final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
      final amPm = dt.hour >= 12 ? 'PM' : 'AM';
      final min = dt.minute.toString().padLeft(2, '0');
      return '$h:$min $amPm';
    } catch (_) { return sessionBootTime; }
  }

  String freeMemoryLabel() => '-'; // not in MQTT telemetry (unused field)

  String lastSessionDurationLabel() => '-';

  DeviceModel copyWith({
    bool? acOn, int? targetTemp, String? fanSpeed, String? swingMode, int? swingPosition,
    bool? sleepActive, int? sleepTimerHours, bool? lightOn, bool? mute, bool? hcMode, bool? dcMode,
    String? currentMode, double? temperature, double? humidity, double? powerWatts, double? voltage,
    double? current, double? frequency, double? powerFactor, double? todayEnergyKwh,
    double? todayRunningMinutes, double? estimatedCostToday, double? systemUptimeSeconds,
    bool? wifiOnline, bool? mqttOnline, bool? esp32Online, bool? tempSensorOnline,
    bool? humiditySensorOnline, bool? energyMeterOnline, bool? irBlasterOnline,
    String? sessionBootTime, String? bootReason, int? rebootCountToday,
    bool? deviceMqttOnline, DateTime? lastSeen,
  }) {
    return DeviceModel(
      acOn: acOn ?? this.acOn, targetTemp: targetTemp ?? this.targetTemp,
      fanSpeed: fanSpeed ?? this.fanSpeed, swingMode: swingMode ?? this.swingMode,
      swingPosition: swingPosition ?? this.swingPosition, sleepActive: sleepActive ?? this.sleepActive,
      sleepTimerHours: sleepTimerHours ?? this.sleepTimerHours, lightOn: lightOn ?? this.lightOn,
      mute: mute ?? this.mute, hcMode: hcMode ?? this.hcMode, dcMode: dcMode ?? this.dcMode,
      currentMode: currentMode ?? this.currentMode, temperature: temperature ?? this.temperature,
      humidity: humidity ?? this.humidity, powerWatts: powerWatts ?? this.powerWatts,
      voltage: voltage ?? this.voltage, current: current ?? this.current,
      frequency: frequency ?? this.frequency, powerFactor: powerFactor ?? this.powerFactor,
      todayEnergyKwh: todayEnergyKwh ?? this.todayEnergyKwh,
      todayRunningMinutes: todayRunningMinutes ?? this.todayRunningMinutes,
      estimatedCostToday: estimatedCostToday ?? this.estimatedCostToday,
      systemUptimeSeconds: systemUptimeSeconds ?? this.systemUptimeSeconds,
      wifiOnline: wifiOnline ?? this.wifiOnline, mqttOnline: mqttOnline ?? this.mqttOnline,
      esp32Online: esp32Online ?? this.esp32Online, tempSensorOnline: tempSensorOnline ?? this.tempSensorOnline,
      humiditySensorOnline: humiditySensorOnline ?? this.humiditySensorOnline,
      energyMeterOnline: energyMeterOnline ?? this.energyMeterOnline,
      irBlasterOnline: irBlasterOnline ?? this.irBlasterOnline,
      sessionBootTime: sessionBootTime ?? this.sessionBootTime, bootReason: bootReason ?? this.bootReason,
      rebootCountToday: rebootCountToday ?? this.rebootCountToday,
      deviceMqttOnline: deviceMqttOnline ?? this.deviceMqttOnline, lastSeen: lastSeen ?? this.lastSeen,
    );
  }

  // For energy screen compatibility (Firestore energy log fields)
  double get freeMemoryKb => 0;
  double get lastSessionUptimeSeconds => 0;
  String get lastResetReason => bootReason;
  bool get turboOn => false;
  bool get internetOnline => wifiOnline;
}
