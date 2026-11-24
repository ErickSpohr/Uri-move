import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../env_config.dart';

class ApiException implements Exception {
  ApiException(this.statusCode, this.message, [this.data]);

  final int statusCode;
  final String message;
  final dynamic data;

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
    final streamed = await _client.send(request);
    return _decode(await http.Response.fromStream(streamed));
  }

  Future<dynamic> delete(String path) {
    return _send('DELETE', path);
  }

  Future<dynamic> _send(
    String method,
    String path, {
    Object? body,
    Map<String, String>? query,
  }) async {
    final uri = Uri.parse('$baseUrl$path').replace(queryParameters: query);
    final headers = _headers(json: body != null || method == 'POST');

    http.Response response;
    switch (method) {
      case 'GET':
        response = await _client.get(uri, headers: headers);
      case 'PATCH':
        response = await _client.patch(
          uri,
          headers: headers,
          body: body == null ? null : jsonEncode(body),
        );
      case 'PUT':
        response = await _client.put(
          uri,
          headers: headers,
          body: body == null ? null : jsonEncode(body),
        );
      case 'DELETE':
        response = await _client.delete(uri, headers: headers);
      default:
        response = await _client.post(
          uri,
          headers: headers,
          body: body == null ? null : jsonEncode(body),
        );
    }

    return _decode(response);
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
