import 'package:flutter/material.dart';

class AppLogo extends StatelessWidget {
  const AppLogo({this.size = 40, this.semanticLabel, super.key})
    : assert(size > 0 && size < double.infinity);

  static const assetName = 'assets/logo.png';
  static const sourceSize = 1024;

  final double size;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final pixels = (size * MediaQuery.devicePixelRatioOf(context))
        .ceil()
        .clamp(1, sourceSize)
        .toInt();
    return Image.asset(
      assetName,
      width: size,
      height: size,
      cacheWidth: pixels,
      cacheHeight: pixels,
      filterQuality: FilterQuality.low,
      gaplessPlayback: true,
      excludeFromSemantics: semanticLabel == null,
      semanticLabel: semanticLabel,
    );
  }
}
