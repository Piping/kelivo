import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:Kelivo/core/models/codex_remote_session.dart';
import 'package:Kelivo/core/providers/codex_remote_provider.dart';
import 'package:Kelivo/icons/lucide_adapter.dart';
import 'package:Kelivo/l10n/app_localizations.dart';

import 'codex_session_detail_page.dart';

class CodexWorkspacePage extends StatefulWidget {
  const CodexWorkspacePage({super.key});

  @override
  State<CodexWorkspacePage> createState() => _CodexWorkspacePageState();
}

class _CodexWorkspacePageState extends State<CodexWorkspacePage> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final provider = context.watch<CodexRemoteProvider>();

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: l10n.settingsPageBackButton,
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Lucide.ArrowLeft),
        ),
        title: Text(l10n.codexWorkspacePageTitle),
        actions: [
          IconButton(
            tooltip: l10n.codexWorkspaceRefreshTooltip,
            onPressed: provider.baseUrl.isEmpty || provider.isLoading
                ? null
                : () => provider.refreshWorkspace(),
            icon: const Icon(Lucide.RefreshCw),
          ),
        ],
      ),
      body: CodexWorkspaceContent(onOpenSession: _openSessionDetail),
    );
  }

  Future<void> _openSessionDetail(CodexRemoteSession session) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CodexSessionDetailPage(
          sessionId: session.id,
          initialSession: session,
        ),
      ),
    );
  }
}

class CodexWorkspaceContent extends StatefulWidget {
  const CodexWorkspaceContent({
    super.key,
    required this.onOpenSession,
    this.padding = const EdgeInsets.fromLTRB(16, 12, 16, 16),
  });

  final ValueChanged<CodexRemoteSession> onOpenSession;
  final EdgeInsetsGeometry padding;

  @override
  State<CodexWorkspaceContent> createState() => _CodexWorkspaceContentState();
}

class _CodexWorkspaceContentState extends State<CodexWorkspaceContent> {
  late final TextEditingController _hostController;
  bool _didAutoRefresh = false;

