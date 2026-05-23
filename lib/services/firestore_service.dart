import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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



class AdminAuditEntry {
  const AdminAuditEntry({
    required this.id,
    required this.action,
    required this.targetType,
    required this.targetId,
    required this.label,
    required this.actorUid,
    required this.actorEmail,
    required this.createdAt,
    required this.details,
  });

  final String id;
  final String action;
  final String targetType;
  final String targetId;
  final String label;
  final String actorUid;
  final String actorEmail;
  final DateTime? createdAt;
  final Map<String, dynamic> details;

  factory AdminAuditEntry.fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final rawCreatedAt = data['createdAt'];
    DateTime? createdAt;
    if (rawCreatedAt is Timestamp) {
      createdAt = rawCreatedAt.toDate();
    } else if (rawCreatedAt is String) {
      createdAt = DateTime.tryParse(rawCreatedAt);
    }

    final rawDetails = data['details'];
    final details = rawDetails is Map ? Map<String, dynamic>.from(rawDetails) : <String, dynamic>{};

    return AdminAuditEntry(
      id: doc.id,
      action: (data['action'] ?? '').toString(),
      targetType: (data['targetType'] ?? '').toString(),
      targetId: (data['targetId'] ?? '').toString(),
      label: (data['label'] ?? '').toString(),
      actorUid: (data['actorUid'] ?? '').toString(),
      actorEmail: (data['actorEmail'] ?? '').toString(),
      createdAt: createdAt,
      details: details,
    );
  }
}

class AdminDashboardStats {
  const AdminDashboardStats({
    required this.users,
    required this.admins,
    required this.normalDoctors,
    required this.dedicatedDoctors,
    required this.ambulances,
    required this.hospitals,
    required this.bloodBanks,
    required this.donors,
  });

  final int users;
  final int admins;
  final int normalDoctors;
  final int dedicatedDoctors;
  final int ambulances;
  final int hospitals;
  final int bloodBanks;
  final int donors;

  int get doctors => normalDoctors + dedicatedDoctors;
  int get emergencyResources => ambulances + hospitals + bloodBanks;
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

  CollectionReference<Map<String, dynamic>> _auditLogsCol() {
    return _firestore.collection('audit_logs');
  }

  User? get _currentUser => FirebaseAuth.instance.currentUser;

