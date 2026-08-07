import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tryp/app/theme.dart';

void main() {
  test('light theme color scheme keeps primary controls readable', () {
    final scheme = TRYPTheme.lightColorScheme;

    expect(scheme.primary, TRYPColors.primary);
    expect(scheme.onPrimary, TRYPColors.white);
    expect(scheme.surface, TRYPColors.white);
    expect(scheme.onSurface, TRYPColors.dark);
    expect(TRYPColors.muted.value, 0xFF8A8A8A);
  });

  test('dark theme color scheme flips text and control contrast', () {
    final scheme = TRYPTheme.darkColorScheme;

    expect(scheme.primary, TRYPColors.white);
    expect(scheme.onPrimary, TRYPColors.dark);
    expect(scheme.surface, const Color(0xFF111111));
    expect(scheme.onSurface, TRYPColors.white);
    expect(TRYPColors.secondaryLight.value, 0xFFBDBDBD);
  });
}
