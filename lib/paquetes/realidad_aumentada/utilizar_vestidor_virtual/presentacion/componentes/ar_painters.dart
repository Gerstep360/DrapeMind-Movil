import 'package:flutter/material.dart';

import 'package:drapemind_mobile/core/theme/app_colors.dart';
import 'package:drapemind_mobile/paquetes/realidad_aumentada/utilizar_vestidor_virtual/dominio/body_geometry.dart';

class MannequinPainter extends CustomPainter {
  final double userHeight;
  final double userChest;
  final double userWaist;
  final bool isCameraMode;

  MannequinPainter({
    required this.userHeight,
    required this.userChest,
    required this.userWaist,
    required this.isCameraMode,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final outlinePaint = Paint()
      ..color = isCameraMode
          ? Colors.white.withAlpha(60)
          : const Color(0xFFD6CEBE)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;
    final fillPaint = Paint()
      ..color = isCameraMode
          ? Colors.black.withAlpha(40)
          : const Color(0xFFEFECE4).withAlpha(180)
      ..style = PaintingStyle.fill;
    final cx = size.width / 2;
    final cy = size.height / 2;
    final path = Path()
      ..addOval(
        Rect.fromCenter(center: Offset(cx, cy - 130), width: 34, height: 46),
      )
      ..moveTo(cx - 10, cy - 107)
      ..lineTo(cx - 10, cy - 90)
      ..lineTo(cx + 10, cy - 90)
      ..lineTo(cx + 10, cy - 107);

    final shoulderWidth = 48.0 * (userChest / 96.0);
    final waistWidth = 36.0 * (userWaist / 82.0);
    path
      ..moveTo(cx - shoulderWidth, cy - 75)
      ..quadraticBezierTo(cx, cy - 85, cx + shoulderWidth, cy - 75)
      ..lineTo(cx + shoulderWidth + 6, cy - 20)
      ..quadraticBezierTo(
        cx + waistWidth,
        cy + 40,
        cx + waistWidth + 4,
        cy + 90,
      )
      ..lineTo(cx - waistWidth - 4, cy + 90)
      ..quadraticBezierTo(
        cx - waistWidth,
        cy + 40,
        cx - shoulderWidth - 6,
        cy - 20,
      )
      ..close();
    canvas
      ..drawPath(path, fillPaint)
      ..drawPath(path, outlinePaint);

    final guidePaint = Paint()
      ..color = isCameraMode
          ? AppColors.lime.withAlpha(80)
          : AppColors.ink.withAlpha(40)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas
      ..drawLine(
        Offset(cx - shoulderWidth - 10, cy - 25),
        Offset(cx + shoulderWidth + 10, cy - 25),
        guidePaint,
      )
      ..drawLine(
        Offset(cx - waistWidth - 8, cy + 45),
        Offset(cx + waistWidth + 8, cy + 45),
        guidePaint,
      );
  }

  @override
  bool shouldRepaint(covariant MannequinPainter oldDelegate) =>
      oldDelegate.userHeight != userHeight ||
      oldDelegate.userChest != userChest ||
      oldDelegate.userWaist != userWaist ||
      oldDelegate.isCameraMode != isCameraMode;
}

class GarmentTensionPainter extends CustomPainter {
  final double ease;
  final Color color;

  GarmentTensionPainter({required this.ease, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final tensionPaint = Paint()
      ..color = color.withAlpha(70)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(8)),
      tensionPaint,
    );
  }

  @override
  bool shouldRepaint(covariant GarmentTensionPainter oldDelegate) =>
      oldDelegate.ease != ease || oldDelegate.color != color;
}

class DemoGarmentPainter extends CustomPainter {
  final BodyAnchors? body;

  DemoGarmentPainter(this.body);

  @override
  void paint(Canvas canvas, Size size) {
    final anchors = body;
    if (anchors == null) return;
    Offset point(double x, double y) => anchors.clothPoint(x, y, size);
    final points = [
      point(.30, -.08),
      point(-.08, -.04),
      point(-.38, .26),
      point(-.14, .39),
      point(-.04, .22),
      point(-.08, 1.03),
      point(1.08, 1.03),
      point(1.04, .22),
      point(1.14, .39),
      point(1.38, .26),
      point(1.08, -.04),
      point(.70, -.08),
    ];
    final outline = Path()
      ..addPolygon(points, false)
      ..quadraticBezierTo(
        point(.5, .18).dx,
        point(.5, .18).dy,
        points.first.dx,
        points.first.dy,
      )
      ..close();
    canvas
      ..drawShadow(outline, Colors.black38, 3, false)
      ..drawPath(outline, Paint()..color = AppColors.paper)
      ..save()
      ..clipPath(outline);
    final stripe = Path()
      ..addPolygon([
        point(-.4, .38),
        point(1.4, .12),
        point(1.4, .34),
        point(-.4, .60),
      ], true);
    canvas
      ..drawPath(stripe, Paint()..color = AppColors.lime)
      ..restore()
      ..drawPath(
        outline,
        Paint()
          ..color = AppColors.ink.withValues(alpha: .7)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    final seam = Path()
      ..moveTo(point(.03, .92).dx, point(.03, .92).dy)
      ..lineTo(point(.97, .92).dx, point(.97, .92).dy);
    canvas.drawPath(
      seam,
      Paint()
        ..color = AppColors.ink.withValues(alpha: .2)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(covariant DemoGarmentPainter oldDelegate) =>
      oldDelegate.body != body;
}
