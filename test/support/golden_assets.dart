import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';

/// Use the fonts distributed with this Flutter SDK, so screenshots have real glyphs.
Future<void> loadGoldenFonts() async {
  final config =
      jsonDecode(File('.dart_tool/package_config.json').readAsStringSync())
          as Map<String, dynamic>;
  final flutter = (config['packages'] as List)
      .cast<Map<String, dynamic>>()
      .firstWhere((p) => p['name'] == 'flutter');
  final root = Directory.fromUri(
    Uri.parse(flutter['rootUri'] as String),
  ).parent.parent.path;
  final fonts = '$root/bin/cache/artifacts/material_fonts';
  for (final entry in {
    'Roboto': ['roboto-regular.ttf', 'roboto-medium.ttf', 'roboto-bold.ttf'],
    'MaterialIcons': ['materialicons-regular.otf'],
  }.entries) {
    final loader = FontLoader(entry.key);
    for (final name in entry.value) {
      loader.addFont(
        Future.value(
          ByteData.sublistView(File('$fonts/$name').readAsBytesSync()),
        ),
      );
    }
    await loader.load();
  }
}
