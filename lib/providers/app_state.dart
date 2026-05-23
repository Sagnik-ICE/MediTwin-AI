import 'package:flutter/material.dart';

import '../models/chat_message.dart';
import '../models/chat_session.dart';
import '../models/health_log.dart';
import '../models/reminder_preferences.dart';
import '../models/reminder_schedule.dart';
import '../models/user_profile.dart';
import 'dart:convert';

import '../services/ai_service.dart';
import '../utils/debug_logger.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/health_score_service.dart';
import '../services/risk_detection_service.dart';
import '../services/simulation_service.dart';
import '../services/storage_service.dart';
import '../services/local_db.dart';
import '../services/notification_service.dart';

class AppState extends ChangeNotifier {
  static const String mainAdminEmail = 'dibbay242-50-014@diu.edu.bd';
  static const int maxStoredHealthLogs = 500;
  static const int maxStoredChatSessions = 20;
  static const int maxStoredChatMessagesPerSession = 200;

  factory AppState({
    required StorageService storageService,
    required AiService aiService,
    required AuthService authService,
    required FirestoreService firestoreService,
    NotificationService? notificationService,
  }) {
    return AppState._internal(
      storageService: storageService,
      aiService: aiService,
      authService: authService,
      firestoreService: firestoreService,
      notificationService: notificationService ?? NotificationService(),
    );
  }

  AppState._internal({
    required this._storageService,
    required this._aiService,
    required this._authService,
    required this._firestoreService,
    required this._notificationService,
  });

  final StorageService _storageService;
  final AiService _aiService;
  final AuthService _authService;
  final FirestoreService _firestoreService;
  final NotificationService _notificationService;

  bool initialized = false;
  bool darkMode = false;
  bool loggedIn = false;
  bool isAdmin = false;
  bool get isDoctor => profile.accountType.toLowerCase() == 'doctor';
  bool get isMainAdmin => _authService.currentUserEmail?.toLowerCase() == mainAdminEmail.toLowerCase();
  String? get currentUserId => _authService.currentUserId;
  String? get currentUserEmail => _authService.currentUserEmail;
  bool onboardingCompleted = false;
  bool isChatLoading = false;


  String chatMode = 'General';
  String apiUrl = StorageService.defaultApiUrl;
  String modelInfo = 'qwen3:8b-q4_K_M via local Ollama';
  ReminderPreferences reminderPreferences = ReminderPreferences.defaults();
  ReminderSchedule reminderSchedule = ReminderSchedule.defaults();

  UserProfile profile = UserProfile.empty();
  List<HealthLog> logs = [];
  List<ChatSession> chatSessions = [];
  String? activeChatSessionId;

  HealthLog? get latestLog => logs.isEmpty ? null : logs.first;

  HealthLog? get todayLog {
    if (logs.isEmpty) {
      return null;
    }

    final now = DateTime.now();
    for (final log in logs) {
      final date = log.date;
      if (date.year == now.year && date.month == now.month && date.day == now.day) {
        return log;
      }
    }

    return null;
  }

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
    await _rescheduleRemindersIfPossible();
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

  int get todayScore => todayLog?.healthScore ?? 0;

  List<String> get memoryHints {
    final hints = <String>[];

    if (logs.isEmpty) {
      hints.add('No health logs yet');
    } else {
      final latest = latestLog!;
      hints.addAll([
        weeklyMemorySummary,
        'Latest score ${latest.healthScore}',
        'Sleep ${latest.sleepHours}h',
        'Stress ${latest.stressLevel}/10',
        'Hydration ${latest.waterGlasses} glasses',
        if (latest.symptoms.isNotEmpty) 'Latest logged symptoms: ${latest.symptoms.take(4).join(', ')}',
        if (latest.riskFlags.isNotEmpty) latest.riskFlags.first,
      ]);
    }

    final goals = profile.healthGoals.trim();
    if (goals.isNotEmpty) {
      hints.add('User goal/focus: $goals');
    }

    final contactInfo = profile.contactInfo.trim();
    if (contactInfo.isNotEmpty) {
      hints.add('Profile note: $contactInfo');
    }

    hints.addAll(_learnedConversationMemoryHints);

    final seen = <String>{};
    return hints
        .map((hint) => hint.trim())
        .where((hint) => hint.isNotEmpty)
        .where((hint) => seen.add(hint.toLowerCase()))
        .take(14)
        .toList(growable: false);
  }

