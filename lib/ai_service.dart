import 'dart:convert';
import 'package:http/http.dart' as http;

class AiService {
  static const String _apiKey = String.fromEnvironment('GEMINI_API_KEY');
  static const String _model = 'gemini-2.5-flash';

  static Future<String> ask(String prompt) async {
    if (_apiKey.isEmpty) {
      return 'API key সেট করা নেই।';
    }
    final Uri uri = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/$_model:generateContent');
    try {
      final http.Response response = await http
          .post(
            uri,
            headers: <String, String>{
              'Content-Type': 'application/json',
              'x-goog-api-key': _apiKey,
            },
            body: jsonEncode(<String, dynamic>{
              'contents': <Map<String, dynamic>>[
                <String, dynamic>{
                  'parts': <Map<String, String>>[
                    <String, String>{'text': prompt},
                  ],
                },
              ],
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) {
        return 'ত্রুটি হয়েছে (কোড ${response.statusCode})।';
      }
      final dynamic data = jsonDecode(utf8.decode(response.bodyBytes));
      final String text = data['candidates'][0]['content']['parts'][0]['text'] as String;
      return text.trim();
    } catch (e) {
      return 'উত্তর আনা যায়নি। ইন্টারনেট সংযোগ দেখুন।';
    }
  }
}
