import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

const Color _kBg = Color(0xFF07080D);
const Color _kSurface = Color(0xFF13151E);
const Color _kBorder = Color(0xFF222636);
const Color _kMuted = Color(0xFF8A8FA3);
const Color _kAccentB = Color(0xFF36E3C4);

enum ScanFilter { original, grayscale, blackWhite }

class ScanPageItem {
  ScanPageItem(this.file);
  final File file;
  ScanFilter filter = ScanFilter.blackWhite;
  int quarterTurns = 0;
}

// Rotate, apply filter, re-encode as JPEG.
Uint8List _renderPage(Uint8List bytes, int turns, int filterIndex) {
  img.Image? image = img.decodeImage(bytes);
  if (image == null) return bytes;

  if (turns % 4 != 0) {
    image = img.copyRotate(image, angle: (turns % 4) * 90);
  }

  final filter = ScanFilter.values[filterIndex];
  if (filter != ScanFilter.original) {
    image = img.grayscale(image);
    image = img.adjustColor(image, contrast: 1.3);
  }
  if (filter == ScanFilter.blackWhite) {
    num sum = 0;
    for (final p in image) {
      sum += img.getLuminance(p);
    }
    final double threshold = (sum / (image.width * image.height)) * 0.92;
    for (final p in image) {
      final int v = img.getLuminance(p) > threshold ? 255 : 0;
      p.r = v;
      p.g = v;
      p.b = v;
    }
  }

  return Uint8List.fromList(img.encodeJpg(image, quality: 85));
}

class DocScannerPage extends StatefulWidget {
  const DocScannerPage({super.key});

  @override
  State<DocScannerPage> createState() => _DocScannerPageState();
}

class _DocScannerPageState extends State<DocScannerPage> {
  final List<ScanPageItem> _pages = <ScanPageItem>[];
  int _selected = 0;
  bool _busy = false;

  ScanPageItem? get _current =>
      _pages.isEmpty ? null : _pages[_selected.clamp(0, _pages.length - 1)];

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _addPage(ImageSource source) async {
    try {
      final XFile? picked = await ImagePicker().pickImage(
        source: source,
        imageQuality: 92,
        maxWidth: 2200,
      );
      if (picked == null) return;
      setState(() {
        _pages.add(ScanPageItem(File(picked.path)));
        _selected = _pages.length - 1;
      });
    } catch (_) {
      _snack('ছবি নেওয়া যায়নি, আবার চেষ্টা করো');
    }
  }

  Future<Uint8List> _renderFor(ScanPageItem p) async {
    final Uint8List bytes = await p.file.readAsBytes();
    return _renderPage(bytes, p.quarterTurns, p.filter.index);
  }

  Future<void> _exportPdf() async {
    if (_pages.isEmpty || _busy) return;
    setState(() => _busy = true);
    try {
      final doc = pw.Document();
      for (final p in _pages) {
        final image = pw.MemoryImage(await _renderFor(p));
        doc.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            margin: pw.EdgeInsets.zero,
            build: (_) => pw.FullPage(
              ignoreMargins: true,
              child: pw.Image(image, fit: pw.BoxFit.contain),
            ),
          ),
        );
      }
      final dir = await getApplicationDocumentsDirectory();
      final out = File(
        '${dir.path}/scan_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );
      await out.writeAsBytes(await doc.save());
      if (!mounted) return;
      await Share.shareXFiles(
        [XFile(out.path, mimeType: 'application/pdf')],
        text: 'স্ক্যান করা ডকুমেন্ট',
      );
    } catch (_) {
      _snack('PDF বানানো যায়নি, আবার চেষ্টা করো');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _removeSelected() {
    if (_pages.isEmpty) return;
    setState(() {
      _pages.removeAt(_selected);
      if (_selected >= _pages.length) _selected = _pages.length - 1;
      if (_selected < 0) _selected = 0;
    });
  }

  void _rotateSelected() {
    final p = _current;
    if (p == null) return;
    setState(() => p.quarterTurns = (p.quarterTurns + 1) % 4);
  }

  void _setFilter(ScanFilter f) {
    final p = _current;
    if (p == null) return;
    setState(() => p.filter = f);
  }

  String _filterLabel(ScanFilter f) {
    switch (f) {
      case ScanFilter.original:
        return 'আসল';
      case ScanFilter.grayscale:
        return 'গ্রেস্কেল';
      case ScanFilter.blackWhite:
        return 'সাদা-কালো';
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _current;
    return Container(
      color: _kBg,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          const Text(
            'ডকুমেন্ট স্ক্যানার',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          const Text(
            'ছবি তুলুন, ফিল্টার দিন, তারপর PDF বানিয়ে শেয়ার করুন।',
            style: TextStyle(fontSize: 12, color: _kMuted),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _busy ? null : () => _addPage(ImageSource.camera),
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: const Text('ক্যামেরা'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : () => _addPage(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('গ্যালারি'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_pages.isEmpty)
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: _kSurface,
                border: Border.all(color: _kBorder),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Center(
                child: Text(
                  'এখনো কোনো পেজ নেই। ক্যামেরা বা গ্যালারি থেকে যোগ করুন।',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: _kMuted),
                ),
              ),
            )
          else ...[
            SizedBox(
              height: 92,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _pages.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final selected = i == _selected;
                  return GestureDetector(
                    onTap: () => setState(() => _selected = i),
                    child: Container(
                      width: 70,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: selected ? _kAccentB : _kBorder,
                          width: selected ? 2 : 1,
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.file(_pages[i].file, fit: BoxFit.cover),
                          Positioned(
                            left: 4,
                            bottom: 4,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              color: _kBg.withOpacity(0.75),
                              child: Text(
                                '${i + 1}',
                                style: const TextStyle(fontSize: 11),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            if (p != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _kSurface,
                  border: Border.all(color: _kBorder),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  children: [
                    AspectRatio(
                      aspectRatio: 3 / 4,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: RotatedBox(
                          quarterTurns: p.quarterTurns,
                          child: ColorFiltered(
                            colorFilter: p.filter == ScanFilter.original
                                ? const ColorFilter.mode(
                                    Colors.transparent,
                                    BlendMode.dst,
                                  )
                                : const ColorFilter.matrix(<double>[
                                    0.2126, 0.7152, 0.0722, 0, 0,
                                    0.2126, 0.7152, 0.0722, 0, 0,
                                    0.2126, 0.7152, 0.0722, 0, 0,
                                    0, 0, 0, 1, 0,
                                  ]),
                            child: Image.file(p.file, fit: BoxFit.contain),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: [
                        for (final f in ScanFilter.values)
                          ChoiceChip(
                            label: Text(_filterLabel(f)),
                            selected: p.filter == f,
                            onSelected: (_) => _setFilter(f),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        IconButton(
                          tooltip: 'ঘোরাও',
                          onPressed: _rotateSelected,
                          icon: const Icon(Icons.rotate_right),
                        ),
                        IconButton(
                          tooltip: 'মুছে দাও',
                          onPressed: _removeSelected,
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: _busy ? null : _exportPdf,
              icon: _busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.picture_as_pdf_outlined),
              label: Text(_busy ? 'PDF বানানো হচ্ছে…' : 'PDF বানিয়ে শেয়ার করো'),
            ),
          ],
        ],
      ),
    );
  }
}
