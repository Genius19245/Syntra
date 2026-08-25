import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';

import '../data/intake_catalog.dart';
import '../models/learner_brief.dart';
import '../models/research_origin.dart';
import '../progress/models.dart';
import '../screens/result/teach_screen.dart';
import '../theme/syntra_theme.dart';

/// Local teaching pack for Flutter widget tests and the standalone preview.
///
/// The live app does not boot this pack. Open it with
/// `flutter run -d chrome -t lib/debug/mock_teach_main.dart`.

const mockTopic = 'Coastal landscapes';

LearnerBrief mockBrief() {
  return LearnerBrief()
    ..selectLevel(IntakeCatalog.levelById('GCSE'))
    ..selectBoard('AQA')
    ..selectSubject('Geography')
    ..setTopic(mockTopic)
    ..selectGoal('exam')
    ..selectDepth('GCSE')
    ..setPriorKnowledge(
      'Waves transfer energy across the sea. Students have seen photos of '
      'beaches and cliffs, but have not named landforms or management options.',
    );
}

ResearchOrigin mockOrigin() {
  return const ResearchOrigin(
    ragUsed: true,
    webUsed: false,
    retrievalMode: 'cache',
    hitCount: 14,
  );
}

PipelineTexts mockPipeline() {
  return PipelineTexts(
    learningObjectives: _objectivesMarkdown,
    prerequisiteAnalysis: _prerequisitesMarkdown,
    curriculum: _curriculumMarkdown,
    lessonPlan: _lessonPlanJson,
    slides: _slidesJson,
    assessment: _assessmentMarkdown,
    knownKnowledge: mockBrief().priorKnowledge,
    explanation: mockExplanation,
    example: mockExample,
    adaptation: mockAdaptation,
    interaction: mockInteraction,
  );
}

TeachScreen mockTeachScreen() {
  return TeachScreen.fromPipeline(
    key: const ValueKey('mock-teach-screen'),
    brief: mockBrief(),
    pipeline: mockPipeline(),
    mock: true,
    standalone: true,
  );
}

Widget mockTeachApp() {
  return MaterialApp(
    title: 'SYNTRA Teaching Studio',
    debugShowCheckedModeBanner: false,
    theme: SyntraTheme.light(),
    scrollBehavior: const MaterialScrollBehavior().copyWith(
      dragDevices: {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
      },
    ),
    home: mockTeachScreen(),
  );
}

const _curriculumMarkdown = '''
# Curriculum Plan

## Learner Profile
- Level: GCSE
- Board: AQA
- Subject: Geography
- Topic: Coastal landscapes
- Assumed Prior Knowledge: Waves transfer energy; beaches and cliffs from photos
- Learning Goal: Prepare for an exam
- Required Depth: GCSE

## Prerequisites
Copy from the Prerequisite Agent analysis.

### Missing
- Difference between weathering and erosion
- How to read a simple OS map extract of a coastline

## Learning Objectives
Copy from the Learning Objectives Agent.

1. Describe how fetch and wind control wave energy at a coastline.
2. Compare constructive and destructive waves using swash and backwash.
3. Explain how longshore drift transports sediment along a beach.
4. Account for the formation of headlands, bays, and wave-cut platforms.
5. Evaluate hard and soft engineering as responses to coastal erosion.

## Curriculum Structure

### 1. Wave energy and fetch
- Purpose: Give students a cause before landforms
- Concepts: Fetch, wind speed, wave energy
- Required depth: GCSE qualitative plus the energy relationship

### 2. Wave types
- Purpose: Contrast constructive and destructive waves
- Concepts: Swash, backwash, beach building, beach stripping
- Required depth: Comparison table they can redraw

### 3. Longshore drift
- Purpose: Show how sediment moves along the shore
- Concepts: Prevailing wind, zigzag transport, spits
- Required depth: Sequence they can annotate

### 4. Erosional landforms
- Purpose: Link geology and process to headlands, bays, and platforms
- Concepts: Differential erosion, hydraulic action, abrasion
- Required depth: Formation sequence for a 6-mark answer

### 5. Coastal management
- Purpose: Weigh hard and soft engineering
- Concepts: Sea walls, groynes, beach nourishment, managed retreat
- Required depth: Evaluation with a named example

## Teaching Sequence
1. Recap energy transfer in waves
2. Define fetch and the wave-energy relationship
3. Compare constructive and destructive waves
4. Walk longshore drift with arrows on the board
5. Build headlands, bays, and a wave-cut platform
6. Weigh hard versus soft engineering
7. Timed 6-mark coasts item

## Difficulty / Depth
Kept at AQA GCSE Paper 1 physical landscapes demand.

## Expected Learning Outcome
Learners can explain coastal processes and landforms, then evaluate management in an exam-style paragraph.
''';

