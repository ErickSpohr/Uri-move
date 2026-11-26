import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/api.dart';
import '../core/formats.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../state/auth_controller.dart';
import '../widgets/common.dart';
import '../widgets/user_safety.dart';
import 'pickup_picker_screen.dart';
import 'rate_ride_screen.dart';
import 'ride_chat_screen.dart';
import 'private_ride_chat_screen.dart';
import 'ride_tracking_screen.dart';

class RideDetailScreen extends StatefulWidget {
  const RideDetailScreen({super.key, required this.rideId});

  final int rideId;

  @override
  State<RideDetailScreen> createState() => _RideDetailScreenState();
}

class _RideDetailScreenState extends State<RideDetailScreen> {
  Ride? _ride;
  List<RideRequest> _requests = [];
  bool _loading = true;
  bool _requestsLoading = false;
  String? _error;
  bool _busy = false;

  bool get _isDriver =>
      _ride?.driver.id == context.read<AuthController>().user?.id;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = context.read<AuthController>().api;
      final ride = await api.ride(widget.rideId);
      if (!mounted) {
        return;
      }
      setState(() {
        _ride = ride;
        _loading = false;
      });
      if (ride.driver.id == context.read<AuthController>().user?.id) {
        await _loadRequests();
      }
    } on ApiException catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = 'Falha de conexão com o servidor.';
        _loading = false;
      });
    }
  }

  Future<void> _loadRequests() async {
    try {
      final api = context.read<AuthController>().api;
      final requests = await api.rideRequests(widget.rideId);
      if (!mounted) {
        return;
      }
      setState(() {
        _requests = requests.where((r) => r.isPending).toList();
        _requestsLoading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _requestsLoading = false);
    }
  }

  Future<void> _run(Future<void> Function() action, {String? success}) async {
    setState(() {
      _busy = true;
    });
    try {
      await action();
      if (!mounted) {
        return;
      }
      if (success != null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(success)));
      }
      await _load();
    } on ApiException catch (e) {
      _showError(e.message);
    } catch (_) {
      _showError('Falha de conexão com o servidor.');
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  void _showError(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red.shade700),
    );
  }

  void _openRequestDialog() async {
    final ride = _ride!;
    final choice = await showDialog<_RequestChoice>(
      context: context,
      builder: (dialogContext) => _RequestDialog(ride: ride),
    );
    if (choice != null && mounted) {
      _run(() async {
        await context.read<AuthController>().api.requestRide(
          ride.id,
          seats: choice.seats,
          pickupLat: choice.pickup?.position.latitude,
          pickupLng: choice.pickup?.position.longitude,
          pickupLabel: choice.pickup?.label,
        );
      }, success: 'Solicitação enviada! Aguarde a confirmação do motorista.');
    }
  }

  void _confirmAction({
    required String title,
    required String message,
    required String confirmLabel,
    required Color color,
    required Future<void> Function() action,
    required String success,
  }) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: color),
            onPressed: () {
              Navigator.of(dialogContext).pop();
              _run(action, success: success);
            },
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
  }

  /// Carona de série: escolhe entre cancelar só esta ou esta e as próximas.
  Future<void> _confirmSeriesCancel(Ride ride) async {
    final wholeSeries = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancelar carona'),
        content: const Text(
          'Esta carona faz parte de uma série semanal. '
          'Os passageiros confirmados serão avisados.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Voltar'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Só esta'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Esta e as próximas'),
          ),
        ],
      ),
    );
    if (wholeSeries == null || !mounted) {
      return;
    }
    final api = context.read<AuthController>().api;
    int? cancelled;
    await _run(() async {
      cancelled = (await api.cancelRide(
        ride.id,
        wholeSeries: wholeSeries,
      )).cancelled;
    });
    // null: a requisição falhou e _run já exibiu o erro.
    if (mounted && cancelled != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            cancelled! > 1
                ? '$cancelled caronas canceladas.'
                : 'Carona cancelada.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Detalhes da carona')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null || _ride == null
          ? Center(child: Text(_error ?? 'Carona não encontrada.'))
          : _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    final ride = _ride!;

    return RefreshIndicator(
      onRefresh: _load,
      color: AppTheme.primary,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              ride.origin,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 2),
                              child: Icon(
                                Icons.arrow_downward,
                                color: AppTheme.primary,
                              ),
                            ),
                            Text(
                              ride.destination,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Usa a cor do tema para manter contraste no modo escuro.
                      Text(
                        formatPrice(ride.price),
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 28),
                  Wrap(
                    spacing: 20,
                    runSpacing: 8,
                    children: [
                      _DetailItem(
                        icon: Icons.calendar_today_outlined,
                        label: formatDate(ride.departureDate),
                      ),
                      _DetailItem(
                        icon: Icons.schedule,
                        label: formatTime(ride.departureTime),
                      ),
                      _DetailItem(
                        icon: Icons.event_seat_outlined,
                        label:
                            '${ride.availableSeats}/${ride.totalSeats} vagas',
                      ),
                    ],
                  ),
                  if (ride.vehicle != null) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(
                          Icons.directions_car_outlined,
                          size: 16,
                          color: Colors.grey,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '${ride.vehicle!.label} · ${ride.vehicle!.plate} · ${ride.vehicle!.seats} lugares',
                            style: TextStyle(
                              fontSize: 13.5,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (ride.notes != null && ride.notes!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      ride.notes!,
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          _DriverCard(ride: ride, showSafetyMenu: !_isDriver),
          const SizedBox(height: 14),
          if (ride.womenOnly)
            const _InfoBanner(
              icon: Icons.female,
              text: 'Carona exclusiva para mulheres',
            ),
          if (!_isDriver && ride.driverPixKey != null)
            _PixCard(pixKey: ride.driverPixKey!, price: ride.price),
          if (ride.isRecurring)
            Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.repeat,
                    size: 18,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    ride.seriesId != null
                        ? 'Faz parte de uma série semanal'
                        : 'Carona recorrente (repete semanalmente)',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          _buildActions(context, ride),
          if (ride.isCompleted &&
              (_isDriver || ride.myRequestStatus == 'accepted')) ...[
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => RateRideScreen(ride: ride),
                ),
              ),
              icon: const Icon(Icons.star_outline),
              label: Text(
                _isDriver ? 'Avaliar passageiros' : 'Avaliar participantes',
              ),
            ),
          ],
          if (ride.isActive && ride.canChat) ...[
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => RideTrackingScreen(ride: ride),
                ),
              ),
              icon: const Icon(Icons.location_on_outlined),
              label: Text(
                _isDriver ? 'Compartilhar localização' : 'Acompanhar carro',
              ),
            ),
          ],
          if (!_isDriver && ride.myRequestStatus == 'pending') ...[
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      PrivateRideChatScreen(ride: ride, otherUser: ride.driver),
                ),
              ),
              icon: const Icon(Icons.chat_bubble_outline),
              label: const Text('Conversar com o motorista'),
            ),
          ],
          if (ride.canChat) ...[
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => RideChatScreen(ride: ride)),
              ),
              icon: const Icon(Icons.forum_outlined),
              label: const Text('Chat da carona'),
            ),
          ],
          if (_isDriver && !ride.isCompleted && !ride.isCancelled) ...[
            const SizedBox(height: 18),
            Text(
              'Solicitações pendentes',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 10),
            if (_requestsLoading)
              const Padding(
                padding: EdgeInsets.all(12),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_requests.isEmpty)
              const EmptyState(
                icon: Icons.person_add_alt_outlined,
                message: 'Nenhuma solicitação pendente.',
              )
            else
              ..._requests.map(
                (r) => _RequestTile(
                  request: r,
                  onChat: r.passenger == null
                      ? null
                      : () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => PrivateRideChatScreen(
                              ride: ride,
                              otherUser: r.passenger!,
                            ),
                          ),
                        ),
                  onRespond: (action) => _run(
                    () async => context
                        .read<AuthController>()
                        .api
                        .respondRequest(ride.id, r.id, action),
                    success: action == 'accepted'
                        ? 'Solicitação aceita.'
                        : 'Solicitação recusada.',
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildActions(BuildContext context, Ride ride) {
    if (_isDriver) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (ride.status == 'scheduled') ...[
            PrimaryButton(
              label: 'Iniciar carona',
              loading: _busy,
              onPressed: () => _confirmAction(
                title: 'Iniciar carona',
                message: 'Iniciar esta carona agora?',
                confirmLabel: 'Iniciar',
                color: AppTheme.primary,
                action: () async =>
                    context.read<AuthController>().api.startRide(ride.id),
                success: 'Carona iniciada.',
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: () => _confirmAction(
                title: 'Concluir carona',
                message: 'Concluir esta carona?',
                confirmLabel: 'Concluir',
                color: Colors.green,
                action: () async =>
                    context.read<AuthController>().api.completeRide(ride.id),
                success: 'Carona concluída.',
              ),
              child: const Text('Concluir'),
            ),
          ] else if (ride.isActive)
            PrimaryButton(
              label: 'Concluir carona',
              loading: _busy,
              onPressed: () => _confirmAction(
                title: 'Concluir carona',
                message: 'Concluir esta carona agora?',
                confirmLabel: 'Concluir',
                color: Colors.green,
                action: () async =>
                    context.read<AuthController>().api.completeRide(ride.id),
                success: 'Carona concluída.',
              ),
            ),
          if (!ride.isCancelled && !ride.isCompleted) ...[
            const SizedBox(height: 10),
            TextButton.icon(
              style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
              onPressed: () => ride.seriesId != null
                  ? _confirmSeriesCancel(ride)
                  : _confirmAction(
                      title: 'Cancelar carona',
                      message: 'Tem certeza que deseja cancelar esta carona?',
                      confirmLabel: 'Cancelar carona',
                      color: Colors.redAccent,
                      action: () async => context
                          .read<AuthController>()
                          .api
                          .cancelRide(ride.id),
                      success: 'Carona cancelada.',
                    ),
              icon: const Icon(Icons.cancel_outlined),
              label: const Text('Cancelar carona'),
            ),
          ],
        ],
      );
    }

    // Passageiro.
    if (ride.myRequestStatus != null) {
      final requested =
          !ride.isCancelled &&
          (ride.myRequestStatus == 'pending' ||
              ride.myRequestStatus == 'accepted');
      final canCancel =
          ride.myRequestId != null &&
          (ride.myRequestStatus == 'pending' ||
              (ride.myRequestStatus == 'accepted' &&
                  ride.status == 'scheduled'));
      final statusBox = Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: requested
              ? Theme.of(context).colorScheme.primaryContainer
              : Theme.of(context).colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              requested ? Icons.hourglass_top : Icons.info_outline,
              color: requested
                  ? Theme.of(context).colorScheme.onPrimaryContainer
                  : Theme.of(context).colorScheme.onErrorContainer,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                ride.isCancelled
                    ? 'Esta carona foi cancelada pelo motorista.'
                    : _myRequestLabel(ride.myRequestStatus!),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      );
      if (!canCancel) {
        return statusBox;
      }
      final accepted = ride.myRequestStatus == 'accepted';
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          statusBox,
          const SizedBox(height: 8),
          TextButton.icon(
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            onPressed: _busy
                ? null
                : () => _confirmAction(
                    title: accepted ? 'Liberar minha vaga' : 'Cancelar solicitação',
                    message: accepted
                        ? 'Sua vaga será liberada para outros passageiros.'
                        : 'O motorista não verá mais sua solicitação.',
                    confirmLabel: accepted ? 'Liberar vaga' : 'Cancelar solicitação',
                    color: Colors.redAccent,
                    action: () async => context
                        .read<AuthController>()
                        .api
                        .cancelRequest(ride.id, ride.myRequestId!),
                    success: accepted ? 'Vaga liberada.' : 'Solicitação cancelada.',
                  ),
            icon: const Icon(Icons.close),
            label: Text(accepted ? 'Liberar minha vaga' : 'Cancelar solicitação'),
          ),
        ],
      );
    }

    if (!ride.hasSeats || ride.isCompleted || ride.isCancelled) {
      return EmptyState(
        icon: Icons.event_busy_outlined,
        message: ride.isCompleted
            ? 'Carona já concluída.'
            : ride.isCancelled
            ? 'Carona cancelada.'
            : 'Não há vagas disponíveis.',
      );
    }

    return PrimaryButton(
      label: 'Solicitar vaga',
      loading: _busy,
      onPressed: _openRequestDialog,
    );
  }

  String _myRequestLabel(String status) {
    switch (status) {
      case 'pending':
        return 'Sua solicitação está aguardando o motorista.';
      case 'accepted':
        return 'Você tem vaga confirmada nesta carona.';
      case 'rejected':
        return 'Sua solicitação foi recusada.';
      case 'cancelled':
        return 'Você cancelou sua solicitação.';
      default:
        return 'Status: $status';
    }
  }
}

