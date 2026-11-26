class Campus {
  Campus({
    required this.id,
    required this.name,
    this.city,
    this.uf,
    this.address,
  });

  final int id;
  final String name;
  final String? city;
  final String? uf;
  final String? address;

  factory Campus.fromJson(Map<String, dynamic> json) => Campus(
    id: json['id'] as int,
    name: json['name'] as String? ?? '',
    city: json['city'] as String?,
    uf: json['uf'] as String?,
    address: json['address'] as String?,
  );

  @override
  String toString() => name;
}

class Course {
  Course({
    required this.id,
    required this.campusId,
    required this.name,
    this.shift,
  });

  final int id;
  final int campusId;
  final String name;
  final String? shift;

  factory Course.fromJson(Map<String, dynamic> json) => Course(
    id: json['id'] as int,
    campusId: json['campus_id'] as int? ?? 0,
    name: json['name'] as String? ?? '',
    shift: json['shift'] as String?,
  );

  @override
  String toString() => name;
}

class User {
  User({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    this.gender,
    this.ra,
    this.role,
    this.photoUrl,
    this.isVerified = false,
    this.ratingAvg,
    this.ratingCount = 0,
    this.rideCount = 0,
    this.course,
    this.campus,
    this.pixKey,
    this.createdAt,
  });

  final int id;
  final String name;
  final String email;
  final String? phone;
  final String? gender;
  final String? ra;
  final String? role;
  final String? photoUrl;
  final bool isVerified;
  final double? ratingAvg;
  final int ratingCount;
  final int rideCount;
  final Course? course;
  final Campus? campus;

  /// Chave Pix (visível apenas para o próprio usuário).
  final String? pixKey;

  /// Data de cadastro (ISO 8601).
  final String? createdAt;

  bool get isDriver => role == 'driver';
  bool get isAdmin => role == 'admin';
  bool get isWoman => gender == 'woman';

  factory User.fromJson(Map<String, dynamic> json) => User(
    id: json['id'] as int,
    name: json['name'] as String? ?? '',
    email: json['email'] as String? ?? '',
    phone: json['phone'] as String?,
    gender: json['gender'] as String?,
    ra: json['ra'] as String?,
    role: json['role'] as String?,
    photoUrl: json['photo_url'] as String?,
    isVerified: json['is_verified'] as bool? ?? false,
    ratingAvg: (json['rating_avg'] as num?)?.toDouble(),
    ratingCount: json['rating_count'] as int? ?? 0,
    rideCount: json['ride_count'] as int? ?? 0,
    course: json['course'] is Map
        ? Course.fromJson(Map<String, dynamic>.from(json['course'] as Map))
        : null,
    campus: json['campus'] is Map
        ? Campus.fromJson(Map<String, dynamic>.from(json['campus'] as Map))
        : null,
    pixKey: json['pix_key'] as String?,
    createdAt: json['created_at'] as String?,
  );
}

class Vehicle {
  Vehicle({
    required this.id,
    required this.brand,
    required this.model,
    this.color,
    this.plate,
    this.year,
    this.seats = 4,
    this.isActive = true,
    this.fuelConsumption,
  });

  final int id;
  final String brand;
  final String model;
  final String? color;
  final String? plate;
  final int? year;
  final int seats;
  final bool isActive;

  /// Consumo médio (km/L) usado no rateio de custos.
  final double? fuelConsumption;

  String get label => '$brand $model${color != null ? ' ($color)' : ''}';

  factory Vehicle.fromJson(Map<String, dynamic> json) => Vehicle(
    id: json['id'] as int,
    brand: json['brand'] as String? ?? '',
    model: json['model'] as String? ?? '',
    color: json['color'] as String?,
    plate: json['plate'] as String?,
    year: json['year'] as int?,
    seats: json['seats'] as int? ?? 4,
    isActive: json['is_active'] as bool? ?? true,
    fuelConsumption: (json['fuel_consumption'] as num?)?.toDouble(),
  );
}

