import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/planning_rules.dart';
import 'planning_store.dart';

class AccountPlanningStore {
  static final Map<String, PlanningStore> _instances = {};
  static Future<PlanningStore> current() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw StateError('Sign in to use the planner.');
    if (_instances[uid] case final store?) return store;
    final store = PlanningStore(
      uid: uid,
      prefs: DevicePlanningPreferences(await SharedPreferences.getInstance()),
      cloud: FirebasePlanningCloud(uid),
      onSyncError: (e) =>
          debugPrint('Saved on device; cloud sync did not finish: $e'),
    );
    _instances[uid] = store;
    return store;
  }
}

class DevicePlanningPreferences implements PlanningPreferences {
  DevicePlanningPreferences(this.delegate);
  final SharedPreferences delegate;
  @override
  String? getString(String key) => delegate.getString(key);
  @override
  int? getInt(String key) => delegate.getInt(key);
  @override
  bool? getBool(String key) => delegate.getBool(key);
  @override
  Set<String> getKeys() => delegate.getKeys();
  @override
  Future<bool> setString(String key, String value) =>
      delegate.setString(key, value);
  @override
  Future<bool> setInt(String key, int value) => delegate.setInt(key, value);
  @override
  Future<bool> setBool(String key, bool value) => delegate.setBool(key, value);
  @override
  Future<bool> remove(String key) => delegate.remove(key);
}

class FirebasePlanningCloud implements PlanningCloud {
  FirebasePlanningCloud(this.uid);
  final String uid;
  DocumentReference<Map<String, dynamic>> get user =>
      FirebaseFirestore.instance.collection('users').doc(uid);
  @override
  Future<TaskData?> readState() async =>
      (await user
              .collection('appData')
              .doc('state')
              .get()
              .timeout(const Duration(seconds: 8)))
          .data();
  @override
  Future<void> saveState(TaskData fields) async {
    await user
        .collection('appData')
        .doc('state')
        .set({
          ...fields,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true))
        .timeout(const Duration(seconds: 8));
  }

  @override
  Future<List<TaskData>?> readDay(String date) async {
    final doc = await user
        .collection('taskDays')
        .doc(date)
        .get()
        .timeout(const Duration(seconds: 8));
    final value = doc.data()?['tasks'];
    return value is List
        ? value.map((v) => Map<String, dynamic>.from(v as Map)).toList()
        : null;
  }

  @override
  Future<void> saveDay(String date, List<TaskData> tasks) async {
    await user
        .collection('taskDays')
        .doc(date)
        .set({
          'tasks': tasks,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true))
        .timeout(const Duration(seconds: 8));
  }

  @override
  Future<Map<String, List<TaskData>>> readDays() async {
    final docs = await user
        .collection('taskDays')
        .get()
        .timeout(const Duration(seconds: 8));
    return {
      for (final doc in docs.docs)
        if (doc.data()['tasks'] is List)
          doc.id: (doc.data()['tasks'] as List)
              .map((v) => Map<String, dynamic>.from(v as Map))
              .toList(),
    };
  }
}
