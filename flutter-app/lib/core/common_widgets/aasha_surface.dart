import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Shared responsive surface; scrolling and callbacks remain owned by each screen.
class AashaSurface extends StatelessWidget {
  const AashaSurface({super.key, required this.child, this.maxWidth = 760});
  final Widget child;
  final double maxWidth;
  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Colors.white, AppTheme.backgroundColor, Color(0xFFE5F1F5)],
      ),
    ),
    child: SafeArea(
      top: false,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: child,
        ),
      ),
    ),
  );
}

class AashaBrand extends StatelessWidget {
  const AashaBrand({super.key});
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppTheme.primaryColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(
          Icons.diversity_1_outlined,
          color: Colors.white,
          size: 25,
        ),
      ),
      const SizedBox(width: 12),
      const Flexible(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Aasha',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
            ),
            Text(
              'REUNIFICATION NETWORK',
              style: TextStyle(
                fontSize: 9,
                letterSpacing: 1,
                color: AppTheme.muted,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

class AashaBenefit extends StatelessWidget {
  const AashaBenefit(this.icon, this.text, {super.key});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 9),
    child: Row(
      children: [
        CircleAvatar(
          radius: 17,
          backgroundColor: const Color(0xFFE1F2F2),
          child: Icon(icon, size: 19, color: AppTheme.secondaryColor),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(text, style: const TextStyle(height: 1.45))),
      ],
    ),
  );
}

/// Decorative map artwork, deliberately independent of live safety/location data.
class AashaMapHeader extends StatelessWidget {
  const AashaMapHeader({super.key});
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(12),
    child: SizedBox(
      height: 112,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(painter: _CoastalMapPainter()),
          Positioned(
            left: 12,
            bottom: 12,
            right: 12,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(240),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Text(
                  'A connection can bring hope.',
                  style: TextStyle(fontSize: 11, color: AppTheme.primaryColor),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _CoastalMapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFFA3C9CC),
    );
    final coast = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height * .25)
      ..cubicTo(
        size.width * .7,
        size.height * .55,
        size.width * .6,
        size.height * .3,
        size.width * .4,
        size.height * .7,
      )
      ..quadraticBezierTo(size.width * .2, size.height, 0, size.height * .8)
      ..close();
    canvas.save();
    canvas.clipPath(coast);
    canvas.drawPath(coast, Paint()..color = const Color(0xFFE4E1D4));
    final roads = Paint()
      ..color = const Color(0xFFC7C7B6)
      ..strokeWidth = .6;
    for (double x = -size.height; x < size.width; x += 21) {
      canvas.drawLine(Offset(x, 0), Offset(x + 45, size.height), roads);
    }
    for (double y = 10; y < size.height; y += 18) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y - 20), roads);
    }
    final riverPaint = Paint()
      ..color = const Color(0xFF9DBCC0)
      ..strokeWidth = 1.7
      ..style = PaintingStyle.stroke;
    for (double x = 40; x < size.width; x += 67) {
      canvas.drawPath(
        Path()
          ..moveTo(x, 0)
          ..cubicTo(x - 20, 35, x + 35, 60, x + 12, size.height),
        riverPaint,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _CoastalMapPainter oldDelegate) => false;
}
