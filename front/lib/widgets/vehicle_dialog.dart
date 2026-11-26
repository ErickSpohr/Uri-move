import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api.dart';
import '../models/models.dart';
import '../state/auth_controller.dart';

class VehicleDialog extends StatefulWidget {
  const VehicleDialog({super.key, this.vehicle});

  final Vehicle? vehicle;

  @override
  State<VehicleDialog> createState() => VehicleDialogState();
}

class VehicleDialogState extends State<VehicleDialog> {
  final _brandController = TextEditingController();
  final _modelController = TextEditingController();
  final _colorController = TextEditingController();
  final _plateController = TextEditingController();
  final _consumptionController = TextEditingController();
  int _seats = 4;
  bool _saving = false;

  bool get _isEditing => widget.vehicle != null;

  @override
  void initState() {
    super.initState();
    final vehicle = widget.vehicle;
    if (vehicle == null) {
      return;
    }
    _brandController.text = vehicle.brand;
    _modelController.text = vehicle.model;
    _colorController.text = vehicle.color ?? '';
    _plateController.text = vehicle.plate ?? '';
    _seats = vehicle.seats;
    _consumptionController.text =
        vehicle.fuelConsumption?.toStringAsFixed(1).replaceAll('.', ',') ?? '';
  }

  @override
  void dispose() {
    _brandController.dispose();
    _modelController.dispose();
    _colorController.dispose();
    _plateController.dispose();
    _consumptionController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_brandController.text.trim().isEmpty ||
        _modelController.text.trim().isEmpty ||
        _plateController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preencha marca, modelo e placa.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final api = context.read<AuthController>().api;
      final brand = _brandController.text.trim();
      final model = _modelController.text.trim();
      final color = _colorController.text.trim().isEmpty
          ? null
          : _colorController.text.trim();
      final plate = _plateController.text.trim().toUpperCase();
      final consumption = double.tryParse(
        _consumptionController.text.trim().replaceAll(',', '.'),
      );
      final vehicle = _isEditing
          ? await api.updateVehicle(
              id: widget.vehicle!.id,
              brand: brand,
              model: model,
              color: color,
              plate: plate,
              year: widget.vehicle!.year,
              seats: _seats,
              fuelConsumption: consumption,
            )
          : await api.createVehicle(
              brand: brand,
              model: model,
              color: color,
              plate: plate,
              seats: _seats,
              fuelConsumption: consumption,
            );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(vehicle);
    } on ApiException catch (e) {
      if (!mounted) {
        return;
      }
      setState(() => _saving = false);
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
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Falha de conexão com o servidor.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEditing ? 'Editar veículo' : 'Cadastrar veículo'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _brandController,
              decoration: const InputDecoration(labelText: 'Marca (ex.: Fiat)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _modelController,
              decoration: const InputDecoration(
                labelText: 'Modelo (ex.: Argo)',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _colorController,
              decoration: const InputDecoration(labelText: 'Cor (opcional)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _plateController,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Placa (ex.: ABC1D23)',
                hintText: 'ABC1D23',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _consumptionController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Consumo médio (km/L)',
                hintText: 'Ex.: 12',
                helperText: 'Usado para calcular o rateio. Em branco: 10 km/L.',
                helperMaxLines: 2,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton.outlined(
                  tooltip: 'Diminuir lugares',
                  onPressed: _seats > 1 ? () => setState(() => _seats--) : null,
                  icon: const Icon(Icons.remove),
                ),
                Text(
                  '$_seats lugares',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                IconButton.outlined(
                  tooltip: 'Aumentar lugares',
                  onPressed: _seats < 12
                      ? () => setState(() => _seats++)
                      : null,
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Salvar'),
        ),
      ],
    );
  }
}
