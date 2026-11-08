import 'package:flutter/services.dart';

class NativeActions {
  static const channel = MethodChannel('drapemind/documents');
  Future<String?> dictate() => channel.invokeMethod<String>('dictate');
  Future<bool> savePdf(String name, Uint8List bytes) async =>
      await channel.invokeMethod<bool>('savePdf', {
        'name': name,
        'bytes': bytes,
      }) ??
      false;
}
