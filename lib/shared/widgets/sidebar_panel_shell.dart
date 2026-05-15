import 'dart:ui' as ui;

import 'package:flutter/material.dart';

class SidebarPanelShell extends StatelessWidget {
  const SidebarPanelShell({
    super.key,
    required this.child,
    this.embedded = false,
    this.embeddedWidth,
    this.drawerWidth,
  });

  final Widget child;
  final bool embedded;
  final double? embeddedWidth;
  final double? drawerWidth;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (embedded) {
      return ClipRect(
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 6, sigmaY: 6),
          child: Material(
            color: cs.surface.withValues(alpha: 0.60),
            child: SizedBox(width: embeddedWidth ?? 300, child: child),
          ),
        ),
      );
    }

    return Drawer(
      backgroundColor: cs.surface,
      width: drawerWidth,
      child: child,
    );
  }
}
