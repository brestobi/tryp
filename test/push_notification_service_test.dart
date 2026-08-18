import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:tryp/core/services/push_notification_service.dart';

void main() {
  group('normalizeFirebaseWebVapidKey', () {
    test('normalizes quotes, whitespace, and padding', () {
      final rawKey = base64UrlEncode([
        4,
        ...List<int>.filled(62, 0),
        251,
        255,
      ]);

      expect(
        normalizeFirebaseWebVapidKey('  "$rawKey"\n'),
        rawKey.replaceAll('=', ''),
      );
    });

    test('rejects an empty or malformed key', () {
      expect(normalizeFirebaseWebVapidKey(''), isNull);
      expect(normalizeFirebaseWebVapidKey('not a VAPID key'), isNull);
      expect(normalizeFirebaseWebVapidKey('FIREBASE_WEB_VAPID_KEY'), isNull);
    });
  });
}
