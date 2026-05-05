/// 将后端返回的相对图片路径补全为可给 [Image.network] 使用的绝对地址。
String resolveArtworkImageUrlWithBase(String raw, String apiBase) {
  final u = raw.trim();
  if (u.isEmpty) return u;
  if (u.startsWith('http://') || u.startsWith('https://') || u.startsWith('data:')) {
    return u;
  }
  var origin = apiBase.trim().replaceAll(RegExp(r'/+$'), '');
  if (origin.endsWith('/api')) {
    origin = origin.substring(0, origin.length - 4);
  }
  if (u.startsWith('/')) {
    return '$origin$u';
  }
  return '$origin/$u';
}
