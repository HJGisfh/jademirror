import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'server_config.dart';

class HttpService {
  late Dio _dio;
  bool _initialized = false;

  static const String _defaultAuthToken = String.fromEnvironment(
    'JADEMIRROR_AUTH_TOKEN',
    defaultValue: '',
  );

  Future<void> init() async {
    if (_initialized) return;
    final baseUrl = await ServerConfig.loadUrl();
    _initDio(baseUrl);
    _initialized = true;
  }

  Future<void> refreshUrl(String baseUrl) async {
    _initDio(baseUrl);
  }

  void _initDio(String baseUrl) {
    var resolved = _resolveBaseUrl(baseUrl);
    // Dio 与 Uri.resolve：path 以 / 开头会从主机根解析，会丢掉 baseUrl 里的 /api，必须相对拼接
    if (!resolved.endsWith('/')) {
      resolved = '$resolved/';
    }

    _dio = Dio(BaseOptions(
      baseUrl: resolved,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 60),
      headers: {'Content-Type': 'application/json'},
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        handler.next(options);
      },
      onError: (error, handler) {
        handler.next(error);
      },
    ));

    if (_defaultAuthToken.isNotEmpty) {
      setToken(_defaultAuthToken);
    }
  }

  String _resolveBaseUrl(String baseUrl) {
    if (baseUrl.startsWith('http://') || baseUrl.startsWith('https://')) {
      return baseUrl;
    }

    if (kIsWeb) {
      return baseUrl;
    }

    if (baseUrl.startsWith('/')) {
      return 'http://10.0.2.2:5000$baseUrl';
    }

    return 'http://10.0.2.2:5000/$baseUrl';
  }

  void setToken(String token) {
    _dio.options.headers['Authorization'] = 'Bearer $token';
  }

  void clearToken() {
    _dio.options.headers.remove('Authorization');
  }

  String _apiPath(String path) {
    final p = path.trim();
    if (p.startsWith('/')) {
      return p.substring(1);
    }
    return p;
  }

  Future<Response> get(String path, {Map<String, dynamic>? queryParameters}) {
    return _dio.get(_apiPath(path), queryParameters: queryParameters);
  }

  Future<Response> post(String path, {dynamic data}) {
    return _dio.post(_apiPath(path), data: data);
  }
}
