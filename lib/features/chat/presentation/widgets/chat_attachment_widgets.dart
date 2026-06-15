part of travel_agent_app;

class ChatMessageContent extends StatelessWidget {
  const ChatMessageContent({
    required this.message,
    required this.foregroundColor,
    super.key,
  });

  final GroupChatMessage message;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    final url = _firstUrlIn(message.text);
    final directGif = url != null && _isGifUri(url);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final attachment in message.attachments)
          Padding(
            padding: EdgeInsets.only(
              bottom: message.text.trim().isEmpty ? 0 : 10,
            ),
            child: ChatAttachmentPreview(attachment: attachment),
          ),
        if (directGif) ...[
          ChatNetworkImagePreview(url: url.toString(), isGif: true),
          if (message.text.trim() != url.toString()) const SizedBox(height: 8),
        ],
        if (message.text.trim().isNotEmpty &&
            (!directGif || message.text.trim() != url.toString()))
          Text(
            message.text,
            softWrap: true,
            style: TextStyle(
              color: foregroundColor,
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
          ),
        if (url != null && !directGif) ...[
          const SizedBox(height: 8),
          _ChatLinkCard(uri: url),
        ],
      ],
    );
  }
}

class ChatAttachmentPreview extends StatelessWidget {
  const ChatAttachmentPreview({
    required this.attachment,
    this.compact = false,
    super.key,
  });

  final Map<String, dynamic> attachment;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final type = (attachment['type'] as String?) ?? 'file';
    final url = (attachment['url'] as String?)?.trim() ?? '';
    final name = (attachment['name'] as String?)?.trim();
    return switch (type) {
      'image' => ChatNetworkImagePreview(url: url),
      'gif' => ChatNetworkImagePreview(url: url, isGif: true),
      'video' => ChatVideoAttachment(url: url, name: name),
      'pdf' => _ChatFileCard(
        url: url,
        name: name ?? 'Document.pdf',
        sizeBytes: attachment['sizeBytes'] as int?,
        icon: Icons.picture_as_pdf_rounded,
        compact: compact,
      ),
      _ => _ChatFileCard(
        url: url,
        name: name ?? 'Attachment',
        sizeBytes: attachment['sizeBytes'] as int?,
        icon: Icons.insert_drive_file_rounded,
        compact: compact,
      ),
    };
  }
}

class ChatNetworkImagePreview extends StatefulWidget {
  const ChatNetworkImagePreview({
    required this.url,
    this.isGif = false,
    super.key,
  });

  final String url;
  final bool isGif;

  @override
  State<ChatNetworkImagePreview> createState() =>
      _ChatNetworkImagePreviewState();
}

class _ChatNetworkImagePreviewState extends State<ChatNetworkImagePreview> {
  var _gifRequested = false;

  @override
  Widget build(BuildContext context) {
    final settings = PerformanceScope.maybeSettingsOf(context);
    final colors = Theme.of(context).colorScheme;
    final shouldLoadGif =
        !widget.isGif ||
        settings.preset == PerformancePreset.high ||
        (settings.preset == PerformancePreset.custom &&
            settings.heavyVisualEffects) ||
        _gifRequested;

    if (widget.url.isEmpty) {
      return const _UnavailableAttachmentCard();
    }
    if (!shouldLoadGif) {
      return Material(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: settings.preset == PerformancePreset.batterySaver
              ? () => _openChatUrl(context, widget.url, isAttachment: true)
              : () => setState(() => _gifRequested = true),
          child: SizedBox(
            height: 150,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.gif_box_rounded, size: 40),
                  const SizedBox(height: 8),
                  Text(
                    appText(
                      context,
                      settings.preset == PerformancePreset.batterySaver
                          ? 'Open GIF'
                          : 'Tap to play GIF',
                    ),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 280, minHeight: 120),
        child: InkWell(
          onTap: () => _openChatUrl(context, widget.url, isAttachment: true),
          child: Image.network(
            widget.url,
            fit: BoxFit.cover,
            filterQuality: settings.filterQuality,
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return const SizedBox(
                height: 180,
                child: Center(child: CircularProgressIndicator()),
              );
            },
            errorBuilder: (_, __, ___) => const _UnavailableAttachmentCard(),
          ),
        ),
      ),
    );
  }
}

class ChatVideoAttachment extends StatefulWidget {
  const ChatVideoAttachment({required this.url, this.name, super.key});

  final String url;
  final String? name;

  @override
  State<ChatVideoAttachment> createState() => _ChatVideoAttachmentState();
}

