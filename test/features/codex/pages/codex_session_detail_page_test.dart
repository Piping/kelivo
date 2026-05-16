import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:Kelivo/core/models/codex_remote_session.dart';
import 'package:Kelivo/core/providers/codex_remote_provider.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/features/codex/pages/codex_session_detail_page.dart';
import 'package:Kelivo/icons/lucide_adapter.dart';
import 'package:Kelivo/l10n/app_localizations.dart';

CodexRemoteSession _sessionWithMessages() {
  return const CodexRemoteSession(
    id: 'session-1',
    name: 'Kelivo Remote',
    preview: 'preview',
    modelProvider: 'newapi',
    model: 'gpt-5',
    createdAt: null,
    updatedAt: null,
    archivedAt: null,
    cwd: '/Users/bytedance/kelivo',
    source: 'Cli',
    runtimeStatus: CodexRemoteRuntimeStatus(
      kind: 'active',
      activeFlags: ['waitingOnApproval'],
    ),
    messages: [
      CodexRemoteSessionMessage(role: 'user', text: '你好，Codex'),
      CodexRemoteSessionMessage(role: 'assistant', text: 'Kelivo 已连接'),
    ],
    pendingApprovals: [
      CodexRemotePendingApproval(
        requestId: 'approval-1',
        kind: 'commandExecution',
        turnId: 'turn-1',
        itemId: 'item-1',
        command: 'pwd',
      ),
    ],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('选择 session 后会进入聊天页并展示 transcript 输入框与审批按钮', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final provider = CodexRemoteProvider();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: provider),
          ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ],
        child: MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: CodexSessionDetailPage(
            sessionId: 'session-1',
            initialSession: _sessionWithMessages(),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Kelivo Remote'), findsOneWidget);
    expect(find.text('你好，Codex'), findsOneWidget);
    expect(find.text('Kelivo 已连接'), findsOneWidget);
    expect(find.text('Approve'), findsOneWidget);
    expect(find.text('Deny'), findsOneWidget);
    expect(find.text('Continue this Codex session…'), findsOneWidget);
    expect(find.byIcon(Lucide.ChevronsUp), findsOneWidget);

    await tester.tap(find.byTooltip('Open session list'));
    await tester.pumpAndSettle();

    expect(find.text('No sessions available.'), findsOneWidget);
  });

  testWidgets('codex session 详情页会展示消息导航按钮', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final provider = CodexRemoteProvider();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: provider),
          ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ],
        child: MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: CodexSessionConversationView(
              sessionId: 'session-1',
              initialSession: const CodexRemoteSession(
                id: 'session-1',
                name: 'Kelivo Remote',
                preview: 'preview',
                modelProvider: 'newapi',
                model: 'gpt-5',
                createdAt: null,
                updatedAt: null,
                archivedAt: null,
                cwd: '/Users/bytedance/kelivo',
                source: 'Cli',
                runtimeStatus: CodexRemoteRuntimeStatus(kind: 'idle'),
                messages: [
                  CodexRemoteSessionMessage(role: 'user', text: '第一条用户消息'),
                  CodexRemoteSessionMessage(role: 'assistant', text: '第一条回复'),
                  CodexRemoteSessionMessage(role: 'user', text: '第二条用户消息'),
                  CodexRemoteSessionMessage(role: 'assistant', text: '第二条回复'),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byIcon(Lucide.ChevronsUp), findsOneWidget);
    expect(find.byIcon(Lucide.ChevronsDown), findsOneWidget);
  });
}
