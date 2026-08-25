import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:syntra_app/debug/mock_lesson.dart';
import 'package:syntra_app/progress/lesson_plan.dart';
import 'package:syntra_app/progress/parser.dart';
import 'package:syntra_app/progress/slide_deck.dart';
import 'package:syntra_app/screens/result/curriculum_screen.dart';
import 'package:syntra_app/screens/result/lesson_ready_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  test('mock pack parses as a full teaching pack', () {
    final brief = mockBrief();
    final pipeline = mockPipeline();

    expect(brief.topic, mockTopic);
    expect(brief.levelId, 'GCSE');
    expect(brief.board, 'AQA');
    expect(brief.resolvedSubject, 'Geography');

    final deck = SlideDeck.tryParse(pipeline.slides);
    expect(deck, isNotNull);
    expect(deck!.lessonTitle, mockTopic);
    expect(deck.slides.length, inInclusiveRange(6, 10));
    expect(deck.slides.first.title, 'Coasts are energy, rock, and sediment');
    expect(
      deck.slides.where((slide) => slide.teacherExplanation.isNotEmpty).length,
      greaterThanOrEqualTo(6),
    );
    expect(
      deck.slides.any((slide) => slide.visualType == 'none'),
      isTrue,
    );
    expect(
      deck.slides.any((slide) => slide.equation != null),
      isTrue,
    );
    expect(
      deck.slides.any((slide) => slide.diagramSpec != null),
      isTrue,
    );
    expect(
      deck.slides.any(
        (slide) => slide.visualAsset != null && !slide.visualAsset!.ready,
      ),
      isTrue,
    );

    final plan = LessonPlan.tryParse(pipeline.lessonPlan);
    expect(plan, isNotNull);
    expect(plan!.steps.length, inInclusiveRange(5, 8));
    expect(plan.steps.first.title, contains('coastline'));
    expect(plan.totalMinutes, greaterThan(40));

    final progress = ProgressParser.parse(pipeline);
    expect(progress.objectives, isNotEmpty);
    expect(
      progress.objectives.first.text,
      contains('fetch and wind'),
    );
    expect(progress.gaps, isNotEmpty);
    expect(progress.assessed, isTrue);
    expect(pipeline.hasTeaching, isTrue);
    expect(pipeline.explanation, contains('Fetch is the unbroken stretch of water'));
    expect(pipeline.example, contains('Holderness zigzag'));
    expect(pipeline.adaptation, contains('stay_on_step'));
    expect(pipeline.adaptation, contains('revisit_prerequisite'));
    expect(pipeline.interaction, contains('Why does the spit curve?'));
  });

  testWidgets('LessonReadyScreen shows mock topic and sequence stats',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 960);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final brief = mockBrief();
    final pipeline = mockPipeline();
    await tester.pumpWidget(
      MaterialApp(
        home: LessonReadyScreen(
          brief: brief,
          markdown: pipeline.curriculum!,
          origin: mockOrigin(),
          pipeline: pipeline,
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Lesson Ready!'), findsOneWidget);
    expect(find.text(mockTopic), findsOneWidget);
    expect(find.text('Geography'), findsOneWidget);
    expect(find.text('GCSE'), findsOneWidget);
    expect(find.textContaining('step'), findsWidgets);
    expect(find.text('View Lesson'), findsOneWidget);
  });

  testWidgets('CurriculumScreen shows mock topic, slide title, and sequence',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 960);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final brief = mockBrief();
    final pipeline = mockPipeline();
    await tester.pumpWidget(
      MaterialApp(
        home: CurriculumScreen(
          brief: brief,
          markdown: pipeline.curriculum!,
          origin: mockOrigin(),
          pipeline: pipeline,
        ),
      ),
    );
    await tester.pump();

    expect(find.text(mockTopic), findsOneWidget);
    expect(find.text('Coasts are energy, rock, and sediment'), findsOneWidget);
    expect(find.textContaining('Slide 1 /'), findsOneWidget);
    expect(
      find.textContaining('Hold the three photos'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('teaching-pack-sequence')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('Activate: what is a coastline doing?'), findsOneWidget);
    expect(find.textContaining('5 min'), findsWidgets);
    expect(find.text('Coasts are energy, rock, and sediment'), findsNothing);
  });

  testWidgets('TeachScreen shows mock explanation, example, and interaction well',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 960);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(mockTeachApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 450));

    expect(find.byKey(const ValueKey('teach-screen')), findsOneWidget);
    expect(find.text('Teaching Studio'), findsOneWidget);
    expect(find.text(mockTopic), findsOneWidget);
    expect(find.text('MOCK PACK'), findsOneWidget);
    expect(find.byKey(const ValueKey('teach-studio-tab-explanation')), findsOneWidget);
    expect(find.byKey(const ValueKey('teach-studio-tab-example')), findsOneWidget);
    expect(find.byKey(const ValueKey('teach-studio-tab-interaction')), findsOneWidget);
    expect(find.byKey(const ValueKey('teach-studio-tab-adaptation')), findsNothing);
    expect(find.text('Stay on step'), findsOneWidget);
    expect(find.text('revisit prerequisite'), findsOneWidget);
    expect(find.byKey(const ValueKey('teach-studio-ask-bar')), findsOneWidget);
    expect(
      find.textContaining('Why does the spit curve?'),
      findsWidgets,
    );
    expect(
      find.textContaining('The spit grows because longshore drift'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('teach-studio-tab-explanation')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 450));
    expect(
      find.textContaining('Fetch is the unbroken stretch of water'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('teach-studio-tab-example')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 450));
    expect(find.textContaining('Holderness zigzag'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('teach-studio-adaptation-banner')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      find.textContaining('weathering vs erosion'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('teach-studio-tab-interaction')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 450));
    expect(find.byKey(const ValueKey('teach-studio-ask-bar')), findsOneWidget);
    expect(find.byKey(const ValueKey('teach-studio-reply-card')), findsOneWidget);
    expect(find.textContaining('Why does the spit curve?'), findsWidgets);
    expect(
      find.textContaining('The spit grows because longshore drift'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('teach-studio-suggestion-1')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 450));
    expect(
      find.textContaining('Fetch is the unbroken stretch of water the wind blows over'),
      findsOneWidget,
    );
  });

  testWidgets('Teach tab opens the teaching studio from the mock lesson',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 960);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final brief = mockBrief();
    final pipeline = mockPipeline();
    await tester.pumpWidget(
      MaterialApp(
        home: CurriculumScreen(
          brief: brief,
          markdown: pipeline.curriculum!,
          origin: mockOrigin(),
          pipeline: pipeline,
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('teaching-pack-teach')));
    await tester.pump();
    expect(find.text('Open studio'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('teaching-pack-open-studio')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.byKey(const ValueKey('teach-screen')), findsOneWidget);
    expect(find.text('Teaching Studio'), findsOneWidget);
    expect(
      find.textContaining('Why does the spit curve?'),
      findsWidgets,
    );
  });
}
