# ❄️ Smart AC - Dual-Core ESP32 IoT Climate & Energy System

[![ESP32](https://img.shields.io/badge/Platform-ESP32%20Dual--Core-red.svg?logo=espressif)](https://www.espressif.com/)
[![Flutter](https://img.shields.io/badge/Mobile%20App-Flutter%203.x-blue.svg?logo=flutter)](https://flutter.dev/)
[![MQTT](https://img.shields.io/badge/Broker-EMQX%20Cloud%20TLS-emerald.svg?logo=mqtt)](https://www.emqx.com/)
[![Telegram](https://img.shields.io/badge/Alerts-Telegram%20Bot%20API-2CA5E0.svg?logo=telegram)](https://telegram.org/)
[![FreeRTOS](https://img.shields.io/badge/OS-FreeRTOS-orange.svg)](https://www.freertos.org/)
[![License](https://img.shields.io/badge/License-MIT-lightgrey.svg)](LICENSE)

An industrial-grade, full-stack IoT Smart Air Conditioner control, monitoring, and automation solution. Built with a **Dual-Core FreeRTOS ESP32 firmware**, an **EMQX Cloud MQTT TLS** messaging backbone, a cross-platform **Flutter mobile application**, and an automated **24/7 Cloud Telegram alert pipeline**.

---

## 📑 Table of Contents
- [Key Features](#-key-features)
- [Mobile Application Showcase](#-mobile-application-showcase)
- [Hardware Implementation & OLED Displays](#-hardware-implementation--oled-displays)
- [Real-World Demonstration Video](#-real-world-demonstration-video)
- [System Architecture](#-system-architecture)
- [Hardware Pinout & Wiring](#-hardware-pinout--wiring)
- [Dual-Core FreeRTOS Partitioning](#-dual-core-freertos-partitioning)
- [MQTT Topic Schema](#-mqtt-topic-schema)
- [24/7 Telegram Alert Engine](#-247-telegram-alert-engine)
- [Project Directory Structure](#-project-directory-structure)
- [Getting Started & Installation](#-getting-started--installation)
  - [1. ESP32 Firmware Setup](#1-esp32-firmware-setup)
  - [2. Flutter Mobile App Setup](#2-flutter-mobile-app-setup)
  - [3. EMQX Cloud & Telegram Webhook Rule Engine](#3-emqx-cloud--telegram-webhook-rule-engine)
- [Security & Credential Configuration](#-security--credential-configuration)
- [License](#-license)

---

## 🌟 Key Features

### 📡 Dual-Core ESP32 Firmware
- **Bi-Directional IR Loopback & Remote Sync**: Controls AC via 940nm IR transmitter and simultaneously decodes physical IR remote commands via IR receiver. Physical remote inputs instantly update cloud state.
- **Precision Energy Metering**: Modbus UART interface with PZEM-004T v3.0 measuring real-time Voltage (V), Current (A), Active Power (W), Energy (kWh), Frequency (Hz), and Power Factor (PF).
- **Anti-Drift DHT22 Climate Sensing**: Dynamic transistor-switched power gating to eliminate DHT22 sensor self-heating and lockups.
- **Non-Volatile Storage (NVS Flash)**: AC state, timer schedules, and air filter runtime are preserved across power cuts and reboot cycles.
- **SSD1306 0.96" OLED Multi-Screen Display**: Real-time display showing status, indoor climate, power consumption, and network health, with tactile push-button screen toggling.
- **Fail-Safe Self-Healing Watchdogs**: Auto-reconnect routines for WiFi dropouts, TLS socket stalls, and brownout hardware events.

### 📱 Flutter Mobile App
- **Real-Time Control**: Power, target temperature, operating modes (Cool, Dry, Fan, Auto), fan speeds (Auto, Min, Med, Max), and oscillation swing modes.
- **Live Telemetry & Diagnostics**: Voltage stability gauges, current load curves, and live power graphs.
- **Scheduler & Auto-Off Timers**: Granular weekly schedules and countdown sleep timers executed both in-app and on the ESP32 hardware level.
- **Energy Cost Analytics**: Real-time daily, weekly, and monthly kWh tracking with custom electricity tariff rates.
- **Light / Dark Theme Support**: Sleek, modern glassmorphic UI tailored for both iOS and Android.

### 🔔 Cloud-Native Telegram Alert System
- **24/7 Standalone Cloud Forwarding**: EMQX Cloud Rule Engine forwards MQTT messages directly to the official Telegram Bot API, ensuring alerts arrive even when your phone is locked or the app is closed.
- **Critical Brownout & Surge Protection**: Instant alerts if line voltage falls below 190V or surges above 250V.
- **Session Energy Summaries**: Detailed report on turn-off showing total run time and electricity consumed during the session.
- **Nightly Energy Digest**: Automated 10:00 PM summary reporting total AC operating hours, kWh consumed, and daily cost.

---


---

## 📱 Mobile Application Showcase

The Flutter mobile application provides an ultra-responsive, glassmorphic dark-mode dashboard with real-time state synchronization, live energy telemetry curves, and granular AC hardware control.

<div align="center">
  <table>
    <tr>
      <td align="center" width="20%">
        <img src="assets/screenshots/Dashboard_Screen.png" width="100%" alt="Dashboard Screen" /><br/>
        <b>🏠 Dashboard</b><br/>
        <sub>Live Climate, Temp Ring &amp; Wattage</sub>
      </td>
      <td align="center" width="20%">
        <img src="assets/screenshots/Remote_Screen.png" width="100%" alt="Remote Control Screen" /><br/>
        <b>🎮 Digital Remote</b><br/>
        <sub>AC Modes, Fan Speeds &amp; Vane Swing</sub>
      </td>
      <td align="center" width="20%">
        <img src="assets/screenshots/Energy_Screen.png" width="100%" alt="Energy Screen" /><br/>
        <b>⚡ Energy Analytics</b><br/>
        <sub>PZEM Voltage, Current &amp; Tariff Cost</sub>
      </td>
      <td align="center" width="20%">
        <img src="assets/screenshots/System_Screen.png" width="100%" alt="System Screen" /><br/>
        <b>🩺 Diagnostics</b><br/>
        <sub>ESP32 Health, Watchdogs &amp; Uptime</sub>
      </td>
      <td align="center" width="20%">
        <img src="assets/screenshots/Telegram_Notification.png" width="100%" alt="Telegram Alerts" /><br/>
        <b>🔔 24/7 Alerts</b><br/>
        <sub>Cloud Telegram Brownout &amp; Turn-Off Logs</sub>
      </td>
    </tr>
  </table>
</div>

---

## 🔌 Hardware Implementation & OLED Displays

The physical controller uses custom circuitry with transistor-isolated DHT22 power gating, high-speed 38kHz IR receiver decoding, PZEM-004T AC mains energy metering, and an SSD1306 0.96" I2C OLED multi-screen diagnostics display.

### ⚡ Circuitry & Transceiver Modules

<div align="center">
  <table>
    <tr>
      <td align="center" width="50%">
        <img src="assets/hardware/Circuit.png" width="100%" alt="Complete Hardware Circuit" /><br/>
        <b>⚡ Complete Dual-Core ESP32 IoT Circuit Setup</b><br/>
        <sub>ESP32 Dev Module, PZEM-004T v3.0, Gated DHT22 &amp; OLED Display</sub>
      </td>
      <td align="center" width="50%">
        <img src="assets/hardware/Ir_Blaster_Receiver.png" width="100%" alt="IR Blaster and Receiver Setup" /><br/>
        <b>📡 Bi-Directional IR Transceiver Hardware</b><br/>
        <sub>TSOP38238 38kHz Decoder &amp; 940nm Blaster Transistor Circuit</sub>
      </td>
    </tr>
  </table>
</div>

### 📺 SSD1306 0.96" OLED Multi-Screen Telemetry

Tactile push-button screen rotation allows reviewing live performance metrics directly at the device:

<div align="center">
  <table>
    <tr>
      <td align="center" width="33%">
        <img src="assets/hardware/Screen_1.png" width="100%" alt="OLED Screen 1" /><br/>
        <b>Screen 1 : Primary Climate</b><br/>
        <sub>Indoor Temp, Humidity &amp; Target Setpoint</sub>
      </td>
      <td align="center" width="33%">
        <img src="assets/hardware/Screen_2a.png" width="100%" alt="OLED Screen 2a" /><br/>
        <b>Screen 2 : Active Power Draw</b><br/>
        <sub>Real-time Wattage (W) &amp; Compressor Load</sub>
      </td>
      <td align="center" width="33%">
        <img src="assets/hardware/Screen_2b.png" width="100%" alt="OLED Screen 2b" /><br/>
        <b>Screen 2b : Grid Voltage &amp; Current</b><br/>
        <sub>True-RMS AC Voltage (V) &amp; Current (A)</sub>
      </td>
    </tr>
    <tr>
      <td align="center" width="33%">
        <img src="assets/hardware/Screen_3.png" width="100%" alt="OLED Screen 3" /><br/>
        <b>Screen 3 : Cumulative Energy</b><br/>
        <sub>Total Energy Consumed (kWh) &amp; Cost Tariff</sub>
      </td>
      <td align="center" width="33%">
        <img src="assets/hardware/Screen_4.png" width="100%" alt="OLED Screen 4" /><br/>
        <b>Screen 4 : Network Health</b><br/>
        <sub>WiFi RSSI, IP Address &amp; MQTT TLS Status</sub>
      </td>
      <td align="center" width="33%">
        <img src="assets/hardware/Screen_5.png" width="100%" alt="OLED Screen 5" /><br/>
        <b>Screen 5 : Filter &amp; Diagnostics</b><br/>
        <sub>Air Filter Health (NVS) &amp; Boot Reason</sub>
      </td>
    </tr>
  </table>
</div>

---

## 🎥 Real-World Demonstration Video

> 🎬 **Hardware Working Demonstration & Full Walkthrough**
> 
> A comprehensive real-world test and demonstration covering:
> 1. **Bi-Directional Sync**: Turning on AC from physical IR remote reflects instantly in the mobile app via 38kHz loopback decoding.
> 2. **Mobile Control**: Setting temperatures, cooling modes, fan speeds, and swing vanes from anywhere via EMQX TLS MQTT.
> 3. **Live Power Surge Response**: Monitoring instantaneous active power (W) and current (A) spikes as the compressor engages.
> 4. **Cloud Telegram Alerts**: Demonstrating automated 24/7 turn-off energy summaries and voltage brownout warnings.
> 
> 🔗 **Demo Video Link**: *[Click here to watch the HD Hardware Demo on Google Drive](#)* *(Video link will be updated here)*

---
## 🏛️ System Architecture

<p align="center">
  <img src="assets/images/system_architecture.svg" alt="Smart AC System Architecture" width="100%" />
</p>

### Architecture Breakdown & Data Flow

| Layer | Component | Protocol / Interface | Primary Function |
| :--- | :--- | :--- | :--- |
| **Mobile Control** | Flutter App ↔ EMQX Cloud | `MQTTS TLS (Port 8883)` | Reactive control, live temperature curves, power consumption charts & timer scheduling. |
| **Cloud Alerting** | EMQX Cloud ➔ Telegram API | `HTTPS Webhook (POST)` | 24/7 standalone alerting for brownouts (<190V), session energy summaries & nightly digests. |
| **ESP32 Core 0** | Network & Protocol Task | `FreeRTOS Priority 1` | TLS MQTT client, non-blocking WiFi watchdogs, NTP synchronization & async Telegram FIFO queue. |
| **ESP32 Core 1** | Sensor & Hardware Loop | `Sub-millisecond loop()` | PZEM-004T Modbus UART, 38kHz IR remote decoding loopback, DHT22 power gating & OLED display. |
| **AC Interface** | ESP32 ➔ Split AC Unit | `940nm IR Blaster (GPIO 5)` | Modulated optical commands for power, temperature, fan speed, modes & swing positions. |
| **Mains Grid** | 230V Line ➔ PZEM-004T | `CT Transformer (100A)` | True-RMS AC measurement of Voltage, Current, Active Power (W), Energy (kWh) & Power Factor. |

---

## 🔌 Hardware Pinout & Wiring

| Component | Pin / Signal | ESP32 GPIO | Description / Notes |
| :--- | :--- | :--- | :--- |
| **TSOP38238 / VS1838B** | Data OUT | `GPIO 4` | IR receiver input for physical remote decoding |
| **940nm IR Blaster LED** | Transistor Base | `GPIO 5` | Driven via 2N2222 / 330Ω base resistor |
| **PZEM-004T v3.0** | RX | `GPIO 17 (TX2)`| Modbus UART Serial2 Transmission |
| **PZEM-004T v3.0** | TX | `GPIO 16 (RX2)`| Modbus UART Serial2 Reception |
| **DHT22 (AM2302)** | Data (OUT) | `GPIO 15` | Temperature & Relative Humidity reading |
| **DHT22 Power Gating** | Transistor Base | `GPIO 25` | Periodic power toggle to prevent self-heating |
| **SSD1306 OLED** | SDA | `GPIO 21` | I2C Data line (0x3C address) |
| **SSD1306 OLED** | SCL | `GPIO 22` | I2C Clock line |
| **Tactile Push Button** | Signal | `GPIO 2` | Active LOW with internal pull-up for OLED screen swap |
| **Status Indicator** | LED | `GPIO 2` | On-board activity / network status indicator |

---

## ⚡ Dual-Core FreeRTOS Partitioning

To avoid timing jitter during 38kHz IR modulation and sensor reads, tasks are strictly isolated across ESP32 cores:

| FreeRTOS Task | Target Core | Priority | Role & Functionality |
| :--- | :---: | :---: | :--- |
| **`core0Task`** | **Core 0** | 1 | WiFi management, EMQX MQTT TLS loop, reconnect watchdogs, NTP synchronization, and async Telegram message queue dispatching. |
| **`loop()` / Sensors** | **Core 1** | 1 | PZEM-004T energy sampling, DHT22 state machine, continuous IR loopback signal processing, and OLED UI updates. |

---

## 📨 MQTT Topic Schema

All payloads are formatted as compact JSON strings under the device prefix `smartac/ac_living_room_01/`:

### 1. Command (`.../cmd`) — *App to ESP32*
```json
{
  "power": true,
  "temp": 24,
  "mode": "cool",
  "fan": "auto",
  "swing": "auto"
}
```

### 2. State (`.../state`) — *ESP32 to App (Retained)*
```json
{
  "power": true,
  "temp": 24,
  "mode": "cool",
  "fan": "auto",
  "swing": "auto",
  "source": "remote",
  "timestamp": 1757912400
}
```

### 3. Telemetry (`.../telemetry`) — *ESP32 to App (Every 2.5s)*
```json
{
  "voltage": 230.4,
  "current": 4.12,
  "power": 948.5,
  "energy": 14.82,
  "frequency": 50.0,
  "pf": 0.98,
  "temp": 25.1,
  "humidity": 58.4,
  "wifi_rssi": -62
}
```

### 4. Status (`.../status`) — *Last Will & Testament (Retained)*
- Online: `{"status":"online","ip":"192.168.1.50"}`
- Offline: `{"status":"offline"}`

### 5. Telegram (`.../telegram`) — *ESP32 to Cloud Rule*
```json
{
  "text": "🔔 Smart AC Turn-OFF Summary:
⏱ Duration: 2h 15m
⚡ Energy: 1.84 kWh
💰 Est Cost: ₹14.72"
}
```

---

## 🔔 24/7 Telegram Alert Engine

The system issues automated notifications for critical events directly to your Telegram account:

```text
🔔 [SMART AC ONLINE]
ESP32 connected to EMQX Cloud.
IP: 192.168.1.50 | RSSI: -61 dBm
Boot Reason: Power On Reset

⚠️ [VOLTAGE ANOMALY DETECTED]
AC Mains Voltage: 184.2 V (Brownout Hazard!)
Standard range: 200V - 245V.

❄️ [AC SHUTDOWN SUMMARY]
Operating Duration: 3 hrs 24 mins
Energy Consumed: 2.91 kWh
Session Cost: ₹23.28

🌙 [NIGHTLY ENERGY REPORT]
Daily AC Runtime: 6 hrs 42 mins
Total Energy Today: 5.78 kWh
Estimated Cost: ₹46.24
```

---

## 📁 Project Directory Structure

```text
Smart_AC_MQTT/
|-- Smart_AC_MQTT.ino           # ESP32 Dual-Core FreeRTOS firmware sketch
|-- pubspec.yaml                # Flutter project dependencies & asset declarations
|-- lib/
|   |-- main.dart               # Flutter application entry point
|   |-- firebase_options.dart   # Firebase configuration options
|   |-- core/                   # Design system, themes, and application constants
|   |-- models/                 # Data models (ACState, TelemetryData, Schedule)
|   |-- providers/              # State management (ACProvider, WeatherProvider, etc.)
|   |-- screens/                # UI Screens (Dashboard, Analytics, Scheduler, Settings)
|   |-- services/               # MQTT client, FCM push, Auth, and Storage services
|   `-- widgets/                # Reusable UI widgets (Gauges, Power Cards, Charts)
|-- android/                    # Native Android project configuration & manifests
|-- assets/                     # UI icons, animations, and sound effects
`-- README.md                   # Project documentation
```

### Key Modules Breakdown

| Path | Description |
| :--- | :--- |
| **`Smart_AC_MQTT.ino`** | Core ESP32 sketch running FreeRTOS tasks, PZEM-004T Modbus sampling, DHT22 power gating, IR remote decoding/blaster loopback, SSD1306 OLED screens, and EMQX TLS MQTT. |
| **`lib/services/mqtt_service.dart`** | Production Flutter MQTT client managing background connection, subscriptions, command queuing, and auto-reconnect logic. |
| **`lib/providers/device_provider.dart`** | Central state provider connecting MQTT telemetry/state streams to the Flutter reactive UI. |
| **`lib/screens/dashboard/`** | Main dashboard with interactive climate ring, live wattage meters, and remote control panel. |
| **`lib/screens/energy/`** | Comprehensive energy and cost analytics screens with historical breakdown. |
| **`lib/services/fcm_push_service.dart`** | Firebase Cloud Messaging push notification dispatcher. |

---

## 🚀 Getting Started & Installation

### 1. ESP32 Firmware Setup

1. **Install Arduino IDE** (version 2.x recommended).
2. Add ESP32 board support via Boards Manager:
   - URL: `https://raw.githubusercontent.com/espressif/arduino-esp32/gh-pages/package_esp32_index.json`
3. Install the required Arduino libraries:
   - `PubSubClient` by Nick O'Leary
   - `ArduinoJson` (v6.x or v7.x) by Benoit Blanchon
   - `IRremoteESP8266` by Mark Szabo, David Conran
   - `PZEM004Tv30` by Mandar
   - `DHT sensor library` by Adafruit
   - `Adafruit SSD1306` & `Adafruit GFX Library`
4. Open `Smart_AC_MQTT.ino`, enter your WiFi and MQTT credentials (see [Security & Credential Configuration](#-security--credential-configuration)), select **ESP32 Dev Module**, and click **Upload**.

### 2. Flutter Mobile App Setup

1. **Prerequisites**: Ensure Flutter SDK (>=3.0.0) is installed and available in your `PATH`.
2. Navigate to the project root and install packages:
   ```bash
   flutter pub get
   ```
3. Run the application on your connected Android device or emulator:
   ```bash
   flutter run
   ```

### 3. EMQX Cloud & Telegram Webhook Rule Engine

To enable 24/7 alerts without keeping a server or app alive:
1. Log into your **EMQX Cloud Console**.
2. Navigate to **Data Integration** -> **Rules** -> **Create Rule**.
3. **SQL Query**:
   ```sql
   SELECT payload.text as text FROM "smartac/+/telegram"
   ```
4. **Action**: Add an **HTTP / Webhook Action**:
   - **Method**: `POST`
   - **URL**: `https://api.telegram.org/bot<YOUR_TELEGRAM_BOT_TOKEN>/sendMessage`
   - **Headers**: `Content-Type: application/json`
   - **Body Template**:
     ```json
     {
       "chat_id": "<YOUR_TELEGRAM_CHAT_ID>",
       "text": "${text}"
     }
     ```

---

## 🔐 Security & Credential Configuration

For open-source distribution, all private credentials in this repository are replaced with `***` placeholders. Before running, insert your credentials in the following files:

| File | Credentials to Configure |
| :--- | :--- |
| **`Smart_AC_MQTT.ino`** | `WIFI_SSID`, `WIFI_PASSWORD`, `MQTT_BROKER`, `MQTT_USER`, `MQTT_PASS`, `TELEGRAM_BOT_TOKEN`, `TELEGRAM_CHAT_ID` |
| **`lib/services/mqtt_service.dart`** | `_broker`, `_user`, `_pass` |
| **`lib/services/fcm_push_service.dart`** | Google Cloud Service Account Private Key |
| **`lib/core/constants.dart`** | `weatherApiKey` (OpenWeatherMap API Key) |
| **`android/app/google-services.json`** | Firebase `current_key` and mobile app client ID |

> 💡 **Tip for Local Users**: If you are working on your local machine, your original live credentials have been preserved in `my_secrets_backup.local` (which is excluded from Git).

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
