import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// A quiet, platform-neutral navigation bar with iOS proportions and the
/// native Cupertino back affordance on pushed routes.
class HavenNavigationBar extends StatelessWidget
    implements PreferredSizeWidget {
  final String title;
  final Widget? trailing;

  const HavenNavigationBar({super.key, required this.title, this.trailing});

  @override
  Size get preferredSize => const Size.fromHeight(46);

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return CupertinoNavigationBar(
      middle: Text(title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleMedium),
      trailing: trailing,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor.withValues(
          alpha: Theme.of(context).brightness == Brightness.dark ? .89 : .87),
      border: Border(
          bottom: BorderSide(
              color: colors.outlineVariant.withValues(alpha: .72), width: .5)),
      transitionBetweenRoutes: false,
    );
  }
}
