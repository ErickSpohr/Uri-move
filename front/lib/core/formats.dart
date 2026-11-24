/// Utilitários de formatação usados nas telas.
library;

/// Converte "2026-09-20" ou datetime ISO em "20/09/2026".
String formatDate(String? value) {
  final raw = value?.split('T').first ?? '';
  final parts = raw.split('-');
  if (parts.length != 3) {
    return value ?? '';
  }
  return '${parts[2]}/${parts[1]}/${parts[0]}';
}

/// Converte "18:00:00" ou "18:00" em "18:00".
String formatTime(String? value) {
  if (value == null) {
    return '';
  }
  final parts = value.split(':');
  if (parts.length >= 2) {
    return '${parts[0]}:${parts[1]}';
  }
  return value;
}

/// "15.00" => "R$ 15,00"
String formatPrice(num? value) {
  if (value == null) {
    return 'Grátis';
  }
  final formatted = value.toStringAsFixed(2).replaceAll('.', ',');
  return 'R\$ $formatted';
}

/// Traduz o status da carona para exibição.
String rideStatusLabel(String? status) {
  switch (status) {
    case 'scheduled':
      return 'Agendada';
    case 'active':
      return 'Em andamento';
    case 'completed':
      return 'Concluída';
    case 'cancelled':
      return 'Cancelada';
    default:
      return status ?? '';
  }
}

/// Rótulo amigável para o tipo de notificação.
String notificationTypeLabel(String? type) {
  switch (type) {
    case 'ride_request_received':
      return 'Nova solicitação';
    case 'ride_request_accepted':
      return 'Solicitação aceita';
    case 'ride_request_rejected':
      return 'Solicitação recusada';
    case 'ride_request_cancelled':
      return 'Solicitação cancelada';
    case 'rating_received':
      return 'Nova avaliação';
    case 'report_update':
      return 'Atualização de denúncia';
    default:
      return 'Notificação';
  }
}