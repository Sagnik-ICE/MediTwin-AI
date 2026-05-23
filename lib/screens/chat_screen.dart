// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_state.dart';
import '../models/chat_session.dart';
import '../theme/app_theme.dart';
import '../widgets/disclaimer_banner.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();
  bool _testingConnection = false;
  final _chatModes = const ['General', 'Symptoms', 'Nutrition', 'Sleep', 'Stress'];

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final appState = context.read<AppState>();
    if (appState.isChatLoading) {
      return;
    }

    final text = _controller.text.trim();
    if (text.isEmpty) {
      return;
    }

    _controller.clear();
    await appState.askAssistantWithMode(text, chatMode: appState.chatMode);
  }

  Future<void> _newChat(AppState appState) async {
    await appState.startNewChat();
    _controller.clear();
  }

  Future<void> _renameChat(AppState appState, ChatSession session) async {
    final controller = TextEditingController(text: session.title == 'New chat' ? '' : session.title);
    final newTitle = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Rename chat'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Chat title'),
          onSubmitted: (value) => Navigator.of(dialogContext).pop(value),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(dialogContext).pop(controller.text), child: const Text('Save')),
        ],
      ),
    );
    controller.dispose();

    if (newTitle == null || newTitle.trim().isEmpty) {
      return;
    }

    await appState.renameChatSession(session.id, newTitle.trim());
  }

  Future<void> _deleteChat(AppState appState, ChatSession session) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete chat?'),
        content: Text('Delete "${session.title}" and all of its messages?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await appState.deleteChatSession(session.id);
    }
  }

  Future<void> _showChatManagerSheet(AppState appState) async {
    final sessions = _sortedSessions(appState);
    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 560),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text('Chats', style: Theme.of(sheetContext).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                      ),
                      IconButton(
                        onPressed: () async {
                          Navigator.of(sheetContext).pop();
                          await _newChat(appState);
                        },
                        icon: const Icon(Icons.add_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.separated(
                      itemCount: sessions.length,
                      separatorBuilder: (context, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final session = sessions[index];
                        final selected = session.id == appState.activeChatSessionId;
                        return ListTile(
                          selected: selected,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          tileColor: selected ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.45) : null,
                          title: Text(session.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                          subtitle: Text('${session.messages.length} messages'),
                          onTap: () async {
                            Navigator.of(sheetContext).pop();
                            await appState.selectChatSession(session.id);
                          },
                          trailing: PopupMenuButton<String>(
                            onSelected: (value) async {
                              if (value == 'rename') {
                                Navigator.of(sheetContext).pop();
                                await _renameChat(appState, session);
                              } else if (value == 'delete') {
                                Navigator.of(sheetContext).pop();
                                await _deleteChat(appState, session);
                              }
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(value: 'rename', child: Text('Rename')),
                              PopupMenuItem(value: 'delete', child: Text('Delete')),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  List<ChatSession> _sortedSessions(AppState appState) {
    final sessions = [...appState.chatSessions];
    sessions.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return sessions;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, _) {
        final sessions = _sortedSessions(appState);
        final wide = MediaQuery.of(context).size.width >= 1000;
        final activeSession = sessions.firstWhere(
          (session) => session.id == appState.activeChatSessionId,
          orElse: () => sessions.isNotEmpty ? sessions.first : ChatSession(id: 'default', title: 'New chat', createdAt: DateTime.now(), updatedAt: DateTime.now(), messages: const []),
        );

        return Scaffold(
          appBar: AppBar(
            title: const Text('AI Wellness Assistant'),
            actions: [
              if (!wide)
                IconButton(
                  onPressed: () => _showChatManagerSheet(appState),
                  icon: const Icon(Icons.menu_rounded),
                  tooltip: 'Chats',
                ),
            ],
          ),
          body: LayoutBuilder(
            builder: (context, constraints) {
              final maxBubbleWidth = constraints.maxWidth >= 1000 ? 760.0 : constraints.maxWidth * 0.82;
              final wide = constraints.maxWidth >= 1000;

              return SafeArea(
                child: Row(
                  children: [
                    if (wide)
                      _ChatSidebar(
                        sessions: sessions,
                        activeChatSessionId: appState.activeChatSessionId,
                        onNewChat: () => _newChat(appState),
                        onSelect: (session) => appState.selectChatSession(session.id),
                        onRename: (session) => _renameChat(appState, session),
                        onDelete: (session) => _deleteChat(appState, session),
                      ),
                    Expanded(
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1100),
                          child: Column(
                            children: [
                              Padding(
                                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Chip(
                                    avatar: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                                    label: Text(activeSession.title),
                                  ),
                                ),
                              ),
                              const Padding(
                                padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
                                child: DisclaimerBanner(),
                              ),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                                child: Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: _chatModes.map((mode) {
                                    return ChoiceChip(
                                      label: Text(mode),
                                      selected: appState.chatMode == mode,
                                      onSelected: (_) => appState.setChatMode(mode),
                                    );
                                  }).toList(),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Expanded(
                                child: appState.chatMessages.isEmpty
                                    ? _EmptyChatState(maxWidth: maxBubbleWidth)
                                    : ListView.separated(
                                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                                        itemCount: appState.chatMessages.length,
                                        separatorBuilder: (context, _) => const SizedBox(height: 10),
                                        itemBuilder: (context, index) {
                                          final msg = appState.chatMessages[index];
                                          final align = msg.isUser ? Alignment.centerRight : Alignment.centerLeft;
                                          final bubbleColor = msg.isUser ? Theme.of(context).colorScheme.primary : Colors.white;

                                          return Align(
                                            alignment: align,
                                            child: Dismissible(
                                              key: ValueKey('${msg.timestamp.millisecondsSinceEpoch}-$index'),
                                              direction: DismissDirection.horizontal,
                                              onDismissed: (_) => appState.removeChatMessageAt(index),
                                              background: Container(
                                                alignment: Alignment.centerLeft,
                                                padding: const EdgeInsets.only(left: 20),
                                                decoration: BoxDecoration(
                                                  color: Theme.of(context).colorScheme.error.withValues(alpha: 0.10),
                                                  borderRadius: BorderRadius.circular(18),
                                                ),
                                                child: const Icon(Icons.delete_rounded),
                                              ),
                                              secondaryBackground: Container(
                                                alignment: Alignment.centerRight,
                                                padding: const EdgeInsets.only(right: 20),
                                                decoration: BoxDecoration(
                                                  color: Theme.of(context).colorScheme.error.withValues(alpha: 0.10),
                                                  borderRadius: BorderRadius.circular(18),
                                                ),
                                                child: const Icon(Icons.delete_rounded),
                                              ),
                                              child: ConstrainedBox(
                                                constraints: BoxConstraints(maxWidth: maxBubbleWidth),
                                                child: Column(
                                                  crossAxisAlignment: msg.isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                                  children: [
                                                    Container(
                                                      padding: const EdgeInsets.all(14),
                                                      decoration: BoxDecoration(
                                                        color: bubbleColor,
                                                        borderRadius: BorderRadius.only(
                                                          topLeft: const Radius.circular(18),
                                                          topRight: const Radius.circular(18),
                                                          bottomLeft: Radius.circular(msg.isUser ? 18 : 6),
                                                          bottomRight: Radius.circular(msg.isUser ? 6 : 18),
                                                        ),
                                                        border: msg.isUser ? null : Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.12)),
                                                        boxShadow: msg.isUser
                                                            ? [BoxShadow(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.14), blurRadius: 16, offset: const Offset(0, 8))]
                                                            : null,
                                                      ),
                                                      child: msg.isUser
                                                          ? Text(
                                                              msg.text,
                                                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white, height: 1.5),
                                                            )
                                                          : _AssistantReply(
                                                              text: msg.text,
                                                              isError: msg.isError,
                                                            ),
                                                    ),
                                                    if (!msg.isUser && msg.isError)
                                                      Padding(
                                                        padding: const EdgeInsets.only(top: 6),
                                                        child: Row(
                                                          mainAxisSize: MainAxisSize.min,
                                                          children: [
                                                            OutlinedButton(
                                                              onPressed: _testingConnection
                                                                  ? null
                                                                  : () async {
                                                                      setState(() => _testingConnection = true);
                                                                      final ok = await appState.testBackendConnection();
                                                                      if (!mounted) return;
                                                                      setState(() => _testingConnection = false);
                                                                      final messenger = ScaffoldMessenger.of(context);
                                                                      // The surrounding code checks `mounted` before this point.
                                                                      messenger.showSnackBar(SnackBar(
                                                                        content: Text(ok ? 'Local Ollama reachable.' : 'Could not reach local Ollama on this laptop.'),
                                                                        backgroundColor: ok ? Colors.green : Colors.orange,
                                                                      ));
                                                                    },
                                                              child: _testingConnection
                                                                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                                                                  : const Text('Test'),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                              ),
                              if (appState.isChatLoading)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: const [
                                      SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                                      SizedBox(width: 8),
                                      Text('Preparing a response...'),
                                    ],
                                  ),
                                ),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: _controller,
                                        minLines: 1,
                                        maxLines: 4,
                                        textInputAction: TextInputAction.send,
                                        onSubmitted: (_) => _send(),
                                        decoration: const InputDecoration(
                                          hintText: 'Ask about sleep, hydration, symptoms, or recovery...',
                                          prefixIcon: Icon(Icons.chat_bubble_outline_rounded),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    FilledButton(onPressed: appState.isChatLoading ? null : _send, child: const Icon(Icons.send_rounded)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
        },
    );
  }
}

class _ChatSidebar extends StatelessWidget {
  const _ChatSidebar({
    required this.sessions,
    required this.activeChatSessionId,
    required this.onNewChat,
    required this.onSelect,
    required this.onRename,
    required this.onDelete,
  });

  final List<ChatSession> sessions;
  final String? activeChatSessionId;
  final VoidCallback onNewChat;
  final ValueChanged<ChatSession> onSelect;
  final ValueChanged<ChatSession> onRename;
  final ValueChanged<ChatSession> onDelete;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 320,
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          border: Border(right: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.12))),
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                        child: Text('Chats', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: onNewChat,
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('New'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  itemCount: sessions.length,
                  separatorBuilder: (context, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final session = sessions[index];
                    final selected = session.id == activeChatSessionId;
                    return Material(
                      color: selected ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.45) : Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                      child: ListTile(
                        selected: selected,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        title: Text(session.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text('${session.messages.length} messages', maxLines: 1, overflow: TextOverflow.ellipsis),
                        onTap: () => onSelect(session),
                        trailing: PopupMenuButton<String>(
                          onSelected: (value) {
                            if (value == 'rename') {
                              onRename(session);
                            } else if (value == 'delete') {
                              onDelete(session);
                            }
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(value: 'rename', child: Text('Rename')),
                            PopupMenuItem(value: 'delete', child: Text('Delete')),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AssistantReply extends StatelessWidget {
  const _AssistantReply({required this.text, required this.isError});

  final String text;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final color = isError ? AppTheme.warning : const Color(0xFF18324A);
    final lines = text.split('\n');
    final spans = <TextSpan>[];

    for (final rawLine in lines) {
      final line = rawLine.trimRight();
      if (line.isEmpty) {
        spans.add(const TextSpan(text: '\n'));
        continue;
      }

      final markdownHeading = line.startsWith('###') || line.startsWith('##') || line.startsWith('#');
      final cleanedHeading = line.replaceFirst(RegExp(r'^#{1,3}\s*'), '').trim();
      final boldHeading = cleanedHeading.startsWith('**') && cleanedHeading.endsWith('**') && cleanedHeading.length > 4;
      final heading = markdownHeading || boldHeading || cleanedHeading.endsWith(':');
      final withoutOuterBold = boldHeading ? cleanedHeading.substring(2, cleanedHeading.length - 2).trim() : cleanedHeading;
      final bullet = withoutOuterBold.startsWith('- ') || withoutOuterBold.startsWith('• ') || withoutOuterBold.startsWith('* ')
          ? withoutOuterBold.replaceFirst(RegExp(r'^(-|•|\*)\s*'), '• ')
          : withoutOuterBold;

      spans.add(
        TextSpan(
          text: '$bullet\n',
          style: TextStyle(
            color: color,
            height: 1.5,
            fontWeight: heading ? FontWeight.w800 : FontWeight.w500,
          ),
        ),
      );
    }

    return SelectableText.rich(
      TextSpan(children: spans),
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: color, height: 1.5),
    );
  }
}

class _EmptyChatState extends StatelessWidget {
  const _EmptyChatState({required this.maxWidth});

  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.chat_bubble_rounded, size: 64, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 14),
              Text(
                'Start a wellness conversation',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                'Ask about sleep, hydration, stress, symptoms, or next steps. The assistant will respond using your laptop-hosted AI endpoint.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
