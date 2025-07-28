// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:seventy_five_hard_tracker/main.dart';
import 'package:seventy_five_hard_tracker/repositories/database_repository.dart';
import 'package:seventy_five_hard_tracker/services/notification_service.dart';

void main() {
  testWidgets('Counter increments smoke test', (WidgetTester tester) async {
    // Initialize required services for testing
    final databaseRepository = DatabaseRepository();
    await databaseRepository.init();
    
    final notificationService = NotificationService();
    await notificationService.init();

    // Build our app and trigger a frame.
    await tester.pumpWidget(MyApp(
      databaseRepository: databaseRepository,
      notificationService: notificationService,
    ));

    // Verify that the app starts correctly
    expect(find.text('Loading 75 Hard Challenge...'), findsOneWidget);
  });
}
