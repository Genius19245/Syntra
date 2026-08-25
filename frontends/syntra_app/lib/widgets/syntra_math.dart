import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:markdown/markdown.dart' as md;

/// Classroom TeX → readable Unicode when [Math.tex] cannot paint.
///
/// Covers the live-workspace cases teachers actually see: Greek letters,
/// `\sin`/`\cos`, subscripts, superscripts, and `\frac{a}{b}`.
String texToPlain(String tex) {
  var s = _unescapeHtml(tex.trim());
  if (s.isEmpty) return s;

  final frac = RegExp(r'\\frac\s*\{([^{}]+)\}\{([^{}]+)\}');
  while (frac.hasMatch(s)) {
    s = s.replaceAllMapped(frac, (match) {
      final num = _scripts(match.group(1)!);
      final den = _scripts(match.group(2)!);
      final wrapNum = _needsParens(num) ? '($num)' : num;
      final wrapDen = _needsParens(den) ? '($den)' : den;
      return '$wrapNum/$wrapDen';
    });
  }

  s = s.replaceAllMapped(RegExp(r'\\([a-zA-Z]+)'), (match) {
    return _texCommands[match.group(1)!] ?? match.group(1)!;
  });
  s = s.replaceAllMapped(RegExp(r'\\[,;:! ]'), (_) => ' ');
  s = s.replaceAll(r'\left', '');
  s = s.replaceAll(r'\right', '');
  s = _scripts(s);
  s = s.replaceAll('{', '').replaceAll('}', '');
  return s.replaceAll(RegExp(r'[ \t]+'), ' ').trim();
}

/// Turns `v >= 0` into `v ≥ 0` outside math spans; leaves `$...$` alone.
String polishPlainMath(String input) {
  final buf = StringBuffer();
  var index = 0;
  for (final match in _mathSpan.allMatches(input)) {
    buf.write(_plainOperators(input.substring(index, match.start)));
    buf.write(match[0]);
    index = match.end;
  }
  buf.write(_plainOperators(input.substring(index)));
  return buf.toString();
}

List<md.InlineSyntax> syntraLatexInlineSyntaxes() => [
  _DollarDisplaySyntax(),
  _DollarInlineSyntax(),
  _ParenLatexSyntax(),
];

List<md.BlockSyntax> syntraLatexBlockSyntaxes() => [SyntraLatexBlockSyntax()];

Map<String, MarkdownElementBuilder> syntraLatexBuilders({Color? color}) => {
  'latex': SyntraLatexBuilder(display: false, color: color),
  'latex-block': SyntraLatexBuilder(display: true, color: color),
};

class SyntraLatexBuilder extends MarkdownElementBuilder {
  SyntraLatexBuilder({required this.display, this.color});

  final bool display;
  final Color? color;

  @override
  bool isBlockElement() => display;

  @override
  Widget visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    final style = (preferredStyle ?? parentStyle ?? const TextStyle()).copyWith(
      color: color ?? preferredStyle?.color ?? parentStyle?.color,
    );
    final asDisplay = display || element.attributes['display'] == 'true';
    return SyntraMath(
      tex: element.textContent,
      display: asDisplay,
      style: style,
    );
  }
}

/// Renders TeX with [Math.tex], falling back to Unicode so `$` never leaks.
class SyntraMath extends StatelessWidget {
  const SyntraMath({
    super.key,
    required this.tex,
    this.display = false,
    this.style,
  });

  final String tex;
  final bool display;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final cleaned = _unescapeHtml(tex.trim());
    final fallbackStyle = style ?? DefaultTextStyle.of(context).style;
    final math = Math.tex(
      cleaned,
      mathStyle: display ? MathStyle.display : MathStyle.text,
      textStyle: fallbackStyle,
      onErrorFallback: (_) => Text(texToPlain(cleaned), style: fallbackStyle),
    );

    if (!display) return math;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: math,
        ),
      ),
    );
  }
}

class SyntraLatexBlockSyntax extends md.BlockSyntax {
  static final _singleLine = RegExp(r'^(?:\$\$(.+)\$\$|\\\[(.+)\\\])\s*$');

  @override
  RegExp get pattern => RegExp(r'^(\$\$|\\\[)');

  @override
  bool canParse(md.BlockParser parser) {
    final line = parser.current.content.trim();
    return line.startsWith(r'$$') || line.startsWith(r'\[');
  }

  @override
  md.Node parse(md.BlockParser parser) {
    final line = parser.current.content.trim();
    parser.advance();

    final single = _singleLine.firstMatch(line);
    if (single != null) {
      final tex = (single.group(1) ?? single.group(2) ?? '').trim();
      return md.Element.text('latex-block', tex);
    }

    final closer = line.startsWith(r'$$') ? r'$$' : r'\]';
    final buf = StringBuffer();
    if (line.startsWith(r'$$') && line.length > 2) {
      buf.writeln(line.substring(2));
    } else if (line.startsWith(r'\[') && line.length > 2) {
      buf.writeln(line.substring(2));
    }

    while (!parser.isDone) {
      final current = parser.current.content;
      parser.advance();
      final trimmed = current.trim();
      if (trimmed == closer || trimmed.endsWith(closer)) {
        if (trimmed != closer) {
          buf.write(trimmed.substring(0, trimmed.length - closer.length));
        }
        break;
      }
      buf.writeln(current);
    }

    return md.Element.text('latex-block', buf.toString().trim());
  }
}

