import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../core/services/announcement_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import 'app_text_field.dart';

class AnnouncementsFeed extends StatelessWidget {
  final String courseId;
  final bool isInstructor;

  const AnnouncementsFeed({
    super.key,
    required this.courseId,
    required this.isInstructor,
  });

  @override
  Widget build(BuildContext context) {
    final service = AnnouncementService();

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: service.watchAnnouncementsForCourse(courseId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: SelectableText(
                'Could not load announcements: ${snapshot.error}',
                style: AppTypography.bodySecondary.copyWith(
                  color: AppColors.error,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        final items = snapshot.data ?? [];
        if (items.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.campaign_outlined,
                    size: 48,
                    color: AppColors.textTertiary,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    isInstructor
                        ? 'No announcements yet. Tap "New Announcement" to post one.'
                        : 'No announcements from your instructor yet.',
                    style: AppTypography.bodySecondary,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(AppSpacing.lg),
          itemCount: items.length,
          itemBuilder: (context, i) {
            final item = items[i];
            final pinned = item['pinned'] == true;
            final createdAt = (item['createdAt'] as Timestamp?)?.toDate();

            return Card(
              margin: const EdgeInsets.only(bottom: AppSpacing.sm),
              color: pinned ? AppColors.primarySurface : AppColors.surface,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (pinned) ...[
                          const Icon(
                            Icons.push_pin,
                            size: 16,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: AppSpacing.xs),
                        ],
                        Expanded(
                          child: Text(
                            item['title'] ?? '',
                            style: AppTypography.heading3,
                          ),
                        ),
                        if (isInstructor)
                          PopupMenuButton<String>(
                            icon: const Icon(
                              Icons.more_vert,
                              size: 20,
                              color: AppColors.textSecondary,
                            ),
                            onSelected: (value) async {
                              if (value == 'pin') {
                                await service.togglePinned(item['id'], !pinned);
                              } else if (value == 'delete') {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (_) => AlertDialog(
                                    title: const Text('Delete Announcement?'),
                                    content: const Text(
                                      'This cannot be undone.',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(context, false),
                                        child: const Text('Cancel'),
                                      ),
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppColors.error,
                                        ),
                                        onPressed: () =>
                                            Navigator.pop(context, true),
                                        child: const Text('Delete'),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirm == true)
                                  await service.deleteAnnouncement(item['id']);
                              }
                            },
                            itemBuilder: (context) => [
                              PopupMenuItem(
                                value: 'pin',
                                child: Text(pinned ? 'Unpin' : 'Pin to top'),
                              ),
                              const PopupMenuItem(
                                value: 'delete',
                                child: Text('Delete'),
                              ),
                            ],
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(item['message'] ?? '', style: AppTypography.body),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      createdAt != null ? _formatDate(createdAt) : '',
                      style: AppTypography.caption,
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  static String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  /// Called by the parent screen's FAB (only relevant when isInstructor).
  static void showComposeSheet(BuildContext context, String courseId) {
    final service = AnnouncementService();
    final titleController = TextEditingController();
    final messageController = TextEditingController();
    bool pinned = false;
    bool isPosting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
              ),
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(AppSpacing.radiusLg),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('New Announcement', style: AppTypography.heading2),
                    const SizedBox(height: AppSpacing.md),
                    AppTextField(controller: titleController, label: 'Title'),
                    const SizedBox(height: AppSpacing.md),
                    TextField(
                      controller: messageController,
                      maxLines: 4,
                      decoration: const InputDecoration(labelText: 'Message'),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        Checkbox(
                          value: pinned,
                          onChanged: (val) =>
                              setSheetState(() => pinned = val ?? false),
                        ),
                        const Text('Pin to top'),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    ElevatedButton(
                      onPressed: isPosting
                          ? null
                          : () async {
                              if (titleController.text.trim().isEmpty ||
                                  messageController.text.trim().isEmpty)
                                return;
                              setSheetState(() => isPosting = true);
                              final uid =
                                  FirebaseAuth.instance.currentUser!.uid;
                              await service.postAnnouncement(
                                courseId: courseId,
                                title: titleController.text.trim(),
                                message: messageController.text.trim(),
                                createdBy: uid,
                                pinned: pinned,
                              );
                              if (sheetContext.mounted)
                                Navigator.pop(sheetContext);
                            },
                      child: isPosting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Post Announcement'),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
