import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_screen.dart';
import '../services/http_service.dart';
import 'auth_provider.dart';
import 'user_provider.dart';

/// 玉灵后端返回的导航提示（与 Web `suggested_route` / `next_action` 对齐）。
class CompanionNavigateEvent {
  final String nextAction;
  final String suggestedRoute;
  final Map<String, dynamic> actionPayload;

  const CompanionNavigateEvent({
    required this.nextAction,
    required this.suggestedRoute,
    this.actionPayload = const {},
  });
}

class CompanionMessage {
  final String id;
  final String role;
  final String content;

  CompanionMessage({
    required this.role,
    required this.content,
  }) : id = '${DateTime.now().millisecondsSinceEpoch}-${content.hashCode}';
}

/// 与 Web `assistantStore` 对齐：用户语音转文字后 POST `/assistant/turn`，
/// 空闲约 90s POST `/assistant/proactive`；设置项与 `CompanionSettings.vue` 对齐。
class CompanionProvider extends ChangeNotifier {
  CompanionProvider({
    required AuthProvider auth,
    required UserProvider user,
  })  : _auth = auth,
        _user = user {
    _auth.addListener(_onAuthChanged);
  }

  static const _kAutoListen = 'companion_auto_listen';
  static const _kAutoSpeak = 'companion_auto_speak';
  static const _kAutoGuide = 'companion_auto_guide';
  static const _kIdle = 'companion_idle_enabled';
  static const _kPrivacy = 'companion_privacy_mode';
  static const _kVoicePersona = 'companion_voice_persona';
  static const _kSilenceMs = 'companion_silence_ms';
  static const _personas = {'default', 'warm', 'bright', 'deep'};

  final AuthProvider _auth;
  final UserProvider _user;
  final HttpService _http = HttpService();

  bool _httpReady = false;
  bool _busy = false;
  bool _listeningSuppressed = false;
  bool _welcomed = false;

  String _stage = 'test';
  String _lastReply = '';
  String _lastError = '';
  final List<CompanionMessage> _messages = [];
  int _idleNudgeCount = 0;

  bool _idleEnabled = true;
  bool _autoGuide = true;
  bool _autoSpeak = true;
  bool _autoListenStt = true;
  bool _privacyMode = false;
  String _voicePersona = 'default';
  int _silenceThresholdMs = 1500;

  Timer? _idleTimer;
  static const Duration _idleAfter = Duration(seconds: 90);

  final FlutterTts _tts = FlutterTts();
  bool _ttsInited = false;
  String _emotionalTone = 'calm';

  void Function(CompanionNavigateEvent event)? onNavigate;
  Future<void> Function(String input)? onLegacyVoiceFallback;

  bool get busy => _busy;
  bool get listeningSuppressed => _listeningSuppressed;
  String get stage => _stage;
  String get lastReply => _lastReply;
  String get lastError => _lastError;
  List<CompanionMessage> get messages => List.unmodifiable(_messages);
  bool get autoGuide => _autoGuide;
  bool get idleEnabled => _idleEnabled;
  bool get autoSpeak => _autoSpeak;
  bool get autoListenStt => _autoListenStt;
  bool get privacyMode => _privacyMode;
  String get voicePersona => _voicePersona;
  int get silenceThresholdMs => _silenceThresholdMs;

  String get emotionalToneLabel {
    switch (_emotionalTone) {
      case 'comforting':
        return '安抚';
      case 'cheerful':
        return '轻快';
      case 'energetic':
        return '振奋';
      case 'contemplative':
        return '沉静';
      default:
        return '平和';
    }
  }

  void _onAuthChanged() {
    notifyListeners();
  }

  @override
  void dispose() {
    _auth.removeListener(_onAuthChanged);
    _clearIdleTimer();
    unawaited(_tts.stop());
    super.dispose();
  }

  Future<void> loadPersistedSettings() async {
    final p = await SharedPreferences.getInstance();
    _autoListenStt = p.getBool(_kAutoListen) ?? true;
    _autoSpeak = p.getBool(_kAutoSpeak) ?? true;
    _autoGuide = p.getBool(_kAutoGuide) ?? true;
    _idleEnabled = p.getBool(_kIdle) ?? true;
    _privacyMode = p.getBool(_kPrivacy) ?? false;
    _voicePersona = p.getString(_kVoicePersona) ?? 'default';
    if (!_personas.contains(_voicePersona)) {
      _voicePersona = 'default';
    }
    _silenceThresholdMs = p.getInt(_kSilenceMs) ?? 1500;
    _silenceThresholdMs = _silenceThresholdMs.clamp(800, 3000);
    notifyListeners();
  }

