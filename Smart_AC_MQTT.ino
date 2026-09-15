// Smart_AC_MQTT.ino  (v2.0 - MQTT Edition)
// =====================================================================
// MQTT DUAL-CORE ARCHITECTURE — Full Feature Parity with Smart_AC.ino
// =====================================================================
// Core 1: Hardware (IR Receiver, OLED 5-Screen, PZEM, DHT22 Power-Cycle, Button)
//         Identical logic to original — zero network calls, 4 FPS OLED
// Core 0: Network (WiFi, EMQX MQTT TLS, NTP, Outdoor Weather, Firebase energy logs)
//         MQTT publish/subscribe replaces ALL Firestore polling.
//         Feedback loop is IMPOSSIBLE because app commands come via MQTT,
//         not by polling Firestore. Physical remote actions publish state
//         to MQTT and the app receives it — one direction only.
// =====================================================================
// Libraries required (Install via Arduino Library Manager):
//   1. IRremoteESP8266 (crankyoldgit)
//   2. Adafruit SSD1306
//   3. Adafruit GFX Library
//   4. PZEM004Tv30 (Olexa Prokopenko)
//   5. DHT sensor library (Adafruit)
//   6. PubSubClient (Nick O'Leary)            <- NEW for MQTT
//   7. ArduinoJson (Benoit Blanchon)           <- NEW for JSON
//   8. Firebase ESP Client (Mobizt)            <- kept for energy logs
// =====================================================================

#include <WiFi.h>
#include <WiFiClientSecure.h>
#include <WiFiClient.h>
#include <HTTPClient.h>
#include <Firebase_ESP_Client.h>
#include <PubSubClient.h>
#include <ArduinoJson.h>
#include <Preferences.h>

#include <IRrecv.h>
#include <IRsend.h>
#include <IRutils.h>
#include <IRac.h>
#include <IRtext.h>
#include <ir_LG.h>

#include <Wire.h>
#include <Adafruit_GFX.h>
#include <Adafruit_SSD1306.h>

#include <PZEM004Tv30.h>
#include <DHT.h>

#include "soc/soc.h"
#include "soc/rtc_cntl_reg.h"

// =====================================================================
// TELEGRAM BOT CONFIGURATION & ASYNC QUEUE
// =====================================================================
#define TELEGRAM_BOT_TOKEN "***"
#define TELEGRAM_CHAT_ID   "***"

struct TelegramMsg {
  char text[384];
};
QueueHandle_t qTelegramMsg = NULL;

// Filter Tracking (stored in Flash NVS)
uint32_t filterResetTs = 0;
uint16_t filterIntervalDays = 30;
uint32_t filterLastAlertDay = 0;

// AC Session Tracking for Run-time & Energy Summary
unsigned long acSessionStartMs = 0;
double acSessionStartEnergy = 0.0;
enum AcSource { SRC_REMOTE, SRC_APP, SRC_SCHEDULE, SRC_BUTTON };
AcSource lastAcTriggerSource = SRC_APP;

// Nightly digest tracking
uint32_t lastDigestDayIdx = 0;

// Alerts cooldowns
unsigned long lastVoltageAlertMs = 0;
unsigned long lastTempAlertMs = 0;
bool bootAlertSent = false;

// =====================================================================
// DEBUG SWITCH  (set to 1 while testing, 0 for production silent mode)
// =====================================================================
#define ENABLE_SERIAL_DEBUG 1

#if ENABLE_SERIAL_DEBUG
  #define DBG_BEGIN(b)    Serial.begin(b)
  #define DBG_PRINT(...)  Serial.print(__VA_ARGS__)
  #define DBG_PRINTLN(...) Serial.println(__VA_ARGS__)
  #define DBG_PRINTF(...) Serial.printf(__VA_ARGS__)
#else
  #define DBG_BEGIN(b)
  #define DBG_PRINT(...)
  #define DBG_PRINTLN(...)
  #define DBG_PRINTF(...)
#endif

// =====================================================================
// OLED
// =====================================================================
#define SCREEN_WIDTH   128
#define SCREEN_HEIGHT  64
#define OLED_RESET     -1
#define SCREEN_ADDRESS 0x3C
Adafruit_SSD1306 display(SCREEN_WIDTH, SCREEN_HEIGHT, &Wire, OLED_RESET);

int currentScreen = 1;
bool autoSwitchedToPower = false;
unsigned long lastOledUpdate = 0;
const unsigned long oledUpdateIntervalMs = 250;

int buttonState = HIGH;
int lastButtonState = HIGH;
unsigned long lastDebounceTime = 0;
const unsigned long debounceDelay = 40;

// =====================================================================
// HARDWARE PINS  (identical to original)
// =====================================================================
#define DHT_PIN        15
#define DHT_POWER_PIN  25
#define PZEM_RX_PIN    16
#define PZEM_TX_PIN    17

const uint16_t kRecvPin   = 4;
const uint16_t kSendPin   = 5;
const uint16_t kButtonPin = 2;

// DHT22 power-cycle state machine
enum DhtState { DHT_OFF, DHT_WARMING, DHT_READY };
DhtState dhtState = DHT_WARMING;
unsigned long lastDhtCycle = 0;
unsigned long dhtStateMs   = 0;
const unsigned long DHT_CYCLE_MS  = 60000;  // read every 60s
const unsigned long DHT_WARMUP_MS = 2000;   // 2s warm-up

// PZEM timing
unsigned long lastPzemRead = 0;
const unsigned long pzemReadMs = 2500;

// =====================================================================
// HARDWARE OBJECTS
// =====================================================================
const uint16_t kCaptureBufferSize = 1024;
const uint8_t  kTimeout = 50;
IRrecv irrecv(kRecvPin, kCaptureBufferSize, kTimeout, true);
decode_results results;
IRsend irsend(kSendPin);
IRLgAc ac(kSendPin);
PZEM004Tv30 pzem(Serial2, PZEM_RX_PIN, PZEM_TX_PIN);
DHT dht(DHT_PIN, DHT22);

// =====================================================================
// CREDENTIALS
// =====================================================================
#define WIFI_SSID            "***"
#define WIFI_PASSWORD        "***"
#define DEVICE_ID            "ac_living_room_01"

// EMQX Cloud MQTT
#define MQTT_BROKER          "***.emqxsl.com"
#define MQTT_PORT            8883
#define MQTT_USER            "***"
#define MQTT_PASS            "***"
#define MQTT_CLIENT_ID       "esp32_smartac_01"

// Firebase (energy logs only)
#define API_KEY              "***"
#define FIREBASE_PROJECT_ID  "smart-ac-iot"
#define FIREBASE_AUTH_EMAIL    "esp32@smartac.com"
#define FIREBASE_AUTH_PASSWORD "***"

// =====================================================================
// MQTT TOPICS
// =====================================================================
#define TOPIC_CMD       "smartac/" DEVICE_ID "/cmd"
#define TOPIC_STATE     "smartac/" DEVICE_ID "/state"
#define TOPIC_TELEMETRY "smartac/" DEVICE_ID "/telemetry"
#define TOPIC_STATUS    "smartac/" DEVICE_ID "/status"
#define TOPIC_TELEGRAM  "smartac/" DEVICE_ID "/telegram"

// =====================================================================
// KNOWN LG RAW CODES  (identical to original)
// =====================================================================
const uint64_t kSwingCode[6] = {
  0x8813048, 0x8813059, 0x881306A, 0x881307B, 0x881308C, 0x881309D
};
const uint64_t kSwingAutoCode = 0x8813149;
const uint64_t kSwingOffCode  = 0x881315A;
const uint16_t kSwingBits = 28;

const uint32_t kSleepCode[8] = {
  0x88A000A, 0x88A03C9, 0x88A0789, 0x88A0B49,
  0x88A0F09, 0x88A12C9, 0x88A1689, 0x88A1A49
};
const uint16_t kSleepBits = 28;

const float kVoltageOffset = 5.5;
const float kCostPerKwh   = 7.0;

// IR self-test
bool awaitingLoopback      = false;
bool irBlasterSelfTestOk   = false;
unsigned long loopbackDeadline  = 0;
const unsigned long loopbackWindowMs = 500;

// =====================================================================
// FREERTOS IPC STRUCTS
// =====================================================================
struct AppStateEvent {
  bool acOn; char mode[8]; int targetTemp; char fanSpeed[8];
  char swingMode[8]; int swingPosition; bool sleepActive; int sleepTimerHours;
  bool lightOn; bool mute; bool hcMode; bool dcMode;
};
struct AppCommandEvent {
  bool acOn; char mode[8]; int targetTemp; char fanSpeed[8];
  char swingMode[8]; int swingPosition; bool sleepActive; int sleepTimerHours;
  bool lightOn; bool mute; bool hcMode; bool dcMode;
  bool hasClimate; bool hasSwing; bool hasSleep;
  bool hasLight; bool hasMute; bool hasHc; bool hasDc;
};

struct SharedTelemetry {
  float roomTemp, roomHumidity, pzemVoltage, pzemCurrent, pzemPower;
  float pzemEnergy, pzemFrequency, pzemPf;
  bool dhtOnline, pzemOnline, wifiConnected, mqttConnected, internetOnline, irBlasterOk;
  float todayRunningMins, hourlyEnergy[24];
  uint32_t uptimeSec;
};

QueueHandle_t qAppCmd   = NULL;  // Core0->Core1 commands
QueueHandle_t qStatePub = NULL;  // Core1->Core0 publish-state signal
SemaphoreHandle_t dataMutex = NULL;
SharedTelemetry sharedData;

// =====================================================================
// AC STATE VARIABLES (Core 1 owned)
// =====================================================================
bool   acOn = false;
String mode = "Cool";
int    targetTemp = 24;
String fanSpeed   = "Auto";
String swingMode  = "off";
int    swingPosition = 0;
bool   sleepActive   = false;
int    sleepTimerHours = 0;
bool   haveClimateState = false;
bool   lightOn = true;
bool   mute    = false;
bool   hcMode  = false;
bool   dcMode  = false;

