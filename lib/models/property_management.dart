import 'package:house_rent/models/house.dart';
import 'package:house_rent/models/marketplace.dart';

class PropertyManagementStats {
  final int totalViews;
  final int views7d;
  final int views30d;
  final int saves;
  final int conversations;
  final int unreadMessages;
  final int viewingRequests;
  final int pendingViewings;
  final int confirmedViewings;
  final int completedViewings;
  final int reservations;
  final int activeReservations;
  final int unreadNotifications;
  final int qualityScore;
  final int daysUntilExpiry;
  final int paidReservationAmount;
  final double responseRate;
  final double saveRate;
  final double viewingRate;
  final double reservationRate;

  const PropertyManagementStats({
    required this.totalViews,
    required this.views7d,
    required this.views30d,
    required this.saves,
    required this.conversations,
    required this.unreadMessages,
    required this.viewingRequests,
    required this.pendingViewings,
    required this.confirmedViewings,
    required this.completedViewings,
    required this.reservations,
    required this.activeReservations,
    required this.unreadNotifications,
    required this.qualityScore,
    required this.daysUntilExpiry,
    required this.paidReservationAmount,
    required this.responseRate,
    required this.saveRate,
    required this.viewingRate,
    required this.reservationRate,
  });

  factory PropertyManagementStats.fromMap(Map<String, dynamic> map) {
    int integer(String key) => _intValue(map[key]);
    double decimal(String key) => _doubleValue(map[key]);
    return PropertyManagementStats(
      totalViews: integer('total_views'),
      views7d: integer('views_7d'),
      views30d: integer('views_30d'),
      saves: integer('saves'),
      conversations: integer('conversations'),
      unreadMessages: integer('unread_messages'),
      viewingRequests: integer('viewing_requests'),
      pendingViewings: integer('pending_viewings'),
      confirmedViewings: integer('confirmed_viewings'),
      completedViewings: integer('completed_viewings'),
      reservations: integer('reservations'),
      activeReservations: integer('active_reservations'),
      unreadNotifications: integer('unread_notifications'),
      qualityScore: integer('quality_score'),
      daysUntilExpiry: integer('days_until_expiry'),
      paidReservationAmount: integer('paid_reservation_amount'),
      responseRate: decimal('response_rate'),
      saveRate: decimal('save_rate'),
      viewingRate: decimal('viewing_rate'),
      reservationRate: decimal('reservation_rate'),
    );
  }
}

class PropertyViewPoint {
  final DateTime date;
  final int views;

  const PropertyViewPoint({required this.date, required this.views});

  factory PropertyViewPoint.fromMap(Map<String, dynamic> map) =>
      PropertyViewPoint(
        date: DateTime.tryParse('${map['date']}') ?? DateTime.now(),
        views: _intValue(map['views']),
      );
}

class PropertyManagementData {
  final House house;
  final PropertyManagementStats stats;
  final List<PropertyViewPoint> viewTrend;
  final List<HavenNotification> notifications;
  final List<ViewingSummary> viewings;
  final List<ConversationSummary> conversations;
  final List<ReservationSummary> reservations;

  const PropertyManagementData({
    required this.house,
    required this.stats,
    required this.viewTrend,
    required this.notifications,
    required this.viewings,
    required this.conversations,
    required this.reservations,
  });

  factory PropertyManagementData.fromMap(Map<String, dynamic> map) {
    List<Map<String, dynamic>> maps(String key) {
      final raw = map[key];
      return raw is List
          ? raw.whereType<Map>().map(Map<String, dynamic>.from).toList()
          : const [];
    }

    return PropertyManagementData(
      house: House.fromMap(_mapValue(map['house'])),
      stats: PropertyManagementStats.fromMap(_mapValue(map['stats'])),
      viewTrend: maps('view_trend').map(PropertyViewPoint.fromMap).toList(),
      notifications:
          maps('notifications').map(HavenNotification.fromMap).toList(),
      viewings: maps('viewings').map(ViewingSummary.fromMap).toList(),
      conversations:
          maps('conversations').map(ConversationSummary.fromMap).toList(),
      reservations:
          maps('reservations').map(ReservationSummary.fromMap).toList(),
    );
  }
}

Map<String, dynamic> _mapValue(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : const <String, dynamic>{};

int _intValue(dynamic value) =>
    value is num ? value.toInt() : int.tryParse('$value') ?? 0;

double _doubleValue(dynamic value) =>
    value is num ? value.toDouble() : double.tryParse('$value') ?? 0;
