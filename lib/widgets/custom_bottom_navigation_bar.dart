import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class CustomBottomNavigationBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int>? onSelected;
  final bool immersive;
  final bool interactionEmphasis;
  final VoidCallback? onInteractionStart;
  final double backdropLuminance;

  const CustomBottomNavigationBar({
    super.key,
    required this.currentIndex,
    this.onSelected,
    this.immersive = false,
    this.interactionEmphasis = true,
    this.onInteractionStart,
    this.backdropLuminance = .3,
  });

  static const items = <_NavItem>[
    _NavItem(CupertinoIcons.house, CupertinoIcons.house_fill, 'Home'),
    _NavItem(CupertinoIcons.map, CupertinoIcons.map_fill, 'Explore'),
    _NavItem(CupertinoIcons.play_rectangle, CupertinoIcons.play_rectangle_fill,
        'Tours'),
    _NavItem(CupertinoIcons.bookmark, CupertinoIcons.bookmark_fill, 'Saved'),
  ];

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final target = !immersive || interactionEmphasis ? 1.0 : 0.0;

    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: target),
        duration: Duration(
            milliseconds: interactionEmphasis || !immersive ? 140 : 680),
        curve: interactionEmphasis || !immersive
            ? Curves.easeOutCubic
            : Curves.easeInOutCubic,
        builder: (context, emphasis, _) => Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (_) => onInteractionStart?.call(),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(25),
            child: BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: 16 + (8 * emphasis),
                sigmaY: 16 + (8 * emphasis),
              ),
              child: Container(
                height: 64,
                padding: const EdgeInsets.symmetric(horizontal: 7),
                decoration: _decoration(colors, dark, emphasis),
                child: Row(
                  children: List.generate(items.length, (index) {
                    final item = items[index];
                    final selected = index == currentIndex;
                    final normalColor =
                        selected ? colors.primary : colors.onSurfaceVariant;
                    final restingColor = selected
                        ? colors.primary
                        : backdropLuminance > .58
                            ? Colors.black.withValues(alpha: .76)
                            : Colors.white.withValues(alpha: .8);
                    final color = immersive
                        ? Color.lerp(
                            restingColor,
                            normalColor,
                            emphasis,
                          )!
                        : normalColor;
                    return Expanded(
                      child: CupertinoButton(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(44, 44),
                        pressedOpacity: .55,
                        onPressed: () => onSelected?.call(index),
                        child: Semantics(
                          selected: selected,
                          label: item.label,
                          button: true,
                          child: AnimatedScale(
                            scale: selected ? 1 : .96,
                            duration: const Duration(milliseconds: 180),
                            curve: Curves.easeOutCubic,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 38,
                                  height: 28,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    color: selected
                                        ? Colors.white.withValues(
                                            alpha: immersive
                                                ? _lerp(.2, dark ? .065 : .32,
                                                    emphasis)
                                                : dark
                                                    ? .065
                                                    : .32)
                                        : Colors.transparent,
                                    border: selected
                                        ? Border.all(
                                            color: Colors.white.withValues(
                                              alpha: immersive
                                                  ? _lerp(.24, dark ? .09 : .44,
                                                      emphasis)
                                                  : dark
                                                      ? .09
                                                      : .44,
                                            ),
                                            width: .45,
                                          )
                                        : null,
                                  ),
                                  child: Icon(
                                    selected ? item.selectedIcon : item.icon,
                                    color: color,
                                    size: 23,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(item.label,
                                    style: TextStyle(
                                      color: color,
                                      fontSize: 10.5,
                                      height: 1,
                                      fontWeight: selected
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                    )),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  BoxDecoration _decoration(ColorScheme colors, bool dark, double emphasis) {
    final luminance = backdropLuminance.clamp(0.0, 1.0);
    // Bright or visually exposed media needs a stronger resting material;
    // darker imagery can safely let more of the tour show through.
    final adaptiveRestAlpha = _lerp(.22, .52, luminance);
    final surfaceAlpha = immersive
        ? _lerp(adaptiveRestAlpha, dark ? .84 : .88, emphasis)
        : dark
            ? .84
            : .88;
    return BoxDecoration(
      color: colors.surface.withValues(alpha: surfaceAlpha),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(
              alpha: immersive
                  ? _lerp(.08, dark ? .055 : .18, emphasis)
                  : dark
                      ? .055
                      : .18),
          Colors.white.withValues(
              alpha: immersive
                  ? _lerp(.018, dark ? .012 : .035, emphasis)
                  : dark
                      ? .012
                      : .035),
          colors.primary.withValues(
              alpha: immersive
                  ? _lerp(.012, dark ? .025 : .018, emphasis)
                  : dark
                      ? .025
                      : .018),
        ],
        stops: const [0, .48, 1],
      ),
      borderRadius: BorderRadius.circular(25),
      border: Border.all(
        color: immersive
            ? Color.lerp(
                Colors.white.withValues(alpha: _lerp(.22, .42, luminance)),
                colors.outlineVariant.withValues(alpha: .8),
                emphasis)!
            : colors.outlineVariant.withValues(alpha: .8),
        width: .7,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(
              alpha: immersive
                  ? _lerp(.07, dark ? .24 : .09, emphasis)
                  : dark
                      ? .24
                      : .09),
          blurRadius: _lerp(14, 26, emphasis),
          offset: Offset(0, _lerp(5, 10, emphasis)),
        ),
        BoxShadow(
          color: Colors.white.withValues(
              alpha: immersive
                  ? _lerp(.1, dark ? .04 : .42, emphasis)
                  : dark
                      ? .04
                      : .42),
          blurRadius: 1,
          offset: const Offset(0, -1),
        ),
      ],
    );
  }

  static double _lerp(double start, double end, double amount) =>
      start + ((end - start) * amount);
}

class _NavItem {
  final IconData icon;
  final IconData selectedIcon;
  final String label;

  const _NavItem(this.icon, this.selectedIcon, this.label);
}
