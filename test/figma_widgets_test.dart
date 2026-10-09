import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seventy_five_hard_tracker/core/theme/figma_tokens.dart';
import 'package:seventy_five_hard_tracker/core/theme/figma_widgets.dart';

/// Smoke tests for the Figma-styled design system introduced during the
/// Figma restyle. Verifies the reusable widgets build without throwing in
/// both light and dark themes.
void main() {
  Widget wrap(Widget child, {Brightness brightness = Brightness.light}) {
    return MaterialApp(
      theme: ThemeData(brightness: brightness),
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );
  }

  testWidgets('FigmaCard renders child', (tester) async {
    await tester.pumpWidget(wrap(const FigmaCard(child: Text('hello'))));
    expect(find.text('hello'), findsOneWidget);
  });

  testWidgets('FigmaSectionHead shows title and note', (tester) async {
    await tester.pumpWidget(
        wrap(const FigmaSectionHead(title: 'Insights', note: '2 metrics')));
    expect(find.text('Insights'), findsOneWidget);
    expect(find.text('2 metrics'), findsOneWidget);
  });

  testWidgets('FigmaGradientButton shows label and taps', (tester) async {
    var tapped = false;
    await tester.pumpWidget(wrap(FigmaGradientButton(
      label: 'Save reflection',
      icon: Icons.menu_book,
      onTap: () => tapped = true,
    )));
    expect(find.text('Save reflection'), findsOneWidget);
    await tester.tap(find.text('Save reflection'));
    expect(tapped, isTrue);
  });

  testWidgets('FigmaPerformanceBar clamps and renders', (tester) async {
    await tester.pumpWidget(wrap(const FigmaPerformanceBar(
      label: 'Drink 3L water',
      percent: 150, // out of range → should clamp, not throw
      color: FigmaTokens.coral,
    )));
    expect(find.text('Drink 3L water'), findsOneWidget);
    expect(find.text('150%'), findsOneWidget);
  });

  testWidgets('FigmaChip and FigmaIconTile build in dark mode', (tester) async {
    await tester.pumpWidget(wrap(
      const Column(
        children: [
          FigmaChip(
              label: 'DAY 18',
              color: Colors.white,
              background: Colors.black26,
              icon: Icons.bolt),
          FigmaIconTile(icon: Icons.water_drop, colorIndex: 0),
          FigmaIconTile(icon: Icons.menu_book, colorIndex: 1),
          FigmaIconTile(icon: Icons.directions_walk, colorIndex: 2),
        ],
      ),
      brightness: Brightness.dark,
    ));
    expect(find.text('DAY 18'), findsOneWidget);
    expect(find.byType(FigmaIconTile), findsNWidgets(3));
  });

  test('FigmaTokens gradient and tile selection are stable', () {
    expect(FigmaTokens.brandGradient.colors.length, 3);
    expect(FigmaTokens.tileGradient(0), FigmaTokens.tileBlue);
    expect(FigmaTokens.tileGradient(1), FigmaTokens.tileViolet);
    expect(FigmaTokens.tileGradient(2), FigmaTokens.tileCoral);
    expect(FigmaTokens.tileGradient(3), FigmaTokens.tileBlue);
  });
}
