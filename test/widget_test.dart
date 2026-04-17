import 'package:flutter_test/flutter_test.dart';
import 'package:seventy_five_hard_tracker/services/smart_notification_service.dart';
import 'package:seventy_five_hard_tracker/repositories/database_repository.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Verify services can be instantiated
    final repo = DatabaseRepository();
    final notifications = SmartNotificationService();
    expect(repo, isNotNull);
    expect(notifications, isNotNull);
  });
}
