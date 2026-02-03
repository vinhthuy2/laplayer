import 'package:flutter/material.dart';

class AppColors extends ThemeExtension<AppColors> {
  final Color background;
  final Color surface;
  final Color surfaceVariant;
  final Color primary;
  final Color primaryMuted;
  final Color primarySubtle;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color divider;
  final Color cardBorder;
  final Color beatGridEmpty;
  final Color beatGridEmptyStrong;
  final Color beatGridPlayhead;
  final Color destructive;
  final Color destructiveText;
  final Color success;

  const AppColors({
    required this.background,
    required this.surface,
    required this.surfaceVariant,
    required this.primary,
    required this.primaryMuted,
    required this.primarySubtle,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.divider,
    required this.cardBorder,
    required this.beatGridEmpty,
    required this.beatGridEmptyStrong,
    required this.beatGridPlayhead,
    required this.destructive,
    required this.destructiveText,
    required this.success,
  });

  static const light = AppColors(
    background: Color(0xFFF5F9F8),
    surface: Color(0xFFFFFFFF),
    surfaceVariant: Color(0xFFEDF5F3),
    primary: Color(0xFF1B6B5A),
    primaryMuted: Color(0xA01B6B5A), // 63%
    primarySubtle: Color(0x661B6B5A), // 40%
    textPrimary: Color(0xFF1A1C1E),
    textSecondary: Color(0xFF5F6368),
    textTertiary: Color(0xFF9AA0A6),
    divider: Color(0xFFE0E0E0),
    cardBorder: Color(0xFFD0E8E2),
    beatGridEmpty: Color(0xFFC8D6D2),
    beatGridEmptyStrong: Color(0xFFA0B5AD),
    beatGridPlayhead: Color(0xFF1A1C1E),
    destructive: Color(0xFFF44336),
    destructiveText: Color(0xFFD32F2F),
    success: Color(0xFF4CAF50),
  );

  static const dark = AppColors(
    background: Color(0xFF0F1412),
    surface: Color(0xFF1A2420),
    surfaceVariant: Color(0xFF232E2A),
    primary: Color(0xFF5BB8A8),
    primaryMuted: Color(0xA05BB8A8), // 63%
    primarySubtle: Color(0x665BB8A8), // 40%
    textPrimary: Color(0xFFE2E3E0),
    textSecondary: Color(0xFF8E9490),
    textTertiary: Color(0xFF5F6864),
    divider: Color(0xFF2E3A36),
    cardBorder: Color(0xFF2E3A36),
    beatGridEmpty: Color(0xFF2E3A36),
    beatGridEmptyStrong: Color(0xFF4A5A54),
    beatGridPlayhead: Color(0xFFFFFFFF),
    destructive: Color(0xFFFFB4AB),
    destructiveText: Color(0xFFFFB4AB),
    success: Color(0xFF81C784),
  );

  @override
  AppColors copyWith({
    Color? background,
    Color? surface,
    Color? surfaceVariant,
    Color? primary,
    Color? primaryMuted,
    Color? primarySubtle,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? divider,
    Color? cardBorder,
    Color? beatGridEmpty,
    Color? beatGridEmptyStrong,
    Color? beatGridPlayhead,
    Color? destructive,
    Color? destructiveText,
    Color? success,
  }) {
    return AppColors(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceVariant: surfaceVariant ?? this.surfaceVariant,
      primary: primary ?? this.primary,
      primaryMuted: primaryMuted ?? this.primaryMuted,
      primarySubtle: primarySubtle ?? this.primarySubtle,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      divider: divider ?? this.divider,
      cardBorder: cardBorder ?? this.cardBorder,
      beatGridEmpty: beatGridEmpty ?? this.beatGridEmpty,
      beatGridEmptyStrong: beatGridEmptyStrong ?? this.beatGridEmptyStrong,
      beatGridPlayhead: beatGridPlayhead ?? this.beatGridPlayhead,
      destructive: destructive ?? this.destructive,
      destructiveText: destructiveText ?? this.destructiveText,
      success: success ?? this.success,
    );
  }

  @override
  AppColors lerp(AppColors? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceVariant: Color.lerp(surfaceVariant, other.surfaceVariant, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      primaryMuted: Color.lerp(primaryMuted, other.primaryMuted, t)!,
      primarySubtle: Color.lerp(primarySubtle, other.primarySubtle, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textTertiary: Color.lerp(textTertiary, other.textTertiary, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      cardBorder: Color.lerp(cardBorder, other.cardBorder, t)!,
      beatGridEmpty: Color.lerp(beatGridEmpty, other.beatGridEmpty, t)!,
      beatGridEmptyStrong: Color.lerp(beatGridEmptyStrong, other.beatGridEmptyStrong, t)!,
      beatGridPlayhead: Color.lerp(beatGridPlayhead, other.beatGridPlayhead, t)!,
      destructive: Color.lerp(destructive, other.destructive, t)!,
      destructiveText: Color.lerp(destructiveText, other.destructiveText, t)!,
      success: Color.lerp(success, other.success, t)!,
    );
  }
}

extension AppColorsExtension on BuildContext {
  AppColors get colors => Theme.of(this).extension<AppColors>()!;
}
