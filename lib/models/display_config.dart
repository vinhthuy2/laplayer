import 'dart:ui';

class DisplayConfig {
  final double fontSize;
  final Color bgColor;
  final Color countdownBgColor;

  const DisplayConfig({
    this.fontSize = 64.0,
    this.bgColor = const Color(0xFF000000),
    this.countdownBgColor = const Color(0xFF000000),
  });

  DisplayConfig copyWith({
    double? fontSize,
    Color? bgColor,
    Color? countdownBgColor,
  }) {
    return DisplayConfig(
      fontSize: fontSize ?? this.fontSize,
      bgColor: bgColor ?? this.bgColor,
      countdownBgColor: countdownBgColor ?? this.countdownBgColor,
    );
  }
}
