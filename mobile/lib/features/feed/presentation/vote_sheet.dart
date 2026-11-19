import 'package:material_ui/material_ui.dart';

import '../../../core/models/models.dart';
import '../../../core/theme/app_theme.dart';

Future<String?> showVoteReasonSheet(
  BuildContext context, {
  required VoteDecision decision,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => _VoteReasonSheet(decision: decision),
  );
}

class _VoteReasonSheet extends StatefulWidget {
  const _VoteReasonSheet({required this.decision});

  final VoteDecision decision;

  @override
  State<_VoteReasonSheet> createState() => _VoteReasonSheetState();
}

class _VoteReasonSheetState extends State<_VoteReasonSheet> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.length < 8) {
      setState(() => _error = 'Need at least 8 characters.');
      return;
    }
    if (text.length > 140) {
      setState(() => _error = 'Max 140 characters.');
      return;
    }
    Navigator.of(context).pop(text);
  }

  @override
  Widget build(BuildContext context) {
    final isApprove = widget.decision == VoteDecision.approve;
    final color = isApprove ? AppColors.approve : AppColors.reject;
    final bottom = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.slateMuted.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            isApprove ? 'Why approve?' : 'Why reject?',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 6),
          Text(
            'One honest sentence. Votes without a reason do not count.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _controller,
            maxLength: 140,
            maxLines: 3,
            autofocus: true,
            decoration: InputDecoration(
              hintText: isApprove
                  ? 'e.g. Fair price and you will use it weekly.'
                  : 'e.g. You already own something that does this.',
              errorText: _error,
            ),
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: _submit,
            style: ElevatedButton.styleFrom(backgroundColor: color),
            child: Text(isApprove ? 'Submit Approve' : 'Submit Reject'),
          ),
        ],
      ),
    );
  }
}
