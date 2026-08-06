import 'package:flutter_test/flutter_test.dart';
import 'package:tryp/core/services/welcome_notification_service.dart';

void main() {
  test('welcome notification uses a clear title and message', () {
    final title = WelcomeNotificationService.welcomeTitle;
    final body = WelcomeNotificationService.welcomeBody;

    expect(title, contains('Welcome'));
    expect(body, contains('TRYP'));
  });
}
