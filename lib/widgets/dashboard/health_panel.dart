import 'package:flutter/material.dart';

import 'glass_card.dart';
import 'package:provider/provider.dart';
import '../../services/mqtt_service.dart';
import '../../providers/device_provider.dart';

class HealthPanel extends StatelessWidget {
  const HealthPanel({super.key});

  Widget _tile(
    Color color,
    IconData icon,
    String title,
    String status,
  ) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.15),
        child: Icon(
          icon,
          color: color,
        ),
      ),
      title: Text(
        title,
        style: const TextStyle(color: Colors.white),
      ),
      trailing: Text(
        status,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mqtt = context.watch<MqttService>();
    final provider = context.watch<DeviceProvider>();
    final isOnline = provider.isEsp32ActuallyOnline;
    return GlassCard(
      glowColor: Colors.purpleAccent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          const Text(
            "System Health",
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 16),

          _tile(
            Colors.greenAccent,
            Icons.wifi,
            "Wi-Fi",
            "Connected",
          ),

          _tile(
            Colors.cyanAccent,
            Icons.cloud_done,
            "Firebase",
            "Online",
          ),

          _tile(
            Colors.blueAccent,
            Icons.hub,
            "MQTT Broker",
            mqtt.isConnected ? "Connected" : "Disconnected",
          ),

          _tile(
            Colors.orangeAccent,
            Icons.memory,
            "ESP32",
            isOnline ? "Online" : "Offline",
          ),

          _tile(
            Colors.purpleAccent,
            Icons.settings_remote,
            "IR Module",
            "Ready",
          ),
        ],
      ),
    );
  }
}