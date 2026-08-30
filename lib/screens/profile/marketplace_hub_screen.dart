import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:house_rent/navigation/haven_page_route.dart';
import 'package:house_rent/config/api_config.dart';
import 'package:house_rent/models/house.dart';
import 'package:house_rent/models/marketplace.dart';
import 'package:house_rent/screens/details/details.dart';
import 'package:house_rent/models/recommendation.dart';
import 'package:house_rent/services/marketplace_service.dart';
import 'package:house_rent/services/app_feedback.dart';
import 'package:house_rent/services/recommendation_service.dart';
import 'package:house_rent/widgets/glass_surface.dart';
import 'package:house_rent/widgets/haven_navigation_bar.dart';
import 'package:house_rent/widgets/screen_state.dart';
import 'package:url_launcher/url_launcher.dart';

class MarketplaceHubScreen extends StatefulWidget {
  final int initialTab;
  final bool selectSavedSearch;
  const MarketplaceHubScreen(
      {super.key, this.initialTab = 0, this.selectSavedSearch = false});

  @override
  State<MarketplaceHubScreen> createState() => _MarketplaceHubScreenState();
}

class _MarketplaceHubScreenState extends State<MarketplaceHubScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  late int _visibleTab;
  late Future<List<ConversationSummary>> _inbox;
  late Future<List<ViewingSummary>> _viewings;
  late Future<NotificationInbox> _notifications;
  late Future<List<SavedSearchSummary>> _searches;
  final Set<int> _expandedViewings = <int>{};

  @override
  void initState() {
    super.initState();
    _tabs = TabController(
      length: 4,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 3),
    )..addListener(_tabChanged);
    _visibleTab = _tabs.index;
    _inbox = _delayedLoad(0, MarketplaceService.instance.conversations);
    _viewings = _delayedLoad(1, MarketplaceService.instance.viewings);
    _notifications = _delayedLoad(2, MarketplaceService.instance.notifications);
    _searches = _delayedLoad(3, MarketplaceService.instance.savedSearches);
  }

  Future<T> _delayedLoad<T>(int tab, Future<T> Function() loader) async {
    final distance = (tab - widget.initialTab).abs();
    if (distance > 0) {
      await Future<void>.delayed(Duration(milliseconds: 180 * distance));
    }
    return loader();
  }

  void _tabChanged() {
    if (!_tabs.indexIsChanging && _visibleTab != _tabs.index && mounted) {
      setState(() => _visibleTab = _tabs.index);
    }
  }

  Future<void> _refresh(int tab) async {
    switch (tab) {
      case 0:
        final future = MarketplaceService.instance.conversations(refresh: true);
        if (!mounted) return;
        setState(() {
          _inbox = future;
        });
        await future;
      case 1:
        final future = MarketplaceService.instance.viewings(refresh: true);
        if (!mounted) return;
        setState(() {
          _viewings = future;
        });
        await future;
      case 2:
        final future = MarketplaceService.instance.notifications(refresh: true);
        if (!mounted) return;
        setState(() {
          _notifications = future;
        });
        await future;
      case 3:
        final future = MarketplaceService.instance.savedSearches(refresh: true);
        if (!mounted) return;
        setState(() {
          _searches = future;
        });
        await future;
    }
  }

  @override
  void dispose() {
    _tabs.removeListener(_tabChanged);
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Your Haven'),
            Text('Messages, viewings and home alerts',
                style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
        actions: [
          if (_tabs.index == 2)
            TextButton(
              onPressed: _markAllRead,
              child: const Text('Read all'),
            ),
          if (_tabs.index == 3)
            IconButton(
              tooltip: 'Home alert settings',
              onPressed: _configureHomeAlerts,
              icon: const Icon(Icons.notifications_active_outlined),
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 3, 16, 9),
            child: TabBar(
              controller: _tabs,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: const [
                Tab(text: 'Messages'),
                Tab(text: 'Viewings'),
                Tab(text: 'Updates'),
                Tab(text: 'Saved searches'),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _MarketplaceList<ConversationSummary>(
            future: _inbox,
            onRefresh: () => _refresh(0),
            onRetry: () => _refresh(0),
            emptyIcon: Icons.forum_outlined,
            emptyTitle: 'No conversations yet',
            emptyBody: 'Message a lister from a home you like.',
            itemBuilder: _conversation,
          ),
          _ViewingList(
            future: _viewings,
            onRefresh: () => _refresh(1),
            onRetry: () => _refresh(1),
            itemBuilder: _viewing,
          ),
          _NotificationList(
            future: _notifications,
            onRefresh: () => _refresh(2),
            onRetry: () => _refresh(2),
            itemBuilder: _notification,
          ),
          _MarketplaceList<SavedSearchSummary>(
            future: _searches,
            onRefresh: () => _refresh(3),
            onRetry: () => _refresh(3),
            emptyIcon: Icons.saved_search_rounded,
            emptyTitle: 'No saved searches',
            emptyBody: 'Save a search to hear when a matching home is listed.',
            itemBuilder: _savedSearch,
          ),
        ],
      ),
      floatingActionButton: _tabs.index == 3
          ? FloatingActionButton.extended(
              onPressed: _createSearch,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Save a search'),
            )
          : null,
    );
  }

  Widget _conversation(BuildContext context, ConversationSummary item) {
    return _HavenCard(
      onTap: () => Navigator.push(
        context,
        HavenPageRoute(
          builder: (_) => ConversationScreen(
            conversationId: item.id,
            propertyTitle: item.propertyTitle,
            participantName: item.participantName,
            participantImagePath: item.participantImagePath,
            participantPhone: item.participantPhone,
            participantWhatsApp: item.participantWhatsApp,
            participantEmail: item.participantEmail,
          ),
        ),
      ).then<void>((_) {
        unawaited(_refresh(0));
      }),
      child: Row(
        children: [
          _PropertyAvatar(
              imagePath: item.propertyImagePath, icon: Icons.home_outlined),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.participantName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 2),
                Text(item.propertyTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 3),
                Text(item.lastMessage,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
          const SizedBox(width: 10),
          if (item.unreadCount > 0)
            Badge(
                label:
                    Text(item.unreadCount > 99 ? '99+' : '${item.unreadCount}'))
          else
            Icon(Icons.chevron_right_rounded,
                color: Theme.of(context).colorScheme.onSurfaceVariant),
        ],
      ),
    );
  }

  Widget _viewing(BuildContext context, ViewingSummary item) {
    final expanded = _expandedViewings.contains(item.id);
    return _HavenCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: item.houseId == null ? null : () => _openViewingHouse(item),
            borderRadius: BorderRadius.circular(16),
            child: Row(
              children: [
                _PropertyAvatar(
                    imagePath: item.imagePath, icon: Icons.home_outlined),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 3),
                      Text(
                        item.otherPartyName ??
                            (item.role == ViewingRole.lister
                                ? 'Viewing requester'
                                : 'Property lister'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _StatusPill(status: item.status),
                if (item.houseId != null)
                  const Padding(
                    padding: EdgeInsets.only(left: 4),
                    child: Icon(Icons.chevron_right_rounded),
                  ),
              ],
            ),
          ),
          if (item.location.isNotEmpty) ...[
            const SizedBox(height: 7),
            Row(children: [
              Icon(Icons.location_on_outlined,
                  size: 16,
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
              const SizedBox(width: 5),
              Expanded(
                  child: Text(item.location,
                      style: Theme.of(context).textTheme.bodySmall)),
            ]),
          ],
          const SizedBox(height: 8),
          Row(children: [
            Icon(Icons.schedule_rounded,
                size: 17, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 7),
            Expanded(
              child: Text(_friendlyDate(item.requestedAt),
                  style: Theme.of(context).textTheme.bodyMedium),
            ),
          ]),
          if (item.isPast && !item.isArchived) ...[
            const SizedBox(height: 7),
            Text(
              item.status == 'confirmed'
                  ? 'Viewing time has passed · update the outcome'
                  : 'Viewing time has passed',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 260),
            sizeCurve: Curves.easeOutCubic,
            crossFadeState:
                expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            firstChild: const SizedBox(width: double.infinity),
            secondChild: _viewingExpandedDetails(item),
          ),
          Center(
            child: TextButton.icon(
              onPressed: () => setState(() {
                expanded
                    ? _expandedViewings.remove(item.id)
                    : _expandedViewings.add(item.id);
              }),
              icon: Icon(expanded
                  ? Icons.keyboard_arrow_up_rounded
                  : Icons.keyboard_arrow_down_rounded),
              label: Text(expanded ? 'Show less' : 'See details'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _viewingExpandedDetails(ViewingSummary item) {
    final actions = _viewingActions(item);
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ViewingDetail(
            label: item.role == ViewingRole.lister ? 'Requester' : 'Lister',
            value: item.otherPartyName ??
                (item.role == ViewingRole.lister
                    ? 'Renter details unavailable'
                    : 'Lister details unavailable'),
          ),
          const SizedBox(height: 8),
          Text(_viewingStatusDescription(item),
              style: Theme.of(context).textTheme.bodySmall),
          if (item.note != null) ...[
            const SizedBox(height: 8),
            _ViewingDetail(label: 'Your note', value: item.note!),
          ],
          if (item.listerResponse != null) ...[
            const SizedBox(height: 8),
            _ViewingDetail(
                label: 'Lister response', value: item.listerResponse!),
          ],
          if (item.respondedAt != null) ...[
            const SizedBox(height: 7),
            Text('Responded ${_relativeTime(item.respondedAt!)}',
                style: Theme.of(context).textTheme.bodySmall),
          ],
          const SizedBox(height: 11),
          Text(
              item.role == ViewingRole.lister
                  ? 'Requester contact'
                  : 'Lister contact',
              style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 7),
          if (_hasContact(item)) ...[
            if (item.otherPartyPhone != null)
              _ContactValue(
                  icon: Icons.phone_outlined, value: item.otherPartyPhone!),
            if (item.otherPartyWhatsApp != null)
              _ContactValue(
                  icon: Icons.chat_outlined, value: item.otherPartyWhatsApp!),
            if (item.otherPartyEmail != null)
              _ContactValue(
                  icon: Icons.email_outlined, value: item.otherPartyEmail!),
            const SizedBox(height: 7),
            _ContactActionRow(actions: _contactActions(item)),
          ] else
            Text('No direct contact details shared',
                style: Theme.of(context).textTheme.bodySmall),
          if (actions.isNotEmpty) ...[
            const SizedBox(height: 13),
            Wrap(spacing: 8, runSpacing: 8, children: actions),
          ],
        ],
      ),
    );
  }

  bool _hasContact(ViewingSummary item) =>
      item.otherPartyPhone != null ||
      item.otherPartyWhatsApp != null ||
      item.otherPartyEmail != null;

  List<Widget> _contactActions(ViewingSummary item) => [
        if (item.otherPartyPhone != null)
          OutlinedButton.icon(
            onPressed: () => _launchContact('tel:${item.otherPartyPhone}'),
            style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                visualDensity: VisualDensity.compact),
            icon: const Icon(Icons.call_outlined, size: 17),
            label: const Text('Call', style: TextStyle(fontSize: 12)),
          ),
        if (item.otherPartyWhatsApp != null)
          OutlinedButton.icon(
            onPressed: () => _launchContact(
                'https://wa.me/${item.otherPartyWhatsApp!.replaceAll(RegExp(r'[^0-9+]'), '').replaceFirst('+', '')}'),
            style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 5),
                visualDensity: VisualDensity.compact),
            icon: const Icon(Icons.chat_outlined, size: 17),
            label: const Text('WhatsApp', style: TextStyle(fontSize: 11)),
          ),
        if (item.otherPartyEmail != null)
          OutlinedButton.icon(
            onPressed: () => _launchContact('mailto:${item.otherPartyEmail}'),
            style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                visualDensity: VisualDensity.compact),
            icon: const Icon(Icons.email_outlined, size: 17),
            label: const Text('Email', style: TextStyle(fontSize: 12)),
          ),
      ];

  Future<void> _launchContact(String rawUrl) async {
    final uri = Uri.parse(rawUrl);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
        mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('This contact option is unavailable.')));
    }
  }

  Future<void> _openViewingHouse(ViewingSummary item) async {
    try {
      final house = await House.fetchHouse(item.houseId!);
      if (!mounted) return;
      await Navigator.push(context,
          Details.route(house, isOwnerView: item.role == ViewingRole.lister));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('This property is unavailable offline.')));
    }
  }

  String _viewingStatusDescription(ViewingSummary item) {
    if (item.isArchived) {
      return 'This viewing is archived. Its details remain available for reference.';
    }
    return switch (item.status) {
      'pending' => item.role == ViewingRole.lister
          ? 'Choose a response to this request.'
          : 'Waiting for the lister to respond.',
      'confirmed' => item.isPast
          ? 'The scheduled time has passed. Mark the viewing complete, record a no-show, or cancel it.'
          : 'Viewing confirmed. Both parties have been notified.',
      'declined' => 'The lister declined this viewing request.',
      'cancelled' => 'This viewing request was cancelled.',
      'completed' => 'This viewing was marked as completed.',
      'no_show' => 'This viewing was marked as a no-show.',
      _ => 'Viewing request updated.',
    };
  }

  List<Widget> _viewingActions(ViewingSummary item) {
    if (item.isArchived) return [];
    if (item.role == ViewingRole.renter) {
      if (item.status != 'pending' && item.status != 'confirmed') return [];
      return [
        OutlinedButton(
            onPressed: () => _updateViewing(item.id, 'cancelled'),
            child: const Text('Cancel request'))
      ];
    }
    if (item.status == 'pending') {
      return [
        FilledButton.tonal(
            onPressed: () => _updateViewing(item.id, 'confirmed'),
            child: const Text('Confirm')),
        TextButton(
            onPressed: () => _updateViewing(item.id, 'declined'),
            child: const Text('Decline')),
      ];
    }
    if (item.status != 'confirmed') return [];
    return [
      if (item.isPast)
        FilledButton.tonal(
            onPressed: () => _updateViewing(item.id, 'completed'),
            child: const Text('Mark complete')),
      if (item.isPast)
        TextButton(
            onPressed: () => _updateViewing(item.id, 'no_show'),
            child: const Text('No-show')),
      TextButton(
          onPressed: () => _updateViewing(item.id, 'cancelled'),
          child: const Text('Cancel viewing')),
    ];
  }

  Widget _notification(BuildContext context, HavenNotification item) {
    return _HavenCard(
      onTap: item.isRead ? null : () => _readNotification(item.id),
      emphasized: !item.isRead,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _IconDisc(icon: _notificationIcon(item.kind)),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(
                      child: Text(item.title,
                          style: Theme.of(context).textTheme.titleMedium)),
                  if (!item.isRead) const _UnreadDot(),
                ]),
                if (item.body.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(item.body,
                      style: Theme.of(context).textTheme.bodyMedium),
                ],
                if (item.createdAt != null) ...[
                  const SizedBox(height: 7),
                  Text(_relativeTime(item.createdAt!),
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _savedSearch(BuildContext context, SavedSearchSummary item) {
    return _HavenCard(
      onTap: widget.selectSavedSearch
          ? () => Navigator.pop(context, item.criteria)
          : null,
      child: Row(
        children: [
          const _IconDisc(icon: Icons.saved_search_rounded),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 5),
                Text(item.description,
                    style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
          Switch.adaptive(
            value: item.alertsEnabled,
            onChanged: (value) => _toggleSearch(item.id, value),
          ),
          PopupMenuButton<String>(
            tooltip: 'Saved search options',
            onSelected: (value) {
              if (value == 'delete') _deleteSearch(item);
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                  value: 'delete', child: Text('Delete saved search')),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _updateViewing(int id, String status) async {
    await _perform(() => MarketplaceService.instance.updateViewing(id, status),
        success: 'Viewing updated.');
    if (mounted) await _refresh(1);
  }

  Future<void> _readNotification(String id) async {
    await _perform(() => MarketplaceService.instance.markNotificationRead(id));
    if (mounted) await _refresh(2);
  }

  Future<void> _markAllRead() async {
    await _perform(MarketplaceService.instance.markAllNotificationsRead,
        success: 'Updates marked as read.');
    if (mounted) await _refresh(2);
  }

  Future<void> _toggleSearch(int id, bool enabled) async {
    await _perform(
        () => MarketplaceService.instance.setSavedSearchAlerts(id, enabled));
    if (mounted) await _refresh(3);
  }

  Future<void> _deleteSearch(SavedSearchSummary item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete saved search?'),
        content: Text('You will stop receiving alerts for “${item.name}”.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep it')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true) return;
    await _perform(() => MarketplaceService.instance.deleteSavedSearch(item.id),
        success: 'Saved search deleted.');
    if (mounted) await _refresh(3);
  }

  Future<void> _createSearch() async {
    final criteria = await Navigator.push<_SavedSearchDraft>(
      context,
      HavenPageRoute(builder: (_) => const _SavedSearchSheet()),
    );
    if (criteria == null) return;
    await _perform(
      () => MarketplaceService.instance.createSavedSearch(
          name: criteria.name,
          criteria: criteria.criteria,
          alertsEnabled: criteria.alertsEnabled),
      success: criteria.alertsEnabled
          ? 'Search saved. Home alerts are on.'
          : 'Search saved.',
    );
    if (mounted) await _refresh(3);
  }

  Future<void> _configureHomeAlerts() async {
    try {
      final enabled =
          await MarketplaceService.instance.recommendationAlertsEnabled();
      if (!mounted) return;
      final selected = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Very good match alerts'),
          content: const Text(
              'Get a home alert when a newly listed property is a very strong match for your Haven preferences. Saved-search alerts remain controlled separately on each search.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(enabled ? 'Turn off' : 'Keep off')),
            FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(enabled ? 'Keep on' : 'Turn on')),
          ],
        ),
      );
      if (selected == null || selected == enabled) return;
      await MarketplaceService.instance.setRecommendationAlerts(selected);
      if (mounted) {
        _notice('Very good match alerts ${selected ? 'on' : 'off'}.');
      }
    } on MarketplaceException catch (error) {
      if (mounted) _notice(error.message);
    }
  }

  Future<void> _perform(Future<void> Function() operation,
      {String? success}) async {
    try {
      await operation();
      if (success != null && mounted) _notice(success);
    } on MarketplaceException catch (error) {
      if (mounted) _notice(error.message);
    }
  }

  void _notice(String message) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(message)));

  String _friendlyDate(DateTime? value) {
    if (value == null) return 'Time not available';
    final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
    final period = value.hour >= 12 ? 'PM' : 'AM';
    return '${value.day}/${value.month}/${value.year} · $hour:${value.minute.toString().padLeft(2, '0')} $period';
  }

  String _relativeTime(DateTime value) {
    final age = DateTime.now().difference(value);
    if (age.inMinutes < 1) return 'Just now';
    if (age.inHours < 1) return '${age.inMinutes}m ago';
    if (age.inDays < 1) return '${age.inHours}h ago';
    if (age.inDays < 7) return '${age.inDays}d ago';
    return '${value.day}/${value.month}/${value.year}';
  }

  IconData _notificationIcon(String kind) => switch (kind) {
        'new_message' => Icons.chat_bubble_outline_rounded,
        'saved_search_match' => Icons.auto_awesome_rounded,
        'viewing_requested' ||
        'viewing_updated' =>
          Icons.calendar_month_outlined,
        'listing_expiring' => Icons.schedule_rounded,
        'verification_updated' => Icons.verified_user_outlined,
        _ => Icons.notifications_none_rounded,
      };
}

