import 'dart:convert';

class ResearchOrigin {
  const ResearchOrigin({
    this.ragUsed = false,
    this.webUsed = false,
    this.retrievalMode,
  });

  final bool ragUsed;
  final bool webUsed;
  final String? retrievalMode;

  bool get fromCache => ragUsed && !webUsed;
  bool get liveWeb => webUsed && !ragUsed;
  bool get hybrid => ragUsed && webUsed;
  bool get known => ragUsed || webUsed;

  String get badge {
    if (fromCache) return 'Reused from SYNTRA cache';
    if (liveWeb) return 'Researched live';
    if (hybrid) return 'Cache + live research';
    return 'Researching';
  }

  String get runSubtitle {
    if (fromCache) {
      return 'Reused from SYNTRA cache — skipping live web research.';
    }
    if (liveWeb) return 'Researched live from the web.';
    if (hybrid) return 'Combined SYNTRA cache with live web research.';
    return 'Labelling the topic, then checking the cache.';
  }

  static ResearchOrigin? parse(String text) {
    final decoded = extractJsonMap(text);
    if (decoded == null) return null;
    final method = decoded['research_method'];
    if (method is Map) {
      return ResearchOrigin(
        ragUsed: method['rag_used'] == true,
        webUsed: method['web_used'] == true,
        retrievalMode: method['retrieval_mode']?.toString(),
      );
    }
    final mode = decoded['retrieval_mode'] ?? decoded['mode'];
    if (mode == 'RAG_ONLY') {
      return const ResearchOrigin(ragUsed: true, retrievalMode: 'RAG_ONLY');
    }
    if (mode == 'WEB_ONLY') {
      return const ResearchOrigin(webUsed: true, retrievalMode: 'WEB_ONLY');
    }
    return null;
  }
}

Map<String, dynamic>? extractJsonMap(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return null;
  final fence = RegExp(r'```(?:json)?\s*([\s\S]*?)```', caseSensitive: false);
  final fenced = fence.firstMatch(trimmed);
  final candidate = (fenced != null ? fenced.group(1) : trimmed)!.trim();
  final start = candidate.indexOf('{');
  final end = candidate.lastIndexOf('}');
  if (start < 0 || end <= start) return null;
  try {
    final decoded = jsonDecode(candidate.substring(start, end + 1));
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) {
      return decoded.map((key, value) => MapEntry(key.toString(), value));
    }
  } catch (_) {
    return null;
  }
  return null;
}
