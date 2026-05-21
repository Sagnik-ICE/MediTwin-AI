import 'package:flutter/material.dart';

// removed unused import
import '../models/chat_message.dart';
import '../models/chat_session.dart';
import '../models/health_log.dart';
import '../models/reminder_preferences.dart';
import '../models/reminder_schedule.dart';
import '../models/user_profile.dart';
import 'dart:convert';

import '../services/ai_service.dart';
import '../utils/debug_logger.dart';
import '../services/emergency_service.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/health_score_service.dart';
import '../services/risk_detection_service.dart';
import '../services/simulation_service.dart';
import '../services/storage_service.dart';
import '../services/local_db.dart';

class AppState extends ChangeNotifier {
  static const String mainAdminEmail = 'dibbay242-50-014@diu.edu.bd';

  factory AppState({
    required StorageService storageService,
    required AiService aiService,
    required AuthService authService,
    required FirestoreService firestoreService,
  }) {
    return AppState._internal(
      storageService: storageService,
      aiService: aiService,
      authService: authService,
      firestoreService: firestoreService,
    );
  }

  AppState._internal({
    required this._storageService,
    required this._aiService,
    required this._authService,
    required this._firestoreService,
  });

  final StorageService _storageService;
  final AiService _aiService;
  final AuthService _authService;
  final FirestoreService _firestoreService;

  bool initialized = false;
  bool darkMode = false;
  bool loggedIn = false;
  bool isAdmin = false;
  bool get isMainAdmin => _authService.currentUserEmail?.toLowerCase() == mainAdminEmail.toLowerCase();
  String? get currentUserEmail => _authService.currentUserEmail;
  bool onboardingCompleted = false;
  bool isChatLoading = false;
  String chatMode = 'General';
  String apiUrl = '';
  String modelInfo = 'qwen3:8b-q4_K_M (local backend expected)';
  ReminderPreferences reminderPreferences = ReminderPreferences.defaults();
  ReminderSchedule reminderSchedule = ReminderSchedule.defaults();

  UserProfile profile = UserProfile.empty();
  List<HealthLog> logs = [];
  List<ChatSession> chatSessions = [];
  String? activeChatSessionId;

  List<ChatMessage> get chatMessages => _activeChatSession.messages;

  ChatSession get _activeChatSession {
    if (chatSessions.isEmpty) {
      final session = _createChatSession();
      chatSessions = [session];
      activeChatSessionId = session.id;
      return session;
    }

    final activeIndex = chatSessions.indexWhere((session) => session.id == activeChatSessionId);
    if (activeIndex >= 0) {
      return chatSessions[activeIndex];
    }

    activeChatSessionId = chatSessions.first.id;
    return chatSessions.first;
  }

  Future<void> init() async {
    await _authService.initializeFirebase();
    loggedIn = _authService.isLoggedIn;
    isAdmin = _authService.isAdmin || isMainAdmin;
    darkMode = await _storageService.getDarkMode();
    apiUrl = await _storageService.getApiUrl();
    reminderPreferences = await _storageService.loadReminderPreferences();
    reminderSchedule = await _storageService.loadReminderSchedule();
    profile = UserProfile.empty();
    logs = [];
    chatSessions = [];
    activeChatSessionId = null;

    // initialize local DB (file-backed) for offline cache
    await LocalDb.init();

    if (loggedIn) {
      await _authService.refreshClaims();
      await _refreshAdminStatus();
      await _pullCloudStateIfAvailable();
      // If cloud returned no logs, try loading local cache as a fallback
      if (logs.isEmpty) {
        final local = await LocalDb.loadHealthLogs();
        if (local.isNotEmpty) {
          logs = local;
        }
      }
    } else {
      // not logged in — load local cache so user still sees recent entries
      logs = await LocalDb.loadHealthLogs();
      _ensureChatSession();
    }

    initialized = true;
    notifyListeners();
  }

  int get todayScore => logs.isEmpty ? 0 : logs.first.healthScore;

  List<String> get memoryHints {
    if (logs.isEmpty) {
      return const ['No health logs yet'];
    }
    final latest = logs.first;
    return [
      weeklyMemorySummary,
      'Latest score ${latest.healthScore}',
      'Sleep ${latest.sleepHours}h',
      'Stress ${latest.stressLevel}/10',
      'Hydration ${latest.waterGlasses} glasses',
      if (latest.riskFlags.isNotEmpty) latest.riskFlags.first,
      if (profile.healthGoals.isNotEmpty) 'Goal focus: ${profile.healthGoals}',
    ];
  }

