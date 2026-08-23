import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:syntra_app/progress/models.dart';
import 'package:syntra_app/progress/slide_deck.dart';
import 'package:syntra_app/progress/slide_panel.dart';

const _deckJson = '''
{
  "lesson_title": "Electromagnetic induction",
  "slides": [
    {
      "slide_number": 1,
      "title": "A changing field induces an EMF",
      "purpose": "Name the phenomenon before the formula.",
      "content": [
        "A changing magnetic field can induce an EMF.",
        "The size of the EMF depends on how fast the flux changes."
      ],
      "visual_type": "ai_generated",
      "visual_description": "Coil and magnet moving together.",
      "visual_asset": {
        "prompt": "Educational cross-sectional illustration of a coil and a moving bar magnet, GCSE physics, no labels or equations.",
        "aspect_ratio": "16:9",
        "educational_purpose": "Visualise electromagnetic induction as a magnet moves through a coil"
      },
      "equation": null,
      "teacher_explanation": "Hold up a coil and a magnet. Move one.",
      "interaction": "Demo",
      "estimated_minutes": 3,
      "difficulty": "foundation"
    },
    {
      "slide_number": 2,
      "title": "Faraday's law",
      "purpose": "Write the relationship.",
      "content": ["EMF is the rate of change of flux."],
      "visual_type": "equation",
      "visual_description": "",
      "equation": {
        "equation": "E = - dNΦ / dt",
        "format": "latex"
      },
      "teacher_explanation": "Point at N, then at the d/dt.",
      "interaction": null,
      "estimated_minutes": 4,
      "difficulty": "intermediate",
      "diagram_spec": null
    }
  ]
}
''';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  test('parses the slide agent visual_asset schema', () {
    final deck = SlideDeck.tryParse(_deckJson);
    expect(deck, isNotNull);
    expect(deck!.lessonTitle, 'Electromagnetic induction');
    expect(deck.slides, hasLength(2));
    expect(deck.totalMinutes, 7);

    final first = deck.slides.first;
    expect(first.title, 'A changing field induces an EMF');
    expect(first.content, hasLength(2));
    expect(first.visualType, 'ai_generated');
    expect(first.visualAsset?.prompt, contains('no labels or equations'));
    expect(first.visualAsset?.aspectRatio, '16:9');
    expect(
      first.visualAsset?.educationalPurpose,
      contains('electromagnetic induction'),
    );
    expect(first.visualAsset?.ready, isFalse);
    expect(first.interaction, 'Demo');

    final second = deck.slides.last;
    expect(second.equation, 'E = - dNΦ / dt');
    expect(second.difficulty, 'intermediate');
    expect(second.visualType, 'equation');
  });

  test('rendering layer can attach a stored url later', () {
    const raw = '''
{"slides":[{"slide_number":1,"title":"Osmosis","content":["Water moves"],"visual_type":"ai_generated","visual_asset":{"prompt":"cell membrane illustration","educational_purpose":"Show water moving across a membrane","aspect_ratio":"16:9","url":"https://example.test/osmosis.png"}}]}
''';
    final slide = SlideDeck.tryParse(raw)!.slides.single;
    expect(slide.visualType, 'ai_generated');
    expect(slide.visualAsset?.ready, isTrue);
    expect(slide.visualAsset?.url, 'https://example.test/osmosis.png');
  });

  test('parses visual_asset when only a url is present', () {
    const raw = '''
{"slides":[{"title":"Osmosis","visual_type":"ai_generated","visual_asset":{"url":"data:image/png;base64,AAAA"}}]}
''';
    final slide = SlideDeck.tryParse(raw)!.slides.single;
    expect(slide.visualAsset?.url, 'data:image/png;base64,AAAA');
    expect(slide.visualAsset?.ready, isTrue);
  });

  test('maps legacy image / image_asset keys', () {
    const raw = '''
{"slides":[{"title":"Old","visual_type":"image","image_asset":{"prompt":"coil","educational_purpose":"show a coil"}}]}
''';
    final slide = SlideDeck.tryParse(raw)!.slides.single;
    expect(slide.visualType, 'ai_generated');
    expect(slide.visualAsset?.prompt, 'coil');
  });

  test('returns null for empty or non-slide JSON', () {
    expect(SlideDeck.tryParse(''), isNull);
    expect(SlideDeck.tryParse('{"lesson_sequence":[]}'), isNull);
    expect(SlideDeck.tryParse('{"slides":[]}'), isNull);
  });

  test('PipelineTexts still reads the slide agent author key', () {
    final texts = PipelineTexts.fromAuthors({
      'slide_agent': _deckJson,
      'curriculum_agent': 'curriculum here',
    });
    expect(texts.slides, _deckJson);
    expect(SlideDeck.tryParse(texts.slides)?.slides, hasLength(2));
  });

  testWidgets('renders a classroom slide from agent JSON', (tester) async {
    final deck = SlideDeck.tryParse(_deckJson)!;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 720,
            width: 980,
            child: SlidePanel(deck: deck),
          ),
        ),
      ),
    );

    expect(find.text('A changing field induces an EMF'), findsOneWidget);
    expect(find.textContaining('changing magnetic field'), findsOneWidget);
    expect(
      find.text(
        'Visualise electromagnetic induction as a magnet moves through a coil',
      ),
      findsNothing,
    );
    expect(
      find.textContaining(
        'Educational cross-sectional illustration of a coil',
      ),
      findsNothing,
    );
    expect(find.text('SYNTRA'), findsOneWidget);
    expect(find.textContaining('Say this'), findsNothing);
    expect(find.text('Hold up a coil and a magnet. Move one.'), findsNothing);
    expect(find.text('Name the phenomenon before the formula.'), findsNothing);
    expect(find.text('Slide 1 / 2'), findsOneWidget);
    expect(find.textContaining('Fig 1'), findsOneWidget);
    expect(find.textContaining('Coil and magnet moving together'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.chevron_right_rounded));
    await tester.pump();

    expect(find.text("Faraday's law"), findsOneWidget);
    expect(find.text('E = - dNΦ / dt'), findsOneWidget);
    expect(find.text('Slide 2 / 2'), findsOneWidget);
  });
}
