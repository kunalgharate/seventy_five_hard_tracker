// Preservation Property Tests — iOS Splash Screen Layout & Cross-Platform Config
//
// These tests verify baseline behaviors that MUST be preserved after the fix:
// - Storyboard constraint IDs remain unchanged
// - View hierarchy (LaunchBackground + LaunchImage) is intact
// - LaunchImage contentMode is "center", LaunchBackground is "scaleToFill"
// - LaunchBackground.imageset/Contents.json references background.png and darkbackground.png
// - lib/main.dart contains InitialScreen with AppColors.primary gradient
// - pubspec.yaml flutter_native_splash section has android: false
//
// On UNFIXED code, these tests are expected to PASS (confirming baseline).
// After the fix, they should STILL PASS (confirming no regressions).
//
// **Validates: Requirements 3.1, 3.2, 3.3, 3.4**

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Preservation Property — Storyboard Constraints (Req 3.1, 3.4)', () {
    late String storyboardXml;

    setUp(() {
      final storyboardFile =
          File('ios/Runner/Base.lproj/LaunchScreen.storyboard');
      expect(storyboardFile.existsSync(), isTrue,
          reason: 'LaunchScreen.storyboard must exist');
      storyboardXml = storyboardFile.readAsStringSync();
    });

    test(
        'Validates: Requirements 3.1 — '
        'All 8 constraint IDs are present in the storyboard', () {
      // These are the exact constraint IDs that must be preserved
      final expectedConstraintIds = [
        '3T2-ad-Qdv',
        'RPx-PI-7Xg',
        'SdS-ul-q2q',
        'Swv-Gf-Rwn',
        'TQA-XW-tRk',
        'duK-uY-Gun',
        'kV7-tw-vXt',
        'xPn-NY-SIU',
      ];

      for (final constraintId in expectedConstraintIds) {
        expect(
          storyboardXml.contains('id="$constraintId"'),
          isTrue,
          reason:
              'Constraint with id="$constraintId" must be present in storyboard',
        );
      }

      // Also verify there are exactly 8 constraint elements
      final constraintPattern = RegExp(r'<constraint\s');
      final matches = constraintPattern.allMatches(storyboardXml);
      expect(
        matches.length,
        equals(8),
        reason: 'Storyboard should have exactly 8 constraints',
      );
    });
  });

  group('Preservation Property — View Hierarchy (Req 3.1, 3.4)', () {
    late String storyboardXml;

    setUp(() {
      final storyboardFile =
          File('ios/Runner/Base.lproj/LaunchScreen.storyboard');
      storyboardXml = storyboardFile.readAsStringSync();
    });

    test(
        'Validates: Requirements 3.4 — '
        '2 imageView subviews in correct order with correct IDs', () {
      // Extract all imageView elements with their IDs in order
      final imageViewPattern = RegExp(r'<imageView[^>]+id="([^"]+)"');
      final matches = imageViewPattern.allMatches(storyboardXml).toList();

      expect(
        matches.length,
        equals(2),
        reason: 'Storyboard should have exactly 2 imageView subviews',
      );

      // First imageView should be LaunchBackground (tWc-Dq-wcI)
      expect(
        matches[0].group(1),
        equals('tWc-Dq-wcI'),
        reason: 'First imageView should be LaunchBackground with id tWc-Dq-wcI',
      );

      // Second imageView should be LaunchImage (YRO-k0-Ey4)
      expect(
        matches[1].group(1),
        equals('YRO-k0-Ey4'),
        reason: 'Second imageView should be LaunchImage with id YRO-k0-Ey4',
      );
    });

    test(
        'Validates: Requirements 3.1 — '
        'LaunchImage contentMode is "center" and LaunchBackground contentMode is "scaleToFill"',
        () {
      // LaunchBackground (tWc-Dq-wcI) should have contentMode="scaleToFill"
      final launchBgPattern = RegExp(
        r'<imageView[^>]+contentMode="scaleToFill"[^>]+id="tWc-Dq-wcI"',
      );
      expect(
        launchBgPattern.hasMatch(storyboardXml),
        isTrue,
        reason:
            'LaunchBackground imageView should have contentMode="scaleToFill"',
      );

      // LaunchImage (YRO-k0-Ey4) should have contentMode="center"
      final launchImgPattern = RegExp(
        r'<imageView[^>]+contentMode="center"[^>]+id="YRO-k0-Ey4"',
      );
      expect(
        launchImgPattern.hasMatch(storyboardXml),
        isTrue,
        reason: 'LaunchImage imageView should have contentMode="center"',
      );
    });
  });

  group('Preservation Property — LaunchBackground Contents.json (Req 3.4)', () {
    test(
        'Validates: Requirements 3.4 — '
        'Contents.json references background.png and darkbackground.png', () {
      final contentsFile = File(
          'ios/Runner/Assets.xcassets/LaunchBackground.imageset/Contents.json');
      expect(contentsFile.existsSync(), isTrue,
          reason: 'Contents.json must exist');

      final contentsJson =
          jsonDecode(contentsFile.readAsStringSync()) as Map<String, dynamic>;

      // Verify the images array structure
      expect(contentsJson.containsKey('images'), isTrue,
          reason: 'Contents.json must have an "images" key');

      final images = contentsJson['images'] as List<dynamic>;
      expect(images.length, equals(2),
          reason: 'Contents.json should have exactly 2 image entries');

      // First entry: background.png (universal, no appearance)
      final firstImage = images[0] as Map<String, dynamic>;
      expect(firstImage['filename'], equals('background.png'),
          reason: 'First image entry should reference background.png');
      expect(firstImage['idiom'], equals('universal'),
          reason: 'First image entry should have idiom "universal"');

      // Second entry: darkbackground.png (universal, dark appearance)
      final secondImage = images[1] as Map<String, dynamic>;
      expect(secondImage['filename'], equals('darkbackground.png'),
          reason: 'Second image entry should reference darkbackground.png');
      expect(secondImage['idiom'], equals('universal'),
          reason: 'Second image entry should have idiom "universal"');

      // Verify dark appearance configuration
      final appearances = secondImage['appearances'] as List<dynamic>;
      expect(appearances.length, equals(1),
          reason: 'Dark image should have 1 appearance entry');
      final appearance = appearances[0] as Map<String, dynamic>;
      expect(appearance['appearance'], equals('luminosity'),
          reason: 'Appearance type should be "luminosity"');
      expect(appearance['value'], equals('dark'),
          reason: 'Appearance value should be "dark"');

      // Verify info section
      expect(contentsJson.containsKey('info'), isTrue,
          reason: 'Contents.json must have an "info" key');
      final info = contentsJson['info'] as Map<String, dynamic>;
      expect(info['author'], equals('xcode'),
          reason: 'Info author should be "xcode"');
      expect(info['version'], equals(1), reason: 'Info version should be 1');
    });
  });

  group('Preservation Property — Dart InitialScreen (Req 3.2)', () {
    test(
        'Validates: Requirements 3.2 — '
        'lib/main.dart contains InitialScreen class with AppColors.primary gradient',
        () {
      final mainDartFile = File('lib/main.dart');
      expect(mainDartFile.existsSync(), isTrue,
          reason: 'lib/main.dart must exist');

      final mainDartContent = mainDartFile.readAsStringSync();

      // Verify InitialScreen class exists
      expect(
        mainDartContent.contains('class InitialScreen'),
        isTrue,
        reason: 'lib/main.dart must contain the InitialScreen class',
      );

      // Verify InitialScreen is a StatefulWidget
      expect(
        mainDartContent.contains('class InitialScreen extends StatefulWidget'),
        isTrue,
        reason: 'InitialScreen must extend StatefulWidget',
      );

      // Verify AppColors.primary is used in the gradient
      expect(
        mainDartContent.contains('AppColors.primary'),
        isTrue,
        reason: 'InitialScreen must reference AppColors.primary',
      );

      // Verify LinearGradient is used
      expect(
        mainDartContent.contains('LinearGradient'),
        isTrue,
        reason: 'InitialScreen must use a LinearGradient',
      );

      // Verify AppColors.primary color value is #FFA726
      expect(
        mainDartContent.contains('0xFFFFA726'),
        isTrue,
        reason: 'AppColors.primary must be defined as 0xFFFFA726 (#FFA726)',
      );
    });
  });

  group('Preservation Property — Android Config Unchanged (Req 3.3)', () {
    test(
        'Validates: Requirements 3.3 — '
        'pubspec.yaml flutter_native_splash section has android: false', () {
      final pubspecFile = File('pubspec.yaml');
      expect(pubspecFile.existsSync(), isTrue,
          reason: 'pubspec.yaml must exist');

      final pubspecContent = pubspecFile.readAsStringSync();

      // Verify flutter_native_splash section exists
      expect(
        pubspecContent.contains('flutter_native_splash:'),
        isTrue,
        reason: 'pubspec.yaml must contain flutter_native_splash section',
      );

      // Verify android: false is present in the flutter_native_splash section
      // Parse the section to ensure android is set to false
      final lines = pubspecContent.split('\n');
      bool inSplashSection = false;
      bool foundAndroidFalse = false;

      for (final line in lines) {
        if (line.trim() == 'flutter_native_splash:') {
          inSplashSection = true;
          continue;
        }
        if (inSplashSection) {
          // Exit section if we hit a non-indented line (new top-level key)
          if (line.isNotEmpty &&
              !line.startsWith(' ') &&
              !line.startsWith('\t')) {
            break;
          }
          if (line.trim() == 'android: false') {
            foundAndroidFalse = true;
            break;
          }
        }
      }

      expect(
        foundAndroidFalse,
        isTrue,
        reason:
            'flutter_native_splash section must have "android: false" to keep Android config unchanged',
      );
    });
  });
}
