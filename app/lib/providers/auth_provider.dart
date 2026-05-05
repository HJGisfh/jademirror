import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/http_service.dart';

class AuthUser {
  final int id;
  final String username;
  final String nickname;

  const AuthUser({
    required this.id,
    required this.username,
    required this.nickname,
  });

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: json['id'] as int,
      username: json['username'] as String,
      nickname: json['nickname'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'username': username,
        'nickname': nickname,
      };

  String get displayName => nickname.isNotEmpty ? nickname : username;
}

class AuthProvider extends ChangeNotifier {
  static const _userKey = 'jademirror_auth_user';
  static const _tokenKey = 'jademirror_auth_token';

  final HttpService _http = HttpService();
  bool _httpReady = false;

  AuthUser? _currentUser;
  String _token = '';
  bool _sessionChecked = false;
  bool _isLoading = false;
  String? _error;

  AuthUser? get currentUser => _currentUser;
  String get token => _token;
  bool get isLoggedIn => _currentUser != null && _token.isNotEmpty;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String get displayName => _currentUser?.displayName ?? '未登录';

  Future<void> initHttp() async {
    if (_httpReady) return;
    await _http.init();
    _httpReady = true;
  }

  Future<void> refreshServerUrl(String url) async {
    await _http.refreshUrl(url);
    _httpReady = true;
  }

  Future<void> _ensureHttp() async {
    if (!_httpReady) {
      await _http.init();
      _httpReady = true;
    }
  }

  Future<void> loadSession() async {
    await _ensureHttp();
    if (_sessionChecked) return;
    _sessionChecked = true;

    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString(_userKey);
    final savedToken = prefs.getString(_tokenKey) ?? '';

    if (userJson != null && savedToken.isNotEmpty) {
      _currentUser = AuthUser.fromJson(
        (jsonDecode(userJson) as Map).cast<String, dynamic>(),
      );
      _token = savedToken;
      _http.setToken(_token);

      try {
        await fetchMe();
      } catch (_) {
        clearAuth();
      }
    }
    notifyListeners();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    if (_currentUser != null) {
      await prefs.setString(_userKey, jsonEncode(_currentUser!.toJson()));
      await prefs.setString(_tokenKey, _token);
    } else {
      await prefs.remove(_userKey);
      await prefs.remove(_tokenKey);
    }
  }

  void clearAuth() {
    _currentUser = null;
    _token = '';
    _http.clearToken();
    _persist();
    notifyListeners();
  }

  void applyAuth(AuthUser user, String token) {
    _currentUser = user;
    _token = token;
    _http.setToken(token);
    _persist();
    notifyListeners();
  }

  Future<String?> register({
    required String username,
    required String password,
    required String nickname,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _http.post('/auth/register', data: {
        'username': username,
        'password': password,
        'nickname': nickname,
      });

      final data = response.data as Map<String, dynamic>;
      final user = AuthUser.fromJson(data['user'] as Map<String, dynamic>);
      final token = data['token'] as String;
      applyAuth(user, token);
      _isLoading = false;
      notifyListeners();
      return null;
    } catch (e) {
      _isLoading = false;
      _error = _extractError(e);
      notifyListeners();
      return _error;
    }
  }

  Future<String?> login({
    required String username,
    required String password,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _http.post('/auth/login', data: {
        'username': username,
        'password': password,
      });

      final data = response.data as Map<String, dynamic>;
      final user = AuthUser.fromJson(data['user'] as Map<String, dynamic>);
      final token = data['token'] as String;
      applyAuth(user, token);
      _isLoading = false;
      notifyListeners();
      return null;
    } catch (e) {
      _isLoading = false;
      _error = _extractError(e);
      notifyListeners();
      return _error;
    }
  }

  Future<void> fetchMe() async {
    try {
      final response = await _http.get('/auth/me');
      final data = response.data as Map<String, dynamic>;
      _currentUser = AuthUser.fromJson(data['user'] as Map<String, dynamic>);
      _persist();
      notifyListeners();
    } catch (_) {
      clearAuth();
    }
  }

  Future<String?> updatePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _http.post('/auth/update-password', data: {
        'currentPassword': currentPassword,
        'newPassword': newPassword,
      });
      _isLoading = false;
      notifyListeners();
      return null;
    } catch (e) {
      _isLoading = false;
      _error = _extractError(e);
      notifyListeners();
      return _error;
    }
  }

  Future<String?> updateNickname(String nickname) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _http.post('/auth/update-nickname', data: {
        'nickname': nickname,
      });
      _currentUser = AuthUser(
        id: _currentUser!.id,
        username: _currentUser!.username,
        nickname: nickname,
      );
      _persist();
      _isLoading = false;
      notifyListeners();
      return null;
    } catch (e) {
      _isLoading = false;
      _error = _extractError(e);
      notifyListeners();
      return _error;
    }
  }

  Future<void> logout() async {
    try {
      if (_token.isNotEmpty) {
        await _http.post('/auth/logout');
      }
    } catch (_) {}
    clearAuth();
  }

  String _extractError(dynamic e) {
    if (e is DioException) {
      final data = e.response?.data;
      if (data is Map && data.containsKey('error')) {
        return data['error'] as String;
      }
      final msg = e.message ?? '';
      switch (e.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          return '连接超时。请确认手机与电脑在同一 Wi‑Fi，并在「我 → 服务器地址」填写电脑局域网 IP（真机不要用 10.0.2.2，那是模拟器专用）。\n$msg';
        case DioExceptionType.connectionError:
          return _connectionErrorHint(e, msg);
        default:
          if (e.response?.statusCode != null) {
            return '请求失败 (${e.response!.statusCode})：$msg';
          }
          return '网络异常：$msg';
      }
    }
    return e.toString();
  }

  static bool _hostLooksLikeTailscale(String? host) {
    if (host == null || host.isEmpty) return false;
    final parts = host.split('.');
    if (parts.length != 4) return false;
    final a = int.tryParse(parts[0]);
    final b = int.tryParse(parts[1]);
    if (a != 100 || b == null) return false;
    // Tailscale 常用 100.64.0.0/10；其它 100.x 也按虚拟网提示
    return b >= 64 && b <= 127;
  }

  String _connectionErrorHint(DioException e, String msg) {
    final base = e.requestOptions.baseUrl;
    String host = '';
    try {
      host = Uri.parse(base.trim()).host;
    } catch (_) {}

    final tailscaleHint = _hostLooksLikeTailscale(host) ||
            msg.contains('No route to host') && base.contains('100.')
        ? '\n\n【关于 100.x 地址】这是 Tailscale 虚拟网。手机必须安装 Tailscale 并登录与电脑同一账号/网络，才能访问。\n'
            '若不想用 Tailscale：在电脑 cmd 运行 ipconfig，看「无线局域网适配器 WLAN」的 IPv4（如 192.168.x.x），在 App「我 → 服务器地址」填 http://该地址:5000/api；或打包时用：\n'
            'flutter build apk --release --dart-define=JADEMIRROR_DEV_HOST=http://192.168.x.x:5000'
        : '';

    return '无法连接到后端（当前请求：$base）。请检查：① 电脑已运行 app/backend 或 jademirror/backend 的 python；② Windows 防火墙放行端口；③ 真机与电脑同一 Wi‑Fi 或同一 Tailscale；④ 不要用 10.0.2.2（仅模拟器）。$tailscaleHint\n$msg';
  }
}