const _objectivesMarkdown = '''
# Learning Objectives

## Target
Subject: Geography
Topic: Coastal landscapes
Education Level: GCSE
Exam Board: AQA

## Objectives

By the end of the learning experience, the learner will be able to:

1. Describe how fetch and wind control wave energy at a coastline.
2. Compare constructive and destructive waves using swash and backwash.
3. Explain how longshore drift transports sediment along a beach.
4. Account for the formation of headlands, bays, and wave-cut platforms.
5. Evaluate hard and soft engineering as responses to coastal erosion.

## Objective Types

- Understanding
- Analysis
- Understanding
- Understanding
- Evaluation

## Progression

Objectives move from wave energy to process, then landform sequences, then a management evaluation.

## Validation

- Specific
- Measurable
- Level appropriate
- Relevant
- Observable
''';

const _prerequisitesMarkdown = '''
# Prerequisite Analysis

## Learner Knowledge

### Missing
- Difference between weathering and erosion
- How to read a simple OS map extract of a coastline

## Recommended preparation
- Sketch a cliff, beach, and sea in one labelled diagram before the lesson
''';

const _assessmentMarkdown = '''
# Assessment

## Results

1. Describe how fetch and wind control wave energy at a coastline — Correct
2. Compare constructive and destructive waves using swash and backwash — Correct
3. Explain how longshore drift transports sediment along a beach — Incorrect
4. Account for the formation of headlands, bays, and wave-cut platforms — Correct
5. Evaluate hard and soft engineering as responses to coastal erosion — Incorrect
''';

final _lessonPlanJson = jsonEncode({
  'lesson_sequence': [
    {
      'step': 1,
      'title': 'Activate: what is a coastline doing?',
      'purpose': 'Surface photos of cliffs and beaches as processes, not scenery.',
      'activity':
          'Show three photos (Holderness cliff, Chesil Beach, a groyned resort). Ask: energy, sediment, or both?',
      'concepts': ['coastline', 'energy', 'sediment'],
      'depends_on': <String>[],
      'estimated_minutes': 5,
      'difficulty': 'foundation',
    },
    {
      'step': 2,
      'title': 'Fetch and wave energy',
      'purpose': 'Give a cause students can point at on a map.',
      'activity':
          'Trace fetch across the Atlantic vs a sheltered bay. Freeze on the energy relationship.',
      'concepts': ['fetch', 'wind speed', 'wave energy'],
      'depends_on': ['energy'],
      'estimated_minutes': 8,
      'difficulty': 'developing',
    },
    {
      'step': 3,
      'title': 'Constructive vs destructive waves',
      'purpose': 'Contrast swash and backwash before naming landforms.',
      'activity':
          'Two-column board: strong swash vs strong backwash. Class votes which photo matches which wave.',
      'concepts': ['swash', 'backwash', 'constructive waves', 'destructive waves'],
      'depends_on': ['wave energy'],
      'estimated_minutes': 8,
      'difficulty': 'developing',
    },
    {
      'step': 4,
      'title': 'Longshore drift on the board',
      'purpose': 'Make the zigzag transport sequence drawable from memory.',
      'activity':
          'Draw prevailing wind, swash, backwash, and net movement. Students add arrows, then a spit at the end.',
      'concepts': ['longshore drift', 'prevailing wind', 'spit'],
      'depends_on': ['swash', 'backwash'],
      'estimated_minutes': 10,
      'difficulty': 'intermediate',
    },
    {
      'step': 5,
      'title': 'Headlands, bays, and platforms',
      'purpose': 'Link geology and process to three exam landforms.',
      'activity':
          'Build the sequence: differential erosion → headland and bay → wave-cut notch → platform. Pause on hydraulic action vs abrasion.',
      'concepts': [
        'headland',
        'bay',
        'wave-cut platform',
        'hydraulic action',
        'abrasion',
      ],
      'depends_on': ['destructive waves'],
      'estimated_minutes': 12,
      'difficulty': 'intermediate',
    },
    {
      'step': 6,
      'title': 'Hard vs soft engineering',
      'purpose': 'Practise evaluation language for a 6-mark coasts item.',
      'activity':
          'Card sort: sea wall, groynes, beach nourishment, managed retreat. Cost, look, and who benefits.',
      'concepts': [
        'sea wall',
        'groynes',
        'beach nourishment',
        'managed retreat',
      ],
      'depends_on': ['longshore drift', 'headland'],
      'estimated_minutes': 8,
      'difficulty': 'advanced',
    },
    {
      'step': 7,
      'title': 'Timed 6-mark coasts item',
      'purpose': 'Transfer the sequence into exam writing under time.',
      'activity':
          'Eight minutes: explain the formation of a wave-cut platform. Live mark against process → landform → example.',
      'concepts': ['wave-cut platform', 'exam command words'],
      'depends_on': ['wave-cut platform'],
      'estimated_minutes': 9,
      'difficulty': 'exam_application',
    },
  ],
});

