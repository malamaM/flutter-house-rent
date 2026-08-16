import 'dart:async';

import 'package:flutter/material.dart';
import 'package:house_rent/screens/home/explore.dart';
import 'package:house_rent/screens/home/home.dart';
import 'package:house_rent/screens/home/reels_screen.dart';
import 'package:house_rent/screens/home/saved_houses_screen.dart';
import 'package:house_rent/services/current_location_service.dart';
import 'package:house_rent/services/navigation_warmup_service.dart';
import 'package:house_rent/widgets/custom_bottom_navigation_bar.dart';

/// Keeps every primary tab and its nested navigation stack alive.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  /// Selects a primary tab without pushing a duplicate tab screen onto the
  /// current tab's nested navigator.
  static bool selectTab(BuildContext context, int index) {
    final state = context.findAncestorStateOfType<_AppShellState>();
    if (state == null) return false;
    state._selectTab(index);
    return true;
  }

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _currentIndex = 0;
  final _navigatorKeys = List.generate(4, (_) => GlobalKey<NavigatorState>());
  final _routeDepths = List<int>.filled(4, 0);
  late final List<_TabNavigatorObserver> _observers;
  final Set<int> _mountedTabs = {0};
  final List<Timer> _warmupTimers = [];

  @override
  void initState() {
    super.initState();
    _observers = List.generate(
      4,
      (index) => _TabNavigatorObserver((depth) {
        _routeDepths[index] = depth;
        if (!mounted || index != _currentIndex) return;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() {});
        });
      }),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(CurrentLocationService.instance.warm());
      _warmupTimers.add(Timer(const Duration(milliseconds: 700),
          () => _mountTab(1))); // Map first: it has the heaviest cold start.
      _warmupTimers
          .add(Timer(const Duration(milliseconds: 1300), () => _mountTab(3)));
      _warmupTimers
          .add(Timer(const Duration(milliseconds: 2100), () => _mountTab(2)));
      unawaited(NavigationWarmupService.instance.warmTab(0));
    });
  }

  void _mountTab(int index) {
    if (mounted && _mountedTabs.add(index)) setState(() {});
  }

  @override
  void dispose() {
    for (final timer in _warmupTimers) {
      timer.cancel();
    }
    super.dispose();
  }

  void _selectTab(int index) {
    if (index == _currentIndex) {
      _navigatorKeys[index].currentState?.popUntil((route) => route.isFirst);
      return;
    }
    setState(() {
      _mountedTabs.add(index);
      _currentIndex = index;
    });
    unawaited(NavigationWarmupService.instance.warmTab(index));
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        final navigator = _navigatorKeys[_currentIndex].currentState;
        if (navigator?.canPop() ?? false) {
          navigator!.pop();
        } else if (_currentIndex != 0) {
          _selectTab(0);
        }
      },
      child: Scaffold(
        extendBody: true,
        body: IndexedStack(
          index: _currentIndex,
          children: List.generate(
            4,
            (index) => !_mountedTabs.contains(index)
                ? const SizedBox.shrink()
                : TickerMode(
                    enabled: index == _currentIndex,
                    child: Navigator(
                      key: _navigatorKeys[index],
                      observers: [_observers[index]],
                      onGenerateRoute: (_) => MaterialPageRoute<void>(
                        builder: (_) => switch (index) {
                          0 => const Home(),
                          1 => const Explore(),
                          2 => const ReelsScreen(),
                          _ => const SavedHousesScreen(),
                        },
                        settings: RouteSettings(name: 'tab-$index'),
                      ),
                    ),
                  ),
          ),
        ),
        bottomNavigationBar: _routeDepths[_currentIndex] <= 1
            ? CustomBottomNavigationBar(
                currentIndex: _currentIndex,
                onSelected: _selectTab,
              )
            : null,
      ),
    );
  }
}

class _TabNavigatorObserver extends NavigatorObserver {
  final ValueChanged<int> onDepthChanged;
  int _depth = 0;

  _TabNavigatorObserver(this.onDepthChanged);

  void _report() => onDepthChanged(_depth);

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _depth++;
    _report();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (_depth > 0) _depth--;
    _report();
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (_depth > 0) _depth--;
    _report();
  }
}
