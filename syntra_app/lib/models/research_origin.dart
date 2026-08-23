import 'dart:convert';

class ResearchOrigin {
  const ResearchOrigin({
    this.ragUsed = false,
    this.webUsed = false,
    this.retrievalMode,
    this.hitCount,
  });

  final bool ragUsed;
  final bool webUsed;
  final String? retrievalMode;
  /// Document reuse count from SSE/package JSON only. Never loaded from Firestore.
  final int? hitCount;

  bool get fromCache => ragUsed && !webUsed;
  bool get liveWeb => webUsed && !ragUsed;
  bool get hybrid => ragUsed && webUsed;
  bool get known => ragUsed || webUsed;

  String get badge {
    if (fromCache) {
      if (hitCount != null && hitCount! > 0) {
        return 'Reused from SYNTRA cache · $hitCount hits';
      }
      return 'Reused from SYNTRA cache';
    }
    if (liveWeb) return 'Researched live';
    if (hybrid) return 'Cache + live research';
    return 'Researching';
  }

  Map<String, dynamic> toJson() {
    return {
      'rag_used': ragUsed,
      'web_used': webUsed,
      if (retrievalMode != null) 'retrieval_mode': retrievalMode,
      if (hitCount != null) 'hit_count': hitCount,
    };
  }

  factory ResearchOrigin.fromJson(Map<String, dynamic> json) {
    return ResearchOrigin(
      ragUsed: json['rag_used'] == true,
      webUsed: json['web_used'] == true,
      retrievalMode: json['retrieval_mode']?.toString(),
      hitCount: _asHitCount(json['hit_count']),
    );
  }

  String get runSubtitle {
    if (fromCache) {
      if (hitCount != null && hitCount! > 0) {
        return 'Reused from SYNTRA cache ($hitCount hits) — skipping live web research.';
      }
      return 'Reused from SYNTRA cache — skipping live web research.';
    }
    if (liveWeb) return 'Researched live from the web.';
    if (hybrid) return 'Combined SYNTRA cache with live web research.';
    return 'Labelling the topic, then checking the cache.';
  }

  static int? _asHitCount(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  static ResearchOrigin? parse(String text) {
    final decoded = extractJsonMap(text);
    if (decoded == null) return null;
    final method = decoded['research_method'];
    final metadata = decoded['metadata'];
    final hitCount = _asHitCount(decoded['hit_count']) ??
        (method is Map ? _asHitCount(method['hit_count']) : null) ??
        (metadata is Map ? _asHitCount(metadata['hit_count']) : null);
    if (method is Map) {
      return ResearchOrigin(
        ragUsed: method['rag_used'] == true,
        webUsed: method['web_used'] == true,
        retrievalMode: method['retrieval_mode']?.toString(),
        hitCount: hitCount,
      );
    }
    final mode = decoded['retrieval_mode'] ?? decoded['mode'];
    if (mode == 'RAG_ONLY') {
      return ResearchOrigin(
        ragUsed: true,
        retrievalMode: 'RAG_ONLY',
        hitCount: hitCount,
      );
    }
    if (mode == 'WEB_ONLY') {
      return ResearchOrigin(
        webUsed: true,
        retrievalMode: 'WEB_ONLY',
        hitCount: hitCount,
      );
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