class Ride {
  Ride({
    required this.id,
    required this.driver,
    this.vehicle,
    required this.origin,
    required this.destination,
    this.departureDate,
    this.departureTime,
    this.departureAt,
    this.totalSeats = 4,
    this.availableSeats = 0,
    this.occupiedSeats = 0,
    this.price,
    this.status,
    this.notes,
    this.isRecurring = false,
    this.myRequestStatus,
    this.myRequestId,
    this.pendingRequestsCount = 0,
    this.canChat = false,
    this.seriesId,
    this.womenOnly = false,
    this.driverPixKey,
    this.originLat,
    this.originLng,
    this.destinationLat,
    this.destinationLng,
    this.costSharing = false,
    this.routeKm,
    this.myPrice,
  });

  final int id;
  final User driver;
  final Vehicle? vehicle;
  final String origin;
  final String destination;
  final String? departureDate;
  final String? departureTime;
  final String? departureAt;
  final int totalSeats;
  final int availableSeats;
  final int occupiedSeats;
  final double? price;
  final String? status;
  final String? notes;
  final bool isRecurring;
  final String? myRequestStatus;
  final int? myRequestId;
  final int pendingRequestsCount;
  final bool canChat;

  /// Identificador compartilhado pelas caronas de uma mesma série recorrente.
  final String? seriesId;
  final bool womenOnly;

  /// Chave Pix do motorista (enviada só ao motorista e a passageiros aceitos).
  final String? driverPixKey;

  /// Coordenadas da origem, quando escolhida pelo autocompletar de endereço.
  final double? originLat;
  final double? originLng;
  final double? destinationLat;
  final double? destinationLng;

  /// Rateio de custos: [price] é a parte fixa ("a partir de"); cada passageiro
  /// paga também o desvio até o seu ponto de embarque.
  final bool costSharing;
  final double? routeKm;

  /// Valor do usuário atual: combinado no aceite ou sugerido no pedido.
  final double? myPrice;

  bool get isActive => status == 'active';
  bool get isCompleted => status == 'completed';
  bool get isCancelled => status == 'cancelled';
  bool get hasSeats => availableSeats > 0;

  factory Ride.fromJson(Map<String, dynamic> json) => Ride(
    id: json['id'] as int,
    driver: json['driver'] is Map
        ? User.fromJson(Map<String, dynamic>.from(json['driver'] as Map))
        : User(id: 0, name: 'Desconhecido', email: ''),
    vehicle: json['vehicle'] is Map
        ? Vehicle.fromJson(Map<String, dynamic>.from(json['vehicle'] as Map))
        : null,
    origin: json['origin'] as String? ?? '',
    destination: json['destination'] as String? ?? '',
    departureDate: json['departure_date'] as String?,
    departureTime: json['departure_time'] as String?,
    departureAt: json['departure_at'] as String?,
    totalSeats: json['total_seats'] as int? ?? 4,
    availableSeats: json['available_seats'] as int? ?? 0,
    occupiedSeats: json['occupied_seats'] as int? ?? 0,
    price: (json['price'] as num?)?.toDouble(),
    status: json['status'] as String?,
    notes: json['notes'] as String?,
    isRecurring: json['is_recurring'] as bool? ?? false,
    myRequestStatus: json['my_request_status'] as String?,
    myRequestId: json['my_request_id'] as int?,
    pendingRequestsCount: json['pending_requests_count'] as int? ?? 0,
    canChat: json['can_chat'] as bool? ?? false,
    seriesId: json['series_id'] as String?,
    womenOnly: json['women_only'] as bool? ?? false,
    driverPixKey: json['driver_pix_key'] as String?,
    originLat: (json['origin_lat'] as num?)?.toDouble(),
    originLng: (json['origin_lng'] as num?)?.toDouble(),
    destinationLat: (json['destination_lat'] as num?)?.toDouble(),
    destinationLng: (json['destination_lng'] as num?)?.toDouble(),
    costSharing: json['cost_sharing'] as bool? ?? false,
    routeKm: (json['route_km'] as num?)?.toDouble(),
    myPrice: (json['my_price'] as num?)?.toDouble(),
  );
}