class _ChatVideoAttachmentState extends State<ChatVideoAttachment> {
  VideoPlayerController? _controller;
  Future<void>? _initialization;
  Object? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final settings = PerformanceScope.maybeSettingsOf(context);
    if (settings.preset != PerformancePreset.batterySaver &&
        _controller == null &&
        widget.url.isNotEmpty) {
      _initialize(settings);
    }
  }

  void _initialize(AppPerformanceSettings settings) {
    final controller = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    _controller = controller;
    _initialization = controller
        .initialize()
        .then((_) async {
          await controller.setLooping(true);
          final autoPlay =
              settings.preset == PerformancePreset.high ||
              (settings.preset == PerformancePreset.custom &&
                  settings.heavyVisualEffects &&
                  settings.animationsEnabled);
          if (autoPlay) {
            await controller.setVolume(0);
            await controller.play();
          }
        })
        .catchError((Object error) {
          _error = error;
        })
        .whenComplete(() {
          if (mounted) setState(() {});
        });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = PerformanceScope.maybeSettingsOf(context);
    final colors = Theme.of(context).colorScheme;
    if (widget.url.isEmpty || _error != null) {
      return const _UnavailableAttachmentCard();
    }
    if (settings.preset == PerformancePreset.batterySaver) {
      return _StaticMediaCard(
        icon: Icons.play_circle_outline_rounded,
        label: widget.name ?? appText(context, 'Video'),
        onTap: () => _openChatUrl(context, widget.url, isAttachment: true),
      );
    }

    final controller = _controller;
    if (controller == null ||
        _initialization == null ||
        !controller.value.isInitialized) {
      return const SizedBox(
        height: 180,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Material(
        color: colors.scrim,
        child: InkWell(
          onTap: () {
            controller.value.isPlaying ? controller.pause() : controller.play();
            setState(() {});
          },
          child: Stack(
            alignment: Alignment.center,
            children: [
              AspectRatio(
                aspectRatio: controller.value.aspectRatio == 0
                    ? 16 / 9
                    : controller.value.aspectRatio,
                child: VideoPlayer(controller),
              ),
              if (!controller.value.isPlaying)
                const Icon(
                  Icons.play_circle_fill_rounded,
                  size: 54,
                  color: Colors.white,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChatFileCard extends StatelessWidget {
  const _ChatFileCard({
    required this.url,
    required this.name,
    required this.icon,
    this.sizeBytes,
    this.compact = false,
  });

  final String url;
  final String name;
  final int? sizeBytes;
  final IconData icon;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _openChatUrl(context, url, isAttachment: true),
        child: Padding(
          padding: EdgeInsets.all(compact ? 10 : 12),
          child: Row(
            children: [
              Icon(icon, color: colors.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.onSurface,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (sizeBytes != null)
                      Text(
                        _fileSizeLabel(sizeBytes!),
                        style: TextStyle(
                          color: colors.onSurfaceVariant,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.open_in_new_rounded, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChatLinkCard extends StatelessWidget {
  const _ChatLinkCard({required this.uri});

  final Uri uri;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _openChatUrl(context, uri.toString()),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              Icon(Icons.link_rounded, color: colors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  uri.toString(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.onSurface,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const Icon(Icons.open_in_new_rounded, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _StaticMediaCard extends StatelessWidget {
  const _StaticMediaCard({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: SizedBox(
          height: 160,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 46),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Text(
                    label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w800),
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

class _UnavailableAttachmentCard extends StatelessWidget {
  const _UnavailableAttachmentCard();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.errorContainer,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                appText(context, 'This file is unavailable or has expired.'),
              ),
            ),
          );
        },
        child: Container(
          constraints: const BoxConstraints(minHeight: 72),
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(Icons.link_off_rounded, color: colors.onErrorContainer),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  appText(context, 'This file is unavailable or has expired.'),
                  style: TextStyle(
                    color: colors.onErrorContainer,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> _openChatUrl(
  BuildContext context,
  String rawUrl, {
  bool isAttachment = false,
}) async {
  try {
    final uri = Uri.parse(rawUrl);
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened) throw StateError('The link could not be opened.');
  } catch (_) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          appText(
            context,
            isAttachment
                ? 'This file is unavailable or has expired.'
                : 'This link could not be opened.',
          ),
        ),
      ),
    );
  }
}

bool _isGifUri(Uri uri) {
  final path = uri.path.toLowerCase();
  return path.endsWith('.gif') || path.contains('.gif/');
}

String _fileSizeLabel(int bytes) {
  if (bytes < 1024) return '$bytes B';
  final kilobytes = bytes / 1024;
  if (kilobytes < 1024) return '${kilobytes.toStringAsFixed(1)} KB';
  final megabytes = kilobytes / 1024;
  return '${megabytes.toStringAsFixed(1)} MB';
}
