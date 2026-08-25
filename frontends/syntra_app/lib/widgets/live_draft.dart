import 'dart:convert';

import 'package:flutter/material.dart';

import '../theme/syntra_palette.dart';
import '../theme/syntra_theme.dart';
import 'syntra_markdown.dart';

/// Parses complete JSON (or a ```json fence) for the live workspace.
/// Incomplete / mid-stream payloads return null so callers can fall back.
Object? tryParseLiveJson(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return null;

  var body = trimmed;
  if (body.startsWith('```')) {
    final fence = RegExp(
      r'^```(?:json)?\s*\n?([\s\S]*?)\n?```\s*$',
      caseSensitive: false,
    );
    final match = fence.firstMatch(body);
    if (match == null) return null;
    body = match.group(1)!.trim();
  }

  if (!body.startsWith('{') && !body.startsWith('[')) return null;
  try {
    return jsonDecode(body);
  } catch (_) {
    return null;
  }
}

String humanizeLiveJsonKey(String key) {
  const special = {
    'topic': 'Topic',
    'subject': 'Subject',
    'education_level': 'Level',
    'exam_board': 'Exam board',
    'learning_objectives': 'Learning objectives',
    'key_concepts': 'Key concepts',
    'misconceptions': 'Common misconceptions',
    'uncertainties': 'Uncertainties',
    'sources': 'Sources',
    'claims': 'Claims',
    'research_method': 'How this was researched',
    'rag_used': 'SYNTRA cache',
    'web_used': 'Live web',
    'fact_check_used': 'Fact-checked',
    'freshness': 'Freshness',
    'retrieval_mode': 'Retrieval',
    'organisation': 'Organisation',
    'title': 'Title',
    'url': 'Link',
    'source_tier': 'Tier',
    'source_authority': 'Authority',
    'claim': 'Claim',
    'evidence': 'Evidence',
    'verification': 'Verification',
    'hit_count': 'Cache hits',
    'lesson_sequence': 'Lesson sequence',
    'confidence': 'Confidence',
  };
  if (special.containsKey(key)) return special[key]!;
  return key
      .replaceAll('_', ' ')
      .split(' ')
      .where((word) => word.isNotEmpty)
      .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
      .join(' ');
}

class SyntraLiveMarkdown extends StatefulWidget {
  const SyntraLiveMarkdown({
    super.key,
    required this.data,
    required this.accent,
  });

  final String data;
  final Color accent;

  @override
  State<SyntraLiveMarkdown> createState() => _SyntraLiveMarkdownState();
}

class _SyntraLiveMarkdownState extends State<SyntraLiveMarkdown> {
  final _controller = ScrollController();

  @override
  void didUpdateWidget(covariant SyntraLiveMarkdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data == widget.data) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_controller.hasClients) return;
      _controller.animateTo(
        _controller.position.maxScrollExtent,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget child;
    try {
      final json = tryParseLiveJson(widget.data);
      child = json != null
          ? LiveJsonView(data: json, accent: widget.accent)
          : SyntraMarkdownView(
              data: widget.data,
              accent: widget.accent,
              shrinkWrap: true,
            );
    } catch (_) {
      child = SyntraMarkdownView(
        data: widget.data,
        accent: widget.accent,
        shrinkWrap: true,
      );
    }

    return SingleChildScrollView(
      controller: _controller,
      padding: const EdgeInsets.only(right: 8, bottom: 8),
      child: child,
    );
  }
}

class LiveJsonView extends StatelessWidget {
  const LiveJsonView({super.key, required this.data, required this.accent});

  final Object data;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    if (data is List) {
      return _JsonValue(value: data, accent: accent);
    }
    if (data is Map) {
      return _JsonMap(
        data: Map<String, dynamic>.from(data as Map),
        accent: accent,
        isRoot: true,
      );
    }
    return SyntraMarkdownView(
      data: data.toString(),
      accent: accent,
      shrinkWrap: true,
    );
  }
}

class _JsonMap extends StatelessWidget {
  const _JsonMap({
    required this.data,
    required this.accent,
    this.isRoot = false,
  });

  final Map<String, dynamic> data;
  final Color accent;
  final bool isRoot;

