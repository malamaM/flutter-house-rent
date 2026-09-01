import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:house_rent/config/api_config.dart';
import 'package:house_rent/models/house.dart';
import 'package:house_rent/models/marketplace.dart';
import 'package:house_rent/models/property_management.dart';
import 'package:house_rent/navigation/haven_page_route.dart';
import 'package:house_rent/screens/my_listings/edit_listing.dart';
import 'package:house_rent/screens/my_listings/listing_preview_screen.dart';
import 'package:house_rent/screens/my_listings/paid_reservation_sheet.dart';
import 'package:house_rent/screens/profile/marketplace_hub_screen.dart';
import 'package:house_rent/services/app_feedback.dart';
import 'package:house_rent/services/marketplace_service.dart';
import 'package:house_rent/theme/app_colors.dart';
import 'package:house_rent/widgets/glass_surface.dart';
import 'package:house_rent/widgets/haven_navigation_bar.dart';
import 'package:house_rent/widgets/screen_state.dart';

class ListingManagementScreen extends StatefulWidget {
  final House house;

  const ListingManagementScreen({super.key, required this.house});

  @override
  State<ListingManagementScreen> createState() =>
      _ListingManagementScreenState();
}

class _ListingManagementScreenState extends State<ListingManagementScreen> {
  late Future<PropertyManagementData> _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load({bool refresh = false}) {
    _future = MarketplaceService.instance
        .propertyManagement(widget.house.id, refresh: refresh);
  }

  Future<void> _edit(PropertyManagementData data) async {
    final changed = await Navigator.push<bool>(
      context,
      HavenPageRoute(builder: (_) => EditListingScreen(house: data.house)),
    );
    if (changed == true && mounted) setState(() => _load(refresh: true));
  }

  Future<void> _preview(PropertyManagementData data) async {
    await Navigator.push<void>(
      context,
      HavenPageRoute(builder: (_) => ListingPreviewScreen(house: data.house)),
    );
  }

  Future<void> _reservations(PropertyManagementData data) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => PaidReservationSheet(
        houseId: data.house.id,
        houseName: data.house.name,
        monthlyRent: data.house.priceRental,
      ),
    );
    if (mounted) setState(() => _load(refresh: true));
  }

  void _openHub(int tab) {
    Navigator.push(
      context,
      HavenPageRoute(builder: (_) => MarketplaceHubScreen(initialTab: tab)),
    );
  }

  Future<void> _markNotificationRead(HavenNotification notification) async {
    if (notification.isRead) return;
    try {
      await MarketplaceService.instance.markNotificationRead(notification.id);
      if (mounted) setState(() => _load(refresh: true));
    } catch (_) {
      // A notification is still useful if a background read request fails.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: HavenNavigationBar(
        title: 'Manage listing',
        trailing: IconButton(
          tooltip: 'Refresh listing data',
          onPressed: () => setState(() => _load(refresh: true)),
          icon: const Icon(Icons.refresh_rounded),
        ),
      ),
      body: FutureBuilder<PropertyManagementData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const _ManagementSkeleton();
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return ScreenState(
              icon: Icons.insights_outlined,
              title: 'Could not load listing management',
              message: snapshot.hasError
                  ? AppFeedback.messageFor(snapshot.error!,
                      fallback: 'Haven could not load this listing’s activity.')
                  : 'Haven could not load this listing’s activity.',
              actionLabel: 'Try again',
              onAction: () => setState(() => _load(refresh: true)),
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              setState(() => _load(refresh: true));
              await _future;
            },
            child: _ManagementBody(
              data: snapshot.data!,
              onPreview: () => _preview(snapshot.data!),
              onEdit: () => _edit(snapshot.data!),
              onReservations: () => _reservations(snapshot.data!),
              onOpenViewings: () => _openHub(1),
              onOpenMessages: () => _openHub(0),
              onOpenReservations: () => _openHub(4),
              onNotificationTap: _markNotificationRead,
            ),
          );
        },
      ),
    );
  }
}

class _ManagementBody extends StatelessWidget {
  final PropertyManagementData data;
  final VoidCallback onPreview;
  final VoidCallback onEdit;
  final VoidCallback onReservations;
  final VoidCallback onOpenViewings;
  final VoidCallback onOpenMessages;
  final VoidCallback onOpenReservations;
  final ValueChanged<HavenNotification> onNotificationTap;

