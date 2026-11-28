import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

const String _visionModel = 'gemini-3.5-flash-lite';
const String _visionKey = String.fromEnvironment('GEMINI_API_KEY');

// Sends a photo plus the user's message to Gemini and returns Bengali text.
class VisionService {
  static Future<String> ask(String prompt, File image) async {
    if (_visionKey.trim().isEmpty) {
      return 'Gemini API Key পাওয়া যায়নি।';
    }
    try {
      final List<int> bytes = await image.readAsBytes();
      final String mime =
          image.path.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg';
      final Uri uri = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/$_visionModel:generateContent',
      );
      final http.Response res = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'x-goog-api-key': _visionKey,
            },
            body: jsonEncode({
              'contents': [
                {
                  'role': 'user',
                  'parts': [
                    {
                      'inlineData': {
                        'mimeType': mime,
                        'data': base64Encode(bytes),
                      },
                    },
                    {
                      'text': '$prompt\n\nবাংলায় সংক্ষেপে ও ধাপে ধাপে উত্তর দাও।',
                    },
                  ],
                },
              ],
              'generationConfig': {'temperature': 0.5, 'maxOutputTokens': 2048},
            }),
          )
          .timeout(const Duration(seconds: 90));
      if (res.statusCode != 200) {
        return 'AI তথ্য পাঠাতে ব্যর্থ (${res.statusCode})। আবার চেষ্টা করুন।';
      }
      final Map<String, dynamic> data = jsonDecode(res.body) as Map<String, dynamic>;
      final List<dynamic> cands = data['candidates'] as List<dynamic>? ?? <dynamic>[];
      if (cands.isEmpty) return 'ছবিটা বোঝা যায়নি।';
      final List<dynamic> parts =
          (cands.first as Map)['content']['parts'] as List<dynamic>;
      final String text =
          parts.map((p) => '${(p as Map)['text'] ?? ''}').join().trim();
      return text.isEmpty ? 'ছবিটা বোঝা যায়নি।' : text;
    } catch (e) {
      return 'নেটওয়ার্ক সমস্যা: $e';
    }
  }
}
