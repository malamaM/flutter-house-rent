import 'dart:collection';

import 'package:flutter/scheduler.dart';

class PerformanceMonitor {
  PerformanceMonitor._();
  static final instance = PerformanceMonitor._();

  final Queue<NetworkTiming> _requests = Queue();
  int _slowFrames = 0;
  bool _initialized = false;

  void initialize() {
    if (_initialized) return;
    _initialized = true;
    SchedulerBinding.instance.addTimingsCallback((timings) {
      for (final timing in timings) {
        if (timing.totalSpan > const Duration(milliseconds: 24)) _slowFrames++;
      }
    });
  }

  Future<T> measure<T>(String operation, Future<T> Function() request) async {
    final watch = Stopwatch()..start();
    var succeeded = false;
    try {
      final result = await request();
      succeeded = true;
      return result;
    } finally {
      watch.stop();
      _requests.addFirst(NetworkTiming(operation, watch.elapsed, succeeded));
      while (_requests.length > 40) {
        _requests.removeLast();
      }
    }
  }

  PerformanceSnapshot get snapshot => PerformanceSnapshot(
        slowFrames: _slowFrames,
        recentRequests: List.unmodifiable(_requests),
      );
}

class NetworkTiming {
  final String operation;
  final Duration duration;
  final bool succeeded;
  const NetworkTiming(this.operation, this.duration, this.succeeded);
}

class PerformanceSnapshot {
  final int slowFrames;
  final List<NetworkTiming> recentRequests;
  const PerformanceSnapshot(
      {required this.slowFrames, required this.recentRequests});
}
