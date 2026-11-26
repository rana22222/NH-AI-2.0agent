import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'ai_service.dart';

const Color _ysSurface = Color(0xFF13151E);
const Color _ysBorder = Color(0xFF222636);
const Color _ysMuted = Color(0xFF8A8FA3);
const Color _ysAccent = Color(0xFF36E3C4);

class YoutubeStudioPage extends StatefulWidget {
  const YoutubeStudioPage({super.key});

  @override
  State<YoutubeStudioPage> createState() =>
      _YoutubeStudioPageState();
}

class _YoutubeStudioPageState extends State<YoutubeStudioPage> {
  final TextEditingController _topic = TextEditingController();
  final TextEditingController _instruction = TextEditingController();
  final TextEditingController _script = TextEditingController();

  final FlutterTts _tts = FlutterTts();

  String _output = '';
  String _mode = 'full';
  String _length = '৬০ সেকেন্ড';

  bool _busy = false;

  static const List<(String, String, IconData)> _agents = [
    ('ideas', 'ভিডিও আইডিয়া এজেন্ট', Icons.lightbulb_outline),
    ('script', 'স্ক্রিপ্ট রাইটার এজেন্ট', Icons.edit_note),
    ('seo', 'YouTube SEO এজেন্ট', Icons.search),
    ('thumbnail', 'টাইটেল ও থাম্বনেইল এজেন্ট', Icons.image_outlined),
    ('scenes', 'সিন ও মোশন প্ল্যানার', Icons.movie_creation_outlined),
    ('shorts', 'Shorts Creator এজেন্ট', Icons.smartphone),
    ('full', 'সম্পূর্ণ ভিডিও প্রডিউসার', Icons.auto_awesome),
  ];

  @override
  void dispose() {
    _topic.dispose();
    _instruction.dispose();
    _script.dispose();
    _tts.stop();
    super.dispose();
  }

  void _message(String
