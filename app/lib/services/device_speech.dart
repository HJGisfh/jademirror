import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

/// 各厂商 Android（含荣耀/华为）上语音识别常见失败原因：
/// 未声明 [RecognitionService] 包可见性、未动态申请麦克风、系统无默认识别引擎等。
class DeviceSpeechInit {
  DeviceSpeechInit._();

  static String unavailableUserHint() {
    return '语音不可用：① 为本应用打开「麦克风」权限；② 系统「语言与输入法」中设置默认识别引擎，或安装「Google 语音服务」；③ 已授权仍失败可点下方「打开应用设置」检查。无语音时可用文字输入。';
  }

  /// 申请麦克风；未永久拒绝时不弹系统设置页。
  static Future<bool> ensureMicrophoneGranted() async {
    if (kIsWeb) return false;
    if (!Platform.isAndroid && !Platform.isIOS) return false;
    final status = await Permission.microphone.status;
    if (status.isGranted) return true;
    final req = await Permission.microphone.request();
    return req.isGranted;
  }

  static Future<void> openAppPermissionSettings() => openAppSettings();

  /// 先麦克风权限，再初始化 [SpeechToText]；Android 上失败会短暂重试一次。
  static Future<bool> initSpeechToText(
    stt.SpeechToText speech, {
    required void Function(String status) onStatus,
    required void Function(SpeechRecognitionError error) onError,
  }) async {
    if (defaultTargetPlatform == TargetPlatform.windows) {
      return false;
    }

    if (Platform.isAndroid || Platform.isIOS) {
      final mic = await ensureMicrophoneGranted();
      if (!mic) return false;
      if (Platform.isAndroid) {
        await Future.delayed(const Duration(milliseconds: 200));
      }
    }

    Future<bool> once() => speech.initialize(
          onStatus: onStatus,
          onError: onError,
          finalTimeout: const Duration(seconds: 45),
        );

    var ok = await once();
    if (!ok && Platform.isAndroid) {
      await Future.delayed(const Duration(milliseconds: 450));
      ok = await once();
    }
    return ok;
  }
}
