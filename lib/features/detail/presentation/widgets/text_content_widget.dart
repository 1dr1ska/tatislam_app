import 'package:flutter/gestures.dart' show TapGestureRecognizer;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:tatislam_app/core/constants/app_colors.dart';
import 'package:tatislam_app/core/constants/app_localizations.dart';
import 'package:tatislam_app/core/providers/text_scale_provider.dart';
import 'package:tatislam_app/features/detail/domain/services/html_parser_service.dart';
import 'package:tatislam_app/features/publications/domain/entities/content_block.dart';

/// Renders a [TextContentBlock] as rich text.
///
/// HTML tags are stripped (see [HtmlParserService]); hyperlinks — both
/// `<a href="…">…</a>` tags and bare URLs — are highlighted with the link color
/// and underlined, and open in an external browser when tapped. The text stays
/// selectable via [SelectableText.rich].
class TextContentWidget extends ConsumerStatefulWidget {
  final TextContentBlock block;
  final HtmlParserService htmlParser;

  const TextContentWidget({
    super.key,
    required this.block,
    this.htmlParser = const HtmlParserService(),
  });

  @override
  ConsumerState<TextContentWidget> createState() => _TextContentWidgetState();
}

class _TextContentWidgetState extends ConsumerState<TextContentWidget> {
  List<TextContentSegment> _segments = [];
  final List<TapGestureRecognizer> _recognizers = [];
  BuildContext? _buildContext;

  @override
  void initState() {
    super.initState();
    _rebuildContent();
  }

  @override
  void didUpdateWidget(TextContentWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.block.text != widget.block.text) {
      _rebuildContent();
    }
  }

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  void _disposeRecognizers() {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    _recognizers.clear();
  }

  void _rebuildContent() {
    _disposeRecognizers();
    _segments = widget.htmlParser.parseToSegments(widget.block.text);
    for (final segment in _segments) {
      if (!segment.isLink) {
        continue;
      }
      final recognizer = TapGestureRecognizer();
      recognizer.onTap = () => _openLink(segment.href!);
      _recognizers.add(recognizer);
    }
  }

  Future<void> _openLink(String href) async {
    final uri = Uri.parse(_normalizeUrl(href));
    try {
      if (await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        return;
      }
      if (await launchUrl(uri, mode: LaunchMode.platformDefault)) {
        return;
      }
      _showLinkError(uri.toString());
    } catch (error) {
      _showLinkError(error.toString());
    }
  }

  /// Ensures the href has a usable scheme for [launchUrl].
  String _normalizeUrl(String href) {
    final trimmed = href.trim();
    if (trimmed.isEmpty) {
      return trimmed;
    }
    final hasScheme = trimmed.startsWith('http://') ||
        trimmed.startsWith('https://') ||
        trimmed.startsWith('mailto:') ||
        trimmed.startsWith('tel:') ||
        trimmed.startsWith('ftp://');
    return hasScheme ? trimmed : 'https://$trimmed';
  }

  void _showLinkError(String message) {
    final context = _buildContext;
    if (context == null || !context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(ref).couldNotOpenUrl(message)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    _buildContext = context;
    final textScale = ref.watch(textScaleProvider).scale;
    // At large text sizes justified alignment creates excessive word gaps.
    // Switch to start-aligned for better readability.
    final align = textScale > 1.15 ? TextAlign.start : TextAlign.justify;

    final baseStyle = Theme.of(context).textTheme.bodyLarge?.copyWith(
      color: const Color(0xFF2D2D44),
      height: 1.7,
      letterSpacing: 0.2,
    );

    var recognizerIndex = 0;
    final children = <TextSpan>[];
    for (final segment in _segments) {
      if (segment.isLink) {
        children.add(
          TextSpan(
            text: segment.text,
            style: const TextStyle(
              color: AppColors.link,
            ),
            recognizer: _recognizers[recognizerIndex],
          ),
        );
        recognizerIndex += 1;
      } else {
        children.add(TextSpan(text: segment.text));
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: SelectableText.rich(
        TextSpan(children: children),
        style: baseStyle,
        textAlign: align,
      ),
    );
  }
}