// =====================================================================
// SENSOR VARIABLES (Core 1 owned)
// =====================================================================
float pzemVoltage = 0, pzemCurrent = 0, pzemPower = 0;
float pzemEnergy  = 0, pzemFrequency = 0, pzemPf = 0;
float dayStartEnergyBase = -1.0;
bool  pzemOnline = false;
int   pzemFailCount = 0;

float hourlyEnergy[24]   = {0};
float lastHourEnergyBase = 0;
int   currentHourTracked = -1;

float roomTemp = 0, roomHumidity = 0;
bool  dhtOnline = false;
int   dhtFailCount = 0;

float outdoorTemp  = 0;
bool  outdoorTempValid = false;
bool  internetOnline   = false;

unsigned long acOnStartMs    = 0;
float         todayRunningMins = 0;
String        lastResetDate    = "";

// =====================================================================
// SMART SCHEDULER STATE (updated by Core 0 from Firestore)
// =====================================================================
volatile bool   schedOnEnabled  = false;
volatile bool   schedOffEnabled = false;
char            schedOnTime[6]  = "";
char            schedOffTime[6] = "";
bool            haveScheduleState      = false;
String          lastScheduleTriggerKey = "";
SemaphoreHandle_t schedMutex = NULL;

// =====================================================================
// RTC (Survives deep-sleep)
// =====================================================================
RTC_DATA_ATTR uint32_t rtcBootCount = 0;
RTC_DATA_ATTR uint32_t rtcLastSessionDurationSec = 0;
RTC_DATA_ATTR uint32_t rtcTodayRebootCount = 0;
RTC_DATA_ATTR char     rtcLastResetReason[32] = "Power On";
RTC_DATA_ATTR char     rtcLastBootDate[12]    = "";
RTC_DATA_ATTR float    rtcDayStartEnergyBase = -1.0;
RTC_DATA_ATTR float    rtcTodayRunningMins   = 0;
RTC_DATA_ATTR float    rtcPzemEnergy         = 0;
RTC_DATA_ATTR char     rtcEnergyDate[12]     = "";
String currentBootReason   = "Power On";
String sessionBootTimeIso  = "";

// =====================================================================
// NETWORK OBJECTS (Core 0 only)
// =====================================================================
WiFiClientSecure mqttTlsClient;
PubSubClient     mqttClient(mqttTlsClient);
FirebaseData     fbdo;
FirebaseAuth     fbAuth;
FirebaseConfig   fbConfig;
volatile bool    mqttConnected = false;

const long kIstOffsetSeconds = 19800; // +5:30 IST

// =====================================================================
// FORWARD DECLARATIONS
// =====================================================================
void networkTask(void*);
void checkIrReceiver();
void handleClimateFrame();
void handleSwingFrame(uint64_t code);
void handleSleepFrame(int hours);
bool isSwingCode(uint32_t code);
int  matchSleepCode(uint32_t rawCode);
void sendClimateIr();
void sendSwingIr();
void sendSleepIr();
void sendLightIr();
void sendMuteIr();
void sendHcIr();
void sendDcIr();
void runBlasterSelfTest();
void readPZEM();
void dhtPowerCycle();
void updateOledDisplay();
void midnightReset();
float getTodayRunningMins();
void checkAndRunSchedule();
void enqueueTelegramAlert(const String& msg);
void sendTelegramHttp(const char* text);
String urlEncode(const String& str);
void loadFilterFromNvs();
void saveFilterToNvs(uint32_t resetTs, uint16_t intervalDays);
void checkFilterAlerts();
void checkNightlyDigest();
void saveScheduleToNvs(bool onEn, const char* onT, bool offEn, const char* offT);
void loadScheduleFromNvs();
void publishState(AppStateEvent& evt);
void publishTelemetry();
bool mqttReconnect();
void mqttCallback(char* topic, byte* payload, unsigned int length);
void bootstrapStateFromFirestore();
void netSaveStateToFirestore(const AppStateEvent& snap);
void netReadSchedule();
void netFetchOutdoorTemp();
void netWriteDailyEnergyLog();
String extractParenthesized(const String& token);
String lgModeWordToLabel(const String& word);
String lgFanWordToLabel(const String& word);
String getCurrentIstHHMM();
String getCurrentIstDateKey();
String getIso8601Timestamp();
void customTokenStatusCallback(TokenInfo info);

// =====================================================================
// TELEGRAM HELPER FUNCTIONS (Non-Blocking FreeRTOS Queue)
// =====================================================================
String urlEncode(const String& str) {
  String encoded = "";
  char c;
  char code0, code1;
  for (int i = 0; i < (int)str.length(); i++) {
    c = str.charAt(i);
    if (isalnum(c)) {
      encoded += c;
    } else if (c == ' ') {
      encoded += "%20";
    } else if (c == '\n') {
      encoded += "%0A";
    } else {
      code1 = (c & 0xf) + '0';
      if ((c & 0xf) > 9) code1 = (c & 0xf) - 10 + 'A';
      c = (c >> 4) & 0xf;
      code0 = c + '0';
      if (c > 9) code0 = c - 10 + 'A';
      encoded += '%';
      encoded += code0;
      encoded += code1;
    }
  }
  return encoded;
}

void enqueueTelegramAlert(const String& msg) {
  if (!qTelegramMsg) return;
  TelegramMsg m;
  strncpy(m.text, msg.c_str(), sizeof(m.text) - 1);
  m.text[sizeof(m.text) - 1] = '\0';
  xQueueSend(qTelegramMsg, &m, 0); // Non-blocking: <1 microsecond
  DBG_PRINTLN("Telegram alert queued");
}

void sendTelegramHttp(const char* text) {
  if (!mqttClient.connected()) return;
  // Escape newlines so the JSON template in EMQX Cloud is 100% valid
  String clean = "";
  for (int i = 0; text[i] != '\0'; i++) {
    if (text[i] == '\n') {
      clean += "\\n";
    } else if (text[i] == '\'') {
      clean += "'";
    } else {
      clean += text[i];
    }
  }
  mqttClient.publish(TOPIC_TELEGRAM, clean.c_str());
  DBG_PRINTLN("Alert published via MQTT (Zero TLS overhead, 100% stable)");
}

void loadFilterFromNvs() {
  Preferences prefs;
  if (prefs.begin("ac_filter", true)) {
    filterResetTs = prefs.getUInt("reset_ts", 0);
    filterIntervalDays = prefs.getUShort("int_days", 30);
    filterLastAlertDay = prefs.getUInt("last_alert", 0);
    prefs.end();
  }
  if (filterResetTs == 0) {
    time_t now = time(nullptr);
    filterResetTs = (now > 1700000000) ? (uint32_t)now : 1725800000;
  }
  DBG_PRINTF("Loaded filter: ResetTs=%u, Interval=%u\n", filterResetTs, filterIntervalDays);
}

void saveFilterToNvs(uint32_t resetTs, uint16_t intervalDays) {
  filterResetTs = resetTs;
  filterIntervalDays = intervalDays;
  filterLastAlertDay = 0;
  Preferences prefs;
  if (prefs.begin("ac_filter", false)) {
    prefs.putUInt("reset_ts", resetTs);
    prefs.putUShort("int_days", intervalDays);
    prefs.putUInt("last_alert", 0);
    prefs.end();
  }
}

void checkFilterAlerts() {
  time_t now = time(nullptr);
  if (now < 1700000000) return;
  uint32_t todayIdx = now / 86400;
  uint32_t daysUsed = (now > filterResetTs) ? (now - filterResetTs) / 86400 : 0;
  int daysRemaining = (int)filterIntervalDays - (int)daysUsed;
  if (daysRemaining <= 0 && filterLastAlertDay != todayIdx) {
    filterLastAlertDay = todayIdx;
    Preferences prefs;
    if (prefs.begin("ac_filter", false)) {
      prefs.putUInt("last_alert", todayIdx);
      prefs.end();
    }
    String msg = "⚠️ <b>Air Filter Clean Reminder</b>\n";
    msg += "🕒 Your AC air filter has been in use for <b>" + String(daysUsed) + " days</b> (Limit: " + String(filterIntervalDays) + " days).\n";
    msg += "Please clean the mesh filter to maintain cooling performance and save electricity.\n";
    msg += "<i>(Tap 'Reset Filter' in the app after cleaning).</i>";
    enqueueTelegramAlert(msg);
  }
}

void checkNightlyDigest() {
  time_t now = time(nullptr);
  if (now < 1700000000) return;
  String hhmm = getCurrentIstHHMM();
  uint32_t todayIdx = now / 86400;
  if (hhmm == "22:00" && lastDigestDayIdx != todayIdx) {
    lastDigestDayIdx = todayIdx;
    uint32_t daysUsed = (now > filterResetTs) ? (now - filterResetTs) / 86400 : 0;
    int daysRemaining = (int)filterIntervalDays - (int)daysUsed;
    String filterCond = (daysRemaining <= 0) ? ("⚠️ OVERDUE by " + String(abs(daysRemaining)) + " days!") : ("✅ Good (" + String(daysRemaining) + " days left)");

    String msg = "📊 <b>Daily Energy Digest — " + getCurrentIstDateKey() + "</b>\n";
    msg += "⏱️ <b>Total AC Runtime</b>: " + String((int)(todayRunningMins / 60)) + "h " + String((int)todayRunningMins % 60) + "m\n";
    msg += "⚡ <b>Electricity Used</b>: " + String(pzemEnergy, 3) + " kWh\n";
    msg += "💰 <b>Estimated Cost</b>: ₹" + String(pzemEnergy * kCostPerKwh, 2) + "\n";
    msg += "🔌 <b>Line Voltage</b>: " + String(pzemVoltage, 0) + "V | <b>Freq</b>: " + String(pzemFrequency, 1) + " Hz\n";
    msg += "────────────────────\n";
    msg += "🧹 <b>Air Filter Status</b>:\n";
    msg += "• <b>Days Used</b>: " + String(daysUsed) + " days\n";
    msg += "• <b>Days Remaining</b>: " + String(daysRemaining) + " days\n";
    msg += "• <b>Condition</b>: " + filterCond;
    enqueueTelegramAlert(msg);
  }
}

