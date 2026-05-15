class CodexRemoteSessionMessage {
  final String role;
  final String text;

  const CodexRemoteSessionMessage({required this.role, required this.text});

  bool get isUser => role == 'user';

  bool get isAssistant => role == 'assistant';

  factory CodexRemoteSessionMessage.fromJson(Map<String, dynamic> json) {
    return CodexRemoteSessionMessage(
      role: json['role'] as String? ?? '',
      text: json['text'] as String? ?? '',
    );
  }
}

class CodexRemoteRuntimeStatus {
  final String kind;
  final List<String> activeFlags;

  const CodexRemoteRuntimeStatus({
    required this.kind,
    this.activeFlags = const [],
  });

  bool get isActive => kind == 'active';

  bool get isWaitingApproval => activeFlags.contains('waitingOnApproval');

  factory CodexRemoteRuntimeStatus.fromJson(Map<String, dynamic> json) {
    return CodexRemoteRuntimeStatus(
      kind: json['kind'] as String? ?? '',
      activeFlags:
          (json['activeFlags'] as List?)?.whereType<String>().toList() ??
          const <String>[],
    );
  }
}

class CodexRemotePendingApproval {
  final String requestId;
  final String kind;
  final String turnId;
  final String itemId;
  final String? reason;
  final String? command;
  final String? cwd;
  final String? grantRoot;

  const CodexRemotePendingApproval({
    required this.requestId,
    required this.kind,
    required this.turnId,
    required this.itemId,
    this.reason,
    this.command,
    this.cwd,
    this.grantRoot,
  });

  bool get isCommandExecution => kind == 'commandExecution';

  factory CodexRemotePendingApproval.fromJson(Map<String, dynamic> json) {
    return CodexRemotePendingApproval(
      requestId: json['requestId'] as String? ?? '',
      kind: json['kind'] as String? ?? '',
      turnId: json['turnId'] as String? ?? '',
      itemId: json['itemId'] as String? ?? '',
      reason: json['reason'] as String?,
      command: json['command'] as String?,
      cwd: json['cwd'] as String?,
      grantRoot: json['grantRoot'] as String?,
    );
  }
}

class CodexRemoteSession {
  final String id;
  final String? name;
  final String preview;
  final String modelProvider;
  final String? model;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? archivedAt;
  final String cwd;
  final String source;
  final String? firstUserMessage;
  final String? reasoningEffort;
  final String? cliVersion;
  final String? approvalMode;
  final String? sandboxPolicy;
  final String? forkedFromId;
  final String? agentNickname;
  final String? agentRole;
  final String? gitBranch;
  final String? gitCommit;
  final List<CodexRemoteSessionMessage> messages;
  final CodexRemoteRuntimeStatus? runtimeStatus;
  final List<CodexRemotePendingApproval> pendingApprovals;

  const CodexRemoteSession({
    required this.id,
    required this.name,
    required this.preview,
    required this.modelProvider,
    required this.model,
    required this.createdAt,
    required this.updatedAt,
    required this.archivedAt,
    required this.cwd,
    required this.source,
    this.firstUserMessage,
    this.reasoningEffort,
    this.cliVersion,
    this.approvalMode,
    this.sandboxPolicy,
    this.forkedFromId,
    this.agentNickname,
    this.agentRole,
    this.gitBranch,
    this.gitCommit,
    this.messages = const [],
    this.runtimeStatus,
    this.pendingApprovals = const [],
  });

  String get displayTitle {
    final trimmedName = name?.trim();
    if (trimmedName != null && trimmedName.isNotEmpty) {
      return trimmedName;
    }
    final trimmedPreview = preview.trim();
    if (trimmedPreview.isNotEmpty) {
      return trimmedPreview;
    }
    return id;
  }

  factory CodexRemoteSession.fromJson(Map<String, dynamic> json) {
    return CodexRemoteSession(
      id: json['id'] as String? ?? '',
      name: json['name'] as String?,
      preview: json['preview'] as String? ?? '',
      modelProvider: json['modelProvider'] as String? ?? '',
      model: json['model'] as String?,
      createdAt: _parseDateTime(json['createdAt']),
      updatedAt: _parseDateTime(json['updatedAt']),
      archivedAt: _parseDateTime(json['archivedAt']),
      cwd: json['cwd'] as String? ?? '',
      source: json['source'] as String? ?? '',
      firstUserMessage: json['firstUserMessage'] as String?,
      reasoningEffort: json['reasoningEffort'] as String?,
      cliVersion: json['cliVersion'] as String?,
      approvalMode: json['approvalMode'] as String?,
      sandboxPolicy: json['sandboxPolicy'] as String?,
      forkedFromId: json['forkedFromId'] as String?,
      agentNickname: json['agentNickname'] as String?,
      agentRole: json['agentRole'] as String?,
      gitBranch: json['gitBranch'] as String?,
      gitCommit: json['gitCommit'] as String?,
      messages:
          (json['messages'] as List?)
              ?.whereType<Map>()
              .map(
                (item) => CodexRemoteSessionMessage.fromJson(
                  item.cast<String, dynamic>(),
                ),
              )
              .toList() ??
          const [],
      runtimeStatus: json['runtimeStatus'] is Map<String, dynamic>
          ? CodexRemoteRuntimeStatus.fromJson(
              json['runtimeStatus'] as Map<String, dynamic>,
            )
          : null,
      pendingApprovals:
          (json['pendingApprovals'] as List?)
              ?.whereType<Map>()
              .map(
                (item) => CodexRemotePendingApproval.fromJson(
                  item.cast<String, dynamic>(),
                ),
              )
              .toList() ??
          const [],
    );
  }

  static DateTime? _parseDateTime(dynamic rawValue) {
    if (rawValue is! String || rawValue.trim().isEmpty) {
      return null;
    }
    return DateTime.tryParse(rawValue);
  }
}
