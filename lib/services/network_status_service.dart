import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:house_rent/config/api_config.dart';
import 'package:http/http.dart' as http;

enum NetworkAvailability { checking, online, offline }

/// Tracks actual Haven API reachability rather than merely whether Wi-Fi or
/// cellular is enabled. A connected network without internet is still offline.
class NetworkStatusService with WidgetsBindingObserver {
  NetworkStatusService._();
  static final instance = NetworkStatusService._();

  final ValueNotifier<NetworkAvailability> availability =
      ValueNotifier(NetworkAvailability.checking);
  Timer? _timer;
  bool _checking = false;
  bool _hasConfirmedConnection = false;
  int _startupFailures = 0;

  bool get isOnline => availability.value == NetworkAvailability.online;

  void initialize() {
    WidgetsBinding.instance.addObserver(this);
    unawaited(checkNow());
    _timer ??= Timer.periodic(
      const Duration(seconds: 20),
      (_) => unawaited(checkNow()),
    );
  }

  Future<bool> checkNow() async {
    if (_checking) return isOnline;
    _checking = true;
    try {
      final response = await http
          .get(Uri.parse('${ApiConfig.apiBase}/health'))
          .timeout(const Duration(seconds: 4));
      if (response.statusCode >= 200 && response.statusCode < 500) {
        _hasConfirmedConnection = true;
        _startupFailures = 0;
        _set(NetworkAvailability.online);
      } else {
        _handleProbeFailure();
      }
    } catch (_) {
      _handleProbeFailure();
    } finally {
      _checking = false;
    }
    return isOnline;
  }

  void reportOnline() {
    _hasConfirmedConnection = true;
    _startupFailures = 0;
    _set(NetworkAvailability.online);
  }

  void reportOffline() {
    if (_hasConfirmedConnection) _set(NetworkAvailability.offline);
  }

  void _handleProbeFailure() {
    // A physical device often reaches the app before its Wi-Fi, Bonjour/DNS or
    // local Laravel server has fully settled. Do not show a false offline
    // state from that single launch-time race. Retest twice quickly first.
    if (!_hasConfirmedConnection && _startupFailures < 2) {
      _startupFailures++;
      _set(NetworkAvailability.checking);
      Future<void>.delayed(const Duration(seconds: 1), () {
        unawaited(checkNow());
      });
      return;
    }
    _set(NetworkAvailability.offline);
  }

  void _set(NetworkAvailability value) {
    if (availability.value != value) availability.value = value;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(checkNow());
  }
}
