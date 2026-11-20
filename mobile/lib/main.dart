import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/config/app_config.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/auth_repository.dart';

Future<void> main() async {
  const ReleaseConfiguration().validate();
  WidgetsFlutterBinding.ensureInitialized();

  if (AppConfig.enableAds) {
    await MobileAds.instance.initialize();
  }

  if (!AppConfig.useMockData) {
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      publishableKey: AppConfig.supabaseAnonKey,
    );
  }

  runApp(const ProviderScope(child: HoldMyWalletApp()));
}

class HoldMyWalletApp extends ConsumerWidget {
  const HoldMyWalletApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'HoldMyWallet',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: appRouter,
      builder: (context, child) => ref.watch(currentUserProvider).when(
            data: (user) =>
                user.acceptedGuidelines ? child! : const _GuidelinesScreen(),
            loading: () => const Scaffold(
                body: Center(child: CircularProgressIndicator())),
            error: (error, stack) => Scaffold(
                body: Center(
                    child: ElevatedButton(
              onPressed: () => ref.invalidate(currentUserProvider),
              child: const Text('Connection failed. Try again'),
            ))),
          ),
    );
  }
}

class _GuidelinesScreen extends ConsumerStatefulWidget {
  const _GuidelinesScreen();

  @override
  ConsumerState<_GuidelinesScreen> createState() => _GuidelinesScreenState();
}

class _GuidelinesScreenState extends ConsumerState<_GuidelinesScreen> {
  bool _saving = false;
  bool _failed = false;

  Future<void> _accept() async {
    setState(() => _saving = true);
    try {
      await ref.read(authRepositoryProvider).acceptGuidelines();
      if (mounted) ref.invalidate(currentUserProvider);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _failed = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: SafeArea(
            child: ListView(padding: const EdgeInsets.all(24), children: [
      Text('Community guidelines',
          style: Theme.of(context).textTheme.headlineMedium),
      const Text(
          'Give an honest reason for each vote. Harassment, scams and explicit content are prohibited. You can report a purchase or block its author.'),
      if (_failed) const Text('Could not save your acceptance. Try again.'),
      ElevatedButton(
          onPressed: _saving ? null : _accept,
          child: const Text('Accept and continue')),
    ])));
  }
}
