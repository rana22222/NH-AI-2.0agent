import 'package:url_launcher/url_launcher.dart';

class PhoneAction {
  const PhoneAction(this.label, this.url);

  final String label;
  final Uri url;
}

const Set<String> _stopWords = {
  'খোলো',
  'খোল',
  'খুলো',
  'খুল',
  'চালাও',
  'চালা',
  'প্লে',
  'play',
  'করো',
  'দাও',
  'একটা',
  'একটি',
  'ও',
  'এই',
  'ভিডিও',
  'ভিডিওটা',
  'সার্চ',
  'খোঁজো',
  'খোজো',
  'গান',
  'গানটা',
  'অডিও',
  'ইউটিউবে',
  'ইউটিউব',
  'youtube',
  'ম্যাপে',
  'ম্যাপ',
  'map',
  'maps',
  'গুগল',
  'google',
  'জিমেইল',
  'gmail',
  'ফেসবুক',
  'facebook',
  'ক্যালেন্ডার',
  'calendar',
  'হোয়াটসঅ্যাপ',
  'whatsapp',
  'আমার',
  'music',
  'মিউজিক',
};

String _query(String value) {
  return value
      .split(RegExp(r'\s+'))
      .where(
        (word) =>
            word.isNotEmpty && !_stopWords.contains(word),
      )
      .join(' ')
      .trim();
}

/// ফোনে অ্যাপ খোলা বা সার্চ করার স্পষ্ট নির্দেশ হলে কাজ করবে।
/// কনটেন্ট তৈরির অনুরোধ হলে null ফেরত দেবে।
PhoneAction? matchAction(String raw) {
  final String t = raw
      .toLowerCase()
      .replaceAll(RegExp(r'[?।!,.;:]'), ' ')
      .trim();

  bool has(List<String> words) {
    return words.any(t.contains);
  }

  final bool open =
      has(['খোলো', 'খুলে দাও', 'ওপেন', 'open']);

  final bool search =
      has(['সার্চ', 'খোঁজো', 'খুঁজে দাও', 'search']);

  final bool play =
      has(['চালাও', 'প্লে', 'play']);

  final bool create = has([
    'থাম্বনেল',
    'thumbnail',
    'স্ক্রিপ্ট',
    'script',
    'বানাও',
    'তৈরি',
    'আইডিয়া',
    'আইডিয়া',
    'seo',
    'টাইটেল',
    'ক্যাপশন',
    'স্টোরিবোর্ড',
  ]);

  // YouTube: তৈরি করার কাজ হলে অ্যাপ খুলবে না।
  if (has(['ইউটিউব', 'youtube']) &&
      !create &&
      (open || search || play)) {
    if (open && !search && !play) {
      return PhoneAction(
        'ইউটিউব খোলা হচ্ছে',
        Uri.https('www.youtube.com'),
      );
    }

    final String q = _query(t);

    return PhoneAction(
      'ইউটিউবে সার্চ হচ্ছে',
      Uri.https(
        'www.youtube.com',
        '/results',
        {
          'search_query':
              q.isEmpty ? 'trending' : q,
        },
      ),
    );
  }

  // Music
  if (has(['গান', 'অডিও', 'music', 'মিউজিক']) &&
      (search || play)) {
    final String q = _query(t);

    return PhoneAction(
      'মিউজিক খোঁজা হচ্ছে',
      Uri.https(
        'music.youtube.com',
        '/search',
        {
          'q': q.isEmpty ? 'popular songs' : q,
        },
      ),
    );
  }

  // Google Maps
  if (has(['ম্যাপ', 'map']) &&
      (open || search)) {
    final String q = _query(t);

    return PhoneAction(
      'গুগল ম্যাপে খোঁজা হচ্ছে',
      Uri.https(
        'www.google.com',
        '/maps/search/',
        {
          'api': '1',
          'query': q.isEmpty
              ? 'আমার কাছাকাছি'
              : q,
        },
      ),
    );
  }

  // Facebook
  if (has(['ফেসবুক', 'facebook']) && open) {
    return PhoneAction(
      'ফেসবুক খোলা হচ্ছে',
      Uri.https('www.facebook.com'),
    );
  }

  // Gmail
  if ((has(['জিমেইল', 'gmail']) ||
          has(['ইমেইল'])) &&
      open) {
    return PhoneAction(
      'জিমেইল খোলা হচ্ছে',
      Uri.https(
        'mail.google.com',
        '/mail/',
      ),
    );
  }

  // Calendar
  if (has(['ক্যালেন্ডার', 'calendar']) &&
      open) {
    return PhoneAction(
      'ক্যালেন্ডার খোলা হচ্ছে',
      Uri.https('calendar.google.com'),
    );
  }

  // WhatsApp
  if (has(['হোয়াটসঅ্যাপ', 'whatsapp']) &&
      open) {
    return PhoneAction(
      'হোয়াটসঅ্যাপ খোলা হচ্ছে',
      Uri.https('web.whatsapp.com'),
    );
  }

  return null;
}
