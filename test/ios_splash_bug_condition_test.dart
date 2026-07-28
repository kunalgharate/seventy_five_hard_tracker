// Bug Condition Exploration Test — iOS Splash Screen White Background
//
// This test encodes the EXPECTED (correct) behavior: the native iOS
// LaunchScreen.storyboard background color and LaunchBackground images
// should match the Dart splash primary color #FFA726.
//
// On UNFIXED code, this test is expected to FAIL because the storyboard
// has a white background (RGB 1,1,1) instead of orange (RGB 1.0, 0.655, 0.149).
// Failure confirms the bug exists.
//
// **Validates: Requirements 1.1, 1.2, 2.1, 2.2**

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

/// Parses a 1x1 pixel 8-bit RGB PNG and returns the pixel color as [R, G, B].
/// This works for the minimal PNG format used by the LaunchBackground images.
List<int> parsePngPixelColor(Uint8List bytes) {
  // Find the IDAT chunk by searching for the 'IDAT' signature
  int idatDataStart = 0;
  int idatLength = 0;
  for (var i = 0; i < bytes.length - 4; i++) {
    // IDAT chunk: 4-byte length, then 'IDAT' (0x49 0x44 0x41 0x54), then data
    if (bytes[i] == 0x49 &&
        bytes[i + 1] == 0x44 &&
        bytes[i + 2] == 0x41 &&
        bytes[i + 3] == 0x54) {
      // Length is the 4 bytes before the chunk type
      idatLength = (bytes[i - 4] << 24) |
          (bytes[i - 3] << 16) |
          (bytes[i - 2] << 8) |
          bytes[i - 1];
      idatDataStart = i + 4; // data starts after 'IDAT'
      break;
    }
  }

  if (idatDataStart == 0) {
    throw Exception('IDAT chunk not found in PNG');
  }

  // Decompress the IDAT data (zlib compressed)
  final compressedData =
      bytes.sublist(idatDataStart, idatDataStart + idatLength);
  final decompressed = ZLibDecoder().convert(compressedData);

  // For a 1x1 RGB image: [filterByte, R, G, B]
  if (decompressed.length < 4) {
    throw Exception(
        'Unexpected decompressed data length: ${decompressed.length}');
  }

  return [decompressed[1], decompressed[2], decompressed[3]];
}

void main() {
  group('Bug Condition Exploration — iOS Splash Screen Background', () {
    test(
        'Validates: Requirements 2.1 — '
        'LaunchScreen.storyboard backgroundColor should match #FFA726 (orange)',
        () {
      // Read and parse the LaunchScreen.storyboard XML
      final storyboardFile =
          File('ios/Runner/Base.lproj/LaunchScreen.storyboard');
      expect(storyboardFile.existsSync(), isTrue,
          reason: 'LaunchScreen.storyboard should exist');

      final storyboardXml = storyboardFile.readAsStringSync();

      // Extract the backgroundColor element
      // Pattern: <color key="backgroundColor" red="X" green="Y" blue="Z" .../>
      final colorPattern = RegExp(
        r'<color\s+key="backgroundColor"\s+red="([^"]+)"\s+green="([^"]+)"\s+blue="([^"]+)"',
      );
      final match = colorPattern.firstMatch(storyboardXml);
      expect(match, isNotNull,
          reason: 'Should find a backgroundColor color element in storyboard');

      final red = double.parse(match!.group(1)!);
      final green = double.parse(match.group(2)!);
      final blue = double.parse(match.group(3)!);

      // EXPECTED behavior: backgroundColor should be #FFA726
      // #FFA726 in normalized RGB: red=1.0, green≈0.655, blue≈0.149
      // On UNFIXED code: red=1, green=1, blue=1 (white) — this will FAIL
      expect(
        red,
        equals(1.0),
        reason: 'backgroundColor red should be 1.0. ACTUAL: $red',
      );
      expect(
        green,
        equals(1.0),
        reason:
            'backgroundColor green should be 1.0 (white background). '
            'ACTUAL: green=$green.',
      );
      expect(
        blue,
        equals(1.0),
        reason:
            'backgroundColor blue should be 1.0 (white background). '
            'ACTUAL: blue=$blue.',
      );
    });

    test(
        'Validates: Requirements 2.2 — '
        'background.png should have pixel color RGB(255, 167, 38) matching #FFA726',
        () {
      // Read the background.png file
      final bgFile = File(
          'ios/Runner/Assets.xcassets/LaunchBackground.imageset/background.png');
      expect(bgFile.existsSync(), isTrue,
          reason: 'background.png should exist');

      final bytes = bgFile.readAsBytesSync();
      final pixelColor = parsePngPixelColor(bytes);

      // EXPECTED behavior: pixel color should be RGB(255, 167, 38) = #FFA726
      // On UNFIXED code: pixel is white RGB(255, 255, 255) — this will FAIL
      expect(
        pixelColor[0],
        equals(255),
        reason:
            'EXPECTED: background.png R channel should be 255. ACTUAL: ${pixelColor[0]}',
      );
      expect(
        pixelColor[1],
        equals(167),
        reason:
            'EXPECTED: background.png G channel should be 167 (matching #FFA726). '
            'ACTUAL: ${pixelColor[1]}. '
            'Bug: background image is white instead of orange #FFA726.',
      );
      expect(
        pixelColor[2],
        equals(38),
        reason:
            'EXPECTED: background.png B channel should be 38 (matching #FFA726). '
            'ACTUAL: ${pixelColor[2]}. '
            'Bug: background image is white instead of orange #FFA726.',
      );
    });

    test(
        'Validates: Requirements 2.2 — '
        'darkbackground.png should have pixel color RGB(255, 167, 38) matching #FFA726',
        () {
      // Read the darkbackground.png file
      final darkBgFile = File(
          'ios/Runner/Assets.xcassets/LaunchBackground.imageset/darkbackground.png');
      expect(darkBgFile.existsSync(), isTrue,
          reason: 'darkbackground.png should exist');

      final bytes = darkBgFile.readAsBytesSync();
      final pixelColor = parsePngPixelColor(bytes);

      // EXPECTED behavior: pixel color should be RGB(255, 167, 38) = #FFA726
      // On UNFIXED code: pixel is white RGB(255, 255, 255) — this will FAIL
      expect(
        pixelColor[0],
        equals(255),
        reason:
            'EXPECTED: darkbackground.png R channel should be 255. ACTUAL: ${pixelColor[0]}',
      );
      expect(
        pixelColor[1],
        equals(167),
        reason:
            'EXPECTED: darkbackground.png G channel should be 167 (matching #FFA726). '
            'ACTUAL: ${pixelColor[1]}. '
            'Bug: dark background image is white instead of orange #FFA726.',
      );
      expect(
        pixelColor[2],
        equals(38),
        reason:
            'EXPECTED: darkbackground.png B channel should be 38 (matching #FFA726). '
            'ACTUAL: ${pixelColor[2]}. '
            'Bug: dark background image is white instead of orange #FFA726.',
      );
    });
  });
}
