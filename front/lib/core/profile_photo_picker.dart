import 'dart:typed_data';

import 'profile_photo_picker_stub.dart'
    if (dart.library.html) 'profile_photo_picker_web.dart'
    as platform;

class PickedProfilePhoto {
  const PickedProfilePhoto(this.bytes, this.filename);

  final Uint8List bytes;
  final String filename;
}

Future<PickedProfilePhoto?> pickProfilePhoto() => platform.pickProfilePhoto();
