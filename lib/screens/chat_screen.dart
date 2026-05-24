// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/chat_session.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/disclaimer_banner.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _chatModes = const ['General', 'Symptoms', 'Nutrition', 'Sleep', 'Stress'];
  int _lastMessageCount = 0;
  bool _lastLoadingState = false;

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final appState = context.read<AppState>();
    if (appState.isChatLoading) return;

    final text = _controller.text.trim();
    if (text.isEmpty) return;

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

    if (newTitle == null || newTitle.trim().isEmpty) return;
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
          FilledButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('Delete')),
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
                        child: Text(
                          'Conversations',
                          style: Theme.of(sheetContext).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ),
                      IconButton(
                        onPressed: () async {
                          Navigator.of(sheetContext).pop();
                          await _newChat(appState);
                        },
                        icon: const Icon(Icons.add_rounded),
                        tooltip: 'New chat',
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
                        return Material(
                          color: selected ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.45) : Colors.transparent,
                          borderRadius: BorderRadius.circular(16),
                          child: ListTile(
                            selected: selected,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            title: Text(session.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                            subtitle: Text('${session.messages.length} messages'),
                            onTap: () async {
                              Navigator.of(sheetContext).pop();
                              await appState.selectChatSession(session.id);
                            },
                            trailing: PopupMenuButton<String>(
                              onSelected: (value) async {
                                Navigator.of(sheetContext).pop();
                                if (value == 'rename') {
                                  await _renameChat(appState, session);
                                } else if (value == 'delete') {
                                  await _deleteChat(appState, session);
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
      },
    );
  }

  List<ChatSession> _sortedSessions(AppState appState) {
    final sessions = [...appState.chatSessions];
    sessions.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return sessions;
  }

  void _maybeScrollToBottom(int messageCount, bool isLoading) {
    if (messageCount == _lastMessageCount && isLoading == _lastLoadingState) return;
    _lastMessageCount = messageCount;
    _lastLoadingState = isLoading;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, _) {
        final sessions = _sortedSessions(appState);
        final activeSession = sessions.firstWhere(
          (session) => session.id == appState.activeChatSessionId,
          orElse: () => sessions.isNotEmpty
              ? sessions.first
              : ChatSession(
                  id: 'default',
                  title: 'New chat',
                  createdAt: DateTime.now(),
                  updatedAt: DateTime.now(),
                  messages: const [],
                ),
        );

        _maybeScrollToBottom(appState.chatMessages.length, appState.isChatLoading);

        return Scaffold(
          backgroundColor: Theme.of(context).colorScheme.surface,
          body: LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 1100;
              final conversationMaxWidth = constraints.maxWidth >= 1100 ? 920.0 : constraints.maxWidth;
              final maxAssistantWidth = constraints.maxWidth >= 1000 ? 720.0 : constraints.maxWidth * 0.82;
              final maxUserWidth = constraints.maxWidth >= 1000 ? 420.0 : constraints.maxWidth * 0.76;

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
                      child: Column(
                        children: [
                          _ChatHeader(
                            activeTitle: activeSession.title,
                            modes: _chatModes,
                            selectedMode: appState.chatMode,
                            wide: wide,
                            onModeSelected: appState.setChatMode,
                            onShowChats: () => _showChatManagerSheet(appState),
                            onNewChat: () => _newChat(appState),
                          ),
                          const Padding(
                            padding: EdgeInsets.fromLTRB(20, 0, 20, 0),
                            child: DisclaimerBanner(),
                          ),
                          Expanded(
                            child: appState.chatMessages.isEmpty
                                ? _EmptyChatState(maxWidth: maxAssistantWidth)
                                : ListView.builder(
                                    controller: _scrollController,
                                    padding: EdgeInsets.fromLTRB(wide ? 28 : 16, 18, wide ? 28 : 16, 18),
                                    itemCount: appState.chatMessages.length,
                                    itemBuilder: (context, index) {
                                      final msg = appState.chatMessages[index];
                                      return Center(
                                        child: ConstrainedBox(
                                          constraints: BoxConstraints(maxWidth: conversationMaxWidth),
                                          child: Padding(
                                            padding: const EdgeInsets.only(bottom: 16),
                                            child: _MessageBubble(
                                              text: msg.text,
                                              isUser: msg.isUser,
                                              isError: msg.isError,
                                              maxAssistantWidth: maxAssistantWidth,
                                              maxUserWidth: maxUserWidth,
                                              onDelete: () => appState.removeChatMessageAt(index),
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                          ),
                          if (appState.isChatLoading) const _GeneratingIndicator(),
                          _Composer(
                            controller: _controller,
                            enabled: !appState.isChatLoading,
                            onSend: _send,
                          ),
                        ],
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

class _ChatHeader extends StatelessWidget {
  const _ChatHeader({
    required this.activeTitle,
    required this.modes,
    required this.selectedMode,
    required this.wide,
    required this.onModeSelected,
    required this.onShowChats,
    required this.onNewChat,
  });

  final String activeTitle;
  final List<String> modes;
  final String selectedMode;
  final bool wide;
  final ValueChanged<String> onModeSelected;
  final VoidCallback onShowChats;
  final VoidCallback onNewChat;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: EdgeInsets.fromLTRB(wide ? 24 : 14, 14, wide ? 24 : 14, 12),
      color: theme.colorScheme.surface,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 980),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            decoration: BoxDecoration(
              gradient: AppTheme.brandGradient,
              borderRadius: BorderRadius.circular(30),
              boxShadow: AppTheme.softShadow(opacity: 0.10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    if (!wide) ...[
                      IconButton(
                        onPressed: onShowChats,
                        icon: const Icon(Icons.forum_rounded),
                        tooltip: 'Conversations',
                        style: IconButton.styleFrom(
                          foregroundColor: Colors.white,
                          backgroundColor: Colors.white.withValues(alpha: 0.12),
                          side: BorderSide(color: Colors.white.withValues(alpha: 0.16)),
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
                      ),
                      child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 26),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'MediTwin Assistant',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleLarge?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.45,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            activeTitle == 'New chat' ? 'Private health conversation' : activeTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: Colors.white.withValues(alpha: 0.86),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    FilledButton.icon(
                      onPressed: onNewChat,
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: Text(wide ? 'New chat' : 'New'),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppTheme.primaryBlue,
                        minimumSize: const Size(0, 42),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final mode in modes)
                      _ModePill(
                        label: mode,
                        selected: selectedMode == mode,
                        onSelected: () => onModeSelected(mode),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ModePill extends StatelessWidget {
  const _ModePill({required this.label, required this.selected, required this.onSelected});

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onSelected,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withValues(alpha: selected ? 0.92 : 0.18)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected) ...[
              const Icon(Icons.check_rounded, size: 15, color: AppTheme.primaryTeal),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: selected ? AppTheme.primaryBlue : Colors.white,
                fontWeight: FontWeight.w800,
                height: 1.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.text,
    required this.isUser,
    required this.isError,
    required this.maxAssistantWidth,
    required this.maxUserWidth,
    required this.onDelete,
  });

  final String text;
  final bool isUser;
  final bool isError;
  final double maxAssistantWidth;
  final double maxUserWidth;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final maxWidth = isUser ? maxUserWidth : maxAssistantWidth;
    final bubble = ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: isUser ? const Color(0xFF071B2C) : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(22),
            topRight: const Radius.circular(22),
            bottomLeft: Radius.circular(isUser ? 22 : 10),
            bottomRight: Radius.circular(isUser ? 10 : 22),
          ),
          border: isUser ? null : Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.12)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isUser ? 0.08 : 0.035),
              blurRadius: isUser ? 18 : 12,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(isUser ? 16 : 18, isUser ? 12 : 16, isUser ? 16 : 18, isUser ? 12 : 16),
          child: isUser
              ? Text(
                  text,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white,
                        height: 1.45,
                        fontWeight: FontWeight.w700,
                      ),
                )
              : _AssistantReply(text: text, isError: isError),
        ),
      ),
    );

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: onDelete,
        child: isUser
            ? bubble
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    margin: const EdgeInsets.only(right: 10, top: 4),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.75),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.auto_awesome_rounded, size: 18, color: Theme.of(context).colorScheme.primary),
                  ),
                  bubble,
                ],
              ),
      ),
    );
  }
}

