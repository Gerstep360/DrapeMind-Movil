import 'dart:ui';

/// Normalized, screen-oriented anchors. No centimetres are inferred from pixels.
class BodyAnchors {
  final Offset leftShoulder, rightShoulder, leftHip, rightHip;
  const BodyAnchors(
    this.leftShoulder,
    this.rightShoulder,
    this.leftHip,
    this.rightHip,
  );

  bool get usable {
    final points = [leftShoulder, rightShoulder, leftHip, rightHip];
    if (points.any(
      (p) =>
          !p.dx.isFinite ||
          !p.dy.isFinite ||
          p.dx < 0 ||
          p.dx > 1 ||
          p.dy < 0 ||
          p.dy > 1,
    )) {
      return false;
    }
    final shoulders = rightShoulder - leftShoulder;
    final torso = (leftHip + rightHip - leftShoulder - rightShoulder) / 2;
    return shoulders.distance > .10 &&
        torso.distance > .15 &&
        torso.dy > .1 &&
        shoulders.dx.abs() > shoulders.distance * .65;
  }

  BodyAnchors blend(BodyAnchors next, double weight) => BodyAnchors(
    Offset.lerp(leftShoulder, next.leftShoulder, weight)!,
    Offset.lerp(rightShoulder, next.rightShoulder, weight)!,
    Offset.lerp(leftHip, next.leftHip, weight)!,
    Offset.lerp(rightHip, next.rightHip, weight)!,
  );

  /// Bilinear cloth coordinates: shoulders at y=0, hips at y=1.
  Offset clothPoint(double x, double y, Size size) {
    final left = leftShoulder + (leftHip - leftShoulder) * y;
    final right = rightShoulder + (rightHip - rightShoulder) * y;
    final point = left + (right - left) * x;
    return Offset(point.dx * size.width, point.dy * size.height);
  }
}

/// Require consecutive detections; do not attach clothing to a stale/fixed pose.
class BodyScan {
  int frames = 0;
  BodyAnchors? anchors;
  bool get ready => frames >= 4;
  void reset() {
    frames = 0;
    anchors = null;
  }

  void update(BodyAnchors? value) {
    if (value == null || !value.usable) {
      reset();
      return;
    }
    anchors = anchors?.blend(value, .55) ?? value;
    frames++;
  }
}
