import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ServerConfig {
  ServerConfig._();

  static const _key = 'jademirror_server_url';

  /// 生产环境默认 API 主机（与 deploy/.env 中 PUBLIC_API_BASE 一致）。
  /// 覆盖方式：`flutter build apk --release --dart-define=JADEMIRROR_API_BASE=https://你的域名/api`
  static const String productionHost = 'http://150.109.235.111:5000';

  static Future<String> loadUrl() async {
    const fromBase = String.fromEnvironment('JADEMIRROR_API_BASE', defaultValue: '');
    if (fromBase.isNotEmpty) return _ensureApi(fromBase);
    const fromHost = String.fromEnvironment('JADEMIRROR_DEV_HOST', defaultValue: '');
    if (fromHost.isNotEmpty) return _ensureApi(fromHost);

    if (kReleaseMode) {
      return _ensureApi(productionHost);
    }

    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_key);
    if (saved != null && saved.isNotEmpty) return _ensureApi(saved);
    return _ensureApi(productionHost);
  }

  static Future<void> saveUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, url.trim());
  }

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
}
