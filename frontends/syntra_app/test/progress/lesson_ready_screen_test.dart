import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syntra_app/data/intake_catalog.dart';
import 'package:syntra_app/models/learner_brief.dart';
import 'package:syntra_app/models/research_origin.dart';
import 'package:syntra_app/progress/models.dart';
import 'package:syntra_app/screens/result/lesson_ready_screen.dart';

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
      "difficulty": "foundation"
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

  PipelineTexts pipeline() {
    return PipelineTexts(
      curriculum: _curriculum,
      lessonPlan: _planJson,
      slides: _deckJson,
    );
  }

  Future<void> pumpReady(
    WidgetTester tester, {
    bool fromHistory = false,
    ResearchOrigin? origin,
  }) async {
    tester.view.physicalSize = const Size(1280, 960);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: LessonReadyScreen(
          brief: brief(),
          markdown: _curriculum,
          origin: origin,
          fromHistory: fromHistory,
          pipeline: pipeline(),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('shows summary stats from the generated pack', (tester) async {
    await pumpReady(
      tester,
      origin: const ResearchOrigin(ragUsed: true),
    );

    expect(find.text('Lesson Ready!'), findsOneWidget);
    expect(find.text('Electromagnetic induction'), findsOneWidget);
    expect(find.text('Physics'), findsOneWidget);
    expect(find.text('GCSE'), findsOneWidget);
    expect(find.text('1 step'), findsOneWidget);
    expect(find.text('6 min'), findsOneWidget);
    expect(find.textContaining('CACHE'), findsOneWidget);
    expect(find.text('View Lesson'), findsOneWidget);
    expect(find.byKey(const ValueKey('lesson-ready-history')), findsOneWidget);
    expect(find.byKey(const ValueKey('lesson-ready-new')), findsOneWidget);
    expect(find.text('TEACHING PACK'), findsNothing);
  });

  testWidgets('View Lesson opens the curriculum workspace', (tester) async {
    await pumpReady(tester);

    await tester.tap(find.byKey(const ValueKey('lesson-ready-view')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('TEACHING PACK'), findsOneWidget);
    expect(find.text('A changing field induces an EMF'), findsOneWidget);
    expect(find.text('Lesson Ready!'), findsOneWidget);
  });

  testWidgets('Past lessons opens history', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await pumpReady(tester);

    await tester.tap(find.byKey(const ValueKey('lesson-ready-history')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(
      find.textContaining('Opening a lesson does not run the pipeline again'),
      findsOneWidget,
    );
  });

  testWidgets('New brief pops back to the first route', (tester) async {
    tester.view.physicalSize = const Size(1280, 960);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: TextButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => LessonReadyScreen(
                        brief: brief(),
                        markdown: _curriculum,
                        pipeline: pipeline(),
                      ),
                    ),
                  );
                },
                child: const Text('open ready'),
              ),
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('open ready'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('Lesson Ready!'), findsOneWidget);

    final newBrief = find.byKey(const ValueKey('lesson-ready-new'));
    await tester.ensureVisible(newBrief);
    await tester.tap(newBrief);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('open ready'), findsOneWidget);
    expect(find.text('Lesson Ready!'), findsNothing);
  });
}
