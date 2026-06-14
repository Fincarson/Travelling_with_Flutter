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
