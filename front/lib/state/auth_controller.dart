import 'package:flutter/foundation.dart';

import '../core/token_storage.dart';
import '../core/profile_photo_picker.dart';

import '../core/api.dart';
import '../core/push_notifications.dart';
import '../models/models.dart';
import '../services/api_repository.dart';
import '../services/ride_location_sharer.dart';

/// Estado global de autenticação e dados do usuário logado.
class AuthController extends ChangeNotifier {
  AuthController({ApiClient? client})
    : _api = ApiRepository(client ?? ApiClient());

  final ApiRepository _api;

  final _tokenStorage = TokenStorage();

  /// Envio automático da posição do motorista durante caronas em andamento.
  late final RideLocationSharer locationSharer = RideLocationSharer(_api);

  /// Incrementado quando dados compartilhados entre abas mudam (veículos,
  /// caronas, solicitações) ou ao trocar de aba; as telas escutam e recarregam.
  final ValueNotifier<int> dataVersion = ValueNotifier<int>(0);

  void notifyDataChanged() => dataVersion.value++;

  bool _ready = false;
  bool _busy = false;
  String? _error;
  String? _pendingVerificationEmail;
  User? _user;

  bool get ready => _ready;
  bool get busy => _busy;
  String? get error => _error;
  String? get pendingVerificationEmail => _pendingVerificationEmail;
  User? get user => _user;
  bool get isAuthenticated => _user != null;

  void clearError() {
    _error = null;
    notifyListeners();
  }

  ApiRepository get api => _api;

  /// Restaura o token salvo e carrega o perfil (usado no splash).
  Future<void> restore() async {
    final token = await _tokenStorage.read();
    if (token == null || token.isEmpty) {
      _ready = true;
      notifyListeners();
      return;
    }

    _api.client.setToken(token);
    try {
      final user = User.fromJson(await _api.me());
      _user = user;
    } on ApiException catch (e) {
      if (e.statusCode == 401) {
        await _tokenStorage.clear();
        _api.client.setToken(null);
      }
    } catch (_) {
      // Sem rede: mantém o usuário desconhecido mas logado visualmente não.
      await _tokenStorage.clear();
      _api.client.setToken(null);
    }
    _ready = true;
    notifyListeners();
  }

  Future<bool> login(String email, String password) async {
    _pendingVerificationEmail = null;
    return _run(
      () async {
        final data = await _api.login(email, password);
        _user = User.fromJson(data['user'] as Map<String, dynamic>);
        final token = data['token'] as String;
        await _persist(token);
      },
      onApiException: (exception) {
        final data = exception.data;
        if (exception.statusCode != 403 || data is! Map) {
          return;
        }

        final user = data['user'];
        final requiresVerification =
            data['requires_email_verification'] == true || user is Map;
        if (!requiresVerification) {
          return;
        }

        final responseEmail = user is Map ? user['email'] : null;
        _pendingVerificationEmail = responseEmail is String
            ? responseEmail
            : email;
      },
    );
  }

  String? takePendingVerificationEmail() {
    final email = _pendingVerificationEmail;
    if (email != null) {
      _pendingVerificationEmail = null;
      _error = null;
      notifyListeners();
    }
    return email;
  }

  Future<bool> register({
    required String name,
    required String email,
    required String password,
    String? ra,
    String? phone,
    String? gender,
    int? courseId,
    int? campusId,
  }) async {
    return _run(() async {
      await _api.register(
        name: name,
        email: email,
        password: password,
        ra: ra,
        phone: phone,
        gender: gender,
        courseId: courseId,
        campusId: campusId,
      );
    });
  }

  /// Verifica o e-mail com o código OTP e autentica o usuário.
  Future<bool> verify(String email, String code) async {
    return _run(() async {
      final data = await _api.verifyEmail(email, code);
      _user = User.fromJson(data['user'] as Map<String, dynamic>);
      await _persist(data['token'] as String);
    });
  }

  Future<bool> resendCode(String email) async {
    return _run(() async {
      await _api.resendCode(email);
    });
  }

  Future<void> refreshUser() async {
    final user = User.fromJson(await _api.me());
    _user = user;
    notifyListeners();
  }

  Future<bool> updateProfile({
    required String name,
    PickedProfilePhoto? photo,
    String? pixKey,
  }) {
    return _run(() async {
      final data = await _api.updateProfile(
        name: name,
        photo: photo,
        pixKey: pixKey,
      );
      _user = User.fromJson(data);
    });
  }

  Future<void> logout() async {
    // Evita que o próximo usuário deste navegador receba avisos da conta anterior.
    try {
      final endpoint = await pushUnsubscribe();
      if (endpoint != null) {
        await _api.deletePushSubscription(endpoint);
      }
    } catch (_) {
      // Sem push ou falha de rede: segue com o logout.
    }
    // Antes de revogar o token, para o servidor ainda aceitar o encerramento.
    await locationSharer.stop();
    try {
      await _api.logout();
    } catch (_) {
      // Falha de rede no logout não impede a saída local.
    }

    await _tokenStorage.clear();
    _api.client.setToken(null);
    _user = null;
    notifyListeners();
  }

  Future<void> _persist(String token) async {
    await _tokenStorage.write(token);
    _api.client.setToken(token);
  }

  Future<bool> _run(
    Future<void> Function() action, {
    void Function(ApiException exception)? onApiException,
  }) async {
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      await action();
      _busy = false;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _busy = false;
      _error = e.message;
      onApiException?.call(e);
      notifyListeners();
      return false;
    } catch (_) {
      _busy = false;
      _error = 'Falha de conexão com o servidor.';
      notifyListeners();
      return false;
    }
  }
}
