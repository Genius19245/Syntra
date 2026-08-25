import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/syntra_palette.dart';
import '../theme/syntra_theme.dart';
import 'slide_deck.dart';

class SlidePanel extends StatefulWidget {
  const SlidePanel({
    super.key,
    required this.deck,
    this.accent = SyntraPalette.rust,
    this.subject,
    this.level,
    this.board,
    this.initialIndex = 0,
    this.onIndexChanged,
  });

  final SlideDeck deck;
  final Color accent;
  final String? subject;
  final String? level;
  final String? board;
  final int initialIndex;
  final ValueChanged<int>? onIndexChanged;

  @override
  State<SlidePanel> createState() => _SlidePanelState();
}

class _SlidePanelState extends State<SlidePanel> {
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = _clampedIndex(widget.initialIndex);
  }

  int _clampedIndex(int index) {
    if (widget.deck.slides.isEmpty) return 0;
    return index.clamp(0, widget.deck.slides.length - 1);
  }

  @override
  void didUpdateWidget(covariant SlidePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.deck.slides.length != widget.deck.slides.length) {
      _index = 0;
      widget.onIndexChanged?.call(_index);
    } else if (_index >= widget.deck.slides.length) {
      _index = widget.deck.slides.length - 1;
      widget.onIndexChanged?.call(_index);
    }
  }

  void _go(int delta) {
    final next = (_index + delta).clamp(0, widget.deck.slides.length - 1);
    if (next != _index) {
      setState(() => _index = next);
      widget.onIndexChanged?.call(_index);
    }
  }

  @override
  Widget build(BuildContext context) {
    final deck = widget.deck;
    final slide = deck.slides[_index];
    final last = _index == deck.slides.length - 1;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () => _go(-1),
        const SingleActivator(LogicalKeyboardKey.arrowRight): () => _go(1),
      },
      child: Focus(
        autofocus: true,
        child: Column(
          children: [
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  var boardWidth = constraints.maxWidth.clamp(220.0, constraints.maxWidth);
                  var boardHeight = boardWidth * 9 / 16;
                  if (boardHeight > constraints.maxHeight) {
                    boardHeight = constraints.maxHeight;
                    boardWidth = boardHeight * 16 / 9;
                  }
                  return Center(
                    child: SizedBox(
                      width: boardWidth,
                      height: boardHeight,
                      child: _Board(
                        slide: slide,
                        accent: widget.accent,
                        subject: widget.subject,
                        level: widget.level,
                        board: widget.board,
                        index: _index,
                        total: deck.slides.length,
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _FooterNav(
                  label: 'Previous',
                  icon: Icons.chevron_left_rounded,
                  leading: true,
                  onPressed: _index == 0 ? null : () => _go(-1),
                  accent: widget.accent,
                ),
                const Spacer(),
                _FooterNav(
                  label: 'Next',
                  icon: Icons.chevron_right_rounded,
                  leading: false,
                  onPressed: last ? null : () => _go(1),
                  accent: widget.accent,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Board extends StatelessWidget {
  const _Board({
    required this.slide,
    required this.accent,
    required this.index,
    required this.total,
    this.subject,
    this.level,
    this.board,
  });

  final Slide slide;
  final Color accent;
  final int index;
  final int total;
  final String? subject;
  final String? level;
  final String? board;

  @override
  Widget build(BuildContext context) {
    final color = difficultyColor(slide.difficulty);
    final crumbs = [
      if (subject != null && subject!.trim().isNotEmpty) subject!.trim(),
      if (board != null && board!.trim().isNotEmpty) board!.trim(),
      if (level != null && level!.trim().isNotEmpty) level!.trim(),
    ];
    return DecoratedBox(
      decoration: BoxDecoration(
        color: SyntraPalette.paper,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: SyntraPalette.strokeStrong),
        boxShadow: [
          BoxShadow(
            color: SyntraPalette.navy.withValues(alpha: 0.12),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: accent.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(height: 6, color: color),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: crumbs.isEmpty
                              ? const SizedBox.shrink()
                              : Wrap(
                                  spacing: 6,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    for (var i = 0; i < crumbs.length; i++) ...[
                                      if (i > 0)
                                        Text(
                                          '·',
                                          style: SyntraTheme.sans(
                                            color: SyntraPalette.inkFaint,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      Text(
                                        crumbs[i],
                                        style: SyntraTheme.sans(
                                          color: SyntraPalette.inkMuted,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                        ),
                        Text(
                          'Slide ${index + 1} / $total',
                          style: SyntraTheme.sans(
                            color: SyntraPalette.navy,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: slide.hasVisual
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  flex: 4,
                                  child: _SlideCopy(slide: slide, color: color),
                                ),
                                const SizedBox(height: 10),
                                Expanded(
                                  flex: 6,
                                  child: _CaptionedVisual(
                                    slide: slide,
                                    accent: accent,
                                  ),
                                ),
                              ],
                            )
                          : _SlideCopy(slide: slide, color: color),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SlideCopy extends StatelessWidget {
  const _SlideCopy({required this.slide, required this.color});

  final Slide slide;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            if (slide.estimatedMinutes > 0)
              _MetaChip(
                label: '${slide.estimatedMinutes} MIN',
                color: color,
              ),
            _MetaChip(label: slide.difficultyLabel, color: color),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          slide.title,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: SyntraTheme.serif(
            color: SyntraPalette.navy,
            fontSize: 22,
            height: 1.15,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final line in slide.content.take(5))
                Flexible(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.only(top: 8, right: 10),
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            line,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: SyntraTheme.sans(
                              color: SyntraPalette.navy,
                              fontSize: 16,
                              height: 1.3,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CaptionedVisual extends StatelessWidget {
  const _CaptionedVisual({required this.slide, required this.accent});

  final Slide slide;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final caption = figureCaption(slide);
    return Stack(
      fit: StackFit.expand,
      children: [
        _SlideVisual(slide: slide, accent: accent),
        if (caption != null)
          Positioned(
            left: 10,
            right: 10,
            bottom: 10,
            child: _CaptionBar(text: caption),
          ),
      ],
    );
  }
}

class _CaptionBar extends StatelessWidget {
  const _CaptionBar({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: SyntraPalette.navy.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: SyntraTheme.sans(
            color: SyntraPalette.paper,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _SlideVisual extends StatelessWidget {
  const _SlideVisual({required this.slide, required this.accent});

  final Slide slide;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final asset = slide.visualAsset;
    if (asset?.ready == true) {
      return _StoredImage(asset: asset!);
    }
    if (slide.visualType == 'equation' && (slide.equation ?? '').isNotEmpty) {
      return _EquationVisual(equation: slide.equation!);
    }
    if (slide.diagramSpec != null || slide.visualType == 'diagram') {
      return _DiagramVisual(
        spec: slide.diagramSpec,
        description: slide.visualDescription,
      );
    }
    return _SpecVisual(slide: slide, accent: accent);
  }
}

class _StoredImage extends StatelessWidget {
  const _StoredImage({required this.asset});

  final VisualAsset asset;

  @override
  Widget build(BuildContext context) {
    final image = _imageFor(asset);
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Stack(
        fit: StackFit.expand,
        children: [
          const ColoredBox(color: SyntraPalette.voidMid),
          image,
        ],
      ),
    );
  }

  Widget _imageFor(VisualAsset asset) {
    final url = asset.url!;
    final bytes = decodeSlideImageBytes(url);
    if (bytes != null) {
      return Image.memory(
        bytes,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => const _QuietVisual(
          kicker: 'SYNTRA',
          icon: Icons.broken_image_outlined,
          color: SyntraPalette.amber,
        ),
      );
    }
    return Image.network(
      url,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => const _QuietVisual(
        kicker: 'SYNTRA',
        icon: Icons.broken_image_outlined,
        color: SyntraPalette.amber,
      ),
    );
  }
}

Uint8List? decodeSlideImageBytes(String url) {
  if (!url.startsWith('data:')) return null;
  final comma = url.indexOf(',');
  if (comma < 0) return null;
  try {
    return base64Decode(url.substring(comma + 1));
  } catch (_) {
    return null;
  }
}

class _QuietVisual extends StatelessWidget {
  const _QuietVisual({
    required this.kicker,
    required this.icon,
    required this.color,
  });

  final String kicker;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 28, color: color),
            const SizedBox(height: 10),
            Text(
              kicker.toUpperCase(),
              style: SyntraTheme.sans(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EquationVisual extends StatelessWidget {
  const _EquationVisual({required this.equation});

  final String equation;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: SyntraPalette.undergraduate.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: SyntraPalette.undergraduate.withValues(alpha: 0.22),
        ),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            equation,
            textAlign: TextAlign.center,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: SyntraTheme.sans(
              color: SyntraPalette.navy,
              fontSize: 22,
              height: 1.25,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

class _DiagramVisual extends StatelessWidget {
  const _DiagramVisual({this.spec, required this.description});

  final DiagramSpec? spec;
  final String description;

  @override
  Widget build(BuildContext context) {
    final concepts = spec?.concepts ?? const <String>[];
    return DecoratedBox(
      decoration: BoxDecoration(
        color: SyntraPalette.voidMid,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: SyntraPalette.stroke),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              (spec?.diagramType.isNotEmpty == true
                      ? spec!.diagramType
                      : 'Diagram')
                  .toUpperCase(),
              style: SyntraTheme.sans(
                color: SyntraPalette.sage,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              spec?.subject.isNotEmpty == true
                  ? spec!.subject
                  : 'Labelled relationships',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: SyntraTheme.sans(
                color: SyntraPalette.navy,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: Text(
                (spec?.description.isNotEmpty == true)
                    ? spec!.description
                    : description,
                maxLines: 5,
                overflow: TextOverflow.ellipsis,
                style: SyntraTheme.sans(
                  color: SyntraPalette.inkMuted,
                  fontSize: 12,
                  height: 1.3,
                ),
              ),
            ),
            if (concepts.isNotEmpty)
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final concept in concepts.take(4))
                    _MetaChip(label: concept, color: SyntraPalette.sage),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _SpecVisual extends StatelessWidget {
  const _SpecVisual({required this.slide, required this.accent});

  final Slide slide;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return _QuietVisual(
      kicker: 'SYNTRA',
      icon: _iconFor(slide.visualType),
      color: accent,
    );
  }
}

class _FooterNav extends StatelessWidget {
  const _FooterNav({
    required this.label,
    required this.icon,
    required this.leading,
    required this.onPressed,
    required this.accent,
  });

  final String label;
  final IconData icon;
  final bool leading;
  final VoidCallback? onPressed;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final color = enabled ? accent : SyntraPalette.inkFaint;
    final children = [
      Icon(icon, size: 22, color: color),
      const SizedBox(width: 4),
      Text(
        label,
        style: SyntraTheme.sans(
          color: color,
          fontSize: 13,
          fontWeight: FontWeight.w800,
        ),
      ),
    ];
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(999),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: leading ? children : children.reversed.toList(),
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: SyntraTheme.sans(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

String? figureCaption(Slide slide) {
  if (!slide.hasVisual) return null;
  final subject = slide.diagramSpec?.subject.trim() ?? '';
  final description = slide.visualDescription.trim();
  final detail = subject.isNotEmpty
      ? subject
      : (description.isNotEmpty ? description : slide.visualLabel);
  if (detail.isEmpty) return null;
  return 'Fig ${slide.number}  $detail';
}

IconData _iconFor(String visualType) {
  switch (visualType) {
    case 'ai_generated':
    case 'image':
      return Icons.image_outlined;
    case 'graph':
      return Icons.show_chart_rounded;
    case 'timeline':
      return Icons.timeline_rounded;
    case 'comparison':
      return Icons.view_column_outlined;
    case 'flowchart':
      return Icons.account_tree_outlined;
    case 'interactive':
      return Icons.touch_app_outlined;
    case 'equation':
      return Icons.functions_rounded;
    default:
      return Icons.auto_awesome_outlined;
  }
}

Color difficultyColor(String difficulty) {
  switch (difficulty) {
    case 'foundation':
      return SyntraPalette.sage;
    case 'developing':
      return SyntraPalette.beginner;
    case 'intermediate':
      return SyntraPalette.amber;
    case 'advanced':
      return SyntraPalette.rust;
    case 'exam_application':
      return SyntraPalette.violet;
    default:
      return SyntraPalette.inkMuted;
  }
}