  List<String> get _learnedConversationMemoryHints {
    final userMessages = chatSessions
        .expand((session) => session.messages)
        .where((message) => message.isUser && message.text.trim().isNotEmpty)
        .toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    if (userMessages.isEmpty) {
      return const [];
    }

    final recentText = userMessages.take(36).map((message) => message.text.toLowerCase()).join(' | ');
    final hints = <String>[];
    final symptoms = <String, List<String>>{
      'headache': ['headache', 'head pain', 'migraine'],
      'dizziness': ['dizzy', 'dizziness', 'lightheaded', 'vertigo'],
      'nausea': ['nausea', 'nauseous', 'vomit', 'vomiting'],
      'fever': ['fever', 'temperature'],
      'cough': ['cough'],
      'fatigue': ['fatigue', 'tired', 'weakness', 'weak'],
      'sleep difficulty': ['insomnia', 'cannot sleep', 'can not sleep', 'poor sleep'],
      'stress': ['stress', 'anxiety', 'anxious', 'panic'],
      'chest pain': ['chest pain', 'chest tightness'],
      'breathing difficulty': ['shortness of breath', 'trouble breathing', 'can not breathe', "can't breathe"],
      'stomach discomfort': ['stomach pain', 'abdominal pain', 'diarrhea', 'gastric'],
    };

    final mentioned = <String>[];
    for (final entry in symptoms.entries) {
      if (entry.value.any((term) => recentText.contains(term))) {
        mentioned.add(entry.key);
      }
    }

    if (mentioned.isNotEmpty) {
      hints.add('Recently discussed symptoms: ${mentioned.take(6).join(', ')}');
    }

    final patterns = <String, String>{
      'Symptoms may relate to meals or food timing.': r'\b(after eating|after meal|empty stomach|skipped meal|food|meal)\b',
      'Symptoms may relate to hydration.': r'\b(dehydrated|hydration|water|not drinking|drink water)\b',
      'Symptoms may relate to sleep or rest.': r'\b(sleep|slept|tired|rest|night)\b',
      'Symptoms may relate to stress.': r'\b(stress|anxiety|anxious|panic|overthinking)\b',
      'User may prefer brief, direct responses.': r'\b(short answer|brief|keep it short|quickly)\b',
    };

    for (final entry in patterns.entries) {
      if (RegExp(entry.value).hasMatch(recentText)) {
        hints.add(entry.key);
      }
    }

    final latestUseful = userMessages
        .map((message) => message.text.trim())
        .where((text) => text.length >= 8 && text.length <= 120)
        .take(3)
        .toList();

    if (latestUseful.isNotEmpty) {
      hints.add('Recent user details: ${latestUseful.join(' / ')}');
    }

    return hints;
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
    final latest = latestLog;
    final base = latest?.insight ?? 'Start tracking daily to generate your personalized insight.';
    final goal = profile.healthGoals.trim();
    if (goal.isEmpty) {
      return base;
    }
    return '$base Goal focus: $goal.';
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

    logs = [finalLog, ...logs].take(maxStoredHealthLogs).toList();
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
    final normalizedUserText = userText.trim();
    if (normalizedUserText.isEmpty || isChatLoading) {
      return;
    }

    final currentSession = _ensureChatSession();
    final userMessage = ChatMessage(
      text: normalizedUserText,
      isUser: true,
      timestamp: DateTime.now(),
    );

    final requestSession = currentSession.copyWith(
      title: _titleForSession(currentSession, normalizedUserText),
      updatedAt: DateTime.now(),
      messages: [...currentSession.messages, userMessage],
    );

    _replaceActiveChatSession(requestSession);

    isChatLoading = true;
    notifyListeners();

    final endpoint = apiUrl.trim().isEmpty ? StorageService.defaultApiUrl : apiUrl.trim();

    String answer;
    try {
      answer = await _aiService.askAssistant(
        prompt: normalizedUserText,
        apiUrl: endpoint,
        memoryHints: memoryHints,
        chatMode: chatMode,
        conversationHistory: requestSession.messages,
      );
    } catch (e, st) {
      DebugLogger.warning('askAssistant threw exception', e);
      DebugLogger.debug(st.toString());
      answer = AiService.fallbackConnectionMessage;
    }

    final isError = answer.startsWith(AiService.fallbackConnectionMessage);

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
    chatSessions = _normalizeChatSessions([session, ...chatSessions], preferredActiveId: session.id);
    activeChatSessionId = session.id;
    await _syncCloudStateIfAvailable();
    notifyListeners();
  }

