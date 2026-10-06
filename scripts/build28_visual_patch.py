from pathlib import Path


def fail(message: str) -> None:
    raise SystemExit(f'Salus build 28 visual patch: {message}')


path = Path('lib/widgets/salus_widgets.dart')
if not path.exists():
    fail('lib/widgets/salus_widgets.dart missing')
text = path.read_text()

start = text.find('class _SalusLandscapePainter extends CustomPainter {')
end = text.find('class SalusWeekStrip extends StatelessWidget {', start)
if start < 0 or end < 0:
    fail('Salus landscape painter markers missing')

replacement = r'''class _SalusLandscapePainter extends CustomPainter {
  const _SalusLandscapePainter();

  @override
  void paint(Canvas canvas, Size size) {
    // SALUS_BUILD28_LOCKED_HOME_BACKGROUND
    // The home reference is nearly black midnight blue with a soft distant
    // mountain horizon and a fine cyan biometric particle field around the
    // recovery orb. Avoid hard polygon ridges, teal wash, or full-screen noise.
    final bounds = Offset.zero & size;

    canvas.drawRect(
      bounds,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: [0.0, 0.34, 0.66, 1.0],
          colors: [
            Color(0xFF050B11),
            Color(0xFF07131B),
            Color(0xFF040A0F),
            Color(0xFF03070A),
          ],
        ).createShader(bounds),
    );

    // A restrained halo behind Recovery. This is glow, not a colored panel.
    canvas.drawRect(
      bounds,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0.0, -0.20),
          radius: 0.62,
          colors: [
            AppTheme.cyan.withValues(alpha: 0.095),
            AppTheme.blue.withValues(alpha: 0.040),
            Colors.transparent,
          ],
          stops: const [0.0, 0.48, 1.0],
        ).createShader(bounds),
    );

    final horizon = size.height * 0.39;

    // Back mountain mass: deliberately soft and low contrast, like atmospheric
    // silhouettes rather than a geometric line graph.
    final backMountains = Path()
      ..moveTo(-30, horizon + 20)
      ..cubicTo(
        size.width * 0.03,
        horizon + 2,
        size.width * 0.10,
        horizon - 42,
        size.width * 0.18,
        horizon - 18,
      )
      ..cubicTo(
        size.width * 0.26,
        horizon + 6,
        size.width * 0.31,
        horizon - 28,
        size.width * 0.38,
        horizon - 52,
      )
      ..cubicTo(
        size.width * 0.45,
        horizon - 74,
        size.width * 0.51,
        horizon - 8,
        size.width * 0.58,
        horizon - 16,
      )
      ..cubicTo(
        size.width * 0.66,
        horizon - 24,
        size.width * 0.72,
        horizon - 64,
        size.width * 0.79,
        horizon - 36,
      )
      ..cubicTo(
        size.width * 0.86,
        horizon - 9,
        size.width * 0.92,
        horizon - 46,
        size.width + 30,
        horizon - 6,
      )
      ..lineTo(size.width + 30, horizon + 120)
      ..lineTo(-30, horizon + 120)
      ..close();

    final backPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xB0122B3C),
          Color(0x6B091721),
          Color(0x0003070A),
        ],
        stops: [0.0, 0.64, 1.0],
      ).createShader(bounds)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7.0);
    canvas.drawPath(backMountains, backPaint);

    // Near mountain layer. Keep the peaks dark and broad; there is no bright
    // outline because the target Salus look does not use a polygon ridge.
    final nearMountains = Path()
      ..moveTo(-24, horizon + 46)
      ..cubicTo(
        size.width * 0.06,
        horizon + 18,
        size.width * 0.13,
        horizon - 20,
        size.width * 0.20,
        horizon + 10,
      )
      ..cubicTo(
        size.width * 0.28,
        horizon + 42,
        size.width * 0.34,
        horizon - 10,
        size.width * 0.42,
        horizon + 8,
      )
      ..cubicTo(
        size.width * 0.51,
        horizon + 30,
        size.width * 0.57,
        horizon - 22,
        size.width * 0.66,
        horizon + 6,
      )
      ..cubicTo(
        size.width * 0.75,
        horizon + 30,
        size.width * 0.83,
        horizon - 18,
        size.width * 0.91,
        horizon + 12,
      )
      ..cubicTo(
        size.width * 0.96,
        horizon + 28,
        size.width + 8,
        horizon + 24,
        size.width + 24,
        horizon + 34,
      )
      ..lineTo(size.width + 24, horizon + 132)
      ..lineTo(-24, horizon + 132)
      ..close();

    canvas.drawPath(
      nearMountains,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xE20A1720),
            Color(0xD4050B10),
            Color(0x0003070A),
          ],
          stops: [0.0, 0.64, 1.0],
        ).createShader(bounds)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0),
    );

    // Biometric particle terrain. The reference uses many tiny points forming
    // a smooth rolling surface concentrated around/below the orb, not rows of
    // equally-spaced dots across the whole page.
    final fieldCenterY = size.height * 0.47;
    final columns = math.max(46, (size.width / 7.0).round());
    final columnStep = size.width / (columns - 1);
    final particle = Paint();

    for (var row = 0; row < 10; row++) {
      final depth = row / 9.0;
      final alpha = 0.24 * (1.0 - depth * 0.58);
      final rowOffset = row * 8.5;
      final amplitude = 20.0 + row * 3.8;
      final phase = row * 0.43;

      for (var column = 0; column < columns; column++) {
        final x = column * columnStep;
        final t = x / size.width;
        final wave =
            math.sin(t * math.pi * 3.25 + phase) * amplitude +
            math.sin(t * math.pi * 6.4 - phase * 0.6) * (amplitude * 0.22);
        final y = fieldCenterY + rowOffset + wave;

        // Stronger near the hero center and fading toward both screen edges.
        final edge = (2.0 * (t - 0.5).abs()).clamp(0.0, 1.0);
        final centerGain = 1.0 - edge * 0.48;
        particle.color = AppTheme.cyan.withValues(
          alpha: alpha * centerGain,
        );
        final radius = 0.72 + (1.0 - depth) * 0.42 * centerGain;
        canvas.drawCircle(Offset(x, y), radius, particle);
      }
    }

    // Two very subtle flowing traces give the particle terrain depth without
    // becoming the visible sine-wave lines seen in the rejected build.
    for (var trace = 0; trace < 2; trace++) {
      final path = Path();
      final base = fieldCenterY + 22 + trace * 31;
      for (double x = 0; x <= size.width; x += 5) {
        final t = x / size.width;
        final y = base +
            math.sin(t * math.pi * (2.7 + trace * 0.35) + trace * 1.2) *
                (18 + trace * 5);
        if (x == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8
          ..color = AppTheme.cyan.withValues(
            alpha: trace == 0 ? 0.095 : 0.055,
          ),
      );
    }

    // Fade the artwork away before the lower cards. The reference turns back
    // into clean midnight glass instead of carrying landscape texture forever.
    canvas.drawRect(
      Rect.fromLTRB(0, size.height * 0.53, size.width, size.height),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0x0003070A),
            Color(0xD903070A),
            Color(0xFF03070A),
          ],
          stops: [0.0, 0.42, 1.0],
        ).createShader(
          Rect.fromLTRB(0, size.height * 0.53, size.width, size.height),
        ),
    );
  }

  @override
  bool shouldRepaint(covariant _SalusLandscapePainter oldDelegate) => false;
}

'''

text = text[:start] + replacement + text[end:]
path.write_text(text)
print('Salus build 28 locked home background applied.')
