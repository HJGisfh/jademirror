import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/jade_models.dart';

class JadeLibraryService {
  List<JadeItem>? _cachedJades;

  Future<List<JadeItem>> loadJades() async {
    if (_cachedJades != null) return _cachedJades!;

    final jsonStr = await rootBundle.loadString('assets/data/jades.json');
    final List<dynamic> jsonList = jsonDecode(jsonStr) as List<dynamic>;

    _cachedJades = jsonList.map((j) => JadeItem.fromJson(j as Map<String, dynamic>)).toList();
    return _cachedJades!;
  }

  Future<JadeItem?> getJadeById(int id) async {
    final jades = await loadJades();
    try {
      return jades.firstWhere((j) => j.id == id);
    } catch (_) {
      return null;
    }
  }

  String getSvgAssetPath(String imageRef) {
    final fileName = imageRef.split('/').last;
    return 'assets/svg/$fileName';
  }
}