  Future<void> _safeLogAdminAction({
    required String action,
    required String targetType,
    required String targetId,
    required String label,
    Map<String, dynamic> details = const {},
  }) async {
    final user = _currentUser;
    if (user == null) return;

    try {
      final safeDetails = <String, dynamic>{};
      details.forEach((key, value) {
        if (value == null) return;
        if (value is String || value is num || value is bool) {
          safeDetails[key] = value;
        } else if (value is Iterable) {
          safeDetails[key] = value.map((item) => item.toString()).take(20).toList();
        } else {
          safeDetails[key] = value.toString();
        }
      });

      await _auditLogsCol().add({
        'action': action,
        'targetType': targetType,
        'targetId': targetId,
        'label': label,
        'actorUid': user.uid,
        'actorEmail': user.email ?? '',
        'details': safeDetails,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      // Audit logging should never break the primary action. Non-admin actors
      // can hit permission-denied when this helper is called from shared flows.
      if (e.code != 'permission-denied') {
        DebugLogger.warning('Failed to write audit log for $action', e);
      }
    } catch (e) {
      DebugLogger.warning('Failed to write audit log for $action', e);
    }
  }

  Future<List<AdminAuditEntry>> loadRecentAdminAuditLogs({int limit = 12}) async {
    try {
      final snapshot = await _auditLogsCol()
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();
      return snapshot.docs.map(AdminAuditEntry.fromDoc).toList();
    } on FirebaseException catch (e, stack) {
      if (e.code == 'permission-denied') {
        DebugLogger.warning('Admin audit logs are not available for this account.', e);
        return const <AdminAuditEntry>[];
      }
      DebugLogger.error('Failed to load admin audit logs', e, stack);
      return const <AdminAuditEntry>[];
    } catch (e, stack) {
      DebugLogger.error('Failed to load admin audit logs', e, stack);
      return const <AdminAuditEntry>[];
    }
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
          'logs': logs.map((e) => e.toFirestoreMap()).toList(),
          'chatSessions': chatSessions.map((e) => e.toFirestoreMap()).toList(),
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
      await _safeLogAdminAction(
        action: 'admin_saved',
        targetType: 'admin',
        targetId: docRef.id,
        label: displayName.isNotEmpty ? displayName : email,
        details: {'email': email.toLowerCase(), 'uid': uid ?? ''},
      );
    } catch (e, stack) {
      DebugLogger.error('Failed to save admin', e, stack);
      rethrow;
    }
  }

  Future<void> deleteAdmin(String adminId) async {
    try {
      await _adminDoc(adminId).delete();
      await _safeLogAdminAction(
        action: 'admin_deleted',
        targetType: 'admin',
        targetId: adminId,
        label: adminId,
      );
    } catch (e, stack) {
      DebugLogger.error('Failed to delete admin $adminId', e, stack);
      rethrow;
    }
  }


  Future<AdminDashboardStats> loadAdminDashboardStats() async {
    // Admin dashboard should not fail completely if one collection cannot be read.
    // Each count is loaded independently, then Firestore rules decide what the
    // signed-in admin can access. The app still logs individual failures.
    final stateDocs = await _safeAdminDocs(
      label: 'user app states',
      query: _firestore.collectionGroup('app'),
    );
    final adminDocs = await _safeAdminDocs(
      label: 'admin records',
      query: _firestore.collection('app_admins'),
    );
    final doctorDocs = await _safeAdminDocs(
      label: 'doctor records',
      query: _firestore.collection('doctors'),
    );
    final ambulanceDocs = await _safeAdminDocs(
      label: 'ambulance records',
      query: _firestore.collection('emergency_resources').where('type', isEqualTo: 'ambulance'),
    );
    final hospitalDocs = await _safeAdminDocs(
      label: 'hospital records',
      query: _firestore.collection('emergency_resources').where('type', isEqualTo: 'hospital'),
    );
    final bloodBankDocs = await _safeAdminDocs(
      label: 'blood bank records',
      query: _firestore.collection('emergency_resources').where('type', isEqualTo: 'blood_bank'),
    );
    final donorDocs = await _safeAdminDocs(
      label: 'donor records',
      query: _firestore.collection('blood_donors'),
    );

    // collectionGroup('app') can theoretically return any document under a
    // collection named "app". Only /users/{uid}/app/state documents count here.
    final userStateDocs = stateDocs.where((doc) => doc.id == 'state').toList();

    var stateAdminCount = 0;
    for (final doc in userStateDocs) {
      final profile = doc.data()['profile'];
      if (profile is Map && (profile['accountType'] ?? '').toString().toLowerCase() == 'admin') {
        stateAdminCount += 1;
      }
    }

    var dedicatedDoctors = 0;
    for (final doc in doctorDocs) {
      final data = doc.data();
      final hasDedicatedProfile = data['hasDedicatedProfile'] == true;
      final doctorUserId = (data['doctorUserId'] ?? '').toString().trim();
      final acceptsAppointments = data['acceptsAppointments'] != false;
      if (hasDedicatedProfile && doctorUserId.isNotEmpty && acceptsAppointments) {
        dedicatedDoctors += 1;
      }
    }

    final normalDoctors = doctorDocs.length - dedicatedDoctors;
    final adminCount = adminDocs.length > stateAdminCount ? adminDocs.length : stateAdminCount;

    return AdminDashboardStats(
      users: userStateDocs.length,
      admins: adminCount,
      normalDoctors: normalDoctors < 0 ? 0 : normalDoctors,
      dedicatedDoctors: dedicatedDoctors,
      ambulances: ambulanceDocs.length,
      hospitals: hospitalDocs.length,
      bloodBanks: bloodBankDocs.length,
      donors: donorDocs.length,
    );
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _safeAdminDocs({
    required String label,
    required Query<Map<String, dynamic>> query,
  }) async {
    try {
      final snapshot = await query.get();
      return snapshot.docs;
    } on FirebaseException catch (e, stack) {
      DebugLogger.warning('Could not load admin dashboard $label', e);
      DebugLogger.debug(stack.toString());
      return <QueryDocumentSnapshot<Map<String, dynamic>>>[];
    } catch (e, stack) {
      DebugLogger.warning('Could not load admin dashboard $label', e);
      DebugLogger.debug(stack.toString());
      return <QueryDocumentSnapshot<Map<String, dynamic>>>[];
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
      final docId = name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');
      await _doctorCategoriesCol().doc(docId).set({
        'name': name.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      await _safeLogAdminAction(
        action: 'doctor_category_saved',
        targetType: 'doctor_category',
        targetId: docId,
        label: name.trim(),
      );
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
      final normalizedDoctorUserId = doctorUserId?.trim() ?? '';
      final normalizedPatientUid = patientUid?.trim() ?? '';

      if (normalizedDoctorUserId.isEmpty && normalizedPatientUid.isEmpty) {
        return <Map<String, dynamic>>[];
      }

      // Keep this query intentionally single-filter and unsorted.
      // Firestore requires a composite index for queries such as:
      //   where('doctorUserId', isEqualTo: x)
      //   where('patientUid', isEqualTo: y)
      //   orderBy('appointmentAt')
      // That index error was preventing appointment pages from loading.
      // We fetch with one indexed equality filter, then apply the second
      // filter and sort safely on the client.
      Query<Map<String, dynamic>> q = _doctorAppointmentsCol();

      if (normalizedPatientUid.isNotEmpty) {
        q = q.where('patientUid', isEqualTo: normalizedPatientUid);
      } else if (normalizedDoctorUserId.isNotEmpty) {
        q = q.where('doctorUserId', isEqualTo: normalizedDoctorUserId);
      }

      final snapshot = await q.limit(300).get();

      var appointments = snapshot.docs.map((doc) => {...doc.data(), 'id': doc.id}).toList();

      if (normalizedDoctorUserId.isNotEmpty) {
        appointments = appointments.where((appointment) {
          return (appointment['doctorUserId'] ?? '').toString() == normalizedDoctorUserId;
        }).toList();
      }

      if (normalizedPatientUid.isNotEmpty) {
        appointments = appointments.where((appointment) {
          return (appointment['patientUid'] ?? '').toString() == normalizedPatientUid;
        }).toList();
      }

      appointments.sort(_compareAppointmentsByTime);
      return appointments;
    } on FirebaseException catch (e, stack) {
      if (e.code == 'permission-denied') {
        DebugLogger.warning(
          'Skipped doctor appointment query because the signed-in user no longer has permission. This commonly happens during logout.',
          e,
        );
        return <Map<String, dynamic>>[];
      }

      DebugLogger.error('Failed to query doctor appointments', e, stack);
      return <Map<String, dynamic>>[];
    } catch (e, stack) {
      DebugLogger.error('Failed to query doctor appointments', e, stack);
      return <Map<String, dynamic>>[];
    }
  }

  int _compareAppointmentsByTime(Map<String, dynamic> a, Map<String, dynamic> b) {
    final aTime = _appointmentSortValue(a['appointmentAt']);
    final bTime = _appointmentSortValue(b['appointmentAt']);

    final timeCompare = aTime.compareTo(bTime);
    if (timeCompare != 0) return timeCompare;

    return (a['id'] ?? '').toString().compareTo((b['id'] ?? '').toString());
  }

  int _appointmentSortValue(dynamic value) {
    if (value == null) return 0;

    if (value is Timestamp) {
      return value.toDate().millisecondsSinceEpoch;
    }

    if (value is DateTime) {
      return value.millisecondsSinceEpoch;
    }

    final parsed = DateTime.tryParse(value.toString());
    return parsed?.millisecondsSinceEpoch ?? 0;
  }

  Timestamp? _timestampFromDateLike(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value;
    if (value is DateTime) return Timestamp.fromDate(value);
    if (value is String) {
      final parsed = DateTime.tryParse(value);
      return parsed == null ? null : Timestamp.fromDate(parsed);
    }
    if (value is int) {
      try {
        return Timestamp.fromDate(DateTime.fromMillisecondsSinceEpoch(value));
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  Future<String> saveDoctorAppointment(Map<String, dynamic> appointment) async {
    try {
      final docRef = appointment['id'] == null || appointment['id'].toString().isEmpty
          ? _doctorAppointmentsCol().doc()
          : _doctorAppointmentsCol().doc(appointment['id'].toString());
      final cloudAppointment = Map<String, dynamic>.from(appointment);
      cloudAppointment.remove('id');

      final appointmentAt = _timestampFromDateLike(cloudAppointment['appointmentAt']);
      if (appointmentAt != null) {
        cloudAppointment['appointmentAt'] = appointmentAt;
      }

      await docRef.set({
        ...cloudAppointment,
        'updatedAt': FieldValue.serverTimestamp(),
        if (appointment['createdAt'] == null) 'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      return docRef.id;
    } catch (e, stack) {
      DebugLogger.error('Failed to save doctor appointment', e, stack);
      rethrow;
    }
  }

  Future<void> deleteDoctorAppointment(String appointmentId) async {
    final normalizedId = appointmentId.trim();
    if (normalizedId.isEmpty) {
      throw ArgumentError('Appointment ID is required.');
    }

    try {
      await _doctorAppointmentsCol().doc(normalizedId).delete();
    } catch (e, stack) {
      DebugLogger.error('Failed to delete doctor appointment $normalizedId', e, stack);
      rethrow;
    }
  }

  Future<void> updateDoctorAppointmentStatus({
    required String appointmentId,
    required String status,
    String? serialNumber,
  }) async {
    final normalizedId = appointmentId.trim();
    final normalizedStatus = status.trim().toLowerCase();
    final normalizedSerial = serialNumber?.trim();

    if (normalizedId.isEmpty) {
      throw ArgumentError('Appointment ID is required.');
    }

    if (normalizedStatus != 'pending' &&
        normalizedStatus != 'confirmed' &&
        normalizedStatus != 'cancelled' &&
        normalizedStatus != 'completed') {
      throw ArgumentError('Unsupported appointment status: $status');
    }

    try {
      final updates = <String, dynamic>{
        'status': normalizedStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (normalizedStatus == 'confirmed' && normalizedSerial != null && normalizedSerial.isNotEmpty) {
        updates['serialNumber'] = normalizedSerial;
        updates['serialAssignedAt'] = FieldValue.serverTimestamp();
      }

      await _doctorAppointmentsCol().doc(normalizedId).set(
        updates,
        SetOptions(merge: true),
      );
      await _safeLogAdminAction(
        action: 'appointment_status_updated',
        targetType: 'appointment',
        targetId: normalizedId,
        label: normalizedStatus,
        details: {
          'status': normalizedStatus,
          if (normalizedSerial != null && normalizedSerial.isNotEmpty) 'serialNumber': normalizedSerial,
        },
      );
    } catch (e, stack) {
      DebugLogger.error('Failed to update doctor appointment $normalizedId', e, stack);
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
    required String appointmentId,
    required String patientUid,
    required String patientName,
    required double rating,
    String? review,
  }) async {
    final normalizedDoctorId = doctorId.trim();
    final normalizedDoctorUserId = doctorUserId.trim();
    final normalizedAppointmentId = appointmentId.trim();
    final normalizedPatientUid = patientUid.trim();

    if (normalizedDoctorId.isEmpty || normalizedDoctorUserId.isEmpty || normalizedAppointmentId.isEmpty || normalizedPatientUid.isEmpty) {
      throw ArgumentError('Doctor, appointment, and patient identifiers are required to save a rating.');
    }

    try {
      final docId = '${normalizedDoctorId}_$normalizedPatientUid';
      await _doctorRatingsCol().doc(docId).set({
        'doctorId': normalizedDoctorId,
        'doctorUserId': normalizedDoctorUserId,
        'appointmentId': normalizedAppointmentId,
        'patientUid': normalizedPatientUid,
        'patientName': patientName.trim(),
        'rating': rating,
        'review': review?.trim() ?? '',
        'updatedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      await recalculateDoctorRating(normalizedDoctorId);
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

      final profile = _safeParseProfile(data['profile'], userId);
      final logs = _safeParseHealthLogs(data['logs'], userId)
        ..sort((a, b) => b.date.compareTo(a.date));

      final sessions = _safeParseChatSessions(data['chatSessions'], userId);
      var activeChatSessionId = _safeString(data['activeChatSessionId']);

      List<ChatSession> normalizedSessions;

      if (sessions.isNotEmpty) {
        normalizedSessions = sessions
            .map(
              (session) => session.copyWith(
                messages: [...session.messages]
                  ..sort((a, b) => a.timestamp.compareTo(b.timestamp)),
              ),
            )
            .toList();

        final activeExists = normalizedSessions.any(
          (session) => session.id == activeChatSessionId,
        );

        if (activeChatSessionId == null || !activeExists) {
          activeChatSessionId = normalizedSessions.first.id;
        }
      } else {
        final legacyMessages = _safeParseChatMessages(data['chatMessages'], userId)
          ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

        normalizedSessions = [
          ChatSession(
            id: 'default',
            title: _legacyChatTitle(legacyMessages),
            createdAt: legacyMessages.isEmpty ? DateTime.now() : legacyMessages.first.timestamp,
            updatedAt: legacyMessages.isEmpty ? DateTime.now() : legacyMessages.last.timestamp,
            messages: legacyMessages,
          ),
        ];
        activeChatSessionId = 'default';
      }

      return CloudUserState(
        profile: profile,
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

  UserProfile _safeParseProfile(dynamic value, String userId) {
    try {
      return UserProfile.fromMap(_safeMap(value));
    } catch (e, stack) {
      DebugLogger.warning('Skipped invalid profile data for $userId. Using an empty profile instead.', e, stack);
      return UserProfile.empty();
    }
  }

  List<HealthLog> _safeParseHealthLogs(dynamic value, String userId) {
    final items = _safeList(value);
    final parsed = <HealthLog>[];

    for (var i = 0; i < items.length; i += 1) {
      try {
        final map = _safeMap(items[i]);
        if (map.isEmpty) continue;
        parsed.add(HealthLog.fromMap(map));
      } catch (e, stack) {
        DebugLogger.warning('Skipped invalid health log #$i for $userId', e, stack);
      }
    }

    return parsed;
  }

  List<ChatSession> _safeParseChatSessions(dynamic value, String userId) {
    final items = _safeList(value);
    final parsed = <ChatSession>[];

    for (var i = 0; i < items.length; i += 1) {
      try {
        final map = _safeMap(items[i]);
        if (map.isEmpty) continue;
        parsed.add(ChatSession.fromMap(map));
      } catch (e, stack) {
        DebugLogger.warning('Skipped invalid chat session #$i for $userId', e, stack);
      }
    }

    return parsed;
  }

  List<ChatMessage> _safeParseChatMessages(dynamic value, String userId) {
    final items = _safeList(value);
    final parsed = <ChatMessage>[];

    for (var i = 0; i < items.length; i += 1) {
      try {
        final map = _safeMap(items[i]);
        if (map.isEmpty) continue;
        parsed.add(ChatMessage.fromMap(map));
      } catch (e, stack) {
        DebugLogger.warning('Skipped invalid legacy chat message #$i for $userId', e, stack);
      }
    }

    return parsed;
  }

  List<dynamic> _safeList(dynamic value) {
    if (value is List) return value;
    if (value is Iterable) return value.toList();
    return const [];
  }

  Map<String, dynamic> _safeMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((key, dynamic mapValue) => MapEntry(key.toString(), mapValue));
    }
    return <String, dynamic>{};
  }

  String? _safeString(dynamic value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  String _legacyChatTitle(List<ChatMessage> messages) {
    if (messages.isEmpty) return 'New chat';

    final firstUserMessage = messages.firstWhere(
      (message) => message.isUser,
      orElse: () => messages.first,
    );

    final title = firstUserMessage.text.trim().split(RegExp(r'\s+')).take(5).join(' ');
    return title.isEmpty ? 'New chat' : title;
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



  /// Updates the public doctor directory document linked to this Firebase user.
  /// This keeps the doctor's own profile changes visible on the doctor home page
  /// and in the public doctor list without allowing the doctor to edit protected
  /// fields such as rating, appointment flags, or the linked UID.
  /// Finds a public doctor directory document by the Firebase Auth email.
  /// This is a fallback for older doctor records where doctorUserId may be
  /// missing or was not linked correctly during earlier app versions.
  Future<Map<String, dynamic>?> getDoctorByEmail(String email) async {
    try {
      final normalized = email.trim().toLowerCase();
      if (normalized.isEmpty) return null;

      final byDoctorEmail = await _firestore
          .collection('doctors')
          .where('doctorEmail', isEqualTo: normalized)
          .limit(1)
          .get();

      if (byDoctorEmail.docs.isNotEmpty) {
        final doc = byDoctorEmail.docs.first;
        return {...doc.data(), 'id': doc.id};
      }

      final byEmail = await _firestore
          .collection('doctors')
          .where('email', isEqualTo: normalized)
          .limit(1)
          .get();

      if (byEmail.docs.isNotEmpty) {
        final doc = byEmail.docs.first;
        return {...doc.data(), 'id': doc.id};
      }

      return null;
    } catch (e, stack) {
      DebugLogger.error('Failed to get doctor by email', e, stack);
      return null;
    }
  }



  /// Updates the public doctor directory document linked to this Firebase user.
  ///
  /// The app has two profile stores for dedicated doctors:
  /// 1. /users/{uid}/app/state          -> private profile/settings
  /// 2. /doctors/{doctorDocId}          -> public doctor list/home/profile
  ///
  /// Updating only the private profile makes Settings show the new name while
  /// the doctor list still shows the old one. This method keeps both in sync.
  /// It returns false when no linked public doctor document can be found.
  Future<bool> updateLinkedDoctorProfileFromUserProfile({
    required String userId,
    required UserProfile profile,
    String? authEmail,
  }) async {
    try {
      if (userId.trim().isEmpty) return false;

      Map<String, dynamic>? doctor = await getDoctorByUserId(userId);

      // Fallback for older/corrupted records where doctorUserId is missing but
      // the doctorEmail still matches the Auth account.
      doctor ??= await getDoctorByEmail(authEmail ?? '');
      doctor ??= await getDoctorByEmail(profile.email);

      final doctorId = (doctor?['id'] ?? '').toString().trim();
      if (doctorId.isEmpty) {
        DebugLogger.warning('No linked public doctor document found for user $userId');
        return false;
      }

      final name = profile.name.trim();
      final email = profile.email.trim().toLowerCase();
      final authEmailValue = (authEmail ?? '').trim().toLowerCase();
      final contactInfo = profile.contactInfo.trim();
      final professionalSummary = profile.healthGoals.trim();
      final division = profile.division.trim();
      final district = profile.district.trim();

      final updates = <String, dynamic>{
        if (name.isNotEmpty) 'name': name,
        if (name.isNotEmpty) 'displayName': name,
        if (email.isNotEmpty) 'doctorEmail': email,
        if (authEmailValue.isNotEmpty) 'authEmail': authEmailValue,
        'contact': contactInfo,
        'contactInfo': contactInfo,
        if (professionalSummary.isNotEmpty) 'specialtySummary': professionalSummary,
        if (professionalSummary.isNotEmpty) 'details': professionalSummary,
        if (professionalSummary.isNotEmpty) 'qualification': professionalSummary,
        if (division.isNotEmpty) 'division': division,
        if (district.isNotEmpty) 'district': district,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (updates.length <= 1) return false;

      await _firestore.collection('doctors').doc(doctorId).set(
            updates,
            SetOptions(merge: true),
          );

      DebugLogger.info('Synced public doctor profile for $userId to doctors/$doctorId');
      return true;
    } catch (e, stack) {
      DebugLogger.error('Failed to sync linked doctor public profile', e, stack);
      rethrow;
    }
  }

  Future<String> saveDoctor(Map<String, dynamic> doctor) async {
    try {
      final docRef = doctor['id'] == null || doctor['id'].toString().isEmpty
          ? _firestore.collection('doctors').doc()
          : _firestore.collection('doctors').doc(doctor['id'].toString());
      final isNew = doctor['id'] == null || doctor['id'].toString().isEmpty;
      await docRef.set({...doctor, 'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
      await _safeLogAdminAction(
        action: isNew ? 'doctor_created' : 'doctor_updated',
        targetType: 'doctor',
        targetId: docRef.id,
        label: (doctor['name'] ?? doctor['displayName'] ?? 'Doctor').toString(),
        details: {
          'category': (doctor['category'] ?? '').toString(),
          'district': (doctor['district'] ?? '').toString(),
          'dedicated': doctor['hasDedicatedProfile'] == true,
        },
      );
      return docRef.id;
    } catch (e, stack) {
      DebugLogger.error('Failed to save doctor', e, stack);
      rethrow;
    }
  }

  Future<void> deleteDoctor(String id) async {
    final normalizedId = id.trim();
    if (normalizedId.isEmpty) {
      throw ArgumentError('Doctor ID is required.');
    }

    try {
      final snapshot = await _firestore.collection('doctors').doc(normalizedId).get();
      final data = snapshot.data();
      if (data == null) {
        await _firestore.collection('doctors').doc(normalizedId).delete();
        return;
      }

      await deleteDoctorCompletely({
        ...data,
        'id': normalizedId,
      });
    } catch (e, stack) {
      DebugLogger.error('Failed to delete doctor $normalizedId', e, stack);
      rethrow;
    }
  }

  Future<void> deleteDoctorCompletely(Map<String, dynamic> doctor) async {
    final doctorId = (doctor['id'] ?? '').toString().trim();
    final doctorUserId = (doctor['doctorUserId'] ?? '').toString().trim();

    if (doctorId.isEmpty) {
      throw ArgumentError('Doctor ID is required.');
    }

    try {
      // Remove appointment records that are attached to this doctor directory
      // document. This covers normal listed doctors and older records.
      await _deleteQueryDocuments(
        _doctorAppointmentsCol().where('doctorId', isEqualTo: doctorId),
        'appointments for doctor document $doctorId',
      );

      // Remove rating records attached to the doctor document.
      await _deleteQueryDocuments(
        _doctorRatingsCol().where('doctorId', isEqualTo: doctorId),
        'ratings for doctor document $doctorId',
      );

      if (doctorUserId.isNotEmpty) {
        // Dedicated doctors also have a private user app-state document and may
        // have appointment/rating records linked by doctorUserId. Remove all of
        // those database records as part of the doctor deletion.
        await _deleteAppointmentsForUser(doctorUserId);
        await _deleteRatingsForDoctorUser(doctorUserId);
        await deleteUserState(doctorUserId);

        // Clean optional records if this account ever created them through older
        // app versions. These deletes are safe when the documents do not exist.
        await deleteDonor(doctorUserId);

        // Remove any duplicate/legacy doctor directory documents linked to this
        // same Firebase user ID, not only the visible card that was tapped.
        await _deleteQueryDocuments(
          _firestore.collection('doctors').where('doctorUserId', isEqualTo: doctorUserId),
          'doctor directory records for doctor user $doctorUserId',
        );
      }

      // Ensure the selected doctor document is removed even if it had no
      // doctorUserId or if the linked-profile query did not include it.
      await _firestore.collection('doctors').doc(doctorId).delete();

      await _safeLogAdminAction(
        action: 'doctor_deleted',
        targetType: 'doctor',
        targetId: doctorId,
        label: (doctor['name'] ?? doctor['displayName'] ?? 'Doctor').toString(),
        details: {
          'doctorUserId': doctorUserId,
          'dedicated': doctorUserId.isNotEmpty,
        },
      );

      DebugLogger.info('Deleted complete doctor database profile for $doctorId');
    } catch (e, stack) {
      DebugLogger.error('Failed to delete complete doctor database profile for $doctorId', e, stack);
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
      final isNew = resource['id'] == null || resource['id'].toString().isEmpty;
      await docRef.set({...resource, 'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
      await _safeLogAdminAction(
        action: isNew ? 'emergency_resource_created' : 'emergency_resource_updated',
        targetType: 'emergency_resource',
        targetId: docRef.id,
        label: (resource['name'] ?? 'Emergency resource').toString(),
        details: {
          'type': (resource['type'] ?? '').toString(),
          'district': (resource['district'] ?? '').toString(),
        },
      );
      return docRef.id;
    } catch (e, stack) {
      DebugLogger.error('Failed to save emergency resource', e, stack);
      rethrow;
    }
  }

  Future<void> deleteEmergencyResource(String id) async {
    try {
      await _firestore.collection('emergency_resources').doc(id).delete();
      await _safeLogAdminAction(
        action: 'emergency_resource_deleted',
        targetType: 'emergency_resource',
        targetId: id,
        label: id,
      );
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
      // Donor records are public-readable, so overwrite the document instead of
      // merging. This removes old/stale sensitive fields that may have been saved
      // by earlier app versions, such as email, health goals, known conditions,
      // height, or weight.
      await docRef.set({
        ...donor,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return docRef.id;
    } catch (e, stack) {
      DebugLogger.error('Failed to save donor', e, stack);
      rethrow;
    }
  }


  Future<void> deleteAccountOwnedData({
    required String userId,
    String? email,
  }) async {
    final normalizedUserId = userId.trim();
    final normalizedEmail = email?.trim().toLowerCase() ?? '';

    if (normalizedUserId.isEmpty) {
      throw ArgumentError('User ID is required for account data deletion.');
    }

    try {
      // Remove appointments where this account is either the patient or the
      // assigned doctor. This must happen before the Auth account is deleted,
      // because Firestore rules still need request.auth.uid.
      await _deleteAppointmentsForUser(normalizedUserId);

      // Remove ratings written by this user and refresh affected doctor rating
      // aggregates while the user's rating document still exists.
      await _deleteRatingsAuthoredByUser(normalizedUserId);

      // If this account belongs to a dedicated doctor, remove ratings attached
      // to that doctor profile and then remove the public doctor directory doc.
      await _deleteRatingsForDoctorUser(normalizedUserId);
      await _deleteLinkedDoctorProfilesForUser(normalizedUserId);

      // Remove optional public donor record, admin registry records, and the
      // private app-state document last.
      await deleteDonor(normalizedUserId);
      await _deleteAdminRecordsForUser(
        userId: normalizedUserId,
        email: normalizedEmail,
      );
      await deleteUserState(normalizedUserId);

      DebugLogger.info('Deleted complete cloud account data for $normalizedUserId');
    } catch (e, stack) {
      DebugLogger.error('Failed to delete complete account data for $normalizedUserId', e, stack);
      rethrow;
    }
  }

  Future<void> _deleteAppointmentsForUser(String userId) async {
    await _deleteQueryDocuments(
      _doctorAppointmentsCol().where('patientUid', isEqualTo: userId),
      'patient appointments for $userId',
    );

    await _deleteQueryDocuments(
      _doctorAppointmentsCol().where('doctorUserId', isEqualTo: userId),
      'doctor appointments for $userId',
    );
  }

  Future<void> _deleteRatingsAuthoredByUser(String userId) async {
    final docs = await _getAllQueryDocuments(
      _doctorRatingsCol().where('patientUid', isEqualTo: userId),
    );

    final doctorIds = <String>{};
    for (final doc in docs) {
      final doctorId = (doc.data()['doctorId'] ?? '').toString().trim();
      if (doctorId.isNotEmpty) doctorIds.add(doctorId);
    }

    // Refresh each affected doctor's aggregate before deleting the user's rating.
    // The rules allow this while the current user's rating document still exists.
    for (final doctorId in doctorIds) {
      await _recalculateDoctorRatingExcludingPatient(
        doctorId: doctorId,
        excludedPatientUid: userId,
      );
    }

    await _deleteSnapshotDocuments(
      docs,
      'doctor ratings authored by $userId',
    );
  }

  Future<void> _deleteRatingsForDoctorUser(String userId) async {
    await _deleteQueryDocuments(
      _doctorRatingsCol().where('doctorUserId', isEqualTo: userId),
      'doctor ratings for doctor user $userId',
    );
  }

  Future<void> _deleteLinkedDoctorProfilesForUser(String userId) async {
    await _deleteQueryDocuments(
      _firestore.collection('doctors').where('doctorUserId', isEqualTo: userId),
      'linked public doctor profiles for $userId',
    );
  }

  Future<void> _deleteAdminRecordsForUser({
    required String userId,
    required String email,
  }) async {
    final refs = <DocumentReference<Map<String, dynamic>>>{
      _adminDoc(userId),
      if (email.isNotEmpty) _adminDoc(email),
    };

    for (final ref in refs) {
      await ref.delete();
    }
  }

  Future<void> _recalculateDoctorRatingExcludingPatient({
    required String doctorId,
    required String excludedPatientUid,
  }) async {
    final normalizedDoctorId = doctorId.trim();
    if (normalizedDoctorId.isEmpty) return;

    final doctorRef = _firestore.collection('doctors').doc(normalizedDoctorId);
    final doctorSnapshot = await doctorRef.get();
    if (!doctorSnapshot.exists) {
      return;
    }

    final docs = await _getAllQueryDocuments(
      _doctorRatingsCol().where('doctorId', isEqualTo: normalizedDoctorId),
    );

    final ratings = docs
        .where((doc) => (doc.data()['patientUid'] ?? '').toString() != excludedPatientUid)
        .map((doc) => (doc.data()['rating'] as num?)?.toDouble() ?? 0)
        .where((rating) => rating >= 1 && rating <= 5)
        .toList();

    final average = ratings.isEmpty
        ? 0.0
        : ratings.reduce((a, b) => a + b) / ratings.length;

    await doctorRef.set(
      {
        'rating': average,
        'ratingCount': ratings.length,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _getAllQueryDocuments(
    Query<Map<String, dynamic>> query, {
    int pageSize = 450,
  }) async {
    final docs = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
    Query<Map<String, dynamic>> pageQuery = query.orderBy(FieldPath.documentId).limit(pageSize);

    while (true) {
      final snapshot = await pageQuery.get();
      if (snapshot.docs.isEmpty) break;

      docs.addAll(snapshot.docs);
      if (snapshot.docs.length < pageSize) break;

      pageQuery = query
          .orderBy(FieldPath.documentId)
          .startAfterDocument(snapshot.docs.last)
          .limit(pageSize);
    }

    return docs;
  }

  Future<void> _deleteQueryDocuments(
    Query<Map<String, dynamic>> query,
    String label,
  ) async {
    final docs = await _getAllQueryDocuments(query);
    await _deleteSnapshotDocuments(docs, label);
  }

  Future<void> _deleteSnapshotDocuments(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    String label,
  ) async {
    if (docs.isEmpty) return;

    const chunkSize = 450;
    for (var start = 0; start < docs.length; start += chunkSize) {
      final end = (start + chunkSize) > docs.length ? docs.length : start + chunkSize;
      final batch = _firestore.batch();

      for (final doc in docs.sublist(start, end)) {
        batch.delete(doc.reference);
      }

      await batch.commit();
    }

    DebugLogger.info('Deleted ${docs.length} $label');
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