  @override
  void initState() {
    super.initState();
    _hostController = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<CodexRemoteProvider>();
      _hostController.text = provider.baseUrl;
      if (provider.baseUrl.isNotEmpty &&
          provider.host == null &&
          !provider.isLoading) {
        provider.refreshWorkspace();
      }
    });
  }

  @override
  void dispose() {
    _hostController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final provider = context.watch<CodexRemoteProvider>();
    if (provider.didLoadPrefs &&
        provider.baseUrl.isNotEmpty &&
        _hostController.text.isEmpty) {
      _hostController.text = provider.baseUrl;
    }
    if (provider.didLoadPrefs &&
        provider.baseUrl.isNotEmpty &&
        provider.host == null &&
        !provider.isLoading &&
        !_didAutoRefresh) {
      _didAutoRefresh = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.read<CodexRemoteProvider>().refreshWorkspace();
      });
    }
    final statusText = switch (provider.status) {
      CodexRemoteConnectionStatus.idle => l10n.codexWorkspaceStatusIdle,
      CodexRemoteConnectionStatus.connecting =>
        l10n.codexWorkspaceStatusConnecting,
      CodexRemoteConnectionStatus.connected =>
        l10n.codexWorkspaceStatusConnected,
      CodexRemoteConnectionStatus.error => l10n.codexWorkspaceStatusError,
    };

    return ListView(
      padding: widget.padding,
      children: [
        _SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.codexWorkspaceConnectSectionTitle,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                l10n.codexWorkspaceConnectSectionSubtitle,
                style: TextStyle(
                  fontSize: 13,
                  color: cs.onSurface.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _hostController,
                decoration: InputDecoration(
                  labelText: l10n.codexWorkspaceHostLabel,
                  hintText: l10n.codexWorkspaceHostHint,
                  border: const OutlineInputBorder(),
                ),
                keyboardType: TextInputType.url,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _connect(),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  FilledButton.icon(
                    onPressed: provider.isLoading ? null : _connect,
                    icon: provider.isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Lucide.Cable, size: 18),
                    label: Text(l10n.codexWorkspaceConnectButton),
                  ),
                  OutlinedButton.icon(
                    onPressed: provider.baseUrl.isEmpty
                        ? null
                        : () async {
                            _hostController.clear();
                            await provider.clearSavedHost();
                          },
                    icon: const Icon(Lucide.Trash2, size: 18),
                    label: Text(l10n.codexWorkspaceForgetButton),
                  ),
                  _StatusChip(label: statusText, status: provider.status),
                ],
              ),
              if (provider.lastError != null &&
                  provider.lastError!.trim().isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  '${l10n.codexWorkspaceErrorLabel}: ${provider.lastError}',
                  style: TextStyle(color: cs.error, fontSize: 13),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        _SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.codexWorkspaceHostSectionTitle,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              if (provider.host == null)
                Text(
                  l10n.codexWorkspaceNoHostConfigured,
                  style: TextStyle(color: cs.onSurface.withValues(alpha: 0.65)),
                )
              else
                Column(
                  children: [
                    _InfoRow(
                      label: l10n.codexWorkspaceHostServerNameLabel,
                      value: provider.host!.serverName,
                    ),
                    _InfoRow(
                      label: l10n.codexWorkspaceHostCodexHomeLabel,
                      value: provider.host!.codexHome,
                    ),
                    _InfoRow(
                      label: l10n.codexWorkspaceHostCurrentDirectoryLabel,
                      value: provider.host!.cwd,
                    ),
                    _InfoRow(
                      label: l10n.codexWorkspaceHostModelProviderLabel,
                      value: provider.host!.modelProviderId,
                    ),
                    _InfoRow(
                      label: l10n.codexWorkspaceHostVersionLabel,
                      value: provider.host!.version,
                      isLast: true,
                    ),
                  ],
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          l10n.codexWorkspaceSessionsSectionTitle,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: cs.onSurface.withValues(alpha: 0.8),
          ),
        ),
        const SizedBox(height: 8),
        if (provider.sessions.isEmpty)
          _SectionCard(
            child: Text(
              l10n.codexWorkspaceSessionsEmpty,
              style: TextStyle(color: cs.onSurface.withValues(alpha: 0.65)),
            ),
          )
        else
          ...provider.sessions.map((session) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _SessionCard(
                session: session,
                onTap: () => widget.onOpenSession(session),
              ),
            );
          }),
      ],
    );
  }

  Future<void> _connect() async {
    await context.read<CodexRemoteProvider>().connect(_hostController.text);
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child});

  final Widget child;

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
      child: child,
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.status});

  final String label;
  final CodexRemoteConnectionStatus status;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final Color color = switch (status) {
      CodexRemoteConnectionStatus.connected => Colors.green,
      CodexRemoteConnectionStatus.connecting => colorScheme.primary,
      CodexRemoteConnectionStatus.error => colorScheme.error,
      CodexRemoteConnectionStatus.idle => colorScheme.outline,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    this.isLast = false,
  });

  final String label;
  final String value;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: cs.onSurface.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 4),
          SelectableText(
            value.isEmpty ? '—' : value,
            style: const TextStyle(fontSize: 14),
          ),
        ],
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({required this.session, required this.onTap});

  final CodexRemoteSession session;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: _SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                session.displayTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                session.preview.trim().isEmpty ? session.id : session.preview,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: cs.onSurface.withValues(alpha: 0.78)),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _MetaChip(value: session.modelProvider),
                  if ((session.model ?? '').trim().isNotEmpty)
                    _MetaChip(value: session.model!),
                  if (session.updatedAt != null)
                    _MetaChip(
                      value:
                          '${session.updatedAt!.year}-${session.updatedAt!.month.toString().padLeft(2, '0')}-${session.updatedAt!.day.toString().padLeft(2, '0')}',
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.value});

  final String value;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        value,
        style: TextStyle(
          fontSize: 12,
          color: cs.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
