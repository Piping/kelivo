import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:Kelivo/core/models/codex_remote_session.dart';
import 'package:Kelivo/core/providers/codex_remote_provider.dart';
import 'package:Kelivo/icons/lucide_adapter.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/ios_tactile.dart';
import 'package:Kelivo/shared/widgets/sidebar_panel_shell.dart';

class CodexSessionDetailPage extends StatefulWidget {
  const CodexSessionDetailPage({
    super.key,
    required this.sessionId,
    required this.initialSession,
  });

  final String sessionId;
  final CodexRemoteSession initialSession;

  @override
  State<CodexSessionDetailPage> createState() => _CodexSessionDetailPageState();
}

class _CodexSessionDetailPageState extends State<CodexSessionDetailPage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _inputController = TextEditingController();
  final FocusNode _inputFocusNode = FocusNode();
  final Set<String> _processingApprovalIds = <String>{};

  late String _sessionId;
  late CodexRemoteSession _fallbackSession;
  Timer? _pollTimer;
  int _lastMessageCount = 0;
  bool _isSending = false;
  bool _isInterrupting = false;
  String? _actionError;

  @override
  void initState() {
    super.initState();
    _sessionId = widget.sessionId;
    _fallbackSession = widget.initialSession;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await context.read<CodexRemoteProvider>().refreshWorkspace();
      await _refresh(activate: true);
      if (!mounted) return;
      _lastMessageCount = _currentSession.messages.length;
      _jumpToBottom();
      _startPolling();
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _scrollController.dispose();
    _inputController.dispose();
    _inputFocusNode.dispose();
    super.dispose();
  }

  CodexRemoteSession get _currentSession {
    final provider = context.read<CodexRemoteProvider>();
    return provider.sessionDetailFor(_sessionId) ?? _fallbackSession;
  }

  bool get _sessionIsActive => _currentSession.runtimeStatus?.isActive ?? false;

  bool get _canSend =>
      !_isSending &&
      !_sessionIsActive &&
      _inputController.text.trim().isNotEmpty;

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (!mounted) return;
      _refresh(activate: true);
    });
  }

  Future<void> _refresh({bool activate = false}) async {
    final provider = context.read<CodexRemoteProvider>();
    final detail = await provider.refreshSessionDetail(
      _sessionId,
      activate: activate,
    );
    if (!mounted || detail == null) {
      return;
    }
    _fallbackSession = detail;
    if (detail.messages.length != _lastMessageCount) {
      _lastMessageCount = detail.messages.length;
      WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToBottom());
    }
  }

  void _jumpToBottom() {
    if (!_scrollController.hasClients) {
      return;
    }
    _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
  }

  Future<void> _sendMessage() async {
    final text = _inputController.text.trim();
    if (text.isEmpty || _isSending || _sessionIsActive) {
      return;
    }

    setState(() {
      _isSending = true;
      _actionError = null;
    });

    try {
      _inputController.clear();
      await context.read<CodexRemoteProvider>().sendSessionMessage(
        _sessionId,
        text,
      );
      if (!mounted) return;
      _inputFocusNode.requestFocus();
      await _refresh(activate: true);
      WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToBottom());
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _actionError = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  Future<void> _interruptSession() async {
    if (_isInterrupting) {
      return;
    }

    setState(() {
      _isInterrupting = true;
      _actionError = null;
    });

    try {
      await context.read<CodexRemoteProvider>().interruptSession(_sessionId);
      if (!mounted) return;
      await _refresh(activate: true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _actionError = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isInterrupting = false;
        });
      }
    }
  }

  Future<void> _resolveApproval(
    CodexRemotePendingApproval approval, {
    required bool approve,
  }) async {
    if (_processingApprovalIds.contains(approval.requestId)) {
      return;
    }

    setState(() {
      _processingApprovalIds.add(approval.requestId);
      _actionError = null;
    });

    try {
      await context.read<CodexRemoteProvider>().resolveApproval(
        _sessionId,
        approval.requestId,
        approve: approve,
      );
      if (!mounted) return;
      await _refresh(activate: true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _actionError = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _processingApprovalIds.remove(approval.requestId);
        });
      }
    }
  }

  Future<void> _selectSession(CodexRemoteSession session) async {
    if (_sessionId == session.id) {
      _closeSessionDrawerIfOpen();
      return;
    }

    setState(() {
      _sessionId = session.id;
      _fallbackSession = session;
      _lastMessageCount = session.messages.length;
      _actionError = null;
      _isSending = false;
      _isInterrupting = false;
      _processingApprovalIds.clear();
      _inputController.clear();
    });
    _closeSessionDrawerIfOpen();
    await _refresh(activate: true);
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToBottom());
  }

  void _closeSessionDrawerIfOpen() {
    if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final provider = context.watch<CodexRemoteProvider>();
    final session = provider.sessionDetailFor(_sessionId) ?? _fallbackSession;
    final sessions = provider.sessions;
    final cs = Theme.of(context).colorScheme;
    final actionError = _actionError ?? provider.lastError;
    final statusText = codexSessionStatusText(context, session.runtimeStatus);
    final screenWidth = MediaQuery.sizeOf(context).width;
    final showEmbeddedSidebar = screenWidth >= 980;

    final content = SafeArea(
      child: Row(
        children: [
          if (showEmbeddedSidebar)
            SizedBox(
              width: 300,
              child: SidebarPanelShell(
                embedded: true,
                embeddedWidth: 300,
                child: _SessionSidebar(
                  sessions: sessions,
                  activeSessionId: _sessionId,
                  title: l10n.codexWorkspaceSessionsSectionTitle,
                  currentChipLabel: l10n.codexWorkspaceSessionCurrentChip,
                  emptyText: l10n.codexWorkspaceSessionsEmpty,
                  onSelectSession: _selectSession,
                ),
              ),
            ),
          Expanded(
            child: Column(
              children: [
                if (actionError != null && actionError.trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: _InlineErrorBanner(
                      message: l10n.codexWorkspaceSessionActionError(
                        actionError,
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: _SessionMetaCard(
                    session: session,
                    statusText: statusText,
                  ),
                ),
                Expanded(
                  child: ListView(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                    children: [
                      if (provider.isLoadingSession(_sessionId) &&
                          session.messages.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(top: 24),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (session.messages.isEmpty)
                        _EmptyConversationCard(
                          text: l10n.codexWorkspaceSessionConversationEmpty,
                        )
                      else
                        ...session.messages.map(
                          (message) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _TranscriptBubble(message: message),
                          ),
                        ),
                      if (session.pendingApprovals.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Text(
                            l10n.codexWorkspaceSessionApprovalsTitle,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: cs.onSurface.withValues(alpha: 0.82),
                            ),
                          ),
                        ),
                        ...session.pendingApprovals.map(
                          (approval) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _ApprovalCard(
                              approval: approval,
                              busy: _processingApprovalIds.contains(
                                approval.requestId,
                              ),
                              onApprove: () =>
                                  _resolveApproval(approval, approve: true),
                              onDeny: () =>
                                  _resolveApproval(approval, approve: false),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                _ComposerBar(
                  controller: _inputController,
                  focusNode: _inputFocusNode,
                  enabled: !_sessionIsActive && !_isSending,
                  sending: _isSending,
                  canSend: _canSend,
                  hintText: l10n.codexWorkspaceSessionInputHint,
                  onChanged: (_) => setState(() {}),
                  onSend: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return Scaffold(
      key: _scaffoldKey,
      drawer: showEmbeddedSidebar
          ? null
          : SidebarPanelShell(
              drawerWidth: MediaQuery.sizeOf(context).width * 0.75,
              child: SafeArea(
                child: _SessionSidebar(
                  sessions: sessions,
                  activeSessionId: _sessionId,
                  title: l10n.codexWorkspaceSessionsSectionTitle,
                  currentChipLabel: l10n.codexWorkspaceSessionCurrentChip,
                  emptyText: l10n.codexWorkspaceSessionsEmpty,
                  onSelectSession: _selectSession,
                ),
              ),
            ),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leadingWidth: showEmbeddedSidebar ? 56 : 108,
        leading: Row(
          children: [
            IconButton(
              tooltip: l10n.settingsPageBackButton,
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(Lucide.ArrowLeft),
            ),
            if (!showEmbeddedSidebar)
              IconButton(
                tooltip: l10n.codexWorkspaceSessionListTooltip,
                onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                icon: const Icon(Lucide.MessagesSquare),
              ),
          ],
        ),
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              session.displayTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              statusText,
              style: TextStyle(
                fontSize: 12,
                color: cs.onSurface.withValues(alpha: 0.65),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: l10n.codexWorkspaceRefreshTooltip,
            onPressed: provider.isLoadingSession(_sessionId)
                ? null
                : () => _refresh(activate: true),
            icon: const Icon(Lucide.RefreshCw),
          ),
          IconButton(
            tooltip: l10n.codexWorkspaceSessionInterruptTooltip,
            onPressed:
                session.runtimeStatus?.isActive == true && !_isInterrupting
                ? _interruptSession
                : null,
            icon: _isInterrupting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Lucide.Square),
          ),
        ],
      ),
      body: content,
    );
  }
}

String codexSessionStatusText(
  BuildContext context,
  CodexRemoteRuntimeStatus? runtimeStatus,
) {
  final l10n = AppLocalizations.of(context)!;
  final status = runtimeStatus;
  if (status == null) {
    return l10n.codexWorkspaceSessionStatusIdle;
  }
  if (status.isWaitingApproval) {
    return l10n.codexWorkspaceSessionStatusWaitingApproval;
  }
  switch (status.kind) {
    case 'active':
      return l10n.codexWorkspaceSessionStatusRunning;
    case 'systemError':
      return l10n.codexWorkspaceSessionStatusSystemError;
    case 'notLoaded':
      return l10n.codexWorkspaceSessionStatusNotLoaded;
    case 'idle':
    default:
      return l10n.codexWorkspaceSessionStatusIdle;
  }
}

class CodexSessionConversationView extends StatefulWidget {
  const CodexSessionConversationView({
    super.key,
    required this.sessionId,
    required this.initialSession,
  });

  final String sessionId;
  final CodexRemoteSession initialSession;

  @override
  State<CodexSessionConversationView> createState() =>
      _CodexSessionConversationViewState();
}

class _CodexSessionConversationViewState
    extends State<CodexSessionConversationView> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _inputController = TextEditingController();
  final FocusNode _inputFocusNode = FocusNode();
  final Set<String> _processingApprovalIds = <String>{};

  late CodexRemoteSession _fallbackSession;
  Timer? _pollTimer;
  int _lastMessageCount = 0;
  bool _isSending = false;
  String? _actionError;

  @override
  void initState() {
    super.initState();
    _fallbackSession = widget.initialSession;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await context.read<CodexRemoteProvider>().refreshWorkspace();
      await _refresh(activate: true);
      if (!mounted) return;
      _lastMessageCount = _currentSession.messages.length;
      _jumpToBottom();
      _startPolling();
    });
  }

  @override
  void didUpdateWidget(covariant CodexSessionConversationView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sessionId == widget.sessionId) {
      return;
    }
    _fallbackSession = widget.initialSession;
    _lastMessageCount = widget.initialSession.messages.length;
    _actionError = null;
    _processingApprovalIds.clear();
    _inputController.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _refresh(activate: true);
      if (!mounted) return;
      _jumpToBottom();
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _scrollController.dispose();
    _inputController.dispose();
    _inputFocusNode.dispose();
    super.dispose();
  }

  CodexRemoteSession get _currentSession {
    final provider = context.read<CodexRemoteProvider>();
    return provider.sessionDetailFor(widget.sessionId) ?? _fallbackSession;
  }

  bool get _sessionIsActive => _currentSession.runtimeStatus?.isActive ?? false;

  bool get _canSend =>
      !_isSending &&
      !_sessionIsActive &&
      _inputController.text.trim().isNotEmpty;

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (!mounted) return;
      _refresh(activate: true);
    });
  }

  Future<void> _refresh({bool activate = false}) async {
    final provider = context.read<CodexRemoteProvider>();
    final detail = await provider.refreshSessionDetail(
      widget.sessionId,
      activate: activate,
    );
    if (!mounted || detail == null) {
      return;
    }
    _fallbackSession = detail;
    if (detail.messages.length != _lastMessageCount) {
      _lastMessageCount = detail.messages.length;
      WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToBottom());
    }
  }

  void _jumpToBottom() {
    if (!_scrollController.hasClients) {
      return;
    }
    _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
  }

  Future<void> _sendMessage() async {
    final text = _inputController.text.trim();
    if (text.isEmpty || _isSending || _sessionIsActive) {
      return;
    }

    setState(() {
      _isSending = true;
      _actionError = null;
    });

    try {
      _inputController.clear();
      await context.read<CodexRemoteProvider>().sendSessionMessage(
        widget.sessionId,
        text,
      );
      if (!mounted) return;
      _inputFocusNode.requestFocus();
      await _refresh(activate: true);
      WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToBottom());
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _actionError = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  Future<void> _resolveApproval(
    CodexRemotePendingApproval approval, {
    required bool approve,
  }) async {
    if (_processingApprovalIds.contains(approval.requestId)) {
      return;
    }

    setState(() {
      _processingApprovalIds.add(approval.requestId);
      _actionError = null;
    });

    try {
      await context.read<CodexRemoteProvider>().resolveApproval(
        widget.sessionId,
        approval.requestId,
        approve: approve,
      );
      if (!mounted) return;
      await _refresh(activate: true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _actionError = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _processingApprovalIds.remove(approval.requestId);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final provider = context.watch<CodexRemoteProvider>();
    final session =
        provider.sessionDetailFor(widget.sessionId) ?? _fallbackSession;
    final cs = Theme.of(context).colorScheme;
    final actionError = _actionError ?? provider.lastError;
    final statusText = codexSessionStatusText(context, session.runtimeStatus);

    return Column(
      children: [
        if (actionError != null && actionError.trim().isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: _InlineErrorBanner(
              message: l10n.codexWorkspaceSessionActionError(actionError),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: _SessionMetaCard(session: session, statusText: statusText),
        ),
        Expanded(
          child: ListView(
            controller: _scrollController,
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            children: [
              if (provider.isLoadingSession(widget.sessionId) &&
                  session.messages.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 24),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (session.messages.isEmpty)
                _EmptyConversationCard(
                  text: l10n.codexWorkspaceSessionConversationEmpty,
                )
              else
                ...session.messages.map(
                  (message) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _TranscriptBubble(message: message),
                  ),
                ),
              if (session.pendingApprovals.isNotEmpty) ...[
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(
                    l10n.codexWorkspaceSessionApprovalsTitle,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface.withValues(alpha: 0.82),
                    ),
                  ),
                ),
                ...session.pendingApprovals.map(
                  (approval) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _ApprovalCard(
                      approval: approval,
                      busy: _processingApprovalIds.contains(approval.requestId),
                      onApprove: () =>
                          _resolveApproval(approval, approve: true),
                      onDeny: () => _resolveApproval(approval, approve: false),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        _ComposerBar(
          controller: _inputController,
          focusNode: _inputFocusNode,
          enabled: !_sessionIsActive && !_isSending,
          sending: _isSending,
          canSend: _canSend,
          hintText: l10n.codexWorkspaceSessionInputHint,
          onChanged: (_) => setState(() {}),
          onSend: _sendMessage,
        ),
      ],
    );
  }
}

class _SessionSidebar extends StatelessWidget {
  const _SessionSidebar({
    required this.sessions,
    required this.activeSessionId,
    required this.title,
    required this.currentChipLabel,
    required this.emptyText,
    required this.onSelectSession,
  });

  final List<CodexRemoteSession> sessions;
  final String activeSessionId;
  final String title;
  final String currentChipLabel;
  final String emptyText;
  final ValueChanged<CodexRemoteSession> onSelectSession;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
          child: Row(
            children: [
              Icon(Lucide.MessagesSquare, size: 18, color: cs.onSurface),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
        Divider(
          height: 1,
          thickness: 1,
          color: cs.outlineVariant.withValues(alpha: 0.18),
        ),
        Expanded(
          child: sessions.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Text(
                      emptyText,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: cs.onSurface.withValues(alpha: 0.65),
                      ),
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(10, 12, 10, 12),
                  itemCount: sessions.length,
                  itemBuilder: (context, index) {
                    final session = sessions[index];
                    final isActive = session.id == activeSessionId;
                    return _SessionSidebarTile(
                      session: session,
                      isActive: isActive,
                      currentChipLabel: currentChipLabel,
                      onTap: () => onSelectSession(session),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _SessionSidebarTile extends StatelessWidget {
  const _SessionSidebarTile({
    required this.session,
    required this.isActive,
    required this.currentChipLabel,
    required this.onTap,
  });

  final CodexRemoteSession session;
  final bool isActive;
  final String currentChipLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final embedded =
        context.findAncestorWidgetOfExactType<SidebarPanelShell>()?.embedded ??
        false;
    final titleColor = isActive ? cs.onPrimary : cs.onSurface;
    final subtitleColor = isActive
        ? cs.onPrimary.withValues(alpha: 0.82)
        : cs.onSurface.withValues(alpha: 0.64);
    final chipTextColor = embedded ? cs.primary : cs.onPrimary;
    final baseColor = isActive
        ? cs.primary.withValues(alpha: embedded ? 0.16 : 0.80)
        : (embedded ? Colors.transparent : cs.surface);

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: IosCardPress(
        baseColor: baseColor,
        borderRadius: BorderRadius.circular(16),
        haptics: false,
        onTap: onTap,
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    session.displayTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: titleColor,
                    ),
                  ),
                ),
                if (isActive) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: embedded
                          ? cs.primary.withValues(alpha: 0.12)
                          : Colors.white.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      currentChipLabel,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: chipTextColor,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 6),
            Text(
              session.preview,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                height: 1.35,
                color: subtitleColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ComposerBar extends StatelessWidget {
  const _ComposerBar({
    required this.controller,
    required this.focusNode,
    required this.enabled,
    required this.sending,
    required this.canSend,
    required this.hintText,
    required this.onChanged,
    required this.onSend,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool enabled;
  final bool sending;
  final bool canSend;
  final String hintText;
  final ValueChanged<String> onChanged;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(
          top: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.35)),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: isDark ? Colors.white10 : const Color(0xFFF2F3F5),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                  child: TextField(
                    controller: controller,
                    focusNode: focusNode,
                    enabled: enabled,
                    minLines: 1,
                    maxLines: 6,
                    textInputAction: TextInputAction.newline,
                    decoration: InputDecoration.collapsed(hintText: hintText),
                    onChanged: onChanged,
                    onSubmitted: (_) {
                      if (canSend) {
                        onSend();
                      }
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            FilledButton(
              onPressed: canSend ? onSend : null,
              style: FilledButton.styleFrom(
                minimumSize: const Size(54, 54),
                shape: const CircleBorder(),
                padding: EdgeInsets.zero,
              ),
              child: sending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Lucide.ArrowUp, size: 20),
            ),
          ],
        ),
      ),
    );
  }
}

class _SessionMetaCard extends StatelessWidget {
  const _SessionMetaCard({required this.session, required this.statusText});

  final CodexRemoteSession session;
  final String statusText;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? Colors.white10 : Colors.white.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.22)),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _MetaChip(icon: Lucide.Activity, text: statusText),
          if ((session.modelProvider).trim().isNotEmpty)
            _MetaChip(icon: Lucide.Bot, text: session.modelProvider),
          if ((session.source).trim().isNotEmpty)
            _MetaChip(icon: Lucide.SquareEqual, text: session.source),
          if ((session.cwd).trim().isNotEmpty)
            _MetaChip(
              icon: Lucide.FolderOpen,
              text: session.cwd,
              expanded: true,
            ),
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({
    required this.icon,
    required this.text,
    this.expanded = false,
  });

  final IconData icon;
  final String text;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final child = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: cs.onSurfaceVariant),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: cs.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
    if (!expanded) {
      return IntrinsicWidth(child: child);
    }
    return SizedBox(width: double.infinity, child: child);
  }
}

class _EmptyConversationCard extends StatelessWidget {
  const _EmptyConversationCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.2)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 14,
          color: cs.onSurface.withValues(alpha: 0.68),
        ),
      ),
    );
  }
}

class _ApprovalCard extends StatelessWidget {
  const _ApprovalCard({
    required this.approval,
    required this.busy,
    required this.onApprove,
    required this.onDeny,
  });

  final CodexRemotePendingApproval approval;
  final bool busy;
  final VoidCallback onApprove;
  final VoidCallback onDeny;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final title = approval.isCommandExecution
        ? l10n.codexWorkspaceSessionApprovalCommandExecution
        : l10n.codexWorkspaceSessionApprovalFileChange;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.errorContainer.withValues(alpha: 0.34),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.error.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: cs.onSurface,
            ),
          ),
          if ((approval.reason ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              approval.reason!,
              style: TextStyle(
                fontSize: 13,
                color: cs.onSurface.withValues(alpha: 0.78),
              ),
            ),
          ],
          if ((approval.command ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            _ApprovalField(
              label: l10n.codexWorkspaceSessionApprovalCommandLabel,
              value: approval.command!,
            ),
          ],
          if ((approval.cwd ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            _ApprovalField(
              label: l10n.codexWorkspaceSessionCwdLabel,
              value: approval.cwd!,
            ),
          ],
          if ((approval.grantRoot ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            _ApprovalField(
              label: l10n.codexWorkspaceSessionApprovalGrantRootLabel,
              value: approval.grantRoot!,
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: busy ? null : onApprove,
                  child: busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(l10n.codexWorkspaceSessionApproveButton),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: busy ? null : onDeny,
                  child: Text(l10n.codexWorkspaceSessionDenyButton),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ApprovalField extends StatelessWidget {
  const _ApprovalField({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: cs.onSurface.withValues(alpha: 0.56),
          ),
        ),
        const SizedBox(height: 4),
        SelectableText(
          value,
          style: TextStyle(
            fontSize: 13,
            height: 1.35,
            color: cs.onSurface.withValues(alpha: 0.84),
          ),
        ),
      ],
    );
  }
}

class _InlineErrorBanner extends StatelessWidget {
  const _InlineErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.errorContainer.withValues(alpha: 0.34),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.error.withValues(alpha: 0.16)),
      ),
      child: Text(
        message,
        style: TextStyle(
          fontSize: 13,
          color: cs.onSurface.withValues(alpha: 0.84),
        ),
      ),
    );
  }
}

class _TranscriptBubble extends StatelessWidget {
  const _TranscriptBubble({required this.message});

  final CodexRemoteSessionMessage message;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final isUser = message.isUser;
    final bubbleColor = isUser ? cs.primary : cs.surfaceContainerHighest;
    final textColor = isUser ? cs.onPrimary : cs.onSurface;
    final roleText = isUser
        ? l10n.codexWorkspaceSessionUserRole
        : l10n.codexWorkspaceSessionAssistantRole;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                roleText,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: textColor.withValues(alpha: 0.82),
                ),
              ),
              const SizedBox(height: 6),
              SelectableText(
                message.text,
                style: TextStyle(fontSize: 14, height: 1.45, color: textColor),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String formatCodexSessionDateTime(DateTime? value) {
  if (value == null) {
    return '—';
  }
  return DateFormat.yMd().add_Hm().format(value.toLocal());
}
