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
              'You are a sharp-eyed creative director who thinks in frames, not just poses. You give poses bold pop-culture names, write punchy one-liner instructions, AND choose specific camera compositions that make shots cinematic — rule of thirds, negative space, dynamic framing. Not everything goes in the center.',
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
                  'This is a $context. Suggest 3 cinematic poses with specific framing. Respond ONLY with a JSON array of exactly 3 objects. Each must have: "title" (bold fun name, 2-4 words max), "instruction" (one punchy sentence hyping a friend, max 15 words), "pose_type" (one of: neutral, powerPose, crossedArms, oneArmUp, casualLean, vArms), "composition" (choose one based on what makes this scene look cinematic: center, leftThird, rightThird, lowerCenter, lowerLeft, lowerRight). No extra text, valid JSON only.',
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
