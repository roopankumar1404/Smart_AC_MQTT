// lib/providers/connectivity_provider.dart
//
// Checks THIS DEVICE's (phone/laptop) actual internet reachability —
// separate from WiFi/ESP32 status, which come from Firestore and only
// describe the ESP32's connectivity, not the client's.

import 'dart:async';
import 'dart:io' show InternetAddress;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

class ConnectivityProvider extends ChangeNotifier {
  bool _hasInternet = true; // optimistic default until first check completes
  bool get hasInternet => _hasInternet;

  Timer? _timer;

  ConnectivityProvider() {
    if (!kIsWeb) {
      _checkNow();
      _timer = Timer.periodic(const Duration(seconds: 5), (_) => _checkNow());
    }
  }

  Future<void> _checkNow() async {
    if (kIsWeb) {
      if (!_hasInternet) {
        _hasInternet = true;
        notifyListeners();
      }
      return;
    }

    bool result;
    try {
      final lookup = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 3));
      result = lookup.isNotEmpty && lookup[0].rawAddress.isNotEmpty;
    } catch (_) {
      result = false;
    }

    if (result != _hasInternet) {
      _hasInternet = result;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}