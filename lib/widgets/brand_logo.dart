import 'package:flutter/material.dart';

class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.compact = false, this.height});

  final bool compact;
  final double? height;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Image.asset(
        'assets/icons/sehatmate_icon.png',
        width: height ?? 36,
        height: height ?? 36,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
      );
    }

    return Image.asset(
      'assets/branding/sehatmate_wordmark.png',
      height: height ?? 36,
      fit: BoxFit.contain,
      alignment: Alignment.centerLeft,
      filterQuality: FilterQuality.high,
    );
  }
}