final _slidesJson = jsonEncode({
  'lesson_title': 'Coastal landscapes',
  'slides': [
    {
      'slide_number': 1,
      'title': 'Coasts are energy, rock, and sediment',
      'purpose': 'Open with a model, not a photo dump.',
      'content': [
        'A coastline is where wave energy meets geology.',
        'Sediment is stored (beach), moved (drift), or lost (erosion).',
        'Today: process first, then landforms, then management.',
      ],
      'visual_type': 'none',
      'visual_description': '',
      'teacher_explanation':
          'Hold the three photos. Do not name landforms yet. Ask which one is being attacked, which is storing sediment, which is being managed.',
      'interaction': 'Photo triad',
      'estimated_minutes': 3,
      'difficulty': 'foundation',
    },
    {
      'slide_number': 2,
      'title': 'Wave energy tracks fetch',
      'purpose': 'Give a cause students can write in one line.',
      'content': [
        'Fetch is the unbroken distance wind blows over water.',
        'Longer fetch and stronger wind mean more energy at the shore.',
        'The Atlantic fetch hitting west Cornwall is not the same as a sheltered ria.',
      ],
      'visual_type': 'equation',
      'visual_description': 'Simple GCSE relationship, not a derived formula.',
      'equation': {
        'equation': 'Wave energy ∝ fetch × wind speed',
        'format': 'latex',
      },
      'teacher_explanation':
          'Point at fetch first, then wind. Ask why a storm in a small lake still looks fierce but does not cut a wave-cut platform.',
      'interaction': 'Map fetch with a finger',
      'estimated_minutes': 4,
      'difficulty': 'developing',
    },
    {
      'slide_number': 3,
      'title': 'Constructive vs destructive waves',
      'purpose': 'Contrast swash and backwash before landforms.',
      'content': [
        'Constructive waves: strong swash, weak backwash, beach builds.',
        'Destructive waves: weak swash, strong backwash, beach is stripped.',
        'Frequency is a clue: destructive waves arrive more often.',
      ],
      'visual_type': 'comparison',
      'visual_description':
          'Two-column board: constructive (low, spilling) versus destructive (steep, plunging).',
      'diagram_spec': {
        'diagram_type': 'comparison',
        'subject': 'Wave type and beach change',
        'description':
            'Left: long wavelength, strong swash, sediment deposited. Right: short wavelength, strong backwash, sediment removed.',
        'concepts': ['swash', 'backwash', 'beach profile'],
      },
      'teacher_explanation':
          'Draw two arrows on the beach face. Swash up, backwash down. Thicker arrow wins. That is the whole distinction.',
      'estimated_minutes': 5,
      'difficulty': 'developing',
    },
    {
      'slide_number': 4,
      'title': 'Longshore drift is a zigzag',
      'purpose': 'Make net sediment movement drawable from memory.',
      'content': [
        'Prevailing wind drives swash at an angle.',
        'Backwash runs straight down the slope under gravity.',
        'Net movement of sediment is along the beach — longshore drift.',
      ],
      'visual_type': 'flowchart',
      'visual_description':
          'Zigzag arrows along a beach, then a spit growing across a river mouth.',
      'diagram_spec': {
        'diagram_type': 'flowchart',
        'subject': 'Longshore drift sequence',
        'description':
            'Prevailing wind → angled swash → perpendicular backwash → net alongshore transport → spit where the coast changes direction.',
        'concepts': ['prevailing wind', 'swash', 'backwash', 'spit'],
      },
      'teacher_explanation':
          'Walk the zigzag with your marker. Stop at the river mouth and ask why the spit curves. Current in the estuary bends it.',
      'estimated_minutes': 5,
      'difficulty': 'intermediate',
    },
    {
      'slide_number': 5,
      'title': 'Headlands and bays from mixed geology',
      'purpose': 'Link rock resistance to planform.',
      'content': [
        'Resistant rock stands out as a headland.',
        'Weaker rock is eroded back into a bay.',
        'Waves refract around the headland, concentrating energy on its sides.',
      ],
      'visual_type': 'ai_generated',
      'visual_description':
          'Plan-view coastline of alternating hard and soft rock, with a bay and two headlands. No labels.',
      'visual_asset': {
        'prompt':
            'Educational plan-view illustration of a mixed-geology coastline, hard rock headlands and a sandy bay, GCSE geography, no text labels.',
        'aspect_ratio': '16:9',
        'educational_purpose':
            'Show differential erosion creating headlands and bays without needing a network image',
        'status': 'placeholder',
      },
      'teacher_explanation':
          'The illustration is a placeholder — talk over it. Shade hard rock darker. Ask where a settlement would put a beach cafe.',
      'estimated_minutes': 4,
      'difficulty': 'intermediate',
    },
    {
      'slide_number': 6,
      'title': 'A wave-cut platform is leftover cliff',
      'purpose': 'Sequence notch → collapse → retreat for a 6-mark answer.',
      'content': [
        'Hydraulic action and abrasion cut a notch at high-water mark.',
        'The overhang collapses; the cliff steps back.',
        'A wave-cut platform is the gently sloping rock left at the foot.',
      ],
      'visual_type': 'diagram',
      'visual_description':
          'Side-view cliff with notch, collapse arrow, and a wide platform in front.',
      'diagram_spec': {
        'diagram_type': 'cross_section',
        'subject': 'Wave-cut platform formation',
        'description':
            'Sea on the left, cliff on the right. Notch at the base, fallen debris, retreated cliff face, and a wide platform exposed at low tide.',
        'concepts': ['notch', 'collapse', 'retreat', 'platform'],
      },
      'teacher_explanation':
          'Count the steps on your fingers: notch, collapse, retreat, platform. If a student writes "the sea erodes the cliff" that is one mark, not four.',
      'estimated_minutes': 6,
      'difficulty': 'intermediate',
    },
    {
      'slide_number': 7,
      'title': 'Hard engineering holds the line',
      'purpose': 'Name three options before evaluating them.',
      'content': [
        'Sea walls reflect energy but are expensive and can scour the beach.',
        'Groynes trap sediment on the updrift side and starve the downdrift side.',
        'Rock armour absorbs energy; it changes how the coast looks.',
      ],
      'visual_type': 'comparison',
      'visual_description':
          'Three panels: curved sea wall, timber groynes, piled boulders.',
      'teacher_explanation':
          'Groynes are the trap. Ask who loses sand. The next town along. That sentence is evaluation, not description.',
      'estimated_minutes': 5,
      'difficulty': 'advanced',
    },
    {
      'slide_number': 8,
      'title': 'Soft engineering works with sediment',
      'purpose': 'Contrast working with the beach versus armouring it.',
      'content': [
        'Beach nourishment adds sediment so the beach absorbs energy.',
        'Dune fencing and planting slow wind erosion behind the berm.',
        'Managed retreat lets the coast move inland where defences cost more than the land.',
      ],
      'visual_type': 'graph',
      'visual_description':
          'Sketch graph: cost vs lifetime for sea wall, groynes, nourishment, managed retreat.',
      'teacher_explanation':
          'Do not pretend nourishment is free. It is cheaper to start and must be repeated. Managed retreat is politically hard — name a place if you can (Medmerry).',
      'estimated_minutes': 4,
      'difficulty': 'advanced',
    },
    {
      'slide_number': 9,
      'title': '6-mark move: platform then example',
      'purpose': 'Show the writing shape before the timed item.',
      'content': [
        'Command word: explain the formation of…',
        'Order: process at the cliff foot → collapse → retreat → named landform.',
        'Add one located example in the last sentence, not the first.',
      ],
      'visual_type': 'none',
      'visual_description': '',
      'teacher_explanation':
          'Eight minutes on the clock. Live-mark one script on the visualiser: ticks for process, landform, and example. Strike vague "the waves erode the rocks".',
      'interaction': 'Timed writing',
      'estimated_minutes': 8,
      'difficulty': 'exam_application',
    },
  ],
});