class ConversationScreen extends StatefulWidget {
  final int conversationId;
  final String propertyTitle;
  final String participantName;
  final String? participantImagePath;
  final String? participantEmail;
  final String? participantPhone;
  final String? participantWhatsApp;

  const ConversationScreen({
    super.key,
    required this.conversationId,
    required this.propertyTitle,
    required this.participantName,
    this.participantImagePath,
    this.participantEmail,
    this.participantPhone,
    this.participantWhatsApp,
  });

  @override
  State<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends State<ConversationScreen>
    with WidgetsBindingObserver {
  final _text = TextEditingController();
  final _scroll = ScrollController();
  Timer? _receiptTimer;
  List<ChatMessage> _messages = const [];
  bool _loading = true;
  bool _sending = false;
  bool _refreshing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load(refresh: true);
    _receiptTimer =
        Timer.periodic(const Duration(seconds: 15), (_) => _refreshReceipts());
  }

  Future<void> _load({bool refresh = false}) async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final messages = await MarketplaceService.instance
          .messages(widget.conversationId, refresh: refresh);
      if (!mounted) return;
      setState(() {
        _messages = messages;
        _loading = false;
      });
      _scrollToBottom();
      unawaited(_markConversationRead());
    } on MarketplaceException catch (error) {
      if (mounted) {
        setState(() {
          _error = error.message;
          _loading = false;
        });
      }
    }
  }

  Future<void> _markConversationRead() async {
    try {
      await MarketplaceService.instance
          .markConversationRead(widget.conversationId);
    } catch (_) {
      // The next refresh/resume retries the receipt when connectivity returns.
    }
  }

  Future<void> _refreshReceipts() async {
    if (!mounted || _loading || _refreshing || _sending) return;
    _refreshing = true;
    try {
      final messages = await MarketplaceService.instance
          .messages(widget.conversationId, refresh: true);
      if (mounted) {
        setState(() => _messages = messages);
        unawaited(_markConversationRead());
      }
    } catch (_) {
      // Keep the current conversation visible during temporary outages.
    } finally {
      _refreshing = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_refreshReceipts());
    }
  }

  Future<void> _send() async {
    final body = _text.text.trim();
    if (body.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      final message = await MarketplaceService.instance
          .sendMessage(widget.conversationId, body);
      if (!mounted) return;
      _text.clear();
      setState(() {
        _messages = [..._messages, message];
        _sending = false;
      });
      _scrollToBottom();
    } on MarketplaceException catch (error) {
      if (!mounted) return;
      setState(() => _sending = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic);
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _receiptTimer?.cancel();
    _text.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: HavenNavigationBar(
        title: widget.participantName,
        middle: _ConversationParticipantHeader(
          name: widget.participantName,
          propertyTitle: widget.propertyTitle,
          imagePath: widget.participantImagePath,
          onTap: _showParticipantProfile,
        ),
      ),
      body: Column(
        children: [
          Expanded(child: _messageBody()),
          SafeArea(
              top: false,
              child: _Composer(
                  controller: _text, sending: _sending, onSend: _send)),
        ],
      ),
    );
  }

  Future<void> _showParticipantProfile() => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        barrierColor: Colors.black.withValues(alpha: .36),
        builder: (context) => _ConversationProfileCard(
          name: widget.participantName,
          propertyTitle: widget.propertyTitle,
          imagePath: widget.participantImagePath,
          email: widget.participantEmail,
          phone: widget.participantPhone,
          whatsApp: widget.participantWhatsApp,
        ),
      );

  Widget _messageBody() {
    if (_loading) return const _MarketplaceSkeleton();
    if (_error != null) {
      return ScreenState(
          icon: Icons.cloud_off_outlined,
          title: 'Messages unavailable',
          message: _error!,
          actionLabel: 'Try again',
          onAction: () => _load(refresh: true));
    }
    if (_messages.isEmpty) {
      return const ScreenState(
          icon: Icons.waving_hand_outlined,
          title: 'Start the conversation',
          message:
              'Ask about availability, viewing times, or anything important about the home.');
    }
    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
      itemCount: _messages.length,
      itemBuilder: (_, index) => _MessageBubble(message: _messages[index]),
    );
  }
}

