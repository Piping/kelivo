import 'package:flutter/material.dart';

import '../../../icons/lucide_adapter.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/ios_tactile.dart';

enum NewSessionAction { chat, codexWorkspace }

Future<NewSessionAction?> showNewSessionSheet(BuildContext context) {
  final cs = Theme.of(context).colorScheme;
  final l10n = AppLocalizations.of(context)!;

  Widget option({
    required IconData icon,
    required String label,
    required String subtitle,
    required NewSessionAction action,
  }) {
    return IosCardPress(
      borderRadius: BorderRadius.circular(16),
      baseColor: cs.surface,
      duration: const Duration(milliseconds: 260),
      onTap: () => Navigator.of(context).pop(action),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 20, color: cs.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.3,
                    color: cs.onSurface.withValues(alpha: 0.72),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(Lucide.ChevronRight, size: 18, color: cs.onSurface),
        ],
      ),
    );
  }

  return showModalBottomSheet<NewSessionAction>(
    context: context,
    backgroundColor: cs.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.homePageNewSessionSheetTitle,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                l10n.homePageNewSessionSheetSubtitle,
                style: TextStyle(
                  fontSize: 13,
                  color: cs.onSurface.withValues(alpha: 0.72),
                ),
              ),
              const SizedBox(height: 14),
              option(
                icon: Lucide.MessageCirclePlus,
                label: l10n.homePageNewSessionChatLabel,
                subtitle: l10n.homePageNewSessionChatSubtitle,
                action: NewSessionAction.chat,
              ),
              const SizedBox(height: 10),
              option(
                icon: Lucide.Cable,
                label: l10n.homePageNewSessionCodexWorkspaceLabel,
                subtitle: l10n.homePageNewSessionCodexWorkspaceSubtitle,
                action: NewSessionAction.codexWorkspace,
              ),
            ],
          ),
        ),
      );
    },
  );
}
