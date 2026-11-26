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
  State&lt;YoutubeStudioPage&gt; createState() => _YoutubeStudioPageState();
}

class _YoutubeStudioPageState extends State&lt;YoutubeStudioPage&gt; {
  final _topic = TextEditingController();
  final _script = TextEditingController();
  final _tts = FlutterTts();
  String _output = '';
  String _mode = 'full';
  String _length = '৬০ সেকেন্ড';
  bool _busy = false;

  @override
  void dispose() {
    _topic.dispose();
    _script.dispose();
    _tts.stop();
    super.dispose();
  }

  void _message(String value) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
  }

  Future&lt;void&gt; _generate() async {
    final topic = _topic.text.trim();
    if (topic.isEmpty) {
      _message('আগে ভিডিওর বিষয় লিখুন।');
      return;
    }
    setState(() { _busy = true; _output = ''; });
    final common = '''
তুমি একজন অভিজ্ঞ বাংলা YouTube Creator Assistant।
বিষয়: $topic
ভিডিওর দৈর্ঘ্য: $_length
সহজ, স্বাভাবিক, শ্রুতিমধুর বাংলায় লিখবে। মৌলিক ও তথ্যনির্ভর কনটেন্ট দেব।
ভুয়া তথ্য, বানানো উদ্ধৃতি বা ভুয়া পরিসংখ্যান দেব না।
''';
    late final String prompt;
    switch (_mode) {
      case 'ideas':
        prompt = '''$common
এই বিষযে ১০টি আলাদা ভিডেও আইডিয়া দাও। প্রতিটির হুক, সম্ভাব্য শিরোনাম, দর্শক কেন দেখবে এবং উপযুক্ত ফরম্যাট লিখবে। শেষে সেরা ৩টি রেঙ্ক করো।''';
        break;
      case 'seo':
        prompt = '''$common
YouTube SEO প্যাকেজ দাও: ৫টি শিরোনাম, প্রথম দুই লাইন শক্তিশালী রেখে বর্ণনা, ১০-১৫টি প্রাসঙ্গিক ট্যাগ, ৩টি সার্চ কিওয়ার্ড এবং ৩টি থাম্বনেইল টেক্সট। কোনো সার্চ ভলিউম বানিয়ে বলবে না।''';
        break;
      case 'scenes':
        prompt = '''$common
সময়, ভিজ্যুয়াল, ক্যামেরা/মোশন, স্ক্রিন টেক্সট, ভয়েসওভার ও ট্রানজিশনসহ দৃশ্যভিত্তিক storyboard তৈরি করো। শেষে ফুটেজ/ছবির তালিকা দাও।''';
        break;
      case 'shorts':
        prompt = '''$common
একটি YouTube Shorts স্ক্রিপ্ট লেখো। প্রথম ২ সেকেন্ডে আকর্ষণীয় হুক, ছোট বাক্য, দ্রুত দৃশ্য পরিবর্তন এবং শেষে payoff ও CTA রাখবে। দৃশ্য নির্দেশনা ও স্ক্রিন টেক্সটও দাও।''';
        break;
      default:
        prompt = '''$common
সম্পূর্ণ ভিডেও প্যাকেজ তৈরি করো: ওপেনিং হুক, পূর্ণ ভয়েসওভার স্ক্রিপ্ট, সময়সহ storyboard, প্রতিটি দৃশ্যের ছবি/ভিডেও তৈরির prompt, ব্যাকগ্রাউন্ড সাউন্ড ও ট্রানজিশন পরামর্শ, CTA, YouTube title, description, tags এবং thumbnail text।''';
    }
    final result = await AiService.ask(prompt);
    if (!mounted) return;
    setState(() { _output = result; _busy = false; });
  }

  Future&lt;void&gt; _makeSrt() async {
    final text = _script.text.trim();
    if (text.isEmpty) {
      _message('আগে স্ক্রিপ্ট বক্সে লেখা দিন।');
      return;
    }
    final sentences = text.replaceAll('\r', '')
        .split(RegExp(r'(?&lt;=[.!?।])\s+|\n+'))
        .map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    var cursor = 0;
    String stamp(int seconds) {
      final h = (seconds ~/ 3600).toString().padLeft(2, '0');
      final m = ((seconds % 3600) ~/ 60).toString().padLeft(2, '0');
      final s = (seconds % 60).toString().padLeft(2, '0');
      return '$h:$m:$s,000';
    }
    final lines = &lt;String&gt;[];
    for (var i = 0; i &lt; sentences.length; i++) {
      final duration = (sentences[i].length / 12).ceil().clamp(2, 7);
      lines.add('${i + 1}\n${stamp(cursor)} --> ${stamp(cursor + duration)}\n${sentences[i]}');
      cursor += duration;
    }
    setState(() { _output = lines.join('\n\n'); });
    await Clipboard.setData(ClipboardData(text: _output));
    _message('SRT তৈরি ও কপি হয়েছে। সময়গুলো আনুমানিক—ভিডেওর সাথে মিলিয়ে নেবেন।');
  }

  Future&lt;void&gt; _copy() async {
    if (_output.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: _output));
    _message('লেখা কপি হয়েছে।');
  }

  Future&lt;void&gt; _speak() async {
    if (_output.isEmpty) return;
    await _tts.setLanguage('bn-BD');
    await _tts.setSpeechRate(0.48);
    await _tts.speak(_output);
  }

  @override
  Widget build(BuildContext context) {
    final options = &lt;(String, String, IconData)&gt;[
      ('full', 'সম্পূর্ণ ভিডেও প্যাকেজ', Icons.movie_creation_outlined),
      ('ideas', 'ভিডেও আইডিয়া', Icons.trending_up),
      ('seo', 'YouTube SEO', Icons.search),
      ('scenes', 'সিন ও মোশন প্ল্যান', Icons.video_camera_back_outlined),
      ('shorts', 'Shorts স্ক্রিপ্ট', Icons.smartphone),
    ];
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: const LinearGradient(colors: [Color(0xFF26345E), Color(0xFF164B4B)]),
          ),
          child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('YouTube AI Studio', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            SizedBox(height: 6),
            Text('আইডিয়া, স্ক্রিপ্ট, দৃশ্য পরিকল্পনা, SEO ও সাবটাইটেল—এক জায়গায়।'),
          ]),
        ),
        const SizedBox(height: 14),
        TextField(controller: _topic, maxLines: 2, decoration: const InputDecoration(
          labelText: 'ভিডেওর বিষয়', hintText: 'যেমন: মোবাইল দিয়ে সুন্দর ভিডেও বানানোর উপায়', filled: true)),
        const SizedBox(height: 10),
        DropdownButtonFormField&lt;String&gt;(
          value: _length,
          decoration: const InputDecoration(labelText: 'ভিডেওর দৈর্ঘ্য', filled: true),
          items: const [
            DropdownMenuItem(value: '৩০ সেকেন্ড', child: Text('৩০ সেকেন্ড')),
            DropdownMenuItem(value: '৬০ সেকেন্ড', child: Text('৬০ সেকেন্ড')),
            DropdownMenuItem(value: '৩ মিনিট', child: Text('৩ মিনিট')),
            DropdownMenuItem(value: '৫ মিনিট', child: Text('৫ মিনিট')),
            DropdownMenuItem(value: '৮-১০ মিনিট', child: Text('৮-১০ মিনিট')),
          ],
 onChanged: (v) => setState(() { _length = v ?? '৬০ সেকেন্ড'; }),
        ),
        const SizedBox(height: 14),
        const Text('কী তৈরি করতে চান?', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        for (final option in options)
          Card(
 color: _mode == option.$1 ? const Color(0xFF202A46) : _ysSurface,
            child: ListTile(
              leading: Icon(option.$3, color: _mode == option.$1 ? _ysAccent : _ysMuted),
              title: Text(option.$2),
 trailing: _mode == option.$1 ? const Icon(Icons.check_circle, color: _ysAccent) : null,
              onTap: () => setState(() { _mode = option.$1; }),
            ),
          ),
        FilledButton.icon(
 onPressed: _busy ? null : _generate,
 icon: _busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.auto_awesome),
 label: Text(_busy ? 'AI তৈরি করছে…' : 'AI দিয়ে তৈরি করুন'),
        ),
        const SizedBox(height: 18),
        const Text('স্ক্রিপ্ট থেকে সাবটাইটেল', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
 TextField(controller: _script, minLines: 3, maxLines: 6, decoration: const InputDecoration(
 hintText: 'AI তৈরি করা স্ক্রিপ্ট এখানে পেস্ট করুন…', filled: true)),
        const SizedBox(height: 8),
 OutlinedButton.icon(onPressed: _makeSrt, icon: const Icon(Icons.subtitles_outlined), label: const Text('SRT সাবটাইটেল তৈরি ও কপি')),
        if (_output.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Text('তৈরি ফলাফল', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Container(
 padding: const EdgeInsets.all(14),
 decoration: BoxDecoration(color: _ysSurface, borderRadius: BorderRadius.circular(14), border: Border.all(color: _ysBorder)),
 child: SelectableText(_output, style: const TextStyle(height: 1.55)),
          ),
          const SizedBox(height: 8),
 Wrap(spacing: 8, children: [
 OutlinedButton.icon(onPressed: _copy, icon: const Icon(Icons.copy), label: const Text('কপি')),
 OutlinedButton.icon(onPressed: _speak, icon: const Icon(Icons.volume_up), label: const Text('শুনুন')),
 OutlinedButton.icon(onPressed: () => _tts.stop(), icon: const Icon(Icons.stop), label: const Text('বন্ধ')),
 OutlinedButton.icon(onPressed: () => setState(() { _script.text = _output; }), icon: const Icon(Icons.edit_note), label: const Text('স্ক্রিপ্টে নিন')),
          ]),
        ],
        const SizedBox(height: 14),
        const Text(
          'নোট: এই সংস্করণ AI দিয়ে লেখা, পরিকল্পনা ও SRT তৈরি করে। এখনো নিজের থেকে MP4 ভিডেও রেন্ডার, ফুটেজ তৈরি বা YouTube-এ আপলোড করে না। AI ব্যবহারে ইন্টারনেট ও বৈধ API key প্রয়োজন।',
 style: TextStyle(color: _ysMuted, fontSize: 12, height: 1.5),
        ),
      ],
    );
  }
}
