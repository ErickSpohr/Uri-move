import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api.dart';
import '../core/formats.dart';
import '../models/models.dart';
import '../state/auth_controller.dart';
import '../widgets/common.dart';

/// Edição de carona publicada, permitida enquanto nenhum passageiro foi aceito.
class EditRideScreen extends StatefulWidget {
  const EditRideScreen({super.key, required this.ride});

  final Ride ride;

  @override
  State<EditRideScreen> createState() => _EditRideScreenState();
}

class _EditRideScreenState extends State<EditRideScreen> {
  late DateTime _date;
  late TimeOfDay _time;
  late int _seats;
  late final TextEditingController _notes;
  bool _saving = false;

  int get _maxSeats => widget.ride.vehicle?.seats ?? 8;

  @override
  void initState() {
    super.initState();
    final ride = widget.ride;
    _date = DateTime.tryParse(ride.departureDate ?? '') ?? DateTime.now();
    final parts = (ride.departureTime ?? '07:00').split(':');
    _time = TimeOfDay(
      hour: int.tryParse(parts[0]) ?? 7,
      minute: int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0,
    );
    _seats = ride.totalSeats;
    _notes = TextEditingController(text: ride.notes ?? '');
  }

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  String get _isoDate => _date.toIso8601String().split('T').first;

  String get _hhmm =>
      '${_time.hour.toString().padLeft(2, '0')}:${_time.minute.toString().padLeft(2, '0')}';

  Future<void> _pickDate() async {
    final today = DateUtils.dateOnly(DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: _date.isBefore(today) ? today : _date,
      firstDate: today,
      lastDate: today.add(const Duration(days: 120)),
      helpText: 'Data de partida',
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time,
      helpText: 'Horário de partida',
    );
    if (picked != null) setState(() => _time = picked);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final updated = await context.read<AuthController>().api.updateRide(
        widget.ride.id,
        departureDate: _isoDate,
        departureTime: _hhmm,
        totalSeats: _seats,
        notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      );
      if (!mounted) return;
      context.read<AuthController>().notifyDataChanged();
      messenger.showSnackBar(const SnackBar(content: Text('Carona atualizada.')));
      Navigator.of(context).pop(updated);
    } on ApiException catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: Colors.red.shade700),
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Falha de conexão com o servidor.')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Editar carona')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              '${widget.ride.origin} → ${widget.ride.destination}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              'Origem e destino não mudam: eles definem a rota e o preço. '
              'Para trocar o trajeto, cancele e publique de novo.',
              style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickDate,
                    icon: const Icon(Icons.calendar_today_outlined, size: 18),
                    label: Text(formatDate(_isoDate)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickTime,
                    icon: const Icon(Icons.schedule, size: 18),
                    label: Text(_hhmm),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Text('Vagas: $_seats', style: const TextStyle(fontWeight: FontWeight.w700)),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Diminuir vagas',
                    onPressed: _seats > 1 ? () => setState(() => _seats--) : null,
                    icon: const Icon(Icons.remove_circle_outline),
                  ),
                  IconButton(
                    tooltip: 'Aumentar vagas',
                    onPressed: _seats < _maxSeats ? () => setState(() => _seats++) : null,
                    icon: const Icon(Icons.add_circle_outline),
                  ),
                ],
              ),
            ),
            if (widget.ride.costSharing)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'Mudar as vagas recalcula o preço do rateio.',
                  style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
                ),
              ),
            const SizedBox(height: 14),
            TextField(
              controller: _notes,
              maxLines: 3,
              maxLength: 1000,
              decoration: const InputDecoration(
                labelText: 'Observações (opcional)',
                prefixIcon: Icon(Icons.notes, size: 20),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Quem já pediu vaga será avisado da alteração.',
              style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 18),
            PrimaryButton(label: 'Salvar alterações', loading: _saving, onPressed: _save),
          ],
        ),
      ),
    );
  }
}
