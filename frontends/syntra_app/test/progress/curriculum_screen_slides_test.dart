import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:syntra_app/data/intake_catalog.dart';
import 'package:syntra_app/models/learner_brief.dart';
import 'package:syntra_app/progress/models.dart';
import 'package:syntra_app/screens/result/curriculum_screen.dart';

const _planJson = '''
{
  "lesson_sequence": [
    {
      "step": 1,
      "title": "Activate prior knowledge",
      "purpose": "Remind the class what a magnetic field is.",
      "concepts": ["magnetic field"],
      "activity": "Show a compass near a bar magnet.",
      "depends_on": [],
      "estimated_minutes": 6,
      "difficulty": "foundation"
    }
  ]
}
''';

const _deckJson = '''
{
  "lesson_title": "Electromagnetic induction",
  "slides": [
    {
      "slide_number": 1,
      "title": "A changing field induces an EMF",
      "purpose": "Name the phenomenon.",
      "content": ["A changing magnetic field can induce an EMF."],
      "visual_type": "ai_generated",
      "visual_asset": {
        "prompt": "coil and magnet",
        "aspect_ratio": "16:9",
        "educational_purpose": "Visualise induction"
      },
      "teacher_explanation": "Move the magnet.",
      "difficulty": "foundation"
    },
    {
      "slide_number": 2,
      "title": "Faraday's law",
      "purpose": "Write the relationship.",
      "content": ["EMF is the rate of change of flux."],
      "visual_type": "equation",
      "equation": {"equation": "E = - dNΦ / dt"},
      "teacher_explanation": "Point at N.",
      "difficulty": "intermediate"
    }
  ]
}
''';

const _curriculum = '''
# Curriculum Plan

## Learner Profile
- Level: GCSE
- Subject: Physics
- Topic: Electromagnetic induction
''';

const _objectives = '''
# Learning Objectives

## Objectives

1. Explain how a changing magnetic flux produces an induced electromotive force.
2. Calculate the induced EMF for a given rate of change of flux.
''';

