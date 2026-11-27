import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api.dart';
import '../core/formats.dart';
import '../models/models.dart';
import '../state/auth_controller.dart';
import '../widgets/common.dart';
import '../widgets/address_autocomplete_field.dart';
import '../widgets/vehicle_dialog.dart';

class CreateRideScreen extends StatefulWidget {
  const CreateRideScreen({super.key, this.onCreated});

  final VoidCallback? onCreated;

  @override
  State<CreateRideScreen> createState() => _CreateRideScreenState();
}

class _CreateRideScreenState extends State<CreateRideScreen> {
  final _originController = TextEditingController();
  final _destinationController = TextEditingController();
  double? _originLat;
  double? _originLng;
  double? _destinationLat;
  double? _destinationLng;
  final _notesController = TextEditingController();

  List<Vehicle> _vehicles = [];
  DateTime _date = DateTime.now();
  TimeOfDay _time = const TimeOfDay(hour: 18, minute: 0);
  int _seats = 4;
  Vehicle? _vehicle;
  bool _womenOnly = false;

  /// true: rateio calculado pelo app; false: carona gratuita.
  bool _costSharing = true;

  // Repetição semanal: dias ISO (1 = segunda … 7 = domingo) até [_repeatUntil].
  bool _repeat = false;
  final Set<int> _repeatDays = {};
  DateTime? _repeatUntil;

  static const _weekdayLabels = ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'];
  static const _weekdayNames = [
    'segunda',
    'terça',
    'quarta',
    'quinta',
    'sexta',
    'sábado',
    'domingo',
  ];

  bool _loading = true;
  bool _submitting = false;

  late final AuthController _auth;

  @override
  void initState() {
    super.initState();
    _auth = context.read<AuthController>();
    // Veículos cadastrados no Perfil aparecem aqui sem reabrir o app.
    _auth.dataVersion.addListener(_loadVehicles);
    _loadVehicles();
  }

  @override
  void dispose() {
    _auth.dataVersion.removeListener(_loadVehicles);
    _originController.dispose();
    _destinationController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadVehicles() async {
    try {
      final api = context.read<AuthController>().api;
      final vehicles = await api.vehicles();
      if (!mounted) {
        return;
      }
      setState(() {
        _vehicles = vehicles.where((v) => v.isActive).toList();
        // Mantém a escolha atual (por id: a lista traz instâncias novas).
        final selectedId = _vehicle?.id;
        _vehicle = _vehicles.isEmpty
            ? null
            : _vehicles.firstWhere(
                (v) => v.id == selectedId,
                orElse: () => _vehicles.first,
              );
        if (_vehicle != null && _seats > _vehicle!.seats) {
          _seats = _vehicle!.seats;
        }
        _loading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _loading = false);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 120)),
      helpText: 'Data de partida',
    );
    if (picked != null) {
      setState(() {
        _date = picked;
        if (_repeatUntil != null && _repeatUntil!.isBefore(picked)) {
          _repeatUntil = picked;
        }
      });
    }
  }

  DateTime get _maxRepeatUntil => DateUtils.dateOnly(
    DateTime.now(),
  ).add(const Duration(days: 60));

  void _toggleRepeat(bool value) {
    setState(() {
      _repeat = value;
      if (value) {
        if (_repeatDays.isEmpty) {
          _repeatDays.add(_date.weekday);
        }
        final suggested = _date.add(const Duration(days: 28));
        _repeatUntil ??= suggested.isAfter(_maxRepeatUntil)
            ? _maxRepeatUntil
            : suggested;
      }
    });
  }

