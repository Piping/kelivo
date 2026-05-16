import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/codex_remote_host.dart';
import '../models/codex_remote_session.dart';

enum CodexRemoteConnectionStatus { idle, connecting, connected, error }

class CodexRemoteProvider extends ChangeNotifier {
  static const String _prefsBaseUrlKey = 'codex_remote_base_url_v1';
  static const Duration _requestTimeout = Duration(seconds: 20);

  String _baseUrl = '';
  CodexRemoteConnectionStatus _status = CodexRemoteConnectionStatus.idle;
  String? _lastError;
  CodexRemoteHost? _host;
  List<CodexRemoteSession> _sessions = const [];
  final Map<String, CodexRemoteSession> _sessionDetails =
      <String, CodexRemoteSession>{};
  final Set<String> _loadingSessionIds = <String>{};
  bool _didLoadPrefs = false;

  String get baseUrl => _baseUrl;
  CodexRemoteConnectionStatus get status => _status;
  String? get lastError => _lastError;
  CodexRemoteHost? get host => _host;
  List<CodexRemoteSession> get sessions => List.unmodifiable(_sessions);
  bool get didLoadPrefs => _didLoadPrefs;
  bool get isLoading => _status == CodexRemoteConnectionStatus.connecting;

  CodexRemoteProvider() {
    _load();
  }

  CodexRemoteSession? sessionDetailFor(String id) => _sessionDetails[id];

  bool isLoadingSession(String id) => _loadingSessionIds.contains(id);

  Future<void> connect(String rawBaseUrl) async {
    final normalizedBaseUrl = _normalizeBaseUrl(rawBaseUrl);
    _baseUrl = normalizedBaseUrl;
    _lastError = null;
    _host = null;
    _sessions = const [];
    _sessionDetails.clear();
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsBaseUrlKey, normalizedBaseUrl);

    await refreshWorkspace();
  }

  Future<void> clearSavedHost() async {
    _baseUrl = '';
    _status = CodexRemoteConnectionStatus.idle;
    _lastError = null;
    _host = null;
    _sessions = const [];
    _sessionDetails.clear();
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsBaseUrlKey);
  }

  Future<void> refreshWorkspace() async {
    if (_baseUrl.trim().isEmpty) {
      _status = CodexRemoteConnectionStatus.idle;
      _lastError = null;
      notifyListeners();
      return;
    }

    _status = CodexRemoteConnectionStatus.connecting;
    _lastError = null;
    notifyListeners();

    try {
      await _getJson('/readyz');
      final hostJson = await _getJson('/api/v1/host');
      final sessionsJson = await _getJson('/api/v1/sessions');
      final rawItems = sessionsJson['items'];
      final items = rawItems is List ? rawItems : const <dynamic>[];

      _host = CodexRemoteHost.fromJson(hostJson);
      _sessions = items
          .whereType<Map>()
          .map(
            (item) => CodexRemoteSession.fromJson(item.cast<String, dynamic>()),
          )
          .toList();
      _status = CodexRemoteConnectionStatus.connected;
      _lastError = null;
    } catch (error) {
      _status = CodexRemoteConnectionStatus.error;
      _lastError = error.toString();
    }

    notifyListeners();
  }

  Future<CodexRemoteSession?> loadSessionDetail(String sessionId) async {
    return refreshSessionDetail(sessionId);
  }

  Future<CodexRemoteSession?> refreshSessionDetail(
    String sessionId, {
    bool activate = false,
  }) async {
    if (_baseUrl.trim().isEmpty) {
      return null;
    }
    if (_loadingSessionIds.contains(sessionId)) {
      return _sessionDetails[sessionId];
    }

    _loadingSessionIds.add(sessionId);
    notifyListeners();

    try {
      final query = activate
          ? '?include_history=true&activate=true'
          : '?include_history=true';
      final sessionJson = await _getJson('/api/v1/sessions/$sessionId$query');
      final detail = CodexRemoteSession.fromJson(sessionJson);
      _sessionDetails[sessionId] = detail;
      _lastError = null;
      return detail;
    } catch (error) {
      _lastError = error.toString();
      return _sessionDetails[sessionId];
    } finally {
      _loadingSessionIds.remove(sessionId);
      notifyListeners();
    }
  }

  Future<CodexRemoteSession?> sendSessionMessage(
    String sessionId,
    String text,
  ) async {
    await _postJson('/api/v1/sessions/$sessionId/messages', <String, dynamic>{
      'text': text,
    });
    return refreshSessionDetail(sessionId, activate: true);
  }

  Future<CodexRemoteSession?> interruptSession(String sessionId) async {
    await _postJson(
      '/api/v1/sessions/$sessionId/interrupt',
      const <String, dynamic>{},
    );
    return refreshSessionDetail(sessionId, activate: true);
  }

  Future<CodexRemoteSession?> resolveApproval(
    String sessionId,
    String requestId, {
    required bool approve,
  }) async {
    await _postJson(
      '/api/v1/sessions/$sessionId/approvals/$requestId',
      <String, dynamic>{'decision': approve ? 'approve' : 'deny'},
    );
    return refreshSessionDetail(sessionId, activate: true);
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _baseUrl = prefs.getString(_prefsBaseUrlKey) ?? '';
    _didLoadPrefs = true;
    notifyListeners();
  }

  Future<Map<String, dynamic>> _getJson(String path) async {
    final response = await http
        .get(Uri.parse('$_baseUrl$path'))
        .timeout(_requestTimeout);
    return _decodeJsonResponse(response);
  }

  Future<Map<String, dynamic>> _postJson(
    String path,
    Map<String, dynamic> body,
  ) async {
    final uri = Uri.parse('$_baseUrl$path');
    final response = await http
        .post(
          uri,
          headers: const <String, String>{'content-type': 'application/json'},
          body: jsonEncode(body),
        )
        .timeout(_requestTimeout);
    return _decodeJsonResponse(response);
  }

  Map<String, dynamic> _decodeJsonResponse(http.Response response) {
    final dynamic decodedBody = response.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(response.body);
    final bodyMap = decodedBody is Map
        ? decodedBody.cast<String, dynamic>()
        : <String, dynamic>{};

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message =
          bodyMap['error'] as String? ??
          'HTTP ${response.statusCode}: ${response.reasonPhrase ?? 'unknown'}';
      throw Exception(message);
    }

    return bodyMap;
  }

  String _normalizeBaseUrl(String input) {
    var normalized = input.trim();
    if (normalized.isEmpty) {
      return normalized;
    }
    if (!normalized.startsWith('http://') &&
        !normalized.startsWith('https://')) {
      normalized = 'http://$normalized';
    }
    while (normalized.endsWith('/')) {
      normalized = normalized.substring(0, normalized.length - 1);
    }
    return normalized;
  }
}