const mockExplanation = '''
# Explanation

## Concept
Fetch and wave energy

## Level
GCSE · qualitative relationship, no derived formula.

## Explanation
Fetch is the unbroken stretch of water the wind blows over. At GCSE, treat wave energy as tracking fetch and wind speed together: a long Atlantic fetch hitting west Cornwall arrives with more energy than a short fetch inside a sheltered ria.

Do not start with landforms. Point at a map first. Ask why a storm on a small lake can look fierce and still fail to cut a wave-cut platform — the fetch is too short for the energy to keep arriving.

Write the relationship once, then freeze:

**Wave energy ∝ fetch × wind speed**

That sentence is the cause. Constructive and destructive waves, then longshore drift, come after it.

## Prior knowledge
Students already know waves transfer energy across the sea. They have seen beaches and cliffs in photos. They have not yet named fetch, swash, or backwash.

## Misconceptions
- A tall wave is automatically a destructive wave. Height is not the test; swash versus backwash is.
- Fetch is "how windy it is". Fetch is distance of open water, not wind speed.

## Limits
Keep the energy relationship qualitative. Do not derive a coastal-process formula beyond what the research pack verified.
''';

const mockExample = '''
# Example

## Type
analogy

## Concept
Longshore drift

## Example
Walk the Holderness zigzag on the board.

Prevailing wind drives swash up the beach at an angle. Gravity takes backwash straight down the slope. One grain of sand therefore moves in a zigzag, and the net path is along the shore — longshore drift.

At a river mouth the coast changes direction. The zigzag has nowhere to go, so sediment is dumped and a spit grows. The current in the estuary bends the tip.

That is the drawable sequence: angled swash → perpendicular backwash → net alongshore transport → spit where the coast turns.

## Analogy limit
The zigzag is a transport path, not a drawing of the wave itself. Do not let students label the arrows as "the wave rolling sideways".

## Validation
- valid: true
- issues: none
- warnings: Keep the named place (Holderness) as a locate, not a case-study dump.
''';

