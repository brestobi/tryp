// This file is selected only for Flutter web builds. The browser APIs are
// intentionally isolated here so native builds never import dart:html.
// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;

bool get isMobileWebDevice {
  final navigator = html.window.navigator;
  final userAgent = navigator.userAgent.toLowerCase();
  final hasMobileUserAgent = RegExp(
    r'android|iphone|ipad|ipod|mobile',
  ).hasMatch(userAgent);

  if (hasMobileUserAgent) return true;

  // Some tablets request a desktop user agent. Keep those supported when the
  // browser still reports touch input and a mobile-sized viewport.
  final viewportWidth = html.window.innerWidth ?? double.infinity;
  return (navigator.maxTouchPoints ?? 0) > 0 && viewportWidth <= 1024;
}
