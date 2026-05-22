import 'package:cloud_firestore/cloud_firestore.dart';

import '../utils/debug_logger.dart';
import '../models/chat_message.dart';
import '../models/chat_session.dart';
import '../models/health_log.dart';
import '../models/user_profile.dart';

/// Cloud database service for syncing user health data to Firestore.
/// Provides save and load operations for user state including profile, logs, and chat history.
class CloudUserState {
  CloudUserState({
    required this.profile,
    required this.logs,
    required this.chatSessions,
    required this.activeChatSessionId,
    required this.onboardingCompleted,
  });

  final UserProfile profile;
  final List<HealthLog> logs;
  final List<ChatSession> chatSessions;
  final String? activeChatSessionId;
  final bool onboardingCompleted;
}

class FirestoreService {
  FirestoreService({FirebaseFirestore? firestore}) : _providedFirestore = firestore;

  final FirebaseFirestore? _providedFirestore;

  FirebaseFirestore get _firestore => _providedFirestore ?? FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _stateDoc(String userId) {
    return _firestore.collection('users').doc(userId).collection('app').doc('state');
  }

  DocumentReference<Map<String, dynamic>> _adminDoc(String adminId) {
    return _firestore.collection('app_admins').doc(adminId);
  }

  CollectionReference<Map<String, dynamic>> _doctorCategoriesCol() {
    return _firestore.collection('doctor_categories');
  }

  CollectionReference<Map<String, dynamic>> _doctorAppointmentsCol() {
    return _firestore.collection('doctor_appointments');
  }

  CollectionReference<Map<String, dynamic>> _doctorRatingsCol() {
    return _firestore.collection('doctor_ratings');
  }

