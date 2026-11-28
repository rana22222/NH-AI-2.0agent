import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter/webview_flutter.dart';

const Color _kBg = Color(0xFF07080D);
const Color _kMuted = Color(0xFF8A8FA3);

const String _geminiModel = 'gemini-3.5-flash-lite';
const String _geminiKey = String.fromEnvironment('GEMINI_API_KEY');

// Injected into every page. Reports user input and clicks to Flutter.
const String _kRecorderJs = r'''
(function () {
  if (window.__nhRec) return;
  window.__nhRec = true;
  function sel(el) {
    if (el.id) return '#' + CSS.escape(el.id);
    var parts = [];
    var n = el;
    while (n && n.nodeType === 1 && n !== document.body && n !== document.documentElement) {
      var idx = 1;
      var s = n;
      while ((s = s.previousElementSibling)) { if (s.tagName === n.tagName) idx++; }
      parts.unshift(n.tagName.toLowerCase() + ':nth-of-type(' + idx + ')');
      n = n.parentElement;
    }
    return 'body > ' + parts.join(' > ');
  }
  function send(obj) {
    try { Recorder.postMessage(JSON.stringify(obj)); } catch (e) {}
  }
  document.addEventListener('change', function (e) {
    var t = e.target;
    if (!t || !t.tagName) return;
    var v = (t.type === 'checkbox' || t.type === 'radio') ? String(t.checked) : (t.value || '');
    send({type: 'input', selector: sel(t), value: v, label: t.name || t.placeholder || t.id || t.tagName});
  }, true);
  document.addEventListener('click', function (e) {
    var t = e.target;
    if (!t || !t.tagName) return;
    if (t.tagName === 'INPUT' || t.tagName === 'TEXTAREA' || t.tagName === 'SELECT') return;
    var text = (t.innerText || t.value || t.tagName || '').toString().trim().slice(0, 40);
    send({type: 'click', selector: sel(t), label: text});
  }, true);
})();
''';

class WebStudioPage extends StatefulWidget {
  const WebStudioPage({super.key});

  @override
  State<WebStudioPage> createState() => _WebStudioPageState();
}

class _WebStudioPageState extends State<WebStudioPage> {
  static const String _prefsKey = 'web_recordings_v1';
  final TextEditingController _urlCtrl =
      TextEditingController(text: 'https://www.google.com');
  late final WebViewController _web;
  final List<Map<String, dynamic>> _steps = <Map<String, dynamic>>[];
  Map<String, dynamic> _saved = <String, dynamic>{};
  String? _selectedRecording;
  bool _recording = false;
  bool _submit = false;
  bool _filling = false;
  String _status = 'একটি ওয়েবসাইট খুলুন';

