import 'package:flutter_test/flutter_test.dart';
import 'package:uri_move_app/models/models.dart';

void main() {
  test('ChatUnread indexa não lidas por carona e por conversa privada', () {
    final unread = ChatUnread.fromJson({
      'total': 5,
      'rides': [
        {'ride_id': 7, 'count': 3},
      ],
      'private': [
        {'ride_id': 9, 'user_id': 4, 'count': 2},
      ],
    });

    expect(unread.total, 5);
    expect(unread.forRide(7), 3);
    expect(unread.forRide(8), 0);
    expect(unread.forPrivate(9, 4), 2);
    expect(unread.forPrivate(9, 5), 0);
  });

  test('RideParticipant lê papel e status de avaliação', () {
    final participant = RideParticipant.fromJson({
      'user': {'id': 1, 'name': 'Ana'},
      'role': 'driver',
      'already_rated': true,
    });

    expect(participant.isDriver, isTrue);
    expect(participant.alreadyRated, isTrue);
    expect(participant.user.name, 'Ana');
  });
}
