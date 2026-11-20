import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/models/models.dart';
import '../../auth/auth_repository.dart';
import '../feed_repository.dart';

class RequestSafetyMenu extends ConsumerWidget {
  const RequestSafetyMenu({super.key, required this.request, this.onBlocked});

  final PurchaseRequest request;
  final VoidCallback? onBlocked;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<String>(
      itemBuilder: (_) => const [
        PopupMenuItem(value: 'report', child: Text('Report')),
        PopupMenuItem(value: 'block', child: Text('Block user')),
      ],
      onSelected: (action) async {
        final messenger = ScaffoldMessenger.of(context);
        try {
          if (action == 'report') {
            final reason = await showDialog<String>(
              context: context,
              builder: (context) =>
                  SimpleDialog(title: const Text('Report request'), children: [
                for (final reason in [
                  'spam',
                  'harassment',
                  'scam link',
                  'NSFW',
                  'other'
                ])
                  SimpleDialogOption(
                      onPressed: () => Navigator.pop(context, reason),
                      child: Text(reason)),
              ]),
            );
            if (reason == null || !context.mounted) return;
            await ref.read(feedRepositoryProvider).report(
                targetType: 'request', targetId: request.id, reason: reason);
            if (messenger.mounted) {
              messenger.showSnackBar(
                  const SnackBar(content: Text('Report submitted. Thanks.')));
            }
          } else {
            final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                      title: const Text('Block this user?'),
                      content: const Text(
                          'Their purchases will be hidden. You can unblock them in your profile.'),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Cancel')),
                        TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('Block')),
                      ],
                    ));
            if (confirm != true || !context.mounted) return;
            await ref.read(authRepositoryProvider).blockUser(request.ownerId);
            if (!context.mounted) return;
            ref.invalidate(currentUserProvider);
            ref.invalidate(feedProvider);
            onBlocked?.call();
            if (messenger.mounted) {
              messenger
                  .showSnackBar(const SnackBar(content: Text('User blocked.')));
            }
          }
        } catch (_) {
          if (messenger.mounted) {
            messenger.showSnackBar(
                const SnackBar(content: Text('Could not save. Try again.')));
          }
        }
      },
    );
  }
}