class _ConversationParticipantHeader extends StatelessWidget {
  final String name;
  final String propertyTitle;
  final String? imagePath;
  final VoidCallback onTap;

  const _ConversationParticipantHeader({
    required this.name,
    required this.propertyTitle,
    required this.imagePath,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: 230,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _PersonAvatar(name: name, imagePath: imagePath, radius: 15),
              const SizedBox(width: 8),
              Flexible(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall),
                    Text(propertyTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.keyboard_arrow_down_rounded,
                  size: 17,
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      );
}

class _ConversationProfileCard extends StatelessWidget {
  final String name;
  final String propertyTitle;
  final String? imagePath;
  final String? email;
  final String? phone;
  final String? whatsApp;

  const _ConversationProfileCard({
    required this.name,
    required this.propertyTitle,
    this.imagePath,
    this.email,
    this.phone,
    this.whatsApp,
  });

  Future<void> _open(BuildContext context, Uri uri) async {
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
        context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('This contact option is unavailable.')));
    }
  }

  String _whatsAppDigits(String value) {
    var digits = value.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.startsWith('0')) digits = '260${digits.substring(1)}';
    if (digits.length == 9) digits = '260$digits';
    return digits;
  }

  @override
  Widget build(BuildContext context) {
    final hasContact = phone != null || whatsApp != null || email != null;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
        child: GlassSurface(
          borderRadius: BorderRadius.circular(28),
          blur: 24,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 12, 22, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                const SizedBox(height: 20),
                _PersonAvatar(name: name, imagePath: imagePath, radius: 44),
                const SizedBox(height: 13),
                Text(name,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 4),
                Text('Conversation about $propertyTitle',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 18),
                if (phone != null)
                  _ProfileContactLine(
                      icon: Icons.phone_outlined,
                      label: 'Phone',
                      value: phone!),
                if (whatsApp != null)
                  _ProfileContactLine(
                      icon: Icons.chat_outlined,
                      label: 'WhatsApp',
                      value: whatsApp!),
                if (email != null)
                  _ProfileContactLine(
                      icon: Icons.email_outlined,
                      label: 'Email',
                      value: email!),
                if (!hasContact)
                  Text('No direct contact details shared',
                      style: Theme.of(context).textTheme.bodyMedium),
                if (hasContact) ...[
                  const SizedBox(height: 15),
                  Row(
                    children: [
                      if (phone != null)
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () =>
                                _open(context, Uri(scheme: 'tel', path: phone)),
                            icon: const Icon(Icons.call_outlined, size: 18),
                            label: const Text('Call'),
                          ),
                        ),
                      if (phone != null && whatsApp != null)
                        const SizedBox(width: 8),
                      if (whatsApp != null)
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _open(
                                context,
                                Uri.https(
                                    'wa.me', '/${_whatsAppDigits(whatsApp!)}')),
                            icon: const Icon(Icons.chat_outlined, size: 18),
                            label: const Text('WhatsApp'),
                          ),
                        ),
                    ],
                  ),
                  if (email != null) ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () =>
                            _open(context, Uri(scheme: 'mailto', path: email)),
                        icon: const Icon(Icons.email_outlined, size: 18),
                        label: const Text('Email'),
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PersonAvatar extends StatelessWidget {
  final String name;
  final String? imagePath;
  final double radius;

  const _PersonAvatar(
      {required this.name, required this.imagePath, required this.radius});

  @override
  Widget build(BuildContext context) {
    final url = ApiConfig.storageUrl(imagePath);
    final fallback = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
    return CircleAvatar(
      radius: radius,
      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      child: ClipOval(
        child: url.isEmpty
            ? Center(
                child: Text(fallback,
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w800)))
            : CachedNetworkImage(
                imageUrl: url,
                width: radius * 2,
                height: radius * 2,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => Center(
                    child: Text(fallback,
                        style: const TextStyle(fontWeight: FontWeight.w800))),
              ),
      ),
    );
  }
}

