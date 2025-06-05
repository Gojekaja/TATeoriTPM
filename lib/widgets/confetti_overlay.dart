import 'dart:math';
import 'package:flutter/material.dart';

class ConfettiOverlay extends StatefulWidget {
  const ConfettiOverlay({super.key});

  @override
  State<ConfettiOverlay> createState() => _ConfettiOverlayState();
}

class _ConfettiOverlayState extends State<ConfettiOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late List<Confetti> _confetti;
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );

    _confetti = List.generate(100, (index) => Confetti(_random));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          painter: ConfettiPainter(_confetti, _controller.value),
          child: Container(),
        );
      },
    );
  }
}

class Confetti {
  final Random random;
  late double x;
  late double y;
  late Color color;
  late double size;
  late double speed;
  late double angle;

  Confetti(this.random) {
    reset();
  }

  void reset() {
    x = random.nextDouble();
    y = random.nextDouble() * -1;
    color = Colors.primaries[random.nextInt(Colors.primaries.length)];
    size = random.nextDouble() * 8 + 4;
    speed = random.nextDouble() * 2 + 1;
    angle = random.nextDouble() * pi * 2;
  }
}

class ConfettiPainter extends CustomPainter {
  final List<Confetti> confetti;
  final double progress;

  ConfettiPainter(this.confetti, this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();

    for (var particle in confetti) {
      final current = progress * particle.speed;
      final y = particle.y + current;
      final x = particle.x + sin(particle.angle + current) * 0.5;

      if (y > 1) {
        particle.reset();
        continue;
      }

      paint.color = particle.color;
      canvas.drawCircle(
        Offset(x * size.width, y * size.height),
        particle.size,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(ConfettiPainter oldDelegate) => true;
}