class _DollarDisplaySyntax extends md.InlineSyntax {
  _DollarDisplaySyntax() : super(r'\$\$([^$]+?)\$\$', startCharacter: 36);

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    parser.addNode(
      md.Element.text('latex', match[1]!.trim())
        ..attributes['display'] = 'true',
    );
    return true;
  }
}

class _DollarInlineSyntax extends md.InlineSyntax {
  _DollarInlineSyntax() : super(r'\$([^$\n]+?)\$', startCharacter: 36);

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    parser.addNode(md.Element.text('latex', match[1]!.trim()));
    return true;
  }
}

class _ParenLatexSyntax extends md.InlineSyntax {
  _ParenLatexSyntax()
    : super(r'\\\[(.+?)\\\]|\\\((.+?)\\\)', startCharacter: 92);

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final display = match[1] != null;
    final tex = (match[1] ?? match[2] ?? '').trim();
    final element = md.Element.text('latex', tex);
    if (display) element.attributes['display'] = 'true';
    parser.addNode(element);
    return true;
  }
}

final _mathSpan = RegExp(
  r'\$\$[\s\S]+?\$\$|\\\[[\s\S]+?\\\]|\$[^$\n]+?\$|\\\(.+?\\\)',
);

String _plainOperators(String text) {
  return text
      .replaceAll('>=', '≥')
      .replaceAll('<=', '≤')
      .replaceAll('!=', '≠')
      .replaceAll(' -> ', ' → ');
}

String _unescapeHtml(String value) {
  return value
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'");
}

bool _needsParens(String value) =>
    value.contains('+') || value.contains('-') || value.contains(' ');

String _scripts(String input) {
  var s = input;
  s = s.replaceAllMapped(RegExp(r'\^\{([^{}]+)\}'), (match) {
    return match.group(1)!.split('').map(_sup).join();
  });
  s = s.replaceAllMapped(RegExp(r'_\{([^{}]+)\}'), (match) {
    return match.group(1)!.split('').map(_sub).join();
  });
  s = s.replaceAllMapped(RegExp(r'\^([A-Za-z0-9+\-])'), (match) {
    return _sup(match.group(1)!);
  });
  s = s.replaceAllMapped(RegExp(r'_([A-Za-z0-9+\-])'), (match) {
    return _sub(match.group(1)!);
  });
  return s;
}

String _sup(String char) => _superscripts[char] ?? char;

String _sub(String char) => _subscripts[char] ?? char;

const _texCommands = {
  'alpha': 'α',
  'beta': 'β',
  'gamma': 'γ',
  'delta': 'δ',
  'epsilon': 'ε',
  'varepsilon': 'ε',
  'zeta': 'ζ',
  'eta': 'η',
  'theta': 'θ',
  'vartheta': 'ϑ',
  'iota': 'ι',
  'kappa': 'κ',
  'lambda': 'λ',
  'mu': 'μ',
  'nu': 'ν',
  'xi': 'ξ',
  'pi': 'π',
  'rho': 'ρ',
  'sigma': 'σ',
  'tau': 'τ',
  'upsilon': 'υ',
  'phi': 'φ',
  'varphi': 'φ',
  'chi': 'χ',
  'psi': 'ψ',
  'omega': 'ω',
  'Gamma': 'Γ',
  'Delta': 'Δ',
  'Theta': 'Θ',
  'Lambda': 'Λ',
  'Xi': 'Ξ',
  'Pi': 'Π',
  'Sigma': 'Σ',
  'Phi': 'Φ',
  'Psi': 'Ψ',
  'Omega': 'Ω',
  'sin': 'sin',
  'cos': 'cos',
  'tan': 'tan',
  'cot': 'cot',
  'sec': 'sec',
  'csc': 'csc',
  'log': 'log',
  'ln': 'ln',
  'exp': 'exp',
  'lim': 'lim',
  'min': 'min',
  'max': 'max',
  'cdot': '·',
  'times': '×',
  'div': '÷',
  'pm': '±',
  'mp': '∓',
  'leq': '≤',
  'geq': '≥',
  'neq': '≠',
  'approx': '≈',
  'equiv': '≡',
  'infty': '∞',
  'to': '→',
  'rightarrow': '→',
  'leftarrow': '←',
  'circ': '°',
  'degree': '°',
  'ell': 'ℓ',
  'hbar': 'ℏ',
  'partial': '∂',
  'nabla': '∇',
  'sum': '∑',
  'prod': '∏',
  'int': '∫',
  'mathrm': '',
  'mathbf': '',
  'mathit': '',
  'textrm': '',
  'text': '',
  'quad': '  ',
  'qquad': '   ',
};

const _superscripts = {
  '0': '⁰',
  '1': '¹',
  '2': '²',
  '3': '³',
  '4': '⁴',
  '5': '⁵',
  '6': '⁶',
  '7': '⁷',
  '8': '⁸',
  '9': '⁹',
  '+': '⁺',
  '-': '⁻',
  'n': 'ⁿ',
  'i': 'ⁱ',
};

const _subscripts = {
  '0': '₀',
  '1': '₁',
  '2': '₂',
  '3': '₃',
  '4': '₄',
  '5': '₅',
  '6': '₆',
  '7': '₇',
  '8': '₈',
  '9': '₉',
  '+': '₊',
  '-': '₋',
  'n': 'ₙ',
  'i': 'ᵢ',
  'j': 'ⱼ',
  'k': 'ₖ',
  't': 'ₜ',
};
