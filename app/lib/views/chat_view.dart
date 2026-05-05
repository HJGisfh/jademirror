import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../utils/app_theme.dart';
import '../widgets/common_widgets.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/jade_spirit_pet.dart';
import '../providers/user_provider.dart';
import '../providers/chat_provider.dart';

class ChatView extends StatefulWidget {
  final VoidCallback onBack;

  const ChatView({super.key, required this.onBack});

  @override
  State<ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<ChatView> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();
  PetState _petState = PetState.idle;

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String _getStatusText() {
    switch (_petState) {
      case PetState.listening:
        return '正在聆听...';
      case PetState.thinking:
        return '正在思考...';
      case PetState.speaking:
        return '正在回应...';
      case PetState.idle:
        return '等待你的提问';
    }
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();
    final chatProvider = context.watch<ChatProvider>();
    final jade = userProvider.matchedJade;
    final jadeName = jade?.name ?? '古玉';

    return JadeBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: AppColors.paper.withValues(alpha: 0.9),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 20),
            onPressed: widget.onBack,
          ),
          title: Column(
            children: [
              Text(jadeName, style: const TextStyle(fontSize: 16)),
              Text(
                '${jade?.dynasty ?? ""} · ${userProvider.matchProfile?.archetypeLabel ?? ""}',
                style: TextStyle(fontSize: 11, color: AppColors.ink500),
              ),
            ],
          ),
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 20),
              onPressed: () => chatProvider.clearMessages(),
            ),
          ],
        ),
        body: Column(
          children: [
            JadeSpiritPanel(
              jadeName: jadeName,
              state: _petState,
              statusText: _getStatusText(),
            ),
            Expanded(
              child: ListView(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                children: [
                  if (chatProvider.messages.isEmpty)
                    _buildEmptyState(jadeName, userProvider)
                  else
                    ...chatProvider.messages.map(
                      (msg) => ChatBubble(
                        content: msg.content,
                        isUser: msg.isUser,
                        timestamp: msg.timestamp,
                      ),
                    ),
                ],
              ),
            ),
            if (chatProvider.isSending) _buildTypingIndicator(),
            _buildSuggestedTopics(chatProvider, userProvider),
            _buildInputBar(chatProvider, userProvider),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(String jadeName, UserProvider userProvider) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: AppSpacing.lg),
      child: Column(
        children: [
          Text(
            jadeName,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: AppColors.ink900,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            userProvider.matchProfile?.psychology.coreEnergy ?? '',
            style: TextStyle(fontSize: 13, color: AppColors.ink500),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            '向你的古玉提问，\n它会以千年的智慧回应你。',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: AppColors.ink400,
              height: 1.8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.cardBg,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.cardBorder),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDot(0),
              const SizedBox(width: 4),
              _buildDot(1),
              const SizedBox(width: 4),
              _buildDot(2),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDot(int index) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.4, end: 1.0),
      duration: Duration(milliseconds: 600 + index * 200),
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: AppColors.ink500,
              shape: BoxShape.circle,
            ),
          ),
        );
      },
    );
  }

  Widget _buildSuggestedTopics(ChatProvider chatProvider, UserProvider userProvider) {
    final jade = userProvider.matchedJade;
    if (jade == null) return const SizedBox.shrink();

    final topics = [
      '你的故事',
      '我的性格',
      '如何成长',
      '影子面',
    ];

    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: topics.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          return ActionChip(
            label: Text(
              topics[index],
              style: TextStyle(fontSize: 13, color: AppColors.ink700),
            ),
            backgroundColor: AppColors.jade100,
            side: BorderSide(color: AppColors.jade300),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            onPressed: () {
              final prompts = {
                '你的故事': '请告诉我，你作为${jade.name}的故事和经历。',
                '我的性格': '根据我的MBTI类型${userProvider.mbtiType}，分析我的性格特点。',
                '如何成长': '我应该如何发挥自己的优势，改善不足？',
                '影子面': '我的影子玉是什么？它反映了我哪些盲区？',
              };
              final prompt = prompts[topics[index]] ?? topics[index];
              _sendMessage(chatProvider, userProvider, prompt);
            },
          );
        },
      ),
    );
  }

  Widget _buildInputBar(ChatProvider chatProvider, UserProvider userProvider) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: AppColors.paper.withValues(alpha: 0.95),
          border: Border(top: BorderSide(color: AppColors.cardBorder)),
        ),
        child: Row(
          children: [
            _buildVoiceButton(chatProvider, userProvider),
            const SizedBox(width: 8),
            Expanded(
              child: Container(
                constraints: const BoxConstraints(maxHeight: 100),
                child: TextField(
                  controller: _textController,
                  focusNode: _focusNode,
                  maxLines: null,
                  keyboardType: TextInputType.multiline,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _handleSend(chatProvider, userProvider),
                  decoration: InputDecoration(
                    hintText: '向古玉提问...',
                    hintStyle: TextStyle(color: AppColors.ink400, fontSize: 14),
                    filled: true,
                    fillColor: AppColors.jade100.withValues(alpha: 0.5),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      borderSide: BorderSide(color: AppColors.ink600.withValues(alpha: 0.3)),
                    ),
                  ),
                  style: TextStyle(fontSize: 14, color: AppColors.ink900),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primaryGradientStart, AppColors.primaryGradientEnd],
                ),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.send_rounded, size: 20, color: Color(0xFFf6f7f5)),
                onPressed: chatProvider.isSending
                    ? null
                    : () => _handleSend(chatProvider, userProvider),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVoiceButton(ChatProvider chatProvider, UserProvider userProvider) {
    final isListening = _petState == PetState.listening;

    return GestureDetector(
      onTap: () => _toggleListening(chatProvider, userProvider),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isListening ? AppColors.petListening.withValues(alpha: 0.2) : AppColors.jade100,
          border: Border.all(
            color: isListening ? AppColors.petListening : AppColors.jade300,
            width: isListening ? 2 : 1,
          ),
        ),
        child: Icon(
          isListening ? Icons.mic : Icons.mic_none,
          size: 22,
          color: isListening ? AppColors.petListening : AppColors.ink500,
        ),
      ),
    );
  }

  void _toggleListening(ChatProvider chatProvider, UserProvider userProvider) {
    if (_petState == PetState.listening) {
      setState(() => _petState = PetState.idle);
    } else {
      setState(() => _petState = PetState.listening);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('语音识别尚未接入，当前为演示模式。'),
          duration: Duration(seconds: 2),
        ),
      );
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted && _petState == PetState.listening) {
          setState(() => _petState = PetState.idle);
        }
      });
    }
  }

  void _handleSend(ChatProvider chatProvider, UserProvider userProvider) {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    _textController.clear();
    _sendMessage(chatProvider, userProvider, text);
  }

  void _sendMessage(ChatProvider chatProvider, UserProvider userProvider, String text) {
    final profile = userProvider.matchProfile;
    final jade = userProvider.matchedJade;
    final matchReason = profile?.verdict ?? '';
    final systemPrompt = profile != null && jade != null
        ? '你是${jade.name}，一件${jade.dynasty}的古玉。你的MBTI类型是${profile.mbtiType}，原型是${profile.archetype}。'
            '你的性格：${jade.personality}。请以古玉的口吻与用户对话，温润而深邃，偶尔引用玉文化典故。'
        : null;

    setState(() => _petState = PetState.thinking);
    chatProvider.sendMessage(
      text,
      systemPrompt: systemPrompt,
      jade: jade,
      matchReason: matchReason,
    ).then((_) {
      if (mounted) {
        setState(() => _petState = PetState.speaking);
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) setState(() => _petState = PetState.idle);
        });
      }
    });
    _scrollToBottom();
  }
}
