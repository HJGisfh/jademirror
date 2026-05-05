import 'package:flutter/foundation.dart';

/// 本地展厅数据变更时递增，供 [GalleryView] 重新加载列表。
class GalleryBus {
  GalleryBus._();

  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  static void notifySaved() {
    revision.value++;
  }
}
