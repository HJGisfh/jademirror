import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../utils/app_theme.dart';
import '../utils/api_image_url.dart';
import '../widgets/common_widgets.dart';
import '../providers/user_provider.dart';
import '../models/jade_models.dart';
import '../services/gallery_storage_service.dart';
import '../services/gallery_bus.dart';
import '../services/server_config.dart';

class GalleryView extends StatefulWidget {
  final VoidCallback onBack;

  const GalleryView({super.key, required this.onBack});

  @override
  State<GalleryView> createState() => _GalleryViewState();
}

class _GalleryViewState extends State<GalleryView> {
  int? _selectedIndex;
  late Future<List<GalleryArtwork>> _artworksFuture;
  late final VoidCallback _galleryRevisionListener;

  Future<List<GalleryArtwork>> _loadResolvedArtworks() async {
    final base = await ServerConfig.loadUrl();
    final raw = await GalleryStorageService().loadArtworks();
    return raw
        .map(
          (a) => GalleryArtwork(
            id: a.id,
            jadeName: a.jadeName,
            imageUrl: resolveArtworkImageUrlWithBase(a.imageUrl, base),
            prompt: a.prompt,
            jadeDescription: a.jadeDescription,
            jadeDynasty: a.jadeDynasty,
            createdAt: a.createdAt,
          ),
        )
        .toList();
  }

  void _reloadArtworks() {
    setState(() {
      _artworksFuture = _loadResolvedArtworks();
    });
  }

  @override
  void initState() {
    super.initState();
    _artworksFuture = _loadResolvedArtworks();
    _galleryRevisionListener = () => _reloadArtworks();
    GalleryBus.revision.addListener(_galleryRevisionListener);
  }