  @override
  Widget build(BuildContext context) {
    final used = <String>{};
    final header = isRoot ? _header(context, used) : null;
    final method = isRoot ? _method(context, used) : null;
    final sections = <Widget>[
      ?header,
      ?method,
      for (final key in _orderedKeys(data, used))
        if (!_isEmpty(data[key])) _section(context, key: key, value: data[key]),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < sections.length; i++) ...[
          if (i > 0) const SizedBox(height: 16),
          sections[i],
        ],
      ],
    );
  }

  Widget? _header(BuildContext context, Set<String> used) {
    final topic = _string(data['topic']);
    final subject = _string(data['subject']);
    final level = _string(data['education_level']);
    final board = _string(data['exam_board']);
    if (topic == null && subject == null && level == null && board == null) {
      return null;
    }
    used.addAll(['topic', 'subject', 'education_level', 'exam_board']);
    final chips = [?subject, ?level, ?board];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (topic != null)
          Text(
            topic,
            style: SyntraTheme.sans(
              color: SyntraPalette.navy,
              fontSize: 20,
              height: 1.25,
              fontWeight: FontWeight.w800,
            ),
          ),
        if (chips.isNotEmpty) ...[
          if (topic != null) const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final chip in chips) _DraftChip(label: chip, color: accent),
            ],
          ),
        ],
      ],
    );
  }

  Widget? _method(BuildContext context, Set<String> used) {
    final raw = data['research_method'];
    if (raw is! Map) return null;
    used.add('research_method');
    final method = Map<String, dynamic>.from(raw);
    final hitCount = data['hit_count'];
    if (hitCount != null) used.add('hit_count');

    final rag = method['rag_used'] == true;
    final web = method['web_used'] == true;
    final fact = method['fact_check_used'] == true;
    final freshness = _string(method['freshness']);
    final chips = <(String, Color)>[
      if (rag && !web) ('Reused from cache', SyntraPalette.sage),
      if (web && !rag) ('Researched live', accent),
      if (rag && web) ('Cache + live web', SyntraPalette.amber),
      if (fact) ('Fact-checked', SyntraPalette.sage),
      if (freshness != null) (_titleCase(freshness), SyntraPalette.inkMuted),
      if (hitCount is num && hitCount > 0)
        ('${hitCount.toInt()} cache hits', SyntraPalette.sage),
    ];
    if (chips.isEmpty) return null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel(text: 'How this was researched', accent: accent),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final chip in chips)
              _DraftChip(label: chip.$1, color: chip.$2),
          ],
        ),
      ],
    );
  }

  Widget _section(
    BuildContext context, {
    required String key,
    required Object? value,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel(text: humanizeLiveJsonKey(key), accent: accent),
        const SizedBox(height: 8),
        _JsonValue(value: value, accent: accent, keyHint: key),
      ],
    );
  }
}

class _JsonValue extends StatelessWidget {
  const _JsonValue({required this.value, required this.accent, this.keyHint});

  final Object? value;
  final Color accent;
  final String? keyHint;

  @override
  Widget build(BuildContext context) {
    final current = value;
    if (current == null) return const SizedBox.shrink();
    if (current is bool) {
      return _DraftChip(
        label: current ? 'Yes' : 'No',
        color: current ? SyntraPalette.sage : SyntraPalette.inkMuted,
      );
    }
    if (current is num) {
      return Text(
        current.toString(),
        style: SyntraTheme.sans(
          color: SyntraPalette.ink,
          fontSize: 15,
          height: 1.45,
        ),
      );
    }
    if (current is String) {
      return SyntraMarkdownView(
        data: current,
        accent: accent,
        shrinkWrap: true,
        selectable: false,
      );
    }
    if (current is List) {
      return _JsonList(items: current, accent: accent, keyHint: keyHint);
    }
    if (current is Map) {
      return _NestedPanel(
        child: _JsonMap(
          data: Map<String, dynamic>.from(current),
          accent: accent,
        ),
      );
    }
    return Text(
      current.toString(),
      style: SyntraTheme.sans(color: SyntraPalette.inkMuted, fontSize: 14),
    );
  }
}

class _JsonList extends StatelessWidget {
  const _JsonList({required this.items, required this.accent, this.keyHint});

  final List<dynamic> items;
  final Color accent;
  final String? keyHint;

