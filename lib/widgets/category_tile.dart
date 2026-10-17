import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../api/models.dart';
import '../theme/tokens.dart';

/// Gekleurde onderwerptegel met een eigen geometrisch motief (bogen), stabiele kleur per categorie.
class CategoryTile extends StatelessWidget {
  const CategoryTile({super.key, required this.category, required this.onTap});

  final Category category;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = HrpColors.forKey(category.slug);
    return Semantics(
      button: true,
      label: '${category.name}, ${category.articleTotal} artikelen',
      excludeSemantics: true,
      child: Material(
        color: color,
        borderRadius: BorderRadius.circular(Radii.m),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Stack(children: [
            Positioned.fill(child: CustomPaint(painter: _ArchesPainter(seed: category.slug.hashCode))),
            Padding(
              padding: const EdgeInsets.all(Space.m),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  category.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700, height: 1.15),
                ),
                const SizedBox(height: 2),
                Text(
                  category.articleTotal == 1 ? '1 artikel' : '${category.articleTotal} artikelen',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

class _ArchesPainter extends CustomPainter {
  _ArchesPainter({required this.seed});
  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    final rnd = math.Random(seed);
    final count = 2 + rnd.nextInt(3);
    final w = size.width / (count + 0.5);
    final base = size.height;
    for (var i = 0; i < count; i++) {
      final h = size.height * (0.35 + rnd.nextDouble() * 0.25);
      final left = size.width - (i + 1) * w * 0.95;
      final paint = Paint()..color = Colors.black.withValues(alpha: 0.10 + i * 0.05);
      final top = base - h;
      final path = Path()
        ..moveTo(left, base)
        ..lineTo(left, top + w / 2)
        ..arcToPoint(Offset(left + w * 0.8, top + w / 2), radius: Radius.circular(w * 0.4))
        ..lineTo(left + w * 0.8, base)
        ..close();
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ArchesPainter old) => old.seed != seed;
}
