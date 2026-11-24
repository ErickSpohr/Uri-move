import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'profile_photo_picker.dart';

Future<PickedProfilePhoto?> pickProfilePhoto() async {
  final input = web.HTMLInputElement()
    ..type = 'file'
    ..accept = 'image/jpeg,image/png,image/webp';
  final selected = Completer<web.File?>();
  input.addEventListener(
    'change',
    ((web.Event _) => selected.complete(input.files?.item(0))).toJS,
  );
  input.addEventListener(
    'cancel',
    ((web.Event _) => selected.complete(null)).toJS,
  );
  input.click();
  final file = await selected.future;
  if (file == null) {
    return null;
  }
  if (!['image/jpeg', 'image/png', 'image/webp'].contains(file.type)) {
    throw const FormatException('Escolha uma imagem JPG, PNG ou WebP.');
  }
  if (file.size > 2 * 1024 * 1024) {
    throw const FormatException('A foto deve ter no máximo 2 MB.');
  }
  final buffer = await file.arrayBuffer().toDart;
  return PickedProfilePhoto(Uint8List.view(buffer.toDart), file.name);
}