  Future<void> selectChatSession(String sessionId) async {
    if (chatSessions.any((session) => session.id == sessionId)) {
      activeChatSessionId = sessionId;
      // Selecting a chat is only a local UI state change. Avoid writing the
      // whole user-state document to Firestore just because the user switched
      // between saved conversations.
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

  Future<String?> updateProfile(UserProfile newProfile) async {
    final previousProfile = profile;

    final requestedAccountType = newProfile.accountType.trim();
    final existingAccountType = previousProfile.accountType.trim();
    final safeAccountType = requestedAccountType.isNotEmpty
        ? requestedAccountType
        : existingAccountType.isNotEmpty
            ? existingAccountType
            : 'patient';

    final normalizedProfile = UserProfile(
      name: newProfile.name.trim(),
      email: newProfile.email.trim().toLowerCase(),
      age: newProfile.age,
      gender: newProfile.gender,
      bloodGroup: newProfile.bloodGroup,
      isBloodDonor: newProfile.isBloodDonor,
      donorContactInfo: newProfile.isBloodDonor ? newProfile.donorContactInfo.trim() : '',
      heightCm: newProfile.heightCm,
      weightKg: newProfile.weightKg,
      healthGoals: newProfile.healthGoals.trim(),
      contactInfo: newProfile.contactInfo.trim(),
      division: newProfile.division,
      district: newProfile.district,
      accountType: safeAccountType,
    );

    profile = normalizedProfile;

    try {
      await _syncCloudStateStrict();

      final userId = _authService.currentUserId;
      if (safeAccountType.toLowerCase() == 'doctor' &&
          userId != null &&
          userId.trim().isNotEmpty) {
        final publicProfileSynced = await _firestoreService.updateLinkedDoctorProfileFromUserProfile(
          userId: userId,
          profile: profile,
          authEmail: _authService.currentUserEmail,
        );
        if (!publicProfileSynced) {
          DebugLogger.warning('Private doctor profile saved, but no linked public doctor directory document was found for $userId');
        }
      }

      // The app should become logged in only after the user's Firestore profile
      // has been saved successfully. This prevents the root app from opening an
      // empty patient shell during signup.
      if (_authService.currentUserId != null) {
        loggedIn = true;
      }
      await _refreshAdminStatus();
      notifyListeners();
      return null;
    } catch (e, st) {
      DebugLogger.warning('Failed to update profile data', e);
      DebugLogger.debug(st.toString());
      profile = previousProfile;
      notifyListeners();
      return 'Profile data could not be saved to Firestore. Check your connection and Firestore rules, then try again.';
    }
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
    await _rescheduleRemindersIfPossible();
    notifyListeners();
  }

  Future<void> setReminderSchedule(ReminderSchedule value) async {
    reminderSchedule = value;
    await _storageService.saveReminderSchedule(value);
    await _rescheduleRemindersIfPossible();
    notifyListeners();
  }

  Future<void> _rescheduleRemindersIfPossible() async {
    try {
      await _notificationService.scheduleDailyReminders(
        preferences: reminderPreferences,
        schedule: reminderSchedule,
      );
    } catch (e, st) {
      DebugLogger.warning('Failed to schedule local reminders', e);
      DebugLogger.debug(st.toString());
    }
  }

  Future<bool> testBackendConnection() async {
    final endpoint = apiUrl.trim().isEmpty ? StorageService.defaultApiUrl : apiUrl.trim();
    return _aiService.testConnection(endpoint);
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

  Future<String?> register(
    String email,
    String password, {
    bool activateSession = true,
  }) async {
    final error = await _authService.register(email: email, password: password);

    if (error != null) {
      return error;
    }

    // Signup is a two-step flow: Firebase Auth account first, then Firestore
    // profile state. Do not switch the root UI into the signed-in shell until
    // completeOnboarding() confirms the profile was saved.
    if (!activateSession) {
      loggedIn = false;
      isAdmin = false;
      notifyListeners();
      return null;
    }

    loggedIn = true;
    _resetUserSessionState();
    await _refreshAdminStatus();
    await _pullCloudStateIfAvailable();
    notifyListeners();
    return null;
  }


  Future<String?> completeOnboarding(UserProfile value) async {
    final previousOnboardingCompleted = onboardingCompleted;
    final previousLoggedIn = loggedIn;

    final requestedAccountType = value.accountType.trim();
    final existingAccountType = profile.accountType.trim();
    final safeAccountType = requestedAccountType.isNotEmpty
        ? requestedAccountType
        : existingAccountType.isNotEmpty
            ? existingAccountType
            : 'patient';

    profile = UserProfile(
      name: value.name.trim(),
      email: value.email.trim().toLowerCase(),
      age: value.age,
      gender: value.gender,
      bloodGroup: value.bloodGroup,
      isBloodDonor: value.isBloodDonor,
      donorContactInfo: value.isBloodDonor ? value.donorContactInfo : '',
      heightCm: value.heightCm,
      weightKg: value.weightKg,
      healthGoals: value.healthGoals,
      contactInfo: value.contactInfo,
      division: value.division,
      district: value.district,
      accountType: safeAccountType,
    );
    onboardingCompleted = true;

    try {
      await _syncCloudStateStrict();

      final userId = _authService.currentUserId;
      if (safeAccountType.toLowerCase() == 'doctor' &&
          userId != null &&
          userId.trim().isNotEmpty) {
        final publicProfileSynced = await _firestoreService.updateLinkedDoctorProfileFromUserProfile(
          userId: userId,
          profile: profile,
          authEmail: _authService.currentUserEmail,
        );
        if (!publicProfileSynced) {
          DebugLogger.warning('Private doctor profile saved, but no linked public doctor directory document was found for $userId');
        }
      }

      // The app should become logged in only after the user's Firestore profile
      // has been saved successfully. This prevents the root app from opening an
      // empty patient shell during signup.
      if (_authService.currentUserId != null) {
        loggedIn = true;
      }
      await _refreshAdminStatus();
      notifyListeners();
      return null;
    } catch (e, st) {
      DebugLogger.warning('Failed to complete onboarding profile sync', e);
      DebugLogger.debug(st.toString());

      // Keep the entered profile data visible in the UI, but report the failure
      // so the auth/onboarding screen does not route forward as if signup
      // finished successfully.
      onboardingCompleted = previousOnboardingCompleted;
      loggedIn = previousLoggedIn;
      notifyListeners();
      return 'Account was created, but profile data could not be saved to Firestore. Check Firestore rules and try again.';
    }
  }

  Future<void> logout() async {
    loggedIn = false;
    isAdmin = false;
    await _authService.logout();

    // Do not clear LocalDb on logout. LocalDb is the offline cache and may be
    // the user's only copy if a previous cloud sync failed. Account deletion is
    // the only flow that intentionally clears local health data.
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
        return;
      }

      profile = cloudState.profile;
      logs = cloudState.logs.take(maxStoredHealthLogs).toList();
      chatSessions = _normalizeChatSessions(cloudState.chatSessions, preferredActiveId: cloudState.activeChatSessionId);
      activeChatSessionId = cloudState.activeChatSessionId ?? (chatSessions.isNotEmpty ? chatSessions.first.id : null);
      onboardingCompleted = cloudState.onboardingCompleted;
      if (!onboardingCompleted && profile.name.trim().isNotEmpty && profile.age > 0 && profile.gender.trim().isNotEmpty && profile.bloodGroup.trim().isNotEmpty) {
        onboardingCompleted = true;
      }
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

  /// Delete the current account.
  ///
  /// Order matters:
  /// 1. Reauthenticate first. If the password is wrong, no data is removed.
  /// 2. Delete the user's Firestore documents while the user is still signed in.
  /// 3. Delete the Firebase Auth account.
  /// 4. Clear local offline cache only after the remote delete succeeds.
  Future<String?> deleteAccount({String? password}) async {
    if (password == null || password.trim().isEmpty) {
      return 'Password is required to delete the account.';
    }

    final userId = _authService.currentUserId;
    if (userId == null || userId.trim().isEmpty) {
      return 'No authenticated account is available for deletion.';
    }

    final reauthError = await _authService.reauthenticateWithPassword(
      password: password.trim(),
    );
    if (reauthError != null) {
      return reauthError;
    }

    final userEmail = _authService.currentUserEmail?.trim().toLowerCase();

    try {
      if (_authService.canUseFirebase) {
        await _firestoreService.deleteAccountOwnedData(
          userId: userId,
          email: userEmail,
        );
      }
    } catch (e, st) {
      DebugLogger.warning('Failed to delete complete cloud account data', e);
      DebugLogger.debug(st.toString());
      return 'Password verified, but all cloud data could not be removed. Account deletion was stopped.';
    }

    final authResult = await _authService.deleteCurrentUser();
    if (authResult != null) {
      return authResult;
    }

    loggedIn = false;
    isAdmin = false;
    _resetUserSessionState();
    await LocalDb.saveHealthLogs([]);

    // Let the declarative app root switch back to the sign-in screen. Do not
    // reset MaterialApp/Navigator keys during this notification; doing so while
    // provider-dependent widgets are being disposed can trigger Flutter web
    // inherited-widget assertions.
    notifyListeners();

    return null;
  }

  Future<String?> changePassword({required String currentPassword, required String newPassword}) async {
    return _authService.reauthenticateAndUpdatePassword(currentPassword: currentPassword, newPassword: newPassword);
  }

  Future<List<Map<String, dynamic>>> loadAdmins() async {
    return _firestoreService.loadAdmins();
  }

  Future<String?> addAdmin({required UserProfile profile, required String password}) async {
    if (!isMainAdmin) {
      return 'Only the main admin can add new admins.';
    }

    final email = profile.email.trim().toLowerCase();
    final displayName = profile.name.trim();

    if (email.isEmpty) {
      return 'Admin email is required.';
    }

    if (displayName.isEmpty) {
      return 'Admin name is required.';
    }

    if (password.trim().isEmpty) {
      return 'Admin password is required.';
    }

    final provisionResult = await _authService.provisionUserAccount(
      email: email,
      password: password,
    );

    if (!provisionResult.success) {
      return provisionResult.errorMessage ?? 'Failed to create the admin account.';
    }

    final uid = provisionResult.uid;

    if (uid == null || uid.trim().isEmpty) {
      return 'Failed to create the admin account.';
    }

    final adminProfile = UserProfile(
      name: displayName,
      email: email,
      age: profile.age,
      gender: profile.gender,
      bloodGroup: profile.bloodGroup,
      isBloodDonor: false,
      donorContactInfo: '',
      heightCm: profile.heightCm,
      weightKg: profile.weightKg,
      healthGoals: profile.healthGoals,
      contactInfo: profile.contactInfo,
      division: profile.division,
      district: profile.district,
      accountType: 'admin',
    );

    try {
      await _firestoreService.saveAdmin(
        email: email,
        displayName: displayName,
        addedBy: _authService.currentUserId ?? '',
        uid: uid,
      );

      await _firestoreService.saveUserState(
        userId: uid,
        profile: adminProfile,
        logs: const [],
        chatSessions: const [],
        activeChatSessionId: null,
        onboardingCompleted: true,
      );

      await _refreshAdminStatus();
      return null;
    } catch (e, st) {
      DebugLogger.warning('Failed to save admin profile data', e);
      DebugLogger.debug(st.toString());

      return 'Admin account was created, but profile data could not be saved. Check Firestore rules and try again.';
    }
  }

  Future<String?> addDoctorAccount({
    required String email,
    required String password,
    required String displayName,
    required Map<String, dynamic> doctorData,
  }) async {
    if (!isAdmin) {
      return 'Only an admin can add doctor accounts.';
    }

    final normalizedEmail = email.trim().toLowerCase();
    final normalizedDisplayName = displayName.trim();

    if (normalizedEmail.isEmpty) {
      return 'Doctor email is required.';
    }

    if (normalizedDisplayName.isEmpty) {
      return 'Doctor name is required.';
    }

    if (password.trim().isEmpty) {
      return 'Doctor password is required.';
    }

    final provisionResult = await _authService.provisionUserAccount(
      email: normalizedEmail,
      password: password,
    );

    if (!provisionResult.success) {
      return provisionResult.errorMessage ?? 'Failed to create the doctor account.';
    }

    final uid = provisionResult.uid;

    if (uid == null || uid.trim().isEmpty) {
      return 'Failed to create the doctor account.';
    }

    final profile = UserProfile(
      name: normalizedDisplayName,
      email: normalizedEmail,
      age: (doctorData['age'] as num?)?.toInt() ?? 0,
      gender: (doctorData['gender'] as String?) ?? '',
      bloodGroup: (doctorData['bloodGroup'] as String?) ?? '',
      isBloodDonor: false,
      donorContactInfo: '',
      heightCm: (doctorData['heightCm'] as num?)?.toDouble() ?? 0,
      weightKg: (doctorData['weightKg'] as num?)?.toDouble() ?? 0,
      healthGoals: (doctorData['specialtySummary'] as String?) ?? '',
      contactInfo: (doctorData['contactInfo'] as String?) ?? '',
      division: (doctorData['division'] as String?) ?? '',
      district: (doctorData['district'] as String?) ?? '',
      accountType: 'doctor',
    );

    try {
      await _firestoreService.saveUserState(
        userId: uid,
        profile: profile,
        logs: const [],
        chatSessions: const [],
        activeChatSessionId: null,
        onboardingCompleted: true,
      );

      await _firestoreService.saveDoctor({
        ...doctorData,
        'doctorUserId': uid,
        'doctorEmail': normalizedEmail,
        'displayName': normalizedDisplayName,
        'rating': (doctorData['rating'] as num?)?.toDouble() ?? 0,
        'ratingCount': 0,
        'hasDedicatedProfile': true,
        'acceptsAppointments': true,
        'updatedAt': DateTime.now().toIso8601String(),
      });

      await _refreshAdminStatus();
      return null;
    } catch (e, st) {
      DebugLogger.warning('Failed to save dedicated doctor profile data', e);
      DebugLogger.debug(st.toString());

      return 'Doctor account was created, but the dedicated doctor profile could not be saved. Check Firestore rules and try again.';
    }
  }

  Future<void> removeAdmin(String adminId) async {
    if (!isMainAdmin) {
      return;
    }
    await _firestoreService.deleteAdmin(adminId);
  }

  String get aiServerIp => apiUrl.trim().isEmpty ? StorageService.defaultApiUrl : apiUrl;

  Future<void> setAiServerIp(String value) async {
    // Kept for backward compatibility. The app now defaults to local Ollama automatically.
    await setApiUrl(value.trim().isEmpty ? StorageService.defaultApiUrl : value);
  }

  Future<bool> testAiConnection() async {
    return testBackendConnection();
  }

  Future<void> _syncCloudStateIfAvailable() async {
    try {
      await _syncCloudStateStrict();
    } catch (e, st) {
      DebugLogger.warning('Failed to sync cloud state', e);
      DebugLogger.debug(st.toString());
    }
  }

  Future<void> _syncCloudStateStrict() async {
    if (!_authService.canUseFirebase) {
      return;
    }

    final userId = _authService.currentUserId;
    if (userId == null) {
      return;
    }

    if (!_hasStateWorthSyncing) {
      return;
    }

    logs = logs.take(maxStoredHealthLogs).toList();
    chatSessions = _normalizeChatSessions(chatSessions, preferredActiveId: activeChatSessionId);
    if (activeChatSessionId != null && !chatSessions.any((session) => session.id == activeChatSessionId)) {
      activeChatSessionId = chatSessions.isNotEmpty ? chatSessions.first.id : null;
    }

    await _firestoreService.saveUserState(
      userId: userId,
      profile: profile,
      logs: logs,
      chatSessions: chatSessions,
      activeChatSessionId: activeChatSessionId,
      onboardingCompleted: onboardingCompleted,
    );

    await _syncDonorRecordIfNeeded();
  }

  bool get _hasStateWorthSyncing {
    final hasMeaningfulProfile = profile.name.trim().isNotEmpty ||
        profile.email.trim().isNotEmpty ||
        profile.gender.trim().isNotEmpty ||
        profile.bloodGroup.trim().isNotEmpty ||
        profile.isBloodDonor ||
        profile.donorContactInfo.trim().isNotEmpty ||
        profile.heightCm > 0 ||
        profile.weightKg > 0 ||
        profile.healthGoals.trim().isNotEmpty ||
        profile.contactInfo.trim().isNotEmpty ||
        profile.division.trim().isNotEmpty ||
        profile.district.trim().isNotEmpty ||
        profile.accountType.trim().isNotEmpty;

    return onboardingCompleted || hasMeaningfulProfile || logs.isNotEmpty || chatSessions.isNotEmpty;
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

    final publicContact = profile.donorContactInfo.trim().isNotEmpty
        ? profile.donorContactInfo.trim()
        : profile.contactInfo.trim();

    // Keep the public donor directory intentionally minimal. The blood_donors
    // collection is public-readable in the current app, so do not publish private
    // profile details such as email, age, height, weight, health goals, known
    // conditions, or general medical notes.
    await _firestoreService.saveDonor({
      'id': userId,
      'type': 'donor',
      'name': profile.name.trim(),
      'contact': publicContact,
      'contactInfo': publicContact,
      'bloodGroup': profile.bloodGroup.trim().toUpperCase(),
      'division': profile.division.trim(),
      'district': profile.district.trim(),
      'gender': profile.gender.trim(),
      'isBloodDonor': true,
      'source': 'profile',
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
    final safeSession = _trimChatSession(session);
    final index = chatSessions.indexWhere((item) => item.id == safeSession.id);
    if (index == -1) {
      chatSessions = _normalizeChatSessions(
        [safeSession, ...chatSessions],
        preferredActiveId: safeSession.id,
      );
      activeChatSessionId = safeSession.id;
      return;
    }

    final updatedSessions = [...chatSessions]..[index] = safeSession;
    chatSessions = _normalizeChatSessions(
      updatedSessions,
      preferredActiveId: safeSession.id,
    );
    activeChatSessionId = safeSession.id;
  }

  ChatSession _trimChatSession(ChatSession session) {
    if (session.messages.length <= maxStoredChatMessagesPerSession) {
      return session;
    }

    return session.copyWith(
      messages: session.messages
          .skip(session.messages.length - maxStoredChatMessagesPerSession)
          .toList(),
    );
  }

  List<ChatSession> _normalizeChatSessions(
    List<ChatSession> sessions, {
    String? preferredActiveId,
  }) {
    final seen = <String>{};
    final deduped = <ChatSession>[];

    for (final session in sessions) {
      if (session.id.trim().isEmpty || seen.contains(session.id)) {
        continue;
      }
      seen.add(session.id);
      deduped.add(_trimChatSession(session));
    }

    if (deduped.length <= maxStoredChatSessions) {
      return deduped;
    }

    final activeId = preferredActiveId ?? activeChatSessionId;
    final activeIndex = activeId == null
        ? -1
        : deduped.indexWhere((session) => session.id == activeId);

    if (activeIndex < 0) {
      return deduped.take(maxStoredChatSessions).toList();
    }

    final activeSession = deduped[activeIndex];
    final remaining = deduped.where((session) => session.id != activeSession.id);
    return [activeSession, ...remaining].take(maxStoredChatSessions).toList();
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
