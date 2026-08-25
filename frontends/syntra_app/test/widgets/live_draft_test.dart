import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:syntra_app/theme/syntra_palette.dart';
import 'package:syntra_app/widgets/live_draft.dart';
import 'package:syntra_app/widgets/syntra_math.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  group('tryParseLiveJson', () {
    test('parses a research package object', () {
      const raw = '''
{
  "topic": "Forces",
  "misconceptions": ["Heavier objects fall faster"]
}
''';
      final parsed = tryParseLiveJson(raw) as Map;
      expect(parsed['topic'], 'Forces');
      expect(parsed['misconceptions'], ['Heavier objects fall faster']);
    });

    test('parses fenced json', () {
      const raw = '''
```json
{"topic": "Magnets", "research_method": {"rag_used": true, "web_used": false}}
```
''';
      final parsed = tryParseLiveJson(raw) as Map;
      expect(parsed['topic'], 'Magnets');
    });

    test('returns null for partial JSON mid-stream', () {
      expect(tryParseLiveJson('{"topic": "Forces", "misconcep'), isNull);
      expect(tryParseLiveJson('{'), isNull);
      expect(tryParseLiveJson('```json\n{"topic":'), isNull);
    });

    test('returns null for markdown', () {
      expect(tryParseLiveJson('# Prerequisite Analysis\n- Flux'), isNull);
    });
  });

  group('texToPlain', () {
    test('renders classroom TeX as symbols', () {
      expect(texToPlain(r'\theta'), 'θ');
      expect(texToPlain(r'\sin \theta'), 'sin θ');
      expect(
        texToPlain(r'm_1u_1 + m_2u_2 = m_1v_1 + m_2v_2'),
        'm₁u₁ + m₂u₂ = m₁v₁ + m₂v₂',
      );
      expect(texToPlain(r'a = \frac{v^2}{r}'), 'a = v²/r');
    });
  });

  group('humanizeLiveJsonKey', () {
    test('uses teacher-facing labels', () {
      expect(humanizeLiveJsonKey('misconceptions'), 'Common misconceptions');
      expect(humanizeLiveJsonKey('research_method'), 'How this was researched');
      expect(humanizeLiveJsonKey('key_concepts'), 'Key concepts');
    });
  });

  testWidgets('live JSON research package is sectioned, not dumped', (
    tester,
  ) async {
    const json = '''
{
  "topic": "Forces",
  "subject": "Physics",
  "education_level": "GCSE",
  "exam_board": "AQA",
  "key_concepts": ["Resultant force", "Newton's laws"],
  "misconceptions": [
    "A force is needed to keep an object moving"
  ],
  "sources": [
    {
      "organisation": "AQA",
      "title": "GCSE Physics specification",
      "url": "https://example.com/aqa",
      "source_tier": 1
    }
  ],
  "research_method": {
    "rag_used": true,
    "web_used": false,
    "fact_check_used": true,
    "retrieval_mode": "RAG_ONLY"
  },
  "hit_count": 4
}
''';

    await tester.pumpWidget(
      _harness(SyntraLiveMarkdown(data: json, accent: SyntraPalette.rust)),
    );
    await tester.pump();

    expect(find.text('Forces'), findsOneWidget);
    expect(find.text('Physics'), findsOneWidget);
    expect(find.textContaining('COMMON MISCONCEPTIONS'), findsOneWidget);
    expect(find.textContaining('KEY CONCEPTS'), findsOneWidget);
    expect(find.textContaining('HOW THIS WAS RESEARCHED'), findsOneWidget);
    expect(find.text('Reused from cache'), findsOneWidget);
    expect(find.text('Fact-checked'), findsOneWidget);
    expect(find.textContaining('A force is needed'), findsOneWidget);
    expect(find.textContaining('"misconceptions"'), findsNothing);
    expect(find.textContaining('rag_used'), findsNothing);
  });

  testWidgets('live markdown renders theta without raw dollar delimiters', (
    tester,
  ) async {
    const markdown = r'''
# Prerequisite Analysis

- Resolve a general angle $\theta$
- Use $\sin \theta$ in resolving components
- Momentum: ($m_1u_1 + m_2u_2 = m_1v_1 + m_2v_2$)
- Centripetal: ($a = \frac{v^2}{r}$)
- Speed satisfies v >= 0
''';

    await tester.pumpWidget(
      _harness(SyntraLiveMarkdown(data: markdown, accent: SyntraPalette.rust)),
    );
    await tester.pump();

    expect(find.byType(SyntraMath), findsWidgets);
    expect(find.textContaining(r'$\theta$'), findsNothing);
    expect(find.textContaining(r'$\sin'), findsNothing);
    expect(find.textContaining(r'\frac'), findsNothing);
    expect(find.textContaining('v ≥ 0'), findsOneWidget);
  });

  testWidgets('partial JSON does not crash the live workspace', (tester) async {
    await tester.pumpWidget(
      _harness(
        const SyntraLiveMarkdown(
          data: '{"topic": "Forces", "misconceptions": [',
          accent: SyntraPalette.rust,
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byType(SyntraLiveMarkdown), findsOneWidget);
  });
}

Widget _harness(Widget child) {
  return MaterialApp(
    home: Scaffold(body: SizedBox(width: 480, height: 720, child: child)),
  );
}
