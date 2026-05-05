import 'package:dio/dio.dart';
import 'http_service.dart';

class ImageService {
  final HttpService _httpService;

  ImageService({HttpService? httpService}) : _httpService = httpService ?? HttpService();

  Future<String> generateWithQwen({
    required String prompt,
    String size = '1024*1024',
  }) async {
    final text = prompt.trim();
    if (text.isEmpty) {
      throw Exception('prompt 不能为空');
    }

    try {
      final response = await _httpService.post('/qwen/image', data: {
        'prompt': text,
        'size': size,
      });
      final imageUrl = response.data['image_url'] as String?;
      if (imageUrl == null || imageUrl.isEmpty) {
        throw Exception('后端未返回图片地址');
      }
      return imageUrl;
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode;
      final errorText = e.response?.data.toString() ?? e.message ?? '请求失败';
      throw Exception('生成失败($statusCode): $errorText');
    }
  }
}
