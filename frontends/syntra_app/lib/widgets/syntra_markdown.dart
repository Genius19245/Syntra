import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../theme/syntra_palette.dart';
import '../theme/syntra_theme.dart';
import 'syntra_math.dart';

export 'live_draft.dart';

abstract final class SyntraMarkdown {
  static MarkdownStyleSheet styleSheet(Color accent) {
    final body = SyntraTheme.serif(
      color: SyntraPalette.ink,
      fontSize: 16,
      height: 1.55,
    );
    final muted = SyntraTheme.serif(
      color: SyntraPalette.inkMuted,
      fontSize: 16,
      height: 1.55,
    );

    return MarkdownStyleSheet(
      p: muted,
      pPadding: const EdgeInsets.only(bottom: 12),
      blockSpacing: 12,
      h1: SyntraTheme.serif(
        color: SyntraPalette.ink,
        fontSize: 28,
        height: 1.2,
        fontWeight: FontWeight.w600,
      ),
      h1Padding: const EdgeInsets.only(top: 8, bottom: 12),
      h2: SyntraTheme.sans(
        color: SyntraPalette.ink,
        fontSize: 20,
        height: 1.3,
        fontWeight: FontWeight.w700,
      ),
      h2Padding: const EdgeInsets.only(top: 18, bottom: 8),
      h3: SyntraTheme.sans(
        color: accent,
        fontSize: 15,
        height: 1.35,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.2,
      ),
      h3Padding: const EdgeInsets.only(top: 16, bottom: 8),
      h4: SyntraTheme.sans(
        color: SyntraPalette.ink,
        fontSize: 14,
        height: 1.35,
        fontWeight: FontWeight.w700,
      ),
      h4Padding: const EdgeInsets.only(top: 12, bottom: 6),
      h5: SyntraTheme.sans(
        color: SyntraPalette.inkMuted,
        fontSize: 13,
        height: 1.35,
        fontWeight: FontWeight.w700,
      ),
      h6: SyntraTheme.sans(
        color: SyntraPalette.inkFaint,
        fontSize: 12,
        height: 1.35,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.6,
      ),
      strong: body.copyWith(
        color: SyntraPalette.ink,
        fontWeight: FontWeight.w700,
      ),
      em: muted.copyWith(fontStyle: FontStyle.italic),
      listBullet: SyntraTheme.sans(
        color: accent,
        fontSize: 16,
        fontWeight: FontWeight.w700,
      ),
      listIndent: 22,
      listBulletPadding: const EdgeInsets.only(right: 8),
      horizontalRuleDecoration: BoxDecoration(
        border: Border(top: BorderSide(color: SyntraPalette.stroke, width: 1)),
      ),
      blockquote: muted.copyWith(fontStyle: FontStyle.italic),
      blockquoteDecoration: BoxDecoration(
        color: SyntraPalette.voidMid.withValues(alpha: 0.55),
        border: Border(left: BorderSide(color: accent, width: 3)),
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(10),
          bottomRight: Radius.circular(10),
        ),
      ),
      blockquotePadding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      code: SyntraTheme.sans(color: accent, fontSize: 13, height: 1.4),
      codeblockDecoration: BoxDecoration(
        color: SyntraPalette.voidMid,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: SyntraPalette.stroke),
      ),
      codeblockPadding: const EdgeInsets.all(14),
      tableHead: SyntraTheme.sans(
        color: SyntraPalette.ink,
        fontSize: 13,
        fontWeight: FontWeight.w700,
      ),
      tableBody: SyntraTheme.serif(
        color: SyntraPalette.inkMuted,
        fontSize: 14,
        height: 1.4,
      ),
      tableBorder: TableBorder.all(color: SyntraPalette.stroke, width: 1),
      tableHeadAlign: TextAlign.left,
      tableCellsPadding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 8,
      ),
      a: muted.copyWith(color: accent, decoration: TextDecoration.underline),
    );
  }
}

class SyntraMarkdownView extends StatelessWidget {
  const SyntraMarkdownView({
    super.key,
    required this.data,
    required this.accent,
    this.selectable = true,
    this.shrinkWrap = false,
    this.padding = EdgeInsets.zero,
  });

  final String data;
  final Color accent;
  final bool selectable;
  final bool shrinkWrap;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final sheet = SyntraMarkdown.styleSheet(accent);
    final rendered = polishPlainMath(data);
    final builders = syntraLatexBuilders(color: SyntraPalette.ink);
    final inlines = syntraLatexInlineSyntaxes();
    final blocks = syntraLatexBlockSyntaxes();
    if (shrinkWrap) {
      return MarkdownBody(
        data: rendered,
        selectable: selectable,
        styleSheet: sheet,
        builders: builders,
        inlineSyntaxes: inlines,
        blockSyntaxes: blocks,
        fitContent: true,
      );
    }
    return Markdown(
      data: rendered,
      selectable: selectable,
      padding: padding,
      styleSheet: sheet,
      builders: builders,
      inlineSyntaxes: inlines,
      blockSyntaxes: blocks,
    );
  }
}
