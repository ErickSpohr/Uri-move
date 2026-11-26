import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:uri_move_app/core/api.dart';
import 'package:uri_move_app/services/api_repository.dart';

void main() {
  test('adminReports filtra por estado e indica se há mais páginas', () async {
    late Uri requested;
    final client = MockClient((request) async {
      requested = request.url;
      return http.Response(
        jsonEncode({
          'data': [
            {
              'id': 3,
              'reason': 'harassment',
              'status': 'open',
              'details': 'Mensagens ofensivas.',
              'ride_id': 9,
              'reported_reports_count': 2,
              'reported': {'id': 5, 'name': 'Bruno', 'email': 'b@uri.edu.br'},
              'reporter': {'id': 6, 'name': 'Carla'},
            },
          ],
          'meta': {'current_page': 1, 'last_page': 2},
        }),
        200,
      );
    });
    final repository = ApiRepository(
      ApiClient(baseUrl: 'https://api.test/api/v1', client: client),
    );

    final result = await repository.adminReports(status: 'open');

    expect(requested.path, '/api/v1/admin/reports');
    expect(requested.queryParameters, {'page': '1', 'status': 'open'});
    expect(result.hasMore, isTrue);
    final report = result.reports.single;
    expect(report.reported?.name, 'Bruno');
    expect(report.reporter?.name, 'Carla');
    expect(report.reportedReportsCount, 2);
    expect(report.copyWith(status: 'resolved').status, 'resolved');
  });

  test('updateReportStatus envia PATCH com o novo estado', () async {
    late http.Request sent;
    final client = MockClient((request) async {
      sent = request;
      return http.Response(
        jsonEncode({
          'message': 'ok',
          'report': {'id': 3, 'reason': 'fraud', 'status': 'resolved'},
        }),
        200,
      );
    });
    final repository = ApiRepository(
      ApiClient(baseUrl: 'https://api.test/api/v1', client: client),
    );

    final updated = await repository.updateReportStatus(3, 'resolved');

    expect(sent.method, 'PATCH');
    expect(sent.url.path, '/api/v1/admin/reports/3/status');
    expect(jsonDecode(sent.body), {'status': 'resolved'});
    expect(updated.status, 'resolved');
  });
}