class RideRequest {
  RideRequest({
    required this.id,
    required this.rideId,
    this.ride,
    this.passenger,
    required this.status,
    this.seatsRequested = 1,
    this.message,
    this.respondedAt,
    this.createdAt,
    this.pickupLat,
    this.pickupLng,
    this.pickupLabel,
    this.detourKm,
    this.detourMinutes,
    this.suggestedPrice,
    this.agreedPrice,
  });

  final int id;
  final int rideId;
  final Ride? ride;
  final User? passenger;
  final String status;
  final int seatsRequested;
  final String? message;
  final String? respondedAt;
  final String? createdAt;

  /// Ponto de encontro escolhido pelo passageiro (opcional).
  final double? pickupLat;
  final double? pickupLng;
  final String? pickupLabel;

  final double? detourKm;
  final int? detourMinutes;
  final double? suggestedPrice;
  final double? agreedPrice;

  bool get hasPickup => pickupLat != null && pickupLng != null;

  bool get isPending => status == 'pending';

  factory RideRequest.fromJson(Map<String, dynamic> json) => RideRequest(
    id: json['id'] as int,
    rideId: json['ride_id'] as int? ?? 0,
    ride: json['ride'] is Map
        ? Ride.fromJson(Map<String, dynamic>.from(json['ride'] as Map))
        : null,
    passenger: json['passenger'] is Map
        ? User.fromJson(Map<String, dynamic>.from(json['passenger'] as Map))
        : null,
    status: json['status'] as String? ?? 'pending',
    seatsRequested: json['seats_requested'] as int? ?? 1,
    message: json['message'] as String?,
    respondedAt: json['responded_at'] as String?,
    createdAt: json['created_at'] as String?,
    pickupLat: (json['pickup_lat'] as num?)?.toDouble(),
    pickupLng: (json['pickup_lng'] as num?)?.toDouble(),
    pickupLabel: json['pickup_label'] as String?,
    detourKm: (json['detour_km'] as num?)?.toDouble(),
    detourMinutes: json['detour_minutes'] as int?,
    suggestedPrice: (json['suggested_price'] as num?)?.toDouble(),
    agreedPrice: (json['agreed_price'] as num?)?.toDouble(),
  );
}

class NotificationItem {
  NotificationItem({
    required this.id,
    this.type,
    required this.title,
    required this.body,
    this.payload,
    this.isRead = false,
    this.createdAt,
  });

  final int id;
  final String? type;
  final String title;
  final String body;
  final Map<String, dynamic>? payload;
  final bool isRead;
  final String? createdAt;

  factory NotificationItem.fromJson(Map<String, dynamic> json) =>
      NotificationItem(
        id: json['id'] as int,
        type: json['type'] as String?,
        title: json['title'] as String? ?? '',
        body: json['body'] as String? ?? '',
        payload: json['payload'] is Map
            ? Map<String, dynamic>.from(json['payload'] as Map)
            : null,
        isRead: json['is_read'] as bool? ?? false,
        createdAt: json['created_at'] as String?,
      );
}

/// Participante de uma carona listado para avaliação.
class RideParticipant {
  RideParticipant({
    required this.user,
    required this.role,
    required this.alreadyRated,
  });

  final User user;
  final String role;
  final bool alreadyRated;

  bool get isDriver => role == 'driver';

  factory RideParticipant.fromJson(Map<String, dynamic> json) =>
      RideParticipant(
        user: User.fromJson(Map<String, dynamic>.from(json['user'] as Map)),
        role: json['role'] as String? ?? 'passenger',
        alreadyRated: json['already_rated'] as bool? ?? false,
      );
}

