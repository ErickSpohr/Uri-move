import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../env_config.dart';

class ApiException implements Exception {
  ApiException(this.statusCode, this.message, [this.data]);

  /// `statusCode` usado para falhas sem resposta HTTP (timeout ou rede).
  static const int noResponse = 0;

  final int statusCode;
  final String message;
  final dynamic data;

  bool get isConnectionError => statusCode == noResponse;

  @override
  String toString() => message;
}

/// Client HTTP para a API do URI Move.
///
/// A URL base pode ser sobrescrita em tempo de build:
/// `flutter run --dart-define=API_URL=http://10.0.2.2:8000/api/v1`
class ApiClient {
  ApiClient({String? baseUrl, http.Client? client})
    : baseUrl = baseUrl ?? EnvConfig.normalizedApiUrl,
      _client = client ?? http.Client();

  /// Limite por requisição. Cobre a retomada do servidor no plano gratuito
  /// do Render (~1 min após inatividade).
  static const Duration requestTimeout = Duration(seconds: 75);

  /// Tempo a partir do qual a requisição é sinalizada como lenta.
  static const Duration slowThreshold = Duration(seconds: 5);

  /// Número de requisições em andamento há mais de [slowThreshold].
  static final ValueNotifier<int> slowRequests = ValueNotifier<int>(0);

  static const Set<int> _retryableStatus = {502, 503, 504};

  final String baseUrl;
  final http.Client _client;
  String? _token;

  void setToken(String? token) => _token = token;

  Map<String, String> _headers({bool json = true}) => {
    if (json) 'Content-Type': 'application/json',
    'Accept': 'application/json',
    if (_token != null) 'Authorization': 'Bearer $_token',
  };

  Future<dynamic> get(String path, {Map<String, String>? query}) {
    return _send('GET', path, query: query);
  }

  Future<dynamic> post(
    String path, {
    Object? body,
    Map<String, String>? query,
  }) {
    return _send('POST', path, body: body, query: query);
  }

  Future<dynamic> patch(String path, {Object? body}) {
    return _send('PATCH', path, body: body);
  }

  Future<dynamic> put(String path, {Object? body}) {
    return _send('PUT', path, body: body);
  }

  Future<dynamic> uploadPhoto(
    String path, {
    required String name,
    required Uint8List bytes,
    required String filename,
  }) async {
    final request = http.MultipartRequest('POST', Uri.parse('$baseUrl$path'));
    request.headers.addAll(_headers(json: false));
    request.fields.addAll({'_method': 'PUT', 'name': name});
    request.files.add(
      http.MultipartFile.fromBytes('photo', bytes, filename: filename),
    );
    final response = await _perform(() async {
      final streamed = await _client.send(request);
      return http.Response.fromStream(streamed);
    });
    return _decode(response);
  }

  Future<dynamic> delete(String path, {Map<String, String>? query}) {
    return _send('DELETE', path, query: query);
  }

  Future<dynamic> _send(
    String method,
    String path, {
    Object? body,
    Map<String, String>? query,
  }) async {
    final uri = Uri.parse('$baseUrl$path').replace(queryParameters: query);
    final headers = _headers(json: body != null || method == 'POST');

    Future<http.Response> request() {
      switch (method) {
        case 'GET':
          return _client.get(uri, headers: headers);
        case 'PATCH':
          return _client.patch(
            uri,
            headers: headers,
            body: body == null ? null : jsonEncode(body),
          );
        case 'PUT':
          return _client.put(
            uri,
            headers: headers,
            body: body == null ? null : jsonEncode(body),
          );
        case 'DELETE':
          return _client.delete(uri, headers: headers);
        default:
          return _client.post(
            uri,
            headers: headers,
            body: body == null ? null : jsonEncode(body),
          );
      }
    }

    // Somente GET é repetido: é idempotente e não duplica efeitos no servidor.
    final response = await _perform(request, retry: method == 'GET');

    return _decode(response);
  }

  /// Executa a requisição com timeout, sinalização de lentidão e conversão de
  /// falhas de rede em [ApiException]. Com [retry], repete uma vez após falha
  /// de conexão ou status 502/503/504.
  Future<http.Response> _perform(
    Future<http.Response> Function() request, {
    bool retry = false,
  }) async {
    var markedSlow = false;
    final slowTimer = Timer(slowThreshold, () {
      markedSlow = true;
      slowRequests.value++;
    });

    try {
      for (var attempt = 1; ; attempt++) {
        final canRetry = retry && attempt == 1;
        try {
          final response = await request().timeout(requestTimeout);
          if (canRetry && _retryableStatus.contains(response.statusCode)) {
            await Future<void>.delayed(const Duration(seconds: 2));
            continue;
          }
          return response;
        } on TimeoutException {
          throw ApiException(
            ApiException.noResponse,
            'O servidor demorou para responder. Verifique sua conexão e tente novamente.',
          );
        } on http.ClientException {
          if (canRetry) {
            await Future<void>.delayed(const Duration(seconds: 2));
            continue;
          }
          throw ApiException(
            ApiException.noResponse,
            'Não foi possível conectar ao servidor. Verifique sua conexão e tente novamente.',
          );
        }
      }
    } finally {
      slowTimer.cancel();
      if (markedSlow) {
        slowRequests.value--;
      }
    }
  }

  dynamic _decode(http.Response response) {
    dynamic decoded;
    try {
      decoded = jsonDecode(utf8.decode(response.bodyBytes));
    } catch (_) {
      decoded = null;
    }

    if (response.statusCode >= 400) {
      throw ApiException(
        response.statusCode,
        _extractMessage(decoded, response.statusCode),
        decoded,
      );
    }

    return decoded;
  }

  String _extractMessage(dynamic decoded, int statusCode) {
    if (decoded is Map<String, dynamic>) {
      final message = decoded['message'];
      if (message is String && message.isNotEmpty) {
        return message;
      }
      final errors = decoded['errors'];
      if (errors is Map && errors.isNotEmpty) {
        for (final value in errors.values) {
          if (value is List && value.isNotEmpty) {
            return value.first.toString();
          }
          return value.toString();
        }
      }
    }
    return 'Erro na requisição ($statusCode).';
  }
}

/// Extrai a lista de itens de uma resposta paginada ou simples.
List<dynamic> dataList(dynamic json) {
  if (json is List) {
    return json;
  }
  if (json is Map && json['data'] is List) {
    return json['data'] as List;
  }
  return const [];
}

/// Extrai um objeto/mapeamento da resposta (lida com o wrapper `data`).
Map<String, dynamic> dataMap(dynamic json) {
  if (json is Map) {
    if (json['data'] is Map) {
      return Map<String, dynamic>.from(json['data'] as Map);
    }
    return Map<String, dynamic>.from(json);
  }
  return <String, dynamic>{};
}