void customTokenStatusCallback(TokenInfo info) {
  if (info.status == token_status_ready) DBG_PRINTLN("Firebase Token Ready.");
}

// =====================================================================
// SETUP (Core 1)
// =====================================================================
void setup() {
  WRITE_PERI_REG(RTC_CNTL_BROWN_OUT_REG, 0);
  // Watchdogs left enabled to prevent esp_task_wdt_reset error spam
  DBG_BEGIN(115200);

  rtcBootCount++; rtcTodayRebootCount++;
  esp_reset_reason_t r = esp_reset_reason();
  switch (r) {
    case ESP_RST_POWERON:  currentBootReason = "Power On"; break;
    case ESP_RST_SW:       currentBootReason = "Software Reset"; break;
    case ESP_RST_PANIC:    currentBootReason = "Software Crash"; break;
    case ESP_RST_INT_WDT:  currentBootReason = "Interrupt Watchdog"; break;
    case ESP_RST_TASK_WDT: currentBootReason = "Task Watchdog"; break;
    case ESP_RST_BROWNOUT: currentBootReason = "Brownout"; break;
    default:               currentBootReason = "Reset (" + String(r) + ")"; break;
  }
  strncpy(rtcLastResetReason, currentBootReason.c_str(), sizeof(rtcLastResetReason));
  DBG_PRINTLN("Boot: " + currentBootReason);

  qAppCmd   = xQueueCreate(10, sizeof(AppCommandEvent));
  qStatePub = xQueueCreate(10, sizeof(AppStateEvent));
  qTelegramMsg = xQueueCreate(6, sizeof(TelegramMsg));
  dataMutex = xSemaphoreCreateMutex();
  schedMutex= xSemaphoreCreateMutex();
  loadScheduleFromNvs(); // Instantly restore schedule from Flash at boot
  loadFilterFromNvs();   // Restore filter tracking from Flash at boot

  pinMode(kButtonPin, INPUT_PULLUP);
  pinMode(DHT_POWER_PIN, OUTPUT);
  digitalWrite(DHT_POWER_PIN, HIGH); // Power on immediately at boot
  dhtStateMs = 0;
  dht.begin();

  Wire.begin(); Wire.setTimeOut(50);
  if (!display.begin(SSD1306_SWITCHCAPVCC, SCREEN_ADDRESS)) {
    DBG_PRINTLN("SSD1306 failed");
  } else {
    display.clearDisplay(); display.setTextColor(SSD1306_WHITE);
    display.setTextSize(1); display.setCursor(0,0);
    display.println("Smart AC MQTT"); display.setCursor(0,16);
    display.println("Starting..."); display.display();
  }

  irrecv.setUnknownThreshold(12); irrecv.enableIRIn();
  ac.begin(); ac.setModel(lg_ac_remote_model_t::AKB74955603);
  runBlasterSelfTest();

  xTaskCreatePinnedToCore(networkTask,"NetworkTask",32768,NULL,1,NULL,0);

  DBG_PRINTLN("===================================================");
  DBG_PRINTLN("Smart AC MQTT Online - Full Dual-Core Architecture");
  DBG_PRINTLN("===================================================");
}

// =====================================================================
// MAIN LOOP (Core 1 - Hardware ONLY)
// =====================================================================
void loop() {
  rtcLastSessionDurationSec = millis() / 1000;

  // IR self-test timeout
  if (awaitingLoopback && millis() > loopbackDeadline) {
    awaitingLoopback = false; irBlasterSelfTestOk = false;
  }

  // 1. Physical remote IR
  checkIrReceiver();

  // 2. App commands from MQTT (delivered by Core 0 via queue)
  AppCommandEvent cmd;
  if (xQueueReceive(qAppCmd, &cmd, 0) == pdTRUE) {
    if (cmd.hasClimate) {
      bool prevAc = acOn;
      lastAcTriggerSource = SRC_APP;
      if (!acOn && cmd.acOn) {
        acOnStartMs = millis();
        acSessionStartMs = millis();
        acSessionStartEnergy = pzemEnergy;
        String aMsg = "❄️ <b>LG Smart AC: Turned ON</b>\n";
        aMsg += "📱 <b>Source</b>: Mobile App\n";
        aMsg += "🎯 <b>Target</b>: " + String(cmd.targetTemp) + "°C | <b>Mode</b>: " + String(cmd.mode) + " | <b>Fan</b>: " + String(cmd.fanSpeed) + "\n";
        aMsg += "🌡️ <b>Room</b>: " + String(roomTemp, 1) + "°C (Humidity: " + String(roomHumidity, 0) + "%)";
        enqueueTelegramAlert(aMsg);
      }
      else if (acOn && !cmd.acOn) {
        todayRunningMins += (millis()-acOnStartMs)/60000.0;
        unsigned long durSec = (millis() - acSessionStartMs) / 1000;
        double sKwh = (pzemEnergy >= acSessionStartEnergy) ? (pzemEnergy - acSessionStartEnergy) : 0.0;
        String oMsg = "⏹️ <b>LG Smart AC: Turned OFF</b>\n";
        oMsg += "📱 <b>Source</b>: Mobile App\n";
        oMsg += "⏱️ <b>Run Time</b>: " + String(durSec / 3600) + "h " + String((durSec % 3600) / 60) + "m\n";
        oMsg += "⚡ <b>Energy Used</b>: " + String(sKwh, 3) + " kWh\n";
        oMsg += "💰 <b>Estimated Cost</b>: ₹" + String(sKwh * kCostPerKwh, 2);
        enqueueTelegramAlert(oMsg);
      }
      acOn=cmd.acOn; mode=String(cmd.mode);
      targetTemp=cmd.targetTemp; fanSpeed=String(cmd.fanSpeed);
      sendClimateIr();
    }
    if (cmd.hasSwing) {
      swingMode=String(cmd.swingMode); swingPosition=cmd.swingPosition; sendSwingIr();
    }
    if (cmd.hasSleep) {
      sleepActive=cmd.sleepActive; sleepTimerHours=cmd.sleepTimerHours; sendSleepIr();
    }
    if (cmd.hasLight) { lightOn=cmd.lightOn; sendLightIr(); }
    if (cmd.hasMute)  { mute=cmd.mute; sendMuteIr(); }
    if (cmd.hasHc) {
      bool prevHc = hcMode;
      hcMode = cmd.hcMode;
      if (hcMode) {
        dcMode = false;
        if (!acOn) { acOn = true; acOnStartMs = millis(); }
        sendHcIr();
      } else if (prevHc && !cmd.hasClimate) {
        dcMode = false;
        sendClimateIr();
      }
    }
    if (cmd.hasDc) {
      bool prevDc = dcMode;
      dcMode = cmd.dcMode;
      if (dcMode) {
        hcMode = false;
        if (!acOn) { acOn = true; acOnStartMs = millis(); }
        sendDcIr();
      } else if (prevDc && !cmd.hasClimate) {
        hcMode = false;
        sendClimateIr();
      }
    }
    enqueueStatePublish();
  }

  // 3. Read PZEM every 2.5s
  if (millis()-lastPzemRead > pzemReadMs) { lastPzemRead=millis(); readPZEM(); }

  // 4. DHT22 power-cycle state machine
  dhtPowerCycle();

  // 5. Smart scheduler, Nightly Digest & Filter Alerts
  checkAndRunSchedule();
  checkNightlyDigest();
  checkFilterAlerts();

  // Grid Voltage Safety Check (15-min cooldown)
  if (pzemOnline && pzemVoltage > 50.0) {
    if ((pzemVoltage < 185.0 || pzemVoltage > 265.0) && (millis() - lastVoltageAlertMs > 900000)) {
      lastVoltageAlertMs = millis();
      String vMsg;
      if (pzemVoltage < 185.0) {
        vMsg = "⚠️ <b>Grid Voltage Alert: Low Voltage!</b>\n";
        vMsg += "⚡ Line Voltage: <b>" + String(pzemVoltage, 0) + "V</b> detected.\n";
        vMsg += "AC compressor may struggle or draw higher current (Normal: 200V–250V).";
      } else {
        vMsg = "⚠️ <b>Grid Voltage Alert: High Voltage Surge!</b>\n";
        vMsg += "⚡ Line Voltage: <b>" + String(pzemVoltage, 0) + "V</b> detected.\n";
        vMsg += "Voltage exceeds 265V! Dangerous surge detected.";
      }
      enqueueTelegramAlert(vMsg);
    }
  }

  // High Room Temperature Warning (30-min cooldown)
  if (dhtOnline && !acOn && roomTemp >= 35.0 && (millis() - lastTempAlertMs > 1800000)) {
    lastTempAlertMs = millis();
    String tMsg = "🔥 <b>High Room Temperature Warning</b>\n";
    tMsg += "🌡️ <b>" + String(roomTemp, 1) + "°C</b> detected in Living Room while AC is OFF.\n";
    tMsg += "Consider switching on the AC!";
    enqueueTelegramAlert(tMsg);
  }

  // 6. Midnight reset
  midnightReset();

  // 7. Update shared telemetry for Core 0
  if (xSemaphoreTake(dataMutex, pdMS_TO_TICKS(5)) == pdTRUE) {
    sharedData.roomTemp=roomTemp; sharedData.roomHumidity=roomHumidity;
    sharedData.pzemVoltage=pzemVoltage; sharedData.pzemCurrent=pzemCurrent;
    sharedData.pzemPower=pzemPower; sharedData.pzemEnergy=pzemEnergy;
    sharedData.pzemFrequency=pzemFrequency; sharedData.pzemPf=pzemPf;
    sharedData.dhtOnline=dhtOnline; sharedData.pzemOnline=pzemOnline;
    sharedData.wifiConnected=(WiFi.status()==WL_CONNECTED);
    sharedData.mqttConnected=mqttConnected;
    sharedData.internetOnline=internetOnline;
    sharedData.irBlasterOk=irBlasterSelfTestOk;
    sharedData.todayRunningMins=getTodayRunningMins();
    for(int i=0;i<24;i++) sharedData.hourlyEnergy[i]=hourlyEnergy[i];
    sharedData.uptimeSec=millis()/1000;
    xSemaphoreGive(dataMutex);
  }

  // 8. Button (5-screen OLED cycle)
  int reading = digitalRead(kButtonPin);
  if (reading != lastButtonState) lastDebounceTime=millis();
  if (millis()-lastDebounceTime > debounceDelay) {
    if (reading != buttonState) {
      buttonState=reading;
      if (buttonState==LOW) { currentScreen++; if(currentScreen>5) currentScreen=1; }
    }
  }
  lastButtonState=reading;

  // Auto-switch to power screen after 7s boot
  if (!autoSwitchedToPower && millis()>10000) { currentScreen=2; autoSwitchedToPower=true; }

  // 9. OLED at 4 FPS
  if (millis()-lastOledUpdate >= oledUpdateIntervalMs) {
    lastOledUpdate=millis(); updateOledDisplay();
  }

  vTaskDelay(pdMS_TO_TICKS(10));
}

