import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

class HavenApiException implements Exception {
  final String message;
  final int? statusCode;
  final String? code;

  const HavenApiException(this.message, {this.statusCode, this.code});

  factory HavenApiException.fromResponse(
    http.Response response, {
    required String operation,
  }) {
    final detail = ApiErrorResolver.responseDetail(response.body);
    return HavenApiException(
      detail ?? ApiErrorResolver.statusMessage(response.statusCode, operation),
      statusCode: response.statusCode,
      code: ApiErrorResolver.responseCode(response.body),
    );
  }

  @override
  String toString() => message;
}

class ApiErrorResolver {
  const ApiErrorResolver._();

  static String message(
    Object error, {
    required String fallback,
  }) {
    if (error is HavenApiException) return error.message;
    if (error is TimeoutException) {
      return 'The request timed out before Haven responded. Check your connection and try again.';
    }
    if (error is HandshakeException) {
      return 'A secure connection to Haven could not be established. Check your device date, network, or server certificate.';
    }
    if (error is SocketException) {
      final raw = error.message.toLowerCase();
      if (raw.contains('refused')) {
        return 'The Haven server refused the connection. Confirm the server is running and reachable from this device.';
      }
      if (raw.contains('host lookup') || raw.contains('nodename')) {
        return 'The Haven server address could not be found. Check your internet connection or server address.';
      }
      if (raw.contains('network is unreachable') ||
          raw.contains('no route to host')) {
        return 'This device has no route to the Haven server. Check Wi-Fi or mobile data and try again.';
      }
      return 'The network connection ended before Haven responded. Check your connection and try again.';
    }
    if (error is FormatException) {
      return 'Haven received a response it could not read. The server may be returning an invalid or incomplete response.';
    }
    if (error is MissingPluginException) {
      return 'This device integration is not ready. Fully restart Haven after installing or updating the app.';
    }
    if (error is PlatformException) {
      final code = error.code.toLowerCase();
      if (code.contains('permission') || code.contains('access_denied')) {
        return 'Haven does not have the required device permission. Enable it in system settings and try again.';
      }
      if (code.contains('camera') &&
          (code.contains('unavailable') || code.contains('not_available'))) {
        return 'No usable camera is available on this device.';
      }
      if (code.contains('already_active')) {
        return 'Another media picker is already open. Close it before trying again.';
      }
      final detail = error.message?.trim();
      return detail?.isNotEmpty == true
          ? detail!
          : 'The device could not complete the requested action (${error.code}).';
    }
    final raw = error
        .toString()
        .replaceFirst(RegExp(r'^(Exception|HttpException):\s*'), '')
        .trim();
    if (raw.isNotEmpty &&
        raw != 'Exception' &&
        !raw.contains('SocketException') &&
        !raw.contains('ClientException') &&
        !_looksTechnical(raw)) {
      return raw;
    }
    return fallback;
  }

  static bool _looksTechnical(String value) {
    final lower = value.toLowerCase();
    return const [
      'fluttererror',
      'renderflex',
      'setstate()',
      'nosuchmethod',
      'null check operator',
      'typeerror',
      'rangeerror',
      'unsupported operation',
      'package:',
      'file://',
      'instance of',
    ].any(lower.contains);
  }

  static String statusMessage(int status, String operation) => switch (status) {
        400 =>
          '$operation could not be completed because some submitted information was invalid.',
        401 => 'Your session has expired. Sign in again to continue.',
        403 => 'Your account does not have permission to $operation.',
        404 =>
          'The requested item could not be found. It may have been removed or changed.',
        408 => '$operation timed out before the server finished processing it.',
        409 =>
          '$operation conflicts with a newer change. Refresh the page and try again.',
        413 =>
          'The selected upload is larger than the server allows. Reduce the file size or number of files.',
        422 =>
          '$operation needs corrected information. Review the fields and try again.',
        429 =>
          'Too many attempts were made in a short time. Wait a moment before trying again.',
        500 =>
          'Haven could not $operation because the server encountered an internal error.',
        502 ||
        503 ||
        504 =>
          'The Haven service needed to $operation is temporarily unavailable.',
        _ => '$operation failed with server response $status.',
      };

  static String? responseDetail(String body) {
    if (body.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(body);
      if (decoded is! Map) return null;
      for (final key in const ['errors', 'messages']) {
        final validation = decoded[key];
        if (validation is Map) {
          for (final value in validation.values) {
            if (value is List && value.isNotEmpty) {
              final text = value.first.toString().trim();
              if (text.isNotEmpty) return text;
            }
            final text = value?.toString().trim() ?? '';
            if (text.isNotEmpty) return text;
          }
        }
      }
      for (final key in const ['message', 'error', 'detail']) {
        final text = decoded[key]?.toString().trim() ?? '';
        if (text.isNotEmpty && text.toLowerCase() != 'validation failed') {
          return text;
        }
      }
    } catch (_) {
      // HTML and malformed bodies are deliberately replaced by status guidance.
    }
    return null;
  }

  static String? responseCode(String body) {
    try {
      final decoded = jsonDecode(body);
      return decoded is Map ? decoded['code']?.toString() : null;
    } catch (_) {
      return null;
    }
  }
}
