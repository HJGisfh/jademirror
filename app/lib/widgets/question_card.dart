import 'package:flutter/material.dart';
import '../../utils/app_theme.dart';
import '../../data/questions.dart';
import 'common_widgets.dart';

class QuestionCard extends StatefulWidget {
  final Question question;
  final int currentIndex;
  final int totalCount;
  final String? selectedValue;
  final ValueChanged<String> onSelected;
  final bool showModule;

  const QuestionCard({
    super.key,
    required this.question,
    required this.currentIndex,
    required this.totalCount,
    this.selectedValue,
    required this.onSelected,
    this.showModule = false,
  });

  @override
  State<QuestionCard> createState() => _QuestionCardState();
}

class _QuestionCardState extends State<QuestionCard> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _controller.forward();
  }

  @override
  void didUpdateWidget(QuestionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.question.id != widget.question.id) {
      _controller.reset();
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final q = widget.question;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: AppColors.cardBg,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.cardBorder),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1A203934),
                blurRadius: 30,
                offset: Offset(0, 16),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Text(
                    '第${widget.currentIndex + 1}问',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.ink500,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  StatusPill(label: q.subtitle),
                  const SizedBox(width: 8),
                  Text(
                    '${widget.currentIndex + 1} / ${widget.totalCount}',
                    style: TextStyle(
                      color: AppColors.ink400,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              if (widget.showModule) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  q.moduleTitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.ink400,
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              Text(
                q.title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                  color: AppColors.ink900,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              ...q.options.asMap().entries.map((entry) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: _OptionTile(
                  option: entry.value,
                  index: entry.key,
                  isSelected: widget.selectedValue == entry.value.value,
                  onTap: () => widget.onSelected(entry.value.value),
                ),
              )),
            ],
          ),
        ),
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  final QuestionOption option;
  final int index;
  final bool isSelected;
  final VoidCallback onTap;

  const _OptionTile({
    required this.option,
    required this.index,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected
          ? AppColors.jade200.withValues(alpha: 0.8)
          : AppColors.paper.withValues(alpha: 0.6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: BorderSide(
          color: isSelected
              ? AppColors.primaryGradientStart.withValues(alpha: 0.6)
              : AppColors.cardBorder,
          width: isSelected ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: isSelected
                      ? option.tone.withValues(alpha: 0.25)
                      : AppColors.jade200.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected
                        ? option.tone
                        : AppColors.jade300,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: isSelected
                    ? Icon(Icons.check, size: 16, color: option.tone)
                    : Center(
                        child: Text(
                          option.value,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.ink600,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      option.label,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                        color: isSelected ? AppColors.ink900 : AppColors.ink700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      option.description,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.ink500,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
