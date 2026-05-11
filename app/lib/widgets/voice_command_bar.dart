import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:speech_to_text/speech_recognition_error.dart';

import '../providers/companion_provider.dart';
import '../providers/voice_shell_controller.dart';
import '../services/device_speech.dart';
import '../utils/app_theme.dart';
import 'companion_settings_sheet.dart';
import 'jade_spirit_pet.dart';

/// 玉灵悬浮球：**按住说话**，松开发送；**单击** 展开/收起字幕；设置在字幕面板内。
///
/// Android 上 `error_busy` 多因 **listen 重叠** 或 **stop 未完成又 listen**。
/// 此处用 **串行队列** + **防抖** + **stop 后短延迟** 再 `listen`。
class VoiceCommandBar extends StatefulWidget {
  final CompanionProvider companion;
  final VoiceShellController voiceShell;
  final String hintText;
  final String title;
  final PetState petState;
  final ValueChanged<DragUpdateDetails>? onPetPanUpdate;
  final Future<void> Function(String text) onUserSpeech;
  final ValueChanged<bool>? onVoiceShellSuppressChanged;
  /// 字幕展开时通知壳层，用于扩大拖动边界。
  final ValueChanged<bool>? onCaptionsExpandedChanged;

  const VoiceCommandBar({
    super.key,
    required this.companion,
    required this.voiceShell,
    required this.hintText,
    required this.title,
    required this.petState,
    required this.onUserSpeech,
    this.onVoiceShellSuppressChanged,
    this.onCaptionsExpandedChanged,
    this.onPetPanUpdate,
  });

  @override
  State<VoiceCommandBar> createState() => _VoiceCommandBarState();
}

class _VoiceCommandBarState extends State<VoiceCommandBar> {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _available = false;
  bool _listening = false;
  String _transcript = '';
  String _error = '';
  String _engineHint = '';
  bool _wasSuppressed = false;
  bool _captionsExpanded = false;
  String _pendingTranscript = '';
  bool _sessionFinalized = false;
  bool _holding = false;

  /// 所有 `stop` / `listen` 串行执行，避免 `error_busy`。
  Future<void> _sttChain = Future.value();

  bool _restartingEngine = false;

  void _setCaptionsExpanded(bool value) {
    if (_captionsExpanded == value) return;
    setState(() => _captionsExpanded = value);
    widget.onCaptionsExpandedChanged?.call(value);
  }

  void _toggleCaptions() {
    _setCaptionsExpanded(!_captionsExpanded);
  }

  void _runSttSerial(Future<void> Function() op) {
    _sttChain = _sttChain.then((_) async {
      try {
        await op();
      } catch (_) {}
    });
  }

  /// 等待队列中本次任务结束（用于设置页打开前必须停干净引擎）。
  Future<void> _runSttSerialAndWait(Future<void> Function() op) {
    final done = Completer<void>();
    _sttChain = _sttChain.then((_) async {
      try {
        await op();
      } catch (_) {
      } finally {
        if (!done.isCompleted) done.complete();
      }
    });
    return done.future;
  }

  bool _canHoldListen() {
    return _available &&
        !widget.voiceShell.suppressFloatingVoice &&
        !widget.companion.busy;
  }

  @override
  void initState() {
    super.initState();
    widget.voiceShell.addListener(_onVoiceShellChanged);
    widget.companion.addListener(_onCompanionChanged);
    widget.onVoiceShellSuppressChanged?.call(widget.voiceShell.suppressFloatingVoice);
    _initSpeech();
  }

  @override
  void dispose() {
    if (_captionsExpanded) {
      widget.onCaptionsExpandedChanged?.call(false);
    }
    widget.voiceShell.removeListener(_onVoiceShellChanged);
    widget.companion.removeListener(_onCompanionChanged);
    unawaited(_speech.stop());
    super.dispose();
  }

