import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:syntra_app/progress/lesson_plan.dart';
import 'package:syntra_app/progress/lesson_plan_panel.dart';
import 'package:syntra_app/progress/models.dart';

const _planJson = '''
{
  "lesson_sequence": [
    {
      "step": 1,
      "title": "Activate prior knowledge",
      "purpose": "Remind the class what a magnetic field is.",
      "concepts": ["magnetic field", "compass"],
      "activity": "Show a compass near a bar magnet and ask what it is doing.",
      "depends_on": [],
      "estimated_minutes": 6,
      "difficulty": "foundation"
    },
    {
      "step": 2,
      "title": "Introduce Faraday's law",
      "purpose": "Connect changing flux to induced EMF.",
      "concepts": ["magnetic flux", "induced EMF"],
      "activity": "Work a single numerical example on the board, then freeze on the formula.",
      "depends_on": ["magnetic field"],
      "estimated_minutes": 12,
      "difficulty": "intermediate"
    }
  ]
}
''';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  test('parses the lesson planner JSON schema', () {
    final plan = LessonPlan.tryParse(_planJson);
    expect(plan, isNotNull);
    expect(plan!.steps, hasLength(2));
    expect(plan.totalMinutes, 18);
    expect(plan.steps.first.title, 'Activate prior knowledge');
    expect(plan.steps.first.concepts, ['magnetic field', 'compass']);
    expect(plan.steps.last.difficulty, 'intermediate');
    expect(plan.steps.last.dependsOn, ['magnetic field']);
  });

  test('parses fenced JSON and ignores surrounding prose', () {
    final plan = LessonPlan.tryParse(
      'Here is the sequence:\n```json\n$_planJson\n```\nDone.',
    );
    expect(plan?.steps.first.step, 1);
    expect(plan?.steps.last.estimatedMinutes, 12);
  });

  test('returns null for empty or non-sequence JSON', () {
    expect(LessonPlan.tryParse(''), isNull);
    expect(LessonPlan.tryParse('{"objectives":[]}'), isNull);
    expect(LessonPlan.tryParse('{"lesson_sequence":[]}'), isNull);
  });

  test('PipelineTexts reads the lesson planner author key', () {
    final texts = PipelineTexts.fromAuthors({
      'learning_objectives_agent': 'objectives here',
      'lesson_planner_agent': _planJson,
      'curriculum_agent': 'curriculum here',
    });
    expect(texts.lessonPlan, _planJson);
    expect(LessonPlan.tryParse(texts.lessonPlan)?.steps, hasLength(2));
  });

  test('PipelineTexts reads the slide agent author key', () {
    const deck = '{"slides":[{"slide":1,"title":"Induction","kind":"title"}]}';
    final texts = PipelineTexts.fromAuthors({
      'slide_agent': deck,
      'curriculum_agent': 'curriculum here',
    });
    expect(texts.slides, deck);
  });

  testWidgets('renders a teacher-facing sequence from JSON', (tester) async {
    final plan = LessonPlan.tryParse(_planJson)!;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 720,
            child: LessonPlanPanel(plan: plan),
          ),
        ),
      ),
    );

    expect(find.text('Activate prior knowledge'), findsOneWidget);
    expect(find.text('Introduce Faraday\'s law'), findsOneWidget);
    expect(find.textContaining('18'), findsWidgets);
    expect(find.text('Foundation'), findsOneWidget);
    expect(find.text('Intermediate'), findsOneWidget);
    expect(find.textContaining('Show a compass'), findsOneWidget);
    expect(find.text('magnetic field'), findsWidgets);
    expect(find.textContaining('Needs: magnetic field'), findsOneWidget);
  });

  testWidgets('compact sequence folds step cards behind an expansion tile',
      (tester) async {
    final plan = LessonPlan.tryParse(_planJson)!;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LessonPlanPanel(plan: plan, compact: true),
        ),
      ),
    );

    expect(find.text('2 steps'), findsOneWidget);
    expect(find.text('Activate prior knowledge'), findsNothing);
    await tester.tap(find.text('2 steps'));
    await tester.pumpAndSettle();
    expect(find.text('Activate prior knowledge'), findsOneWidget);
    expect(find.text('Introduce Faraday\'s law'), findsOneWidget);
    expect(find.textContaining('6 min'), findsWidgets);
  });
}
