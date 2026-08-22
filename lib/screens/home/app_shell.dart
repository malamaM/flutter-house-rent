import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:house_rent/screens/home/explore.dart';
import 'package:house_rent/screens/home/home.dart';
import 'package:house_rent/screens/home/reels_screen.dart';
import 'package:house_rent/screens/home/saved_houses_screen.dart';
import 'package:house_rent/screens/profile/offline_sync_screen.dart';
import 'package:house_rent/services/current_location_service.dart';
import 'package:house_rent/services/navigation_warmup_service.dart';
import 'package:house_rent/services/app_cache.dart';
import 'package:house_rent/widgets/custom_bottom_navigation_bar.dart';
import 'package:house_rent/widgets/offline_status_pill.dart';

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
      // The splash has already prepared the first home feed. Leave a little
      // breathing room before mounting the heavier cached tabs so their map,
      // media and route work cannot compete with the first interactive frames.
      _warmupTimers.add(Timer(const Duration(milliseconds: 3200),
          () => _queueIdleMount(1))); // Map first after launch settles.
      _warmupTimers.add(
          Timer(const Duration(milliseconds: 4800), () => _queueIdleMount(3)));
      _warmupTimers.add(
          Timer(const Duration(milliseconds: 6400), () => _queueIdleMount(2)));
      _warmupTimers.add(
          Timer(const Duration(milliseconds: 3500), () => _queueIdleWarmup(0)));
    });
  }

  void _mountTab(int index) {
    if (mounted && _mountedTabs.add(index)) setState(() {});
  }

  void _queueIdleMount(int index) {
    if (!mounted || _mountedTabs.contains(index)) return;
    SchedulerBinding.instance.scheduleTask(
      () => _mountTab(index),
      Priority.idle,
      debugLabel: 'preload-tab-$index',
    );
  }

  void _queueIdleWarmup(int index) {
    if (!mounted) return;
    SchedulerBinding.instance.scheduleTask(
      () => NavigationWarmupService.instance.warmTab(index),
      Priority.idle,
      debugLabel: 'warm-tab-routes-$index',
    );
  }

  @override
  void dispose() {
    for (final timer in _warmupTimers) {
      timer.cancel();
    }
    super.dispose();
  }

  void _selectTab(int index) {
    if (index < 0 || index >= _navigatorKeys.length) return;
    final changedTab = index != _currentIndex;
    if (changedTab) {
      setState(() {
        _mountedTabs.add(index);
        _currentIndex = index;
      });
      unawaited(NavigationWarmupService.instance.warmTab(index));
      return;
    }

    // A second tap on the active tab mirrors Instagram: return to its root,
    // scroll its primary content to the top, then fetch a fresh view. This is
    // separate from house-cache updates, so it cannot reset a warm tab.
    _navigatorKeys[index].currentState?.popUntil((route) => route.isFirst);
    AppCache.instance.announce('tab-refresh', '$index');
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
        body: Stack(children: [
          IndexedStack(
            index: _currentIndex,
            children: List.generate(
              4,
              (index) => !_mountedTabs.contains(index)
                  ? const SizedBox.shrink()
                  : RepaintBoundary(
                      child: TickerMode(
                        enabled: index == _currentIndex,
                        child: Navigator(
                          key: _navigatorKeys[index],
                          observers: [_observers[index]],
                          onGenerateRoute: (_) {
                            final page = switch (index) {
                              0 => const Home(),
                              1 => const Explore(),
                              2 => const ReelsScreen(),
                              _ => const SavedHousesScreen(),
                            };
                            final settings = RouteSettings(name: 'tab-$index');
                            // The tab root must also be Cupertino on iOS. Mixing
                            // Material below a Cupertino details page can prevent
                            // Flutter from enabling its native edge-back gesture.
                            if (Theme.of(context).platform ==
                                TargetPlatform.iOS) {
                              return CupertinoPageRoute<void>(
                                builder: (_) => page,
                                settings: settings,
                              );
                            }
                            return MaterialPageRoute<void>(
                              builder: (_) => page,
                              settings: settings,
                            );
                          },
                        ),
                      ),
                    ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: _routeDepths[_currentIndex] <= 1 ? 94 : 18,
            child: SafeArea(
              top: false,
              child: Center(
                child: OfflineStatusPill(
                  onTap: () => _navigatorKeys[_currentIndex].currentState?.push(
                        MaterialPageRoute<void>(
                            builder: (_) => const OfflineSyncScreen()),
                      ),
                ),
              ),
            ),
          ),
        ]),
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
