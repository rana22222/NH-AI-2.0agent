import 'dart:io';

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:path_provider/path_provider.dart';

class VideoResult {
  final bool ok;
  final String? path;
  final String message;
  const VideoResult.success(this.path)
      : ok = true,
        message = 'সম্পন্ন';
  const VideoResult.failure(this.message)
      : ok = false,
        path = null;
}

enum CropRatio { r16x9, r9x16, r1x1 }

enum VideoFilter { grayscale, warm, vivid, bright, sepia }

/// সব এডিটিং ফোনের ভেতরেই FFmpeg দিয়ে হয়। কোনো নকল প্রসেসিং নেই।
class VideoStudioService {
  Future<String> _outPath(String name) async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/video_studio');
    if (!await dir.exists()) await dir.create(recursive: true);
    return '${dir.path}/${DateTime.now().millisecondsSinceEpoch}_$name';
  }

  Future<VideoResult> _run(List<String> args, String out) async {
    try {
      final session = await FFmpegKit.executeWithArguments(args);
      final rc = await session.getReturnCode();
      if (ReturnCode.isSuccess(rc)) return VideoResult.success(out);
      final logs = await session.getAllLogsAsString() ?? '';
      final tail = logs.length > 400 ? logs.substring(logs.length - 400) : logs;
      return VideoResult.failure('FFmpeg ব্যর্থ হয়েছে: $tail');
    } catch (e) {
      return VideoResult.failure('ত্রুটি: $e');
    }
  }

  static const _v = ['-c:v', 'libx264', '-preset', 'veryfast', '-pix_fmt', 'yuv420p'];
  static const _a = ['-c:a', 'aac', '-b:a', '128k'];

  Future<VideoResult> trim(String input, double startSec, double endSec) async {
    final out = await _outPath('trim.mp4');
    return _run([
      '-y', '-ss', startSec.toStringAsFixed(2), '-to', endSec.toStringAsFixed(2),
      '-i', input, ..._v, ..._a, out,
    ], out);
  }

  /// সব ভিডিওতে অডিও ট্র্যাক থাকতে হবে।
  Future<VideoResult> merge(List<String> inputs) async {
    if (inputs.length < 2) {
      return const VideoResult.failure('মার্জ করতে কমপক্ষে ২টি ভিডিও লাগবে।');
    }
    final out = await _outPath('merged.mp4');
    final args = <String>['-y'];
    for (final i in inputs) {
      args.addAll(['-i', i]);
    }
    final f = StringBuffer();
    for (var i = 0; i < inputs.length; i++) {
      f.write('[$i:v]scale=1280:720:force_original_aspect_ratio=decrease,'
          'pad=1280:720:(ow-iw)/2:(oh-ih)/2,setsar=1,fps=30[v$i];');
    }
    for (var i = 0; i < inputs.length; i++) {
      f.write('[v$i][$i:a]');
    }
    f.write('concat=n=${inputs.length}:v=1:a=1[v][a]');
    args.addAll(['-filter_complex', f.toString(), '-map', '[v]', '-map', '[a]', ..._v, ..._a, out]);
    return _run(args, out);
  }

  Future<VideoResult> crop(String input, CropRatio ratio) async {
    final out = await _outPath('crop.mp4');
    final vf = switch (ratio) {
      CropRatio.r16x9 => "crop='min(iw,ih*16/9)':'min(ih,iw*9/16)'",
      CropRatio.r9x16 => "crop='min(iw,ih*9/16)':'min(ih,iw*16/9)'",
      CropRatio.r1x1 => "crop='min(iw,ih)':'min(iw,ih)'",
    };
    return _run(['-y', '-i', input, '-vf', vf, ..._v, ..._a, out], out);
  }

  Future<VideoResult> compress(String input) async {
    final out = await _outPath('compressed.mp4');
    return _run([
      '-y', '-i', input, '-vf', 'scale=-2:720', '-c:v', 'libx264', '-crf', '28',
      '-preset', 'veryfast', '-pix_fmt', 'yuv420p', ..._a, out,
    ], out);
  }

  Future<VideoResult> applyFilter(String input, VideoFilter filter) async {
    final out = await _outPath('filter.mp4');
    final vf = switch (filter) {
      VideoFilter.grayscale => 'hue=s=0',
      VideoFilter.warm => 'colorbalance=rs=0.2:bs=-0.2',
      VideoFilter.vivid => 'eq=saturation=1.5:contrast=1.1',
      VideoFilter.bright => 'eq=brightness=0.08',
      VideoFilter.sepia =>
        'colorchannelmixer=.393:.769:.189:0:.349:.686:.168:0:.272:.534:.131',
    };
    return _run(['-y', '-i', input, '-vf', vf, ..._v, ..._a, out], out);
  }

  /// ব্যাকগ্রাউন্ড মিউজিক বা ভয়েস-ওভার (রেকর্ড করা অডিও ফাইল) মেশানো।
  /// ভিডিওতে অডিও ট্র্যাক থাকতে হবে। [volume] ০.০ – ১.০।
  Future<VideoResult> mixAudio(String video, String audio, {double volume = 0.4}) async {
    final out = await _outPath('audio.mp4');
    return _run([
      '-y', '-i', video, '-i', audio, '-filter_complex',
      '[1:a]volume=${volume.toStringAsFixed(2)}[m];[0:a][m]amix=inputs=2:duration=first:dropout_transition=2[a]',
      '-map', '0:v', '-map', '[a]', '-c:v', 'copy', ..._a, out,
    ], out);
  }

  /// টেক্সট বসানো। সতর্কতা: বাংলা যুক্তাক্ষর drawtext-এ ঠিকভাবে নাও দেখাতে পারে।
  Future<VideoResult> addText(String input, String text,
      {String fontPath = '/system/fonts/NotoSansBengali-Regular.ttf'}) async {
    final out = await _outPath('text.mp4');
    final safe = text
        .replaceAll('\\', '\\\\')
        .replaceAll(':', '\\:')
        .replaceAll("'", '')
        .replaceAll('%', '\\%');
    final font = File(fontPath).existsSync()
        ? fontPath
        : '/system/fonts/Roboto-Regular.ttf';
    final vf = "drawtext=fontfile=$font:text='$safe':fontcolor=white:fontsize=h/18:"
        "box=1:boxcolor=black@0.5:boxborderw=12:x=(w-text_w)/2:y=h-text_h-h/10";
    return _run(['-y', '-i', input, '-vf', vf, ..._v, '-c:a', 'copy', out], out);
  }

  /// HD এক্সপোর্ট (৭২০ বা ১০৮০)।
  Future<VideoResult> exportHd(String input, {int height = 1080}) async {
    final out = await _outPath('export_${height}p.mp4');
    return _run([
      '-y', '-i', input, '-vf', 'scale=-2:$height', '-c:v', 'libx264', '-crf', '18',
      '-preset', 'medium', '-pix_fmt', 'yuv420p', ..._a, '-movflags', '+faststart', out,
    ], out);
  }
}
