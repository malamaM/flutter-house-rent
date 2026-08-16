import 'dart:collection';

import 'package:flutter/scheduler.dart';

class PerformanceMonitor {
  PerformanceMonitor._();
  static final instance = PerformanceMonitor._();

  final Queue<NetworkTiming> _requests = Queue();
  int _slowFrames = 0;
  int _severelySlowFrames = 0;
  bool _initialized = false;

  void initialize() {
    if (_initialized) return;
    _initialized = true;
    SchedulerBinding.instance.addTimingsCallback((timings) {
      for (final timing in timings) {
        // 17 ms catches missed 60 Hz deadlines, while 9 ms catches frames that
        // cannot sustain a 120 Hz display's 8.33 ms budget.
        if (timing.totalSpan > const Duration(milliseconds: 9)) _slowFrames++;
        if (timing.totalSpan > const Duration(milliseconds: 17)) {
          _severelySlowFrames++;
        }
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
        severelySlowFrames: _severelySlowFrames,
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
  final int severelySlowFrames;
  final List<NetworkTiming> recentRequests;
  const PerformanceSnapshot({
    required this.slowFrames,
    required this.severelySlowFrames,
    required this.recentRequests,
  });
}