const mockAdaptation = '''
# Adaptation

## Learner state
struggling

## Action
revisit_prerequisite

## Guidance
Stay on longshore drift. Repair weathering versus erosion before naming spits. Do not skip to coastal management.

## Stay on step
Yes

## Revisit
- Difference between weathering and erosion
- How to read a simple OS map extract of a coastline

```json
{
  "stay_on_step": true,
  "action": "revisit_prerequisite",
  "revisit_concepts": [
    "weathering vs erosion",
    "OS map extract of a coastline"
  ]
}
```
''';

const mockInteraction = '''
# Student interaction

## Intent
clarify · stay_on_step

Student asked: "Why does the spit curve?"

## Reply
The spit grows because longshore drift dumps sediment where the coast changes direction. It curves because the current in the estuary bends the tip. Stay with that sentence. Do not open a new landform.

If they are still mixing drift with erosion, send them back to the zigzag arrows: swash at an angle, backwash straight down, net movement along the beach.

## Teaching note
Stay on this step. Briefly recall swash and backwash. Do not defer to management, and do not invent a second named example.

## Suggested questions
- Why does the spit curve?
- Is fetch the same as how windy it is?
- Why haven't we named a spit yet?

## Other answers

**Is fetch the same as how windy it is?**
Fetch is the unbroken stretch of water the wind blows over. Wind speed is a separate thing. A fierce storm on a small lake still has a short fetch.

**Why haven't we named a spit yet?**
Stay on the zigzag. Adaptation is holding this step until weathering versus erosion is repaired. Naming the spit comes after the transport sequence sticks.
''';

