import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:speech_to_text/speech_recognition_error.dart';
import '../utils/app_theme.dart';
import '../widgets/common_widgets.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/jade_spirit_pet.dart';
import '../providers/user_provider.dart';
import '../providers/chat_provider.dart';
import '../providers/voice_shell_controller.dart';
import '../services/device_speech.dart';

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

  final stt.SpeechToText _chatSpeech = stt.SpeechToText();
  final FlutterTts _flutterTts = FlutterTts();
  bool _chatSpeechReady = false;
  bool _chatListening = false;
  bool _holdDown = false;
  bool _holdShellExclusive = false;
  String _holdBuffer = '';
  bool _autoSpeakReply = true;
  bool _voiceBusy = false;
  VoiceShellController? _voiceShell;
  String _speechHint = '';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _voiceShell = context.read<VoiceShellController>();
  }

  @override
  void initState() {
    super.initState();
    _initChatTts();
    _initChatSpeech();
  }

  Future<void> _initChatTts() async {
    try {
      await _flutterTts.setLanguage('zh-CN');
      await _flutterTts.setSpeechRate(0.45);
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(1.0);
    } catch (_) {}
  }

  Future<void> _initChatSpeech() async {
    if (defaultTargetPlatform == TargetPlatform.windows) return;
    try {
      final ok = await DeviceSpeechInit.initSpeechToText(
        _chatSpeech,
        onStatus: (s) {
          if (!mounted) return;
          if (s == 'listening') {
            setState(() {
              _chatListening = true;
              _petState = PetState.listening;
            });
          } else if (s == 'notListening') {
            setState(() {
              _chatListening = false;
              if (!_holdDown && _petState == PetState.listening) {
                _petState = PetState.idle;
              }
            });
          }
        },
        onError: (SpeechRecognitionError e) {
          if (!mounted) return;
          setState(() {
            _chatListening = false;
            _petState = PetState.idle;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('语音识别：${e.errorMsg}')),
          );
        },
      );
      if (mounted) {
        setState(() {
          _chatSpeechReady = ok;
          _speechHint = ok ? '' : DeviceSpeechInit.unavailableUserHint();
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _chatSpeechReady = false;
          _speechHint = DeviceSpeechInit.unavailableUserHint();
        });
      }
    }
  }

  @override
  void dispose() {
    if (_holdShellExclusive) {
      _voiceShell?.endExclusiveVoiceSession();
      _holdShellExclusive = false;
    }
    unawaited(_chatSpeech.stop());
    unawaited(_flutterTts.stop());
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
    if (!_chatSpeechReady) {
      if (defaultTargetPlatform == TargetPlatform.windows) {
        return '当前平台不支持语音输入';
      }
      return _speechHint.isNotEmpty ? '语音不可用，见下方说明' : '正在准备麦克风…';
    }
    switch (_petState) {
      case PetState.listening:
        return _holdDown ? '按住说话中…' : '正在聆听…';
      case PetState.thinking:
        return '正在思考...';
      case PetState.speaking:
        return '正在回应...';
      case PetState.idle:
        return '可文字或语音与玉交流';
    }
  }

  void _mergeTranscript(String transcript) {
    final t = transcript.trim();
    if (t.isEmpty) return;
    final cur = _textController.text.trim();
    _textController.text = cur.isEmpty ? t : '$cur $t';
    _textController.selection = TextSelection.collapsed(offset: _textController.text.length);
  }

  Future<void> _runExclusiveVoice(Future<void> Function() body) async {
    final shell = _voiceShell ?? context.read<VoiceShellController>();
    shell.beginExclusiveVoiceSession();
    setState(() => _voiceBusy = true);
    try {
      await body();
    } finally {
      shell.endExclusiveVoiceSession();
      if (mounted) setState(() => _voiceBusy = false);
    }
  }

  Future<void> _voiceInputOnce() async {
    if (!_chatSpeechReady || _voiceBusy) {
      if (!_chatSpeechReady) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('当前设备不支持或未授权语音识别')),
        );
      }
      return;
    }

    await _runExclusiveVoice(() async {
      await _chatSpeech.stop();
      await Future.delayed(const Duration(milliseconds: 120));
      final completer = Completer<String>();
      var settled = false;

      void finish(String v) {
        if (settled) return;
        settled = true;
        if (!completer.isCompleted) completer.complete(v);
      }

      await _chatSpeech.listen(
        localeId: 'zh_CN',
        listenOptions: stt.SpeechListenOptions(listenMode: stt.ListenMode.confirmation),
        onResult: (result) {
          final words = result.recognizedWords.trim();
          if (words.isEmpty) return;
          if (result.finalResult) {
            finish(words);
            unawaited(_chatSpeech.stop());
          }
        },
      );

      final text = await completer.future.timeout(
        const Duration(seconds: 25),
        onTimeout: () {
          unawaited(_chatSpeech.stop());
          return '';
        },
      );
      _mergeTranscript(text);
    });
  }

  Future<void> _holdPointerDown() async {
    if (!_chatSpeechReady || _voiceBusy) return;
    setState(() {
      _holdDown = true;
      _petState = PetState.listening;
      _holdBuffer = '';
    });
    final shell = _voiceShell ?? context.read<VoiceShellController>();
    shell.beginExclusiveVoiceSession();
    _holdShellExclusive = true;
    try {
      await _chatSpeech.stop();
      await Future.delayed(const Duration(milliseconds: 80));
      await _chatSpeech.listen(
        localeId: 'zh_CN',
        listenOptions: stt.SpeechListenOptions(listenMode: stt.ListenMode.dictation),
        onResult: (r) {
          _holdBuffer = r.recognizedWords;
        },
      );
    } catch (_) {
      await _chatSpeech.stop();
      if (_holdShellExclusive) {
        shell.endExclusiveVoiceSession();
        _holdShellExclusive = false;
      }
      if (mounted) {
        setState(() {
          _holdDown = false;
          _petState = PetState.idle;
        });
      }
    }
  }

  Future<void> _holdPointerUp() async {
    await _chatSpeech.stop();
    if (_holdShellExclusive && mounted) {
      (_voiceShell ?? context.read<VoiceShellController>()).endExclusiveVoiceSession();
      _holdShellExclusive = false;
    }
    if (!_holdDown) return;
    setState(() => _holdDown = false);
    final t = _holdBuffer.trim();
    if (t.isNotEmpty) {
      _mergeTranscript(t);
    }
    if (mounted) setState(() => _petState = PetState.idle);
  }

  Future<void> _stopChatListen() async {
    await _chatSpeech.stop();
    if (mounted) {
      setState(() {
        _chatListening = false;
        _holdDown = false;
        _petState = PetState.idle;
      });
    }
  }

  Future<void> _speakLatestAssistant(ChatProvider chatProvider) async {
    if (!_autoSpeakReply) return;
    for (final m in chatProvider.messages.reversed) {
      if (!m.isUser && m.content.trim().isNotEmpty) {
        try {
          await _flutterTts.stop();
          await _flutterTts.speak(m.content.trim());
        } catch (_) {}
        break;
      }
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
              icon: Icon(_autoSpeakReply ? Icons.volume_up_outlined : Icons.volume_off_outlined, size: 20),
              tooltip: '自动播报玉音',
              onPressed: () => setState(() => _autoSpeakReply = !_autoSpeakReply),
            ),
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
            if (!_chatSpeechReady &&
                _speechHint.isNotEmpty &&
                (Platform.isAndroid || Platform.isIOS))
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.sm),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.jade100.withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: AppColors.jade300),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          _speechHint,
                          style: TextStyle(fontSize: 12, height: 1.35, color: AppColors.ink600),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: [
                            TextButton(
                              onPressed: () => DeviceSpeechInit.openAppPermissionSettings(),
                              child: const Text('打开应用设置'),
                            ),
                            TextButton(
                              onPressed: () => unawaited(_initChatSpeech()),
                              child: const Text('重试语音'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_chatSpeechReady) ...[
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: chatProvider.isSending || _voiceBusy || _holdDown
                          ? null
                          : () => unawaited(_voiceInputOnce()),
                      icon: Icon(
                        _voiceBusy ? Icons.hourglass_top : Icons.mic_none,
                        size: 18,
                        color: AppColors.ink600,
                      ),
                      label: Text(_voiceBusy ? '聆听中…' : '语音输入'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.ink700,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Listener(
                      onPointerDown: (_) => unawaited(_holdPointerDown()),
                      onPointerUp: (_) => unawaited(_holdPointerUp()),
                      onPointerCancel: (_) => unawaited(_holdPointerUp()),
                      child: Material(
                        color: _holdDown ? AppColors.petListening.withValues(alpha: 0.25) : AppColors.jade100,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        child: Container(
                          alignment: Alignment.center,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                            border: Border.all(
                              color: _holdDown ? AppColors.petListening : AppColors.jade300,
                            ),
                          ),
                          child: Text(
                            _holdDown ? '松开结束' : '按住说话',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: _holdDown ? AppColors.petListening : AppColors.ink700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: '停止聆听',
                    onPressed: _chatListening ? () => unawaited(_stopChatListen()) : null,
                    icon: const Icon(Icons.stop_circle_outlined),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            Row(
              children: [
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
          ],
        ),
      ),
    );
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
    unawaited(_flutterTts.stop());
    chatProvider
        .sendMessage(
          text,
          systemPrompt: systemPrompt,
          jade: jade,
          matchReason: matchReason,
        )
        .then((_) async {
      if (!mounted) return;
      setState(() => _petState = PetState.speaking);
      await _speakLatestAssistant(chatProvider);
      if (mounted) {
        setState(() => _petState = PetState.idle);
      }
    });
    _scrollToBottom();
  }
}
