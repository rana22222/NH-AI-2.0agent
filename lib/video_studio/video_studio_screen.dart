import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:video_player/video_player.dart';

import 'video_studio_service.dart';

enum _Tool { trim, merge, crop, filter, audio, text, compress, export }

class VideoStudioScreen extends StatefulWidget {
  const VideoStudioScreen({super.key});

  @override
  State<VideoStudioScreen> createState() => _VideoStudioScreenState();
}

class _VideoStudioScreenState extends State<VideoStudioScreen> {
  final _service = VideoStudioService();
  final _textCtrl = TextEditingController();

  VideoPlayerController? _player;
  String? _current;
  List<String> _extraVideos = [];
  String? _audioPath;

  _Tool _tool = _Tool.trim;
  RangeValues _range = const RangeValues(0, 1);
  double _durationSec = 1;
  CropRatio _ratio = CropRatio.r9x16;
  VideoFilter _filter = VideoFilter.vivid;
  double _volume = 0.4;
  int _exportHeight = 1080;

  bool _busy = false;
  String? _status;

  @override
  void dispose() {
    _player?.dispose();
    _textCtrl.dispose();
    super.dispose();
  }

  Future<void> _load(String path) async {
    final old = _player;
    final c = VideoPlayerController.file(File(path));
    await c.initialize();
    await c.setLooping(true);
    if (!mounted) {
      await c.dispose();
      return;
    }
    setState(() {
      _player = c;
      _current = path;
      _durationSec = c.value.duration.inMilliseconds / 1000.0;
      _range = RangeValues(0, _durationSec <= 0 ? 1 : _durationSec);
    });
    await old?.dispose();
  }

  Future<void> _pickVideo() async {
    final f = await FilePicker.pickFile(type: FileType.video);
    final p = f?.path;
    if (p != null) await _load(p);
  }

  Future<void> _pickExtraVideos() async {
    final files = await FilePicker.pickFiles(type: FileType.video);
    if (files.isEmpty) return;
    setState(() => _extraVideos = files.map((f) => f.path).whereType<String>().toList());
  }

  Future<void> _pickAudio() async {
    final f = await FilePicker.pickFile(type: FileType.audio);
    final p = f?.path;
    if (p != null) setState(() => _audioPath = p);
  }

