import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../utils/app_theme.dart';
import '../widgets/common_widgets.dart';
import '../providers/user_provider.dart';
import '../data/questions.dart';
import '../models/jade_models.dart';

class ResultView extends StatelessWidget {
  final VoidCallback onBack;
  final VoidCallback onChat;
  final VoidCallback onGenerate;
  final VoidCallback onGallery;
  final VoidCallback onRetest;

  const ResultView({
    super.key,
    required this.onBack,
    required this.onChat,
    required this.onGenerate,
    required this.onGallery,
    required this.onRetest,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<UserProvider>();
    final jade = provider.matchedJade;
    final profile = provider.matchProfile;
    final dimensionScores = provider.dimensionScores;

    if (jade == null || profile == null) {
      return JadeBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, size: 20),
              onPressed: onBack,
            ),
            title: const Text('照心结果', style: TextStyle(fontSize: 16)),
          ),
          body: const Center(child: Text('尚未完成测试')),
        ),
      );
    }

    return JadeBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 20),
            onPressed: onBack,
          ),
          title: const Text('照心结果', style: TextStyle(fontSize: 16)),
          actions: [
            IconButton(
              icon: const Icon(Icons.chat_bubble_outline, size: 22),
              onPressed: onChat,
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.only(
            left: AppSpacing.md,
            right: AppSpacing.md,
            bottom: AppSpacing.xxl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildJadeHeader(context, jade, profile, provider.matchScore),
              const SizedBox(height: AppSpacing.lg),
              _buildTraitsCard(jade),
              const SizedBox(height: AppSpacing.lg),
              _buildVerdictCard(profile),
              const SizedBox(height: AppSpacing.lg),
              _buildMbtiSection(provider),
              const SizedBox(height: AppSpacing.lg),
              _buildDimensionRadar(context, dimensionScores),
              const SizedBox(height: AppSpacing.lg),
              _buildArchetypeBars(context, dimensionScores),
              const SizedBox(height: AppSpacing.lg),
              _buildPsychologyCard(profile),
              const SizedBox(height: AppSpacing.lg),
              _buildShadowSection(provider),
              const SizedBox(height: AppSpacing.xl),
              _buildActionButtons(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildJadeHeader(
    BuildContext context,
    JadeItem jade,
    JadeProfile profile,
    double matchScore,
  ) {
    final matchPercent = (matchScore * 100).round().clamp(0, 100);

    return JadeCard(
      child: Column(
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.jade200, AppColors.jade300.withValues(alpha: 0.5)],
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.ink600.withValues(alpha: 0.12),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Icon(
              Icons.diamond_outlined,
              size: 40,
              color: AppColors.ink700,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            jade.name,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.ink900,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${jade.dynasty} · ${profile.archetypeLabel}',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.ink500,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              StatusPill(label: profile.mbtiType),
              const SizedBox(width: 8),
              StatusPill(label: profile.archetype),
              const SizedBox(width: 8),
              StatusPill(label: '匹配度 $matchPercent%'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVerdictCard(JadeProfile profile) {
    return JadeCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_stories, size: 18, color: AppColors.ink600),
              const SizedBox(width: 8),
              Text(
                '专属判词',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink900,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            profile.verdict,
            style: TextStyle(
              fontSize: 14.5,
              height: 1.9,
              color: AppColors.ink700,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTraitsCard(JadeItem jade) {
    final traits = jade.traits;

    return JadeCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.local_florist, size: 18, color: AppColors.ink600),
              const SizedBox(width: 8),
              Text(
                '玉之五感',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink900,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              _buildTraitItem('山水', traits.landscape),
              _buildTraitItem('色泽', traits.color),
              _buildTraitItem('象意', traits.symbol),
              _buildTraitItem('气韵', traits.mood),
              _buildTraitItem('质地', traits.texture),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTraitItem(String label, String value) {
    final displayValue = value.isEmpty ? '—' : value;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.jade100,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.jade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: AppColors.ink500,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            displayValue,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.ink700,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMbtiSection(UserProvider provider) {
    final mbti = provider.mbtiType;
    final archetype = provider.archetype;

    return JadeCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              children: [
                Text(
                  mbti,
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink900,
                    letterSpacing: 4,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'MBTI 人格',
                  style: TextStyle(fontSize: 12, color: AppColors.ink500),
                ),
              ],
            ),
          ),
          Container(width: 1, height: 48, color: AppColors.cardBorder),
          Expanded(
            child: Column(
              children: [
                Text(
                  archetype?.label ?? '',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '荣格原型',
                  style: TextStyle(fontSize: 12, color: AppColors.ink500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDimensionRadar(BuildContext context, DimensionScores? scores) {
    if (scores == null) return const SizedBox.shrink();

    return JadeCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.radar, size: 18, color: AppColors.ink600),
              const SizedBox(width: 8),
              Text(
                'MBTI 维度分析',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink900,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          ...mbtiDims.map((key) {
            final score = scores.mbti[key];
            if (score == null) return const SizedBox.shrink();
            return _DimensionBar(
              label: vectorLabels[key] ?? key,
              dominant: score.dominant,
              percent: score.percent,
            );
          }),
        ],
      ),
    );
  }

  Widget _buildArchetypeBars(BuildContext context, DimensionScores? scores) {
    if (scores == null) return const SizedBox.shrink();

    return JadeCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.psychology, size: 18, color: AppColors.ink600),
              const SizedBox(width: 8),
              Text(
                '荣格原型分布',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink900,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          ...archetypeDims.map((key) {
            final score = scores.archetypes[key];
            if (score == null) return const SizedBox.shrink();
            return _DimensionBar(
              label: vectorLabels[key] ?? key,
              percent: score.percent,
              barColor: AppColors.ink600.withValues(alpha: 0.6),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildPsychologyCard(JadeProfile profile) {
    return JadeCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.psychology_outlined, size: 18, color: AppColors.ink600),
              const SizedBox(width: 8),
              Text(
                '心理学侧写',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink900,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _buildInfoRow('核心能量', profile.psychology.coreEnergy),
          const SizedBox(height: AppSpacing.sm),
          _buildInfoRow('性格底色', profile.psychology.baseColor),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: AppColors.ink500,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            color: AppColors.ink700,
            height: 1.6,
          ),
        ),
      ],
    );
  }

  Widget _buildShadowSection(UserProvider provider) {
    final shadowJade = provider.shadowJade;
    final shadowProfile = provider.shadowProfile;
    if (shadowJade == null || shadowProfile == null) return const SizedBox.shrink();

    return JadeCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.dark_mode_outlined, size: 18, color: AppColors.amber),
              const SizedBox(width: 8),
              Text(
                '影子面 · 盲区提醒',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink900,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            '你的影子玉：${shadowJade.name}',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.amber,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            shadowProfile.shadowBlindSpot,
            style: TextStyle(
              fontSize: 14,
              color: AppColors.ink700,
              height: 1.7,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.jade100.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.lightbulb_outline, size: 16, color: AppColors.ink600),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    shadowProfile.shadowAdvice,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.ink700,
                      height: 1.6,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Column(
      children: [
        JadeButton(
          label: '💬 与古玉对话',
          isPrimary: true,
          icon: Icons.chat_bubble_outline,
          onPressed: onChat,
        ),
        const SizedBox(height: AppSpacing.md),
        JadeButton(
          label: '🎨 生成专属玉像',
          isPrimary: false,
          icon: Icons.image_outlined,
          onPressed: onGenerate,
        ),
        const SizedBox(height: AppSpacing.md),
        JadeButton(
          label: '🏛️ 收藏至展厅',
          isPrimary: false,
          icon: Icons.museum_outlined,
          onPressed: onGallery,
        ),
        const SizedBox(height: AppSpacing.lg),
        JadeButton(
          label: '重新测试',
          isPrimary: false,
          isWarn: false,
          onPressed: onRetest,
        ),
      ],
    );
  }
}

class _DimensionBar extends StatelessWidget {
  final String label;
  final String? dominant;
  final int percent;
  final Color? barColor;

  const _DimensionBar({
    required this.label,
    required this.percent,
    this.dominant,
    this.barColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.ink700,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (dominant != null)
                Text(
                  dominant!,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.ink600,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              Text(
                '$percent%',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.ink500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: percent / 100,
              minHeight: 6,
              backgroundColor: AppColors.jade200,
              valueColor: AlwaysStoppedAnimation<Color>(
                barColor ?? AppColors.ink600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