const _prereqs = '''
# Prerequisite Analysis

## Learner Knowledge

### Missing
- Magnetic flux and flux density
''';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  LearnerBrief brief() {
    return LearnerBrief()
      ..selectLevel(IntakeCatalog.levelById('GCSE'))
      ..selectBoard('AQA')
      ..selectSubject('Physics')
      ..setTopic('Electromagnetic induction');
  }

  PipelineTexts pipeline({
    String? slides,
    String? explanation,
    String? example,
  }) {
    return PipelineTexts(
      curriculum: _curriculum,
      learningObjectives: _objectives,
      prerequisiteAnalysis: _prereqs,
      lessonPlan: _planJson,
      slides: slides,
      explanation: explanation,
      example: example,
    );
  }

  Future<void> pumpResult(
    WidgetTester tester, {
    String? slides,
    String? explanation,
    String? example,
  }) async {
    tester.view.physicalSize = const Size(1280, 960);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: CurriculumScreen(
          brief: brief(),
          markdown: _curriculum,
          pipeline: pipeline(
            slides: slides,
            explanation: explanation,
            example: example,
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('presenter stage keeps the topic once; rail opens Notes by default',
      (tester) async {
    await pumpResult(tester, slides: _deckJson);

    expect(find.text('TEACHING PACK'), findsOneWidget);
    expect(find.text('Electromagnetic induction'), findsOneWidget);
    expect(find.text('Physics'), findsOneWidget);
    expect(find.text('AQA'), findsOneWidget);
    expect(find.text('A changing field induces an EMF'), findsOneWidget);
    expect(find.text('Slide 1 / 2'), findsOneWidget);
    expect(find.text('SAY THIS'), findsOneWidget);
    expect(find.text('Move the magnet.'), findsOneWidget);
    expect(
      find.text(
        'Explain how a changing magnetic flux produces an induced electromotive force.',
      ),
      findsNothing,
    );
    expect(find.text('Activate prior knowledge'), findsNothing);
    expect(find.text('Name the phenomenon.'), findsNothing);
  });

  testWidgets('rail tap shows Objectives without duplicating the topic title',
      (tester) async {
    await pumpResult(tester, slides: _deckJson);

    await tester.tap(find.byKey(const ValueKey('teaching-pack-objectives')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('Electromagnetic induction'), findsOneWidget);
    expect(
      find.text(
        'Explain how a changing magnetic flux produces an induced electromotive force.',
      ),
      findsOneWidget,
    );
    expect(find.text('Magnetic flux and flux density'), findsOneWidget);
    expect(find.text('Move the magnet.'), findsNothing);
    expect(find.text('A changing field induces an EMF'), findsOneWidget);
  });

  testWidgets('arrows still change the slide title and Notes follows the slide',
      (tester) async {
    await pumpResult(tester, slides: _deckJson);

    expect(find.text('Move the magnet.'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.chevron_right_rounded));
    await tester.pump();

    expect(find.text("Faraday's law"), findsOneWidget);
    expect(find.text('Slide 2 / 2'), findsOneWidget);
    expect(find.text('Point at N.'), findsOneWidget);
    expect(find.text('Move the magnet.'), findsNothing);
    expect(find.text('Electromagnetic induction'), findsOneWidget);
    expect(find.text('Physics'), findsOneWidget);
  });

  testWidgets('Sequence tap puts the plan on the stage instead of slides',
      (tester) async {
    await pumpResult(tester, slides: _deckJson);

    await tester.tap(find.byKey(const ValueKey('teaching-pack-sequence')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('Activate prior knowledge'), findsOneWidget);
    expect(find.textContaining('6 min'), findsWidgets);
    expect(find.text('Electromagnetic induction'), findsOneWidget);
    expect(find.textContaining('Sequence is on the board'), findsOneWidget);
    expect(find.text('A changing field induces an EMF'), findsNothing);
    expect(find.text('Slide 1 / 2'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('teaching-pack-objectives')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('Slide 1 / 2'), findsOneWidget);
    expect(find.text('A changing field induces an EMF'), findsOneWidget);
    expect(find.text('Activate prior knowledge'), findsNothing);
  });

  testWidgets('leaving Sequence restores the last slide index', (tester) async {
    await pumpResult(tester, slides: _deckJson);

    await tester.tap(find.byIcon(Icons.chevron_right_rounded));
    await tester.pump();
    expect(find.text("Faraday's law"), findsOneWidget);
    expect(find.text('Slide 2 / 2'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('teaching-pack-sequence')));
    await tester.pump();
    expect(find.text('Slide 2 / 2'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('teaching-pack-notes')));
    await tester.pump();

    expect(find.text("Faraday's law"), findsOneWidget);
    expect(find.text('Slide 2 / 2'), findsOneWidget);
    expect(find.text('Point at N.'), findsOneWidget);
  });

  testWidgets('hides the slide board when slides JSON is missing',
      (tester) async {
    await pumpResult(tester);

    expect(find.text('Activate prior knowledge'), findsOneWidget);
    expect(find.text('Electromagnetic induction'), findsOneWidget);
    expect(find.text('Objectives'), findsOneWidget);
    expect(
      find.text(
        'Explain how a changing magnetic flux produces an induced electromotive force.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('Slide '), findsNothing);
    expect(find.byIcon(Icons.chevron_right_rounded), findsNothing);
    expect(find.text('Notes'), findsNothing);
    expect(find.text('Teach'), findsOneWidget);
  });

  testWidgets('narrow width puts teaching-pack chips above the stage',
      (tester) async {
    tester.view.physicalSize = const Size(720, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: CurriculumScreen(
          brief: brief(),
          markdown: _curriculum,
          pipeline: pipeline(slides: _deckJson),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('TEACHING PACK'), findsNothing);
    expect(find.byKey(const ValueKey('teaching-pack-chip-Notes')), findsOneWidget);
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('teaching-pack-chip-Notes'))).dy,
      lessThan(tester.getTopLeft(find.text('Slide 1 / 2')).dy),
    );

    await tester.tap(find.byKey(const ValueKey('teaching-pack-chip-Objectives')));
    await tester.pump();
    expect(
      find.text(
        'Explain how a changing magnetic flux produces an induced electromotive force.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('teaching-pack-chip-Sequence')));
    await tester.pump();
    expect(find.text('Activate prior knowledge'), findsOneWidget);
    expect(find.text('Slide 1 / 2'), findsNothing);
    expect(find.text('A changing field induces an EMF'), findsNothing);
  });

  testWidgets('Teach tab shows specialist outputs without extra agent calls',
      (tester) async {
    await pumpResult(
      tester,
      slides: _deckJson,
      explanation: '# Explanation\n\nFlux is how much field passes through a surface.',
      example: '# Example\n\nMove a magnet through a coil.',
    );

    expect(find.text('Teach'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('teaching-pack-teach')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 450));

    expect(find.text('STUDIO'), findsOneWidget);
    expect(find.text('ON THE BOARD'), findsOneWidget);
    expect(find.text('Open studio'), findsOneWidget);
    expect(find.byKey(const ValueKey('teach-studio-body')), findsOneWidget);
    expect(
      find.textContaining('Flux is how much field passes through a surface.'),
      findsOneWidget,
    );
    expect(find.text('Move the magnet.'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('teach-studio-tab-example')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 450));
    expect(
      find.textContaining('Move a magnet through a coil.'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('teaching-pack-open-studio')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.byKey(const ValueKey('teach-screen')), findsOneWidget);
    expect(find.text('Teaching Studio'), findsOneWidget);
    expect(
      find.textContaining('Flux is how much field passes through a surface.'),
      findsWidgets,
    );
  });
}
