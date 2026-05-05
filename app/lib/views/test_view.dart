import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../utils/app_theme.dart';
import '../widgets/common_widgets.dart';
import '../widgets/question_card.dart';
import '../providers/user_provider.dart';
import '../data/questions.dart';
import 'home_view.dart';

class TestView extends StatefulWidget {
  final VoidCallback onComplete;
  final VoidCallback onBack;
  final VoidCallback onViewResult;
  final VoidCallback onOpenChat;

  const TestView({
    super.key,
    required this.onComplete,
    required this.onBack,
    required this.onViewResult,
    required this.onOpenChat,
  });

  @override
  State<TestView> createState() => _TestViewState();
}

class _TestViewState extends State<TestView> {
  int _currentIndex = 0;
  bool _isSubmitting = false;
  String? _lastTestMode;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<UserProvider>();
    final questions = provider.currentQuestions;
    final total = questions.length;

    final currentMode = provider.testMode;
    if (_lastTestMode != currentMode) {
      _lastTestMode = currentMode;
      _currentIndex = 0;
    }

    if (total > 0 && _currentIndex >= total) {
      _currentIndex = total - 1;
    }

    // 照心首页：未选深度/极简时展示原首页（玉璧、开始照心、模式卡片）
    if (questions.isEmpty) {
      return HomeView(
        onStartTest: () => setState(() {}),
        onViewResult: widget.onViewResult,
        onOpenChat: widget.onOpenChat,
      );
    }

    final current = questions[_currentIndex.clamp(0, total - 1)];
    final selectedValue = provider.testAnswers[current.id];

    return JadeBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 20),
            onPressed: () {
              if (_currentIndex > 0) {
                setState(() => _currentIndex--);
              } else {
                context.read<UserProvider>().exitTestToIntro();
              }
            },
          ),
          title: Text(
            provider.testMode == 'deep' ? '照心 · 拾陆问' : '照心 · 陆问',
            style: const TextStyle(fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () => _showResetDialog(provider),
              child: Text('重置', style: TextStyle(fontSize: 13, color: AppColors.ink500)),
            ),
          ],
        ),
        body: Column(
          children: [
            _buildProgressBar(provider, total),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                child: QuestionCard(
                  question: current,
                  currentIndex: _currentIndex,
                  totalCount: total,
                  selectedValue: selectedValue,
                  showModule: provider.testMode == 'deep',
                  onSelected: (value) => _onOptionSelected(provider, value, total),
                ),
              ),
            ),
            _buildBottomBar(provider, total),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBar(UserProvider provider, int total) {
    final progress = total == 0 ? 0.0 : (provider.answeredCount) / total;
    final currentModule = _getCurrentModule(provider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('第${_currentIndex + 1} / $total 题', style: TextStyle(fontSize: 12, color: AppColors.ink500)),
                const Spacer(),
                Text('已完成 ${provider.answeredCount} 题', style: TextStyle(fontSize: 12, color: AppColors.ink500)),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                backgroundColor: AppColors.jade200.withValues(alpha: 0.72),
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryGradientStart),
              ),
            ),
            if (provider.testMode == 'deep' && currentModule != null) ...[
              const SizedBox(height: AppSpacing.sm),
              _buildModuleProgress(provider),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildModuleProgress(UserProvider provider) {
    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: deepTestModules.map((m) {
        final isActive = _getCurrentModule(provider)?.key == m.key;
        final moduleQuestions = deepTestQuestions.where((q) => q.module == m.key).toList();
        final answered = moduleQuestions.where((q) => provider.testAnswers.containsKey(q.id)).length;
        final isDone = answered == moduleQuestions.length;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(color: isActive ? Colors.transparent : AppColors.ink500.withValues(alpha: 0.18)),
            color: isActive
                ? AppColors.ink700.withValues(alpha: 0.88)
                : isDone
                    ? AppColors.jade200.withValues(alpha: 0.8)
                    : AppColors.paper.withValues(alpha: 0.85),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(m.label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isActive ? AppColors.jade100 : AppColors.ink600)),
              const SizedBox(width: 4),
              Text('$answered/${moduleQuestions.length}', style: TextStyle(fontSize: 10, color: isActive ? AppColors.jade100.withValues(alpha: 0.75) : AppColors.ink500)),
            ],
          ),
        );
      }).toList(),
    );
  }

  TestModule? _getCurrentModule(UserProvider provider) {
    if (provider.testMode != 'deep') return null;
    for (final m in deepTestModules) {
      if (_currentIndex >= m.range[0] && _currentIndex <= m.range[1]) {
        return m;
      }
    }
    return null;
  }

  Widget _buildBottomBar(UserProvider provider, int total) {
    final isLast = _currentIndex == total - 1;
    final hasAnswer = provider.testAnswers.containsKey(provider.currentQuestions[_currentIndex].id);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            if (_currentIndex > 0)
              Expanded(
                child: JadeButton(
                  label: '上一题',
                  isPrimary: false,
                  onPressed: () => setState(() => _currentIndex--),
                ),
              ),
            if (_currentIndex > 0) const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: isLast
                  ? JadeButton(
                      label: '提交并匹配古玉',
                      isPrimary: true,
                      isLoading: _isSubmitting,
                      icon: Icons.auto_awesome,
                      onPressed: hasAnswer && !_isSubmitting ? _submitTest : null,
                    )
                  : JadeButton(
                      label: '下一题',
                      isPrimary: true,
                      onPressed: hasAnswer ? () => setState(() => _currentIndex++) : null,
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _onOptionSelected(UserProvider provider, String value, int total) {
    provider.setAnswer(provider.currentQuestions[_currentIndex].id, value);
    if (_currentIndex < total - 1) {
      Future.delayed(const Duration(milliseconds: 350), () {
        if (mounted) setState(() => _currentIndex++);
      });
    }
  }

  void _showResetDialog(UserProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('重置答案'),
        content: const Text('确定要清除所有已作答的答案吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(
            onPressed: () {
              provider.clearAnswers();
              setState(() => _currentIndex = 0);
              Navigator.pop(ctx);
            },
            child: Text('确定', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
  }

  Future<void> _submitTest() async {
    setState(() => _isSubmitting = true);
    final provider = context.read<UserProvider>();
    await provider.computeAndMatch();
    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (provider.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(provider.error!), backgroundColor: AppColors.danger),
      );
      return;
    }

    widget.onComplete();
  }
}