// =====================================================================
// NETWORK TASK (Core 0 - MQTT + Firebase energy logs + weather)
// =====================================================================
void networkTask(void* pv) {
  // WiFi
  WiFi.mode(WIFI_STA); WiFi.setSleep(false);
  WiFi.setTxPower(WIFI_POWER_19_5dBm);
  WiFi.setAutoReconnect(true);
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  int att=0;
  while (WiFi.status()!=WL_CONNECTED && att<40) { vTaskDelay(pdMS_TO_TICKS(300)); att++; }
  DBG_PRINTLN(WiFi.status()==WL_CONNECTED ? "WiFi OK" : "WiFi FAIL");

  // NTP
  configTime(0, 0, "pool.ntp.org", "time.nist.gov");
  time_t ntpNow=time(nullptr); int ntpAtt=0;
  while (ntpNow<1700000000 && ntpAtt<50) { vTaskDelay(pdMS_TO_TICKS(100)); ntpNow=time(nullptr); ntpAtt++; }

  sessionBootTimeIso = getIso8601Timestamp();
  String today = getCurrentIstDateKey();

  if (!bootAlertSent) {
    bootAlertSent = true;
    esp_reset_reason_t rst = esp_reset_reason();
    String bMsg;
    if (rst == ESP_RST_POWERON) {
      bMsg = "⚡ <b>Smart AC: Power Restored</b>\n";
      bMsg += "🕒 <b>Boot Time</b>: " + getCurrentIstHHMM() + " IST\n";
      bMsg += "⚠️ <b>Cause</b>: System recovered from Power Cut / Voltage Sag\n";
      bMsg += "✅ Wi-Fi, MQTT & Sensors reconnected successfully.";
    } else {
      bMsg = "✅ <b>Smart AC Online</b>\n";
      bMsg += "🕒 <b>Boot Time</b>: " + getCurrentIstHHMM() + " IST\n";
      bMsg += "📶 <b>Wi-Fi</b>: Connected (" + String(WiFi.RSSI()) + " dBm)\n";
      bMsg += "ℹ️ <b>Boot Reason</b>: " + currentBootReason;
    }
    enqueueTelegramAlert(bMsg);
  }
  if (strcmp(rtcLastBootDate, today.c_str())!=0) {
    rtcTodayRebootCount=1;
    strncpy(rtcLastBootDate, today.c_str(), sizeof(rtcLastBootDate));
  }

  // MQTT TLS setup
  mqttTlsClient.setInsecure(); // EMQX Cloud uses trusted CA; setInsecure skips cert pinning
  mqttClient.setServer(MQTT_BROKER, MQTT_PORT);
  mqttClient.setCallback(mqttCallback);
  mqttClient.setKeepAlive(30);
  mqttClient.setSocketTimeout(15);
  mqttClient.setBufferSize(2048);

  // Firebase (energy logs only)
  fbConfig.api_key = API_KEY;
  fbConfig.token_status_callback = customTokenStatusCallback;
  fbAuth.user.email = FIREBASE_AUTH_EMAIL;
  fbAuth.user.password = FIREBASE_AUTH_PASSWORD;
  fbdo.setBSSLBufferSize(2048, 1024); fbdo.setResponseSize(2048);
  fbConfig.timeout.socketConnection = 2500;
  fbConfig.timeout.serverResponse = 3000;
  Firebase.begin(&fbConfig, &fbAuth);
  Firebase.reconnectNetwork(false);

  // Wait for Firebase token (max 15s)
  unsigned long fbWait = millis();
  while (!Firebase.ready() && millis()-fbWait<15000) vTaskDelay(pdMS_TO_TICKS(100));

  // Bootstrap
  if (Firebase.ready()) {
    bootstrapStateFromFirestore();
    if (!haveScheduleState) netReadSchedule();
  }
  netFetchOutdoorTemp();

  // Initial MQTT connect
  if (!mqttReconnect()) {
    vTaskDelay(pdMS_TO_TICKS(3000));
    mqttReconnect();
  }

  unsigned long lastTelemetryMs = 0, lastEnergyLogMs = 0;
  unsigned long lastScheduleMs  = 0, lastWeatherMs   = 0;
  unsigned long lastMqttRetryMs = 0, lastWifiRetryMs = 0;

  while (true) {
    // WiFi recovery
    if (WiFi.status()!=WL_CONNECTED) {
      mqttConnected=false;
      if (millis()-lastWifiRetryMs>5000) {
        lastWifiRetryMs=millis(); WiFi.disconnect(); WiFi.begin(WIFI_SSID,WIFI_PASSWORD);
      }
      vTaskDelay(pdMS_TO_TICKS(200)); continue;
    }

    // MQTT reconnect
    if (!mqttClient.connected()) {
      mqttConnected=false;
      if (millis()-lastMqttRetryMs>5000) {
        lastMqttRetryMs=millis(); if(mqttReconnect()) mqttConnected=true;
      }
    } else { mqttConnected=true; }

    mqttClient.loop(); // handle incoming messages

    // Core 1 signaled a state change — publish immediately
    uint8_t sig;
    AppStateEvent evt;
      if (xQueueReceive(qStatePub, &evt, 0) == pdTRUE) {
        publishState(evt);
        netSaveStateToFirestore(evt);
      }

    // Telegram queue processing (non-blocking)
    TelegramMsg tMsg;
    if (xQueueReceive(qTelegramMsg, &tMsg, 0) == pdTRUE) {
      if (WiFi.status() == WL_CONNECTED) {
        sendTelegramHttp(tMsg.text);
      }
    }

    // Telemetry every 4s (ultra-responsive live power monitoring)
    if (millis()-lastTelemetryMs>4000) { lastTelemetryMs=millis(); publishTelemetry(); }

    // Energy log every 10 min
    if (Firebase.ready() && millis()-lastEnergyLogMs>600000) { lastEnergyLogMs=millis(); netWriteDailyEnergyLog(); }

    // Schedule is managed autonomously via MQTT + onboard NVS Flash (no periodic polling needed)

    // Outdoor weather every 15min
    if (millis()-lastWeatherMs>900000) { lastWeatherMs=millis(); netFetchOutdoorTemp(); }

      // Print free stack every 30s for debugging
      static unsigned long lastStackPrint=0;
      if(millis()-lastStackPrint>30000){lastStackPrint=millis(); DBG_PRINTF("Network stack free: %d bytes\n", uxTaskGetStackHighWaterMark(NULL)*4);}
      vTaskDelay(pdMS_TO_TICKS(25));
  }
}

// =====================================================================
// MQTT RECONNECT
// =====================================================================
bool mqttReconnect() {
  DBG_PRINT("MQTT connect... ");
  bool ok = mqttClient.connect(MQTT_CLIENT_ID, MQTT_USER, MQTT_PASS,
                               TOPIC_STATUS, 1, true, "offline");
  if (ok) {
    mqttClient.subscribe(TOPIC_CMD, 1);
    mqttClient.publish(TOPIC_STATUS, "online", true);
    DBG_PRINTLN("OK");
    // Immediately publish current state on reconnect
      enqueueStatePublish();
  } else {
    DBG_PRINTF("FAIL rc=%d\n", mqttClient.state());
  }
  return ok;
}

