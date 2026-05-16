import 'package:flutter/material.dart';

enum AppButtonVariant {
  filled,
  outlined,
  text,
}

class AppButton extends StatelessWidget {
  static const _minimumSize = Size(64, 48);
  static final _shape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(8),
  );

  const AppButton({
    required this.text,
    required this.onPressed,
    this.variant = AppButtonVariant.filled,
    this.icon,
    this.fullWidth = true,
    super.key,
  });

  const AppButton.outlined({
    required this.text,
    required this.onPressed,
    this.icon,
    this.fullWidth = true,
    super.key,
  }) : variant = AppButtonVariant.outlined;

  const AppButton.text({
    required this.text,
    required this.onPressed,
    this.icon,
    this.fullWidth = false,
    super.key,
  }) : variant = AppButtonVariant.text;

  final String text;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final IconData? icon;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    final child = _ButtonContent(
      text: text,
      icon: icon,
    );

    final button = switch (variant) {
      AppButtonVariant.filled => FilledButton(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            minimumSize: _minimumSize,
            shape: _shape,
          ),
          child: child,
        ),
      AppButtonVariant.outlined => OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            minimumSize: _minimumSize,
            shape: _shape,
          ),
          child: child,
        ),
      AppButtonVariant.text => TextButton(
          onPressed: onPressed,
          style: TextButton.styleFrom(
            minimumSize: _minimumSize,
            shape: _shape,
          ),
          child: child,
        ),
    };

    if (!fullWidth) {
      return button;
    }

    return SizedBox(
      width: double.infinity,
      child: button,
    );
  }
}

class _ButtonContent extends StatelessWidget {
  const _ButtonContent({
    required this.text,
    this.icon,
  });

  final String text;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    if (icon == null) {
      return Text(text);
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 18),
        const SizedBox(width: 8),
        Flexible(child: Text(text)),
      ],
    );
  }
}
