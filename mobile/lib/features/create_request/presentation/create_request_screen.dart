import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/config/app_config.dart';
import '../../../core/models/models.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/auth_repository.dart';
import '../../feed/feed_repository.dart';

class CreateRequestScreen extends ConsumerStatefulWidget {
  const CreateRequestScreen({super.key});

  @override
  ConsumerState<CreateRequestScreen> createState() =>
      _CreateRequestScreenState();
}

class _CreateRequestScreenState extends ConsumerState<CreateRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _price = TextEditingController();
  final _why = TextEditingController();
  final _alt = TextEditingController();
  final _imageUrl = TextEditingController();
  final _productUrl = TextEditingController();

  CurrencyCode _currency = CurrencyCode.PHP;
  int _durationHours = 6;
  RequestVisibility _visibility = RequestVisibility.public;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      final user = await ref.read(authRepositoryProvider).ensureSession();
      if (mounted) setState(() => _currency = user.currency);
    });
  }

  @override
  void dispose() {
    _title.dispose();
    _price.dispose();
    _why.dispose();
    _alt.dispose();
    _imageUrl.dispose();
    _productUrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      final priceMajor = double.parse(_price.text.trim());
      final priceCents = (priceMajor * 100).round();
      final created = await ref.read(feedRepositoryProvider).createRequest(
            title: _title.text.trim(),
            priceCents: priceCents,
            currency: _currency,
            whyWant: _why.text.trim(),
            cheaperAlt:
                _alt.text.trim().isEmpty ? null : _alt.text.trim(),
            imageUrl: _imageUrl.text.trim().isEmpty
                ? null
                : _imageUrl.text.trim(),
            productUrl: _productUrl.text.trim().isEmpty
                ? null
                : _productUrl.text.trim(),
            durationHours: _durationHours,
            visibility: _visibility,
          );
      ref.invalidate(feedProvider);
      if (!mounted) return;

      if (_visibility == RequestVisibility.circle) {
        final link =
            '${AppConfig.deepLinkScheme}://r/${created.shareToken}';
        final https =
            'https://${AppConfig.httpsFallbackHost}/r/${created.shareToken}';
        await Share.share(
          'Help me decide before I buy “${created.title}”:\n$link\n$https',
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Request submitted. Timer started.')),
      );
      context.go('/feed');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not submit: $e')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ask the crowd')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            Text(
              'Create a purchase request',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 6),
            Text(
              'Set a timer. Get Approve / Reject with real reasons.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _title,
              decoration: const InputDecoration(labelText: 'Item name'),
              validator: (v) {
                final t = v?.trim() ?? '';
                if (t.length < 3) return 'At least 3 characters';
                if (t.length > 80) return 'Max 80 characters';
                return null;
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _price,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Price'),
                    validator: (v) {
                      final n = double.tryParse(v?.trim() ?? '');
                      if (n == null || n < 0) return 'Enter a valid price';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonFormField<CurrencyCode>(
                    key: ValueKey(_currency),
                    initialValue: _currency,
                    decoration: const InputDecoration(labelText: 'Currency'),
                    items: CurrencyCode.values
                        .map(
                          (c) => DropdownMenuItem(
                            value: c,
                            child: Text(c.name),
                          ),
                        )
                        .toList(),
                    onChanged: (c) {
                      if (c != null) setState(() => _currency = c);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _imageUrl,
              decoration: const InputDecoration(
                labelText: 'Image URL (optional)',
                hintText: 'https://…',
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _productUrl,
              decoration: const InputDecoration(
                labelText: 'Product link (optional)',
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _why,
              maxLength: 280,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Why I want it',
              ),
              validator: (v) {
                final t = v?.trim() ?? '';
                if (t.isEmpty) return 'Required';
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _alt,
              maxLength: 280,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Cheaper alternative (optional)',
              ),
            ),
            const SizedBox(height: 8),
            Text('Voting duration', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [1, 6, 24].map((h) {
                final selected = _durationHours == h;
                return ChoiceChip(
                  label: Text('${h}h'),
                  selected: selected,
                  selectedColor: AppColors.mintSoft,
                  onSelected: (_) => setState(() => _durationHours = h),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            Text('Visibility', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            SegmentedButton<RequestVisibility>(
              segments: const [
                ButtonSegment(
                  value: RequestVisibility.public,
                  label: Text('Public Square'),
                  icon: Icon(Icons.public),
                ),
                ButtonSegment(
                  value: RequestVisibility.circle,
                  label: Text('Private Circle'),
                  icon: Icon(Icons.lock_outline),
                ),
              ],
              selected: {_visibility},
              onSelectionChanged: (s) =>
                  setState(() => _visibility = s.first),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _submitting ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.slate,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(52),
              ),
              child: _submitting
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Start the countdown'),
            ),
          ],
        ),
      ),
    );
  }
}
