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

  // Deliberately rely on the browser identity rather than viewport size or
  // touch support. Desktop browsers can be resized and touchscreen laptops
  // can report touch input, but neither should unlock the mobile-only app.
  return hasMobileUserAgent;
}
