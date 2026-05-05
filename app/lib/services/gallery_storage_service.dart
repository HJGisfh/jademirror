import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class GalleryArtwork {
  final String id;
  final String jadeName;
  final String imageUrl;
  final String prompt;
  final String jadeDescription;
  final String jadeDynasty;
  final DateTime createdAt;

  const GalleryArtwork({
    required this.id,
    required this.jadeName,
    required this.imageUrl,
    required this.prompt,
    required this.jadeDescription,
    required this.jadeDynasty,
    required this.createdAt,
  });

  factory GalleryArtwork.fromJson(Map<String, dynamic> json) {
    return GalleryArtwork(
      id: json['id'] as String? ?? '',
      jadeName: json['jadeName'] as String? ?? '古玉',
      imageUrl: json['imageUrl'] as String? ?? '',
      prompt: json['prompt'] as String? ?? '',
      jadeDescription: json['jadeDescription'] as String? ?? '',
      jadeDynasty: json['jadeDynasty'] as String? ?? '',
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'jadeName': jadeName,
      'imageUrl': imageUrl,
      'prompt': prompt,
      'jadeDescription': jadeDescription,
      'jadeDynasty': jadeDynasty,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}

class GalleryStorageService {
  static const String _storageKey = 'jademirror_gallery_artworks';

  Future<List<GalleryArtwork>> loadArtworks() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) {
      return [];
    }

    final decoded = jsonDecode(raw);
    if (decoded is! List) {
      return [];
    }

    return decoded
        .whereType<Map>()
        .map((item) => GalleryArtwork.fromJson(Map<String, dynamic>.from(item)))
        .where((item) => item.imageUrl.isNotEmpty)
        .toList();
  }

  Future<void> saveArtwork(GalleryArtwork artwork) async {
    final prefs = await SharedPreferences.getInstance();
    final items = await loadArtworks();
    final filtered = items.where((item) => item.imageUrl != artwork.imageUrl).toList();
    filtered.insert(0, artwork);
    await prefs.setString(
      _storageKey,
      jsonEncode(filtered.map((item) => item.toJson()).toList()),
    );
  }

  Future<void> deleteArtwork(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final items = await loadArtworks();
    final filtered = items.where((item) => item.id != id).toList();
    await prefs.setString(
      _storageKey,
      jsonEncode(filtered.map((item) => item.toJson()).toList()),
    );
  }

  Future<void> clearArtworks() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
  }
}