// =====================================================================
// MQTT CALLBACK — App command arrives here (Core 0 context)
// =====================================================================
void mqttCallback(char* topic, byte* payload, unsigned int length) {
  if (length > 1024 || length == 0) return;
  if (String(topic) != TOPIC_CMD) return;

  StaticJsonDocument<512> doc;
  if (deserializeJson(doc, payload, length)) { DBG_PRINTLN("JSON err"); return; }

  if (doc.containsKey("cmd")) {
    const char* c = doc["cmd"];
    if (c && strcmp(c, "refresh") == 0) {
      publishTelemetry();
      enqueueStatePublish();
      DBG_PRINTLN("Force refresh triggered via MQTT");
      return;
    }
  }

  if (doc.containsKey("filter")) {
    JsonObject fObj = doc["filter"];
    const char* action = fObj["action"];
    if (action && strcmp(action, "reset") == 0) {
      int interval = fObj["intervalDays"] | 30;
      time_t nNow = time(nullptr);
      if (nNow < 1700000000) nNow = 1725800000;
      saveFilterToNvs((uint32_t)nNow, (uint16_t)interval);
      String fMsg = "✅ <b>Filter Reset Confirmed!</b>\n";
      fMsg += "🧹 AC air filter timer has been reset.\n";
      fMsg += "📅 <b>Reset Date</b>: " + getCurrentIstDateKey() + "\n";
      fMsg += "⏳ <b>Next Cleaning Due</b>: In " + String(interval) + " days";
      enqueueTelegramAlert(fMsg);
      DBG_PRINTLN("Filter reset confirmed & saved to Flash");
      return;
    }
  }

  AppCommandEvent cmd = {};
  bool hasCli = doc.containsKey("acOn")||doc.containsKey("targetTemp")||
                doc.containsKey("fanSpeed")||doc.containsKey("currentMode");
  if (hasCli) {
    // SAFE: Only read from JSON. Never read Core 1 globals here (race condition = crash!)
    cmd.hasClimate=true;
    cmd.acOn       = doc["acOn"].as<bool>();
    cmd.targetTemp = doc["targetTemp"].as<int>();
    const char* nm = doc["currentMode"]; if (nm) strncpy(cmd.mode,    nm, sizeof(cmd.mode)-1);
    const char* nf = doc["fanSpeed"];    if (nf) strncpy(cmd.fanSpeed, nf, sizeof(cmd.fanSpeed)-1);
  }
  if (doc.containsKey("swingMode")||doc.containsKey("swingPosition")) {
    cmd.hasSwing=true;
    cmd.swingPosition = doc["swingPosition"].as<int>();
    const char* ns = doc["swingMode"]; if (ns) strncpy(cmd.swingMode, ns, sizeof(cmd.swingMode)-1);
  }
  if (doc.containsKey("sleepActive")||doc.containsKey("sleepTimerHours")) {
    cmd.hasSleep=true;
    cmd.sleepActive     = doc["sleepActive"].as<bool>();
    cmd.sleepTimerHours = doc["sleepTimerHours"].as<int>();
  }
  if (doc.containsKey("lightOn")) { cmd.hasLight=true; cmd.lightOn=doc["lightOn"].as<bool>(); }
  if (doc.containsKey("mute"))    { cmd.hasMute=true;  cmd.mute=doc["mute"].as<bool>(); }
  if (doc.containsKey("hcMode"))  { cmd.hasHc=true;    cmd.hcMode=doc["hcMode"].as<bool>(); }
  if (doc.containsKey("dcMode"))  { cmd.hasDc=true;    cmd.dcMode=doc["dcMode"].as<bool>(); }

  if (doc.containsKey("schedule")) {
    JsonObject sched = doc["schedule"];
    bool onEn = sched["onEnabled"].as<bool>();
    const char* onT = sched["onTime"];
    bool offEn = sched["offEnabled"].as<bool>();
    const char* offT = sched["offTime"];
    if (xSemaphoreTake(schedMutex, pdMS_TO_TICKS(10)) == pdTRUE) {
      schedOnEnabled = onEn;
      schedOffEnabled = offEn;
      if (onT) strncpy(schedOnTime, onT, sizeof(schedOnTime)-1);
      if (offT) strncpy(schedOffTime, offT, sizeof(schedOffTime)-1);
      haveScheduleState = true;
      xSemaphoreGive(schedMutex);
    }
    saveScheduleToNvs(onEn, onT, offEn, offT);
    DBG_PRINTLN("Schedule updated via MQTT & saved to Flash");
  }

  xQueueSend(qAppCmd, &cmd, 0);
  DBG_PRINTLN("CMD received via MQTT");
}

// =====================================================================
// PUBLISH STATE (called by Core 0 whenever state changes)
// =====================================================================
void publishState(AppStateEvent& evt) {
  if (!mqttClient.connected()) return;
  StaticJsonDocument<512> doc;
  doc["acOn"]=evt.acOn; doc["currentMode"]=evt.mode; doc["targetTemp"]=evt.targetTemp;
  doc["fanSpeed"]=evt.fanSpeed; doc["swingMode"]=evt.swingMode; doc["swingPosition"]=evt.swingPosition;
  doc["sleepActive"]=evt.sleepActive; doc["sleepTimerHours"]=evt.sleepTimerHours;
  doc["lightOn"]=evt.lightOn; doc["mute"]=evt.mute; doc["hcMode"]=evt.hcMode; doc["dcMode"]=evt.dcMode;
  doc["ts"]=getIso8601Timestamp();
  char buf[512]; serializeJson(doc,buf,sizeof(buf));
  mqttClient.publish(TOPIC_STATE, buf, true); // retained
  DBG_PRINTLN("State published");
}

// =====================================================================
// PUBLISH TELEMETRY (every 12s — sensor + diagnostics)
// =====================================================================
void publishTelemetry() {
  if (!mqttClient.connected()) return;
  SharedTelemetry snap;
  if (xSemaphoreTake(dataMutex,pdMS_TO_TICKS(50))==pdTRUE) { snap=sharedData; xSemaphoreGive(dataMutex); } else return;

  StaticJsonDocument<768> doc;
  doc["temperature"]=snap.roomTemp; doc["humidity"]=snap.roomHumidity;
  doc["powerWatts"]=snap.pzemPower; doc["voltage"]=snap.pzemVoltage;
  doc["current"]=snap.pzemCurrent; doc["frequency"]=snap.pzemFrequency;
  doc["powerFactor"]=snap.pzemPf; doc["todayEnergyKwh"]=snap.pzemEnergy;
  doc["todayRunningMinutes"]=snap.todayRunningMins;
  doc["estimatedCostToday"]=snap.pzemEnergy*kCostPerKwh;
  doc["systemUptimeSeconds"]=snap.uptimeSec;
  doc["wifiOnline"]=snap.wifiConnected; doc["mqttOnline"]=snap.mqttConnected;
  doc["esp32Online"]=true; doc["tempSensorOnline"]=snap.dhtOnline;
  doc["humiditySensorOnline"]=snap.dhtOnline;
  doc["energyMeterOnline"]=snap.pzemOnline;
  doc["irBlasterOnline"]=snap.irBlasterOk;
  doc["internetOnline"]=snap.internetOnline;
  doc["outdoorTemp"]=outdoorTemp; doc["outdoorTempValid"]=outdoorTempValid;
  doc["sessionBootTime"]=sessionBootTimeIso; doc["bootReason"]=currentBootReason;
  doc["lastSessionUptimeSeconds"]=(double)rtcLastSessionDurationSec;
  doc["lastResetReason"]=String(rtcLastResetReason);
  doc["rebootCountToday"]=(int)rtcTodayRebootCount;
  doc["freeHeapKb"]=(int)(ESP.getFreeHeap()/1024);
  doc["minFreeHeapKb"]=(int)(ESP.getMinFreeHeap()/1024);
  doc["ts"]=getIso8601Timestamp();
  char buf[768]; serializeJson(doc,buf,sizeof(buf));
  mqttClient.publish(TOPIC_TELEMETRY, buf, false);
}

// =====================================================================
// IR RECEIVER — Physical remote → state + MQTT publish
// =====================================================================
void checkIrReceiver() {
  if (!irrecv.decode(&results)) return;

  if (awaitingLoopback) {
    awaitingLoopback=false; irBlasterSelfTestOk=true; irrecv.resume(); return;
  }
  if (results.decode_type!=decode_type_t::LG2 &&
      results.decode_type!=decode_type_t::LG &&
      results.bits!=28) { irrecv.resume(); return; }

  uint32_t rawCode = (uint32_t)results.value;
  DBG_PRINTF("IR raw: 0x%08X\n", rawCode);

  // Sleep
  int sh = matchSleepCode(rawCode);
  if (sh>=0) { handleSleepFrame(sh); irrecv.resume(); enqueueStatePublish(); return; }

  // Light
  if (rawCode==0x88C00A6) { lightOn=!lightOn; irrecv.resume(); enqueueStatePublish(); return; }
  // Mute
  if (rawCode==0x88C0758) { mute=!mute; irrecv.resume(); enqueueStatePublish(); return; }
  // HC
  if (rawCode==0x88100DE) { hcMode=true; dcMode=false; irrecv.resume(); enqueueStatePublish(); return; }
  // DC
  if (rawCode==0x88101F1) { dcMode=true; hcMode=false; irrecv.resume(); enqueueStatePublish(); return; }

  if (isSwingCode(rawCode)) handleSwingFrame(rawCode);
  else handleClimateFrame();

  irrecv.resume();
  enqueueStatePublish();
}

bool isSwingCode(uint32_t code) {
  if (code==kSwingAutoCode||code==kSwingOffCode) return true;
  for (int i=0;i<6;i++) if(code==kSwingCode[i]) return true;
  return false;
}

int matchSleepCode(uint32_t raw) {
  for (int h=0;h<=7;h++) if(raw==kSleepCode[h]) return h;
  return -1;
}

void handleSleepFrame(int hours) {
  sleepActive=(hours>0); sleepTimerHours=hours;
}

void handleClimateFrame() {
  String desc = IRAcUtils::resultAcToString(&results);
  if (desc.length()==0) return;

  bool na=acOn; String nm=mode; int nt=targetTemp; String nf=fanSpeed;
  int s=0;
  while (s<(int)desc.length()) {
    int c=desc.indexOf(',',s);
    String tok=(c==-1)?desc.substring(s):desc.substring(s,c);
    s=(c==-1)?desc.length():(c+1); tok.trim();
    if (tok.startsWith("Power:"))      na=(tok.indexOf("On")!=-1);
    else if (tok.startsWith("Mode:"))  nm=lgModeWordToLabel(extractParenthesized(tok));
    else if (tok.startsWith("Temp:")) {
      String v=tok.substring(tok.indexOf(':')+1); v.trim(); v.replace("C",""); v.trim(); nt=v.toInt();
    }
    else if (tok.startsWith("Fan:"))   nf=lgFanWordToLabel(extractParenthesized(tok));
  }

  bool changed=!haveClimateState||na!=acOn||nm!=mode||(na&&nt!=targetTemp)||nf!=fanSpeed||hcMode||dcMode;
  if (!changed) return;

  if (!acOn&&na) {
    acOnStartMs=millis();
    acSessionStartMs = millis();
    acSessionStartEnergy = pzemEnergy;
    lastAcTriggerSource = SRC_REMOTE;
    String rMsg = "❄️ <b>LG Smart AC: Turned ON</b>\n";
    rMsg += "🎮 <b>Source</b>: Physical IR Remote\n";
    rMsg += "🎯 <b>Target</b>: " + String(nt) + "°C | <b>Mode</b>: " + nm + " | <b>Fan</b>: " + nf + "\n";
    rMsg += "🌡️ <b>Room</b>: " + String(roomTemp, 1) + "°C (Humidity: " + String(roomHumidity, 0) + "%)";
    enqueueTelegramAlert(rMsg);
  }
  else if (acOn&&!na) {
    todayRunningMins+=(millis()-acOnStartMs)/60000.0;
    unsigned long durSec = (millis() - acSessionStartMs) / 1000;
    double sKwh = (pzemEnergy >= acSessionStartEnergy) ? (pzemEnergy - acSessionStartEnergy) : 0.0;
    String roMsg = "⏹️ <b>LG Smart AC: Turned OFF</b>\n";
    roMsg += "🎮 <b>Source</b>: Physical IR Remote\n";
    roMsg += "⏱️ <b>Run Time</b>: " + String(durSec / 3600) + "h " + String((durSec % 3600) / 60) + "m\n";
    roMsg += "⚡ <b>Energy Used</b>: " + String(sKwh, 3) + " kWh\n";
    roMsg += "💰 <b>Estimated Cost</b>: ₹" + String(sKwh * kCostPerKwh, 2);
    enqueueTelegramAlert(roMsg);
  }
  acOn=na; mode=nm; if(na) targetTemp=nt; fanSpeed=nf;
  haveClimateState=true; hcMode=false; dcMode=false;
}

