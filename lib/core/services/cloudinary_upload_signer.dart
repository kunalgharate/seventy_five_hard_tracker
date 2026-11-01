import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

/// The upload parameters sent to a trusted server-side Cloudinary signer.
///
/// The endpoint must sign the exact values in [parameters] and return a
/// [CloudinarySignedUpload]. The endpoint never receives the image bytes or a
/// Cloudinary API secret.
class CloudinarySignRequest {
  const CloudinarySignRequest({required this.parameters});

  final Map<String, String> parameters;

  Map<String, dynamic> toJson() => {
        'parameters': Map<String, String>.from(parameters),
      };

  factory CloudinarySignRequest.fromJson(Object? value) {
    if (value is! Map) {
      throw const FormatException(
          'Cloudinary signer request must be an object.');
    }

    final rawParameters = value['parameters'];
    if (rawParameters is! Map) {
      throw const FormatException(
        'Cloudinary signer request must contain a parameters object.',
      );
    }

    final parameters = <String, String>{};
    for (final entry in rawParameters.entries) {
      if (entry.key is! String || entry.value is! String) {
        throw const FormatException(
          'Cloudinary signer parameters must be string pairs.',
        );
      }
      parameters[entry.key as String] = entry.value as String;
    }
    return CloudinarySignRequest(parameters: parameters);
  }
}

/// The minimum response contract required for a signed Cloudinary upload.
///
/// `signature` and `timestamp` are always supplied by the signer. `apiKey`
/// and `cloudName` may be returned by the endpoint or supplied by local
/// configuration, but an upload is rejected unless both effective values are
/// present.
class CloudinarySignedUpload {
  const CloudinarySignedUpload({
    required this.signature,
    required this.timestamp,
    this.apiKey,
    this.cloudName,
  });

  final String signature;
  final int timestamp;
  final String? apiKey;
  final String? cloudName;

  Map<String, dynamic> toJson() => {
        'signature': signature,
        'timestamp': timestamp,
        if (apiKey != null) 'api_key': apiKey,
        if (cloudName != null) 'cloud_name': cloudName,
      };

  factory CloudinarySignedUpload.fromJson(Object? value) {
    if (value is! Map) {
      throw const FormatException(
        'Cloudinary signer response must be an object.',
      );
    }

    final signature = _requiredString(value['signature'], 'signature');
    final timestamp = _requiredInt(value['timestamp'], 'timestamp');
    final apiKey = _optionalString(value['api_key'] ?? value['apiKey']);
    final cloudName =
        _optionalString(value['cloud_name'] ?? value['cloudName']);

    return CloudinarySignedUpload(
      signature: signature,
      timestamp: timestamp,
      apiKey: apiKey,
      cloudName: cloudName,
    );
  }
}

abstract interface class CloudinaryUploadSigner {
  Future<CloudinarySignedUpload> sign(CloudinarySignRequest request,
      {String? authToken});
}

/// HTTP implementation of the signer endpoint contract:
///
/// ```json
/// POST {"parameters":{"folder":"task_proofs","timestamp":"..."}}
/// 200 {"signature":"...","timestamp":0,"api_key":"...",
///      "cloud_name":"..."}
/// ```
///
/// The signer may omit `api_key` and `cloud_name` when those values are
/// supplied by [CloudinarySignerConfiguration].
class HttpCloudinaryUploadSigner implements CloudinaryUploadSigner {
  HttpCloudinaryUploadSigner({required this.endpoint, http.Client? client})
      : _client = client ?? http.Client();

  final Uri endpoint;
  final http.Client _client;
  static const _signTimeout = Duration(seconds: 15);

  @override
  Future<CloudinarySignedUpload> sign(CloudinarySignRequest request,
      {String? authToken}) async {
    final headers = <String, String>{
      'accept': 'application/json',
      'content-type': 'application/json',
    };
    if (authToken != null && authToken.isNotEmpty) {
      headers['authorization'] = 'Bearer $authToken';
    }

    final response = await _client
        .post(
          endpoint,
          headers: headers,
          body: jsonEncode(request.toJson()),
        )
        .timeout(_signTimeout);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw CloudinarySignerException(
        'Signer endpoint returned HTTP ${response.statusCode}.',
      );
    }

    final decoded = jsonDecode(response.body);
    return CloudinarySignedUpload.fromJson(decoded);
  }
}