class _ProfileContactLine extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _ProfileContactLine(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12)),
              child: Icon(icon,
                  size: 19, color: Theme.of(context).colorScheme.primary),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: Theme.of(context).textTheme.labelSmall),
                  const SizedBox(height: 1),
                  Text(value, style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            ),
          ],
        ),
      );
}

class _SavedSearchSheet extends StatefulWidget {
  const _SavedSearchSheet();

  @override
  State<_SavedSearchSheet> createState() => _SavedSearchSheetState();
}

class _SavedSearchSheetState extends State<_SavedSearchSheet> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _minPrice = TextEditingController();
  final _maxPrice = TextEditingController();
  late final Future<RecommendationOptions> _options;
  int? _cityId;
  final Set<int> _areaIds = {};
  String? _type;
  int? _minBeds;
  int? _maxBeds;
  final Set<String> _amenities = {};
  bool _alertsEnabled = false;

  @override
  void initState() {
    super.initState();
    _options = RecommendationService.instance.options();
  }

  @override
  void dispose() {
    _name.dispose();
    _minPrice.dispose();
    _maxPrice.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Scaffold(
      appBar: const HavenNavigationBar(title: 'Save Search'),
      body: SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, 14, 20, 18 + bottom),
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        'Reuse these filters anytime. Home alerts are optional.',
                        style: Theme.of(context).textTheme.bodyMedium),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _name,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                          labelText: 'Search name',
                          hintText: 'e.g. Kabulonga two-bedroom'),
                      validator: (value) => (value?.trim().isEmpty ?? true)
                          ? 'Give this search a name'
                          : null,
                    ),
                    const SizedBox(height: 14),
                    FutureBuilder<RecommendationOptions>(
                      future: _options,
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const LinearProgressIndicator();
                        }
                        return _locationFields(snapshot.data!);
                      },
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      initialValue: _type,
                      decoration:
                          const InputDecoration(labelText: 'Property type'),
                      items: const [
                        'House',
                        'Apartment',
                        'Bedsitter',
                        'Flat',
                        'Townhouse',
                        'Villa',
                        'Other'
                      ]
                          .map((value) => DropdownMenuItem(
                              value: value, child: Text(value)))
                          .toList(),
                      onChanged: (value) => setState(() => _type = value),
                    ),
                    const SizedBox(height: 14),
                    Row(children: [
                      Expanded(child: _numberField(_minPrice, 'Minimum price')),
                      const SizedBox(width: 10),
                      Expanded(child: _numberField(_maxPrice, 'Maximum price')),
                    ]),
                    const SizedBox(height: 14),
                    Row(children: [
                      Expanded(
                          child: _bedroomField('Min bedrooms', _minBeds,
                              (value) => setState(() => _minBeds = value))),
                      const SizedBox(width: 10),
                      Expanded(
                          child: _bedroomField('Max bedrooms', _maxBeds,
                              (value) => setState(() => _maxBeds = value))),
                    ]),
                    const SizedBox(height: 18),
                    Text('Must-have amenities',
                        style: Theme.of(context).textTheme.labelLarge),
                    const SizedBox(height: 9),
                    FutureBuilder<RecommendationOptions>(
                      future: _options,
                      builder: (context, snapshot) => Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: (snapshot.data?.amenities ?? const [])
                            .map((amenity) => FilterChip(
                                  label: Text(amenity.name),
                                  selected: _amenities.contains(amenity.key),
                                  onSelected: (selected) => setState(() =>
                                      selected
                                          ? _amenities.add(amenity.key)
                                          : _amenities.remove(amenity.key)),
                                ))
                            .toList(),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.fromLTRB(16, 10, 10, 10),
                      decoration: BoxDecoration(
                        color:
                            Theme.of(context).colorScheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(children: [
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Home alerts for this search',
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500)),
                              SizedBox(height: 3),
                              Text(
                                  'Notify me when a newly listed home matches.',
                                  style: TextStyle(
                                      color: CupertinoColors.secondaryLabel,
                                      fontSize: 13)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        CupertinoSwitch(
                          value: _alertsEnabled,
                          activeTrackColor:
                              Theme.of(context).colorScheme.primary,
                          onChanged: (value) =>
                              setState(() => _alertsEnabled = value),
                        ),
                      ]),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                        width: double.infinity,
                        child: CupertinoButton.filled(
                            onPressed: _submit,
                            child: const Text('Save Search'))),
                  ],
                ),
              ),
            ),
          )),
    );
  }

  Widget _locationFields(RecommendationOptions options) {
    final city = options.cities.where((item) => item.id == _cityId).firstOrNull;
    return Column(children: [
      DropdownButtonFormField<int>(
        key: ValueKey('saved-search-city:$_cityId'),
        initialValue: _cityId,
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'City or town'),
        items: options.cities
            .map((item) =>
                DropdownMenuItem(value: item.id, child: Text(item.name)))
            .toList(),
        onChanged: (value) => setState(() {
          _cityId = value;
          _areaIds.clear();
        }),
      ),
      if (city != null) ...[
        const SizedBox(height: 14),
        Align(
            alignment: Alignment.centerLeft,
            child: Text('Areas (up to 10)',
                style: Theme.of(context).textTheme.labelLarge)),
        const SizedBox(height: 9),
        Align(
          alignment: Alignment.centerLeft,
          child: Wrap(
            spacing: 7,
            runSpacing: 7,
            children: city.areas
                .map((area) => FilterChip(
                      label: Text(area.name),
                      selected: _areaIds.contains(area.id),
                      onSelected: (selected) {
                        if (selected && _areaIds.length >= 10) return;
                        setState(() => selected
                            ? _areaIds.add(area.id)
                            : _areaIds.remove(area.id));
                      },
                    ))
                .toList(),
          ),
        ),
      ],
    ]);
  }

  Widget _numberField(TextEditingController controller, String label) =>
      TextFormField(
        controller: controller,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(labelText: label, prefixText: 'K '),
        validator: (value) => value!.isNotEmpty && int.tryParse(value) == null
            ? 'Use numbers only'
            : null,
      );

  Widget _bedroomField(String label, int? value, ValueChanged<int?> changed) =>
      DropdownButtonFormField<int>(
        key: ValueKey('$label:$value'),
        initialValue: value,
        decoration: InputDecoration(labelText: label),
        items: List.generate(
            11,
            (index) => DropdownMenuItem(
                value: index, child: Text(index == 10 ? '10+' : '$index'))),
        onChanged: changed,
      );

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final minPrice = int.tryParse(_minPrice.text);
    final maxPrice = int.tryParse(_maxPrice.text);
    if (minPrice != null && maxPrice != null && maxPrice < minPrice) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Maximum price must be above minimum price.')));
      return;
    }
    if (_minBeds != null && _maxBeds != null && _maxBeds! < _minBeds!) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Maximum bedrooms must be above minimum bedrooms.')));
      return;
    }
    Navigator.pop(
        context,
        _SavedSearchDraft(_name.text.trim(), _alertsEnabled, {
          if (_cityId != null) 'city_id': _cityId,
          if (_areaIds.isNotEmpty) 'area_ids': _areaIds.toList(),
          if (_type != null) 'type': _type,
          if (minPrice != null) 'min_price': minPrice,
          if (maxPrice != null) 'max_price': maxPrice,
          if (_minBeds != null) 'min_bedrooms': _minBeds,
          if (_maxBeds != null) 'max_bedrooms': _maxBeds,
          if (_amenities.isNotEmpty) 'amenities': _amenities.toList(),
        }));
  }
}