/// Resumo de mensagens não lidas: chat em grupo por carona e privado por remetente.
class ChatUnread {
  const ChatUnread({
    this.total = 0,
    this.rides = const {},
    this.private = const {},
  });

  final int total;

  /// Não lidas do chat em grupo, por `rideId`.
  final Map<int, int> rides;

  /// Não lidas de conversas privadas, por chave [privateKey].
  final Map<String, int> private;

  static String privateKey(int rideId, int userId) => '$rideId:$userId';

  int forRide(int rideId) => rides[rideId] ?? 0;

  int forPrivate(int rideId, int userId) =>
      private[privateKey(rideId, userId)] ?? 0;

  factory ChatUnread.fromJson(Map<String, dynamic> json) {
    final rides = <int, int>{};
    for (final item in (json['rides'] as List? ?? const [])) {
      final map = Map<String, dynamic>.from(item as Map);
      rides[map['ride_id'] as int] = map['count'] as int;
    }
    final private = <String, int>{};
    for (final item in (json['private'] as List? ?? const [])) {
      final map = Map<String, dynamic>.from(item as Map);
      private[privateKey(map['ride_id'] as int, map['user_id'] as int)] =
          map['count'] as int;
    }
    return ChatUnread(
      total: json['total'] as int? ?? 0,
      rides: rides,
      private: private,
    );
  }
}

/// Denúncia vista pelo painel de administração.
class AdminReport {
  AdminReport({
    required this.id,
    required this.reason,
    required this.status,
    this.reported,
    this.reporter,
    this.rideId,
    this.details,
    this.reportedReportsCount = 1,
    this.createdAt,
  });

  final int id;
  final String reason;
  final String status;
  final User? reported;
  final User? reporter;
  final int? rideId;
  final String? details;

  /// Total de denúncias recebidas pelo mesmo usuário (indica reincidência).
  final int reportedReportsCount;
  final String? createdAt;

  AdminReport copyWith({String? status}) => AdminReport(
    id: id,
    reason: reason,
    status: status ?? this.status,
    reported: reported,
    reporter: reporter,
    rideId: rideId,
    details: details,
    reportedReportsCount: reportedReportsCount,
    createdAt: createdAt,
  );

  factory AdminReport.fromJson(Map<String, dynamic> json) {
    User? user(Object? value) => value is Map
        ? User.fromJson(Map<String, dynamic>.from(value))
        : null;
    return AdminReport(
      id: json['id'] as int,
      reason: json['reason'] as String? ?? 'other',
      status: json['status'] as String? ?? 'open',
      reported: user(json['reported']),
      reporter: user(json['reporter']),
      rideId: json['ride_id'] as int?,
      details: json['details'] as String?,
      reportedReportsCount: json['reported_reports_count'] as int? ?? 1,
      createdAt: json['created_at'] as String?,
    );
  }
}

/// Orçamento do rateio para um ponto de embarque (GET /rides/{id}/quote).
class PriceQuote {
  const PriceQuote({
    required this.baseShare,
    required this.detourKm,
    required this.detourMinutes,
    required this.detourCost,
    required this.suggestedPrice,
    this.estimated = false,
  });

  final double baseShare;
  final double detourKm;
  final int detourMinutes;
  final double detourCost;
  final double suggestedPrice;

  /// Rota calculada por estimativa (serviço de rotas indisponível).
  final bool estimated;

  factory PriceQuote.fromJson(Map<String, dynamic> json) => PriceQuote(
    baseShare: (json['base_share'] as num).toDouble(),
    detourKm: (json['detour_km'] as num).toDouble(),
    detourMinutes: (json['detour_minutes'] as num).toInt(),
    detourCost: (json['detour_cost'] as num).toDouble(),
    suggestedPrice: (json['suggested_price'] as num).toDouble(),
    estimated: json['estimated'] as bool? ?? false,
  );
}