  void _onCompanionChanged() {
    if (!mounted) return;
    if (widget.companion.busy) {
      _holding = false;
      _runSttSerial(() async {
        try {
          await _speech.stop();
        } catch (_) {}
        if (mounted) setState(() => _listening = false);
      });
    }
    setState(() {});
  }

  void _onVoiceShellChanged() {
    if (!mounted) return;
    final sup = widget.voiceShell.suppressFloatingVoice;
    widget.onVoiceShellSuppressChanged?.call(sup);
    if (sup) {
      _wasSuppressed = true;
      _holding = false;
      _runSttSerial(() async {
        try {
          await _speech.stop();
        } catch (_) {}
        if (mounted) setState(() => _listening = false);
      });
    } else if (_wasSuppressed) {
      _wasSuppressed = false;
    }
    setState(() {});
  }

  Future<void> _initSpeech() async {
    if (defaultTargetPlatform == TargetPlatform.windows) {
      if (!mounted) return;
      setState(() {
        _available = false;
        _engineHint = 'Windows 桌面暂不支持该语音识别插件。';
      });
      return;
    }

    try {
      final available = await DeviceSpeechInit.initSpeechToText(
        _speech,
        onStatus: _onStatus,
        onError: _onError,
      );
      if (!mounted) return;
      setState(() {
        _available = available;
        if (!available) {
          _engineHint = DeviceSpeechInit.unavailableUserHint();
          _error = '';
        } else {
          _engineHint = '';
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _available = false;
        _engineHint = '语音识别初始化异常，请点「重试」或在小动物设置里检查权限。';
      });
    }
  }

  void _onStatus(String status) {
    final isListening = status == 'listening';
    if (!mounted) return;
    final wasListening = _listening;
    setState(() => _listening = isListening);
    if (wasListening && !isListening && !_sessionFinalized && !_holding) {
      final pending = _pendingTranscript.trim();
      if (pending.isNotEmpty) {
        _sessionFinalized = true;
        _runSttSerial(() => _finalizeUtterance(pending));
      }
    }
  }

  void _onError(SpeechRecognitionError error) {
    if (!mounted) return;
    final code = error.errorMsg;
    final isBusy = code == 'error_busy';
    final isClient = code == 'error_client';
    setState(() {
      _error = isBusy ? '' : _mapError(code);
      _listening = false;
    });
    _holding = false;
    if (isClient) {
      _runSttSerial(_restartSpeechEngine);
    }
  }

  String _mapError(String code) {
    switch (code) {
      case 'error_audio':
        return '没有检测到麦克风。';
      case 'error_permission':
        return '麦克风权限未开启。';
      case 'error_network':
        return '语音识别网络异常。';
      case 'error_busy':
        return '识别引擎忙，正在自动重试…';
      case 'error_client':
        return '识别引擎异常，正在恢复…';
      default:
        return '语音识别失败，请重试。';
    }
  }

  Future<void> _restartSpeechEngine() async {
    if (_restartingEngine) return;
    _restartingEngine = true;
    try {
      try {
        await _speech.cancel();
      } catch (_) {}
      try {
        await _speech.stop();
      } catch (_) {}
      await Future.delayed(const Duration(milliseconds: 420));
      if (!mounted) return;
      await _initSpeech();
    } finally {
      _restartingEngine = false;
    }
  }

  Future<void> _openListenSession() async {
    if (!_canHoldListen() || !_holding) {
      _holding = false;
      return;
    }

    try {
      try {
        await _speech.cancel();
      } catch (_) {}
      await _speech.stop();
    } catch (_) {}

    await Future.delayed(Duration(milliseconds: Platform.isAndroid ? 320 : 200));
    if (!mounted || !_canHoldListen() || !_holding) {
      _holding = false;
      return;
    }

    if (Platform.isAndroid || Platform.isIOS) {
      final mic = await DeviceSpeechInit.ensureMicrophoneGranted();
      if (!mic) {
        if (mounted) {
          setState(() {
            _error = '麦克风权限未开启。';
          });
        }
        _holding = false;
        return;
      }
    }

    if (!mounted || !_canHoldListen() || !_holding) {
      _holding = false;
      return;
    }
    setState(() {
      _error = '';
      _transcript = '';
    });
    _pendingTranscript = '';
    _sessionFinalized = false;

    try {
      await _speech.listen(
        localeId: 'zh_CN',
        listenFor: const Duration(minutes: 2),
        pauseFor: const Duration(seconds: 5),
        listenOptions: stt.SpeechListenOptions(
          listenMode: stt.ListenMode.dictation,
          partialResults: true,
          cancelOnError: false,
        ),
        onResult: (result) {
          final words = result.recognizedWords.trim();
          if (!mounted || words.isEmpty) return;
          _pendingTranscript = words;
          setState(() => _transcript = words);
          if (result.finalResult && !_sessionFinalized) {
            _sessionFinalized = true;
            _runSttSerial(() => _finalizeUtterance(words));
          }
        },
      );
    } catch (_) {
      if (mounted) {
        setState(() => _listening = false);
      }
      _holding = false;
    }
  }

  void _startHoldListen() {
    if (!_canHoldListen() || _holding) return;
    _holding = true;
    _pendingTranscript = '';
    _sessionFinalized = false;
    setState(() {
      _error = '';
      _transcript = '';
    });
    _runSttSerial(_openListenSession);
  }

  void _stopHoldListen() {
    if (!_holding) return;
    _holding = false;
    _runSttSerial(() async {
      try {
        await _speech.stop();
      } catch (_) {}
      await Future.delayed(const Duration(milliseconds: 180));
      if (!mounted || _sessionFinalized) return;
      final words = _pendingTranscript.trim();
      if (words.isEmpty) return;
      _sessionFinalized = true;
      await _finalizeUtterance(words);
    });
  }

  Future<void> _finalizeUtterance(String words) async {
    try {
      await _speech.stop();
    } catch (_) {}
    await Future.delayed(const Duration(milliseconds: 240));
    if (!mounted) return;
    
    // 🔥 语音识别纠错：修复常见误识别（与jademirror voiceStore对齐）
    final corrected = _correctTranscript(words);
    await widget.onUserSpeech(corrected);
  }

  /// 修正语音识别中的常见错误（与jademirror voiceStore.correctTranscript对齐）
  String _correctTranscript(String text) {
    String result = text;
    
    // 优先匹配完整短语（避免误伤）
    final phraseCorrections = {
      '与域对话': '与玉对话',
      '玉域对话': '与玉对话',
      '遇域对话': '与玉对话',
      '与鱼对话': '与玉对话',
      '生成域': '生成玉',
      '生成鱼': '生成玉',
      '匹配域': '匹配玉',
      '匹配鱼': '匹配玉',
      '古域': '古玉',
      '古鱼': '古玉',
      '域灵童子': '玉灵童子',
      '鱼灵童子': '玉灵童子',
      '域器': '玉器',
      '鱼器': '玉器',
    };
    
    for (final entry in phraseCorrections.entries) {
      result = result.replaceAll(entry.key, entry.value);
    }
    
    return result;
  }

  Future<void> _openSettings() async {
    _setCaptionsExpanded(false);
    _holding = false;
    await _runSttSerialAndWait(() async {
      try {
        await _speech.stop();
      } catch (_) {}
      await Future.delayed(const Duration(milliseconds: 220));
    });
    if (!mounted) return;
    setState(() => _listening = false);
    await showCompanionSettingsSheet(context);
  }

  @override
  Widget build(BuildContext context) {
    final suppressed = widget.voiceShell.suppressFloatingVoice;
    final busy = widget.companion.busy;
    final listenOn = _available && !suppressed && !busy;

    final pet = JadeSpiritPet(
      state: suppressed
          ? PetState.idle
          : busy
              ? PetState.thinking
              : (_listening ? PetState.listening : widget.petState),
      size: 52,
    );

    final bubble = Material(
      elevation: 6,
      shadowColor: AppColors.ink900.withValues(alpha: 0.18),
      shape: const CircleBorder(),
      color: AppColors.cardBg,
      child: GestureDetector(
        onPanUpdate: widget.onPetPanUpdate,
        onTap: _toggleCaptions,
        onLongPressStart: (_) => _startHoldListen(),
        onLongPressEnd: (_) => _stopHoldListen(),
        onLongPressCancel: _stopHoldListen,
        child: SizedBox(
          width: 58,
          height: 58,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Center(child: pet),
              if (listenOn && _listening)
                Positioned(
                  right: 2,
                  top: 2,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: AppColors.petListening,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.cardBg, width: 1),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );

    final tip = suppressed
      ? '对话中，玉灵已暂停语音'
      : !_available && _engineHint.isNotEmpty
        ? _engineHint
        : busy
          ? '玉灵正在回复…'
          : (_error.isNotEmpty
            ? _error
            : (_holding || _listening)
              ? (_transcript.isNotEmpty ? _transcript : '正在聆听…')
              : widget.hintText);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (_captionsExpanded) _buildCaptionsCard(suppressed, busy, listenOn),
        if (!_captionsExpanded &&
            (_transcript.isNotEmpty || _error.isNotEmpty || listenOn || suppressed || busy))
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 220),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 6, right: 2),
              child: Text(
                tip,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 10.5,
                  height: 1.25,
                  color: _error.isNotEmpty ? AppColors.danger : AppColors.ink500,
                ),
              ),
            ),
          ),
        Tooltip(
          message: '单击展开/收起字幕；按住说话、松开发送；拖动可移动位置',
          child: Opacity(
            opacity: suppressed ? 0.55 : 1,
            child: bubble,
          ),
        ),
        if (!_available && (Platform.isAndroid || Platform.isIOS))
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: TextButton(
              onPressed: () => unawaited(_initSpeech()),
              child: const Text('重试语音', style: TextStyle(fontSize: 11)),
            ),
          ),
      ],
    );
  }

  Widget _buildCaptionsCard(bool suppressed, bool busy, bool listenOn) {
    final msgs = widget.companion.messages;
    final tail = msgs.length > 12 ? msgs.sublist(msgs.length - 12) : msgs;

    return Container(
      width: 288,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: [
          BoxShadow(
            color: AppColors.ink900.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text(
                '字幕',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink900,
                ),
              ),
              const Spacer(),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                icon: Icon(Icons.settings, size: 18, color: AppColors.ink500),
                tooltip: '设置',
                onPressed: () => unawaited(_openSettings()),
              ),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                icon: Icon(Icons.expand_more, size: 22, color: AppColors.ink500),
                tooltip: '收起',
                onPressed: () => _setCaptionsExpanded(false),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (_transcript.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '正在识别',
                    style: TextStyle(fontSize: 10, color: AppColors.ink400),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _transcript,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.35,
                      color: AppColors.ink700,
                    ),
                  ),
                ],
              ),
            ),
          if (tail.isEmpty && _transcript.isEmpty)
            Text(
              '暂无对话。说话时识别文字与玉灵回复会显示在这里。',
              style: TextStyle(fontSize: 12, height: 1.35, color: AppColors.ink500),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220),
              child: ListView.builder(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: tail.length,
                itemBuilder: (context, i) {
                  final m = tail[i];
                  final isUser = m.role == 'user';
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isUser ? '你' : '玉灵',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: isUser ? AppColors.ink500 : AppColors.primaryGradientStart,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          m.content,
                          style: TextStyle(
                            fontSize: 12.5,
                            height: 1.35,
                            color: AppColors.ink700,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          if (_error.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                _error,
                style: TextStyle(fontSize: 11.5, color: AppColors.danger),
              ),
            ),
          if (!listenOn && _error.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                suppressed
                    ? '对话中，已暂停监听。'
                    : busy
                        ? '玉灵正在回复…'
                        : '按住小动物说话，松开发送。',
                style: TextStyle(fontSize: 11, color: AppColors.ink500),
              ),
            ),
        ],
      ),
    );
  }
}