  const _ManagementBody({
    required this.data,
    required this.onPreview,
    required this.onEdit,
    required this.onReservations,
    required this.onOpenViewings,
    required this.onOpenMessages,
    required this.onOpenReservations,
    required this.onNotificationTap,
  });

  @override
  Widget build(BuildContext context) {
    final stats = data.stats;
    final colors = Theme.of(context).colorScheme;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 42),
      children: [
        _ManagementHero(house: data.house, stats: stats),
        const SizedBox(height: 14),
        _ActionGrid(
          onPreview: onPreview,
          onEdit: onEdit,
          onReservations: onReservations,
          onOpenViewings: onOpenViewings,
        ),
        const SizedBox(height: 26),
        const _SectionHeading(
          title: 'Listing performance',
          subtitle: 'A clear view of how renters are responding.',
          icon: Icons.insights_rounded,
        ),
        const SizedBox(height: 12),
        _StatsGrid(stats: stats),
        const SizedBox(height: 14),
        _ViewTrendCard(points: data.viewTrend),
        const SizedBox(height: 28),
        const _SectionHeading(
          title: 'Property activity',
          subtitle: 'Everything here belongs to this listing.',
          icon: Icons.bolt_rounded,
        ),
        const SizedBox(height: 12),
        _ActivitySummaryCard(
          icon: Icons.notifications_none_rounded,
          title: 'Notifications',
          subtitle: data.notifications.isEmpty
              ? 'No property updates yet'
              : '${data.notifications.length} recent update${data.notifications.length == 1 ? '' : 's'}',
          count: stats.unreadNotifications,
          accent: colors.primary,
          child: data.notifications.isEmpty
              ? const _ActivityEmpty(
                  message: 'Updates related to this home will appear here.')
              : Column(
                  children: data.notifications
                      .take(5)
                      .map((notification) => _NotificationRow(
                            notification: notification,
                            onTap: () => onNotificationTap(notification),
                          ))
                      .toList(),
                ),
        ),
        const SizedBox(height: 10),
        _ActivitySummaryCard(
          icon: Icons.calendar_month_rounded,
          title: 'Viewing requests',
          subtitle: stats.pendingViewings == 0
              ? '${data.viewings.length} recent request${data.viewings.length == 1 ? '' : 's'}'
              : '${stats.pendingViewings} waiting for your response',
          count: stats.pendingViewings,
          accent: colors.tertiary,
          onOpen: onOpenViewings,
          child: data.viewings.isEmpty
              ? const _ActivityEmpty(
                  message: 'Viewing requests for this home will appear here.')
              : Column(
                  children: data.viewings
                      .take(4)
                      .map((viewing) => _ViewingRow(viewing: viewing))
                      .toList(),
                ),
        ),
        const SizedBox(height: 10),
        _ActivitySummaryCard(
          icon: Icons.forum_outlined,
          title: 'Messages about this home',
          subtitle: stats.unreadMessages == 0
              ? '${data.conversations.length} conversation${data.conversations.length == 1 ? '' : 's'}'
              : '${stats.unreadMessages} unread message${stats.unreadMessages == 1 ? '' : 's'}',
          count: stats.unreadMessages,
          accent: colors.primary,
          onOpen: onOpenMessages,
          child: data.conversations.isEmpty
              ? const _ActivityEmpty(
                  message: 'Chats started from this listing will appear here.')
              : Column(
                  children: data.conversations
                      .take(4)
                      .map((conversation) =>
                          _ConversationRow(conversation: conversation))
                      .toList(),
                ),
        ),
        const SizedBox(height: 10),
        _ActivitySummaryCard(
          icon: Icons.account_balance_wallet_outlined,
          title: 'Paid reservations',
          subtitle: stats.activeReservations == 0
              ? '${data.reservations.length} reservation${data.reservations.length == 1 ? '' : 's'} in history'
              : '${stats.activeReservations} active reservation${stats.activeReservations == 1 ? '' : 's'}',
          count: stats.activeReservations,
          accent: colors.secondary,
          onOpen: onOpenReservations,
          child: data.reservations.isEmpty
              ? const _ActivityEmpty(
                  message:
                      'Paid reservation activity for this home will appear here.')
              : Column(
                  children: data.reservations
                      .take(4)
                      .map((reservation) =>
                          _ReservationRow(reservation: reservation))
                      .toList(),
                ),
        ),
        const SizedBox(height: 24),
        const _InfoBanner(
          icon: Icons.lock_outline_rounded,
          title: 'Private listing workspace',
          message:
              'Only you can see these stats and property activity. Customer-facing listing content remains unchanged.',
        ),
      ],
    );
  }
}

