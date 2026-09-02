import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';

/// The status-chip pattern (colored pill: Published/Draft, Open/Expired,
/// Completed, etc.) was being hand-built with slightly different code in
/// course_detail_screen, exam_list_screen, results_overview_screen, and
/// timeline_screen. Centralizing it here means every status badge in the
/// app now shares one visual language, and a future palette tweak only
/// needs to happen once.
enum StatusTone { primary, success, warning, error, neutral }

class StatusChip extends StatelessWidget {
  final String label;
  final StatusTone tone;
  final IconData? icon;

  const StatusChip({
    super.key,
    required this.label,
    required this.tone,
    this.icon,
  });

  (Color, Color) get _colors {
    switch (tone) {
      case StatusTone.primary:
        return (AppColors.primarySurface, AppColors.primary);
      case StatusTone.success:
        return (AppColors.successSurface, AppColors.success);
      case StatusTone.warning:
        return (AppColors.warningSurface, AppColors.warning);
      case StatusTone.error:
        return (AppColors.errorSurface, AppColors.error);
      case StatusTone.neutral:
        return (AppColors.neutralSurface, AppColors.textSecondary);
    }
  }

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = _colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: fg),
            const SizedBox(width: 4),
          ],
          Text(label, style: AppTypography.label.copyWith(color: fg, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
