import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../utils/app_theme.dart';
import '../widgets/common_widgets.dart';
import '../providers/user_provider.dart';

class HomeView extends StatefulWidget {
  final VoidCallback onStartTest;
  final VoidCallback onViewResult;
  final VoidCallback onOpenChat;

  const HomeView({
    super.key,
    required this.onStartTest,
    required this.onViewResult,
    required this.onOpenChat,
  });

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _rotateController;
  late Animation<double> _fadeAnimation;
  bool _showModeCards = false;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _rotateController = AnimationController(
      duration: const Duration(milliseconds: 12000),
      vsync: this,
    )..repeat();

    _fadeAnimation = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    Future.delayed(const Duration(milliseconds: 200), () => _fadeController.forward());
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _rotateController.dispose();
    super.dispose();
  }

  void _startTest(String mode) {
    final userProvider = context.read<UserProvider>();
    userProvider.setTestMode(mode);
    widget.onStartTest();
  }

  @override
  Widget build(BuildContext context) {
    return JadeBackground(
      child: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.lg, AppSpacing.md, AppSpacing.xl),
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Column(
              children: [
                _buildMirrorStage(context),
                const SizedBox(height: AppSpacing.lg),
                _buildFeatureRow(),
                const SizedBox(height: AppSpacing.xl),
                _buildMainCta(context),
                if (_showModeCards) ...[
                  const SizedBox(height: AppSpacing.md),
                  _buildModeCard(
                    seal: '深',
                    title: '玉鉴本心 · 拾陆问',
                    subtitle: '深度测试版',
                    description: '16 道题，四大模块。不仅测表层行为，更测深层动机与压力状态。',
                    tags: ['荣格原型', '大五人格', 'MBTI', '压力边界'],
                    onTap: () => _startTest('deep'),
                  ),
                  _buildModeCard(
                    seal: '微',
                    title: '玉鉴微影 · 陆问',
                    subtitle: '极简高能版',
                    description: '6 道题，刀刀致命。每一题直接对应一个核心维度。',
                    tags: ['开放性', '宜人性', '原型投射', '秩序感'],
                    onTap: () => _startTest('quick'),
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                _buildLinks(context),
                const SizedBox(height: AppSpacing.xxl),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMirrorStage(BuildContext context) {
    return JadeCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(AppSpacing.lg),
      background: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.jade100.withValues(alpha: 0.7), AppColors.paper.withValues(alpha: 0.85)],
          ),
        ),
      ),
      child: Column(
        children: [
          _buildJadeMirror(),
          const SizedBox(height: AppSpacing.lg),
          _buildStageCopy(),
        ],
      ),
    );
  }

  Widget _buildJadeMirror() {
    return SizedBox(
      width: 160,
      height: 160,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: _rotateController,
            builder: (context, child) {
              return Transform.rotate(
                angle: _rotateController.value * math.pi * 2,
                child: Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: SweepGradient(
                      colors: [
                        AppColors.jade200.withValues(alpha: 0.3),
                        AppColors.jade300.withValues(alpha: 0.6),
                        AppColors.primaryGradientStart.withValues(alpha: 0.4),
                        AppColors.jade200.withValues(alpha: 0.3),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                center: const Alignment(-0.3, -0.3),
                radius: 0.8,
                colors: [AppColors.jade200, AppColors.primaryGradientStart.withValues(alpha: 0.8)],
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryGradientStart.withValues(alpha: 0.3),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(Icons.diamond_outlined, size: 36, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildStageCopy() {
    return Column(
      children: [
        Text('JadeMirror · 心象实验场', style: TextStyle(fontSize: 11, letterSpacing: 1.4, color: AppColors.ink500)),
        const SizedBox(height: AppSpacing.sm),
        Text('以玉为镜，照见本心', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, letterSpacing: 1, color: AppColors.ink900)),
        const SizedBox(height: AppSpacing.sm),
        Text('在旋转玉璧中开启一段古今对话。', style: TextStyle(fontSize: 14, color: AppColors.ink500)),
        const SizedBox(height: AppSpacing.xs),
        Text('让传统玉器拥有可对话、可触摸的数字生命。', style: TextStyle(fontSize: 13, color: AppColors.ink400)),
      ],
    );
  }

  Widget _buildFeatureRow() {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      alignment: WrapAlignment.center,
      children: [
        _buildFeaturePill('语音对话'),
        _buildFeaturePill('触玉成乐'),
        _buildFeaturePill('玉灵'),
      ],
    );
  }

  Widget _buildFeaturePill(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: AppColors.ink500.withValues(alpha: 0.2)),
        color: AppColors.jade100.withValues(alpha: 0.82),
      ),
      child: Text(label, style: TextStyle(fontSize: 12, color: AppColors.ink700)),
    );
  }

  Widget _buildMainCta(BuildContext context) {
    return Column(
      children: [
        JadeButton(
          label: _showModeCards ? '收起选择' : '开始照心',
          isPrimary: true,
          icon: _showModeCards ? Icons.expand_less : Icons.auto_awesome,
          onPressed: () => setState(() => _showModeCards = !_showModeCards),
          minWidth: 156,
        ),
      ],
    );
  }

  Widget _buildModeCard({
    required String seal,
    required String title,
    required String subtitle,
    required String description,
    required List<String> tags,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.ink500.withValues(alpha: 0.18)),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.paper.withValues(alpha: 0.92), AppColors.jade100.withValues(alpha: 0.72)],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF3d6b5e), Color(0xFF6a9b89)],
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(seal, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.jade100)),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.ink900)),
                      Text(subtitle, style: TextStyle(fontSize: 11, color: AppColors.ink500)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(description, style: TextStyle(fontSize: 12, color: AppColors.ink500, height: 1.5)),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: tags.map((tag) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    color: AppColors.ink500.withValues(alpha: 0.1),
                  ),
                  child: Text(tag, style: TextStyle(fontSize: 10, color: AppColors.ink600)),
                )).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLinks(BuildContext context) {
    final userProvider = context.watch<UserProvider>();
    final hasMatched = userProvider.hasMatchedJade;

    return Column(
      children: [
        if (hasMatched)
          TextButton(
            onPressed: widget.onViewResult,
            style: TextButton.styleFrom(foregroundColor: AppColors.ink500),
            child: const Text('查看匹配结果', style: TextStyle(fontSize: 13, decoration: TextDecoration.underline)),
          )
        else
          Text(
            '完成测试后可匹配古玉、对话与收藏',
            style: TextStyle(fontSize: 12, color: AppColors.ink400.withValues(alpha: 0.65)),
          ),
      ],
    );
  }
}
