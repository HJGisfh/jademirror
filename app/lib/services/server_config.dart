import 'package:shared_preferences/shared_preferences.dart';

class ServerConfig {
  ServerConfig._();

  static const _key = 'jademirror_server_url';

  static Future<String> loadUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_key);
    if (saved != null && saved.isNotEmpty) return _ensureApi(saved);
    return _defaultUrl;
  }

  static Future<void> saveUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, url.trim());
  }

  /// 已提供内置默认 API，不再提示在「我」里填写服务器地址。
  static Future<bool> isConfigured() async => true;

  static String _ensureApi(String url) {
    var trimmed = url.trim().replaceAll(RegExp(r'/+$'), '');
    if (trimmed.endsWith('/api')) trimmed = trimmed.substring(0, trimmed.length - 4);
    if (!trimmed.startsWith('http://') && !trimmed.startsWith('https://')) {
      trimmed = 'http://$trimmed';
    }
    if (trimmed.endsWith('/api')) return trimmed;
    return '$trimmed/api';
  }

  /// 默认后端根（不含 /api 后缀也可，会经 [_ensureApi] 处理）。
  /// - 打 APK 指定局域网：`flutter build apk --release --dart-define=JADEMIRROR_DEV_HOST=http://192.168.1.5:5000`
  /// - 或完整 API 根：`--dart-define=JADEMIRROR_API_BASE=http://...:5000/api`
  /// - 模拟器：`--dart-define=JADEMIRROR_DEV_HOST=http://10.0.2.2:5000`
  /// 100.x 为 Tailscale：手机必须也装 Tailscale，否则请改用上面 192.168.x.x。
  static String get _defaultUrl {
    const env = String.fromEnvironment('JADEMIRROR_API_BASE', defaultValue: '');
    if (env.isNotEmpty) return _ensureApi(env);
    const host = String.fromEnvironment(
      'JADEMIRROR_DEV_HOST',
      defaultValue: 'http://100.81.24.217:5000',
    );
    return _ensureApi(host);
  }
}
