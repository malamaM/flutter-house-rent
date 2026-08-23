import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:house_rent/services/api_error.dart';
import 'package:http/http.dart' as http;

void main() {
  test('uses the first server validation detail before generic status text',
      () {
    final response = http.Response(
      '{"message":"Validation failed","errors":{"email":["That email is already registered."]}}',
      422,
    );

    final error = HavenApiException.fromResponse(response,
        operation: 'create your account');

    expect(error.message, 'That email is already registered.');
    expect(error.statusCode, 422);
  });

  test('describes server upload rejection when no response body is available',
      () {
    final error = HavenApiException.fromResponse(http.Response('', 413),
        operation: 'upload listing media');

    expect(error.message, contains('larger than the server allows'));
  });

  test('distinguishes a refused server connection from ordinary offline use',
      () {
    final message = ApiErrorResolver.message(
      const SocketException('Connection refused'),
      fallback: 'Fallback',
    );

    expect(message, contains('server refused the connection'));
  });

  test('does not expose framework internals to users', () {
    final message = ApiErrorResolver.message(
      UnsupportedError('Unsupported operation: Infinity or NaN toInt'),
      fallback: 'This section could not be displayed safely.',
    );

    expect(message, 'This section could not be displayed safely.');
  });
}