  Future<void> _apply() async {
    final input = _current;
    if (input == null) {
      setState(() => _status = 'আগে একটি ভিডিও বাছাই করো।');
      return;
    }
    setState(() {
      _busy = true;
      _status = 'প্রসেস হচ্ছে… একটু অপেক্ষা করো।';
    });
    _player?.pause();

    VideoResult res;
    switch (_tool) {
      case _Tool.trim:
        res = await _service.trim(input, _range.start, _range.end);
      case _Tool.merge:
        res = await _service.merge([input, ..._extraVideos]);
      case _Tool.crop:
        res = await _service.crop(input, _ratio);
      case _Tool.filter:
        res = await _service.applyFilter(input, _filter);
      case _Tool.audio:
        if (_audioPath == null) {
          res = const VideoResult.failure('আগে একটি অডিও ফাইল বাছাই করো।');
        } else {
          res = await _service.mixAudio(input, _audioPath!, volume: _volume);
        }
      case _Tool.text:
        if (_textCtrl.text.trim().isEmpty) {
          res = const VideoResult.failure('লেখা খালি রাখা যাবে না।');
        } else {
          res = await _service.addText(input, _textCtrl.text.trim());
        }
      case _Tool.compress:
        res = await _service.compress(input);
      case _Tool.export:
        res = await _service.exportHd(input, height: _exportHeight);
    }

    if (!mounted) return;
    if (res.ok && res.path != null) {
      await _load(res.path!);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _status = 'সম্পন্ন। ফলাফল এখন প্রিভিউতে আছে।';
      });
    } else {
      setState(() {
        _busy = false;
        _status = res.message;
      });
    }
  }

  Future<void> _saveToGallery() async {
    final p = _current;
    if (p == null) return;
    try {
      final ok = await Gal.hasPermission() || await Gal.requestPermission();
      if (!ok) {
        if (mounted) setState(() => _status = 'গ্যালারিতে সেভ করার অনুমতি দেওয়া হয়নি।');
        return;
      }
      await Gal.putVideo(p);
      if (mounted) setState(() => _status = 'গ্যালারিতে সেভ হয়েছে।');
    } catch (e) {
      if (mounted) setState(() => _status = 'সেভ করা যায়নি: $e');
    }
  }

  String _fmt(double s) {
    final m = (s ~/ 60).toString().padLeft(2, '0');
    final sec = (s % 60).toStringAsFixed(1).padLeft(4, '0');
    return '$m:$sec';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('ভিডিও স্টুডিও'),
        actions: [
          IconButton(
            tooltip: 'গ্যালারিতে সেভ',
            onPressed: _current == null || _busy ? null : _saveToGallery,
            icon: const Icon(Icons.download_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _preview(cs),
          const SizedBox(height: 12),
          FilledButton.tonalIcon(
            onPressed: _busy ? null : _pickVideo,
            icon: const Icon(Icons.video_library_rounded),
            label: Text(_current == null ? 'ভিডিও বাছাই করো' : 'অন্য ভিডিও বাছাই করো'),
          ),
          const SizedBox(height: 16),
          _toolChips(),
          const SizedBox(height: 12),
          _toolOptions(),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _busy ? null : _apply,
            icon: _busy
                ? const SizedBox(
                    width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.play_arrow_rounded),
            label: Text(_busy ? 'প্রসেস হচ্ছে…' : 'প্রয়োগ করো'),
          ),
          if (_status != null) ...[
            const SizedBox(height: 12),
            Text(_status!, style: TextStyle(color: cs.onSurfaceVariant)),
          ],
          const SizedBox(height: 24),
          _backendCard(cs),
        ],
      ),
    );
  }

  Widget _preview(ColorScheme cs) {
    final p = _player;
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        color: cs.surfaceContainerHighest,
        height: 220,
        alignment: Alignment.center,
        child: p == null
            ? Text('কোনো ভিডিও নেই', style: TextStyle(color: cs.onSurfaceVariant))
            : Stack(
                alignment: Alignment.center,
                children: [
                  AspectRatio(aspectRatio: p.value.aspectRatio, child: VideoPlayer(p)),
                  IconButton.filled(
                    onPressed: () => setState(() {
                      p.value.isPlaying ? p.pause() : p.play();
                    }),
                    icon: Icon(p.value.isPlaying ? Icons.pause : Icons.play_arrow),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _toolChips() {
    const labels = {
      _Tool.trim: 'ট্রিম',
      _Tool.merge: 'মার্জ',
      _Tool.crop: 'ক্রপ',
      _Tool.filter: 'ফিল্টার',
      _Tool.audio: 'মিউজিক/ভয়েস',
      _Tool.text: 'লেখা',
      _Tool.compress: 'কমপ্রেস',
      _Tool.export: 'HD এক্সপোর্ট',
    };
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final t in _Tool.values)
          ChoiceChip(
            label: Text(labels[t]!),
            selected: _tool == t,
            onSelected: _busy ? null : (_) => setState(() => _tool = t),
          ),
      ],
    );
  }

  Widget _toolOptions() {
    switch (_tool) {
      case _Tool.trim:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${_fmt(_range.start)}  →  ${_fmt(_range.end)}'),
            RangeSlider(
              values: _range,
              min: 0,
              max: _durationSec <= 0 ? 1 : _durationSec,
              onChanged: _current == null || _busy ? null : (v) => setState(() => _range = v),
            ),
          ],
        );
      case _Tool.merge:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            OutlinedButton.icon(
              onPressed: _busy ? null : _pickExtraVideos,
              icon: const Icon(Icons.add_rounded),
              label: const Text('যোগ করার ভিডিও বাছাই করো'),
            ),
            const SizedBox(height: 6),
            Text('${_extraVideos.length}টি ভিডিও বাছাই করা হয়েছে (বর্তমান ভিডিওর পরে জোড়া লাগবে)। '
                'সব ভিডিওতে অডিও থাকতে হবে।'),
          ],
        );
      case _Tool.crop:
        return SegmentedButton<CropRatio>(
          segments: const [
            ButtonSegment(value: CropRatio.r16x9, label: Text('16:9')),
            ButtonSegment(value: CropRatio.r9x16, label: Text('9:16')),
            ButtonSegment(value: CropRatio.r1x1, label: Text('1:1')),
          ],
          selected: {_ratio},
          onSelectionChanged: (s) => setState(() => _ratio = s.first),
        );
      case _Tool.filter:
        const names = {
          VideoFilter.grayscale: 'সাদা-কালো',
          VideoFilter.warm: 'উষ্ণ',
          VideoFilter.vivid: 'উজ্জ্বল রং',
          VideoFilter.bright: 'ব্রাইট',
          VideoFilter.sepia: 'সেপিয়া',
        };
        return Wrap(
          spacing: 8,
          children: [
            for (final f in VideoFilter.values)
              ChoiceChip(
                label: Text(names[f]!),
                selected: _filter == f,
                onSelected: (_) => setState(() => _filter = f),
              ),
          ],
        );
      case _Tool.audio:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            OutlinedButton.icon(
              onPressed: _busy ? null : _pickAudio,
              icon: const Icon(Icons.music_note_rounded),
              label: Text(_audioPath == null
                  ? 'মিউজিক বা ভয়েস-ওভার ফাইল বাছাই করো'
                  : _audioPath!.split('/').last),
            ),
            Text('ভলিউম: ${(_volume * 100).round()}%'),
            Slider(value: _volume, onChanged: (v) => setState(() => _volume = v)),
            const Text('ভিডিওতে আগে থেকে অডিও ট্র্যাক থাকতে হবে।'),
          ],
        );
      case _Tool.text:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _textCtrl,
              decoration: const InputDecoration(
                labelText: 'ভিডিওর ওপর যে লেখা বসবে',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 6),
            const Text('সতর্কতা: বাংলা যুক্তাক্ষর এই পদ্ধতিতে ভুলভাবে দেখা যেতে পারে। ইংরেজি লেখা নিরাপদ।'),
          ],
        );
      case _Tool.compress:
        return const Text('ভিডিও ৭২০p-এ ছোট করে ফাইলের আকার কমানো হবে।');
      case _Tool.export:
        return SegmentedButton<int>(
          segments: const [
            ButtonSegment(value: 720, label: Text('720p')),
            ButtonSegment(value: 1080, label: Text('1080p')),
          ],
          selected: {_exportHeight},
          onSelectionChanged: (s) => setState(() => _exportHeight = s.first),
        );
    }
  }

  Widget _backendCard(ColorScheme cs) {
    const items = [
      'টেক্সট-টু-ভিডিও',
      'ইমেজ-টু-ভিডিও',
      'AI ভিডিও এনহান্সমেন্ট',
      'অটো সাবটাইটেল (বাংলা speech-to-text)',
    ];
    return Card(
      color: cs.surfaceContainerHigh,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('backend/API integration এখনো লাগবে',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            for (final i in items)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(children: [
                  const Icon(Icons.lock_clock_rounded, size: 16),
                  const SizedBox(width: 8),
                  Expanded(child: Text(i)),
                ]),
              ),
            const SizedBox(height: 8),
            const Text('এই ফিচারগুলো paid AI সার্ভিস ও নিরাপদ backend ছাড়া কাজ করবে না, তাই নকল রেজাল্ট দেখানো হয় না।'),
          ],
        ),
      ),
    );
  }
}
