import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../core/profile_photo_picker.dart';
import '../models/models.dart';
import '../state/auth_controller.dart';
import '../state/theme_controller.dart';
import '../widgets/common.dart';
import '../widgets/vehicle_dialog.dart';
import 'admin_reports_screen.dart';
import 'blocked_users_screen.dart';
import 'login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  List<Vehicle> _vehicles = [];
  bool _loadingVehicles = false;
  late final AuthController _auth;

  @override
  void initState() {
    super.initState();
    _auth = context.read<AuthController>();
    _auth.dataVersion.addListener(_loadVehicles);
    _loadVehicles();
  }

  @override
  void dispose() {
    _auth.dataVersion.removeListener(_loadVehicles);
    super.dispose();
  }

  Future<void> _loadVehicles() async {
    // Recarga silenciosa quando a lista já está na tela.
    setState(() => _loadingVehicles = _vehicles.isEmpty);
    try {
      final vehicles = await context.read<AuthController>().api.vehicles();
      if (!mounted) {
        return;
      }
      setState(() {
        _vehicles = vehicles;
        _loadingVehicles = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _loadingVehicles = false);
    }
  }

  Future<void> _addVehicle() async {
    final created = await showDialog<Vehicle>(
      context: context,
      builder: (_) => const VehicleDialog(),
    );
    if (created == null || !mounted) {
      return;
    }
    setState(() => _vehicles.add(created));
    context.read<AuthController>().notifyDataChanged();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Veículo cadastrado com sucesso!')),
    );
  }

  Future<void> _editVehicle(Vehicle vehicle) async {
    final updated = await showDialog<Vehicle>(
      context: context,
      builder: (_) => VehicleDialog(vehicle: vehicle),
    );
    if (updated == null || !mounted) {
      return;
    }
    context.read<AuthController>().notifyDataChanged();
    setState(() {
      final index = _vehicles.indexWhere((item) => item.id == updated.id);
      if (index != -1) {
        _vehicles[index] = updated;
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Veículo atualizado com sucesso!')),
    );
  }

  Future<void> _editProfile(User user) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _EditProfileDialog(user: user),
    );
    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Perfil atualizado com sucesso!')),
      );
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sair da conta'),
        content: const Text('Tem certeza que deseja sair?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Sair'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    await context.read<AuthController>().logout();
    if (!mounted) {
      return;
    }
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final user = auth.user;

    return Scaffold(
      appBar: AppBar(title: const Text('Perfil')),
      body: user == null
          ? const SizedBox.shrink()
          : RefreshIndicator(
              onRefresh: _loadVehicles,
              color: AppTheme.primary,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        children: [
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              InitialsAvatar(
                                name: user.name,
                                photoUrl: user.photoUrl,
                                radius: 38,
                              ),
                              Positioned(
                                right: -4,
                                bottom: -4,
                                child: Material(
                                  color: AppTheme.primary,
                                  shape: const CircleBorder(),
                                  elevation: 2,
                                  child: IconButton(
                                    tooltip: 'Editar nome e foto',
                                    icon: const Icon(Icons.edit, size: 18),
                                    color: Colors.white,
                                    constraints: const BoxConstraints(
                                      minWidth: 34,
                                      minHeight: 34,
                                    ),
                                    padding: EdgeInsets.zero,
                                    onPressed: () => _editProfile(user),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            user.name,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            user.email,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13.5,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                          ),
                          if (user.ra != null || user.course != null) ...[
                            const SizedBox(height: 6),
                            Text(
                              [
                                if (user.ra != null) 'RA ${user.ra}',
                                if (user.course != null) user.course!.name,
                                if (user.campus != null) user.campus!.name,
                              ].join(' · '),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _StatBox(
                                icon: Icons.star_rounded,
                                color: Colors.amber,
                                value:
                                    user.ratingAvg?.toStringAsFixed(1) ?? '—',
                                label: 'Avaliação',
                              ),
                              const SizedBox(width: 10),
                              _StatBox(
                                icon: Icons.directions_car_outlined,
                                color: AppTheme.primary,
                                value: '${user.rideCount}',
                                label: 'Caronas',
                              ),
                              const SizedBox(width: 10),
                              _StatBox(
                                icon: Icons.verified_outlined,
                                color: user.isVerified
                                    ? Colors.green
                                    : Colors.orange,
                                value: user.isVerified ? 'Sim' : 'Não',
                                label: 'E-mail verificado',
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Card(
                    child: SwitchListTile(
                      secondary: Icon(
                        context.watch<ThemeController>().darkMode
                            ? Icons.dark_mode
                            : Icons.light_mode_outlined,
                      ),
                      title: const Text('Modo escuro'),
                      subtitle: const Text('Usar cores escuras no aplicativo'),
                      value: context.watch<ThemeController>().darkMode,
                      onChanged: context.read<ThemeController>().setDarkMode,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (user.isAdmin) ...[
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.admin_panel_settings_outlined),
                        title: const Text('Painel de denúncias'),
                        subtitle: const Text('Administração'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const AdminReportsScreen(),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.block),
                      title: const Text('Usuários bloqueados'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const BlockedUsersScreen(),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Meus veículos',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 10),
                  FilledButton.icon(
                    onPressed: _loadingVehicles ? null : _addVehicle,
                    icon: const Icon(Icons.add),
                    label: const Text('Cadastrar veículo'),
                  ),
                  const SizedBox(height: 10),
                  if (_loadingVehicles)
                    const Padding(
                      padding: EdgeInsets.all(12),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_vehicles.isEmpty)
                    const EmptyState(
                      icon: Icons.directions_car_outlined,
                      message: 'Nenhum veículo cadastrado.',
                    )
                  else
                    for (final v in _vehicles)
                      _VehicleCard(vehicle: v, onEdit: () => _editVehicle(v)),
                  const SizedBox(height: 20),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                    ),
                    onPressed: _logout,
                    icon: const Icon(Icons.logout),
                    label: const Text('Sair da conta'),
                  ),
                ],
              ),
            ),
    );
  }
}

class _EditProfileDialog extends StatefulWidget {
  const _EditProfileDialog({required this.user});

  final User user;

  @override
  State<_EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends State<_EditProfileDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _pixController;
  PickedProfilePhoto? _photo;
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user.name);
    _pixController = TextEditingController(text: widget.user.pixKey ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _pixController.dispose();
    super.dispose();
  }

  Future<void> _choosePhoto() async {
    try {
      final photo = await pickProfilePhoto();
      if (!mounted || photo == null) {
        return;
      }
      setState(() {
        _photo = photo;
        _error = null;
      });
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is FormatException
              ? error.message
              : 'Não foi possível selecionar a foto.',
        );
      }
    }
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty || name.length > 191) {
      setState(() => _error = 'Informe um nome de até 191 caracteres.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final auth = context.read<AuthController>();
    final saved = await auth.updateProfile(
      name: name,
      photo: _photo,
      pixKey: _pixController.text.trim(),
    );
    if (!mounted) {
      return;
    }
    if (saved) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _saving = false;
        _error = auth.error ?? 'Não foi possível atualizar o perfil.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Editar perfil'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_photo != null)
              ClipOval(
                child: Image.memory(
                  _photo!.bytes,
                  width: 76,
                  height: 76,
                  fit: BoxFit.cover,
                ),
              )
            else
              InitialsAvatar(
                name: widget.user.name,
                photoUrl: widget.user.photoUrl,
                radius: 38,
              ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _saving ? null : _choosePhoto,
              icon: const Icon(Icons.add_a_photo_outlined),
              label: const Text('Escolher foto'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _nameController,
              enabled: !_saving,
              maxLength: 191,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Nome'),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _pixController,
              enabled: !_saving,
              maxLength: 140,
              decoration: const InputDecoration(
                labelText: 'Chave Pix (opcional)',
                helperText:
                    'Mostrada só aos passageiros aceitos nas suas caronas.',
                helperMaxLines: 2,
                prefixIcon: Icon(Icons.pix),
              ),
              onSubmitted: (_) => _save(),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Salvar'),
        ),
      ],
    );
  }
}

class _StatBox extends StatelessWidget {
  const _StatBox({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final Color color;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VehicleCard extends StatelessWidget {
  const _VehicleCard({required this.vehicle, required this.onEdit});

  final Vehicle vehicle;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.directions_car,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    vehicle.label,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [
                      if (vehicle.plate != null) vehicle.plate!,
                      '${vehicle.seats} lugares',
                    ].join(' · '),
                    style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (!vehicle.isActive)
              const _Badge(label: 'Inativo', color: Colors.orange),
            IconButton(
              tooltip: 'Editar veículo',
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined),
            ),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
