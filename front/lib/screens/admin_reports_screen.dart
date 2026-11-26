import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api.dart';
import '../core/formats.dart';
import '../models/models.dart';
import '../state/auth_controller.dart';
import '../widgets/common.dart';
import '../widgets/user_safety.dart';

/// Rótulos dos estados de denúncia (`Report::STATUS_*`).
const Map<String, String> reportStatusLabels = {
  'open': 'Aberta',
  'reviewing': 'Em análise',
  'resolved': 'Resolvida',
  'dismissed': 'Descartada',
};

/// Painel de denúncias para administradores: filtra por estado e altera o estado.
class AdminReportsScreen extends StatefulWidget {
  const AdminReportsScreen({super.key});

  @override
  State<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends State<AdminReportsScreen> {
  /// `null` = todas.
  String? _status = 'open';
  final List<AdminReport> _reports = [];
  int _page = 1;
  bool _hasMore = false;
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  final Set<int> _updating = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _page = 1;
    });
    try {
      final result = await context.read<AuthController>().api.adminReports(
        status: _status,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _reports
          ..clear()
          ..addAll(result.reports);
        _hasMore = result.hasMore;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _loading = false;
        });
      }
    }
  }

  Future<void> _loadMore() async {
    setState(() => _loadingMore = true);
    try {
      final result = await context.read<AuthController>().api.adminReports(
        status: _status,
        page: _page + 1,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _page++;
        _reports.addAll(result.reports);
        _hasMore = result.hasMore;
      });
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loadingMore = false);
      }
    }
  }

  Future<void> _setStatus(AdminReport report, String status) async {
    setState(() => _updating.add(report.id));
    final messenger = ScaffoldMessenger.of(context);
    try {
      final updated = await context
          .read<AuthController>()
          .api
          .updateReportStatus(report.id, status);
      if (!mounted) {
        return;
      }
      setState(() {
        final index = _reports.indexWhere((r) => r.id == report.id);
        if (index == -1) {
          return;
        }
        // Sai da lista se não pertence mais ao filtro atual.
        if (_status != null && updated.status != _status) {
          _reports.removeAt(index);
        } else {
          _reports[index] = _reports[index].copyWith(status: updated.status);
        }
      });
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Denúncia marcada como ${reportStatusLabels[status]?.toLowerCase()}.',
          ),
        ),
      );
    } on ApiException catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: Colors.red.shade700),
      );
    } finally {
      if (mounted) {
        setState(() => _updating.remove(report.id));
      }
    }
  }

  void _selectStatus(String? status) {
    if (status == _status) {
      return;
    }
    setState(() => _status = status);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Denúncias')),
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: Row(
              children: [
                for (final entry in <String?, String>{
                  ...reportStatusLabels,
                  null: 'Todas',
                }.entries)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ChoiceChip(
                      label: Text(entry.value),
                      selected: _status == entry.key,
                      onSelected: (_) => _selectStatus(entry.key),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!),
            TextButton(
              onPressed: _load,
              child: const Text('Tentar novamente'),
            ),
          ],
        ),
      );
    }
    if (_reports.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 80),
            EmptyState(
              icon: Icons.verified_user_outlined,
              message: 'Nenhuma denúncia neste filtro.',
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _reports.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _reports.length) {
            return Center(
              child: _loadingMore
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(),
                    )
                  : TextButton(
                      onPressed: _loadMore,
                      child: const Text('Carregar mais'),
                    ),
            );
          }
          final report = _reports[index];
          return _ReportCard(
            report: report,
            updating: _updating.contains(report.id),
            onStatus: (status) => _setStatus(report, status),
          );
        },
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({
    required this.report,
    required this.updating,
    required this.onStatus,
  });

  final AdminReport report;
  final bool updating;
  final ValueChanged<String> onStatus;

  Color _statusColor(ColorScheme colors) => switch (report.status) {
    'open' => Colors.orange.shade700,
    'reviewing' => colors.primary,
    'resolved' => Colors.green.shade700,
    _ => colors.onSurfaceVariant,
  };

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final muted = TextStyle(fontSize: 13, color: colors.onSurfaceVariant);
    final reported = report.reported;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    reportReasons[report.reason] ?? report.reason,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _statusColor(colors).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    reportStatusLabels[report.status] ?? report.status,
                    style: TextStyle(
                      color: _statusColor(colors),
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (reported != null)
              Row(
                children: [
                  InitialsAvatar(
                    name: reported.name,
                    photoUrl: reported.photoUrl,
                    radius: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Denunciado: ${reported.name}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        if (reported.email.isNotEmpty)
                          Text(reported.email, style: muted),
                      ],
                    ),
                  ),
                  if (report.reportedReportsCount > 1)
                    Tooltip(
                      message: 'Total de denúncias contra este usuário',
                      child: Chip(
                        avatar: Icon(
                          Icons.warning_amber,
                          size: 16,
                          color: Colors.orange.shade800,
                        ),
                        label: Text('${report.reportedReportsCount}'),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                ],
              ),
            if (report.details != null && report.details!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(report.details!),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              [
                if (report.reporter != null) 'Por ${report.reporter!.name}',
                if (report.createdAt != null) formatDate(report.createdAt),
                if (report.rideId != null) 'Carona #${report.rideId}',
              ].join(' · '),
              style: muted,
            ),
            const SizedBox(height: 10),
            if (updating)
              const Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 4,
                alignment: WrapAlignment.end,
                children: [
                  if (report.status == 'open')
                    OutlinedButton(
                      onPressed: () => onStatus('reviewing'),
                      child: const Text('Analisar'),
                    ),
                  if (report.status == 'open' || report.status == 'reviewing') ...[
                    TextButton(
                      onPressed: () => onStatus('dismissed'),
                      child: const Text('Descartar'),
                    ),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                      ),
                      onPressed: () => onStatus('resolved'),
                      child: const Text('Resolver'),
                    ),
                  ] else
                    TextButton(
                      onPressed: () => onStatus('open'),
                      child: const Text('Reabrir'),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
