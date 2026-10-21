import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:seventy_five_hard_tracker/core/services/photo_sync_service.dart';
import 'package:seventy_five_hard_tracker/core/services/cloudinary_upload_signer.dart';

void main() {
  group('Cloudinary signer contract', () {
    test('parses and serializes signer request parameters', () {
      const request = CloudinarySignRequest(
        parameters: {
          'folder': 'task_proofs',
          'timestamp': '1760000000',
        },
      );

      final parsed = CloudinarySignRequest.fromJson(request.toJson());

      expect(parsed.parameters, request.parameters);
    });

    test('parses signed upload response fields', () {
      final response = CloudinarySignedUpload.fromJson({
        'signature': 'signed-value',
        'timestamp': '1760000000',
        'api_key': 'public-api-key',
        'cloud_name': 'example-cloud',
      });

      expect(response.signature, 'signed-value');
      expect(response.timestamp, 1760000000);
      expect(response.apiKey, 'public-api-key');
      expect(response.cloudName, 'example-cloud');
    });

    test('rejects incomplete signer responses', () {
      expect(
        () => CloudinarySignedUpload.fromJson({'signature': 'only-signature'}),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => CloudinarySignRequest.fromJson({
          'parameters': {'timestamp': 1}
        }),
        throwsA(isA<FormatException>()),
      );
    });

    test('posts the documented JSON contract and parses the response',
        () async {
      late http.Request captured;
      final client = MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode({
            'signature': 'server-signature',
            'timestamp': 1760000000,
          }),
          200,
          headers: const {'content-type': 'application/json'},
        );
      });
      final signer = HttpCloudinaryUploadSigner(
        endpoint: Uri.parse('https://signer.example.test/cloudinary/sign'),
        client: client,
      );

      final result = await signer.sign(
        const CloudinarySignRequest(
          parameters: {
            'folder': 'task_proofs',
            'timestamp': '1760000000',
          },
        ),
      );

      expect(captured.method, 'POST');
      expect(captured.url.toString(),
          'https://signer.example.test/cloudinary/sign');
      expect(captured.headers['content-type'], startsWith('application/json'));
      expect(
        jsonDecode(captured.body),
        {
          'parameters': {
            'folder': 'task_proofs',
            'timestamp': '1760000000',
          },
        },
      );
      expect(result.signature, 'server-signature');
      expect(result.timestamp, 1760000000);
    });

    test('fails on a non-success signer response', () async {
      final signer = HttpCloudinaryUploadSigner(
        endpoint: Uri.parse('https://signer.example.test/cloudinary/sign'),
        client: MockClient((_) async => http.Response('nope', 503)),
      );

      await expectLater(
        signer.sign(
          const CloudinarySignRequest(parameters: {'timestamp': '1'}),
        ),
        throwsA(isA<CloudinarySignerException>()),
      );
    });

    test('photo service fails closed when no signer is configured', () async {
      final service = PhotoSyncService.forTesting();

      final result = await service.uploadPhoto(
        File('/path/that/does/not/exist.jpg'),
        'challenge-id',
        DateTime(2026, 10, 20),
      );

      expect(result, isNull);
      expect(service.hasConfiguredSigner, isFalse);
    });
  });
}