  String get weeklyMemorySummary {
    if (logs.isEmpty) {
      return 'Weekly trend unavailable: no logs yet.';
    }

    final week = logs.take(7).toList();
    final avgScore = week.map((e) => e.healthScore).reduce((a, b) => a + b) / week.length;
    final avgSleep = week.map((e) => e.sleepHours).reduce((a, b) => a + b) / week.length;
    final avgStress = week.map((e) => e.stressLevel).reduce((a, b) => a + b) / week.length;
    final hydrationDays = week.where((e) => e.waterGlasses >= 8).length;

    return 'Weekly summary: avg score ${avgScore.toStringAsFixed(0)}, sleep ${avgSleep.toStringAsFixed(1)}h, stress ${avgStress.toStringAsFixed(1)}/10, hydration target met $hydrationDays/${week.length} days.';
  }

  String get personalizedInsight {
    final latest = logs.isNotEmpty ? logs.first : null;
    final base = latest?.insight ?? 'Start tracking daily to generate your personalized insight.';
    return '$base Goal focus: ${profile.healthGoals}.';
  }

  Future<void> addHealthLog({
    required double sleepHours,
    required int waterGlasses,
    required int stressLevel,
    required String mood,
    required int exerciseMinutes,
    required List<String> symptoms,
    required String foodQuality,
    required double weight,
    required String notes,
  }) async {
    final score = HealthScoreService.calculateScore(
      sleepHours: sleepHours,
      waterGlasses: waterGlasses,
      stressLevel: stressLevel,
      mood: mood,
      exerciseMinutes: exerciseMinutes,
      symptoms: symptoms,
    );

    final rawLog = HealthLog(
      date: DateTime.now(),
      sleepHours: sleepHours,
      waterGlasses: waterGlasses,
      stressLevel: stressLevel,
      mood: mood,
      exerciseMinutes: exerciseMinutes,
      symptoms: symptoms,
      foodQuality: foodQuality,
      weight: weight,
      notes: notes,
      healthScore: score,
      riskFlags: const [],
      insight: '',
    );

    final riskFlags = RiskDetectionService.detectRisks(rawLog, [rawLog, ...logs]);

    final finalLog = HealthLog(
      date: rawLog.date,
      sleepHours: rawLog.sleepHours,
      waterGlasses: rawLog.waterGlasses,
      stressLevel: rawLog.stressLevel,
      mood: rawLog.mood,
      exerciseMinutes: rawLog.exerciseMinutes,
      symptoms: rawLog.symptoms,
      foodQuality: rawLog.foodQuality,
      weight: rawLog.weight,
      notes: rawLog.notes,
      healthScore: rawLog.healthScore,
      riskFlags: riskFlags,
      insight: HealthScoreService.buildInsight(rawLog),
    );

    logs = [finalLog, ...logs];
    // Prefer cloud sync; if unavailable or fails, persist locally.
    try {
      if (_authService.canUseFirebase && _authService.currentUserId != null) {
        await _syncCloudStateIfAvailable();
      } else {
        await LocalDb.appendHealthLog(finalLog);
      }
    } catch (e, st) {
      DebugLogger.warning('Failed to sync health log to cloud, saving locally', e);
      DebugLogger.debug(st.toString());
      await LocalDb.appendHealthLog(finalLog);
    }
    notifyListeners();
  }

  Future<void> askAssistant(String userText) async {
    await askAssistantWithMode(userText, chatMode: chatMode);
  }