void handleSwingFrame(uint64_t code) {
  if (code==kSwingAutoCode)     { swingMode="auto"; swingPosition=0; }
  else if (code==kSwingOffCode) { swingMode="off";  swingPosition=0; }
  else {
    for (int i=0;i<6;i++) if(code==kSwingCode[i]) { swingMode="fixed"; swingPosition=i+1; break; }
  }
}

String lgModeWordToLabel(const String& w) {
  if (w=="Dry"||w=="DRY") return "Dry";
  if (w=="Fan"||w=="FAN") return "Fan";
  return "Cool";
}

String lgFanWordToLabel(const String& w) {
  if (w=="Auto"||w=="AUTO")   return "Auto";
  if (w=="Quiet")             return "F1";
  if (w=="Low"||w=="LOW")     return "F2";
  if (w=="Medium"||w=="MED")  return "F3";
  if (w=="High"||w=="HIGH")   return "F4";
  if (w=="Maximum"||w=="MAX") return "F5";
  return "Auto";
}

String extractParenthesized(const String& t) {
  int a=t.indexOf('('), b=t.indexOf(')');
  if (a==-1||b==-1||b<=a) return "";
  return t.substring(a+1,b);
}

// =====================================================================
// IR BLASTER — Exact same IR codes as original
// =====================================================================
void sendClimateIr() {
  ac.stateReset();
  ac.setModel(lg_ac_remote_model_t::AKB74955603);
  ac.setPower(acOn);
  if (acOn) {
    ac.setMode(mode=="Dry"?kLgAcDry:(mode=="Fan"?kLgAcFan:kLgAcCool));
    ac.setTemp(targetTemp);
    uint8_t fv;
    if      (fanSpeed=="F1") fv=kLgAcFanLowest;
    else if (fanSpeed=="F2") fv=kLgAcFanLowAlt;
    else if (fanSpeed=="F3") fv=kLgAcFanMedium;
    else if (fanSpeed=="F4") fv=kLgAcFanHigh;
    else if (fanSpeed=="F5") fv=kLgAcFanMax;
    else                     fv=kLgAcFanAuto;
    ac.setFan(fv);
  }
  ac.send();
  irrecv.resume();
}

void sendSwingIr() {
  if      (swingMode=="off")   irsend.sendLG2(kSwingOffCode,kSwingBits);
  else if (swingMode=="auto")  irsend.sendLG2(kSwingAutoCode,kSwingBits);
  else if (swingMode=="fixed"&&swingPosition>=1&&swingPosition<=6)
    irsend.sendLG2(kSwingCode[swingPosition-1],kSwingBits);
  irrecv.resume();
}

void sendSleepIr() {
  int h=sleepActive?sleepTimerHours:0;
  if (h<0||h>7) return;
  irsend.sendLG2(kSleepCode[h],kSleepBits);
  irrecv.resume();
}

void sendLightIr() { irsend.sendLG2(0x88C00A6,28); irrecv.resume(); }
void sendMuteIr()  { irsend.sendLG2(0x88C0758,28); irrecv.resume(); }
void sendHcIr()    { irsend.sendLG2(0x88100DE,28); irrecv.resume(); }
void sendDcIr()    { irsend.sendLG2(0x88101F1,28); irrecv.resume(); }

void runBlasterSelfTest() {
  uint16_t testPattern[] = {
    9000,4500,560,560,560,560,560,1690,
    560,560,560,1690,560,560,560,1690,
    560,560,560,560
  };
  irsend.sendRaw(testPattern,20,38);
  awaitingLoopback=true; loopbackDeadline=millis()+loopbackWindowMs;
}

// =====================================================================
// SENSORS
// =====================================================================
void readPZEM() {
  int maxFlush=128;
  while (Serial2.available()&&maxFlush-->0) Serial2.read();
  float v=pzem.voltage(),c=pzem.current(),p=pzem.power();
  float e=pzem.energy(),f=pzem.frequency(),pf=pzem.pf();
  if (!isnan(v)&&!isnan(c)&&v>50.0) {
    pzemVoltage=(v>kVoltageOffset)?(v-kVoltageOffset):v;
    pzemCurrent=c; pzemPower=isnan(p)?0:p;
    if (!isnan(e)&&e>=0) {
      if (dayStartEnergyBase<0) dayStartEnergyBase=e;
      float diff=e-dayStartEnergyBase; pzemEnergy=(diff>=0)?diff:0.0;
    }
    pzemFrequency=isnan(f)?0:f; pzemPf=isnan(pf)?0:pf;
    pzemOnline=true; pzemFailCount=0;
    time_t now=time(nullptr); time_t ist=now+kIstOffsetSeconds;
    struct tm ti; gmtime_r(&ist,&ti); int curH=ti.tm_hour;
    if (curH!=currentHourTracked) { currentHourTracked=curH; lastHourEnergyBase=pzemEnergy; }
    float diff=pzemEnergy-lastHourEnergyBase; if(diff>=0) hourlyEnergy[curH]=diff;
  } else {
    pzemFailCount++;
    if (pzemFailCount>=2) { pzemOnline=false; pzemVoltage=0;pzemCurrent=0;pzemPower=0;pzemFrequency=0;pzemPf=0; }
    if (pzemFailCount>=4) {
      Serial2.end(); delay(30); Serial2.begin(9600,SERIAL_8N1,PZEM_RX_PIN,PZEM_TX_PIN);
      int mf=128; while(Serial2.available()&&mf-->0) Serial2.read();
      pzemFailCount=0;
    }
  }
}

void dhtPowerCycle() {
  switch (dhtState) {
    case DHT_OFF:
      if (millis()-lastDhtCycle>=DHT_CYCLE_MS) {
        digitalWrite(DHT_POWER_PIN,HIGH); dhtState=DHT_WARMING; dhtStateMs=millis();
      }
      break;
    case DHT_WARMING:
      if (millis()-dhtStateMs>=DHT_WARMUP_MS) dhtState=DHT_READY;
      break;
    case DHT_READY: {
      float t=dht.readTemperature(), h=dht.readHumidity();
      if (!isnan(t)&&!isnan(h)&&t>-40&&t<80&&h>=0&&h<=100) {
        roomTemp=t; roomHumidity=h; dhtOnline=true; dhtFailCount=0;
      } else { dhtFailCount++; if(dhtFailCount>=3) dhtOnline=false; }
      digitalWrite(DHT_POWER_PIN,LOW); dhtState=DHT_OFF; lastDhtCycle=millis();
      break;
    }
  }
}

// =====================================================================
// 5-SCREEN OLED  (identical layout to original)
// =====================================================================
// Helper to push state from Core 1 to Core 0 safely
void enqueueStatePublish() {
  AppStateEvent evt;
  evt.acOn = acOn; evt.targetTemp = targetTemp; evt.swingPosition = swingPosition;
  evt.sleepActive = sleepActive; evt.sleepTimerHours = sleepTimerHours;
  evt.lightOn = lightOn; evt.mute = mute; evt.hcMode = hcMode; evt.dcMode = dcMode;
  strncpy(evt.mode, mode.c_str(), 7); evt.mode[7]=0;
  strncpy(evt.fanSpeed, fanSpeed.c_str(), 7); evt.fanSpeed[7]=0;
  strncpy(evt.swingMode, swingMode.c_str(), 7); evt.swingMode[7]=0;
  xQueueSend(qStatePub, &evt, 0);
}