class _SavedSearchDraft {
  final String name;
  final bool alertsEnabled;
  final Map<String, dynamic> criteria;
  const _SavedSearchDraft(this.name, this.alertsEnabled, this.criteria);
}

class _ViewingList extends StatelessWidget {
  final Future<List<ViewingSummary>> future;
  final Future<void> Function() onRefresh;
  final VoidCallback onRetry;
  final Widget Function(BuildContext, ViewingSummary) itemBuilder;

  const _ViewingList({
    required this.future,
    required this.onRefresh,
    required this.onRetry,
    required this.itemBuilder,
  });

  @override
  Widget build(BuildContext context) => FutureBuilder<List<ViewingSummary>>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const _MarketplaceSkeleton();
          }
          if (snapshot.hasError && !snapshot.hasData) {
            return ScreenState(
                icon: Icons.cloud_off_outlined,
                title: 'Couldn’t load viewings',
                message: AppFeedback.messageFor(snapshot.error!,
                    fallback: 'Haven could not load your viewing requests.'),
                actionLabel: 'Try again',
                onAction: onRetry);
          }
          final items = snapshot.data ?? const <ViewingSummary>[];
          if (items.isEmpty) {
            return const ScreenState(
                icon: Icons.calendar_month_outlined,
                title: 'No viewings yet',
                message: 'Request a viewing from a property page.');
          }
          final active = items.where((item) => !item.isArchived).toList();
          final archived = items.where((item) => item.isArchived).toList();
          return RefreshIndicator(
            onRefresh: onRefresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 104),
              children: [
                ...active.expand((item) => [
                      itemBuilder(context, item),
                      const SizedBox(height: 10),
                    ]),
                if (active.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Text('No active viewing requests',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium),
                  ),
                if (archived.isNotEmpty)
                  ExpansionTile(
                    tilePadding: const EdgeInsets.symmetric(horizontal: 4),
                    childrenPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.archive_outlined),
                    title: Text('Archived (${archived.length})'),
                    subtitle: const Text('Viewings older than three days'),
                    children: archived
                        .expand((item) => [
                              itemBuilder(context, item),
                              const SizedBox(height: 10),
                            ])
                        .toList(),
                  ),
              ],
            ),
          );
        },
      );
}