  Future<void> askAssistantWithMode(String userText, {required String chatMode}) async {
    final currentSession = _ensureChatSession();
    final userMessage = ChatMessage(
      text: userText,
      isUser: true,
      timestamp: DateTime.now(),
    );
    _replaceActiveChatSession(
      currentSession.copyWith(
        title: _titleForSession(currentSession, userText),
        updatedAt: DateTime.now(),
        messages: [...currentSession.messages, userMessage],
      ),
    );
    isChatLoading = true;
    notifyListeners();
    // If no API URL configured, short-circuit with clear instruction.
    if (apiUrl.trim().isEmpty) {
      final assistantMessage = ChatMessage(
        text: 'AI server not configured. Please open Settings → AI Endpoint and enter your laptop\'s IP and port (e.g. 192.168.1.5:11434), then tap "Test Connection".',
        isUser: false,
        timestamp: DateTime.now(),
        isError: true,
      );

      _appendToActiveChat(assistantMessage);
      isChatLoading = false;
      notifyListeners();
      return;
    }

    String answer;
    try {
      answer = await _aiService.askAssistant(
        prompt: userText,
        apiUrl: apiUrl,
        memoryHints: memoryHints,
        chatMode: chatMode,
      );
    } catch (e, st) {
      DebugLogger.warning('askAssistant threw exception', e);
      DebugLogger.debug(st.toString());
      answer = AiService.fallbackConnectionMessage;
    }

    final isError = answer == AiService.fallbackConnectionMessage || answer == EmergencyService.emergencyWarning;

    final assistantMessage = ChatMessage(
      text: answer,
      isUser: false,
      timestamp: DateTime.now(),
      isError: isError,
    );

    _appendToActiveChat(assistantMessage);
    isChatLoading = false;
    await _syncCloudStateIfAvailable();
    notifyListeners();
  }

  Future<void> setChatMode(String value) async {
    chatMode = value;
    notifyListeners();
  }

  Future<void> removeChatMessageAt(int index) async {
    final session = _ensureChatSession();
    if (index < 0 || index >= session.messages.length) {
      return;
    }

    final updatedMessages = [...session.messages]..removeAt(index);
    _replaceActiveChatSession(session.copyWith(messages: updatedMessages, updatedAt: DateTime.now()));
    await _syncCloudStateIfAvailable();
    notifyListeners();
  }

  Future<void> clearChatHistory() async {
    final session = _ensureChatSession();
    _replaceActiveChatSession(session.copyWith(messages: [], title: 'New chat', updatedAt: DateTime.now()));
    await _syncCloudStateIfAvailable();
    notifyListeners();
  }

  Future<void> startNewChat() async {
    final session = _createChatSession();
    chatSessions = [session, ...chatSessions];
    activeChatSessionId = session.id;
    await _syncCloudStateIfAvailable();
    notifyListeners();
  }

  Future<void> selectChatSession(String sessionId) async {
    if (chatSessions.any((session) => session.id == sessionId)) {
      activeChatSessionId = sessionId;
      await _syncCloudStateIfAvailable();
      notifyListeners();
    }
  }

  Future<void> renameChatSession(String sessionId, String title) async {
    final normalized = title.trim();
    if (normalized.isEmpty) {
      return;
    }

    final index = chatSessions.indexWhere((session) => session.id == sessionId);
    if (index == -1) {
      return;
    }

    final updated = chatSessions[index].copyWith(title: normalized, updatedAt: DateTime.now());
    chatSessions = [...chatSessions]..[index] = updated;
    await _syncCloudStateIfAvailable();
    notifyListeners();
  }

  Future<void> deleteChatSession(String sessionId) async {
    if (chatSessions.length <= 1) {
      await clearChatHistory();
      return;
    }

    chatSessions = [...chatSessions]..removeWhere((session) => session.id == sessionId);
    if (activeChatSessionId == sessionId) {
      activeChatSessionId = chatSessions.first.id;
    }
    await _syncCloudStateIfAvailable();
    notifyListeners();
  }

  Map<String, dynamic> runSimulation(String scenario) {
    return SimulationService.simulate(scenario: scenario, history: logs);
  }

  Future<void> updateProfile(UserProfile newProfile) async {
    profile = newProfile;
    await _syncDonorRecordIfNeeded();
    await _syncCloudStateIfAvailable();
    notifyListeners();
  }

  Future<void> setDarkMode(bool enabled) async {
    darkMode = enabled;
    await _storageService.setDarkMode(enabled);
    notifyListeners();
  }

  Future<void> setApiUrl(String value) async {
    apiUrl = value;
    await _storageService.setApiUrl(value);
    notifyListeners();
  }

  Future<void> setReminderPreferences(ReminderPreferences value) async {
    reminderPreferences = value;
    await _storageService.saveReminderPreferences(value);
    notifyListeners();
  }

  Future<void> setReminderSchedule(ReminderSchedule value) async {
    reminderSchedule = value;
    await _storageService.saveReminderSchedule(value);
    notifyListeners();
  }

