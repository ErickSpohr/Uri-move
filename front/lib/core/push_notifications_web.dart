import 'dart:js_interop';

/// Objeto `window.uriMovePush` definido em web/push_helper.js.
@JS('uriMovePush')
external _PushHelper? get _helper;

extension type _PushHelper._(JSObject _) implements JSObject {
  external bool supported();
  external String permission();
  external JSPromise<JSString?> subscribe(String publicKey);
  external JSPromise<JSString?> current();
  external JSPromise<JSString?> unsubscribe();
}

bool supported() => _helper?.supported() ?? false;

String permission() => _helper?.permission() ?? 'unsupported';

Future<String?> subscribe(String publicKey) async {
  final helper = _helper;
  if (helper == null) {
    return null;
  }
  return (await helper.subscribe(publicKey).toDart)?.toDart;
}

Future<String?> current() async {
  final helper = _helper;
  if (helper == null) {
    return null;
  }
  return (await helper.current().toDart)?.toDart;
}

Future<String?> unsubscribe() async {
  final helper = _helper;
  if (helper == null) {
    return null;
  }
  return (await helper.unsubscribe().toDart)?.toDart;
}