class _ManagementHero extends StatelessWidget {
  final House house;
  final PropertyManagementStats stats;

  const _ManagementHero({required this.house, required this.stats});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final status = house.isArchived ? 'Archived' : 'Live on Haven';
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: Stack(
        children: [
          SizedBox(
            height: 250,
            width: double.infinity,
            child: CachedNetworkImage(
              imageUrl: ApiConfig.optimizedImageUrl(
                house.imageUrl,
                width: 1100,
                height: 700,
                quality: 84,
              ),
              fit: BoxFit.cover,
              errorWidget: (_, __, ___) => ColoredBox(
                color: colors.primaryContainer,
                child: Icon(Icons.home_work_outlined,
                    size: 54, color: colors.onPrimaryContainer),
              ),
            ),
          ),
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Color(0xDD071E1A)],
                ),
              ),
            ),
          ),
          Positioned(
            top: 16,
            left: 16,
            child: _StatusChip(
              label: status,
              icon: house.isArchived
                  ? Icons.inventory_2_outlined
                  : Icons.check_circle_outline_rounded,
            ),
          ),
          Positioned(
            left: 20,
            right: 20,
            bottom: 18,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  house.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 25,
                    height: 1.08,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined,
                        color: Colors.white70, size: 16),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        [house.address, house.district]
                            .whereType<String>()
                            .where((item) => item.trim().isNotEmpty)
                            .join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ),
                    if (stats.qualityScore > 0) ...[
                      const SizedBox(width: 8),
                      Text('${stats.qualityScore}% quality',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700)),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionGrid extends StatelessWidget {
  final VoidCallback onPreview;
  final VoidCallback onEdit;
  final VoidCallback onReservations;
  final VoidCallback onOpenViewings;

  const _ActionGrid({
    required this.onPreview,
    required this.onEdit,
    required this.onReservations,
    required this.onOpenViewings,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - 10) / 2;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _ActionTile(
              width: width,
              icon: Icons.visibility_outlined,
              title: 'Preview listing',
              subtitle: 'See the renter view',
              onTap: onPreview,
            ),
            _ActionTile(
              width: width,
              icon: Icons.edit_outlined,
              title: 'Edit listing',
              subtitle: 'Update details & media',
              onTap: onEdit,
            ),
            _ActionTile(
              width: width,
              icon: Icons.event_available_outlined,
              title: 'Paid reservations',
              subtitle: 'Dates, rules & amount',
              onTap: onReservations,
            ),
            _ActionTile(
              width: width,
              icon: Icons.calendar_month_outlined,
              title: 'Viewings',
              subtitle: 'Review requests',
              onTap: onOpenViewings,
            ),
          ],
        );
      },
    );
  }
}

