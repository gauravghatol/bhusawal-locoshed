import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirebaseQuickstartService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static Future<User?> signInAnonymously() async {
    final result = await _auth.signInAnonymously();
    return result.user;
  }

  static bool get isAuthenticated => _auth.currentUser != null;
  static User? get currentUser => _auth.currentUser;

  static Stream<List<Map<String, dynamic>>> collectionStream(
    String collectionPath,
  ) {
    return _firestore
        .collection(collectionPath)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => {'id': doc.id, ...doc.data()})
              .toList(),
        );
  }

  static Future<Map<String, dynamic>?> getDocument(
    String collectionPath,
    String docId,
  ) async {
    final doc = await _firestore.collection(collectionPath).doc(docId).get();
    return doc.exists ? doc.data() : null;
  }

  static Future<void> setDocument(
    String collectionPath,
    String docId,
    Map<String, dynamic> data,
  ) async {
    await _firestore
        .collection(collectionPath)
        .doc(docId)
        .set(data, SetOptions(merge: true));
  }

  static Future<void> deleteDocument(
    String collectionPath,
    String docId,
  ) async {
    await _firestore.collection(collectionPath).doc(docId).delete();
  }

  static Future<void> batchSetDocuments(
    String collectionPath,
    Map<String, Map<String, dynamic>> updates,
  ) async {
    final batch = _firestore.batch();
    updates.forEach((docId, data) {
      final docRef = _firestore.collection(collectionPath).doc(docId);
      batch.set(docRef, data, SetOptions(merge: true));
    });
    await batch.commit();
  }

  static Future<void> signOut() async {
    await _auth.signOut();
  }

  // Additional helper methods for real-time data updates
  static Stream<Map<String, dynamic>?> documentStream(
    String collectionPath,
    String docId,
  ) {
    return _firestore
        .collection(collectionPath)
        .doc(docId)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.exists ? {'id': snapshot.id, ...snapshot.data()!} : null,
        );
  }

  static Future<String> addDocument(
    String collectionPath,
    Map<String, dynamic> data,
  ) async {
    final docRef = await _firestore.collection(collectionPath).add(data);
    return docRef.id;
  }

  static Future<void> updateDocument(
    String collectionPath,
    String docId,
    Map<String, dynamic> data,
  ) async {
    await _firestore.collection(collectionPath).doc(docId).update(data);
  }

  // Query methods for filtered real-time updates
  static Stream<List<Map<String, dynamic>>> collectionStreamWhere(
    String collectionPath,
    String field,
    dynamic isEqualTo,
  ) {
    return _firestore
        .collection(collectionPath)
        .where(field, isEqualTo: isEqualTo)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => {'id': doc.id, ...doc.data()})
              .toList(),
        );
  }

  static Stream<List<Map<String, dynamic>>> collectionStreamOrderBy(
    String collectionPath,
    String field, {
    bool descending = false,
  }) {
    return _firestore
        .collection(collectionPath)
        .orderBy(field, descending: descending)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => {'id': doc.id, ...doc.data()})
              .toList(),
        );
  }
}