  @override
  void initState() {
    super.initState();
    _web = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel('Recorder', onMessageReceived: _onRecorded)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String _) async {
            await _web.runJavaScript(_kRecorderJs);
            if (mounted) setState(() => _status = 'পেজ লোড হয়েছে');
          },
        ),
      );
    _web.loadRequest(Uri.parse(_urlCtrl.text));
    _loadSaved();
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    super.dispose();
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _loadSaved() async {
    final prefs = await SharedPreferences.getInstance();
    final String? raw = prefs.getString(_prefsKey);
    if (raw == null || !mounted) return;
    setState(() {
      _saved = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      if (_saved.isNotEmpty) _selectedRecording = _saved.keys.first;
    });
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(_saved));
  }

  void _onRecorded(JavaScriptMessage msg) {
    if (!_recording) return;
    try {
      final Map<String, dynamic> data =
          Map<String, dynamic>.from(jsonDecode(msg.message) as Map);
      setState(() => _steps.add(data));
    } catch (_) {}
  }

  void _go() {
    String u = _urlCtrl.text.trim();
    if (u.isEmpty) return;
    if (!u.startsWith('http')) u = 'https://$u';
    setState(() => _status = 'লোড হচ্ছে…');
    _web.loadRequest(Uri.parse(u));
  }

  void _toggleRecording() {
    setState(() {
      _recording = !_recording;
      if (_recording) _steps.clear();
      _status = _recording
          ? 'রেকর্ড চলছে। ওয়েবপেজে লেখা ও ক্লিক করুন'
          : 'রেকর্ড বন্ধ';
    });
  }

  Future<void> _saveRecording() async {
    if (_steps.isEmpty) {
      _snack('আগে কিছু রেকর্ড করুন');
      return;
    }
    final String? name = await showDialog<String>(
      context: context,
      builder: (BuildContext ctx) {
        final TextEditingController c =
            TextEditingController(text: 'কাজ ${_saved.length + 1}');
        return AlertDialog(
          title: const Text('নাম দিন'),
          content: TextField(controller: c, autofocus: true),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('বাতিল'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, c.text.trim()),
              child: const Text('সেভ'),
            ),
          ],
        );
      },
    );
    if (name == null || name.isEmpty) return;
    setState(() {
      _saved[name] = _steps.map((s) => Map<String, dynamic>.from(s)).toList();
      _selectedRecording = name;
    });
    await _persist();
    _snack('"$name" সেভ হয়েছে');
  }

  List<Map<String, dynamic>> _stepsOf(String name) {
    return (_saved[name] as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  Future<void> _replay() async {
    final String? name = _selectedRecording;
    if (name == null || _saved[name] == null) {
      _snack('কোনো সেভ করা কাজ নেই');
      return;
    }
    final List<Map<String, dynamic>> steps = _stepsOf(name);

    // Ask for the values to type in before running.
    final Map<int, TextEditingController> values = <int, TextEditingController>{};
    for (int i = 0; i < steps.length; i++) {
      if (steps[i]['type'] == 'input') {
        values[i] = TextEditingController(text: '${steps[i]['value'] ?? ''}');
      }
    }
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          title: const Text('মান দিন'),
          content: SizedBox(
            width: 320,
            child: SingleChildScrollView(
              child: values.isEmpty
                  ? const Text('এই কাজে লেখার ঘর নেই। সরাসরি চালানো হবে।')
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final e in values.entries)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: TextField(
                              controller: e.value,
                              decoration: InputDecoration(
                                labelText: '${steps[e.key]['label'] ?? 'ঘর'}',
                                border: const OutlineInputBorder(),
                              ),
                            ),
                          ),
                      ],
                    ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('বাতিল'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('চালাও'),
            ),
          ],
        );
      },
    );
    if (ok != true) return;

    setState(() => _status = 'রিপ্লে চলছে…');
    for (int i = 0; i < steps.length; i++) {
      final Map<String, dynamic> s = steps[i];
      final String sel = jsonEncode('${s['selector']}');
      final String js;
      if (s['type'] == 'input') {
        final String v = jsonEncode(values[i]?.text ?? '${s['value'] ?? ''}');
        js = '(function(){var el=document.querySelector($sel);'
            'if(!el) return;el.focus();el.value=$v;'
            'el.dispatchEvent(new Event("input",{bubbles:true}));'
            'el.dispatchEvent(new Event("change",{bubbles:true}));})();';
      } else {
        js = '(function(){var el=document.querySelector($sel);if(el) el.click();})();';
      }
      await _web.runJavaScript(js);
      await Future<void>.delayed(const Duration(milliseconds: 900));
    }
    if (mounted) setState(() => _status = 'রিপ্লে শেষ');
  }

  // Ask Gemini to read a document and return {field label: value}.
  Future<Map<String, String>> _extract(PlatformFile f, List<String> labels) async {
    final String ext = (f.extension ?? '').toLowerCase();
    final Uint8List bytes = f.bytes ?? Uint8List(0);
    final String prompt =
        'এই ডকুমেন্ট থেকে নিচের ফর্মের ঘরগুলোর মান বের করো। '
        'ফর্মের ঘরের নাম: ${labels.join(', ')}। '
        'শুধু JSON object দাও, key হবে উপরের তালিকার নাম, value হবে ডকুমেন্টে পাওয়া মান। '
        'না পেলে তা key বাদ দাও। কোনো ব্যাখ্যা লিখো না।';
    final List<Map<String, dynamic>> parts = <Map<String, dynamic>>[];
    if (ext == 'txt' || ext == 'csv') {
      parts.add({'text': '$prompt\n\nডকুমেন্ট:\n${utf8.decode(bytes, allowMalformed: true)}'});
    } else {
      final String mime = ext == 'pdf'
          ? 'application/pdf'
          : (ext == 'png' ? 'image/png' : 'image/jpeg');
      parts.add({'inlineData': {'mimeType': mime, 'data': base64Encode(bytes)}});
      parts.add({'text': prompt});
    }
    final Uri uri = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$_geminiModel:generateContent',
    );
    final http.Response res = await http
        .post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'x-goog-api-key': _geminiKey,
          },
          body: jsonEncode({
            'contents': [
              {'role': 'user', 'parts': parts},
            ],
            'generationConfig': {
              'responseMimeType': 'application/json',
              'temperature': 0.1,
            },
          }),
        )
        .timeout(const Duration(seconds: 90));
    if (res.statusCode != 200) {
      throw Exception('AI তথ্য পাঠাতে ব্যর্থ (${res.statusCode})');
    }
    final Map<String, dynamic> data = jsonDecode(res.body) as Map<String, dynamic>;
    final List<dynamic> cands = data['candidates'] as List<dynamic>? ?? <dynamic>[];
    if (cands.isEmpty) throw Exception('AI উত্তর দিল না');
    final List<dynamic> outParts =
        (cands.first as Map)['content']['parts'] as List<dynamic>;
    final String text = outParts.map((p) => '${(p as Map)['text'] ?? ''}').join();
    final Map<String, dynamic> obj = jsonDecode(
      text.replaceAll(RegExp(r'```(json)?'), '').trim(),
    ) as Map<String, dynamic>;
    return obj.map((String k, dynamic v) => MapEntry<String, String>(k, '$v'));
  }

  String _norm(String s) =>
      s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9\u0980-\u09ff]'), '');

  String? _matchValue(String label, Map<String, String> data) {
    final String l = _norm(label);
    if (l.isEmpty) return null;
    for (final MapEntry<String, String> e in data.entries) {
      final String k = _norm(e.key);
      if (k.isNotEmpty && (k == l || k.contains(l) || l.contains(k))) {
        return e.value;
      }
    }
    return null;
  }

  // Fills the saved form on the current page. Submits only if the toggle is on.
  Future<int> _fillForm(List<Map<String, dynamic>> steps, Map<String, String> data) async {
    int lastClick = -1;
    for (int i = 0; i < steps.length; i++) {
      if (steps[i]['type'] == 'click') lastClick = i;
    }
    int filled = 0;
    for (int i = 0; i < steps.length; i++) {
      final Map<String, dynamic> s = steps[i];
      final String sel = jsonEncode('${s['selector']}');
      if (s['type'] == 'input') {
        final String? v = _matchValue('${s['label'] ?? ''}', data);
        if (v == null) continue;
        final String val = jsonEncode(v);
        await _web.runJavaScript(
          '(function(){var el=document.querySelector($sel);if(!el) return;el.focus();el.value=$val;'
          'el.dispatchEvent(new Event("input",{bubbles:true}));'
          'el.dispatchEvent(new Event("change",{bubbles:true}));})();',
        );
        filled++;
        await Future<void>.delayed(const Duration(milliseconds: 300));
      } else if (s['type'] == 'click' && _submit && i == lastClick) {
        await _web.runJavaScript(
          '(function(){var el=document.querySelector($sel);if(el) el.click();})();',
        );
        await Future<void>.delayed(const Duration(seconds: 3));
      }
    }
    return filled;
  }

  Future<void> _fillFromDocuments() async {
    final String? name = _selectedRecording;
    if (name == null || _saved[name] == null) {
      _snack('আগে একটি ফর্ম রেকর্ড করে সেভ করুন');
      return;
    }
    if (_geminiKey.isEmpty) {
      _snack('AI কী নেই (GEMINI_API_KEY)');
      return;
    }
    final FilePickerResult? picked = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png', 'txt', 'csv'],
      withData: true,
    );
    if (picked == null || picked.files.isEmpty) return;

    final List<Map<String, dynamic>> steps = _stepsOf(name);
    final List<String> labels = <String>[
      for (final s in steps)
        if (s['type'] == 'input') '${s['label'] ?? ''}',
    ];

    setState(() => _filling = true);
    try {
      for (int i = 0; i < picked.files.length; i++) {
        final PlatformFile f = picked.files[i];
        setState(() => _status = '${i + 1}/${picked.files.length}: ${f.name} পড়া হচ্ছে…');
        final Map<String, String> data = await _extract(f, labels);
        setState(() => _status = '${f.name}: ${data.length}টি মান পাওয়া গেছে, বসানো হচ্ছে…');
        final int filled = await _fillForm(steps, data);
        setState(() => _status = '${f.name}: $filledটি ঘর ভরা হয়েছে');
      }
    } catch (e) {
      _snack('তথ্য ডুবে বা ফর্ম ভরা যায়নি: $e');
    } finally {
      if (mounted) setState(() => _filling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        title: const Text('ওয়েব অটোমেশন'),
        backgroundColor: _kBg,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _urlCtrl,
                    keyboardType: TextInputType.url,
                    onSubmitted: (_) => _go(),
                    decoration: const InputDecoration(
                      hintText: 'ওয়েবসাইটের ঠিকানা',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(onPressed: _go, child: const Text('যাও')),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                FilledButton.tonalIcon(
                  onPressed: _toggleRecording,
                  icon: Icon(_recording ? Icons.stop : Icons.fiber_manual_record),
                  label: Text(_recording ? 'রেকর্ড বন্ধ' : 'রেকর্ড শুরু'),
                ),
                OutlinedButton.icon(
                  onPressed: _saveRecording,
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('সেভ'),
                ),
                OutlinedButton.icon(
                  onPressed: _saved.isEmpty || _filling ? null : _replay,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('রিপ্লে'),
                ),
                FilledButton.icon(
                  onPressed: _saved.isEmpty || _filling ? null : _fillFromDocuments,
                  icon: _filling
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.upload_file),
                  label: const Text('ডকুমেন্ট দিয়ে ভরাও'),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Checkbox(
                      value: _submit,
                      onChanged: (bool? v) => setState(() => _submit = v ?? false),
                    ),
                    const Text('ভরার পর জমা দিন'),
                  ],
                ),
              ],
            ),
          ),
          if (_saved.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: DropdownButton<String>(
                value: _selectedRecording,
                isExpanded: true,
                items: [
                  for (final String k in _saved.keys)
                    DropdownMenuItem<String>(value: k, child: Text(k)),
                ],
                onChanged: (String? v) => setState(() => _selectedRecording = v),
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(_status, style: const TextStyle(color: _kMuted, fontSize: 12)),
            ),
          ),
          Expanded(child: WebViewWidget(controller: _web)),
          SizedBox(
            height: 120,
            child: _steps.isEmpty
                ? const Center(
                    child: Text('এখনো কিছু রেকর্ড হয়নি', style: TextStyle(color: _kMuted)),
                  )
                : ListView.builder(
                    itemCount: _steps.length,
                    itemBuilder: (BuildContext c, int i) {
                      final Map<String, dynamic> s = _steps[i];
                      final bool isInput = s['type'] == 'input';
                      return ListTile(
                        dense: true,
                        leading: Icon(
                          isInput ? Icons.edit_outlined : Icons.touch_app_outlined,
                          size: 18,
                        ),
                        title: Text('${s['label'] ?? ''}'),
                        subtitle: isInput ? Text('${s['value'] ?? ''}') : null,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
