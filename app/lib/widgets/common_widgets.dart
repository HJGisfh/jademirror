import 'package:flutter/material.dart';
import '../utils/app_theme.dart';

class JadeCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final Widget? background;

  const JadeCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.onTap,
    this.background,
  });

  @override
  Widget build(BuildContext context) {
    final content = Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(AppSpacing.lg),
      child: child,
    );

    return Container(
      margin: margin ?? const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      child: Material(
        color: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide(color: AppColors.cardBorder),
        ),
        elevation: 0,
        shadowColor: AppColors.ink900.withValues(alpha: 0.08),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: Stack(
            children: [
              if (background != null) Positioned.fill(child: background!),
              Container(
                color: AppColors.cardBg,
                child: onTap == null
                    ? content
                    : InkWell(
                        onTap: onTap,
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        child: content,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class JadeButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isPrimary;
  final bool isWarn;
  final bool isLoading;
  final IconData? icon;
  final double? minWidth;

  const JadeButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isPrimary = true,
    this.isWarn = false,
    this.isLoading = false,
    this.icon,
    this.minWidth,
  });

  @override
  Widget build(BuildContext context) {
    final isEnabled = !isLoading && onPressed != null;
    final effectiveOnPressed = isEnabled ? onPressed : null;
    final opacity = isEnabled ? 1.0 : 0.55;

    Widget button;
    if (isWarn) {
      button = Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.warnGradientStart, AppColors.warnGradientEnd],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(AppRadius.pill),
          boxShadow: [
            BoxShadow(
              color: AppColors.warnGradientStart.withValues(alpha: 0.27),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: effectiveOnPressed,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18.4, vertical: 9.92),
              child: _buildContent(Colors.white),
            ),
          ),
        ),
      );
    } else if (isPrimary) {
      button = Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.primaryGradientStart, AppColors.primaryGradientEnd],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(AppRadius.pill),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryGradientStart.withValues(alpha: 0.27),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: effectiveOnPressed,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18.4, vertical: 9.92),
              child: _buildContent(const Color(0xFFf6f7f5)),
            ),
          ),
        ),
      );
    } else {
      button = Container(
        decoration: BoxDecoration(
          color: AppColors.secondaryBg,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: AppColors.secondaryBorder),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: effectiveOnPressed,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18.4, vertical: 9.92),
              child: _buildContent(AppColors.ink700),
            ),
          ),
        ),
      );
    }

    return Opacity(
      opacity: opacity,
      child: ConstrainedBox(
        constraints: BoxConstraints(minWidth: minWidth ?? 0),
        child: button,
      ),
    );
  }

  Widget _buildContent(Color textColor) {
    if (isLoading) {
      return SizedBox(
        height: 20,
        child: Center(
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(textColor),
            ),
          ),
        ),
      );
    }

    if (icon != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: textColor),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: textColor,
              fontSize: 15.2,
              letterSpacing: 0.02,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      );
    }

    return Text(
      label,
      style: TextStyle(
        color: textColor,
        fontSize: 15.2,
        letterSpacing: 0.02,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class StatusPill extends StatelessWidget {
  final String label;
  final IconData? icon;

  const StatusPill({
    super.key,
    required this.label,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.jade200,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: AppColors.jade300.withValues(alpha: 0.6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: AppColors.ink700),
            const SizedBox(width: 4.8),
          ],
          Text(
            label,
            style: TextStyle(
              color: AppColors.ink700,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class JadeSvgIcon extends StatelessWidget {
  final String assetName;
  final double size;
  final Color? color;

  const JadeSvgIcon({
    super.key,
    required this.assetName,
    this.size = 64,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/svg/$assetName',
      width: size,
      height: size,
      color: color,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: AppColors.jade200,
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.diamond_outlined,
            size: size * 0.5,
            color: AppColors.ink500,
          ),
        );
      },
    );
  }
}

class JadeBackground extends StatelessWidget {
  final Widget child;

  const JadeBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.paper, AppColors.paperDeep],
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(painter: _RadialGradientPainter()),
          ),
          child,
        ],
      ),
    );
  }
}

class _RadialGradientPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint1 = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.72, -0.64),
        radius: 0.28,
        colors: [const Color(0x4DA8D5A8), Colors.transparent],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint1);

    final paint2 = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0.68, -0.68),
        radius: 0.30,
        colors: [const Color(0x66E8D5A3), Colors.transparent],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint2);

    final paint3 = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.64, 0.70),
        radius: 0.22,
        colors: [const Color(0x3390C090), Colors.transparent],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint3);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
