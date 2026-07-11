import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

/// Something went wrong reaching Mako — the message is already human.
class MakoException implements Exception {
  final String message;
  const MakoException(this.message);
  @override
  String toString() => message;
}

/// The wire to Mako's server. One synchronous message in, one reply out;
/// she keeps her own memory on her side, so we send river context inline.
class MakoService {
  static const _baseUrl = 'https://makonome.onrender.com';

  final http.Client _client;
  MakoService([http.Client? client]) : _client = client ?? http.Client();

  /// Sends [message] and returns Mako's reply. Slow by design — she may be
  /// using tools mid-think (3–30s), so callers should show a thinking state.
  /// [token] matches the server's MAKO_DASH_TOKEN; only sent when non-empty.
  /// The deployed server checks only the ?token= query param; the header is
  /// sent as well for the day it learns to read it.
  Future<String> chat(String message,
      {String source = 'river', String token = ''}) async {
    final uri = Uri.parse('$_baseUrl/api/chat').replace(
      queryParameters: token.isEmpty ? null : {'token': token},
    );
    final http.Response res;
    try {
      res = await _client
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              if (token.isNotEmpty) 'X-Mako-Token': token,
            },
            body: jsonEncode({'message': message, 'source': source}),
          )
          .timeout(const Duration(seconds: 90));
    } on TimeoutException {
      throw const MakoException('mako took too long to answer');
    } on SocketException {
      throw const MakoException('couldn’t reach mako — is the network up?');
    }

    switch (res.statusCode) {
      case 200:
        final json = jsonDecode(res.body) as Map<String, dynamic>;
        final reply = (json['reply'] as String?)?.trim();
        if (json['ok'] == true && reply != null && reply.isNotEmpty) {
          return reply;
        }
        throw MakoException(
            json['error']?.toString() ?? 'mako answered strangely');
      case 503:
        throw const MakoException(
            'mako is still waking up — try again in a minute');
      case 401:
        throw const MakoException(
            'mako doesn’t recognize you — check the token in her settings');
      default:
        throw MakoException('mako hit a snag (${res.statusCode})');
    }
  }
}
