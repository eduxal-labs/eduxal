import 'package:flutter/material.dart';
import 'tiptap_renderer.dart';

/// Renders a question stimulus (passage, table, graph, diagram) in a
/// visually distinct container that separates it from the question body.
///
/// Stimulus map shape:
///   { 'type': 'passage'|'table'|'graph'|'diagram',
///     'body': String, 'body_format': 'plain'|'tiptap',
///     'caption': String? }
class StimulusBlock extends StatelessWidget {
  const StimulusBlock({super.key, required this.stimulus});

  final Map<String, dynamic> stimulus;

  @override
  Widget build(BuildContext context) {
    final type = stimulus['type'] as String? ?? 'passage';
    final body = stimulus['body'] as String? ?? '';
    final bodyFormat = stimulus['body_format'] as String? ?? 'plain';
    final caption = stimulus['caption'] as String?;
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: switch (type) {
        'passage' => _PassageBlock(
          body: body,
          bodyFormat: bodyFormat,
          caption: caption,
          theme: theme,
        ),
        'table' => _TableBlock(
          body: body,
          bodyFormat: bodyFormat,
          caption: caption,
          theme: theme,
        ),
        _ => _ImageBlock(stimulus: stimulus, caption: caption, theme: theme),
      },
    );
  }
}

class _PassageBlock extends StatelessWidget {
  const _PassageBlock({
    required this.body,
    required this.bodyFormat,
    required this.caption,
    required this.theme,
  });
  final String body;
  final String bodyFormat;
  final String? caption;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.35,
        ),
        border: Border(
          left: BorderSide(color: theme.colorScheme.primary, width: 3),
        ),
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(4),
          bottomRight: Radius.circular(4),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (caption != null) ...[
            Text(
              caption!.toUpperCase(),
              style: theme.textTheme.labelSmall?.copyWith(
                letterSpacing: 1.1,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
          ],
          renderBody(
            body,
            bodyFormat,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontSize: 13,
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }
}

class _TableBlock extends StatelessWidget {
  const _TableBlock({
    required this.body,
    required this.bodyFormat,
    required this.caption,
    required this.theme,
  });
  final String body;
  final String bodyFormat;
  final String? caption;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (caption != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              caption!,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        renderBody(body, bodyFormat),
      ],
    );
  }
}

class _ImageBlock extends StatelessWidget {
  const _ImageBlock({
    required this.stimulus,
    required this.caption,
    required this.theme,
  });
  final Map<String, dynamic> stimulus;
  final String? caption;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    // Graph/diagram — body is descriptive text if no image is present.
    final body = stimulus['body'] as String? ?? '';
    final bodyFormat = stimulus['body_format'] as String? ?? 'plain';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        renderBody(body, bodyFormat),
        if (caption != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              caption!,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );
  }
}
