import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase/supabase.dart';

class AuthUser {
  const AuthUser({required this.id, this.email});

  final String id;
  final String? email;
}

abstract class VaultAuthService {
  const VaultAuthService();

  bool get requiresLogin;
  Future<AuthUser?> restoreSession();
  Future<AuthUser> signIn({required String email, required String password});
  Future<AuthUser> signUp({required String email, required String password});
  Future<void> signOut();
}

class AnonymousVaultAuthService extends VaultAuthService {
  const AnonymousVaultAuthService();

  @override
  bool get requiresLogin => false;

  @override
  Future<AuthUser?> restoreSession() async {
    return const AuthUser(id: 'local-user');
  }

  @override
  Future<AuthUser> signIn({
    required String email,
    required String password,
  }) async {
    return const AuthUser(id: 'local-user');
  }

  @override
  Future<AuthUser> signUp({
    required String email,
    required String password,
  }) async {
    return const AuthUser(id: 'local-user');
  }

  @override
  Future<void> signOut() async {}
}

class SupabaseVaultAuthService extends VaultAuthService {
  const SupabaseVaultAuthService(this.client);

  static const _sessionKey = 'racers_vault.supabase_session';

  final SupabaseClient client;

  @override
  bool get requiresLogin => true;

  @override
  Future<AuthUser?> restoreSession() async {
    final currentUser = client.auth.currentUser;
    if (currentUser != null) {
      return _fromSupabaseUser(currentUser);
    }

    final prefs = await SharedPreferences.getInstance();
    final sessionJson = prefs.getString(_sessionKey);
    if (sessionJson == null || sessionJson.isEmpty) {
      return null;
    }

    try {
      final response = await client.auth.recoverSession(sessionJson);
      final user = response.user;
      if (user == null) {
        return null;
      }

      await _saveCurrentSession();
      return _fromSupabaseUser(user);
    } catch (_) {
      await prefs.remove(_sessionKey);
      return null;
    }
  }

  @override
  Future<AuthUser> signIn({
    required String email,
    required String password,
  }) async {
    final response = await client.auth.signInWithPassword(
      email: email,
      password: password,
    );
    final user = response.user;
    if (user == null) {
      throw StateError('Sign in failed. Check your email and password.');
    }

    await _saveCurrentSession();
    return _fromSupabaseUser(user);
  }

  @override
  Future<AuthUser> signUp({
    required String email,
    required String password,
  }) async {
    final response = await client.auth.signUp(email: email, password: password);
    final user = response.user;
    if (user == null) {
      throw StateError('Could not create account.');
    }

    if (response.session == null) {
      throw StateError(
        'Account created. Check your email to confirm it, then sign in.',
      );
    }

    await _saveCurrentSession();
    return _fromSupabaseUser(user);
  }

  @override
  Future<void> signOut() async {
    await client.auth.signOut();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionKey);
  }

  Future<void> _saveCurrentSession() async {
    final session = client.auth.currentSession;
    if (session == null) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sessionKey, jsonEncode(session.toJson()));
  }

  AuthUser _fromSupabaseUser(User user) {
    return AuthUser(id: user.id, email: user.email);
  }
}