  @override
  void dispose() {
    GalleryBus.revision.removeListener(_galleryRevisionListener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();
    final jade = userProvider.matchedJade;

    return JadeBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 20),
            onPressed: widget.onBack,
          ),
          title: const Text('我的展厅', style: TextStyle(fontSize: 16)),
        ),
        body: FutureBuilder<List<GalleryArtwork>>(
          future: _artworksFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryGradientStart),
                ),
              );
            }

            final items = snapshot.data ?? [];
            if (items.isEmpty) {
              return _buildEmptyState();
            }

            return _buildGalleryGrid(items, jade);
          },
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.museum_outlined,
              size: 72,
              color: AppColors.ink400.withValues(alpha: 0.25),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              '藏室空空如也',
              style: TextStyle(fontSize: 18, color: AppColors.ink500, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              '在「生成」页生成玉像后点「收藏至展厅」，作品会保存在本机；从底部进入展厅即可查看。',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: AppColors.ink400, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGalleryGrid(
    List<GalleryArtwork> items,
    dynamic jade,
  ) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.xs),
          child: Row(
            children: [
              Icon(Icons.collections_bookmark, size: 18, color: AppColors.ink600),
              const SizedBox(width: 8),
              Text(
                '共 ${items.length} 件藏品',
                style: TextStyle(fontSize: 14, color: AppColors.ink500),
              ),
              const Spacer(),
              if (_selectedIndex != null)
                TextButton(
                  onPressed: () => setState(() => _selectedIndex = null),
                  child: const Text('收起', style: TextStyle(fontSize: 13)),
                ),
            ],
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(AppSpacing.md),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: AppSpacing.md,
              crossAxisSpacing: AppSpacing.md,
              childAspectRatio: 0.85,
            ),
            itemCount: items.length + 1,
            itemBuilder: (context, index) {
              if (index < items.length) {
                final item = items[index];
                return _buildGalleryCard(
                  index: index,
                  artwork: item,
                  isSelected: _selectedIndex == index,
                  onTap: () => setState(() {
                    _selectedIndex = _selectedIndex == index ? null : index;
                  }),
                  onDelete: () => _deleteArtwork(item),
                );
              }
              return _buildAddPlaceholder();
            },
          ),
        ),
        if (_selectedIndex != null && _selectedIndex! < items.length)
          _buildDetailPanel(items[_selectedIndex!], jade),
      ],
    );
  }

  Widget _buildGalleryCard({
    required int index,
    required GalleryArtwork artwork,
    required bool isSelected,
    required VoidCallback onTap,
    required VoidCallback onDelete,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          image: DecorationImage(
            image: NetworkImage(artwork.imageUrl),
            fit: BoxFit.cover,
            onError: (exception, stackTrace) {
              // Handle image load error
            },
          ),
          border: Border.all(
            color: isSelected ? AppColors.primaryGradientStart : Colors.transparent,
            width: isSelected ? 2 : 0,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.ink900.withValues(alpha: isSelected ? 0.14 : 0.06),
              blurRadius: isSelected ? 16 : 10,
              offset: Offset(0, isSelected ? 8.0 : 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.lg),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.4),
                  ],
                ),
              ),
            ),
            Positioned(
              bottom: 10,
              left: 10,
              right: 10,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    artwork.jadeName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    artwork.jadeDynasty,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white.withValues(alpha: 0.75),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              top: 6,
              right: 6,
              child: IconButton(
                icon: const Icon(Icons.close, size: 16, color: Colors.white70),
                onPressed: onDelete,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddPlaceholder() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: AppColors.jade300.withValues(alpha: 0.5),
          style: BorderStyle.solid,
          width: 1.5,
        ),
        color: AppColors.jade100.withValues(alpha: 0.3),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add_circle_outline, size: 36, color: AppColors.ink400.withValues(alpha: 0.35)),
            const SizedBox(height: 8),
            Text(
              '生成新玉像',
              style: TextStyle(fontSize: 12, color: AppColors.ink400),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailPanel(
    GalleryArtwork artwork,
    dynamic jade,
  ) {
    final traits = jade?.traits;

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxHeight: 320),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(AppRadius.lg),
          topRight: Radius.circular(AppRadius.lg),
        ),
        border: Border(top: BorderSide(color: AppColors.cardBorder)),
        boxShadow: [
          BoxShadow(
            color: AppColors.ink900.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.cardBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              artwork.jadeName,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.ink900),
            ),
            Text(
              artwork.jadeDynasty,
              style: TextStyle(fontSize: 12, color: AppColors.ink500),
            ),
            const SizedBox(height: AppSpacing.lg),
            _buildJadeIntroCard(artwork.jadeDescription, jade),
            if (traits != null) ...[
              const SizedBox(height: AppSpacing.md),
              _buildTraitChips(traits),
            ],
            const SizedBox(height: AppSpacing.md),
            Divider(color: AppColors.cardBorder),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildDetailAction(Icons.download_outlined, '保存', () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('✓ 已保存'),
                      duration: const Duration(seconds: 1),
                      behavior: SnackBarBehavior.floating,
                      margin: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.pill)),
                    ),
                  );
                }),
                _buildDetailAction(Icons.share_outlined, '分享', () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('分享功能即将开放'),
                      duration: const Duration(seconds: 1),
                      behavior: SnackBarBehavior.floating,
                      margin: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.pill)),
                    ),
                  );
                }),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildJadeIntroCard(String description, dynamic jade) {
    final finalDesc = description.isNotEmpty ? description : '珍贵的玉器文物';

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.jade100.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.jade300.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bookmark_outline, size: 16, color: AppColors.ink600),
              const SizedBox(width: 6),
              Text(
                '玉器介绍',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.ink900),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            finalDesc,
            style: TextStyle(fontSize: 13, color: AppColors.ink700, height: 1.7),
          ),
        ],
      ),
    );
  }

  Widget _buildTraitChips(JadeTraits traits) {
    final map = {
      '山水': traits.landscape,
      '色泽': traits.color,
      '纹样': traits.symbol,
      '气韵': traits.mood,
      '质地': traits.texture,
    };

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: map.entries
          .where((e) => e.value.isNotEmpty)
          .map((e) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.jade200.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  border: Border.all(color: AppColors.jade300.withValues(alpha: 0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      e.key,
                      style: TextStyle(fontSize: 11, color: AppColors.ink500, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      e.value,
                      style: TextStyle(fontSize: 11, color: AppColors.ink700, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ))
          .toList(),
    );
  }

  Widget _buildDetailAction(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: AppColors.ink600),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontSize: 11, color: AppColors.ink500)),
          ],
        ),
      ),
    );
  }

  void _deleteArtwork(GalleryArtwork artwork) async {
    await GalleryStorageService().deleteArtwork(artwork.id);
    if (mounted) setState(() => _selectedIndex = null);
    GalleryBus.notifySaved();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('已移除藏品'),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.pill)),
      ),
    );
  }
}
