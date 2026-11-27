import 'package:flutter_test/flutter_test.dart';
import 'package:uri_move_app/services/place_search.dart';

void main() {
  test('atalho do câmpus aparece ao digitar "uri santo" sem acento', () {
    final matches = PlaceSearch.matchCampuses('uri santo angelo');
    expect(matches.single.label, startsWith('URI Santo Ângelo'));
    expect(PlaceSearch.matchCampuses('campus'), hasLength(6));
    expect(PlaceSearch.matchCampuses('rua tiradentes'), isEmpty);
  });

  test('Photon: monta rótulo legível e descarta fora do Brasil', () {
    final places = PlaceSearch.parsePhoton({
      'features': [
        {
          'geometry': {'coordinates': [-54.26187, -28.31264]},
          'properties': {
            'countrycode': 'BR',
            'name': 'Rua Antunes Ribas',
            'street': 'Rua Antunes Ribas',
            'housenumber': '1200',
            'district': 'Centro',
            'city': 'Santo Ângelo',
          },
        },
        {
          'geometry': {'coordinates': [-57.5, -25.3]},
          'properties': {'countrycode': 'PY', 'name': 'Asunción'},
        },
      ],
    });

    expect(places.single.label, 'Rua Antunes Ribas, 1200 - Centro - Santo Ângelo');
    expect(places.single.latitude, -28.31264);
  });

  test('Nominatim (reserva): rótulo curto com nome, rua e cidade', () {
    final places = PlaceSearch.parseNominatim([
      {
        'lat': '-28.27718',
        'lon': '-54.27096',
        'name': 'URI',
        'display_name': 'URI, Rua Universidade das Missões, Santo Ângelo, RS, Brasil',
        'address': {
          'road': 'Rua Universidade das Missões',
          'city': 'Santo Ângelo',
        },
      },
    ]);

    expect(places.single.label, 'URI - Rua Universidade das Missões - Santo Ângelo');
    expect(places.single.longitude, -54.27096);
  });
}
