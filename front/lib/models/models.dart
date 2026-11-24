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

  bool get isDriver => role == 'driver';
  bool get isAdmin => role == 'admin';

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
  });

  final int id;
  final String brand;
  final String model;
  final String? color;
  final String? plate;
  final int? year;
  final int seats;
  final bool isActive;

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
    this.pendingRequestsCount = 0,
    this.canChat = false,
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
  final int pendingRequestsCount;
  final bool canChat;

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
    pendingRequestsCount: json['pending_requests_count'] as int? ?? 0,
    canChat: json['can_chat'] as bool? ?? false,
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