  @override
  Widget build(BuildContext context) {
    final values = items.where((item) => !_isEmpty(item)).toList();
    if (values.isEmpty) return const SizedBox.shrink();

    if (values.every((item) => item is String)) {
      final strings = values.cast<String>();
      final asChips =
          strings.every((item) => item.trim().length <= 42) &&
          keyHint != 'misconceptions' &&
          keyHint != 'uncertainties' &&
          keyHint != 'claims';
      if (asChips) {
        return Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final item in strings)
              _DraftChip(label: item, color: SyntraPalette.navy),
          ],
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final item in strings)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 7),
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: accent,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SyntraMarkdownView(
                      data: item,
                      accent: accent,
                      shrinkWrap: true,
                      selectable: false,
                    ),
                  ),
                ],
              ),
            ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < values.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          _NestedPanel(
            child: values[i] is Map
                ? _objectCard(Map<String, dynamic>.from(values[i] as Map))
                : _JsonValue(value: values[i], accent: accent),
          ),
        ],
      ],
    );
  }

  Widget _objectCard(Map<String, dynamic> item) {
    if (item.containsKey('claim')) {
      return _ClaimCard(data: item, accent: accent);
    }
    if (item.containsKey('organisation') ||
        item.containsKey('url') ||
        (item.containsKey('title') && item.length <= 6)) {
      return _SourceCard(data: item, accent: accent);
    }
    return _JsonMap(data: item, accent: accent);
  }
}

class _ClaimCard extends StatelessWidget {
  const _ClaimCard({required this.data, required this.accent});

  final Map<String, dynamic> data;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final claim = _string(data['claim']);
    final evidence = _string(data['evidence']);
    final sources = data['sources'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (claim != null)
          SyntraMarkdownView(
            data: claim,
            accent: accent,
            shrinkWrap: true,
            selectable: false,
          ),
        if (evidence != null) ...[
          const SizedBox(height: 6),
          Text(
            evidence,
            style: SyntraTheme.sans(
              color: SyntraPalette.inkMuted,
              fontSize: 13,
              height: 1.45,
            ),
          ),
        ],
        if (sources is List && sources.isNotEmpty) ...[
          const SizedBox(height: 8),
          _JsonList(items: sources, accent: accent, keyHint: 'sources'),
        ],
      ],
    );
  }
}

class _SourceCard extends StatelessWidget {
  const _SourceCard({required this.data, required this.accent});

  final Map<String, dynamic> data;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final title = _string(data['title']);
    final org = _string(data['organisation']);
    final url = _string(data['url']);
    final tier = data['source_tier'];
    final authority = _string(data['source_authority']);
    final heading = title ?? org ?? 'Source';
    final markdown = url != null ? '[$heading]($url)' : heading;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SyntraMarkdownView(
          data: markdown,
          accent: accent,
          shrinkWrap: true,
          selectable: false,
        ),
        if (org != null && title != null)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              org,
              style: SyntraTheme.sans(
                color: SyntraPalette.inkMuted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        if (tier != null || authority != null) ...[
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (authority != null)
                _DraftChip(
                  label: _titleCase(authority),
                  color: SyntraPalette.inkMuted,
                ),
              if (tier != null)
                _DraftChip(label: 'Tier $tier', color: SyntraPalette.inkMuted),
            ],
          ),
        ],
      ],
    );
  }
}

class _NestedPanel extends StatelessWidget {
  const _NestedPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: SyntraPalette.voidMid.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: SyntraPalette.stroke),
      ),
      child: child,
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text, required this.accent});

  final String text;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: Theme.of(
        context,
      ).textTheme.labelSmall?.copyWith(color: accent, letterSpacing: 1.0),
    );
  }
}

class _DraftChip extends StatelessWidget {
  const _DraftChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: SyntraTheme.sans(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

const _preferredKeys = [
  'key_concepts',
  'learning_objectives',
  'claims',
  'misconceptions',
  'uncertainties',
  'sources',
  'lesson_sequence',
];

List<String> _orderedKeys(Map<String, dynamic> data, Set<String> used) {
  final keys = <String>[];
  for (final key in _preferredKeys) {
    if (data.containsKey(key) && !used.contains(key)) keys.add(key);
  }
  for (final key in data.keys) {
    if (used.contains(key) || keys.contains(key) || key.startsWith('_')) {
      continue;
    }
    keys.add(key);
  }
  return keys;
}

bool _isEmpty(Object? value) {
  if (value == null) return true;
  if (value is String) return value.trim().isEmpty;
  if (value is List) return value.isEmpty;
  if (value is Map) return value.isEmpty;
  return false;
}

String? _string(Object? value) {
  if (value == null) return null;
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}

String _titleCase(String value) {
  return value
      .replaceAll('_', ' ')
      .split(' ')
      .where((word) => word.isNotEmpty)
      .map(
        (word) => '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}',
      )
      .join(' ');
}
