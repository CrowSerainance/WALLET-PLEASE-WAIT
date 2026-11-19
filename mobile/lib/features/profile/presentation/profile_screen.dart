import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/models/models.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/auth_repository.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _name = TextEditingController();
  CurrencyCode _currency = CurrencyCode.USD;
  bool _loaded = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _hydrate(AppUser user) async {
    if (_loaded) return;
    _name.text = user.displayName;
    _currency = user.currency;
    _loaded = true;
  }

  Future<void> _save() async {
    await ref.read(authRepositoryProvider).updateProfile(
          displayName: _name.text.trim(),
          currency: _currency,
        );
    ref.invalidate(currentUserProvider);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profile updated')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('You')),
      body: userAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (user) {
          if (user == null) {
            return const Center(child: Text('Not signed in'));
          }
          _hydrate(user);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'HoldMyWallet',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              Text(
                'Wallet, Please Wait · ad-supported MVP',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Display name'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<CurrencyCode>(
                key: ValueKey(_currency),
                initialValue: _currency,
                decoration: const InputDecoration(labelText: 'Default currency'),
                items: CurrencyCode.values
                    .map((c) => DropdownMenuItem(value: c, child: Text(c.name)))
                    .toList(),
                onChanged: (c) {
                  if (c != null) setState(() => _currency = c);
                },
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.slate,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Save'),
              ),
              const SizedBox(height: 24),
              const Divider(),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Blocked users'),
                subtitle: Text(
                  user.blockedIds.isEmpty
                      ? 'None'
                      : '${user.blockedIds.length} blocked',
                ),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Community guidelines'),
                subtitle: const Text(
                  'No scams, hate, or NSFW. Reasons required on every vote. Report & block available on every card.',
                ),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Deep links'),
                subtitle: Text(
                  '${AppConfig.deepLinkScheme}://r/{share_token}\n'
                  'https://${AppConfig.httpsFallbackHost}/r/{share_token}',
                ),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Mode'),
                subtitle: Text(
                  AppConfig.useMockData
                      ? 'Mock data (USE_MOCK_DATA=true)'
                      : 'Live Supabase',
                ),
              ),
              if (user.voiceOfReason)
                const ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.military_tech, color: AppColors.approve),
                  title: Text('Voice of Reason'),
                  subtitle: Text('Your helpful votes earned a badge.'),
                ),
            ],
          );
        },
      ),
    );
  }
}
