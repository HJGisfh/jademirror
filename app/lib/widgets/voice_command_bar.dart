import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:speech_to_text/speech_recognition_error.dart';
import '../utils/app_theme.dart';
import '../widgets/jade_spirit_pet.dart';

class VoiceCommandBar extends StatefulWidget {
  final ValueChanged<String> onCommand;
  final String hintText;
  final String title;
  final PetState petState;
  final bool autoStartListening;

  const VoiceCommandBar({
    super.key,
    required this.onCommand,
    required this.hintText,
    required this.title,
    this.petState = PetState.idle,
    this.autoStartListening = true,
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

  @override
  void initState() {
    super.initState();
    _initSpeech();
  }

  @override
  void dispose() {
    _speech.stop();
    super.dispose();
  }

  Future<void> _initSpeech() async {
    if (defaultTargetPlatform == TargetPlatform.windows) {
      if (!mounted) return;
      setState(() {
        _available = false;
        _error = 'Windows 桌面暂不支持该语音识别插件。';
      });
      return;
    }

    try {
      final available = await _speech.initialize(
        onStatus: _onStatus,
        onError: _onError,
      );
      if (!mounted) return;
      setState(() => _available = available);
      if (available && widget.autoStartListening) {
        await Future.delayed(const Duration(milliseconds: 220));
        if (mounted) {
          await _toggle();
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _available = false;
        _error = '当前平台暂不支持语音识别。';
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
    setState(() {
      _error = _mapError(error.errorMsg);
      _listening = false;
    });
  }

  String _mapError(String code) {
    switch (code) {
      case 'error_audio':
        return '没有检测到麦克风。';
      case 'error_permission':
        return '麦克风权限未开启。';
      case 'error_network':
        return '语音识别网络异常。';
      default:
        return '语音识别失败，请重试。';
    }
  }

  Future<void> _toggle() async {
    if (!_available) {
      setState(() => _error = '当前设备不支持语音识别。');
      return;
    }

    if (_listening) {
      await _speech.stop();
      if (mounted) setState(() => _listening = false);
      return;
    }

    setState(() {
      _error = '';
      _transcript = '';
    });

    await _speech.listen(
      localeId: 'zh_CN',
      listenOptions: stt.SpeechListenOptions(
        listenMode: stt.ListenMode.confirmation,
      ),
      onResult: (result) {
        final words = result.recognizedWords.trim();
        if (!mounted || words.isEmpty) return;
        setState(() => _transcript = words);
        if (result.finalResult) {
          widget.onCommand(words);
          _speech.stop();
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final displayText = _transcript.isNotEmpty
        ? _transcript
        : _error.isNotEmpty
            ? _error
            : widget.hintText;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: [
          BoxShadow(
            color: AppColors.ink900.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          JadeSpiritPet(state: _listening ? PetState.listening : widget.petState, size: 56),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.title,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  displayText,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: _error.isNotEmpty ? AppColors.danger : AppColors.ink500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: _listening
                    ? [AppColors.amber, AppColors.primaryGradientEnd]
                    : [AppColors.primaryGradientStart, AppColors.primaryGradientEnd],
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryGradientStart.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: IconButton(
              icon: Icon(
                _listening ? Icons.graphic_eq : Icons.mic_rounded,
                size: 20,
                color: AppColors.paperDeep,
              ),
              onPressed: _toggle,
            ),
          ),
        ],
      ),
    );
  }
}
