import 'package:flutter/foundation.dart';

/// 协调「玉灵悬浮条」与「对话页语音输入」：同机只允许一路麦克风监听。
class VoiceShellController extends ChangeNotifier {
  int _exclusiveDepth = 0;

  /// 为 true 时悬浮条应停止监听，把麦克风让给对话等页面。
  bool get suppressFloatingVoice => _exclusiveDepth > 0;

  void beginExclusiveVoiceSession() {
    _exclusiveDepth++;
    notifyListeners();
  }

  void endExclusiveVoiceSession() {
    if (_exclusiveDepth > 0) {
      _exclusiveDepth--;
      notifyListeners();
    }
  }
}