class _GeneratingIndicator extends StatelessWidget {
  const _GeneratingIndicator();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2, color: Theme.of(context).colorScheme.primary),
          ),
          const SizedBox(width: 8),
          Text(
            'Generating response...',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({required this.controller, required this.enabled, required this.onSend});

  final TextEditingController controller;
  final bool enabled;
  final Future<void> Function() onSend;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: AppTheme.scaffold,
        border: Border(top: BorderSide(color: AppTheme.border.withValues(alpha: 0.95))),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryNavy.withValues(alpha: 0.06),
            blurRadius: 22,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 980),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: enabled
                          ? AppTheme.primaryBlue.withValues(alpha: 0.24)
                          : AppTheme.border.withValues(alpha: 0.85),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryNavy.withValues(alpha: 0.07),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: controller,
                    enabled: enabled,
                    minLines: 1,
                    maxLines: 5,
                    textInputAction: TextInputAction.send,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                    onSubmitted: (_) {
                      if (enabled) onSend();
                    },
                    decoration: InputDecoration(
                      hintText: 'Message MediTwin...',
                      hintStyle: theme.textTheme.bodyMedium?.copyWith(
                        color: AppTheme.textMuted,
                        fontWeight: FontWeight.w600,
                      ),
                      prefixIcon: Icon(
                        Icons.chat_bubble_outline_rounded,
                        color: AppTheme.primaryBlue.withValues(alpha: enabled ? 0.78 : 0.35),
                      ),
                      filled: true,
                      fillColor: enabled ? AppTheme.surfaceSoft.withValues(alpha: 0.62) : AppTheme.surfaceSoft,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(23),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(23),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(23),
                        borderSide: BorderSide.none,
                      ),
                      disabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(23),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.fromLTRB(0, 16, 16, 16),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                height: 56,
                width: 60,
                child: FilledButton(
                  onPressed: enabled ? onSend : null,
                  style: FilledButton.styleFrom(
                    padding: EdgeInsets.zero,
                    backgroundColor: AppTheme.primaryNavy,
                    disabledBackgroundColor: AppTheme.textMuted.withValues(alpha: 0.28),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    elevation: 0,
                  ),
                  child: const Icon(Icons.arrow_upward_rounded),
                ),
              ),
            ],
          ),
        ),
      ),
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
      width: 300,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF6FAFC),
          border: Border(right: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.12))),
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Chats',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900, letterSpacing: -0.35),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${sessions.length} conversations',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    IconButton.filledTonal(
                      onPressed: onNewChat,
                      icon: const Icon(Icons.add_rounded),
                      tooltip: 'New chat',
                    ),
                  ],
                ),
              ),
              Expanded(
                child: sessions.isEmpty
                    ? const Center(child: Text('No conversations yet.'))
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                        itemCount: sessions.length,
                        separatorBuilder: (context, _) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final session = sessions[index];
                          final selected = session.id == activeChatSessionId;
                          return Material(
                            color: selected ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.65) : Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(18),
                              onTap: () => onSelect(session),
                              child: Container(
                                padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: selected
                                        ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.20)
                                        : Theme.of(context).dividerColor.withValues(alpha: 0.08),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            session.title,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '${session.messages.length} messages',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                                          ),
                                        ],
                                      ),
                                    ),
                                    PopupMenuButton<String>(
                                      tooltip: 'Chat options',
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
                                  ],
                                ),
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
    final blocks = _parseBlocks(text);

    if (blocks.isEmpty) return const SizedBox.shrink();

    return SelectionArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < blocks.length; i++) ...[
            _AssistantLine(block: blocks[i], color: color),
            if (i != blocks.length - 1) SizedBox(height: blocks[i].spacingAfter),
          ],
        ],
      ),
    );
  }

  List<_ReplyLine> _parseBlocks(String value) {
    var cleaned = value
        .replaceAll(RegExp(r'<think>[\s\S]*?</think>', caseSensitive: false), '')
        .replaceAll(RegExp(r'</?think>', caseSensitive: false), '')
        .replaceAll(RegExp(r'\*\*([^*]+)\*\*'), r'$1')
        .replaceAll(RegExp(r'__([^_]+)__'), r'$1')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();

    if (cleaned.isEmpty) return const [];

    final result = <_ReplyLine>[];
    final lines = cleaned.split('\n');

    for (final raw in lines) {
      var line = _cleanLine(raw);
      line = line.replaceFirst(RegExp(r'^(?:•|-|\*)\s+(?=\d+[.)]\s+)'), '');
      if (line.isEmpty) {
        _addGap(result);
        continue;
      }

      final split = _splitInlineHeading(line);
      if (split != null) {
        _addHeading(result, split.$1);
        if (split.$2.isNotEmpty) {
          result.add(_ReplyLine(_cleanLine(split.$2), _ReplyLineKind.paragraph));
        }
        continue;
      }

      if (_isKnownHeading(line)) {
        _addHeading(result, line.replaceFirst(RegExp(r':$'), ''));
        continue;
      }

      final numberedBullet = RegExp(r'^\d+[.)]\s+').firstMatch(line);
      if (numberedBullet != null) {
        final withoutNumber = line.replaceFirst(RegExp(r'^\d+[.)]\s+'), '').trim();
        final numberedSplit = _splitInlineHeading(withoutNumber);
        if (numberedSplit != null) {
          _addHeading(result, numberedSplit.$1);
          if (numberedSplit.$2.isNotEmpty) {
            result.add(_ReplyLine(_cleanLine(numberedSplit.$2), _ReplyLineKind.paragraph));
          }
        } else {
          result.add(_ReplyLine(_cleanLine(withoutNumber), _ReplyLineKind.bullet));
        }
        continue;
      }

      final isBullet = RegExp(r'^(•|-|\*)\s+').hasMatch(line);
      if (isBullet) {
        final bulletText = _cleanLine(line.replaceFirst(RegExp(r'^(•|-|\*)\s+'), ''));
        final bulletSplit = _splitInlineHeading(bulletText);
        if (bulletSplit != null) {
          _addHeading(result, bulletSplit.$1);
          if (bulletSplit.$2.isNotEmpty) {
            result.add(_ReplyLine(_cleanLine(bulletSplit.$2), _ReplyLineKind.paragraph));
          }
        } else if (bulletText.isNotEmpty) {
          result.add(_ReplyLine(bulletText, _ReplyLineKind.bullet));
        }
        continue;
      }

      result.add(_ReplyLine(line, _ReplyLineKind.paragraph));
    }

    return _compact(result);
  }

  List<_ReplyLine> _compact(List<_ReplyLine> lines) {
    final compacted = <_ReplyLine>[];
    for (final line in lines) {
      if (line.kind == _ReplyLineKind.gap) {
        if (compacted.isEmpty || compacted.last.kind == _ReplyLineKind.gap) continue;
      }
      if (line.text.trim().isEmpty && line.kind != _ReplyLineKind.gap) continue;
      compacted.add(line);
    }
    while (compacted.isNotEmpty && compacted.last.kind == _ReplyLineKind.gap) {
      compacted.removeLast();
    }
    return compacted;
  }

  void _addGap(List<_ReplyLine> result) {
    if (result.isNotEmpty && result.last.kind != _ReplyLineKind.gap) {
      result.add(const _ReplyLine('', _ReplyLineKind.gap));
    }
  }

  void _addHeading(List<_ReplyLine> result, String heading) {
    final clean = _titleCaseHeading(_cleanLine(heading.replaceFirst(RegExp(r':$'), '')));
    if (clean.isEmpty) return;
    if (result.isNotEmpty && result.last.kind != _ReplyLineKind.gap) {
      result.add(const _ReplyLine('', _ReplyLineKind.gap));
    }
    result.add(_ReplyLine(clean, _ReplyLineKind.heading));
  }

  String _cleanLine(String raw) {
    return raw
        .trim()
        .replaceFirst(RegExp(r'^#{1,6}\s*'), '')
        .replaceAll(RegExp(r'\*\*([^*]+)\*\*'), r'$1')
        .replaceAll(RegExp(r'__([^_]+)__'), r'$1')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  (String, String)? _splitInlineHeading(String line) {
    final match = RegExp(
      r'^(?:\d+[.)]\s*)?(Brief assessment|Assessment|Summary|What you can do now|Next steps|Seek care urgently if|Watch for|Red flags|Question)\s*:\s*(.*)$',
      caseSensitive: false,
    ).firstMatch(line);
    if (match == null) return null;
    return (match.group(1) ?? '', match.group(2)?.trim() ?? '');
  }

  bool _isKnownHeading(String line) {
    final normalized = line.toLowerCase().replaceFirst(RegExp(r':$'), '').trim();
    return normalized == 'brief assessment' ||
        normalized == 'assessment' ||
        normalized == 'summary' ||
        normalized == 'what you can do now' ||
        normalized == 'next steps' ||
        normalized == 'seek care urgently if' ||
        normalized == 'watch for' ||
        normalized == 'red flags' ||
        normalized == 'question';
  }

  String _titleCaseHeading(String value) {
    final normalized = value.toLowerCase().trim();
    switch (normalized) {
      case 'assessment':
      case 'brief assessment':
        return 'Brief assessment';
      case 'summary':
        return 'Summary';
      case 'next steps':
      case 'what you can do now':
        return 'What you can do now';
      case 'watch for':
      case 'red flags':
      case 'seek care urgently if':
        return 'Seek care urgently if';
      case 'question':
        return 'Question';
      default:
        return value;
    }
  }
}