class _ActionTile extends StatelessWidget {
  final double width;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionTile({
    required this.width,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SizedBox(
      width: width,
      child: Material(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Icon(icon, color: colors.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 3),
                      Text(subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded,
                    size: 19, color: colors.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  final PropertyManagementStats stats;

  const _StatsGrid({required this.stats});

  @override
  Widget build(BuildContext context) {
    final entries = [
      (
        Icons.visibility_outlined,
        'Total views',
        '${stats.totalViews}',
        'all time'
      ),
      (
        Icons.trending_up_rounded,
        'Last 7 days',
        '${stats.views7d}',
        'listing views'
      ),
      (
        Icons.date_range_outlined,
        'Last 30 days',
        '${stats.views30d}',
        'listing views'
      ),
      (
        Icons.bookmark_border_rounded,
        'Saved homes',
        '${stats.saves}',
        '${stats.saveRate.toStringAsFixed(1)}% of views'
      ),
      (
        Icons.forum_outlined,
        'Conversations',
        '${stats.conversations}',
        '${stats.unreadMessages} unread'
      ),
      (
        Icons.calendar_month_outlined,
        'Viewing requests',
        '${stats.viewingRequests}',
        '${stats.viewingRate.toStringAsFixed(1)}% of views'
      ),
      (
        Icons.account_balance_wallet_outlined,
        'Reservations',
        '${stats.reservations}',
        '${stats.reservationRate.toStringAsFixed(1)}% of views'
      ),
      (
        Icons.payments_outlined,
        'Reserved value',
        'K${_number(stats.paidReservationAmount)}',
        'paid reservation deposits'
      ),
      (
        Icons.check_circle_outline_rounded,
        'Completed viewings',
        '${stats.completedViewings}',
        '${stats.confirmedViewings} currently confirmed'
      ),
      (
        Icons.speed_rounded,
        'Reply rate',
        '${stats.responseRate.round()}%',
        'your lister response rate'
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - 10) / 2;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: entries
              .map((entry) => _MetricTile(
                    width: width,
                    icon: entry.$1,
                    label: entry.$2,
                    value: entry.$3,
                    detail: entry.$4,
                  ))
              .toList(),
        );
      },
    );
  }
}

class _MetricTile extends StatelessWidget {
  final double width;
  final IconData icon;
  final String label;
  final String value;
  final String detail;

  const _MetricTile({
    required this.width,
    required this.icon,
    required this.label,
    required this.value,
    required this.detail,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: width,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: colors.primary, size: 20),
          const SizedBox(height: 12),
          Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style:
                  const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 3),
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 3),
          Text(detail,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _ViewTrendCard extends StatelessWidget {
  final List<PropertyViewPoint> points;

  const _ViewTrendCard({required this.points});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final total = points.fold<int>(0, (sum, item) => sum + item.views);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 13),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('Views over the last 14 days',
                    style: TextStyle(fontWeight: FontWeight.w800)),
              ),
              Text('$total views',
                  style: TextStyle(
                      color: colors.primary, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 92,
            child: points.isEmpty
                ? Center(
                    child: Text('No view trend yet',
                        style: Theme.of(context).textTheme.bodySmall))
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: points.map((point) {
                      final max = points.fold<int>(
                          1,
                          (value, item) =>
                              value > item.views ? value : item.views);
                      final height = point.views == 0
                          ? 4.0
                          : 12 + (point.views / max) * 60;
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: Tooltip(
                            message:
                                '${_shortDate(point.date)} · ${point.views} views',
                            child: Align(
                              alignment: Alignment.bottomCenter,
                              child: Container(
                                height: height,
                                decoration: BoxDecoration(
                                  color: colors.primary.withValues(
                                      alpha: point.views == 0 ? .16 : .78),
                                  borderRadius: BorderRadius.circular(5),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
          ),
          const SizedBox(height: 7),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (points.isNotEmpty) Text(_shortDate(points.first.date)),
              if (points.length > 1) Text(_shortDate(points.last.date)),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActivitySummaryCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final int count;
  final Color accent;
  final Widget child;
  final VoidCallback? onOpen;

  const _ActivitySummaryCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.count,
    required this.accent,
    required this.child,
    this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                    color: accent.withValues(alpha: .12),
                    shape: BoxShape.circle),
                child: Icon(icon, color: accent, size: 21),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 3),
                      Text(subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall),
                    ]),
              ),
              if (count > 0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                      color: accent.withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(99)),
                  child: Text('$count',
                      style: TextStyle(
                          color: accent, fontWeight: FontWeight.w800)),
                ),
              if (onOpen != null)
                IconButton(
                    onPressed: onOpen,
                    tooltip: 'Open ${title.toLowerCase()}',
                    icon: Icon(Icons.chevron_right_rounded,
                        color: colors.onSurfaceVariant)),
            ],
          ),
          const SizedBox(height: 11),
          child,
        ],
      ),
    );
  }
}

class _NotificationRow extends StatelessWidget {
  final HavenNotification notification;
  final VoidCallback onTap;

  const _NotificationRow({required this.notification, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.only(top: 6, right: 9),
              decoration: BoxDecoration(
                color: notification.isRead
                    ? colors.outlineVariant
                    : colors.primary,
                shape: BoxShape.circle,
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(notification.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(notification.body,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            if (notification.createdAt != null)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Text(_relativeDate(notification.createdAt!),
                    style: Theme.of(context).textTheme.labelSmall),
              ),
          ],
        ),
      ),
    );
  }
}