  Future<bool> testBackendConnection() async {
    return _aiService.testConnection(apiUrl);
  }

  Future<String?> login(String email, String password) async {
    final error = await _authService.login(email: email, password: password);
    if (error == null) {
      loggedIn = true;
      _resetUserSessionState();
      await _refreshAdminStatus();
      await _pullCloudStateIfAvailable();
      notifyListeners();
    }
    return error;
  }

  Future<String?> register(String email, String password) async {
    final error = await _authService.register(email: email, password: password);
    if (error == null) {
      loggedIn = true;
      _resetUserSessionState();
      await _refreshAdminStatus();
      await _pullCloudStateIfAvailable();
      notifyListeners();
    }
    return error;
  }


  Future<void> completeOnboarding(UserProfile value) async {
    profile = value;
    onboardingCompleted = true;
    await _syncCloudStateIfAvailable();
    notifyListeners();
  }

  Future<void> logout() async {
    loggedIn = false;
    isAdmin = false;
    await _authService.logout();
    await LocalDb.saveHealthLogs([]);
    _resetUserSessionState();
    notifyListeners();
  }

  void _resetUserSessionState() {
    profile = UserProfile.empty();
    logs = [];
    chatSessions = [];
    activeChatSessionId = null;
    onboardingCompleted = false;
    isChatLoading = false;
  }

  Future<void> _refreshAdminStatus() async {
    await _authService.refreshClaims();
    final email = _authService.currentUserEmail?.toLowerCase();
    final uid = _authService.currentUserId;
    final emailIsAdmin = email != null && await _firestoreService.isAdminEmail(email);
    final uidIsAdmin = uid != null && uid.isNotEmpty && await _firestoreService.isAdminUid(uid);
    isAdmin = _authService.isAdmin || email == mainAdminEmail || emailIsAdmin || uidIsAdmin;
  }

  /// Public helper to refresh auth-related state and pull cloud user state.
  Future<void> refreshAuthState() async {
    await _refreshAdminStatus();
    await _pullCloudStateIfAvailable();
    notifyListeners();
  }

  Future<void> _pullCloudStateIfAvailable() async {
    if (!_authService.canUseFirebase) {
      return;
    }

    final userId = _authService.currentUserId;
    if (userId == null) {
      return;
    }

    try {
      final cloudState = await _firestoreService.loadUserState(userId);
      if (cloudState == null) {
        await _syncCloudStateIfAvailable();
        return;
      }

      profile = cloudState.profile;
      logs = cloudState.logs;
      chatSessions = cloudState.chatSessions;
      activeChatSessionId = cloudState.activeChatSessionId ?? (chatSessions.isNotEmpty ? chatSessions.first.id : null);
      onboardingCompleted = cloudState.onboardingCompleted;
    } catch (e, st) {
      DebugLogger.warning('Failed to pull cloud state', e);
      DebugLogger.debug(st.toString());
    }
  }

  /// Send a password reset email using AuthService.
  Future<String?> sendPasswordReset(String email) async {
    return _authService.sendPasswordReset(email: email);
  }

  /// Export user data as a JSON string for sharing or backup.
  Future<String> exportUserData() async {
    final map = {
      'profile': profile.toMap(),
      'logs': logs.map((e) => e.toMap()).toList(),
      'chatSessions': chatSessions.map((session) => session.toMap()).toList(),
      'activeChatSessionId': activeChatSessionId,
    };
    return jsonEncode(map);
  }

  /// Delete user cloud data and attempt to delete the authentication account.
  Future<String?> deleteAccount({String? password}) async {
    if (password == null || password.trim().isEmpty) {
      return 'Password is required to delete the account.';
    }

    try {
      if (_authService.canUseFirebase) {
        final userId = _authService.currentUserId;
        if (userId != null) {
          await _firestoreService.deleteDonor(userId);
          await _firestoreService.deleteUserState(userId);
        }
      }
    } catch (e, st) {
      DebugLogger.warning('Failed to delete cloud user state', e);
      DebugLogger.debug(st.toString());
      return 'Failed to remove cloud data';
    }

    final authResult = await _authService.reauthenticateAndDeleteWithPassword(password: password);
    if (authResult != null) return authResult;

    // Clear local data
    logs = [];
    chatSessions = [];
    activeChatSessionId = null;
    profile = UserProfile.empty();
    await LocalDb.saveHealthLogs([]);
    notifyListeners();
    return null;
  }