void updateOledDisplay() {
  display.clearDisplay(); display.setTextColor(SSD1306_WHITE);
  switch (currentScreen) {
    case 1: // Status
      display.setTextSize(1); display.setCursor(0,0); display.print("--- SYSTEM STATUS ---");
      display.setCursor(0,14); display.print("WiFi    : "); display.println(WiFi.status()==WL_CONNECTED?"CONNECTED":"DISCONNECTED");
      display.setCursor(0,26); display.print("MQTT    : "); display.println(mqttConnected?"ONLINE":"WAITING");
      display.setCursor(0,38); display.print("PZEM    : "); display.println(pzemOnline?"ONLINE":"OFFLINE");
      display.setCursor(0,50); display.print("DHT22   : "); display.println(dhtOnline?"ONLINE":"OFFLINE");
      break;
    case 2: { // Power (auto-rotates voltage/current vs power/energy)
      int sub=(millis()/5000)%2;
      if (sub==0) {
        display.setTextSize(1); display.setCursor(0,2); display.print("VOLTAGE");
        display.setTextSize(2); display.setCursor(0,14); display.print(pzemVoltage,1); display.print(" V");
        display.setTextSize(1); display.setCursor(0,36); display.print("CURRENT");
        display.setTextSize(2); display.setCursor(0,48); display.print(pzemCurrent,2); display.print(" A");
      } else {
        display.setTextSize(1); display.setCursor(0,2); display.print("ACTIVE POWER");
        display.setTextSize(2); display.setCursor(0,14); display.print(pzemPower,0); display.print(" W");
        display.setTextSize(1); display.setCursor(0,36); display.print("TODAY ENERGY");
        display.setTextSize(2); display.setCursor(0,48); display.print(pzemEnergy,2); display.print(" kWh");
      }
      break;
    }
    case 3: // Temperature
      display.setTextSize(1); display.setCursor(0,0); display.print("--- TEMPERATURE ---");
      display.setCursor(0,14); display.print("Set Temp : "); display.print(targetTemp); display.print((char)247); display.print("C");
      display.setCursor(0,26); display.print("Room Temp: "); display.print(roomTemp,1); display.print((char)247); display.print("C");
      display.setCursor(0,38); display.print("Humidity : "); display.print(roomHumidity,0); display.print("%");
      display.setCursor(0,50); display.print("Outdoor  : ");
      if (outdoorTempValid) { display.print(outdoorTemp,1); display.print((char)247); display.print("C"); }
      else display.print("--.- C");
      break;
    case 4: // AC Controls
      display.setTextSize(1); display.setCursor(0,0); display.print("--- AC CONTROLS ---");
      display.setCursor(0,14); display.print("Power : "); display.println(acOn?"ON":"OFF");
      display.setCursor(0,26); display.print("Mode  : "); display.println(mode);
      display.setCursor(0,38); display.print("Fan   : "); display.println(fanSpeed);
      display.setCursor(0,50); display.print("Swing : ");
      if (swingMode=="fixed") { display.print("Fixed ("); display.print(swingPosition); display.print(")"); }
      else display.println(swingMode);
      if (hcMode) { display.setCursor(96,14); display.print("[HC]"); }
      if (dcMode) { display.setCursor(96,14); display.print("[dC]"); }
      break;
    case 5: // Diagnostics
      display.setTextSize(1); display.setCursor(0,0); display.print("--- DIAGNOSTICS ---");
      display.setCursor(0,14); display.print("FreeHeap: "); display.print(ESP.getFreeHeap()/1024); display.println(" KB");
      display.setCursor(0,26); display.print("Up Time : "); display.print(millis()/60000); display.println(" min");
      display.setCursor(0,38); display.print("Reboots : "); display.println(rtcTodayRebootCount);
      display.setCursor(0,50); display.print("Crash   : "); display.println(rtcLastResetReason);
      break;
  }
  display.display();
}

// =====================================================================
// MIDNIGHT RESET  (identical to original)
// =====================================================================
void midnightReset() {
  time_t now=time(nullptr); if(now<1700000000) return;
  String today=getCurrentIstDateKey();
  if (lastResetDate.length()==0||lastResetDate.startsWith("1970")) { lastResetDate=today; return; }
  if (today!=lastResetDate) {
    float raw=pzem.energy();
    dayStartEnergyBase=(!isnan(raw)&&raw>=0)?raw:-1.0;
    pzemEnergy=0; lastHourEnergyBase=0;
    for(int i=0;i<24;i++) hourlyEnergy[i]=0;
    todayRunningMins=0; if(acOn) acOnStartMs=millis();
    lastResetDate=today; rtcTodayRebootCount=0;
  }
}

float getTodayRunningMins() {
  float total=todayRunningMins;
  if (acOn&&acOnStartMs>0) total+=(millis()-acOnStartMs)/60000.0;
  rtcTodayRunningMins = total;
  return total;
}

// =====================================================================
// SMART SCHEDULER  (reads Firestore schedule, executes locally)
// =====================================================================
// =====================================================================
// NVS FLASH SCHEDULE PERSISTENCE
// =====================================================================
void saveScheduleToNvs(bool onEn, const char* onT, bool offEn, const char* offT) {
  Preferences p;
  if (p.begin("ac_sched", false)) {
    p.putBool("onEn", onEn);
    p.putString("onT", onT ? onT : "06:00");
    p.putBool("offEn", offEn);
    p.putString("offT", offT ? offT : "22:00");
    p.end();
    DBG_PRINTLN("Schedule permanently saved to NVS Flash.");
  }
}

void loadScheduleFromNvs() {
  Preferences p;
  if (p.begin("ac_sched", true)) {
    if (p.isKey("onEn")) {
      bool onEn = p.getBool("onEn", false);
      String ot = p.getString("onT", "06:00");
      bool offEn = p.getBool("offEn", false);
      String oft = p.getString("offT", "22:00");
      if (xSemaphoreTake(schedMutex, pdMS_TO_TICKS(10)) == pdTRUE) {
        schedOnEnabled = onEn;
        schedOffEnabled = offEn;
        strncpy(schedOnTime, ot.c_str(), sizeof(schedOnTime)-1);
        strncpy(schedOffTime, oft.c_str(), sizeof(schedOffTime)-1);
        haveScheduleState = true;
        xSemaphoreGive(schedMutex);
      }
      DBG_PRINTF("Loaded schedule from Flash: ON=%s (%d), OFF=%s (%d)\n", schedOnTime, schedOnEnabled, schedOffTime, schedOffEnabled);
    }
    p.end();
  }
}

void checkAndRunSchedule() {
  if (!haveScheduleState) return;
  time_t now = time(nullptr);
  if (now < 1700000000) return; // Wait until NTP has valid network time
  String nowHHMM=getCurrentIstHHMM(), todayKey=getCurrentIstDateKey();
  
  String onT, offT; bool onEn, offEn;
  if (xSemaphoreTake(schedMutex,pdMS_TO_TICKS(5))==pdTRUE) {
    onT=String(schedOnTime); offT=String(schedOffTime);
    onEn=schedOnEnabled; offEn=schedOffEnabled;
    xSemaphoreGive(schedMutex);
  } else return;

  if (onEn&&onT.length()>0&&nowHHMM==onT) {
    String key=todayKey+" "+nowHHMM+"-ON";
    if (key!=lastScheduleTriggerKey) {
      lastScheduleTriggerKey=key;
      if (!acOn) {
        acOn=true;
        acOnStartMs=millis();
        acSessionStartMs = millis();
        acSessionStartEnergy = pzemEnergy;
        lastAcTriggerSource = SRC_SCHEDULE;
        String sMsg = "❄️ <b>LG Smart AC: Turned ON</b>\n";
        sMsg += "⏰ <b>Source</b>: Smart Schedule\n";
        sMsg += "🌡️ <b>Target</b>: " + String(targetTemp) + "°C | <b>Mode</b>: " + mode + " | <b>Fan</b>: " + fanSpeed + "\n";
        sMsg += "🏠 <b>Room</b>: " + String(roomTemp, 1) + "°C (Humidity: " + String(roomHumidity, 0) + "%)";
        enqueueTelegramAlert(sMsg);
      }
      sendClimateIr();
      enqueueStatePublish();
    }
  }
  if (offEn&&offT.length()>0&&nowHHMM==offT) {
    String key=todayKey+" "+nowHHMM+"-OFF";
    if (key!=lastScheduleTriggerKey) {
      lastScheduleTriggerKey=key;
      if (acOn) {
        todayRunningMins+=(millis()-acOnStartMs)/60000.0;
        unsigned long durSec = (millis() - acSessionStartMs) / 1000;
        double sKwh = (pzemEnergy >= acSessionStartEnergy) ? (pzemEnergy - acSessionStartEnergy) : 0.0;
        String soMsg = "🛑 <b>LG Smart AC: Turned OFF</b>\n";
        soMsg += "⏰ <b>Source</b>: Smart Schedule\n";
        soMsg += "⏱️ <b>Run Time</b>: " + String(durSec / 3600) + "h " + String((durSec % 3600) / 60) + "m\n";
        soMsg += "⚡ <b>Energy Used</b>: " + String(sKwh, 3) + " kWh\n";
        soMsg += "💰 <b>Estimated Cost</b>: ₹" + String(sKwh * kCostPerKwh, 2);
        enqueueTelegramAlert(soMsg);
      }
      acOn=false; sendClimateIr();
      enqueueStatePublish();
    }
  }
}

// =====================================================================
// FIREBASE FUNCTIONS (Core 0 — energy logs + schedule + bootstrap)
// =====================================================================
// =====================================================================
// SAVE STATE TO FIRESTORE (called whenever state changes so reboot restores correctly)
// =====================================================================
void netSaveStateToFirestore(const AppStateEvent& snap) {
  if (!Firebase.ready()) return;
  static unsigned long lastSaveMs = 0;
  // 1s debounce to avoid spamming Firestore on quick successive taps
  if (millis() - lastSaveMs < 1000) return;
  lastSaveMs = millis();

  fbdo.clear();
  String dp = "devices/" + String(DEVICE_ID);
  FirebaseJson content;
  content.set("fields/acOn/booleanValue",            snap.acOn);
  content.set("fields/currentMode/stringValue",      String(snap.mode));
  content.set("fields/targetTemp/integerValue",      snap.targetTemp);
  content.set("fields/fanSpeed/stringValue",         String(snap.fanSpeed));
  content.set("fields/swingMode/stringValue",        String(snap.swingMode));
  content.set("fields/swingPosition/integerValue",   snap.swingPosition);
  content.set("fields/sleepActive/booleanValue",     snap.sleepActive);
  content.set("fields/sleepTimerHours/integerValue", snap.sleepTimerHours);
  content.set("fields/lightOn/booleanValue",         snap.lightOn);
  content.set("fields/mute/booleanValue",            snap.mute);
  content.set("fields/hcMode/booleanValue",          snap.hcMode);
  content.set("fields/dcMode/booleanValue",          snap.dcMode);
  content.set("fields/lastActiveDate/stringValue",   getCurrentIstDateKey());

    content.set("fields/todayRunningMinutes/doubleValue", (double)getTodayRunningMins());
  content.set("fields/todayEnergyKwh/doubleValue",       (double)pzemEnergy);
  content.set("fields/dayStartEnergyBase/doubleValue",   (double)dayStartEnergyBase);
  String mask = "acOn,currentMode,targetTemp,fanSpeed,swingMode,swingPosition,sleepActive,sleepTimerHours,lightOn,mute,hcMode,dcMode,todayRunningMinutes,todayEnergyKwh,dayStartEnergyBase,lastActiveDate";
  Firebase.Firestore.patchDocument(&fbdo, FIREBASE_PROJECT_ID, "", dp.c_str(), content.raw(), mask.c_str());
  fbdo.clear();
  DBG_PRINTLN("State saved to Firestore");
}

