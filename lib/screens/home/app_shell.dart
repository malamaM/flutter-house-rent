import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:house_rent/screens/home/explore.dart';
import 'package:house_rent/screens/home/home.dart';
import 'package:house_rent/screens/home/reels_screen.dart';
import 'package:house_rent/screens/home/saved_houses_screen.dart';
import 'package:house_rent/screens/profile/offline_sync_screen.dart';
import 'package:house_rent/models/house.dart';
import 'package:house_rent/navigation/haven_page_route.dart';
import 'package:house_rent/services/navigation_warmup_service.dart';
import 'package:house_rent/services/app_cache.dart';
import 'package:house_rent/widgets/custom_bottom_navigation_bar.dart';
import 'package:house_rent/widgets/offline_status_pill.dart';

/// Keeps every primary tab and its nested navigation stack alive.
class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    this.initialHomeFeed,
    this.initialHomeType,
  });

  final HomeFeedData? initialHomeFeed;
  final String? initialHomeType;

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

class _AppShellState extends State<AppShell> with WidgetsBindingObserver {
  int _currentIndex = 0;
  final _navigatorKeys = List.generate(4, (_) => GlobalKey<NavigatorState>());
  final _routeDepths = List<int>.filled(4, 0);
  late final List<_TabNavigatorObserver> _observers;
  final Set<int> _mountedTabs = {0};
  final List<Timer> _warmupTimers = [];
  Timer? _toursNavSettleTimer;
  bool _toursNavEmphasized = false;
  double _toursBackdropLuminance = .3;
  DateTime? _backgroundedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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
      // Fetch next-tab data quietly first. Mounting a live map or media page
      // offstage creates platform views and decoders on the UI thread, which
      // was causing the short first-open freeze. Widgets mount on demand; the
      // data and likely detail routes are already warmed when they do.
      _warmupTimers.add(
          Timer(const Duration(milliseconds: 6500), () => _queueIdleWarmup(1)));
      _warmupTimers.add(
          Timer(const Duration(milliseconds: 8500), () => _queueIdleWarmup(3)));
      _warmupTimers.add(Timer(
          const Duration(milliseconds: 10500), () => _queueIdleWarmup(2)));
      _warmupTimers.add(Timer(
          const Duration(milliseconds: 12500), () => _queueIdleWarmup(0)));
    });
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
    WidgetsBinding.instance.removeObserver(this);
    _toursNavSettleTimer?.cancel();
    for (final timer in _warmupTimers) {
      timer.cancel();
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _backgroundedAt ??= DateTime.now();
      return;
    }
    if (state != AppLifecycleState.resumed) return;
    final backgroundedAt = _backgroundedAt;
    _backgroundedAt = null;
    if (backgroundedAt == null ||
        DateTime.now().difference(backgroundedAt) <
            const Duration(minutes: 5)) {
      return;
    }
    AppCache.instance.announce('tab-refresh', '$_currentIndex');
  }

  void _selectTab(int index) {
    if (index < 0 || index >= _navigatorKeys.length) return;
    final changedTab = index != _currentIndex;
    if (changedTab) {
      setState(() {
        _mountedTabs.add(index);
        _currentIndex = index;
        _toursNavEmphasized = index == 2;
      });
      if (index == 2) {
        _scheduleToursNavSettle();
      } else {
        _toursNavSettleTimer?.cancel();
      }
      unawaited(NavigationWarmupService.instance.warmTab(index));
      return;
    }

    // A second tap on the active tab mirrors Instagram: return to its root,
    // scroll its primary content to the top, then fetch a fresh view. This is
    // separate from house-cache updates, so it cannot reset a warm tab.
    _navigatorKeys[index].currentState?.popUntil((route) => route.isFirst);
    AppCache.instance.announce('tab-refresh', '$index');
  }

  void _showToursNavigation() {
    if (!mounted || _currentIndex != 2) return;
    _toursNavSettleTimer?.cancel();
    if (!_toursNavEmphasized) {
      setState(() => _toursNavEmphasized = true);
    }
    _scheduleToursNavSettle();
  }

  void _scheduleToursNavSettle() {
    _toursNavSettleTimer?.cancel();
    _toursNavSettleTimer = Timer(const Duration(milliseconds: 1450), () {
      if (mounted && _currentIndex == 2 && _toursNavEmphasized) {
        setState(() => _toursNavEmphasized = false);
      }
    });
  }

  void _updateToursBackdrop(double luminance) {
    final next = luminance.clamp(0.0, 1.0);
    if (!mounted || (_toursBackdropLuminance - next).abs() < .025) return;
    setState(() => _toursBackdropLuminance = next);
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
                              0 => Home(
                                  initialFeed: widget.initialHomeFeed,
                                  initialType: widget.initialHomeType,
                                ),
                              1 => const Explore(),
                              2 => ReelsScreen(
                                  onInteraction: _showToursNavigation,
                                  onBackdropLuminance: _updateToursBackdrop,
                                ),
                              _ => const SavedHousesScreen(),
                            };
                            final settings = RouteSettings(name: 'tab-$index');
                            return HavenPageRoute<void>(
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
                        HavenPageRoute<void>(
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
                immersive: _currentIndex == 2,
                interactionEmphasis: _toursNavEmphasized,
                onInteractionStart: _showToursNavigation,
                backdropLuminance: _toursBackdropLuminance,
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
