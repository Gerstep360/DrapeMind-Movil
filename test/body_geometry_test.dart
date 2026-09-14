import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:drapemind_mobile/paquetes/realidad_aumentada/utilizar_vestidor_virtual/dominio/body_geometry.dart';

void main() {
  const body = BodyAnchors(
    Offset(.3, .2),
    Offset(.7, .2),
    Offset(.35, .7),
    Offset(.65, .7),
  );
  test(
    'garment anchors follow the detected torso, not fixed image coordinates',
    () {
      expect(body.clothPoint(0, 0, const Size(100, 200)), const Offset(30, 40));
      expect(
        body.clothPoint(1, 1, const Size(100, 200)),
        const Offset(65, 140),
      );
    },
  );
  test(
    'scan needs four detections and hides immediately when tracking is lost',
    () {
      final scan = BodyScan();
      for (var i = 0; i < 3; i++) {
        scan.update(body);
        expect(scan.ready, false);
      }
      scan.update(body);
      expect(scan.ready, true);
      scan.update(null);
      expect(scan.ready, false);
      expect(scan.anchors, null);
    },
  );
  test('rejects collapsed and off-screen bodies', () {
    expect(
      const BodyAnchors(
        Offset.zero,
        Offset.zero,
        Offset.zero,
        Offset.zero,
      ).usable,
      false,
    );
    expect(
      const BodyAnchors(
        Offset(-.1, .2),
        Offset(.7, .2),
        Offset(.3, .7),
        Offset(.6, .7),
      ).usable,
      false,
    );
  });
  test('smoothing follows a new pose without changing scan geometry', () {
    final moved = BodyAnchors(
      body.leftShoulder + const Offset(.1, 0),
      body.rightShoulder + const Offset(.1, 0),
      body.leftHip + const Offset(.1, 0),
      body.rightHip + const Offset(.1, 0),
    );
    expect(body.blend(moved, .5).leftShoulder.dx, closeTo(.35, .0001));
  });
}
