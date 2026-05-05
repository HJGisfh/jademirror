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

/// 玉灵悬浮球：默认 **自动监听**；**单击** 展开/收起字幕；**长按** 打开设置（声线、监听等）。
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

  /// 所有 `stop` / `listen` 串行执行，避免 `error_busy`。
  Future<void> _sttChain = Future.value();

  Timer? _debounceListen;

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

  bool _canAutoListen() {
    return widget.companion.autoListenStt &&
        _available &&
        !widget.voiceShell.suppressFloatingVoice &&
        !widget.companion.busy;
  }

  void _debouncedStartListen({Duration delay = const Duration(milliseconds: 720)}) {
    if (!_canAutoListen()) return;
    _debounceListen?.cancel();
    _debounceListen = Timer(delay, () {
      _debounceListen = null;
      if (!mounted || !_canAutoListen()) return;
      _runSttSerial(_openListenSession);
    });
  }

  void _cancelDebouncedListen() {
    _debounceListen?.cancel();
    _debounceListen = null;
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
    _cancelDebouncedListen();
    if (_captionsExpanded) {
      widget.onCaptionsExpandedChanged?.call(false);
    }
    widget.voiceShell.removeListener(_onVoiceShellChanged);
    widget.companion.removeListener(_onCompanionChanged);
    unawaited(_speech.stop());
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant VoiceCommandBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.companion.autoListenStt != widget.companion.autoListenStt ||
        oldWidget.companion.silenceThresholdMs != widget.companion.silenceThresholdMs) {
      _cancelDebouncedListen();
      _runSttSerial(() async {
        try {
          await _speech.stop();
        } catch (_) {}
        if (mounted) setState(() => _listening = false);
        await Future.delayed(const Duration(milliseconds: 200));
        if (mounted) _debouncedStartListen();
      });
    }
  }

  void _onCompanionChanged() {
    if (!mounted) return;
    if (widget.companion.busy) {
      _cancelDebouncedListen();
      _runSttSerial(() async {
        try {
          await _speech.stop();
        } catch (_) {}
        if (mounted) setState(() => _listening = false);
      });
    } else {
      _debouncedStartListen();
    }
    setState(() {});
  }

  void _onVoiceShellChanged() {
    if (!mounted) return;
    final sup = widget.voiceShell.suppressFloatingVoice;
    widget.onVoiceShellSuppressChanged?.call(sup);
    if (sup) {
      _wasSuppressed = true;
      _cancelDebouncedListen();
      _runSttSerial(() async {
        try {
          await _speech.stop();
        } catch (_) {}
        if (mounted) setState(() => _listening = false);
      });
    } else if (_wasSuppressed) {
      _wasSuppressed = false;
      _debouncedStartListen();
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
      if (available) {
        _debouncedStartListen(delay: const Duration(milliseconds: 400));
      }
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
    setState(() => _listening = isListening);
  }

  void _onError(SpeechRecognitionError error) {
    if (!mounted) return;
    final code = error.errorMsg;
    final isBusy = code == 'error_busy';
    setState(() {
      _error = isBusy ? '' : _mapError(code);
      _listening = false;
    });
    if (isBusy) {
      _debouncedStartListen(delay: const Duration(milliseconds: 1200));
    } else {
      _debouncedStartListen(delay: const Duration(milliseconds: 900));
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
      default:
        return '语音识别失败，请重试。';
    }
  }

  Future<void> _openListenSession() async {
    if (!_canAutoListen()) return;

    try {
      await _speech.stop();
    } catch (_) {}

    await Future.delayed(Duration(milliseconds: Platform.isAndroid ? 320 : 200));
    if (!mounted || !_canAutoListen()) return;

    if (Platform.isAndroid || Platform.isIOS) {
      final mic = await DeviceSpeechInit.ensureMicrophoneGranted();
      if (!mic) {
        if (mounted) {
          setState(() {
            _error = '麦克风权限未开启。';
          });
        }
        return;
      }
    }

    if (!mounted || !_canAutoListen()) return;
    setState(() {
      _error = '';
      _transcript = '';
    });

    final pauseMs = widget.companion.silenceThresholdMs.clamp(800, 3000);

    try {
      await _speech.listen(
        localeId: 'zh_CN',
        listenFor: const Duration(minutes: 2),
        pauseFor: Duration(milliseconds: pauseMs),
        listenOptions: stt.SpeechListenOptions(
          listenMode: stt.ListenMode.dictation,
          partialResults: true,
          cancelOnError: false,
        ),
        onResult: (result) {
          final words = result.recognizedWords.trim();
          if (!mounted || words.isEmpty) return;
          setState(() => _transcript = words);
          if (result.finalResult) {
            _runSttSerial(() => _finalizeUtterance(words));
          }
        },
      );
    } catch (_) {
      if (mounted) {
        setState(() => _listening = false);
      }
      _debouncedStartListen(delay: const Duration(milliseconds: 1000));
    }
  }

  Future<void> _finalizeUtterance(String words) async {
    try {
      await _speech.stop();
    } catch (_) {}
    await Future.delayed(const Duration(milliseconds: 240));
    if (!mounted) return;
    await widget.onUserSpeech(words);
  }

  Future<void> _openSettings() async {
    _setCaptionsExpanded(false);
    _cancelDebouncedListen();
    await _runSttSerialAndWait(() async {
      try {
        await _speech.stop();
      } catch (_) {}
      await Future.delayed(const Duration(milliseconds: 220));
    });
    if (!mounted) return;
    setState(() => _listening = false);
    await showCompanionSettingsSheet(context);
    if (!mounted) return;
    _debouncedStartListen();
  }

  @override
  Widget build(BuildContext context) {
    final suppressed = widget.voiceShell.suppressFloatingVoice;
    final busy = widget.companion.busy;
    final listenOn = widget.companion.autoListenStt && _available && !suppressed && !busy;

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
        onLongPress: () => unawaited(_openSettings()),
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
        ? '对话中，玉灵已暂停监听'
        : !_available && _engineHint.isNotEmpty
            ? _engineHint
            : busy
                ? '玉灵正在回复…'
                : (_error.isNotEmpty
                    ? _error
                    : (listenOn
                        ? (_transcript.isNotEmpty ? _transcript : widget.hintText)
                        : '自动监听已关闭，可在设置中重新打开'));

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (_captionsExpanded) _buildCaptionsCard(suppressed, busy, listenOn),
        if (!_captionsExpanded &&
            (_transcript.isNotEmpty || _error.isNotEmpty || !listenOn || suppressed || busy))
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
          message: '单击展开/收起字幕；长按打开设置；拖动可移动位置',
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
                        : '自动监听已关闭，可在「长按 → 设置」里打开。',
                style: TextStyle(fontSize: 11, color: AppColors.ink500),
              ),
            ),
        ],
      ),
    );
  }
}
