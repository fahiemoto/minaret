import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/api_client.dart';
import '../api/models.dart';
import '../theme/tokens.dart';

/// Cover voor een artikel: de foto uit de API als die er is, anders een gegenereerde cover
/// (geometrisch patroon + boog in een stabiele kleur per onderwerp, met de exacte titel).
class CoverArt extends StatelessWidget {
  const CoverArt({super.key, required this.article, this.wide = false, this.radius = Radii.m, this.showTitle = true});

  final ArticleSummary article;
  final bool wide;
  final double radius;
  final bool showTitle;

  @override
  Widget build(BuildContext context) {
    final url = wide ? (article.imageWide ?? article.image) : (article.image ?? article.imageWide);
    final generated = GeneratedCover(
      seed: article.category?.slug ?? '${article.id}',
      title: showTitle ? article.title : null,
      label: article.category?.name,
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: url == null
          ? generated
          : CachedNetworkImage(
              imageUrl: Provider.of<ApiClient>(context, listen: false).resolveMediaUrl(url),
              fit: BoxFit.cover,
              fadeInDuration: const Duration(milliseconds: 200),
              placeholder: (_, __) => GeneratedCover(seed: article.category?.slug ?? '${article.id}'),
              errorWidget: (_, __, ___) => generated,
            ),
    );
  }
}

class GeneratedCover extends StatelessWidget {
  const GeneratedCover({super.key, required this.seed, this.title, this.label});

  final String seed;
  final String? title;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final color = HrpColors.forKey(seed);
    return LayoutBuilder(builder: (context, c) {
      final small = c.maxWidth < 150;
      return DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [color, Color.lerp(color, Colors.black, 0.35)!],
          ),
        ),
        child: Stack(fit: StackFit.expand, children: [
          CustomPaint(painter: _PatternPainter(seed: seed)),
          if (title != null)
            Padding(
              padding: EdgeInsets.all(small ? 10 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (label != null && !small)
                    Text(label!.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 10, letterSpacing: 1.4, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  Text(
                    title!,
                    maxLines: small ? 4 : 5,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontFamily: 'serif',
                      fontWeight: FontWeight.w700,
                      height: 1.15,
                      fontSize: small ? 13 : 20,
                      shadows: const [Shadow(blurRadius: 8, color: Colors.black26)],
                    ),
                  ),
                ],
              ),
            ),
        ]),
      );
    });
  }
}

/// Rustig achtergrondpatroon: raster van achtpuntige sterren en een boog (mihrab-vorm) onderaan.
class _PatternPainter extends CustomPainter {
  _PatternPainter({required this.seed});
  final String seed;

  @override
  void paint(Canvas canvas, Size size) {
    final rnd = math.Random(seed.hashCode);
    final line = Paint()
      ..color = Colors.white.withValues(alpha: 0.10)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final cell = math.max(28.0, size.shortestSide / 4);
    final offset = Offset(rnd.nextDouble() * cell, rnd.nextDouble() * cell);
    for (var y = -cell; y < size.height + cell; y += cell) {
      for (var x = -cell; x < size.width + cell; x += cell) {
        _star(canvas, Offset(x, y) + offset, cell * 0.32, line);
      }
    }

    final arch = Paint()..color = Colors.white.withValues(alpha: 0.12);
    final w = size.width * (0.5 + rnd.nextDouble() * 0.2);
    final left = size.width - w * 0.75;
    final top = size.height * 0.42;
    final path = Path()
      ..moveTo(left, size.height)
      ..lineTo(left, top + w / 2)
      ..quadraticBezierTo(left, top, left + w / 2, top - w * 0.18)
      ..quadraticBezierTo(left + w, top, left + w, top + w / 2)
      ..lineTo(left + w, size.height)
      ..close();
    canvas.drawPath(path, arch);
  }

  void _star(Canvas canvas, Offset c, double r, Paint p) {
    for (final angle in [0.0, math.pi / 4]) {
      final path = Path();
      for (var i = 0; i < 4; i++) {
        final a = angle + i * math.pi / 2;
        final pt = c + Offset(math.cos(a) * r, math.sin(a) * r);
        if (i == 0) {
          path.moveTo(pt.dx, pt.dy);
        } else {
          path.lineTo(pt.dx, pt.dy);
        }
      }
      path.close();
      canvas.drawPath(path, p);
    }
  }

  @override
  bool shouldRepaint(covariant _PatternPainter old) => old.seed != seed;
}
