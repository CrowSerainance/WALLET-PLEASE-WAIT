import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/app_config.dart';
import '../../core/models/models.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  if (AppConfig.useMockData) return MockAuthRepository();
  return SupabaseAuthRepository(Supabase.instance.client);
});

final currentUserProvider = FutureProvider<AppUser?>((ref) async {
  return ref.watch(authRepositoryProvider).ensureSession();
});

abstract class AuthRepository {
  Future<AppUser> ensureSession();
  Future<AppUser?> currentUser();
  Future<void> updateProfile({
    String? displayName,
    String? region,
    CurrencyCode? currency,
  });
  Future<void> blockUser(String userId);
}

class MockAuthRepository implements AuthRepository {
  AppUser _user = const AppUser(
    id: '00000000-0000-0000-0000-000000000001',
    displayName: 'You',
    region: 'PH',
    currency: CurrencyCode.PHP,
  );

  @override
  Future<AppUser> ensureSession() async => _user;

  @override
  Future<AppUser?> currentUser() async => _user;

  @override
  Future<void> updateProfile({
    String? displayName,
    String? region,
    CurrencyCode? currency,
  }) async {
    _user = AppUser(
      id: _user.id,
      displayName: displayName ?? _user.displayName,
      region: region ?? _user.region,
      currency: currency ?? _user.currency,
      blockedIds: _user.blockedIds,
      voiceOfReason: _user.voiceOfReason,
    );
  }

  @override
  Future<void> blockUser(String userId) async {
    final ids = {..._user.blockedIds, userId}.toList();
    _user = AppUser(
      id: _user.id,
      displayName: _user.displayName,
      region: _user.region,
      currency: _user.currency,
      blockedIds: ids,
      voiceOfReason: _user.voiceOfReason,
    );
  }
}

class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<AppUser> ensureSession() async {
    var session = _client.auth.currentSession;
    if (session == null) {
      final res = await _client.auth.signInAnonymously();
      session = res.session;
    }
    final uid = session!.user.id;
    final row = await _client.from('users').select().eq('id', uid).maybeSingle();
    if (row == null) {
      await _client.from('users').upsert({
        'id': uid,
        'display_name': 'Anonymous',
      });
      return AppUser(
        id: uid,
        displayName: 'Anonymous',
        region: 'US',
        currency: CurrencyCode.USD,
      );
    }
    return AppUser.fromJson(row);
  }

  @override
  Future<AppUser?> currentUser() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return null;
    final row = await _client.from('users').select().eq('id', uid).maybeSingle();
    return row == null ? null : AppUser.fromJson(row);
  }

  @override
  Future<void> updateProfile({
    String? displayName,
    String? region,
    CurrencyCode? currency,
  }) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return;
    await _client.from('users').update({
      if (displayName != null) 'display_name': displayName,
      if (region != null) 'region': region,
      if (currency != null) 'currency': currency.name,
    }).eq('id', uid);
  }

  @override
  Future<void> blockUser(String userId) async {
    await _client.rpc('block_user', params: {'p_blocked': userId});
  }
}
