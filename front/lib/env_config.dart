/// Configuração de compilação do aplicativo URI Move.
///
/// Os valores são inseridos com `--dart-define` e compilados no pacote web.
/// Portanto, somente configurações públicas do cliente devem ficar aqui.
/// Segredos do servidor e tokens privilegiados devem permanecer no ambiente
/// do backend/Coolify.
abstract final class EnvConfig {
  static const String apiUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'http://127.0.0.1:8000/api/v1',
  );

  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
  );

  static const String firebaseApiKey = String.fromEnvironment(
    'FIREBASE_API_KEY',
  );
  static const String firebaseAuthDomain = String.fromEnvironment(
    'FIREBASE_AUTH_DOMAIN',
  );
  static const String firebaseProjectId = String.fromEnvironment(
    'FIREBASE_PROJECT_ID',
  );
  static const String firebaseStorageBucket = String.fromEnvironment(
    'FIREBASE_STORAGE_BUCKET',
  );
  static const String firebaseMessagingSenderId = String.fromEnvironment(
    'FIREBASE_MESSAGING_SENDER_ID',
  );
  static const String firebaseAppId = String.fromEnvironment('FIREBASE_APP_ID');
  static const String firebaseMeasurementId = String.fromEnvironment(
    'FIREBASE_MEASUREMENT_ID',
  );
  static const String firebaseDatabaseUrl = String.fromEnvironment(
    'FIREBASE_DATABASE_URL',
  );

  static String get normalizedApiUrl => _withoutTrailingSlash(apiUrl);

  static String get supabaseFunctionsUrl => _derivedSupabaseUrl('functions/v1');

  static String get supabaseStorageUrl => _derivedSupabaseUrl('storage/v1');

  /// Retorna uma URL pública do Supabase Storage com os segmentos do caminho codificados com segurança.
  static String storageAsset(String bucket, String path) {
    if (bucket.trim().isEmpty || path.trim().isEmpty) {
      throw ArgumentError('Storage bucket and asset path are required.');
    }

    final storageUri = Uri.parse('${_requireSupabaseUrl()}/storage/v1');
    return storageUri
        .replace(
          pathSegments: <String>[
            ...storageUri.pathSegments.where((segment) => segment.isNotEmpty),
            'object',
            'public',
            bucket,
            ...path.split('/').where((segment) => segment.isNotEmpty),
          ],
        )
        .toString();
  }

  /// Interrompe a inicialização se uma configuração obrigatória estiver ausente ou inválida.
  static void validate({
    bool requireSupabase = false,
    bool requireFirebase = false,
  }) {
    final missing = <String>[];

    if (!_isAbsoluteHttpUrl(apiUrl)) {
      missing.add('API_URL (absolute HTTP(S) URL)');
    }

    if (requireSupabase) {
      if (!_isAbsoluteHttpUrl(supabaseUrl)) {
        missing.add('SUPABASE_URL (absolute HTTP(S) URL)');
      }
      if (supabaseAnonKey.trim().isEmpty) {
        missing.add('SUPABASE_ANON_KEY');
      }
    }

    if (requireFirebase) {
      final firebaseValues = <String, String>{
        'FIREBASE_API_KEY': firebaseApiKey,
        'FIREBASE_AUTH_DOMAIN': firebaseAuthDomain,
        'FIREBASE_PROJECT_ID': firebaseProjectId,
        'FIREBASE_STORAGE_BUCKET': firebaseStorageBucket,
        'FIREBASE_MESSAGING_SENDER_ID': firebaseMessagingSenderId,
        'FIREBASE_APP_ID': firebaseAppId,
      };
      for (final entry in firebaseValues.entries) {
        if (entry.value.trim().isEmpty) {
          missing.add(entry.key);
        }
      }
    }

    if (missing.isNotEmpty) {
      throw StateError(
        'Missing or invalid configuration: ${missing.join(', ')}',
      );
    }
  }

  static String _derivedSupabaseUrl(String path) =>
      '${_requireSupabaseUrl()}/$path';

  static String _requireSupabaseUrl() {
    if (!_isAbsoluteHttpUrl(supabaseUrl)) {
      throw StateError('SUPABASE_URL is missing or invalid.');
    }
    return _withoutTrailingSlash(supabaseUrl);
  }

  static String _withoutTrailingSlash(String value) =>
      value.trim().replaceFirst(RegExp(r'/+$'), '');

  static bool _isAbsoluteHttpUrl(String value) {
    final uri = Uri.tryParse(value.trim());
    return uri != null &&
        uri.hasAuthority &&
        (uri.scheme == 'http' || uri.scheme == 'https');
  }
}
