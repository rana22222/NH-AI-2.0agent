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
  final TextEditingController _topic = TextEditingController();
  final TextEditingController _instruction = TextEditingController();
  final TextEditingController _script = TextEditingController();
  final FlutterTts _tts = FlutterTts();
  String _output = '';
  String _mode = 'full';
  String _length = '৬০ সেকেন্ড';
  bool _busy = false;

  static const List&lt;(String, String, IconData)&gt; _agents = [
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

  void _message(String value) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
  }

  String _buildPrompt() {
    final String topic = _topic.text.trim().isEmpty
        ? 'ব্যবহারকারীর নির্দেশনা থেক বিষয নির ধার করো'
        : _topic.text.trim();
    final String instruction = _instruction.text.trim();
    final String common = '''
তুমি NH AI Agent-র দকষ YouTube Creator Team।
ভিডিওর বিষয: ''' + topic + '''
ভিডিওর দৈরঘ: ''' + _length + '''
ব্যবহারকারীর নিরদেশনা: ''' +
        (instruction.isEmpty ? 'সেরা ফলাফল দাও' : instruction) + '''
সহজ, স্বাভাবিক ও শ্রুতিমধুর বাংলায় লিখব। মৌলিক ও তথ্যনিভর কন্টেন্ট দেব।
তথ্য, পরিসংখ্যান, সার্চ ভলিউম বা উদ্ধৃতি বানিয়ে বলব না। অনিশ্চিত তথ্য স্পষ্ট করব।
শিরোনাম ও ধাপে ধাপে সাজানো ব্যবহারযোগ্য আউটপুট দেব।
''';
    switch (_mode) {
      case 'ideas':
        return common + '\n১০টি মৌলিক ভিডিও আইডিয়া দাও। প্রতিটির হুক, শিরোনাম, দর্শক কেন দেখবে ও ফরম্যাট লিখে সেরা ৩টি র‍্যাংক করো।';
      case 'script':
        return common + '\nপ্রথম ৩ সেকেন্ডের হুক, পূর্ণ ভয়েসওভার, দৃশ্য নিরদেশনা, দর্শক ধরে রাখার কৌশল ও শেষে CTA-সহ স্ক্রিপ্ট লেখো।';
      case 'seo':
        return common + '\n৫টি YouTube title, SEO description, ১৫টি tag, ৩টি keyword phrase, hashtag ও chapter দাও। ভুয়া search volume দেবে না।';
      case 'thumbnail':
        return common + '\n১০টি title এবং ৫টি thumbnail concept দাও। thumbnail text, composition, subject, background, lighting ও image prompt লিখো। বিভ্রান্তিকর clickbait এড়াও।';
      case 'scenes':
        return common + '\nসময়সহ storyboard বানাও। প্রতিটি দৃশ্যে visual/action, subject motion, camera movement, framing, lighting, screen text, voiceover, transition ও sound cue দাও। শেষে asset checklist ও image/video prompts দাও।';
      case 'shorts':
        return common + '\n৯:১৬ YouTube Shorts script লেখো। প্রথম ২ সেকেন্ডে hook, দ্রুত pacing, ছোট বাক্য, scene-by-scene visual, captions, payoff ও CTA রাখো।';
      default:
        return common + '\nসম্পূর্ণ YouTube production pack দাও: content angle, hook, পূর্ণ script, timed storyboard, visual prompts, voiceover notes, subtitle text, title, description, tags, hashtags, thumbnail concept ও CTA। শেষে production checklist দাও।';
    }
  }

  Future&lt;void&gt; _runAgent() async {
    if (_topic.text.trim().isEmpty && _instruction.text.trim().isEmpty) {
      _message('ভিডিওর বিষয় অথবা AI-কে নিরদেশনা লিখুন।');
      return;
    }
    setState(() { _busy = true; _output = ''; });
    final String result = await AiService.ask(_buildPrompt());
    if (!mounted) return;
    setState(() { _output = result; _busy = false; });
  }

  Future&lt;void&gt; _copyOutput() async {
    if (_output.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: _output));
    _message('ফলাফল কপি হয়েছ।');
  }

  Future&lt;void&gt; _speakOutput() async {
    if (_output.isEmpty) return;
    await _tts.setLanguage('bn-BD');
    await _tts.setSpeechRate(0.48);
    await _tts.speak(_output);
  }

  Future&lt;void&gt; _makeSrt() async {
    final String text = _script.text.trim();
    if (text.isEmpty) {
      _message('আগে স্ক্রিপ্ট বক্সে লেখা দিন।');
      return;
    }
    final List&lt;String&gt; sentences = text.replaceAll('\r', '')
        .split(RegExp(r'(?&lt;=[.!?।])\s+|\n+'))
        .map((String s) => s.trim())
        .where((String s) => s.isNotEmpty).toList();
    int cursor = 0;
    String stamp(int seconds) {
      final String h = (seconds ~/ 3600).toString().padLeft(2, '0');
      final String m = ((seconds % 3600) ~/ 60).toString().padLeft(2, '0');
      final String s = (seconds % 60).toString().padLeft(2, '0');
      return h + ':' + m + ':' + s + ',000';
    }
    final List&lt;String&gt; lines = [];
    for (int i = 0; i &lt; sentences.length; i++) {
      final int duration = (sentences[i].length / 12).ceil().clamp(2, 7).toInt();
      lines.add((i + 1).toString() + '\n' + stamp(cursor) + ' --> ' +
          stamp(cursor + duration) + '\n' + sentences[i]);
      cursor += duration;
    }
    setState(() { _output = lines.join('\n\n'); });
    await Clipboard.setData(ClipboardData(text: _output));
    _message('SRT তৈরি ও কপি হয়েছে। টাইমিং ভিডিওর সাথে মিলিয়ে নেবেন।');
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: const LinearGradient(colors: [Color(0xFF26345E), Color(0xFF164B4B)]),
          ),
          child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(Icons.smart_display, size: 28),
              SizedBox(width: 10),
              Text('NH YouTube AI Studio', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            ]),
            SizedBox(height: 8),
            Text('একটি জায়গা থেকেই AI-কে নিরদেশ দিন। আইডিয়া, স্ক্রিপ্ট, SEO, থাম্বনেইল ও ভিডিও পরিকল্পনা।'),
          ]),
        ),
        const SizedBox(height: 18),
        const Text('ভিডিওর বিষয়', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 7),
        TextField(controller: _topic, maxLines: 2, decoration: const InputDecoration(
          hintText: 'যেমন: ইসলামিক শিক্ষা, প্রযুক্তি, ভ্রমণ…', filled: true)),
        const SizedBox(height: 12),
        DropdownButtonFormField&lt;String&gt;(
          value: _length,
          decoration: const InputDecoration(labelText: 'ভিডিওর দৈর্ঘ্য', filled: true),
          items: const [
            DropdownMenuItem(value: '৩০ সেকেন্ড', child: Text('৩০ সেকেন্ড')),
            DropdownMenuItem(value: '৬০ সেকেন্ড', child: Text('৬০ সেকেন্ড')),
            DropdownMenuItem(value: '৩ মিনিট', child: Text('৩ মিনিট')),
            DropdownMenuItem(value: '৫ মিনিট', child: Text('৫ মিনিট')),
            DropdownMenuItem(value: '৮-১০ মিনিট', child: Text('৮-১০ মিনিট')),
          ],
          onChanged: (String? value) => setState(() => _length = value ?? '৬০ সেকেন্ড'),
        ),
        const SizedBox(height: 18),
        const Text('আপনার YouTube AI Agents', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        for (final agent in _agents)
          Card(
            color: _mode == agent.$1 ? const Color(0xFF202A46) : _ysSurface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: _mode == agent.$1 ? _ysAccent : _ysBorder),
            ),
            child: ListTile(
              leading: Icon(agent.$3, color: _mode == agent.$1 ? _ysAccent : _ysMuted),
              title: Text(agent.$2),
              trailing: _mode == agent.$1
                  ? const Icon(Icons.check_circle, color: _ysAccent)
                  : const Icon(Icons.chevron_right),
              onTap: () => setState(() => _mode = agent.$1),
            ),
          ),
        const SizedBox(height: 14),
        const Text('AI-কে আপনার নিরদেশনা দিন', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 7),
        TextField(controller: _instruction, minLines: 3, maxLines: 6,
          decoration: const InputDecoration(
            hintText: 'যেমন: ১ মিনিটের ইসলামিক Shorts বানাও, ৫টি দৃশ্য দাও, আবেগপূর্ণ ভয়েসওভার ও SEO title তৈরি করো…',
            filled: true)),
        const SizedBox(height: 10),
        SizedBox(
          height: 54,
          child: FilledButton.icon(
            onPressed: _busy ? null : _runAgent,
            icon: _busy
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.send_rounded),
            label: Text(_busy ? 'YouTube AI কাজ করছে…' : 'YouTube AI-কে নিরদেশ দিন'),
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _busy ? null : _runAgent,
          icon: const Icon(Icons.auto_awesome),
          label: const Text('নির্বাচিত Agent চালু করুন'),
        ),
        const SizedBox(height: 20),
        const Text('স্ক্রিপ্ট থেকে সাবটাইটেল', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        TextField(controller: _script, minLines: 3, maxLines: 6,
          decoration: const InputDecoration(hintText: 'স্ক্রিপ্ট এখানে পেস্ট করুন…', filled: true)),
        const SizedBox(height: 8),
        OutlinedButton.icon(onPressed: _makeSrt,
          icon: const Icon(Icons.subtitles_outlined), label: const Text('SRT সাবটাইটেল তৈরি ও কপি')),
        if (_output.isNotEmpty) ...[
          const SizedBox(height: 18),
          const Text('AI-এর ফলাফল', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: _ysSurface, borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _ysBorder)),
            child: SelectableText(_output, style: const TextStyle(height: 1.55)),
          ),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            OutlinedButton.icon(onPressed: _copyOutput, icon: const Icon(Icons.copy), label: const Text('কপি')),
            OutlinedButton.icon(onPressed: _speakOutput, icon: const Icon(Icons.volume_up), label: const Text('শুনুন')),
            OutlinedButton.icon(onPressed: () => _tts.stop(), icon: const Icon(Icons.stop), label: const Text('বন্ধ')),
            OutlinedButton.icon(onPressed: () => setState(() => _script.text = _output),
              icon: const Icon(Icons.edit_note), label: const Text('স্ক্রিপ্টে নিন')),
          ]),
        ],
        const SizedBox(height: 14),
        const Text(
          'এই পেজটি বর্তমানে অ্যাপের Gemini AI সার্ভিস ব্যবহার করে লেখা ও পরিকল্পনা তৈরি করে। vidIQ-এর লাইভ চ্যানেল অ্যানালিটিক্স/পাবলিশিং এবং MP4 রেন্ডার চালাতে আলাদা অনুমোদিত সংযোগ প্রয়োজন।',
          style: TextStyle(color: _ysMuted, fontSize: 12, height: 1.5)),
      ],
    );
  }
}
