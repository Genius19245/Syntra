import 'package:flutter_test/flutter_test.dart';
import 'package:syntra_app/models/research_origin.dart';
import 'package:syntra_app/services/adk_client.dart';
import 'package:syntra_app/services/adk_config.dart';

void main() {
  test('studio defaults to the Cloud Run orchestrator', () {
    expect(AdkConfig.baseUrl, AdkConfig.cloudRunUrl);
    expect(
      AdkConfig.cloudRunUrl,
      'https://syntra-orchestrator-459448503831.us-central1.run.app',
    );
    expect(AdkConfig.appName, 'syntra_orchestrator');
  });

  test('parses cache-only research_method from agent JSON', () {
    const text = '''
```json
{
  "topic": "magnets",
  "research_method": {
    "rag_used": true,
    "web_used": false,
    "retrieval_mode": "RAG_ONLY"
  }
}
```
''';
    final origin = ResearchOrigin.parse(text);
    expect(origin, isNotNull);
    expect(origin!.fromCache, isTrue);
    expect(origin.badge, 'Reused from SYNTRA cache');
  });

  test('parses live web research_method', () {
    const text = '''
{"research_method": {"rag_used": false, "web_used": true, "retrieval_mode": "WEB_ONLY"}}
''';
    final origin = ResearchOrigin.parse(text)!;
    expect(origin.liveWeb, isTrue);
    expect(origin.badge, 'Researched live');
  });

  test('shows hit_count from SSE JSON without talking to Firestore', () {
    const text = '''
{"research_method": {"rag_used": true, "web_used": false, "retrieval_mode": "RAG_ONLY"}, "hit_count": 12}
''';
    final origin = ResearchOrigin.parse(text)!;
    expect(origin.fromCache, isTrue);
    expect(origin.hitCount, 12);
    expect(origin.badge, 'Reused from SYNTRA cache · 12 hits');
  });

  test('ignores missing hit_count', () {
    const text =
        '{"research_method": {"rag_used": true, "web_used": false, "retrieval_mode": "RAG_ONLY"}}';
    final origin = ResearchOrigin.parse(text)!;
    expect(origin.hitCount, isNull);
    expect(origin.badge, 'Reused from SYNTRA cache');
  });

  test('parses HYBRID research_method and camelCase aliases', () {
    const text = '''
{"research_method": {"rag_used": true, "web_used": true, "retrieval_mode": "HYBRID"}, "hit_count": 3}
''';
    final origin = ResearchOrigin.parse(text)!;
    expect(origin.hybrid, isTrue);
    expect(origin.hitCount, 3);
    expect(origin.badge, 'Cache + live research');
  });

  test('AdkEvent captures functionCall names', () {
    final event = AdkEvent.fromJson({
      'author': 'research_agent',
      'content': {
        'parts': [
          {
            'functionCall': {'name': 'plan_retrieval', 'args': {}},
          },
        ],
      },
    });
    expect(event.toolName, 'plan_retrieval');
    expect(event.author, 'research_agent');
  });

  test('AdkEvent captures stateDelta output_key JSON', () {
    final event = AdkEvent.fromJson({
      'author': 'curriculum_agent',
      'content': {
        'parts': [
          {'text': '# Curriculum Plan'},
        ],
      },
      'actions': {
        'stateDelta': {
          'slides': {
            'lesson_title': 'Osmosis',
            'slides': [
              {'title': 'Water moves', 'visual_type': 'none'},
            ],
          },
          'lesson_plan': {
            'lesson_sequence': [
              {'step': 1, 'title': 'Activate', 'estimated_minutes': 5},
            ],
          },
          'research_package': {
            'research_method': {'rag_used': true, 'web_used': false},
          },
        },
      },
    });
    expect(event.text, '# Curriculum Plan');
    expect(event.stateDelta['slides'], contains('Water moves'));
    expect(event.stateDelta['lesson_plan'], contains('Activate'));
    expect(ResearchOrigin.parse(event.stateDelta['research_package']!), isNotNull);
  });
}
