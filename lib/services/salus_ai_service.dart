import 'dart:convert';
import 'dart:io';

import 'chatgpt_connection_service.dart';

/// Real ChatGPT plan usage: API catalog selects a granted model; Responses API
/// uses stream:true and store:false. No fallback fake responses.
class SalusAiService {
  const SalusAiService();
  static const _account = ChatGptConnectionService();

  Future<String> _model(String token) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 12);
    try {
      final req = await client.getUrl(Uri.parse('https://api.openai.com/v1/models'));
      req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      final res = await req.close().timeout(const Duration(seconds: 20));
      final data = await res.transform(utf8.decoder).join();
      if (res.statusCode != 200) {
        throw StateError('Cannot load available ChatGPT models (${res.statusCode}).');
      }
      final value = jsonDecode(data);
      if (value is! Map) throw StateError('Invalid ChatGPT model catalog.');
      final list = value['data'];
      if (list is! List || list.isEmpty) throw StateError('No models available with this account.');
      final visible = list.whereType<Map>().where((m) =>
          m['visibility'] == null || m['visibility'] == 'list').toList();
      final options = visible.isNotEmpty ? visible : list.whereType<Map>().toList();
      if (options.isEmpty) throw StateError('No accessible ChatGPT model.');
      final selected = options.where((m) => (m['id'] ?? '').toString().startsWith('gpt-'));
      final record = selected.isEmpty ? options.first : selected.first;
      final slug = (record['id'] ?? '').toString();
      if (slug.isEmpty) throw StateError('Model catalog did not return a usable slug.');
      return slug;
    } finally { client.close(force: true); }
  }

  Future<String> ask(String userPrompt, {
    List<Map<String, String>> prior = const [],
    String? imagePath,
  }) async {
    final token = await _account.accessToken();
    final model = await _model(token);
    final instructions = imagePath == null
        ? 'You are Salus AI, a helpful wellness and nutrition assistant. '
          'Explain limitations and avoid diagnosis, invented device readings, '
          'or personalized medical treatment. Use only health values the user '
          'explicitly provides in this message. Answer concisely.'
        : 'You analyze food photographs for optional nutrition journaling. '
          'A single photo cannot establish exact weights, added oil, sauces, '
          'or ingredients. Return ONLY valid JSON, no markdown, as: '
          '{"foods":[{"name":"string","estimated_grams":number,'
          '"calories":number,"protein":number,"carbs":number,'
          '"fat":number}],"notes":"string","confidence":"low"}. '
          'Only include visually plausible foods. Provide conservative '
          'approximations, not verified values. List key assumptions in notes. '
          'If unable to identify, return foods empty.';
    final input = <Map<String, dynamic>>[
      for (final item in prior.take(12))
        {
          'role': item['role'] == 'assistant' ? 'assistant' : 'user',
          'content': item['text'] ?? '',
        },
    ];
    if (imagePath == null) {
      input.add({'role': 'user', 'content': userPrompt});
    } else {
      final file = File(imagePath);
      if (!await file.exists()) throw StateError('Selected food photo not found.');
      final bytes = await file.readAsBytes();
      if (bytes.length > 9 * 1024 * 1024) {
        throw StateError('Photo too large. Capture a smaller image.');
      }
      final isPng = imagePath.toLowerCase().endsWith('.png');
      input.add({'role': 'user', 'content': [
        {'type': 'input_text', 'text': userPrompt},
        {'type': 'input_image', 'image_url':
            'data:image/${isPng ? 'png' : 'jpeg'};base64,${base64Encode(bytes)}'},
      ]});
    }
    final payload = jsonEncode({
      'model': model,
      'instructions': instructions,
      'input': input,
      'store': false,
      'stream': true,
    });
    return _streamResponse(token, payload);
  }

  Future<String> _streamResponse(String token, String body) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 16);
    try {
      final req = await client.postUrl(Uri.parse('https://api.openai.com/v1/responses'));
      req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      req.headers.contentType = ContentType.json;
      req.write(body);
      final res = await req.close().timeout(const Duration(seconds: 30));
      if (res.statusCode != 200) {
        final failure = await res.transform(utf8.decoder).join();
        String msg = 'AI request failed (${res.statusCode}).';
        try {
          final decoded = jsonDecode(failure) as Map;
          final error = decoded['error'];
          if (error is Map) msg = (error['message'] ?? msg).toString();
        } catch (_) { /* Do not surface raw payloads. */ }
        throw StateError(msg);
      }
      final buffer = StringBuffer();
      var completed = false;
      final event = StringBuffer();
      // Read Server-Sent Events to their terminal event (HTTP may remain open
      // after receiving initial deltas). The stream completion is authoritative.
      await for (final line in res.transform(utf8.decoder).transform(const LineSplitter())) {
        if (line.startsWith('data:')) {
          event.writeln(line.substring(5).trimLeft());
          continue;
        }
        if (line.isNotEmpty) continue;
        final value = event.toString().trim();
        event.clear();
        if (value.isEmpty || value == '[DONE]') continue;
        Map<String, dynamic> payload;
        try { payload = Map<String, dynamic>.from(jsonDecode(value) as Map); }
        catch (_) { continue; }
        final type = payload['type']?.toString() ?? '';
        if (type == 'response.output_text.delta') {
          buffer.write(payload['delta']?.toString() ?? '');
        } else if (type == 'response.failed' || type == 'response.incomplete' ||
            type == 'error') {
          throw StateError('ChatGPT response did not complete. Try again or check plan limits.');
        } else if (type == 'response.completed') {
          completed = true;
        }
      }
      if (!completed) throw StateError('ChatGPT stream ended without completing.');
      final result = buffer.toString().trim();
      if (result.isEmpty) throw StateError('ChatGPT returned an empty answer.');
      return result;
    } finally { client.close(force: true); }
  }
}

class AiEstimatedFood {
  final String name;
  final double grams, calories, protein, carbs, fat;
  const AiEstimatedFood(this.name, this.grams, this.calories,
      this.protein, this.carbs, this.fat);

  static double number(dynamic value) {
    final v = value is num ? value.toDouble() : double.tryParse('$value') ?? 0;
    return v.isFinite && v >= 0 && v <= 10000 ? v : 0;
  }

  static List<AiEstimatedFood> parse(String response) {
    final start = response.indexOf('{');
    final end = response.lastIndexOf('}');
    if (start < 0 || end <= start) throw const FormatException('Food analysis did not return JSON.');
    final value = jsonDecode(response.substring(start, end + 1));
    if (value is! Map || value['foods'] is! List) {
      throw const FormatException('Food analysis response has no food list.');
    }
    return (value['foods'] as List).whereType<Map>().take(12).map((f) {
      final name = (f['name'] ?? '').toString().trim();
      return AiEstimatedFood(name, number(f['estimated_grams']),
          number(f['calories']), number(f['protein']),
          number(f['carbs']), number(f['fat']));
    }).where((f) => f.name.isNotEmpty).toList();
  }
}
