import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:supabase/supabase.dart';

import 'app.dart';
import 'services/auth_service.dart';
import 'services/car_recognition_service.dart';
import 'services/supabase_vault_repository.dart';
import 'services/vault_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const recognizerUrl = String.fromEnvironment('RECOGNIZER_URL');
  const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  final appServices = await _createAppServices(
    recognizerUrl: recognizerUrl,
    supabaseUrl: supabaseUrl,
    supabaseAnonKey: supabaseAnonKey,
  );

  runApp(
    RacersVaultApp(
      repository: appServices.repository,
      authService: appServices.authService,
      carRecognitionService: appServices.carRecognitionService,
    ),
  );
}

Future<_AppServices> _createAppServices({
  required String recognizerUrl,
  required String supabaseUrl,
  required String supabaseAnonKey,
}) async {
  if (supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty) {
    final client = SupabaseClient(
      supabaseUrl,
      supabaseAnonKey,
      authOptions: const AuthClientOptions(authFlowType: AuthFlowType.implicit),
    );
    return _AppServices(
      repository: SupabaseVaultRepository(client: client),
      authService: SupabaseVaultAuthService(client),
      carRecognitionService: recognizerUrl.isEmpty
          ? const MockCarRecognitionService()
          : HttpCarRecognitionService(
              Uri.parse(recognizerUrl),
              accessTokenProvider: () =>
                  client.auth.currentSession?.accessToken,
            ),
    );
  }

  await Firebase.initializeApp();
  return _AppServices(
    repository: FirebaseVaultRepository(),
    authService: const AnonymousVaultAuthService(),
    carRecognitionService: recognizerUrl.isEmpty
        ? const MockCarRecognitionService()
        : HttpCarRecognitionService(Uri.parse(recognizerUrl)),
  );
}

class _AppServices {
  const _AppServices({
    required this.repository,
    required this.authService,
    required this.carRecognitionService,
  });

  final VaultRepository repository;
  final VaultAuthService authService;
  final CarRecognitionService carRecognitionService;
}