enum _ReplyLineKind { heading, bullet, paragraph, gap }

class _ReplyLine {
  const _ReplyLine(this.text, this.kind);

  final String text;
  final _ReplyLineKind kind;

  double get spacingAfter {
    switch (kind) {
      case _ReplyLineKind.heading:
        return 7;
      case _ReplyLineKind.gap:
        return 4;
      case _ReplyLineKind.bullet:
        return 6;
      case _ReplyLineKind.paragraph:
        return 9;
    }
  }
}

class _AssistantLine extends StatelessWidget {
  const _AssistantLine({required this.block, required this.color});

  final _ReplyLine block;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (block.kind == _ReplyLineKind.gap) return const SizedBox(height: 4);

    final textTheme = Theme.of(context).textTheme;

    if (block.kind == _ReplyLineKind.heading) {
      return Text(
        block.text,
        style: textTheme.titleSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w900,
          height: 1.25,
          letterSpacing: -0.1,
        ),
      );
    }

    if (block.kind == _ReplyLineKind.bullet) {
      return Padding(
        padding: const EdgeInsets.only(left: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.62),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                block.text,
                style: textTheme.bodyMedium?.copyWith(color: color, height: 1.52, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      );
    }

    return Text(
      block.text,
      style: textTheme.bodyMedium?.copyWith(color: color, height: 1.55, fontWeight: FontWeight.w500),
    );
  }
}

class _EmptyChatState extends StatelessWidget {
  const _EmptyChatState({required this.maxWidth});

  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final examples = [
      'I have a headache and mild nausea',
      'Help me improve my sleep routine',
      'What should I track today?',
    ];

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.10)),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.035), blurRadius: 24, offset: const Offset(0, 12)),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(26),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFFCFF9F0), Color(0xFFEAF7FF)]),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Icon(Icons.health_and_safety_rounded, size: 36, color: Theme.of(context).colorScheme.primary),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Start a natural health chat',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900, letterSpacing: -0.35),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Ask about symptoms, sleep, hydration, nutrition, stress, or recovery. MediTwin keeps the conversation context while you chat.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant, height: 1.5),
                  ),
                  const SizedBox(height: 18),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final example in examples)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.10)),
                          ),
                          child: Text(example, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700)),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
