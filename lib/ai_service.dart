import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

class AiService {
  static const String _apiKey =
      String.fromEnvironment('GEMINI_API_KEY');

  static const String _model =
      'gemini-3.5-flash-lite';

  static Future<String> ask(String prompt) async {
    if (_apiKey.trim().isEmpty) {
      return 'Gemini API Key পাওয়া যায়নি। '
          'GitHub Secrets-এ GEMINI_API_KEY পরীক্ষা করুন।';
    }

    final Uri uri = Uri.https(
      'generativelanguage.googleapis.com',
      '/v1beta/models/$_model:generateContent',
    );

    try {
      final http.Response response = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'x-goog-api-key': _apiKey,
            },
            body: jsonEncode({
              'contents': [
                {
                  'role': 'user',
                  'parts': [
                    {'text': prompt},
                  ],
                },
              ],
              'generationConfig': {
                'temperature': 0.7,
                'maxOutputTokens': 4096,
              },
            }),
          )
          .timeout(const Duration(seconds: 60));

      dynamic data;

      try {
        data = jsonDecode(
          utf8.decode(response.bodyBytes),
        );
      } catch (_) {
        data = null;
      }

      if (response.statusCode != 200) {
        final dynamic error =
            data is Map ? data['error'] : null;

        final String message =
            error is Map
                ? error['message']?.toString() ??
                    'অজানা API সমস্যা'
                : 'সার্ভার থেকে সঠিক Error পাওয়া যায়নি';

        switch (response.statusCode) {
          case 400:
            return 'Gemini Request Error (400): $message';

          case 401:
          case 403:
            return 'API Key অথবা Permission সমস্যা '
                '(${response.statusCode}): $message';

          case 404:
            return 'Gemini Model পাওয়া যায়নি (404): $message';

          case 429:
            return 'Gemini Free Quota বা Rate Limit শেষ। '
                'কিছুক্ষণ পরে আবার চেষ্টা করুন।';

          case 500:
          case 503:
            return 'Gemini Server সাময়িকভাবে ব্যস্ত। '
                'কিছুক্ষণ পরে চেষ্টা করুন।';

          default:
            return 'Gemini API Error '
                '(${response.statusCode}): $message';
        }
      }

      if (data is! Map<String, dynamic>) {
        return 'Gemini থেকে সঠিক Response পাওয়া যায়নি।';
      }

      final dynamic candidates = data['candidates'];

      if (candidates is List &&
          candidates.isNotEmpty) {
        final dynamic content =
            candidates.first['content'];

        final dynamic parts =
            content is Map ? content['parts'] : null;

        if (parts is List) {
          final String answer = parts
              .whereType<Map>()
              .map(
                (part) =>
                    part['text']?.toString() ?? '',
              )
              .where((text) => text.isNotEmpty)
              .join('\n')
              .trim();

          if (answer.isNotEmpty) {
            return answer;
          }
        }
      }

      final dynamic feedback =
          data['promptFeedback'];

      if (feedback is Map &&
          feedback['blockReason'] != null) {
        return 'নিরাপত্তা নীতির কারণে অনুরোধটি '
            'প্রসেস করা যায়নি।';
      }

      return 'Gemini কোনো Text Response দেয়নি। '
          'আবার চেষ্টা করুন।';
    } on TimeoutException {
      return 'Gemini উত্তর দিতে বেশি সময় নিচ্ছে। '
          'ইন্টারনেট পরীক্ষা করে আবার চেষ্টা করুন।';
    } on http.ClientException catch (e) {
      return 'Network Connection Error: ${e.message}';
    } catch (e) {
      return 'AI Service Error: $e';
    }
  }
}
