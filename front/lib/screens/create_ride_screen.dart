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
  final _priceController = TextEditingController();
  final _notesController = TextEditingController();

  List<Vehicle> _vehicles = [];
  DateTime _date = DateTime.now();
  TimeOfDay _time = const TimeOfDay(hour: 18, minute: 0);
  int _seats = 4;
  Vehicle? _vehicle;
  bool _loading = true;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _loadVehicles();
  }

  @override
  void dispose() {
    _originController.dispose();
    _destinationController.dispose();
    _priceController.dispose();
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
        if (_vehicles.isNotEmpty) {
          _vehicle = _vehicles.first;
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
      setState(() => _date = picked);
    }
  }

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

    setState(() => _submitting = true);
    try {
      final api = context.read<AuthController>().api;
      await api.createRide(
        vehicleId: '${_vehicle!.id}',
        origin: _originController.text.trim(),
        originLat: _originLat,
        originLng: _originLng,
        destination: _destinationController.text.trim(),
        destinationLat: _destinationLat,
        destinationLng: _destinationLng,
        departureDate: _date.toIso8601String().split('T').first,
        departureTime:
            '${_time.hour.toString().padLeft(2, '0')}:${_time.minute.toString().padLeft(2, '0')}',
        totalSeats: _seats,
        price: _priceToDouble(),
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Carona publicada com sucesso!')),
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

  double? _priceToDouble() {
    final text = _priceController.text.trim().replaceAll(',', '.');
    if (text.isEmpty) {
      return null;
    }
    return double.tryParse(text);
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
                        initialValue: _vehicle,
                        decoration: const InputDecoration(
                          labelText: 'Veículo',
                          prefixIcon: Icon(Icons.directions_car_outlined),
                        ),
                        items: [
                          for (final v in _vehicles)
                            DropdownMenuItem(
                              value: v,
                              child: Text(
                                '${v.label} · ${v.plate ?? ''}',
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
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _priceController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Preço por vaga (R\$)',
                              prefixIcon: Icon(Icons.attach_money),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
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
                                  visualDensity: VisualDensity.compact,
                                  onPressed: _seats > 1
                                      ? () => setState(() => _seats--)
                                      : null,
                                  icon: const Icon(Icons.remove_circle_outline),
                                ),
                                IconButton(
                                  visualDensity: VisualDensity.compact,
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
                      label: 'Publicar carona',
                      loading: _submitting,
                      onPressed: _submit,
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