  Future<String?> changePassword({required String currentPassword, required String newPassword}) async {
    return _authService.reauthenticateAndUpdatePassword(currentPassword: currentPassword, newPassword: newPassword);
  }

  Future<List<Map<String, dynamic>>> loadAdmins() async {
    return _firestoreService.loadAdmins();
  }

  Future<String?> addAdmin({required String email, required String displayName, required String password}) async {
    if (!isMainAdmin) {
      return 'Only the main admin can add new admins.';
    }
    final uid = await _authService.provisionUserAccount(email: email, password: password);
    if (uid == null || uid.isEmpty) {
      return 'Failed to create the admin account.';
    }
    if (uid.contains('failed') || uid.contains('enter a valid') || uid.contains('password') || uid.contains('email')) {
      return uid;
    }
    await _firestoreService.saveAdmin(
      email: email,
      displayName: displayName,
      addedBy: _authService.currentUserId ?? '',
      uid: uid,
    );
    await _refreshAdminStatus();
    return null;
  }

  Future<void> removeAdmin(String adminId) async {
    if (!isMainAdmin) {
      return;
    }
    await _firestoreService.deleteAdmin(adminId);
  }

  String get aiServerIp => apiUrl;

  Future<void> setAiServerIp(String value) async {
    await setApiUrl(value);
  }

  Future<bool> testAiConnection() async {
    return testBackendConnection();
  }

  Future<void> _syncCloudStateIfAvailable() async {
    if (!_authService.canUseFirebase) {
      return;
    }

    final userId = _authService.currentUserId;
    if (userId == null) {
      return;
    }

    try {
      await _firestoreService.saveUserState(
        userId: userId,
        profile: profile,
        logs: logs,
        chatSessions: chatSessions,
        activeChatSessionId: activeChatSessionId,
        onboardingCompleted: onboardingCompleted,
      );
      await _syncDonorRecordIfNeeded();
    } catch (e, st) {
      DebugLogger.warning('Failed to sync cloud state', e);
      DebugLogger.debug(st.toString());
    }
  }

  Future<void> _syncDonorRecordIfNeeded() async {
    if (!_authService.canUseFirebase) {
      return;
    }

    final userId = _authService.currentUserId;
    final email = _authService.currentUserEmail;
    if (userId == null || email == null || email.isEmpty) {
      return;
    }

    if (!profile.isBloodDonor) {
      await _firestoreService.deleteDonor(userId);
      return;
    }

    await _firestoreService.saveDonor({
      'id': userId,
      'name': profile.name,
      'email': email,
      'contactInfo': profile.donorContactInfo,
      'bloodGroup': profile.bloodGroup,
      'gender': profile.gender,
      'age': profile.age,
      'heightCm': profile.heightCm,
      'weightKg': profile.weightKg,
      'healthGoals': profile.healthGoals,
      'knownConditions': profile.knownConditions,
      'isBloodDonor': true,
      'source': 'signup',
    });
  }

  ChatSession _createChatSession({String? title}) {
    final now = DateTime.now();
    return ChatSession(
      id: now.microsecondsSinceEpoch.toString(),
      title: title ?? 'New chat',
      createdAt: now,
      updatedAt: now,
      messages: const [],
    );
  }

  ChatSession _ensureChatSession() {
    return _activeChatSession;
  }

  void _replaceActiveChatSession(ChatSession session) {
    final index = chatSessions.indexWhere((item) => item.id == session.id);
    if (index == -1) {
      chatSessions = [session, ...chatSessions];
      activeChatSessionId = session.id;
      return;
    }

    chatSessions = [...chatSessions]..[index] = session;
    activeChatSessionId = session.id;
  }

  void _appendToActiveChat(ChatMessage message) {
    final session = _ensureChatSession();
    _replaceActiveChatSession(
      session.copyWith(
        updatedAt: DateTime.now(),
        messages: [...session.messages, message],
      ),
    );
  }

  String _titleForSession(ChatSession session, String userText) {
    if (session.messages.isNotEmpty || session.title != 'New chat') {
      return session.title;
    }

    final words = userText.trim().split(RegExp(r'\s+'));
    final title = words.take(6).join(' ');
    return title.isEmpty ? 'New chat' : title;
  }
}
