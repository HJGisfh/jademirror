import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../utils/app_theme.dart';
import '../widgets/common_widgets.dart';
import '../providers/auth_provider.dart';
import '../providers/user_provider.dart';
import '../services/http_service.dart';
import '../services/gallery_storage_service.dart';

class GenerateView extends StatefulWidget {
  final VoidCallback onBack;

  const GenerateView({super.key, required this.onBack});

  @override
  State<GenerateView> createState() => _GenerateViewState();
}

class _GenerateViewState extends State<GenerateView> {
  bool _isGenerating = false;
  String? _generatedImageUrl;
  final _httpService = HttpService();

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();
    final jade = userProvider.matchedJade;
    final jadeName = jade?.name ?? '专属玉';
    final profile = userProvider.matchProfile;

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
          title: Text('生成$jadeName像', style: const TextStyle(fontSize: 16)),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildJadeContextCard(jade, profile),
              const SizedBox(height: AppSpacing.lg),
              _buildGeneratedImageArea(jadeName),
              const SizedBox(height: AppSpacing.lg),
              _buildActionButtons(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildJadeContextCard(dynamic jade, dynamic profile) {
    if (jade == null) return const SizedBox.shrink();

    return JadeCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [AppColors.jade200, AppColors.jade300.withValues(alpha: 0.5)],
              ),
            ),
            child: const Icon(Icons.diamond_outlined, size: 22, color: AppColors.ink700),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '基于 "${jade.name}" 生成',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.ink900),
                ),
                const SizedBox(height: 2),
                Text(
                  '${jade.dynasty} · ${profile?.archetypeLabel ?? ""}',
                  style: TextStyle(fontSize: 12, color: AppColors.ink500),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.jade200,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            child: Text('载体', style: TextStyle(fontSize: 10, color: AppColors.ink600)),
          ),
        ],
      ),
    );
  }



  Widget _buildGeneratedImageArea(String jadeName) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 280),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFD8E6D8), Color(0xFFB8CEB8), Color(0xFF9BB89B)],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.ink900.withValues(alpha: 0.12),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            top: 16,
            left: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Text(
                jadeName,
                style: const TextStyle(fontSize: 11, color: Colors.white),
              ),
            ),
          ),
          if (_isGenerating)
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 48,
                  height: 48,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryGradientStart),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  '正在生成玉像...',
                  style: TextStyle(fontSize: 14, color: AppColors.ink500),
                ),
              ],
            )
          else if (_generatedImageUrl != null)
            Image.network(
              _generatedImageUrl!,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 48,
                      color: AppColors.ink400,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      '图片加载失败',
                      style: TextStyle(fontSize: 12, color: AppColors.ink500),
                    ),
                  ],
                );
              },
            )
          else
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.auto_awesome,
                  size: 48,
                  color: AppColors.ink400.withValues(alpha: 0.35),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  '点击生成专属玉像',
                  style: TextStyle(fontSize: 14, color: AppColors.ink400),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '将为 "$jadeName" 创建视觉形象',
                  style: TextStyle(fontSize: 12, color: AppColors.ink400.withValues(alpha: 0.6)),
                ),
              ],
            ),
          Positioned(
            bottom: 10,
            right: 14,
            child: _generatedImageUrl != null
                ? Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: const Text(
                      '✓ 生成完毕',
                      style: TextStyle(fontSize: 10, color: Colors.white),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        JadeButton(
          label: '✨ 生成专属玉像',
          isPrimary: false,
          icon: Icons.auto_awesome,
          isLoading: _isGenerating,
          onPressed: _isGenerating ? null : _generateImage,
        ),
        if (_generatedImageUrl != null) ...[
          const SizedBox(height: AppSpacing.md),
          JadeButton(
            label: '🏛️ 收藏至展厅',
            isPrimary: true,
            icon: Icons.museum_outlined,
            onPressed: _addToGallery,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            '生成结果已保存，可在展厅查看',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: AppColors.ink400),
          ),
        ],
      ],
    );
  }

  Future<void> _generateImage() async {
    final userProvider = context.read<UserProvider>();
    final jade = userProvider.matchedJade;
    if (jade == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('未找到本命玉信息'),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    setState(() => _isGenerating = true);

    try {
      await _httpService.init();
      final auth = context.read<AuthProvider>();
      if (auth.token.isNotEmpty) {
        _httpService.setToken(auth.token);
      } else {
        _httpService.clearToken();
      }

      final prompt = '古代玉器${jade.name}，${jade.dynasty}时期，${jade.traits.color.isNotEmpty ? jade.traits.color : '翡翠'}色泽，${jade.description.isNotEmpty ? jade.description : '精美的玉石雕刻'}';

      final response = await _httpService.post(
        '/qwen/image',
        data: {'prompt': prompt},
      );

      if (!mounted) return;

      final responseData = response.data;
      final imageUrl = responseData['image_url'] as String?;

      if (imageUrl != null && imageUrl.isNotEmpty) {
        setState(() {
          _isGenerating = false;
          _generatedImageUrl = imageUrl;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('✨ 玉像生成完毕！'),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.pill)),
          ),
        );
      } else {
        setState(() => _isGenerating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('⚠️ 未获得图片URL'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isGenerating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('生成失败：${_formatGenerateError(e)}'),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  String _formatGenerateError(Object e) {
    if (e is DioException) {
      final data = e.response?.data;
      if (data is Map && data['error'] != null) {
        return data['error'].toString();
      }
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.sendTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.connectionError) {
        return '无法连接后端，请确认本页使用的服务器与 python 进程已启动';
      }
      return e.message?.isNotEmpty == true ? e.message! : e.toString();
    }
    return e.toString();
  }

  Future<void> _addToGallery() async {
    if (_generatedImageUrl == null) return;
    final userProvider = context.read<UserProvider>();
    final jade = userProvider.matchedJade;
    if (jade == null) return;

    try {
      final artwork = GalleryArtwork(
        id: const Uuid().v4(),
        jadeName: jade.name,
        imageUrl: _generatedImageUrl!,
        prompt: '${jade.name}生成玉像',
        jadeDescription: jade.description,
        jadeDynasty: jade.dynasty,
        createdAt: DateTime.now(),
      );

      await GalleryStorageService().saveArtwork(artwork);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('"${jade.name}" 已收藏至展厅'),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.pill)),
          ),
        );
        // Reset for next generation
        setState(() => _generatedImageUrl = null);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('收藏失败：${e.toString()}'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }
}