void bootstrapStateFromFirestore() {
  fbdo.clear();
  String dp="devices/"+String(DEVICE_ID);
  if (!Firebase.Firestore.getDocument(&fbdo,FIREBASE_PROJECT_ID,"",dp.c_str(),"")) {
    fbdo.clear(); return;
  }
  FirebaseJson json; json.setJsonData(fbdo.payload().c_str());
  FirebaseJsonData r;

  bool initAcOn=false; String initMode="Cool"; int initTemp=24; String initFan="Auto";
  String initSwing="off"; int initSwingPos=0; bool initSleep=false; int initSleepHrs=0;

  if (json.get(r,"fields/acOn/booleanValue"))            initAcOn=r.to<bool>();
  if (json.get(r,"fields/currentMode/stringValue"))       initMode=r.to<String>();
  if (json.get(r,"fields/targetTemp/integerValue"))       initTemp=r.to<int>();
  if (json.get(r,"fields/fanSpeed/stringValue"))          initFan=r.to<String>();
  if (json.get(r,"fields/swingMode/stringValue"))         initSwing=r.to<String>();
  if (json.get(r,"fields/swingPosition/integerValue"))    initSwingPos=r.to<int>();
  if (json.get(r,"fields/sleepActive/booleanValue"))      initSleep=r.to<bool>();
  if (json.get(r,"fields/sleepTimerHours/integerValue"))  initSleepHrs=r.to<int>();
  if (json.get(r,"fields/lightOn/booleanValue"))          lightOn=r.to<bool>();
  if (json.get(r,"fields/mute/booleanValue"))             mute=r.to<bool>();
  if (json.get(r,"fields/hcMode/booleanValue"))           hcMode=r.to<bool>();
  if (json.get(r,"fields/dcMode/booleanValue"))           dcMode=r.to<bool>();

  float restoredMins=0, restoredEnergy=0, restoredEnergyBase=-1.0;
  if (json.get(r,"fields/todayRunningMinutes/doubleValue"))  restoredMins=r.to<float>();
  else if (json.get(r,"fields/totalRunningMinutes/doubleValue")) restoredMins=r.to<float>();
  if (json.get(r,"fields/todayEnergyKwh/doubleValue"))       restoredEnergy=r.to<float>();
  if (json.get(r,"fields/dayStartEnergyBase/doubleValue"))   restoredEnergyBase=r.to<float>();

  String lastDate="";
  if (json.get(r,"fields/lastActiveDate/stringValue")) lastDate=r.to<String>();
  String today=getCurrentIstDateKey();

  if (lastDate.length()==0||lastDate==today||today.startsWith("1970")) {
    if (restoredMins > todayRunningMins) todayRunningMins = restoredMins;
    if (restoredEnergy > pzemEnergy) pzemEnergy = restoredEnergy;
    if (restoredEnergyBase >= 0 && dayStartEnergyBase < 0) dayStartEnergyBase = restoredEnergyBase;
    rtcTodayRunningMins = todayRunningMins;
    rtcPzemEnergy = pzemEnergy;
    rtcDayStartEnergyBase = dayStartEnergyBase;
  } else {
    todayRunningMins=0; pzemEnergy=0; dayStartEnergyBase=-1.0;
  }

  acOn=initAcOn; mode=initMode; targetTemp=initTemp; fanSpeed=initFan;
  swingMode=initSwing; swingPosition=initSwingPos;
  sleepActive=initSleep; sleepTimerHours=initSleepHrs;
  haveClimateState=true;
  if (acOn) acOnStartMs=millis();
  fbdo.clear();
  DBG_PRINTLN("Bootstrap done.");

  // Publish initial state to MQTT so app sees current state immediately
  enqueueStatePublish();
}

void netReadSchedule() {
  fbdo.clear();
  String dp="schedules/"+String(DEVICE_ID);
  if (!Firebase.Firestore.getDocument(&fbdo,FIREBASE_PROJECT_ID,"",dp.c_str(),"")) {
    fbdo.clear(); return;
  }
  FirebaseJson json; json.setJsonData(fbdo.payload().c_str());
  FirebaseJsonData r;
  bool onEn=false, offEn=false; String onT="", offT="";
  if (json.get(r,"fields/onEnabled/booleanValue"))  onEn=r.to<bool>();
  if (json.get(r,"fields/onTime/stringValue"))       onT=r.to<String>();
  if (json.get(r,"fields/offEnabled/booleanValue")) offEn=r.to<bool>();
  if (json.get(r,"fields/offTime/stringValue"))      offT=r.to<String>();
  if (xSemaphoreTake(schedMutex,pdMS_TO_TICKS(10))==pdTRUE) {
    schedOnEnabled=onEn; schedOffEnabled=offEn;
    strncpy(schedOnTime, onT.c_str(), sizeof(schedOnTime)-1);
    strncpy(schedOffTime,offT.c_str(),sizeof(schedOffTime)-1);
    haveScheduleState=true;
    xSemaphoreGive(schedMutex);
  }
  fbdo.clear();
}

void netFetchOutdoorTemp() {
  if (WiFi.status()!=WL_CONNECTED) return;
  WiFiClient client; HTTPClient http;
  String url="http://api.open-meteo.com/v1/forecast?latitude=13.1147&longitude=80.1069&current=temperature_2m";
  if (!http.begin(client,url)) return;
  http.setTimeout(3000);
  int code=http.GET();
  if (code==200) {
    String payload=http.getString();
    StaticJsonDocument<512> wDoc;
    DeserializationError err = deserializeJson(wDoc, payload);
    if (!err && wDoc.containsKey("current") && wDoc["current"].containsKey("temperature_2m")) {
      outdoorTemp=wDoc["current"]["temperature_2m"].as<float>();
      outdoorTempValid=true; internetOnline=true;
    }
  } else { internetOnline=false; }
  http.end(); client.stop();
}

void netWriteDailyEnergyLog() {
  SharedTelemetry snap;
  if (xSemaphoreTake(dataMutex,pdMS_TO_TICKS(100))==pdTRUE) { snap=sharedData; xSemaphoreGive(dataMutex); } else return;

  static float lastLoggedEnergy = -1.0;
  static float lastLoggedMins   = -1.0;
  static int   lastLoggedHour   = -1;
  String today=getCurrentIstDateKey();
  time_t now=time(nullptr), ist=now+kIstOffsetSeconds;
  struct tm ti; gmtime_r(&ist,&ti); int curH=ti.tm_hour;

  // Skip unnecessary Firestore TLS patches if energy and running time haven't changed
  if (fabs(snap.pzemEnergy - lastLoggedEnergy) < 0.005 &&
      fabs(snap.todayRunningMins - lastLoggedMins) < 1.0 &&
      curH == lastLoggedHour) {
    return;
  }
  lastLoggedEnergy = snap.pzemEnergy;
  lastLoggedMins   = snap.todayRunningMins;
  lastLoggedHour   = curH;

  fbdo.clear();
  char hf[8]; snprintf(hf,sizeof(hf),"h%02d",curH);

  FirebaseJson content;
  content.set("fields/deviceId/stringValue",DEVICE_ID);
  content.set("fields/date/stringValue",today);
  content.set("fields/year/integerValue", ti.tm_year+1900);
  content.set("fields/month/integerValue",ti.tm_mon+1);
  content.set("fields/day/integerValue",  ti.tm_mday);
  content.set("fields/weekday/integerValue",ti.tm_wday==0?7:ti.tm_wday);
  content.set("fields/totalKwh/doubleValue",(double)snap.pzemEnergy);
  content.set("fields/totalRunningMinutes/doubleValue",(double)snap.todayRunningMins);
  content.set("fields/estimatedCost/doubleValue",(double)(snap.pzemEnergy*kCostPerKwh));
  content.set(String("fields/")+hf+"/doubleValue",(double)snap.hourlyEnergy[curH]);
  content.set("fields/lastUpdated/timestampValue",getIso8601Timestamp());
  content.set("fields/lastActiveDate/stringValue",today);

  String docPath="energy_logs/"+String(DEVICE_ID)+"_"+today;
  String mask="deviceId,date,year,month,day,weekday,totalKwh,totalRunningMinutes,estimatedCost,lastUpdated,lastActiveDate,"+String(hf);
  Firebase.Firestore.patchDocument(&fbdo,FIREBASE_PROJECT_ID,"",docPath.c_str(),content.raw(),mask.c_str());
  fbdo.clear();
}

// =====================================================================
// TIME UTILITIES
// =====================================================================
String getIso8601Timestamp() {
  time_t now=time(nullptr); if(now<1700000000) return "1970-01-01T00:00:00Z";
  struct tm ti; gmtime_r(&now,&ti);
  char buf[25]; strftime(buf,sizeof(buf),"%Y-%m-%dT%H:%M:%SZ",&ti); return String(buf);
}

String getCurrentIstDateKey() {
  time_t now=time(nullptr), ist=now+kIstOffsetSeconds;
  struct tm ti; gmtime_r(&ist,&ti);
  char buf[11]; strftime(buf,sizeof(buf),"%Y-%m-%d",&ti); return String(buf);
}

String getCurrentIstHHMM() {
  time_t now=time(nullptr), ist=now+kIstOffsetSeconds;
  struct tm ti; gmtime_r(&ist,&ti);
  char buf[6]; strftime(buf,sizeof(buf),"%H:%M",&ti); return String(buf);
}


