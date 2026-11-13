import 'dart:io';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

Future<void> saveTransferFile(
  BuildContext context,
  String content, {
  required bool compact,
}) async {
  final extension = compact ? 'rth' : 'json';
  final filename =
      'rtsp-hub-${DateTime.now().millisecondsSinceEpoch}.$extension';
  if (Platform.isAndroid || Platform.isIOS) {
    final box = context.findRenderObject() as RenderBox?;
    final origin = box == null
        ? null
        : box.localToGlobal(Offset.zero) & box.size;
    final root = await getTemporaryDirectory();
    final folder = Directory('${root.path}/rtsp-hub-share');
    await folder.create(recursive: true);
    await for (final entry in folder.list()) {
      if (entry is File &&
          DateTime.now().difference((await entry.stat()).modified).inDays >=
              1) {
        await entry.delete();
      }
    }
    final file = File('${folder.path}/$filename');
    await file.writeAsString(content, flush: true);
    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile(
            file.path,
            mimeType: compact ? 'text/plain' : 'application/json',
          ),
        ],
        sharePositionOrigin: origin,
      ),
    );
  } else {
    final location = await getSaveLocation(
      suggestedName: filename,
      acceptedTypeGroups: [
        XTypeGroup(
          label: compact ? 'RTSP Hub compacto' : 'JSON',
          extensions: [extension],
        ),
      ],
    );
    if (location != null) {
      await File(location.path).writeAsString(content, flush: true);
    }
  }
}
