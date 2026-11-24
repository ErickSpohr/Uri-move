import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:uri_move_app/core/api.dart';

void main() {
  const baseUrl = 'https://api.test/api/v1';

  test('GET repete uma vez após 503 e retorna a segunda resposta', () async {
    var calls = 0;
    final client = MockClient((request) async {
      calls++;
      return calls == 1
          ? http.Response('{"message":"indisponível"}', 503)
          : http.Response('{"data":[1]}', 200);
    });

    final api = ApiClient(baseUrl: baseUrl, client: client);
    final result = await api.get('/campuses');

    expect(calls, 2);
    expect(dataList(result), [1]);
  });

  test('POST não é repetido após 503', () async {
    var calls = 0;
    final client = MockClient((request) async {
      calls++;
      return http.Response('{"message":"indisponível"}', 503);
    });

    final api = ApiClient(baseUrl: baseUrl, client: client);

    await expectLater(
      api.post('/auth/login', body: {'email': 'a@uri.edu.br'}),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'statusCode', 503)),
    );
    expect(calls, 1);
  });

  test('falha de conexão vira ApiException sem resposta', () async {
    final client = MockClient((request) async {
      throw http.ClientException('offline', request.url);
    });

    final api = ApiClient(baseUrl: baseUrl, client: client);

    await expectLater(
      api.post('/auth/login'),
      throwsA(
        isA<ApiException>()
            .having((e) => e.isConnectionError, 'isConnectionError', true),
      ),
    );
  });
}