class _DetailItem extends StatelessWidget {
  const _DetailItem({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

class _DriverCard extends StatelessWidget {
  const _DriverCard({required this.ride, this.showSafetyMenu = false});

  final Ride ride;
  final bool showSafetyMenu;

  @override
  Widget build(BuildContext context) {
    final driver = ride.driver;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            InitialsAvatar(
              name: driver.name,
              photoUrl: driver.photoUrl,
              radius: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    driver.name,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    driver.course?.name ?? 'Motorista',
                    style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (driver.ratingAvg != null)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.tertiaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.star_rounded,
                      color: Colors.amber,
                      size: 18,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      driver.ratingAvg!.toStringAsFixed(1),
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(width: 2),
                    Text(
                      '(${driver.ratingCount})',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            if (showSafetyMenu) UserSafetyMenu(user: driver, rideId: ride.id),
          ],
        ),
      ),
    );
  }
}

class _RequestTile extends StatelessWidget {
  const _RequestTile({
    required this.request,
    required this.onRespond,
    this.onChat,
  });

  final RideRequest request;
  final void Function(String action) onRespond;
  final VoidCallback? onChat;

  @override
  Widget build(BuildContext context) {
    final passenger = request.passenger;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                InitialsAvatar(
                  name: passenger?.name ?? '?',
                  photoUrl: passenger?.photoUrl,
                  radius: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        passenger?.name ?? 'Passageiro',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        '${request.seatsRequested} vaga${request.seatsRequested > 1 ? 's' : ''}',
                        style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                _RespondButton(
                  label: 'Recusar',
                  color: Colors.redAccent,
                  onTap: () => onRespond('rejected'),
                ),
                const SizedBox(width: 8),
                _RespondButton(
                  label: 'Aceitar',
                  color: Colors.green,
                  onTap: () => onRespond('accepted'),
                ),
              ],
            ),
            if (request.message != null && request.message!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                request.message!,
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
            if (request.hasPickup) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.place_outlined,
                    size: 18,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Embarque: ${request.pickupLabel ?? 'ponto marcado no mapa'}',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ],
            if (onChat != null)
              TextButton.icon(
                onPressed: onChat,
                icon: const Icon(Icons.chat_bubble_outline),
                label: const Text('Conversar antes de aceitar'),
              ),
          ],
        ),
      ),
    );
  }
}

