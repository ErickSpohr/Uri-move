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

  /// [pixKey] vazio remove a chave cadastrada.
  Future<Map<String, dynamic>> updateProfile({
    required String name,
    PickedProfilePhoto? photo,
    String? pixKey,
  }) async {
    final json = photo == null
        ? await client.put(
            '/me',
            body: {'name': name, if (pixKey != null) 'pix_key': pixKey},
          )
        : await client.uploadPhoto(
            '/me',
            name: name,
            bytes: photo.bytes,
            filename: photo.filename,
            fields: {if (pixKey != null) 'pix_key': pixKey},
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
    String? fromTime,
    String? toTime,
    double? priceMax,
    bool womenOnly = false,
  }) async {
    final query = <String, String>{
      if (origin != null && origin.isNotEmpty) 'origin': origin,
      if (destination != null && destination.isNotEmpty)
        'destination': destination,
      if (date != null && date.isNotEmpty) 'date': date,
      if (fromTime != null) 'from_time': fromTime,
      if (toTime != null) 'to_time': toTime,
      if (priceMax != null) 'price_max': priceMax.toStringAsFixed(2),
      if (womenOnly) 'women_only': '1',
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

  /// Publica a carona; com [repeatDays] (1 = segunda … 7 = domingo) e
  /// [repeatUntil] cria uma série semanal. Retorna a primeira carona e o total criado.
  Future<({Ride ride, int created})> createRide({
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
    bool womenOnly = false,
    List<int> repeatDays = const [],
    String? repeatUntil,
  }) async {
    final body = <String, dynamic>{
      'women_only': womenOnly,
      if (repeatDays.isNotEmpty) 'repeat_days': repeatDays,
      if (repeatDays.isNotEmpty) 'repeat_until': repeatUntil,
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
    final data = dataMap(await client.post('/rides', body: body));
    return (
      ride: Ride.fromJson(data['ride'] as Map<String, dynamic>),
      created: data['rides_created'] as int? ?? 1,
    );
  }

  Future<Ride> startRide(int id) async {
    final json = await client.post('/rides/$id/start');
    return Ride.fromJson(dataMap(json)['ride'] as Map<String, dynamic>);
  }

  Future<Ride> completeRide(int id) async {
    final json = await client.post('/rides/$id/complete');
    return Ride.fromJson(dataMap(json)['ride'] as Map<String, dynamic>);
  }

  /// Com [wholeSeries], cancela também as próximas caronas da mesma série.
  Future<({Ride ride, int cancelled})> cancelRide(
    int id, {
    bool wholeSeries = false,
  }) async {
    final data = dataMap(
      await client.post(
        '/rides/$id/cancel',
        body: wholeSeries ? {'scope': 'series'} : null,
      ),
    );
    return (
      ride: Ride.fromJson(data['ride'] as Map<String, dynamic>),
      cancelled: data['cancelled_count'] as int? ?? 1,
    );
  }

  // ------------------------------------------------------------- Web Push
  Future<String> pushPublicKey() async {
    final json = await client.get('/push/public-key');
    return (json as Map)['public_key'] as String;
  }

  Future<void> savePushSubscription(Map<String, dynamic> subscription) async {
    await client.post('/push/subscriptions', body: subscription);
  }

  Future<void> deletePushSubscription(String endpoint) async {
    await client.delete('/push/subscriptions', query: {'endpoint': endpoint});
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

  /// Passageiro cancela a própria solicitação (pendente, ou aceita antes da partida).
  Future<void> cancelRequest(int rideId, int requestId) async {
    await client.delete('/rides/$rideId/requests/$requestId');
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

  // ------------------------------------------------------------- Administração
  /// Denúncias (somente administradores). [status] nulo lista todas.
  Future<({List<AdminReport> reports, bool hasMore})> adminReports({
    String? status,
    int page = 1,
  }) async {
    final json = await client.get(
      '/admin/reports',
      query: {'page': '$page', 'status': ?status},
    );
    final map = Map<String, dynamic>.from(json as Map);
    final meta = map['meta'] is Map
        ? Map<String, dynamic>.from(map['meta'] as Map)
        : const <String, dynamic>{};
    final currentPage = meta['current_page'] as int? ?? page;
    final lastPage = meta['last_page'] as int? ?? page;
    return (
      reports: dataList(map)
          .map((e) => AdminReport.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      hasMore: currentPage < lastPage,
    );
  }

  Future<AdminReport> updateReportStatus(int reportId, String status) async {
    final json = await client.patch(
      '/admin/reports/$reportId/status',
      body: {'status': status},
    );
    return AdminReport.fromJson(
      Map<String, dynamic>.from(dataMap(json)['report'] as Map),
    );
  }

  // ------------------------------------------------------------- Avaliações
  Future<({bool canRate, List<RideParticipant> participants})> rideParticipants(
    int rideId,
  ) async {
    final json = await client.get('/rides/$rideId/participants');
    final map = Map<String, dynamic>.from(json as Map);
    return (
      canRate: map['can_rate'] as bool? ?? false,
      participants: dataList(map)
          .map(
            (e) =>
                RideParticipant.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .toList(),
    );
  }

  Future<void> rateUser({
    required int rideId,
    required int ratedId,
    required int score,
    String? comment,
  }) async {
    await client.post(
      '/ratings',
      body: {
        'ride_id': rideId,
        'rated_id': ratedId,
        'score': score,
        if (comment != null && comment.isNotEmpty) 'comment': comment,
      },
    );
  }

  // ------------------------------------------------------------- Bloqueios
  Future<List<User>> blockedUsers() async {
    final json = await client.get('/blocks');
    return dataList(json)
        .map((e) => User.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<void> blockUser(int userId) async {
    await client.post('/blocks', body: {'blocked_id': userId});
  }

  Future<void> unblockUser(int userId) async {
    await client.delete('/blocks', query: {'user_id': '$userId'});
  }

  // ------------------------------------------------------------- Mensagens não lidas
  Future<ChatUnread> chatUnread() async {
    final json = await client.get('/chats/unread');
    return ChatUnread.fromJson(Map<String, dynamic>.from(json as Map));
  }
}
