import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../models/pose_suggestion.dart';

class ClaudeService {
  static const _apiUrl = 'https://api.anthropic.com/v1/messages';
  static const _model = 'claude-sonnet-4-6';

  final String apiKey;

  ClaudeService({required this.apiKey});

  Future<List<PoseSuggestion>> getSuggestions({
    required Uint8List imageBytes,
    required int personCount,
  }) async {
    final base64Image = base64Encode(imageBytes);
    final context = personCount == 1 ? 'solo portrait' : 'group photo with $personCount people';

    final body = jsonEncode({
      'model': _model,
      'max_tokens': 512,
      'system':
          'You are a professional photography pose coach. Suggest 3 specific, actionable poses. Keep each to 1-2 sentences. Be encouraging and practical.',
      'messages': [
        {
          'role': 'user',
          'content': [
            {
              'type': 'image',
              'source': {
                'type': 'base64',
                'media_type': 'image/jpeg',
                'data': base64Image,
              },
            },
            {
              'type': 'text',
              'text':
                  'This is a $context. Suggest 3 poses. Respond with a JSON array of exactly 3 objects, each with "title" (short name) and "instruction" (1-2 sentence guide). No extra text, just valid JSON.',
            }
          ],
        }
      ],
    });

    final response = await http.post(
      Uri.parse(_apiUrl),
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': apiKey,
        'anthropic-version': '2023-06-01',
      },
      body: body,
    );

    if (response.statusCode != 200) {
      throw Exception('Claude API error: ${response.statusCode}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final text = (data['content'] as List).first['text'] as String;

    final jsonStart = text.indexOf('[');
    final jsonEnd = text.lastIndexOf(']') + 1;
    final jsonStr = text.substring(jsonStart, jsonEnd);
    final list = jsonDecode(jsonStr) as List;

    return list.map((e) => PoseSuggestion.fromJson(e as Map<String, dynamic>)).toList();
  }
}
