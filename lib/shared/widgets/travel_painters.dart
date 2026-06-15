part of travel_agent_app;

class _GlobePainter extends CustomPainter {
  const _GlobePainter(this.progress);
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) * .42;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = _secondary.withValues(alpha: .35);
    canvas.drawCircle(center, radius, paint);
    for (var i = 0; i < 4; i++) {
      final angle = progress * math.pi * 2 + i * math.pi / 2;
      final point =
          center +
          Offset(math.cos(angle) * radius, math.sin(angle) * radius * .55);
      canvas.drawCircle(
        point,
        5,
        Paint()..color = i.isEven ? _accent : _primary,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _GlobePainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _MapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final road = Paint()
      ..color = Colors.white.withValues(alpha: .22)
      ..strokeWidth = 12
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final thin = Paint()
      ..color = _accent.withValues(alpha: .5)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 6; i++) {
      final y = size.height * (i + 1) / 7;
      canvas.drawLine(
        Offset(-20, y),
        Offset(size.width + 20, y + math.sin(i) * 40),
        road,
      );
      canvas.drawLine(
        Offset(-20, y),
        Offset(size.width + 20, y + math.sin(i) * 40),
        thin,
      );
    }
    for (var i = 0; i < 5; i++) {
      final x = size.width * (i + 1) / 6;
      canvas.drawLine(
        Offset(x, -20),
        Offset(x + math.cos(i) * 50, size.height + 20),
        road,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