/// Signs Cloudinary upload parameters on-device. Used when no signing
/// endpoint is deployed — the API secret ships inside the build (less
/// secure than a server signer; acceptable for this app's threat model).
class LocalCloudinaryUploadSigner implements CloudinaryUploadSigner {
  LocalCloudinaryUploadSigner({
    required this.apiSecret,
    this.apiKey,
    this.cloudName,
  });

  final String apiSecret;
  final String? apiKey;
  final String? cloudName;

  @override
  Future<CloudinarySignedUpload> sign(CloudinarySignRequest request,
      {String? authToken}) async {
    // Cloudinary signature: SHA-1 hex of the alphabetically sorted
    // "key=value" pairs, joined with '&', with the API secret appended.
    final entries = request.parameters.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final payload =
        entries.map((e) => '${e.key}=${e.value}').join('&') + apiSecret;
    final signature = sha1.convert(utf8.encode(payload)).toString();
    final timestamp =
        int.tryParse(request.parameters['timestamp'] ?? '') ??
            DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return CloudinarySignedUpload(
      signature: signature,
      timestamp: timestamp,
      apiKey: apiKey,
      cloudName: cloudName,
    );
  }
}

/// Client-side configuration that is safe to ship with the app. The API
/// secret is intentionally absent; it must remain on the signer server —
/// unless the app uses the local signer, in which case it comes from
/// dart-define at build time and is never committed to source control.
class CloudinarySignerConfiguration {
  const CloudinarySignerConfiguration({
    required this.endpoint,
    required this.cloudName,
    this.apiKey,
    this.apiSecret,
  });

  /// Empty when signing happens on-device (local signer mode).
  final Uri endpoint;
  final String cloudName;
  final String? apiKey;
  final String? apiSecret;

  bool get isValid =>
      cloudName.isNotEmpty &&
      ((endpoint.scheme == 'https' && endpoint.host.isNotEmpty) ||
          (apiKey != null &&
              apiKey!.isNotEmpty &&
              apiSecret != null &&
              apiSecret!.isNotEmpty));

  /// Reads an endpoint and cloud name supplied at build time. Without both,
  /// [PhotoSyncService] has no signer and fails closed.
  static CloudinarySignerConfiguration? fromEnvironment() {
    const endpoint = String.fromEnvironment('CLOUDINARY_SIGNER_ENDPOINT');
    const cloudName = String.fromEnvironment('CLOUDINARY_CLOUD_NAME');
    const apiKey = String.fromEnvironment('CLOUDINARY_API_KEY');
    const apiSecret = String.fromEnvironment('CLOUDINARY_API_SECRET');
    if (cloudName.isEmpty) return null;

    // Local-signer mode: no endpoint, but key+secret let the app sign
    // upload parameters directly.
    if (endpoint.isEmpty) {
      if (apiKey.isEmpty || apiSecret.isEmpty) return null;
      return CloudinarySignerConfiguration(
        endpoint: Uri.https('localhost', '/'),
        cloudName: cloudName,
        apiKey: apiKey,
        apiSecret: apiSecret,
      );
    }

    final parsed = Uri.tryParse(endpoint);
    if (parsed == null) return null;
    return CloudinarySignerConfiguration(
      endpoint: parsed,
      cloudName: cloudName,
      apiKey: apiKey.isEmpty ? null : apiKey,
      apiSecret: apiSecret.isEmpty ? null : apiSecret,
    );
  }
}

class CloudinarySignerException implements Exception {
  const CloudinarySignerException(this.message);

  final String message;

  @override
  String toString() => 'CloudinarySignerException: $message';
}

String _requiredString(Object? value, String field) {
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('Cloudinary signer response requires "$field".');
  }
  return value;
}

String? _optionalString(Object? value) {
  if (value == null) return null;
  if (value is! String || value.trim().isEmpty) {
    throw const FormatException(
      'Optional Cloudinary signer response fields must be non-empty strings.',
    );
  }
  return value;
}

int _requiredInt(Object? value, String field) {
  if (value is int) return value;
  if (value is num && value == value.roundToDouble()) return value.toInt();
  if (value is String) {
    final parsed = int.tryParse(value);
    if (parsed != null) return parsed;
  }
  throw FormatException(
      'Cloudinary signer response requires integer "$field".');
}
