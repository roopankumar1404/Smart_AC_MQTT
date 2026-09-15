// lib/services/mqtt_service.dart
//
// EMQX MQTT Client for Smart AC
// Replaces all Firebase polling/realtime for live control.
// Firebase Firestore is used ONLY for energy logs and schedules.

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

class MqttService extends ChangeNotifier {
  static const String _broker   = '***.emqxsl.com';
  static const int    _port     = 8883;
  static const String _user     = '***';
  static const String _pass     = '***';
  static const String _deviceId = 'ac_living_room_01';

  static const String topicState     = 'smartac/$_deviceId/state';
  static const String topicTelemetry = 'smartac/$_deviceId/telemetry';
  static const String topicStatus    = 'smartac/$_deviceId/status';
  static const String topicCmd       = 'smartac/$_deviceId/cmd';

  MqttServerClient? _client;
  bool _connected = false;
  bool get isConnected => _connected;

  // Stream controllers for incoming data
  final _stateController     = StreamController<Map<String,dynamic>>.broadcast();
  final _telemetryController = StreamController<Map<String,dynamic>>.broadcast();
  final _statusController    = StreamController<String>.broadcast();

  Stream<Map<String,dynamic>> get stateStream     => _stateController.stream;
  Stream<Map<String,dynamic>> get telemetryStream => _telemetryController.stream;
  Stream<String>              get statusStream    => _statusController.stream;

  // Reconnect timer
  Timer? _reconnectTimer;

  // ──────────────────────────────────────────
  // CONNECT
  // ──────────────────────────────────────────
  Future<void> connect() async {
    // Generate unique session client ID to prevent broker collision when app is killed & reopened
    final sessionId = 'flutter_${DateTime.now().millisecondsSinceEpoch % 1000000}';
    _client = MqttServerClient.withPort(_broker, sessionId, _port);
    _client!.secure = true;
    _client!.keepAlivePeriod = 30;
    _client!.autoReconnect = true;
    _client!.resubscribeOnAutoReconnect = true;
    _client!.connectTimeoutPeriod = 10000;
    _client!.logging(on: false);

    // LWT — so ESP32 can detect app going offline if needed
    final connMsg = MqttConnectMessage()
        .withClientIdentifier(sessionId)
        .authenticateAs(_user, _pass)
        .withWillTopic('smartac/$_deviceId/app_status')
        .withWillMessage('offline')
        .withWillRetain()
        .startClean();
    _client!.connectionMessage = connMsg;

    _client!.onConnected    = _onConnected;
    _client!.onDisconnected = _onDisconnected;
    _client!.onAutoReconnected = _onConnected;

    try {
      await _client!.connect();
    } catch (e) {
      debugPrint('[MQTT] connect error: $e');
      _scheduleReconnect();
    }
  }

  void _onConnected() {
    debugPrint('[MQTT] Connected to EMQX');
    _connected = true;
    notifyListeners();
    _subscribeAll();
    _cancelReconnect();
  }

  void _onDisconnected() {
    debugPrint('[MQTT] Disconnected');
    _connected = false;
    notifyListeners();
    _scheduleReconnect();
  }

  void _subscribeAll() {
    _client!.subscribe(topicState,     MqttQos.atLeastOnce);
    _client!.subscribe(topicTelemetry, MqttQos.atLeastOnce);
    _client!.subscribe(topicStatus,    MqttQos.atLeastOnce);

    _client!.updates?.listen((List<MqttReceivedMessage<MqttMessage>> messages) {
      for (final msg in messages) {
        final pubMsg = msg.payload as MqttPublishMessage;
        final payload = MqttPublishPayload.bytesToStringAsString(pubMsg.payload.message);
        _handleMessage(msg.topic, payload);
      }
    });
  }

  void _handleMessage(String topic, String payload) {
    try {
      if (topic == topicState) {
        final data = jsonDecode(payload) as Map<String,dynamic>;
        _stateController.add(data);
      } else if (topic == topicTelemetry) {
        final data = jsonDecode(payload) as Map<String,dynamic>;
        _telemetryController.add(data);
      } else if (topic == topicStatus) {
        _statusController.add(payload); // "online" or "offline"
      }
    } catch (e) {
      debugPrint('[MQTT] parse error: $e');
    }
  }

  // ──────────────────────────────────────────
  // PUBLISH COMMAND
  // ──────────────────────────────────────────
  void publishCommand(Map<String,dynamic> command) {
    if (!_connected || _client == null) {
      debugPrint('[MQTT] Not connected — command dropped');
      return;
    }
    final payload = jsonEncode(command);
    final builder = MqttClientPayloadBuilder();
    builder.addString(payload);
    _client!.publishMessage(topicCmd, MqttQos.atLeastOnce, builder.payload!);
    debugPrint('[MQTT] CMD published: $payload');
  }

  // ──────────────────────────────────────────
  // RECONNECT
  // ──────────────────────────────────────────
  void _scheduleReconnect() {
    _cancelReconnect();
    _reconnectTimer = Timer(const Duration(seconds: 5), () async {
      debugPrint('[MQTT] Attempting reconnect...');
      await connect();
    });
  }

  void _cancelReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
  }

  // ──────────────────────────────────────────
  // DISPOSE
  // ──────────────────────────────────────────
  @override
  void dispose() {
    _cancelReconnect();
    _client?.disconnect();
    _stateController.close();
    _telemetryController.close();
    _statusController.close();
    super.dispose();
  }
}

