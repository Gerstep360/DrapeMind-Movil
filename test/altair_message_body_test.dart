import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drapemind_mobile/compartido/componentes/altair/altair_message_body.dart';

void main() {
  testWidgets('ASCII retains spaces and tables fit a narrow conversation', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 280,
            child: AltairMessageBody(
              text:
                  '**Tu selección**\n```text\nCamisa\n  |\n  +-- Pantalón\n```\n| Prenda | Precio |\n| --- | --- |\n| Camisa | 120 |',
              style: TextStyle(fontSize: 14),
            ),
          ),
        ),
      ),
    );
    expect(find.text('Camisa\n  |\n  +-- Pantalón'), findsOneWidget);
    expect(find.text('Prenda'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
