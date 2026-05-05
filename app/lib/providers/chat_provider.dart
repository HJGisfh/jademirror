import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../models/jade_models.dart';
import '../services/http_service.dart';

class ChatMessage {
  final String id;
  final String content;
  final bool isUser;
  final DateTime timestamp;

  const ChatMessage({
    required this.id,
    required this.content,
    required this.isUser,
    required this.timestamp,
  });
}

class ChatProvider extends ChangeNotifier {
  final HttpService _httpService = HttpService();
  bool _httpReady = false;

  List<ChatMessage> _messages = [];
  bool _isSending = false;
  String? _error;

  List<ChatMessage> get messages => _messages;
  bool get isSending => _isSending;
  String? get error => _error;

  void addMessage(String content, {required bool isUser}) {
    final msg = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      content: content,
      isUser: isUser,
      timestamp: DateTime.now(),
    );
    _messages = [..._messages, msg];
    notifyListeners();
  }

  Future<void> initHttp() async {
    if (_httpReady) return;
    await _httpService.init();
    _httpReady = true;
  }

  Future<void> refreshServerUrl(String url) async {
    await _httpService.refreshUrl(url);
    _httpReady = true;
  }

  Future<void> _ensureHttp() async {
    if (!_httpReady) {
      await _httpService.init();
      _httpReady = true;
    }
  }

  Future<void> sendMessage(
    String content, {
    String? systemPrompt,
    JadeItem? jade,
    String? matchReason,
  }) async {
    if (content.trim().isEmpty) return;

    addMessage(content, isUser: true);
    await _ensureHttp();
    _isSending = true;
    _error = null;
    notifyListeners();

    try {
      final payloadMessages = _messages
          .take(_messages.length)
          .toList()
          .reversed
          .take(12)
          .toList()
          .reversed
          .map((m) => {
                'role': m.isUser ? 'user' : 'assistant',
                'content': m.content,
              })
          .toList();

      final response = await _httpService.post('/deepseek/chat', data: {
        'messages': payloadMessages,
        if (systemPrompt != null) 'systemPrompt': systemPrompt,
        if (jade != null)
          'jadeContext': {
            'id': jade.id,
            'name': jade.name,
            'dynasty': jade.dynasty,
            'description': jade.description,
            'traits': {
              'landscape': jade.traits.landscape,
              'color': jade.traits.color,
              'symbol': jade.traits.symbol,
              'mood': jade.traits.mood,
              'texture': jade.traits.texture,
            },
          },
        if (matchReason != null && matchReason.isNotEmpty) 'matchReason': matchReason,
      });

      final reply = response.data['content'] as String? ?? '（沉默片刻）我暂时无法回应。';
      addMessage(reply, isUser: false);
    } catch (e) {
      final dioErr = e is DioException ? e : null;
      final statusCode = dioErr?.response?.statusCode;
      final errMsg = dioErr?.message ?? e.toString();
      if (statusCode == 401) {
        _error = '后端需要登录授权，请先在 backend 关闭 AUTH_REQUIRED 或登录。';
      } else if (dioErr?.type == DioExceptionType.connectionTimeout || dioErr?.type == DioExceptionType.connectionError) {
        _error = '无法连接到服务器，请检查电脑 IP 和端口。\n$errMsg';
      } else {
        _error = errMsg;
      }
      addMessage('（玉镜蒙尘：$_error）', isUser: false);
    } finally {
      _isSending = false;
      notifyListeners();
    }
  }

  void clearMessages() {
    _messages = [];
    notifyListeners();
  }
}