  Future<void> _pickRepeatUntil() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _repeatUntil ?? _date,
      firstDate: _date,
      lastDate: _maxRepeatUntil,
      helpText: 'Repetir até',
    );
    if (picked != null) {
      setState(() => _repeatUntil = picked);
    }
  }

  String _isoDate(DateTime value) => value.toIso8601String().split('T').first;

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time,
      helpText: 'Horário de partida',
    );
    if (picked != null) {
      setState(() => _time = picked);
    }
  }

  Future<void> _addVehicle() async {
    final created = await showDialog<Vehicle>(
      context: context,
      builder: (_) => const VehicleDialog(),
    );
    if (created != null && mounted) {
      setState(() {
        _vehicles.add(created);
        _vehicle = created;
      });
      _auth.notifyDataChanged();
    }
  }

  Future<void> _submit() async {
    if (_vehicle == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cadastre um veículo para publicar a carona.'),
        ),
      );
      return;
    }
    if (_originController.text.trim().isEmpty ||
        _destinationController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe origem e destino.')),
      );
      return;
    }
    if (_costSharing &&
        (_originLat == null || _destinationLat == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Para calcular o preço, escolha origem e destino na lista de '
            'sugestões ou use "Marcar no mapa".',
          ),
        ),
      );
      return;
    }
    if (_repeat && _repeatDays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Escolha ao menos um dia da semana.')),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final api = context.read<AuthController>().api;
      final result = await api.createRide(
        vehicleId: '${_vehicle!.id}',
        origin: _originController.text.trim(),
        originLat: _originLat,
        originLng: _originLng,
        destination: _destinationController.text.trim(),
        destinationLat: _destinationLat,
        destinationLng: _destinationLng,
        departureDate: _isoDate(_date),
        departureTime:
            '${_time.hour.toString().padLeft(2, '0')}:${_time.minute.toString().padLeft(2, '0')}',
        totalSeats: _seats,
        costSharing: _costSharing,
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        womenOnly: _womenOnly,
        repeatDays: _repeat ? (_repeatDays.toList()..sort()) : const [],
        repeatUntil: _repeat && _repeatUntil != null
            ? _isoDate(_repeatUntil!)
            : null,
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.created > 1
                ? '${result.created} caronas publicadas!'
                : 'Carona publicada com sucesso!',
          ),
        ),
      );
      widget.onCreated?.call();
    } on ApiException catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: Colors.red.shade700,
        ),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Falha de conexão com o servidor.'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Publicar carona')),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_vehicles.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .tertiaryContainer,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Você ainda não tem um veículo cadastrado.',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Colors.brown.shade800,
                              ),
                            ),
                            const SizedBox(height: 8),
                            FilledButton.icon(
                              onPressed: _addVehicle,
                              icon: const Icon(Icons.directions_car, size: 18),
                              label: const Text('Cadastrar veículo'),
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    else ...[
                      DropdownButtonFormField<Vehicle>(
                        // Recria o campo quando a lista muda (initialValue só vale na criação).
                        key: ValueKey(
                          '${_vehicles.map((v) => v.id).join(',')}:${_vehicle?.id}',
                        ),
                        initialValue: _vehicle,
                        // Ocupa a largura do campo: sem isso o texto do
                        // veículo escolhido passava da borda.
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Veículo',
                          prefixIcon: Icon(Icons.directions_car_outlined),
                        ),
                        items: [
                          for (final v in _vehicles)
                            DropdownMenuItem(
                              value: v,
                              child: Text(
                                [v.model, if (v.plate != null && v.plate!.isNotEmpty) v.plate]
                                    .join(' · '),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        onChanged: (v) => setState(() => _vehicle = v),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: _addVehicle,
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('Cadastrar outro veículo'),
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    AddressAutocompleteField(
                      controller: _originController,
                      onSelected: (latitude, longitude) {
                        _originLat = latitude;
                        _originLng = longitude;
                      },
                      label: 'Origem',
                      icon: Icons.trip_origin,
                      currentLocation: CurrentLocationMode.address,
                    ),
                    const SizedBox(height: 14),
                    AddressAutocompleteField(
                      controller: _destinationController,
                      onSelected: (latitude, longitude) {
                        _destinationLat = latitude;
                        _destinationLng = longitude;
                      },
                      label: 'Destino',
                      icon: Icons.location_on_outlined,
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _pickDate,
                            icon: const Icon(
                              Icons.calendar_today_outlined,
                              size: 18,
                            ),
                            label: Text(
                              formatDate(
                                _date.toIso8601String().split('T').first,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _pickTime,
                            icon: const Icon(Icons.schedule, size: 18),
                            label: Text(
                              '${_time.hour.toString().padLeft(2, '0')}:'
                              '${_time.minute.toString().padLeft(2, '0')}',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _buildPriceMode(context),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHigh,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Text(
                                  'Vagas: $_seats',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const Spacer(),
                                IconButton(
                                  tooltip: 'Diminuir vagas',
                                  onPressed: _seats > 1
                                      ? () => setState(() => _seats--)
                                      : null,
                                  icon: const Icon(Icons.remove_circle_outline),
                                ),
                                IconButton(
                                  tooltip: 'Aumentar vagas',
                                  onPressed: _seats < (_vehicle?.seats ?? 4)
                                      ? () => setState(() => _seats++)
                                      : null,
                                  icon: const Icon(Icons.add_circle_outline),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _buildRepeatSection(context),
                    if (context.watch<AuthController>().user?.isWoman ??
                        false)
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        secondary: const Icon(Icons.female),
                        title: const Text('Somente para mulheres'),
                        subtitle: const Text(
                          'A carona só aparece para usuárias mulheres.',
                        ),
                        value: _womenOnly,
                        onChanged: (v) => setState(() => _womenOnly = v),
                      ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _notesController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Observações (opcional)',
                        prefixIcon: Icon(Icons.notes, size: 20),
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: 22),
                    PrimaryButton(
                      label: _repeat ? 'Publicar caronas' : 'Publicar carona',
                      loading: _submitting,
                      onPressed: _submit,
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildRepeatSection(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            secondary: const Icon(Icons.repeat),
            title: const Text('Repetir toda semana'),
            subtitle: const Text('Publica de uma vez as próximas caronas.'),
            value: _repeat,
            onChanged: _toggleRepeat,
          ),
          if (_repeat) ...[
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (var day = 1; day <= 7; day++)
                  FilterChip(
                    label: Text(_weekdayLabels[day - 1]),
                    tooltip: _weekdayNames[day - 1],
                    selected: _repeatDays.contains(day),
                    onSelected: (selected) => setState(
                      () => selected
                          ? _repeatDays.add(day)
                          : _repeatDays.remove(day),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _pickRepeatUntil,
              icon: const Icon(Icons.event_repeat, size: 18),
              label: Text(
                'Até ${formatDate(_isoDate(_repeatUntil ?? _date))}',
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Máximo de 60 dias. Cada carona pode ser cancelada '
              'sozinha ou junto com as próximas.',
              style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPriceMode(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(
              value: true,
              icon: Icon(Icons.local_gas_station_outlined),
              label: Text('Dividir custos'),
            ),
            ButtonSegment(
              value: false,
              icon: Icon(Icons.volunteer_activism_outlined),
              label: Text('Gratuita'),
            ),
          ],
          selected: {_costSharing},
          onSelectionChanged: (value) =>
              setState(() => _costSharing = value.first),
        ),
        const SizedBox(height: 6),
        Text(
          _costSharing
              ? 'O preço é calculado pela distância e pelo consumo do veículo. '
                    'Cada passageiro paga a parte da viagem mais o desvio até o '
                    'ponto de embarque dele. Você pode dar desconto ao aceitar.'
              : 'Ninguém paga nada pela carona.',
          style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }
}
