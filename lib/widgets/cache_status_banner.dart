import 'dart:async';

import 'package:flutter/material.dart';
import 'package:house_rent/models/house.dart';

class CacheStatusBanner extends StatefulWidget {
  final String? resource;

  const CacheStatusBanner({Key? key, this.resource}) : super(key: key);

  @override
  State<CacheStatusBanner> createState() => _CacheStatusBannerState();
}

class _CacheStatusBannerState extends State<CacheStatusBanner> {
  static const _showDelay = Duration(seconds: 5);
  Timer? _showTimer;
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    House.cacheState.addListener(_stateChanged);
    _stateChanged();
  }

  @override
  void didUpdateWidget(CacheStatusBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.resource != widget.resource) _stateChanged();
  }

  bool _shouldShow(HouseCacheState state) {
    final relevant =
        widget.resource == null || state.resource == widget.resource;
    return relevant &&
        state.servedFromCache &&
        state.isStale &&
        state.refreshFailed;
  }

  void _stateChanged() {
    if (!_shouldShow(House.cacheState.value)) {
      _showTimer?.cancel();
      _showTimer = null;
      if (_visible && mounted) setState(() => _visible = false);
      return;
    }
    if (_visible || _showTimer?.isActive == true) return;
    _showTimer = Timer(_showDelay, () {
      _showTimer = null;
      if (mounted && _shouldShow(House.cacheState.value)) {
        setState(() => _visible = true);
      }
    });
  }

  @override
  void dispose() {
    House.cacheState.removeListener(_stateChanged);
    _showTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) return const SizedBox.shrink();
    return ValueListenableBuilder<HouseCacheState>(
      valueListenable: House.cacheState,
      builder: (context, state, _) {
        if (!_shouldShow(state)) {
          return const SizedBox.shrink();
        }
        return Container(
          margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Icon(Icons.cloud_off_outlined,
                  color: Theme.of(context).colorScheme.primary, size: 19),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Connection unavailable. Showing saved results${_age(state.updatedAt)}.',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _age(DateTime? updatedAt) {
    if (updatedAt == null) return '';
    final elapsed = DateTime.now().difference(updatedAt);
    if (elapsed.inMinutes < 2) return ' from moments ago';
    if (elapsed.inHours < 1) return ' from ${elapsed.inMinutes} minutes ago';
    if (elapsed.inDays < 1) return ' from ${elapsed.inHours} hours ago';
    return ' from ${elapsed.inDays} days ago';
  }
}
