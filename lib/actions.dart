import 'package:url_launcher/url_launcher.dart';

class PhoneAction {
  const PhoneAction(this.label, this.url);
  final String label;
  final Uri url;
}

const Set<String> _stopWords = {
  'খোলো', 'খোল', 'খুলো', 'খুল', 'চালাও', 'চালা', 'প্লে', 'play', 'করো', 'দাও',
  'একটা', 'একটি', 'ও', 'এই', 'ভিডিও', 'ভিডিওটা', 'সার্চ', 'খোঁজো', 'খোজো',
  'গান', 'গানটা', 'অডিও', 'ইউটিউবে', 'ইউটিউব', 'youtube', 'ম্যাপে', 'ম্যাপ',
  'map', 'maps', 'গুগল', 'google', 'জিমেইল', 'gmail', 'ফেসবুক', 'facebook',
  'ক্যালেন্ডার', 'calendar', 'হোয়াটসঅ্যাপ', 'আমার', 'music', 'মিউজিক',
};

String _query(String t) {
  return t
      .split(RegExp(r'\s+'))
      .where((String w) => w.isNotEmpty && !_stopWords.contains(w))
      .join(' ');
}

/// কমান্ডটি ফোনের কোনো কাজ (অ্যাপ/ওয়েব খোলা বা খোঁজা) হলে তার বিবরণ দেয়।
/// না হলে null, তখন এটি সাধারণ AI প্রশ্ন হিসেবে যাবে।
PhoneAction? matchAction(String raw) {
  final String t = raw.toLowerCase().replaceAll(RegExp(r'[?।!,.;:]'), ' ');
  bool has(List<String> keys) => keys.any((String k) => t.contains(k));

  if (has(['ইউটিউব', 'youtube'])) {
    final String q = _query(t);
    return PhoneAction(
      'ইউটিউবে খোঁজা হচ্ছে',
      Uri.https('www.youtube.com', '/results', {'search_query': q.isEmpty ? 'trending' : q}),
    );
  }
  if (has(['গান', 'অডিও', 'music', 'মিউজিক'])) {
    final String q = _query(t);
    return PhoneAction(
      'মিউজিক খোঁজা হচ্ছে',
      Uri.https('music.youtube.com', '/search', {'q': q.isEmpty ? 'popular songs' : q}),
    );
  }
  if (has(['ম্যাপ', 'map'])) {
    final String q = _query(t);
    return PhoneAction(
      'গুগল ম্যাপে খোঁজা হচ্ছে',
      Uri.https('www.google.com', '/maps/search/', {'api': '1', 'query': q.isEmpty ? 'আমার কাছাকাছি' : q}),
    );
  }
  if (has(['ফেসবুক', 'facebook'])) {
    return PhoneAction('ফেসবুক খোলা হচ্ছে', Uri.https('www.facebook.com'));
  }
  if (has(['জিমেইল', 'gmail']) || (has(['ইমেইল']) && has(['খোল', 'খুল']))) {
    return PhoneAction('জিমেইল খোলা হচ্ছে', Uri.https('mail.google.com', '/mail/'));
  }
  if (has(['ক্যালেন্ডার', 'calendar'])) {
    return PhoneAction('ক্যালেন্ডার খোলা হচ্ছে', Uri.https('calendar.google.com'));
  }
  if (has(['হোয়াটসঅ্যাপ']) && has(['খোল', 'খুল'])) {
    return PhoneAction('হোয়াটসঅ্যাপ খোলা হচ্ছে', Uri.https('web.whatsapp.com'));
  }
  return null;
}