  Future<void> _savePrefs() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kAutoListen, _autoListenStt);
    await p.setBool(_kAutoSpeak, _autoSpeak);
    await p.setBool(_kAutoGuide, _autoGuide);
    await p.setBool(_kIdle, _idleEnabled);
    await p.setBool(_kPrivacy, _privacyMode);
    await p.setString(_kVoicePersona, _voicePersona);
    await p.setInt(_kSilenceMs, _silenceThresholdMs);
  }

  Future<void> setAutoListenStt(bool value) async {
    if (_autoListenStt == value) return;
    _autoListenStt = value;
    await _savePrefs();
    notifyListeners();
  }

  Future<void> setSilenceThresholdMs(int value) async {
    final v = value.clamp(800, 3000);
    if (_silenceThresholdMs == v) return;
    _silenceThresholdMs = v;
    await _savePrefs();
    notifyListeners();
  }

  Future<void> setVoicePersona(String raw) async {
    final v = _personas.contains(raw) ? raw : 'default';
    if (_voicePersona == v) return;
    _voicePersona = v;
    await _savePrefs();
    notifyListeners();
  }

  Future<void> setPrivacyMode(bool value) async {
    if (_privacyMode == value) return;
    _privacyMode = value;
    await _savePrefs();
    notifyListeners();
  }

  /// 与 Web `normalizeStage` 对齐：当前 App 页面对应的 `stage` 传给后端。
  void syncStageFromAppScreen(AppScreen screen) {
    final next = assistantStageForAppScreen(screen);
    if (next != _stage) {
      _stage = next;
      touchActivity();
    }
  }

  void setListeningSuppressed(bool value) {
    if (_listeningSuppressed == value) return;
    _listeningSuppressed = value;
    if (value) {
      _clearIdleTimer();
    } else {
      touchActivity();
    }
    notifyListeners();
  }

  Future<void> setAutoGuide(bool value) async {
    if (_autoGuide == value) return;
    _autoGuide = value;
    await _savePrefs();
    notifyListeners();
  }

  Future<void> setIdleEnabled(bool value) async {
    if (_idleEnabled == value) return;
    _idleEnabled = value;
    if (!value) _clearIdleTimer();
    await _savePrefs();
    touchActivity();
    notifyListeners();
  }

  Future<void> setAutoSpeak(bool value) async {
    if (_autoSpeak == value) return;
    _autoSpeak = value;
    await _savePrefs();
    notifyListeners();
  }

  void _clearIdleTimer() {
    _idleTimer?.cancel();
    _idleTimer = null;
  }

  /// 用户有操作或轮次结束时重置空闲计时（与 Web `touchActivity` 一致）。
  void touchActivity() {
    _clearIdleTimer();
    if (!_idleEnabled || _busy || _listeningSuppressed || _stage == 'login') {
      return;
    }
    _idleTimer = Timer(_idleAfter, () {
      unawaited(_runIdleNudge());
    });
  }

  Future<void> _ensureHttp() async {
    if (!_httpReady) {
      await _http.init();
      _httpReady = true;
    }
    if (_auth.token.isNotEmpty) {
      _http.setToken(_auth.token);
    } else {
      _http.clearToken();
    }
  }

  Future<void> _ensureTts() async {
    if (_ttsInited) return;
    await _tts.setLanguage('zh-CN');
    await _tts.setVolume(1.0);
    _ttsInited = true;
  }

  double _speechRateForTone() {
    var rate = switch (_emotionalTone) {
      'comforting' => 0.38,
      'cheerful' => 0.48,
      'energetic' => 0.48,
      'contemplative' => 0.36,
      _ => 0.42,
    };
    rate += switch (_voicePersona) {
      'warm' => -0.02,
      'bright' => 0.04,
      'deep' => -0.04,
      _ => 0.0,
    };
    return rate.clamp(0.28, 0.58);
  }

  double _personaPitch() {
    return switch (_voicePersona) {
      'warm' => 0.94,
      'bright' => 1.08,
      'deep' => 0.82,
      _ => 1.0,
    };
  }

  Map<String, dynamic> _buildContext() {
    return {
      'hasMatchedJade': _user.hasMatchedJade,
      'hasGeneratedImage': false,
      'worksCount': 0,
      'workPreview': <Map<String, dynamic>>[],
      'matchedJadeName': _user.matchedJade?.name ?? '',
      'currentEmotion': '',
      'idleNudgeCount': _idleNudgeCount,
      'privacy_mode': _privacyMode,
      'voice_persona': _voicePersona,
    };
  }

  void _applyEmotionTone(String? emotion) {
    final normalized = (emotion ?? '').trim().toLowerCase();
    if (normalized.isEmpty) return;
    const map = {
      'calm': 'calm',
      'neutral': 'calm',
      'anxious': 'comforting',
      'sad': 'comforting',
      'worried': 'comforting',
      'happy': 'cheerful',
      'excited': 'energetic',
      'curious': 'cheerful',
      'reflective': 'contemplative',
    };
    _emotionalTone = map[normalized] ?? 'calm';
  }

  Future<void> _speak(String text) async {
    if (!_autoSpeak || text.trim().isEmpty) return;
    try {
      await _ensureTts();
      await _tts.setPitch(_personaPitch());
      await _tts.setSpeechRate(_speechRateForTone());
      await _tts.stop();
      await _tts.speak(text);
    } catch (_) {}
  }

  void _appendMessage(String role, String content) {
    _messages.add(CompanionMessage(role: role, content: content));
    if (_messages.length > 40) {
      _messages.removeRange(0, _messages.length - 40);
    }
    if (role == 'assistant') {
      _lastReply = content;
    }
    notifyListeners();
  }

  Future<void> welcomeIfNeeded() async {
    if (_welcomed) return;
    _welcomed = true;
    const text =
        '我是玉灵童子。我会一直听你说话（可在设置里关闭自动监听）；点小动物打开设置，可调声线、播报与空闲闲聊等。';
    _appendMessage('assistant', text);
    await _speak(text);
    touchActivity();
  }

  Future<void> handleUserText(String raw) async {
    final text = raw.trim();
    if (text.isEmpty || _busy) return;

    _appendMessage('user', text);
    touchActivity();
    await sendTurn(text);
  }

  Future<void> sendTurn(String text) async {
    if (text.trim().isEmpty) return;
    _busy = true;
    _lastError = '';
    notifyListeners();

    try {
      await _ensureHttp();
      final res = await _http.post('/assistant/turn', data: {
        'text': text,
        'stage': _stage,
        'context': _buildContext(),
      });
      final data = res.data;
      if (data is! Map) {
        throw StateError('响应格式异常');
      }
      final map = data.cast<String, dynamic>();
      if (map.containsKey('error')) {
        throw DioException(
          requestOptions: RequestOptions(path: '/assistant/turn'),
          message: map['error']?.toString() ?? '请求失败',
        );
      }

      final reply = (map['reply'] as String?)?.trim().isNotEmpty == true
          ? map['reply'] as String
          : '我在，继续和我说说。';
      final nextAction = (map['next_action'] as String?)?.trim() ?? 'free_chat';
      final suggestedRoute = (map['suggested_route'] as String?)?.trim() ?? '';
      final actionPayload = map['action_payload'] is Map
          ? (map['action_payload'] as Map).cast<String, dynamic>()
          : <String, dynamic>{};

      _applyEmotionTone(map['emotion'] as String?);
      _appendMessage('assistant', reply);
      await _speak(reply);

      if (_autoGuide) {
        onNavigate?.call(CompanionNavigateEvent(
          nextAction: nextAction,
          suggestedRoute: suggestedRoute,
          actionPayload: actionPayload,
        ));
      }
    } catch (e) {
      final msg = _formatError(e);
      _lastError = msg;
      _appendMessage('assistant', '我刚刚有些分神了。你可以再说一次，或改用底部导航。');
      await _speak('我刚刚有些分神了。你可以再说一次。');

      if (onLegacyVoiceFallback != null) {
        try {
          await onLegacyVoiceFallback!(text);
        } catch (_) {}
      }
    } finally {
      _busy = false;
      notifyListeners();
      touchActivity();
    }
  }

  Future<void> _runIdleNudge() async {
    if (!_idleEnabled || _busy || _listeningSuppressed || _stage == 'login') {
      touchActivity();
      return;
    }

    _busy = true;
    _lastError = '';
    notifyListeners();

    try {
      await _ensureHttp();
      final res = await _http.post('/assistant/proactive', data: {
        'stage': _stage,
        'context': _buildContext(),
      });
      final data = res.data;
      if (data is! Map) return;
      final map = data.cast<String, dynamic>();
      if (map.containsKey('error')) {
        throw DioException(
          requestOptions: RequestOptions(path: '/assistant/proactive'),
          message: map['error']?.toString() ?? '请求失败',
        );
      }

      final reply = (map['reply'] as String?)?.trim().isNotEmpty == true
          ? map['reply'] as String
          : '我在这里，想继续哪一步，我都陪你。';
      final nextAction = (map['next_action'] as String?)?.trim() ?? 'free_chat';
      final suggestedRoute = (map['suggested_route'] as String?)?.trim() ?? '';
      final actionPayload = map['action_payload'] is Map
          ? (map['action_payload'] as Map).cast<String, dynamic>()
          : <String, dynamic>{};

      _applyEmotionTone(map['emotion'] as String?);
      _appendMessage('assistant', reply);
      _idleNudgeCount += 1;
      await _speak(reply);

      if (_autoGuide) {
        onNavigate?.call(CompanionNavigateEvent(
          nextAction: nextAction,
          suggestedRoute: suggestedRoute,
          actionPayload: actionPayload,
        ));
      }
    } catch (e) {
      _lastError = _formatError(e);
    } finally {
      _busy = false;
      notifyListeners();
      touchActivity();
    }
  }

  String _formatError(Object e) {
    if (e is DioException) {
      final data = e.response?.data;
      if (data is Map && data['error'] != null) {
        return data['error'].toString();
      }
      if (e.response?.statusCode == 401) {
        return '请先登录后再使用玉灵联网闲聊（「我」页登录）。';
      }
      return e.message ?? e.toString();
    }
    return e.toString();
  }
}
