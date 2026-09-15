// lib/services/firestore_service.dart
// MQTT edition: Firestore used ONLY for energy logs, filter, and schedule.
// All live AC control goes through MQTT.

import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  DocumentReference<Map<String,dynamic>> get _deviceDoc =>
      _db.collection(AppConstants.collectionDevices).doc(AppConstants.deviceId);

  // Keep for ESP32 system commands
  Future<void> requestEspRestart() async {
    await _deviceDoc.set({'restartRequestedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
  }
  Future<void> requestFactoryReset() async {
    await _deviceDoc.set({'factoryResetRequestedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
  }

  // Energy logs
  Stream<List<Map<String,dynamic>>> dailyLogsStream() {
    return _db
        .collection(AppConstants.collectionEnergyLogs)
        .where('deviceId', isEqualTo: AppConstants.deviceId)
        .snapshots()
        .map((snap) => snap.docs.map((d) { final m=d.data(); m['id']=d.id; return m; }).toList());
  }

  Future<List<Map<String,dynamic>>> fetchEnergyHistory(String period, {int limit = 30}) async {
    final snap = await _db
        .collection(AppConstants.collectionEnergyLogs)
        .where('deviceId', isEqualTo: AppConstants.deviceId)
        .orderBy('lastUpdated', descending: true)
        .limit(limit)
        .get();
    return snap.docs.map((d) => d.data()).toList();
  }

  // Filter
  DocumentReference<Map<String,dynamic>> get _filterDoc =>
      _db.collection(AppConstants.collectionFilterLogs).doc(AppConstants.deviceId);

  Future<void> resetFilterTimer() async {
    await _filterDoc.set({AppConstants.filterLastResetKey: FieldValue.serverTimestamp()}, SetOptions(merge: true));
  }
  Stream<DateTime?> lastFilterResetStream() {
    return _filterDoc.snapshots().map((snap) {
      if (!snap.exists) return null;
      final ts = snap.data()?[AppConstants.filterLastResetKey];
      if (ts is Timestamp) return ts.toDate();
      return null;
    });
  }
  int daysUntilFilterDue(DateTime? lastReset, int intervalDays) {
    if (lastReset == null) return 0;
    final remaining = intervalDays - DateTime.now().difference(lastReset).inDays;
    return remaining < 0 ? 0 : remaining;
  }

  // Schedule
  DocumentReference<Map<String,dynamic>> get _scheduleDoc =>
      _db.collection(AppConstants.collectionSchedules).doc(AppConstants.deviceId);

  Stream<Map<String,dynamic>?> scheduleStream() {
    return _scheduleDoc.snapshots().map((snap) => snap.exists ? snap.data() : null);
  }
  Future<void> setSchedule(Map<String,dynamic> data) async {
    await _scheduleDoc.set(data, SetOptions(merge: true));
  }
}
