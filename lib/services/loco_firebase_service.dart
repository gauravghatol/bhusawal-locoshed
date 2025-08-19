import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class LocoFirebaseService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static const String dataCollection = 'loco_data';
  static const String scheduledLocosCollection = 'scheduled_locos_data';
  static const String updatesLogCollection = 'updates_log';

  static bool _isFirebaseAvailable = false;
  static bool get isFirebaseAvailable => _isFirebaseAvailable;

  static Stream<Map<String, String>> getDataStream() {
    return _firestore
        .collection(dataCollection)
        .snapshots()
        .map((snapshot) {
          Map<String, String> data = {};
          for (var doc in snapshot.docs) {
            data[doc.id] = doc.data()['value'] ?? '';
          }
          _isFirebaseAvailable = true;
          return data;
        })
        .handleError((error) {
          debugPrint('Firebase stream error: $error');
          _isFirebaseAvailable = false;
          throw error;
        });
  }

  static Stream<Map<String, String>> getScheduledLocosDataStream() {
    return _firestore
        .collection(scheduledLocosCollection)
        .snapshots()
        .map((snapshot) {
          Map<String, String> data = {};
          for (var doc in snapshot.docs) {
            data[doc.id] = doc.data()['value'] ?? '';
          }
          _isFirebaseAvailable = true;
          return data;
        })
        .handleError((error) {
          debugPrint('Firebase scheduled locos stream error: $error');
          _isFirebaseAvailable = false;
          throw error;
        });
  }

  static Future<void> updatePosition(String key, String value) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      await _firestore.collection(dataCollection).doc(key).set({
        'value': value,
        'lastUpdated': FieldValue.serverTimestamp(),
        'updatedBy': user.email ?? 'anonymous',
        'updatedByUid': user.uid,
      }, SetOptions(merge: true));

      await _logUpdate(key, value, user);
    } catch (e) {
      debugPrint('Error updating position: $e');
      throw Exception('Failed to update: $e');
    }
  }

  static Future<void> updateScheduledLoco(Map<String, String> updates) async {
    if (updates.isEmpty) return;

    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final batch = _firestore.batch();

      for (String key in updates.keys) {
        final String value = updates[key]!;
        final docRef = _firestore.collection(scheduledLocosCollection).doc(key);

        batch.set(docRef, {
          'value': value,
          'lastUpdated': FieldValue.serverTimestamp(),
          'updatedBy': user.email ?? 'anonymous',
          'updatedByUid': user.uid,
        }, SetOptions(merge: true));
      }

      await batch.commit();

      // Log each update
      for (String key in updates.keys) {
        await _logScheduledLocoUpdate(key, updates[key]!, user);
      }
    } catch (e) {
      debugPrint('Error updating scheduled loco: $e');
      throw Exception('Failed to update: $e');
    }
  }

  static Future<void> batchUpdatePositions(Map<String, String> updates) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final batch = _firestore.batch();
      final timestamp = FieldValue.serverTimestamp();

      for (var entry in updates.entries) {
        final docRef = _firestore.collection(dataCollection).doc(entry.key);
        batch.set(docRef, {
          'value': entry.value,
          'lastUpdated': timestamp,
          'updatedBy': user.email ?? 'anonymous',
          'updatedByUid': user.uid,
        }, SetOptions(merge: true));
      }

      await batch.commit();

      // Log each update individually for comprehensive tracking
      for (var entry in updates.entries) {
        await _logUpdate(entry.key, entry.value, user, action: 'batch_update');
      }

      debugPrint(
        'Batch updated ${updates.length} positions with audit logging',
      );
    } catch (e) {
      debugPrint('Error in batch update: $e');
      throw Exception('Failed to batch update: $e');
    }
  }

  static Future<void> deleteRowFields(List<String> fieldKeys) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final batch = _firestore.batch();

      for (String fieldKey in fieldKeys) {
        final docRef = _firestore.collection(dataCollection).doc(fieldKey);
        batch.delete(docRef);
      }

      await batch.commit();

      // Log each deletion for comprehensive tracking
      for (String fieldKey in fieldKeys) {
        await _logUpdate(fieldKey, '[DELETED]', user, action: 'delete');
      }

      debugPrint(
        'Deleted ${fieldKeys.length} field documents from Firebase with audit logging',
      );
    } catch (e) {
      debugPrint('Error deleting row fields: $e');
      throw Exception('Failed to delete row fields: $e');
    }
  }

  static Future<void> _logUpdate(
    String key,
    String value,
    User user, {
    String? action,
    String? section,
  }) async {
    try {
      await _firestore.collection(updatesLogCollection).add({
        'key': key,
        'value': value,
        'action': action ?? 'update',
        'section': section ?? _getSectionFromKey(key),
        'updatedBy': user.email ?? 'anonymous',
        'updatedByUid': user.uid,
        'timestamp': FieldValue.serverTimestamp(),
      });
      debugPrint(
        'Logged ${action ?? 'update'}: $key = "$value" in ${section ?? _getSectionFromKey(key)} by ${user.email}',
      );
    } catch (e) {
      debugPrint('Failed to log update: $e');
    }
  }

  static Future<void> _logScheduledLocoUpdate(
    String key,
    String value,
    User user, {
    String? action,
  }) async {
    try {
      await _firestore.collection(updatesLogCollection).add({
        'key': key,
        'value': value,
        'action': action ?? 'update',
        'section': 'Scheduled Locos',
        'updatedBy': user.email ?? 'anonymous',
        'updatedByUid': user.uid,
        'timestamp': FieldValue.serverTimestamp(),
      });
      debugPrint(
        'Logged ${action ?? 'update'}: $key = "$value" in Scheduled Locos by ${user.email}',
      );
    } catch (e) {
      debugPrint('Failed to log scheduled loco update: $e');
    }
  }

  static String _getSectionFromKey(String key) {
    if (key.contains('shed_')) return 'Loco Shed';
    if (key.contains('_loco_no') ||
        key.contains('_loco_type') ||
        key.contains('_forecast') ||
        key.contains('_sch'))
      return 'Loco Forecast';
    if (key.contains('new_loco_')) return "Today's Outage";
    if (key.contains('new_schedule_') || key.contains('_schedule_type'))
      return 'Scheduled Locos';
    if (key.contains('rt_plant')) return 'Plant Status';
    return 'General';
  }

  // Enhanced logging for row operations
  static Future<void> logRowAction(
    String action,
    String rowId,
    String section, {
    String? additionalInfo,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      await _firestore.collection(updatesLogCollection).add({
        'key': '${action.toLowerCase()}_row_$rowId',
        'value': additionalInfo ?? rowId,
        'action': action,
        'section': section,
        'updatedBy': user.email ?? 'anonymous',
        'updatedByUid': user.uid,
        'timestamp': FieldValue.serverTimestamp(),
      });
      debugPrint('Logged $action: Row $rowId in $section by ${user.email}');
    } catch (e) {
      debugPrint('Failed to log row action: $e');
    }
  }

  static Future<List<Map<String, dynamic>>> getAuditLogs({
    int limit = 100,
  }) async {
    try {
      final querySnapshot = await _firestore
          .collection(updatesLogCollection)
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();

      List<Map<String, dynamic>> logs = [];
      for (var doc in querySnapshot.docs) {
        Map<String, dynamic> data = doc.data();
        data['id'] = doc.id; // Add document ID for unique identification
        logs.add(data);
      }

      debugPrint('Retrieved ${logs.length} audit logs');
      return logs;
    } catch (e) {
      debugPrint('Failed to get audit logs: $e');
      throw Exception('Failed to load audit logs: $e');
    }
  }
}
