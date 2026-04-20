import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../models/pose_suggestion.dart';

class PoseService {
  static const _apiUrl = 'https://api.openai.com/v1/chat/completions';
  static const _model = 'gpt-4.1';

  final String apiKey;

  PoseService({required this.apiKey});

  Future<List<PoseSuggestion>> getSuggestions({
    required Uint8List imageBytes,
    required int personCount,
  }) async {
    final base64Image = base64Encode(imageBytes);
    final context = personCount == 1 ? 'solo portrait' : 'group photo with $personCount people';

    final body = jsonEncode({
      'model': _model,
      'max_tokens': 512,
      'messages': [
        {
          'role': 'system',
          'content':
              'You are a fun, witty pose director — think Vogue meets TikTok. Give poses bold, memorable pop-culture names and write instructions like a hyped-up friend, not a fitness coach. Be short, punchy, and make people smile. No filler words.',
        },
        {
          'role': 'user',
          'content': [
            {
              'type': 'image_url',
              'image_url': {
                'url': 'data:image/jpeg;base64,$base64Image',
                'detail': 'low',
              },
            },
            {
              'type': 'text',
              'text':
                  'This is a $context. Suggest 3 fun poses with personality. Respond ONLY with a JSON array of exactly 3 objects. Each must have: "title" (a bold fun name like "The CEO", "Main Character Energy", "Victory Lap" — 2-4 words max), "instruction" (one punchy sentence, like you\'re hyping up a friend before a shoot — no more than 15 words), "pose_type" (one of: neutral, powerPose, crossedArms, oneArmUp, casualLean, vArms). No extra text, just valid JSON.',
            }
          ],
        }
      ],
    });

    final response = await http.post(
      Uri.parse(_apiUrl),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      },
      body: body,
    );

    if (response.statusCode != 200) {
      throw Exception('OpenAI API error: ${response.statusCode}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final text = data['choices'][0]['message']['content'] as String;

    final jsonStart = text.indexOf('[');
    final jsonEnd = text.lastIndexOf(']') + 1;
    if (jsonStart == -1 || jsonEnd <= jsonStart) {
      throw Exception('Unexpected response format from OpenAI API');
    }
    final jsonStr = text.substring(jsonStart, jsonEnd);
    final list = jsonDecode(jsonStr) as List;

    return list.map((e) => PoseSuggestion.fromJson(e as Map<String, dynamic>)).toList();
  }
}
