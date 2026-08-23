import 'package:flutter/cupertino.dart';

/// The single route used for every pushed Haven screen.
///
/// CupertinoPageRoute owns Apple's interactive edge-back gesture. Keeping the
/// route type consistent across nested navigators also prevents a Material
/// route lower in the stack from silently disabling that gesture.
class HavenPageRoute<T> extends CupertinoPageRoute<T> {
  HavenPageRoute({
    required super.builder,
    super.settings,
    super.title,
    super.maintainState = true,
    super.fullscreenDialog = false,
    super.allowSnapshotting = true,
  });
}