class _ViewingRow extends StatelessWidget {
  final ViewingSummary viewing;

  const _ViewingRow({required this.viewing});

  @override
  Widget build(BuildContext context) {
    return _CompactActivityRow(
      icon: Icons.calendar_today_outlined,
      title: viewing.otherPartyName ?? 'Haven member',
      detail:
          '${_statusLabel(viewing.status)} · ${_relativeDate(viewing.requestedAt)}',
      badge: viewing.status,
    );
  }
}

class _ConversationRow extends StatelessWidget {
  final ConversationSummary conversation;

  const _ConversationRow({required this.conversation});

  @override
  Widget build(BuildContext context) {
    return _CompactActivityRow(
      icon: Icons.chat_bubble_outline_rounded,
      title: conversation.participantName,
      detail: conversation.lastMessage,
      badge: conversation.unreadCount > 0
          ? '${conversation.unreadCount} new'
          : null,
    );
  }
}

class _ReservationRow extends StatelessWidget {
  final ReservationSummary reservation;

  const _ReservationRow({required this.reservation});

  @override
  Widget build(BuildContext context) {
    return _CompactActivityRow(
      icon: Icons.account_balance_wallet_outlined,
      title: reservation.otherPartyName ?? 'Haven customer',
      detail:
          '${_statusLabel(reservation.effectiveStatus)} · ${_shortDate(reservation.scheduledStart)}',
      badge: reservation.reservationAmount == null
          ? null
          : 'K${_number(reservation.reservationAmount!)}',
    );
  }
}

class _CompactActivityRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String detail;
  final String? badge;

  const _CompactActivityRow({
    required this.icon,
    required this.title,
    required this.detail,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Icon(icon, size: 19, color: colors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(detail,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          if (badge != null)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Text(badge!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: colors.primary, fontWeight: FontWeight.w800)),
            ),
        ],
      ),
    );
  }
}

class _ActivityEmpty extends StatelessWidget {
  final String message;

  const _ActivityEmpty({required this.message});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(message, style: Theme.of(context).textTheme.bodySmall),
        ),
      );
}

class _SectionHeading extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;

  const _SectionHeading(
      {required this.title, required this.subtitle, required this.icon});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: colors.primary, size: 23),
        const SizedBox(width: 9),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 3),
            Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
          ]),
        ),
      ],
    );
  }
}

class _InfoBanner extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _InfoBanner(
      {required this.icon, required this.title, required this.message});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return GlassSurface(
      borderRadius: BorderRadius.circular(18),
      tint: colors.primaryContainer.withValues(alpha: .45),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: colors.primary),
          const SizedBox(width: 10),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(message, style: Theme.of(context).textTheme.bodySmall),
            ]),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final IconData icon;

  const _StatusChip({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .92),
          borderRadius: BorderRadius.circular(99),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 15, color: AppColors.primary),
          const SizedBox(width: 5),
          Text(label,
              style: const TextStyle(
                  color: AppColors.primary, fontWeight: FontWeight.w800)),
        ]),
      );
}

class _ManagementSkeleton extends StatelessWidget {
  const _ManagementSkeleton();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    Widget block(double height, {double? width}) => Container(
          height: height,
          width: width,
          decoration: BoxDecoration(
              color: colors.surfaceContainer,
              borderRadius: BorderRadius.circular(20)),
        );
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        block(250),
        const SizedBox(height: 14),
        block(100),
        const SizedBox(height: 26),
        block(170),
        const SizedBox(height: 14),
        block(120),
        const SizedBox(height: 10),
        block(120),
      ],
    );
  }
}

String _number(int value) => value.toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => ',',
    );

String _shortDate(DateTime value) => '${value.day}/${value.month}';

String _relativeDate(DateTime? value) {
  if (value == null) return 'recently';
  final difference = DateTime.now().difference(value);
  if (difference.isNegative || difference.inMinutes < 1) return 'now';
  if (difference.inHours < 1) return '${difference.inMinutes}m';
  if (difference.inDays < 1) return '${difference.inHours}h';
  if (difference.inDays < 7) return '${difference.inDays}d';
  return _shortDate(value);
}

String _statusLabel(String value) => value.replaceAll('_', ' ');