class _MarketplaceList<T> extends StatelessWidget {
  final Future<List<T>> future;
  final Future<void> Function() onRefresh;
  final VoidCallback onRetry;
  final IconData emptyIcon;
  final String emptyTitle;
  final String emptyBody;
  final Widget Function(BuildContext, T) itemBuilder;
  const _MarketplaceList(
      {required this.future,
      required this.onRefresh,
      required this.onRetry,
      required this.emptyIcon,
      required this.emptyTitle,
      required this.emptyBody,
      required this.itemBuilder});

  @override
  Widget build(BuildContext context) => FutureBuilder<List<T>>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const _MarketplaceSkeleton();
          }
          if (snapshot.hasError && !snapshot.hasData) {
            return ScreenState(
                icon: Icons.cloud_off_outlined,
                title: 'Couldn’t load this yet',
                message: AppFeedback.messageFor(snapshot.error!,
                    fallback: 'Haven could not load this marketplace section.'),
                actionLabel: 'Try again',
                onAction: onRetry);
          }
          final items = snapshot.data ?? const [];
          if (items.isEmpty) {
            return ScreenState(
                icon: emptyIcon, title: emptyTitle, message: emptyBody);
          }
          return RefreshIndicator(
            onRefresh: onRefresh,
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 104),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) =>
                  itemBuilder(context, items[index]),
            ),
          );
        },
      );
}

