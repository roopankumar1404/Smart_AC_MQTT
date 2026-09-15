// lib/core/constants.dart

/// App-wide constants: device identifiers, Firestore paths,
/// timing thresholds, and default values.
class AppConstants {
  AppConstants._();

  // ---------------------------------------------------------------------
  // APP INFO
  // ---------------------------------------------------------------------
  static const String appName = 'Smart AC Controller';
  static const String appVersion = '1.0.0';

  // ---------------------------------------------------------------------
  // DEVICE IDENTITY
  // Change this to match your actual ESP32 device document ID in Firestore.
  // ---------------------------------------------------------------------
  static const String deviceId = 'ac_living_room_01';
  static const String roomName = 'My Room';
  static const String defaultWeatherLocation = 'Avadi, Tamil Nadu';
  // ---------------------------------------------------------------------
  // FIRESTORE COLLECTIONS
  // ---------------------------------------------------------------------
  static const String collectionDevices = 'devices';
  static const String collectionEnergyLogs = 'energy_logs';
  static const String collectionFilterLogs = 'filter_logs';
  static const String collectionSchedules = 'schedules';
  static const String collectionNotifications = 'notifications';

  // ---------------------------------------------------------------------
  // FIRESTORE FIELD KEYS (device document)
  // ---------------------------------------------------------------------
  static const String fieldTemperature = 'temperature';
  static const String fieldHumidity = 'humidity';
  static const String fieldPowerWatts = 'powerWatts';
  static const String fieldVoltage = 'voltage';
  static const String fieldCurrent = 'current';
  static const String fieldTodayEnergyKwh = 'todayEnergyKwh';
  static const String fieldAcOn = 'acOn';
  static const String fieldTargetTemp = 'targetTemp';
  static const String fieldFanSpeed = 'fanSpeed';
  static const String fieldSwingMode = 'swingMode';
  static const String fieldSleepOn = 'sleepOn';
  static const String fieldTurboOn = 'turboOn';
  static const String fieldWifiOnline = 'wifiOnline';
  static const String fieldEsp32Online = 'esp32Online';
  static const String fieldCommandTimestamp = 'commandTimestamp';
  static const String fieldLastSeen = 'lastSeen';
  static const String fieldCurrentMode = 'currentMode';
  static const String fieldFrequency = 'frequency';
  static const String fieldPowerFactor = 'powerFactor';
  static const String fieldTodayRunningMinutes = 'todayRunningMinutes';
  static const String fieldEstimatedCostToday = 'estimatedCostToday';
  static const String fieldInternetOnline = 'internetOnline';
  static const String fieldTempSensorOnline = 'tempSensorOnline';
  static const String fieldHumiditySensorOnline = 'humiditySensorOnline';
  static const String fieldEnergyMeterOnline = 'energyMeterOnline';
  static const String fieldFirmwareVersion = 'firmwareVersion';
  static const String fieldSystemUptimeSeconds = 'systemUptimeSeconds';
  static const String fieldFreeMemoryKb = 'freeMemoryKb';
  static const String fieldSleepActive = 'sleepActive';
  static const String fieldSleepTimerHours = 'sleepTimerHours';
  // ---------------------------------------------------------------------
  // AC CONTROL LIMITS
  // ---------------------------------------------------------------------
  static const int minTargetTemp = 16;
  static const int maxTargetTemp = 30;
  static const int defaultTargetTemp = 24;

  static const List<String> fanSpeeds = ['Auto', 'F1', 'F2', 'F3', 'F4', 'F5'];
  // AC Mode — matches real remote: Cool, Dry, Fan
  static const List<String> acModes = ['Cool', 'Dry', 'Fan'];
// Vertical swing: 0 = Off, 1..swingPositionCount = fixed physical steps,
  // matching how many stops your AC's original remote cycles through.
  static const int swingPositionCount = 6;
  static const List<String> swingPositionLabels = [
    'Lowest',
    'Low',
    'Middle',
    'Upper Mid',
    'High',
    'Highest'
  ];
  // ---------------------------------------------------------------------
  // FILTER CLEANING
  // ---------------------------------------------------------------------
  static const int filterResetIntervalDays = 14;
  static const String filterLastResetKey = 'filter_last_reset_timestamp';

  // ---------------------------------------------------------------------
  // ENERGY
  // ---------------------------------------------------------------------
  static const double energyWarningThresholdKwh = 8.0;
  static const List<String> energyPeriods = [
    'Daily',
    'Weekly',
    'Monthly',
    'Yearly',
  ];

  // ---------------------------------------------------------------------
  // CONNECTIVITY / HEALTH
  // ---------------------------------------------------------------------
  // If the device hasn't reported in this window, treat it as offline
  // even if the Firestore doc says otherwise (stale-data protection).
  static const int staleDataThresholdSeconds = 120;

  // ---------------------------------------------------------------------
  // WEATHER API
  // ---------------------------------------------------------------------
  // Replace with your actual weather provider key/config.
  // Keep this out of source control in a real deployment (.env / --dart-define).
  // Get a free API key at https://openweathermap.org/api (sign up,
  // API keys section, takes a few minutes). Paste it below.
  static const String weatherApiKey = '***';
  static const String weatherApiBaseUrl =
      'https://api.openweathermap.org/data/2.5';
  static const String geocodingApiBaseUrl =
      'https://api.openweathermap.org/geo/1.0';
  static const String weatherApiUnits = 'metric';

  // ---------------------------------------------------------------------
  // ANIMATION DURATIONS (ms)
  // ---------------------------------------------------------------------
  static const int animFast = 200;
  static const int animMedium = 350;
  static const int animSlow = 600;

  // ---------------------------------------------------------------------
  // BREAKPOINTS (px) — kept here too for quick reference alongside Responsive
  // ---------------------------------------------------------------------
  static const double breakpointTablet = 700;
  static const double breakpointDesktop = 1100;
}