  Future<void> saveUserState({
    required String userId,
    required UserProfile profile,
    required List<HealthLog> logs,
    required List<ChatSession> chatSessions,
    required String? activeChatSessionId,
    required bool onboardingCompleted,
  }) async {
    try {
      await _stateDoc(userId).set(
        {
          'profile': profile.toMap(),
          'logs': logs.map((e) => e.toMap()).toList(),
          'chatSessions': chatSessions.map((e) => e.toMap()).toList(),
          'activeChatSessionId': activeChatSessionId,
          'onboardingCompleted': onboardingCompleted,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      DebugLogger.info('Synced user state for $userId (${logs.length} logs, ${chatSessions.length} chats)');
    } catch (e, stack) {
      DebugLogger.error('Failed to save user state for $userId', e, stack);
      rethrow;
    }
  }

  Future<void> deleteUserState(String userId) async {
    try {
      await _stateDoc(userId).delete();
      DebugLogger.info('Deleted user state for $userId');
    } catch (e, stack) {
      DebugLogger.error('Failed to delete user state for $userId', e, stack);
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> loadAdmins() async {
    try {
      final snapshot = await _firestore.collection('app_admins').orderBy('email').get();
      return snapshot.docs.map((doc) => {...doc.data(), 'id': doc.id}).toList();
    } catch (e, stack) {
      DebugLogger.error('Failed to load admins', e, stack);
      return <Map<String, dynamic>>[];
    }
  }

  Future<bool> isAdminEmail(String email) async {
    try {
      final doc = await _adminDoc(email.toLowerCase()).get();
      return doc.exists;
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        return false;
      }
      DebugLogger.error('Failed to check admin email', e, StackTrace.current);
      return false;
    } catch (e, stack) {
      DebugLogger.error('Failed to check admin email', e, stack);
      return false;
    }
  }

  /// Check whether a given Firebase `uid` is listed as an admin.
  /// Supports admin documents keyed by UID or documents that include a `uid` field.
  Future<bool> isAdminUid(String uid) async {
    try {
      if (uid.isEmpty) return false;
      // First try document keyed by uid
      final doc = await _adminDoc(uid).get();
      if (doc.exists) return true;

      // Fallback: search for a document that has a `uid` field matching this uid
      final q = await _firestore.collection('app_admins').where('uid', isEqualTo: uid).limit(1).get();
      return q.docs.isNotEmpty;
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        return false;
      }
      DebugLogger.error('Failed to check admin uid', e, StackTrace.current);
      return false;
    } catch (e, stack) {
      DebugLogger.error('Failed to check admin uid', e, stack);
      return false;
    }
  }

  Future<void> saveAdmin({required String email, required String displayName, required String addedBy, String? uid}) async {
    try {
      final docRef = (uid != null && uid.isNotEmpty) ? _adminDoc(uid) : _adminDoc(email.toLowerCase());
      final data = {
        'email': email.toLowerCase(),
        'displayName': displayName,
        'addedBy': addedBy,
        'uid': uid,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      await docRef.set(data, SetOptions(merge: true));
    } catch (e, stack) {
      DebugLogger.error('Failed to save admin', e, stack);
      rethrow;
    }
  }

  Future<void> deleteAdmin(String adminId) async {
    try {
      await _adminDoc(adminId).delete();
    } catch (e, stack) {
      DebugLogger.error('Failed to delete admin $adminId', e, stack);
      rethrow;
    }
  }

  Future<List<String>> loadDoctorCategories() async {
    try {
      final snapshot = await _doctorCategoriesCol().orderBy('name').get();
      return snapshot.docs.map((doc) => (doc.data()['name'] ?? '').toString()).where((name) => name.trim().isNotEmpty).toList();
    } catch (e, stack) {
      DebugLogger.error('Failed to load doctor categories', e, stack);
      return <String>[];
    }
  }

  Future<void> saveDoctorCategory(String name) async {
    try {
      await _doctorCategoriesCol().doc(name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_')).set({
        'name': name.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e, stack) {
      DebugLogger.error('Failed to save doctor category', e, stack);
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> getDoctorByUserId(String userId) async {
    try {
      if (userId.isEmpty) return null;
      final q = await _firestore.collection('doctors').where('doctorUserId', isEqualTo: userId).limit(1).get();
      if (q.docs.isEmpty) return null;
      final data = q.docs.first.data();
      return {...data, 'id': q.docs.first.id};
    } catch (e, stack) {
      DebugLogger.error('Failed to get doctor by user id', e, stack);
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> queryDoctorAppointments({String? doctorUserId, String? patientUid}) async {
    try {
      Query<Map<String, dynamic>> q = _doctorAppointmentsCol().orderBy('appointmentAt', descending: false);
      if (doctorUserId != null && doctorUserId.isNotEmpty) {
        q = q.where('doctorUserId', isEqualTo: doctorUserId);
      }
      if (patientUid != null && patientUid.isNotEmpty) {
        q = q.where('patientUid', isEqualTo: patientUid);
      }
      final snapshot = await q.limit(200).get();
      return snapshot.docs.map((doc) => {...doc.data(), 'id': doc.id}).toList();
    } catch (e, stack) {
      DebugLogger.error('Failed to query doctor appointments', e, stack);
      return <Map<String, dynamic>>[];
    }
  }

  Future<String> saveDoctorAppointment(Map<String, dynamic> appointment) async {
    try {
      final docRef = appointment['id'] == null || appointment['id'].toString().isEmpty
          ? _doctorAppointmentsCol().doc()
          : _doctorAppointmentsCol().doc(appointment['id'].toString());
      await docRef.set({
        ...appointment,
        'updatedAt': FieldValue.serverTimestamp(),
        if (appointment['createdAt'] == null) 'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      return docRef.id;
    } catch (e, stack) {
      DebugLogger.error('Failed to save doctor appointment', e, stack);
      rethrow;
    }
  }

  Future<double> recalculateDoctorRating(String doctorId) async {
    try {
      final snapshot = await _doctorRatingsCol().where('doctorId', isEqualTo: doctorId).get();
      if (snapshot.docs.isEmpty) {
        await _firestore.collection('doctors').doc(doctorId).set({'rating': 0, 'ratingCount': 0}, SetOptions(merge: true));
        return 0;
      }
      final ratings = snapshot.docs.map((d) => (d.data()['rating'] as num?)?.toDouble() ?? 0).toList();
      final avg = ratings.reduce((a, b) => a + b) / ratings.length;
      await _firestore.collection('doctors').doc(doctorId).set({
        'rating': avg,
        'ratingCount': ratings.length,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      return avg;
    } catch (e, stack) {
      DebugLogger.error('Failed to recalculate doctor rating', e, stack);
      return 0;
    }
  }

  Future<void> saveDoctorRating({
    required String doctorId,
    required String doctorUserId,
    required String patientUid,
    required String patientName,
    required double rating,
    String? review,
  }) async {
    try {
      final docId = '${doctorId}_$patientUid';
      await _doctorRatingsCol().doc(docId).set({
        'doctorId': doctorId,
        'doctorUserId': doctorUserId,
        'patientUid': patientUid,
        'patientName': patientName,
        'rating': rating,
        'review': review ?? '',
        'updatedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      await recalculateDoctorRating(doctorId);
    } catch (e, stack) {
      DebugLogger.error('Failed to save doctor rating', e, stack);
      rethrow;
    }
  }

  Future<CloudUserState?> loadUserState(String userId) async {
    try {
      final snapshot = await _stateDoc(userId).get();
      if (!snapshot.exists) {
        DebugLogger.debug('No cloud state found for $userId');
        return null;
      }

      final data = snapshot.data();
      if (data == null) {
        return null;
      }

      final profileMap = data['profile'];
      final safeProfileMap = profileMap is Map<String, dynamic> ? profileMap : <String, dynamic>{};

    final rawLogs = (data['logs'] as List<dynamic>? ?? const []);
    final logs = rawLogs
        .whereType<Map<String, dynamic>>()
        .map(HealthLog.fromMap)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    final rawSessions = (data['chatSessions'] as List<dynamic>? ?? const []);
    final sessions = rawSessions
        .whereType<Map<String, dynamic>>()
        .map(ChatSession.fromMap)
        .toList();

    List<ChatSession> normalizedSessions;
    String? activeChatSessionId = data['activeChatSessionId'] as String?;

    if (sessions.isNotEmpty) {
      normalizedSessions = sessions
          .map((session) => session.copyWith(
                messages: [...session.messages]..sort((a, b) => a.timestamp.compareTo(b.timestamp)),
              ))
          .toList();
    } else {
      final rawChat = (data['chatMessages'] as List<dynamic>? ?? const []);
      final chat = rawChat
          .whereType<Map<String, dynamic>>()
          .map(ChatMessage.fromMap)
          .toList()
        ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

      normalizedSessions = [
        ChatSession(
          id: 'default',
          title: chat.isEmpty
              ? 'New chat'
              : chat.firstWhere((message) => message.isUser, orElse: () => chat.first).text.split(RegExp(r'\s+')).take(5).join(' '),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          messages: chat,
        ),
      ];
      activeChatSessionId ??= 'default';
    }

      return CloudUserState(
        profile: UserProfile.fromMap(safeProfileMap),
        logs: logs,
        chatSessions: normalizedSessions,
        activeChatSessionId: activeChatSessionId,
        onboardingCompleted: (data['onboardingCompleted'] as bool?) ?? false,
      );
    } catch (e, stack) {
      DebugLogger.error('Failed to load user state for $userId', e, stack);
      return null;
    }
  }

  /// Query doctors collection with optional filters.
  /// Returns a list of raw document maps.
  Future<List<Map<String, dynamic>>> queryDoctors({
    String? search,
    String? category,
    String? division,
    String? district,
    int limit = 100,
  }) async {
    try {
      Query<Map<String, dynamic>> q = _firestore.collection('doctors').withConverter<Map<String, dynamic>>(fromFirestore: (s, _) => s.data() ?? <String, dynamic>{}, toFirestore: (m, _) => m);

      if (category != null && category.isNotEmpty) {
        q = q.where('category', isEqualTo: category);
      }
      if (division != null && division.isNotEmpty) {
        q = q.where('division', isEqualTo: division);
      }
      if (district != null && district.isNotEmpty) {
        q = q.where('district', isEqualTo: district);
      }

      final snapshot = await q.limit(limit).get();
      var docs = snapshot.docs.map((d) => d.data()..['id'] = d.id).toList();

      if (search != null && search.trim().isNotEmpty) {
        final s = search.toLowerCase();
        docs = docs.where((doc) {
          final name = (doc['name'] ?? '').toString().toLowerCase();
          final quals = (doc['qualification'] ?? '').toString().toLowerCase();
          final chamber = (doc['chamber'] ?? '').toString().toLowerCase();
          final chambers = (doc['chambers'] as List<dynamic>? ?? const []);
          final chamberMatch = chambers.whereType<Map<String, dynamic>>().any((item) {
            final title = (item['name'] ?? '').toString().toLowerCase();
            final address = (item['address'] ?? '').toString().toLowerCase();
            return title.contains(s) || address.contains(s);
          });
          final categoryField = (doc['category'] ?? '').toString().toLowerCase();
          return name.contains(s) || quals.contains(s) || chamber.contains(s) || chamberMatch || categoryField.contains(s);
        }).toList();
      }

      return docs.cast<Map<String, dynamic>>();
    } catch (e, stack) {
      DebugLogger.error('Failed to query doctors', e, stack);
      return <Map<String, dynamic>>[];
    }
  }

  Future<Map<String, dynamic>?> getDoctorById(String id) async {
    try {
      final doc = await _firestore.collection('doctors').doc(id).get();
      if (!doc.exists) return null;
      final data = doc.data();
      if (data == null) return null;
      final map = Map<String, dynamic>.from(data);
      map['id'] = doc.id;
      return map;
    } catch (e, stack) {
      DebugLogger.error('Failed to get doctor $id', e, stack);
      return null;
    }
  }

  Future<String> saveDoctor(Map<String, dynamic> doctor) async {
    try {
      final docRef = doctor['id'] == null || doctor['id'].toString().isEmpty
          ? _firestore.collection('doctors').doc()
          : _firestore.collection('doctors').doc(doctor['id'].toString());
      await docRef.set({...doctor, 'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
      return docRef.id;
    } catch (e, stack) {
      DebugLogger.error('Failed to save doctor', e, stack);
      rethrow;
    }
  }

  Future<void> deleteDoctor(String id) async {
    try {
      await _firestore.collection('doctors').doc(id).delete();
    } catch (e, stack) {
      DebugLogger.error('Failed to delete doctor $id', e, stack);
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> queryEmergencyResources({
    String? type,
    String? division,
    String? district,
    int limit = 200,
  }) async {
    try {
      Query<Map<String, dynamic>> q = _firestore.collection('emergency_resources').withConverter<Map<String, dynamic>>(fromFirestore: (s, _) => s.data() ?? <String, dynamic>{}, toFirestore: (m, _) => m);
      if (type != null && type.isNotEmpty) q = q.where('type', isEqualTo: type);
      if (division != null && division.isNotEmpty) q = q.where('division', isEqualTo: division);
      if (district != null && district.isNotEmpty) q = q.where('district', isEqualTo: district);
      final snapshot = await q.limit(limit).get();
      return snapshot.docs.map((d) => d.data()..['id'] = d.id).toList();
    } catch (e, stack) {
      DebugLogger.error('Failed to query emergency resources', e, stack);
      return <Map<String, dynamic>>[];
    }
  }

  Future<String> saveEmergencyResource(Map<String, dynamic> resource) async {
    try {
      final docRef = resource['id'] == null || resource['id'].toString().isEmpty
          ? _firestore.collection('emergency_resources').doc()
          : _firestore.collection('emergency_resources').doc(resource['id'].toString());
      await docRef.set({...resource, 'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
      return docRef.id;
    } catch (e, stack) {
      DebugLogger.error('Failed to save emergency resource', e, stack);
      rethrow;
    }
  }

  Future<void> deleteEmergencyResource(String id) async {
    try {
      await _firestore.collection('emergency_resources').doc(id).delete();
    } catch (e, stack) {
      DebugLogger.error('Failed to delete emergency resource $id', e, stack);
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> queryDonors({
    String? bloodGroup,
    String? division,
    String? district,
    int limit = 200,
  }) async {
    try {
      Query<Map<String, dynamic>> q = _firestore.collection('blood_donors').withConverter<Map<String, dynamic>>(fromFirestore: (s, _) => s.data() ?? <String, dynamic>{}, toFirestore: (m, _) => m);
      if (bloodGroup != null && bloodGroup.isNotEmpty) q = q.where('bloodGroup', isEqualTo: bloodGroup.toUpperCase());
      if (division != null && division.isNotEmpty) q = q.where('division', isEqualTo: division);
      if (district != null && district.isNotEmpty) q = q.where('district', isEqualTo: district);
      final snapshot = await q.limit(limit).get();
      return snapshot.docs.map((d) => d.data()..['id'] = d.id).toList();
    } catch (e, stack) {
      DebugLogger.error('Failed to query donors', e, stack);
      return <Map<String, dynamic>>[];
    }
  }

  Future<String> saveDonor(Map<String, dynamic> donor) async {
    try {
      final docRef = donor['id'] == null || donor['id'].toString().isEmpty
          ? _firestore.collection('blood_donors').doc()
          : _firestore.collection('blood_donors').doc(donor['id'].toString());
      await docRef.set({...donor, 'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
      return docRef.id;
    } catch (e, stack) {
      DebugLogger.error('Failed to save donor', e, stack);
      rethrow;
    }
  }

  Future<void> deleteDonor(String id) async {
    try {
      await _firestore.collection('blood_donors').doc(id).delete();
    } catch (e, stack) {
      DebugLogger.error('Failed to delete donor $id', e, stack);
      rethrow;
    }
  }
}
