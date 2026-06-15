part of travel_agent_app;

class LoadingScreen extends StatelessWidget {
  const LoadingScreen({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return ScreenScaffold(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(color: _primary),
                const SizedBox(height: 22),
                Text(
                  appText(context, message),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: _secondary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SyncBanner extends StatelessWidget {
  const SyncBanner({required this.message, super.key});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      elevation: 8,
      borderRadius: BorderRadius.circular(22),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: UnexpectedErrorView(
          error: AppErrorData.fromMessage(message),
          compact: true,
        ),
      ),
    );
  }
}

class FormNotice extends StatelessWidget {
  const FormNotice({required this.message, super.key});
  final String message;

  @override
  Widget build(BuildContext context) {
    if (looksLikeTechnicalError(message)) {
      return Material(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: UnexpectedErrorView(
            error: AppErrorData.fromMessage(message),
            compact: true,
          ),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: Color(0xFFB91C1C)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              appText(context, message),
              style: const TextStyle(
                color: Color(0xFF991B1B),
                fontSize: 12,
                fontWeight: FontWeight.w800,
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ScreenScaffold extends StatelessWidget {
  const ScreenScaffold({
    required this.child,
    this.bottomPadding = 0,
    super.key,
  });
  final Widget child;
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomPadding),
        child: child,
      ),
    );
  }
}
