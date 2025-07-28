import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';

class SmoothScrollBehavior extends ScrollBehavior {
  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    // Use standard ClampingScrollPhysics for stability
    return const ClampingScrollPhysics(
      parent: AlwaysScrollableScrollPhysics(),
    );
  }

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    // Return child without scrollbar for cleaner look
    return child;
  }

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    // Use platform-appropriate overscroll indicator
    switch (getPlatform(context)) {
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return child;
      case TargetPlatform.android:
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.windows:
        return GlowingOverscrollIndicator(
          axisDirection: details.direction,
          color: const Color(0xFFFFA726), // Orange glow to match theme
          child: child,
        );
    }
  }

  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.stylus,
        PointerDeviceKind.trackpad,
      };
}

// Simple, stable scroll physics
class StableScrollPhysics extends ClampingScrollPhysics {
  const StableScrollPhysics({super.parent});

  @override
  StableScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return StableScrollPhysics(parent: buildParent(ancestor));
  }

  @override
  double get minFlingVelocity => 100.0; // Slightly responsive

  @override
  double get maxFlingVelocity => 2500.0; // Standard max velocity
}
