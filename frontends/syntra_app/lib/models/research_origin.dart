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
    return fromPackage(decoded);
  }

  static ResearchOrigin? fromPackage(Map<String, dynamic> decoded) {
    final method = decoded['research_method'] ?? decoded['researchMethod'];
    final metadata = decoded['metadata'];
    final methodMap = method is Map ? Map<String, dynamic>.from(method) : null;
    final hitCount = _asHitCount(decoded['hit_count'] ?? decoded['hitCount']) ??
        (methodMap != null
            ? _asHitCount(methodMap['hit_count'] ?? methodMap['hitCount'])
            : null) ??
        (metadata is Map
            ? _asHitCount(metadata['hit_count'] ?? metadata['hitCount'])
            : null);

    bool? rag;
    bool? web;
    String? mode;
    if (methodMap != null) {
      rag = _asFlag(methodMap['rag_used'] ?? methodMap['ragUsed']);
      web = _asFlag(methodMap['web_used'] ?? methodMap['webUsed']);
      mode = (methodMap['retrieval_mode'] ?? methodMap['retrievalMode'])
          ?.toString();
    }
    mode ??= (decoded['retrieval_mode'] ?? decoded['retrievalMode'] ?? decoded['mode'])
        ?.toString();
    rag ??= _asFlag(decoded['rag_used'] ?? decoded['ragUsed']);
    web ??= _asFlag(decoded['web_used'] ?? decoded['webUsed']);

    final normalised = mode?.toUpperCase().replaceAll('-', '_');
    if (normalised == 'RAG_ONLY') {
      rag ??= true;
      web ??= false;
    } else if (normalised == 'WEB_ONLY') {
      rag ??= false;
      web ??= true;
    } else if (normalised == 'HYBRID') {
      rag ??= true;
      web ??= true;
    }

    if (rag != true && web != true) return null;
    return ResearchOrigin(
      ragUsed: rag == true,
      webUsed: web == true,
      retrievalMode: mode,
      hitCount: hitCount,
    );
  }

  static bool? _asFlag(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value > 0;
    if (value is String) {
      switch (value.trim().toLowerCase()) {
        case 'true':
        case 'yes':
        case '1':
          return true;
        case 'false':
        case 'no':
        case '0':
          return false;
      }
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

/// Encode ADK state / function-response values so parsers can read them.
String? encodePipelineValue(Object? value) {
  if (value == null) return null;
  if (value is String) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : value;
  }
  if (value is Map || value is List) {
    try {
      return jsonEncode(value);
    } catch (_) {
      return null;
    }
  }
  return value.toString();
}

Object? pickJsonField(Map data, List<String> keys) {
  for (final key in keys) {
    if (!data.containsKey(key)) continue;
    final value = data[key];
    if (value != null) return value;
  }
  return null;
}
