import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter/webview_flutter.dart';

const Color _kBg = Color(0xFF07080D);
const Color _kMuted = Color(0xFF8A8FA3);

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

  Future<void> _replay() async {
    final String? name = _selectedRecording;
    if (name == null || _saved[name] == null) {
      _snack('কোনো সেভ করা কাজ নেই');
      return;
    }
    final List<Map<String, dynamic>> steps = (_saved[name] as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

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
                  onPressed: _saved.isEmpty ? null : _replay,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('রিপ্লে'),
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
