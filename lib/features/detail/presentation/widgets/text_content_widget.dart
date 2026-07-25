import 'package:flutter/material.dart';
import 'package:tatislam_app/features/detail/domain/services/html_parser_service.dart';
import 'package:tatislam_app/features/publications/domain/entities/content_block.dart';

/// Renders a [TextContentBlock] as plain text with HTML stripped.
class TextContentWidget extends StatelessWidget {
  final TextContentBlock block;
  final HtmlParserService htmlParser;

  const TextContentWidget({
    super.key,
    required this.block,
    this.htmlParser = const HtmlParserService(),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(
        htmlParser.parseToPlainText(block.text),
        style: Theme.of(context).textTheme.bodyLarge,
        textAlign: TextAlign.justify,
      ),
    );
  }
}