class _RespondButton extends StatelessWidget {
  const _RespondButton({
    required this.label,
    required this.color,
    required this.onTap,
  });

  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: color,
          padding: const EdgeInsets.symmetric(horizontal: 14),
        ),
        onPressed: onTap,
        child: Text(label, style: const TextStyle(fontSize: 13)),
      ),
    );
  }
}

class _RequestDialog extends StatefulWidget {
  const _RequestDialog({required this.ride});

  final Ride ride;

  @override
  State<_RequestDialog> createState() => _RequestDialogState();
}

/// Resultado do diálogo de solicitação.
class _RequestChoice {
  const _RequestChoice(this.seats, this.pickup);

  final int seats;
  final PickupPoint? pickup;
}

class _RequestDialogState extends State<_RequestDialog> {
  int _seats = 1;
  PickupPoint? _pickup;

  Future<void> _choosePickup() async {
    final picked = await Navigator.of(context).push<PickupPoint>(
      MaterialPageRoute(
        builder: (_) => PickupPickerScreen(initial: _pickup),
      ),
    );
    if (picked != null && mounted) {
      setState(() => _pickup = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Solicitar vaga'),
      content: SingleChildScrollView(
        child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Quantas vagas você deseja na carona ${widget.ride.origin} → ${widget.ride.destination}?',
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton.outlined(
                tooltip: 'Diminuir vagas',
                onPressed: _seats > 1 ? () => setState(() => _seats--) : null,
                icon: const Icon(Icons.remove),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  '$_seats',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton.outlined(
                tooltip: 'Aumentar vagas',
                onPressed: _seats < widget.ride.availableSeats
                    ? () => setState(() => _seats++)
                    : null,
                icon: const Icon(Icons.add),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Disponível: ${widget.ride.availableSeats} vaga(s)',
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _choosePickup,
            icon: Icon(
              _pickup == null ? Icons.add_location_alt_outlined : Icons.edit_location_alt,
            ),
            label: Text(
              _pickup == null
                  ? 'Escolher ponto de encontro'
                  : (_pickup!.label ?? 'Ponto de encontro marcado'),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Opcional. O motorista vê o ponto no mapa e você é avisado '
            'quando ele estiver chegando.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
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
          onPressed: () =>
              Navigator.of(context).pop(_RequestChoice(_seats, _pickup)),
          child: const Text('Enviar solicitação'),
        ),
      ],
    );
  }
}


class _InfoBanner extends StatelessWidget {
  const _InfoBanner({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: scheme.onSecondaryContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: scheme.onSecondaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Chave Pix do motorista, exibida a passageiros aceitos.
class _PixCard extends StatelessWidget {
  const _PixCard({required this.pixKey, this.price});

  final String pixKey;
  final double? price;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Row(
          children: [
            Icon(Icons.pix, color: scheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    price != null
                        ? 'Pagamento via Pix · ${formatPrice(price)}'
                        : 'Pagamento via Pix',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  SelectableText(
                    pixKey,
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Copiar chave Pix',
              icon: const Icon(Icons.copy),
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: pixKey));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Chave Pix copiada.')),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
