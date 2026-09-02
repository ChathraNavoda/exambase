import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';

/// A code (enrollment code, exam code) shown in a pill with a copy icon.
/// Tapping anywhere on it copies the code and shows a brief confirmation —
/// used anywhere a code is displayed so copying behaves the same everywhere.
class CopyableCode extends StatelessWidget {
  final String code;
  final String? label;
  final bool compact;

  const CopyableCode({
    super.key,
    required this.code,
    this.label,
    this.compact = false,
  });

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: code));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${label ?? "Code"} copied: $code')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
      onTap: () => _copy(context),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? AppSpacing.sm : AppSpacing.md,
          vertical: compact ? 4 : AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: AppColors.primarySurface,
          borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              code,
              style: (compact ? AppTypography.label : AppTypography.bodyMedium)
                  .copyWith(color: AppColors.primary, fontWeight: FontWeight.w700),
            ),
            SizedBox(width: compact ? 4 : AppSpacing.xs),
            Icon(Icons.copy_outlined, size: compact ? 13 : 16, color: AppColors.primary),
          ],
        ),
      ),
    );
  }
}
