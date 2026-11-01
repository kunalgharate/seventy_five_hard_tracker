// Safe-area + image-fit coverage for the proof photo surfaces.
//
// The full-screen proof viewer used to be a plain Dialog: on notched devices
// the close button sat under the status bar/notch, and a portrait photo
// sized to the full screen width could run off the bottom of the screen.
// These tests pin the fixed behavior:
//   * the viewer is wrapped in a SafeArea
//   * the viewer image uses BoxFit.contain (whole photo visible)
//   * the in-list thumbnail uses BoxFit.cover (fills its box, no letterbox)

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seventy_five_hard_tracker/features/human_accountability/data/models/accountability_task.dart';
import 'package:seventy_five_hard_tracker/features/human_accountability/presentation/widgets/partner_task_details_dialog.dart';

void main() {
  AccountabilityTask taskWithProof() => AccountabilityTask(
        id: 'task-1',
        assignedByUid: 'creator-uid',
        assignedByName: 'Creator',
        accountableUid: 'assignee-uid',
        accountableName: 'Assignee',
        partnershipId: 'partnership-1',
        challengeId: 'challenge-1',
        title: 'Complete the task',
        status: AccountabilityTaskStatus.approved,
        proofStatus: ProofStatus.approved,
        proofUrl: 'https://example.com/proof.jpg',
        assignedAt: DateTime(2026, 10, 18),
        taskType: 'hard',
      );

  Future<void> pumpDialog(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: PartnerTaskDetailsDialog(task: taskWithProof())),
      ),
    );
    await tester.pump();
  }

  testWidgets('proof thumbnail covers its box with BoxFit.cover',
      (tester) async {
    await pumpDialog(tester);

    final images = tester.widgetList<Image>(find.byType(Image)).toList();
    expect(images, isNotEmpty);
    expect(
      images.every((image) => image.fit == BoxFit.cover),
      isTrue,
      reason: 'inline proof thumbnails must fill their frame with cover',
    );
  });

  testWidgets('tapping the proof opens a viewer inside a SafeArea',
      (tester) async {
    await pumpDialog(tester);

    await tester.tap(find.byType(Image).first);
    await tester.pumpAndSettle();

    expect(find.byType(InteractiveViewer), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(Dialog),
        matching: find.byType(SafeArea),
      ),
      findsWidgets,
      reason: 'viewer must not place the photo/close button in the unsafe area',
    );
    expect(find.byIcon(Icons.close), findsOneWidget);

    final viewerImage = tester
        .widgetList<Image>(
          find.descendant(
            of: find.byType(InteractiveViewer),
            matching: find.byType(Image),
          ),
        )
        .toList();
    expect(viewerImage, isNotEmpty);
    expect(
      viewerImage.every((image) => image.fit == BoxFit.contain),
      isTrue,
      reason: 'full-screen viewer must show the whole photo (contain)',
    );
  });
}
