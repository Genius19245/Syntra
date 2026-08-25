import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/research_origin.dart';
import 'adk_config.dart';

class AdkEvent {
  const AdkEvent({
    this.author,
    this.text,
    this.toolName,
    this.partial = false,
    this.error,
    this.stateDelta = const {},
  });

  final String? author;
  final String? text;
  final String? toolName;
  final bool partial;
  final String? error;
  /// output_key values from ADK `actions.stateDelta`.
  final Map<String, String> stateDelta;

  bool get hasText => text != null && text!.trim().isNotEmpty;

  factory AdkEvent.fromJson(Map<String, dynamic> json) {
    if (json['error'] != null) {
      return AdkEvent(error: json['error'].toString());
    }

    final content = json['content'];
    final buffer = StringBuffer();
    String? toolName;
    if (content is Map && content['parts'] is List) {
      for (final part in content['parts'] as List) {
        if (part is! Map) continue;
        if (part['text'] is String) {
          buffer.write(part['text']);
        }
        final call = part['functionCall'] ?? part['function_call'];
        if (call is Map && call['name'] is String) {
          toolName = call['name'] as String;
        }
        final response = part['functionResponse'] ?? part['function_response'];
        if (response is Map) {
          if (toolName == null && response['name'] is String) {
            toolName = response['name'] as String;
          }
          if (buffer.isEmpty) {
            final encoded = encodePipelineValue(
              response['response'] ?? response['result'],
            );
            if (encoded != null) buffer.write(encoded);
          }
        }
      }
    }

    final stateDelta = <String, String>{};
    final actions = json['actions'];
    if (actions is Map) {
      final delta = actions['stateDelta'] ?? actions['state_delta'];
      if (delta is Map) {
        for (final entry in delta.entries) {
          final encoded = encodePipelineValue(entry.value);
          if (encoded != null && encoded.trim().isNotEmpty) {
            stateDelta[entry.key.toString()] = encoded;
          }
        }
      }
    }

    return AdkEvent(
      author: json['author'] as String?,
      text: buffer.isEmpty ? null : buffer.toString(),
      toolName: toolName,
      partial: json['partial'] == true,
      stateDelta: Map.unmodifiable(stateDelta),
    );
  }
}

class AdkClient {
  AdkClient({http.Client? httpClient}) : _client = httpClient ?? http.Client();

  final http.Client _client;

  static const _sessionTimeout = Duration(seconds: 90);

  Uri get _base => AdkConfig.uri;

  Future<String> createSession({required String userId}) async {
    final uri = _base.replace(
      path: '/apps/${AdkConfig.appName}/users/$userId/sessions',
    );
    try {
      final response = await _client
          .post(
            uri,
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode(const <String, dynamic>{}),
          )
          .timeout(_sessionTimeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw AdkException(
          'Could not start a lesson (${response.statusCode}).',
          detail: 'The teaching engine at ${AdkConfig.baseUrl} rejected the session.',
        );
      }
      final decoded = jsonDecode(response.body);
      if (decoded is Map && decoded['id'] is String) {
        return decoded['id'] as String;
      }
      throw AdkException('ADK session response did not include an id.');
    } on AdkException {
      rethrow;
    } on TimeoutException {
      throw AdkException(
        'SYNTRA is waking the teaching engine.',
        detail: 'Cloud Run took too long to start. Retry in a few seconds.',
      );
    } catch (error) {
      throw AdkException(
        'SYNTRA could not start this lesson.',
        detail:
            'Could not reach ${AdkConfig.baseUrl}. Check the network, then retry.',
      );
    }
  }

  Future<Map<String, dynamic>?> fetchSessionState({
    required String userId,
    required String sessionId,
  }) async {
    final uri = _base.replace(
      path: '/apps/${AdkConfig.appName}/users/$userId/sessions/$sessionId',
    );
    try {
      final response = await _client.get(uri).timeout(const Duration(seconds: 30));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map) return null;
      final state = decoded['state'];
      if (state is! Map) return null;
      return state.map((key, value) => MapEntry(key.toString(), value));
    } catch (_) {
      return null;
    }
  }

  Stream<AdkEvent> runSse({
    required String userId,
    required String sessionId,
    required String message,
  }) async* {
    final request = http.Request('POST', _base.replace(path: '/run_sse'));
    request.headers['Content-Type'] = 'application/json';
    request.headers['Accept'] = 'text/event-stream';
    request.headers['Cache-Control'] = 'no-cache';
    request.body = jsonEncode({
      'appName': AdkConfig.appName,
      'userId': userId,
      'sessionId': sessionId,
      'streaming': true,
      'newMessage': {
        'role': 'user',
        'parts': [
          {'text': message},
        ],
      },
    });

    try {
      final response = await _client.send(request);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final body = await response.stream.bytesToString();
        throw AdkException(
          'The teaching engine could not run this lesson (${response.statusCode}).',
          detail: body.trim().isEmpty ? null : body,
        );
      }

      var buffer = '';
      await for (final chunk in response.stream.transform(utf8.decoder)) {
        buffer += chunk;
        while (true) {
          final index = buffer.indexOf('\n\n');
          if (index < 0) break;
          final rawEvent = buffer.substring(0, index);
          buffer = buffer.substring(index + 2);
          for (final line in rawEvent.split('\n')) {
            if (!line.startsWith('data:')) continue;
            final data = line.substring(5).trim();
            if (data.isEmpty || data == '[DONE]') continue;
            final decoded = jsonDecode(data);
            if (decoded is Map<String, dynamic>) {
              yield AdkEvent.fromJson(decoded);
            }
          }
        }
      }
    } on AdkException {
      rethrow;
    } catch (error) {
      throw AdkException(
        'SYNTRA lost the connection to the teaching engine.',
        detail: error.toString(),
      );
    }
  }

  void close() => _client.close();
}

class AdkException implements Exception {
  AdkException(this.message, {this.detail});
  final String message;
  final String? detail;

  @override
  String toString() => detail == null ? message : '$message\n$detail';
}
