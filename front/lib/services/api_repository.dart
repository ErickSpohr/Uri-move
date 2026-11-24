import '../core/api.dart';
import '../core/profile_photo_picker.dart';
import '../models/models.dart';

/// Camada de acesso à API do URI Move.
class ApiRepository {
  ApiRepository(this.client);

  final ApiClient client;

  // ------------------------------------------------------------- Autenticação
  Future<Map<String, dynamic>> login(String email, String password) async {
    final json = await client.post(
      '/auth/login',
      body: {'email': email, 'password': password},
    );
    return dataMap(json);
  }

  Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String password,
    String? ra,
    String? phone,
    String? gender,
    int? courseId,
    int? campusId,
  }) async {
    final json = await client.post(
      '/auth/register',
      body: {
        'name': name,
        'email': email,
        'password': password,
        'password_confirmation': password,
        'ra': ra,
        'phone': phone,
        'gender': gender,
        'course_id': courseId,
        'campus_id': campusId,
      },
    );
    return dataMap(json);
  }

  Future<Map<String, dynamic>> verifyEmail(String email, String code) async {
    final json = await client.post(
      '/auth/verify-email',
      body: {'email': email, 'code': code},
    );
    return dataMap(json);
  }

  Future<void> resendCode(String email) async {
    await client.post('/auth/resend-code', body: {'email': email});
  }

  Future<void> forgotPassword(String email) async {
    await client.post('/auth/forgot-password', body: {'email': email});
  }

  Future<void> resetPassword(
    String email,
    String token,
    String password,
    String confirmation,
  ) async {
    await client.post(
      '/auth/reset-password',
      body: {
        'email': email,
        'token': token,
        'password': password,
        'password_confirmation': confirmation,
      },
    );
  }

  Future<Map<String, dynamic>> me() async {
    final json = await client.get('/me');
    return dataMap(json);
  }

  Future<Map<String, dynamic>> updateProfile({
    required String name,
    PickedProfilePhoto? photo,
  }) async {
    final json = photo == null
        ? await client.put('/me', body: {'name': name})
        : await client.uploadPhoto(
            '/me',
            name: name,
            bytes: photo.bytes,
            filename: photo.filename,
          );
    return Map<String, dynamic>.from((json as Map)['user'] as Map);
  }

  Future<void> logout() async {
    await client.post('/auth/logout');
  }

  // ------------------------------------------------------------- Dados básicos
  Future<List<Campus>> campuses() async {
    final json = await client.get('/campuses');
    return dataList(json)
        .map((e) => Campus.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<List<Course>> courses() async {
    final json = await client.get('/courses');
    return dataList(json)
        .map((e) => Course.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  // ------------------------------------------------------------- Caronas
  Future<List<Ride>> rides({
    String? origin,
    String? destination,
    String? date,
  }) async {
    final query = <String, String>{
      if (origin != null && origin.isNotEmpty) 'origin': origin,
      if (destination != null && destination.isNotEmpty)
        'destination': destination,
      if (date != null && date.isNotEmpty) 'date': date,
    };
    final json = await client.get('/rides', query: query);
    return dataList(json)
        .map((e) => Ride.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<Ride> ride(int id) async {
    final json = await client.get('/rides/$id');
    return Ride.fromJson(dataMap(json));
  }

  Future<Map<String, dynamic>> rideLocation(int rideId) async {
    final json = await client.get('/rides/$rideId/location');
    return dataMap(json);
  }

  Future<void> updateRideLocation(
    int rideId,
    double latitude,
    double longitude,
    int accuracyMeters,
  ) async {
    await client.put(
      '/rides/$rideId/location',
      body: {
        'latitude': latitude,
        'longitude': longitude,
        'accuracy_meters': accuracyMeters,
      },
    );
  }

  Future<void> stopRideLocation(int rideId) async {
    await client.delete('/rides/$rideId/location');
  }

  Future<Ride> createRide({
    String? vehicleId,
    required String origin,
    double? originLat,
    double? originLng,
    required String destination,
    double? destinationLat,
    double? destinationLng,
    required String departureDate,
    required String departureTime,
    required int totalSeats,
    double? price,
    String? notes,
  }) async {
    final body = <String, dynamic>{
      if (vehicleId != null) 'vehicle_id': int.tryParse(vehicleId),
      'origin': origin,
      'destination': destination,
      'departure_date': departureDate,
      'departure_time': departureTime,
      'total_seats': totalSeats,
      'price': price,
      'notes': notes,
    };
    if (originLat != null) {
      body['origin_lat'] = originLat;
    }
    if (originLng != null) {
      body['origin_lng'] = originLng;
    }
    if (destinationLat != null) {
      body['destination_lat'] = destinationLat;
    }
    if (destinationLng != null) {
      body['destination_lng'] = destinationLng;
    }
    final json = await client.post('/rides', body: body);
    return Ride.fromJson(dataMap(json)['ride'] as Map<String, dynamic>);
  }

  Future<Ride> startRide(int id) async {
    final json = await client.post('/rides/$id/start');
    return Ride.fromJson(dataMap(json)['ride'] as Map<String, dynamic>);
  }

  Future<Ride> completeRide(int id) async {
    final json = await client.post('/rides/$id/complete');
    return Ride.fromJson(dataMap(json)['ride'] as Map<String, dynamic>);
  }

  Future<Ride> cancelRide(int id) async {
    final json = await client.post('/rides/$id/cancel');
    return Ride.fromJson(dataMap(json)['ride'] as Map<String, dynamic>);
  }

  // ------------------------------------------------------------- Solicitações
  Future<RideRequest> requestRide(
    int rideId, {
    int seats = 1,
    String? message,
  }) async {
    final json = await client.post(
      '/rides/$rideId/requests',
      body: {
        'seats_requested': seats,
        if (message != null && message.isNotEmpty) 'message': message,
      },
    );
    return RideRequest.fromJson(
      dataMap(json)['request'] as Map<String, dynamic>,
    );
  }

  Future<List<RideRequest>> rideRequests(int rideId) async {
    final json = await client.get('/rides/$rideId/requests');
    return dataList(json)
        .map((e) => RideRequest.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<void> respondRequest(int rideId, int requestId, String action) async {
    await client.patch(
      '/rides/$rideId/requests/$requestId',
      body: {'action': action},
    );
  }

  // ------------------------------------------------------------- Veículos
  Future<List<Vehicle>> vehicles() async {
    final json = await client.get('/vehicles');
    return dataList(json)
        .map((e) => Vehicle.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<Vehicle> createVehicle({
    required String brand,
    required String model,
    String? color,
    required String plate,
    String? year,
    int seats = 4,
  }) async {
    final json = await client.post(
      '/vehicles',
      body: {
        'brand': brand,
        'model': model,
        'color': color,
        'plate': plate,
        if (year != null && year.isNotEmpty) 'year': int.tryParse(year),
        'seats': seats,
      },
    );
    return Vehicle.fromJson(dataMap(json)['vehicle'] as Map<String, dynamic>);
  }

  Future<Vehicle> updateVehicle({
    required int id,
    required String brand,
    required String model,
    String? color,
    required String plate,
    int? year,
    int seats = 4,
  }) async {
    final json = await client.put(
      '/vehicles/$id',
      body: {
        'brand': brand,
        'model': model,
        'color': color,
        'plate': plate,
        'year': year,
        'seats': seats,
      },
    );
    return Vehicle.fromJson(dataMap(json)['vehicle'] as Map<String, dynamic>);
  }

  // ------------------------------------------------------------- Perfil
  Future<List<Ride>> myRides() async {
    final json = await client.get('/me/rides');
    return dataList(json)
        .map((e) => Ride.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<List<Ride>> myJoinedRides() async {
    final json = await client.get('/me/rides/joined');
    return dataList(json)
        .map((e) => Ride.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<List<RideRequest>> myRequests() async {
    final json = await client.get('/me/requests');
    return dataList(json)
        .map((e) => RideRequest.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  // ------------------------------------------------------------- Notificações
  Future<List<NotificationItem>> notifications() async {
    final json = await client.get('/notifications');
    return dataList(json)
        .map(
          (e) => NotificationItem.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList();
  }

  Future<void> markAllNotificationsRead() async {
    await client.patch('/notifications/read-all');
  }

  // ------------------------------------------------------------- Denúncias
  Future<void> createReport({
    required int reportedId,
    int? rideId,
    required String reason,
    String? details,
  }) async {
    await client.post(
      '/reports',
      body: {
        'reported_id': reportedId,
        'ride_id': ?rideId,
        'reason': reason,
        if (details != null && details.isNotEmpty) 'details': details,
      },
    );
  }
}