class _NotificationList extends StatelessWidget {
  final Future<NotificationInbox> future;
  final Future<void> Function() onRefresh;
  final VoidCallback onRetry;
  final Widget Function(BuildContext, HavenNotification) itemBuilder;
  const _NotificationList(
      {required this.future,
      required this.onRefresh,
      required this.onRetry,
      required this.itemBuilder});

  @override
  Widget build(BuildContext context) => FutureBuilder<NotificationInbox>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const _MarketplaceSkeleton();
          }
          if (snapshot.hasError && !snapshot.hasData) {
            return ScreenState(
                icon: Icons.cloud_off_outlined,
                title: 'Updates unavailable',
                message: AppFeedback.messageFor(snapshot.error!,
                    fallback: 'Haven could not load your updates.'),
                actionLabel: 'Try again',
                onAction: onRetry);
          }
          final items = snapshot.data?.items ?? const [];
          if (items.isEmpty) {
            return const ScreenState(
                icon: Icons.notifications_none_rounded,
                title: 'You’re all caught up',
                message:
                    'Viewing replies, messages, and new matching homes appear here.');
          }
          return RefreshIndicator(
            onRefresh: onRefresh,
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 104),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) =>
                  itemBuilder(context, items[index]),
            ),
          );
        },
      );
}

class _HavenCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final bool emphasized;
  const _HavenCard({required this.child, this.onTap, this.emphasized = false});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return GlassSurface(
      borderRadius: BorderRadius.circular(20),
      tint: emphasized
          ? colors.primaryContainer.withValues(alpha: .42)
          : colors.surface.withValues(alpha: .88),
      borderColor: emphasized
          ? colors.primary.withValues(alpha: .28)
          : colors.outlineVariant,
      blur: 16,
      shadows: const [],
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(padding: const EdgeInsets.all(16), child: child),
        ),
      ),
    );
  }
}

class _PropertyAvatar extends StatelessWidget {
  final String? imagePath;
  final IconData icon;
  const _PropertyAvatar({this.imagePath, required this.icon});

  @override
  Widget build(BuildContext context) {
    final url = ApiConfig.storageUrl(imagePath);
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 52,
        height: 52,
        color: Theme.of(context).colorScheme.primaryContainer,
        child: url.isEmpty
            ? Icon(icon, color: Theme.of(context).colorScheme.primary)
            : CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) =>
                    Icon(icon, color: Theme.of(context).colorScheme.primary)),
      ),
    );
  }
}

class _IconDisc extends StatelessWidget {
  final IconData icon;
  const _IconDisc({required this.icon});
  @override
  Widget build(BuildContext context) => Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            shape: BoxShape.circle),
        child:
            Icon(icon, size: 21, color: Theme.of(context).colorScheme.primary),
      );
}

class _StatusPill extends StatelessWidget {
  final String status;
  const _StatusPill({required this.status});
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final positive = status == 'confirmed' || status == 'completed';
    final closed =
        status == 'declined' || status == 'cancelled' || status == 'no_show';
    final color = positive
        ? colors.primary
        : closed
            ? colors.error
            : colors.secondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
          color: color.withValues(alpha: .12),
          borderRadius: BorderRadius.circular(999)),
      child: Text(status.replaceAll('_', ' '),
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.w800)),
    );
  }
}

class _ViewingDetail extends StatelessWidget {
  final String label;
  final String value;

  const _ViewingDetail({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: RichText(
        text: TextSpan(
          style: Theme.of(context).textTheme.bodySmall,
          children: [
            TextSpan(
                text: '$label\n',
                style: const TextStyle(fontWeight: FontWeight.w800)),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }
}

class _ContactValue extends StatelessWidget {
  final IconData icon;
  final String value;

  const _ContactValue({required this.icon, required this.value});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 5),
        child: Row(
          children: [
            Icon(icon, size: 17, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            Expanded(
                child:
                    Text(value, style: Theme.of(context).textTheme.bodyMedium)),
          ],
        ),
      );
}

class _ContactActionRow extends StatelessWidget {
  final List<Widget> actions;

  const _ContactActionRow({required this.actions});

  @override
  Widget build(BuildContext context) => Row(
        children: [
          for (var index = 0; index < actions.length; index++) ...[
            if (index > 0) const SizedBox(width: 6),
            Expanded(
              child: ButtonTheme(
                alignedDropdown: true,
                child: actions[index],
              ),
            ),
          ],
        ],
      );
}

class _UnreadDot extends StatelessWidget {
  const _UnreadDot();
  @override
  Widget build(BuildContext context) => Container(
      width: 9,
      height: 9,
      decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary,
          shape: BoxShape.circle));
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  const _MessageBubble({required this.message});
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Align(
      alignment: message.isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints:
            BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * .78),
        margin: const EdgeInsets.only(bottom: 9),
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
        decoration: BoxDecoration(
          color: message.isMine
              ? colors.primaryContainer
              : colors.surfaceContainerHigh,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(message.isMine ? 18 : 5),
            bottomRight: Radius.circular(message.isMine ? 5 : 18),
          ),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(message.body,
              style: TextStyle(
                  color: message.isMine
                      ? colors.onPrimaryContainer
                      : colors.onSurface,
                  height: 1.35)),
          if (message.createdAt != null) ...[
            const SizedBox(height: 3),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                    '${message.createdAt!.hour.toString().padLeft(2, '0')}:${message.createdAt!.minute.toString().padLeft(2, '0')}',
                    style: TextStyle(
                        fontSize: 9,
                        color: (message.isMine
                                ? colors.onPrimaryContainer
                                : colors.onSurfaceVariant)
                            .withValues(alpha: .7))),
                if (message.isMine) ...[
                  const SizedBox(width: 5),
                  Icon(
                    message.readAt != null
                        ? Icons.done_all
                        : message.deliveredAt != null
                            ? Icons.done
                            : Icons.schedule,
                    size: 14,
                    semanticLabel: message.readAt != null
                        ? 'Read'
                        : message.deliveredAt != null
                            ? 'Delivered'
                            : 'Sending',
                    color: message.readAt != null
                        ? colors.primary
                        : colors.onPrimaryContainer.withValues(alpha: .68),
                  ),
                ],
              ],
            ),
          ],
        ]),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;
  const _Composer(
      {required this.controller, required this.sending, required this.onSend});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: GlassSurface(
          borderRadius: BorderRadius.circular(20),
          blur: 20,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 7, 7, 7),
            child: Row(children: [
              Expanded(
                  child: TextField(
                      controller: controller,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.newline,
                      decoration: const InputDecoration(
                          hintText: 'Write a message…',
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          filled: false))),
              const SizedBox(width: 6),
              IconButton.filled(
                  onPressed: sending ? null : onSend,
                  icon: sending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.arrow_upward_rounded)),
            ]),
          ),
        ),
      );
}

class _MarketplaceSkeleton extends StatelessWidget {
  const _MarketplaceSkeleton();
  @override
  Widget build(BuildContext context) => ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: 5,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, __) => Container(
            height: 92,
            decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(20))),
      );
}
