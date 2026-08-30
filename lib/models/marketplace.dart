class ConversationSummary {
  final int id;
  final String propertyTitle;
  final String? propertyImagePath;
  final String participantName;
  final String? participantImagePath;
  final String? participantEmail;
  final String? participantPhone;
  final String? participantWhatsApp;
  final String lastMessage;
  final int unreadCount;
  final DateTime? updatedAt;

  const ConversationSummary({
    required this.id,
    required this.propertyTitle,
    required this.participantName,
    required this.lastMessage,
    required this.unreadCount,
    this.propertyImagePath,
    this.participantImagePath,
    this.participantEmail,
    this.participantPhone,
    this.participantWhatsApp,
    this.updatedAt,
  });

  factory ConversationSummary.fromMap(Map<String, dynamic> map) {
    final house = _map(map['house']);
    final messages = map['messages'] as List? ?? const [];
    final last =
        messages.isEmpty ? const <String, dynamic>{} : _map(messages.first);
    final role = map['viewer_role'] == 'lister'
        ? ViewingRole.lister
        : ViewingRole.renter;
    final otherParty =
        role == ViewingRole.lister ? _map(map['renter']) : _map(map['lister']);
    return ConversationSummary(
      id: _integer(map['id']),
      propertyTitle: _text(house['title'], fallback: 'Property conversation'),
      propertyImagePath: _nullableText(house['image-cover']),
      participantName: _personName(otherParty) ?? 'Haven member',
      participantImagePath: _nullableText(otherParty['profile_picture']),
      participantEmail: _nullableText(otherParty['email']),
      participantPhone:
          _nullableText(otherParty['phone_number'] ?? otherParty['phone']),
      participantWhatsApp: _nullableText(
          otherParty['whatsapp_number'] ?? otherParty['whatsapp']),
      lastMessage: _text(last['body'], fallback: 'Conversation started'),
      unreadCount: _integer(map['unread_count']),
      updatedAt: _date(map['last_message_at'] ?? map['updated_at']),
    );
  }
}

enum ViewingRole { renter, lister }

class ReservationSlot {
  final int id;
  final DateTime startsAt;
  final DateTime? endsAt;
  final bool isActive;

  const ReservationSlot({
    required this.id,
    required this.startsAt,
    this.endsAt,
    required this.isActive,
  });

  factory ReservationSlot.fromMap(Map<String, dynamic> map) => ReservationSlot(
        id: _integer(map['id']),
        startsAt: _date(map['starts_at']) ?? DateTime.now(),
        endsAt: _date(map['ends_at']),
        isActive: _boolean(map['is_active'] ?? true),
      );
}

enum ReservationRole { customer, lister }

class ReservationSummary {
  final int id;
  final int houseId;
  final int reservationSlotId;
  final String propertyTitle;
  final String location;
  final String? imagePath;
  final String? otherPartyName;
  final String status;
  final ReservationRole role;
  final DateTime scheduledStart;
  final DateTime? scheduledEnd;
  final DateTime? confirmedAt;
  final DateTime? cancelledAt;
  final DateTime? expiresAt;
  final DateTime? expiredAt;
  final String? cancellationReason;

  const ReservationSummary({
    required this.id,
    required this.houseId,
    required this.reservationSlotId,
    required this.propertyTitle,
    required this.location,
    required this.status,
    required this.role,
    required this.scheduledStart,
    this.imagePath,
    this.otherPartyName,
    this.scheduledEnd,
    this.confirmedAt,
    this.cancelledAt,
    this.expiresAt,
    this.expiredAt,
    this.cancellationReason,
  });

  bool get isActive => status == 'confirmed';

  factory ReservationSummary.fromMap(Map<String, dynamic> map) {
    final house = _map(map['house']);
    final district = _text(house['district']);
    final city = _text(house['city']);
    final role = map['viewer_role'] == 'lister'
        ? ReservationRole.lister
        : ReservationRole.customer;
    final otherParty = role == ReservationRole.lister
        ? _map(map['customer'])
        : _map(map['lister']);
    return ReservationSummary(
      id: _integer(map['id']),
      houseId: _nullableInteger(house['id'] ?? map['house_id']) ??
          _integer(map['house_id']),
      reservationSlotId: _integer(map['reservation_slot_id']),
      propertyTitle: _text(house['title'], fallback: 'Rental home'),
      location: [district, city].where((part) => part.isNotEmpty).join(', '),
      imagePath: _nullableText(house['image-cover']),
      otherPartyName: _personName(otherParty),
      status: _text(map['status'], fallback: 'confirmed'),
      role: role,
      scheduledStart: _date(map['scheduled_start']) ?? DateTime.now(),
      scheduledEnd: _date(map['scheduled_end']),
      confirmedAt: _date(map['confirmed_at']),
      cancelledAt: _date(map['cancelled_at']),
      expiresAt: _date(map['expires_at']),
      expiredAt: _date(map['expired_at']),
      cancellationReason: _nullableText(map['cancellation_reason']),
    );
  }
}

class ReservationState {
  final bool isReserved;
  final bool isMine;
  final bool isInterested;
  final ReservationSummary? reservation;
  final List<ReservationSlot> slots;

  const ReservationState({
    required this.isReserved,
    required this.isMine,
    required this.isInterested,
    required this.reservation,
    required this.slots,
  });

  factory ReservationState.fromMap(Map<String, dynamic> map) {
    final rawSlots = map['slots'] as List? ?? const [];
    final rawReservation = map['reservation'];
    return ReservationState(
      isReserved: _boolean(map['is_reserved']),
      isMine: _boolean(map['is_mine']),
      isInterested: _boolean(map['is_interested']),
      reservation: rawReservation is Map
          ? ReservationSummary.fromMap(
              Map<String, dynamic>.from(rawReservation))
          : null,
      slots: rawSlots
          .whereType<Map>()
          .map((slot) =>
              ReservationSlot.fromMap(Map<String, dynamic>.from(slot)))
          .toList(),
    );
  }
}

class ViewingSummary {
  final int id;
  final int? houseId;
  final String title;
  final String location;
  final String? imagePath;
  final String? otherPartyName;
  final String? otherPartyEmail;
  final String? otherPartyPhone;
  final String? otherPartyWhatsApp;
  final String status;
  final ViewingRole role;
  final DateTime? requestedAt;
  final DateTime? respondedAt;
  final DateTime? completedAt;
  final String? note;
  final String? listerResponse;

  const ViewingSummary({
    required this.id,
    this.houseId,
    required this.title,
    required this.location,
    this.imagePath,
    this.otherPartyName,
    this.otherPartyEmail,
    this.otherPartyPhone,
    this.otherPartyWhatsApp,
    required this.status,
    required this.role,
    this.requestedAt,
    this.respondedAt,
    this.completedAt,
    this.note,
    this.listerResponse,
  });

  bool get isOpen => status == 'pending' || status == 'confirmed';

  bool get isPast =>
      requestedAt != null && requestedAt!.isBefore(DateTime.now());

  bool get isArchived =>
      requestedAt != null &&
      requestedAt!.add(const Duration(days: 3)).isBefore(DateTime.now());

  factory ViewingSummary.fromMap(Map<String, dynamic> map) {
    final house = _map(map['house']);
    final district = _text(house['district']);
    final city = _text(house['city']);
    final role = map['viewer_role'] == 'lister'
        ? ViewingRole.lister
        : ViewingRole.renter;
    final renter = _map(map['renter']);
    final lister = _map(map['lister']);
    final otherParty = role == ViewingRole.lister ? renter : lister;
    final contact = _map(otherParty['contact']);
    return ViewingSummary(
      id: _integer(map['id']),
      houseId: _nullableInteger(house['id'] ?? map['house_id']),
      title: _text(house['title'], fallback: 'Rental home'),
      location: [district, city].where((part) => part.isNotEmpty).join(', '),
      imagePath: _nullableText(house['image-cover']),
      otherPartyName: _personName(otherParty),
      otherPartyEmail: _nullableText(otherParty['email'] ?? contact['email']),
      otherPartyPhone: _nullableText(otherParty['phone_number'] ??
          otherParty['phone'] ??
          contact['phone_number'] ??
          contact['phone']),
      otherPartyWhatsApp: _nullableText(otherParty['whatsapp_number'] ??
          otherParty['whatsapp'] ??
          contact['whatsapp_number'] ??
          contact['whatsapp']),
      status: _text(map['status'], fallback: 'pending'),
      role: role,
      requestedAt: _date(map['requested_at']),
      respondedAt: _date(map['responded_at']),
      completedAt: _date(map['completed_at']),
      note: _nullableText(map['note']),
      listerResponse: _nullableText(map['lister_response']),
    );
  }
}

class HavenNotification {
  final String id;
  final String kind;
  final String title;
  final String body;
  final bool isRead;
  final DateTime? createdAt;
  final int? houseId;
  final int? conversationId;
  final int? reservationId;
  final String? viewerRole;

  const HavenNotification({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
    required this.isRead,
    this.createdAt,
    this.houseId,
    this.conversationId,
    this.reservationId,
    this.viewerRole,
  });

  factory HavenNotification.fromMap(Map<String, dynamic> map) {
    final data = _map(map['data']);
    return HavenNotification(
      id: _text(map['id']),
      kind: _text(data['kind'], fallback: 'update'),
      title: _text(data['title'], fallback: 'Haven update'),
      body: _text(data['body']),
      isRead: map['read_at'] != null,
      createdAt: _date(map['created_at']),
      houseId: _nullableInteger(data['house_id']),
      conversationId: _nullableInteger(data['conversation_id']),
      reservationId: _nullableInteger(data['reservation_id']),
      viewerRole: _nullableText(data['viewer_role']),
    );
  }
}

class NotificationInbox {
  final int unreadCount;
  final List<HavenNotification> items;
  const NotificationInbox({required this.unreadCount, required this.items});
}

class SavedSearchSummary {
  final int id;
  final String name;
  final bool alertsEnabled;
  final Map<String, dynamic> criteria;

  const SavedSearchSummary({
    required this.id,
    required this.name,
    required this.alertsEnabled,
    required this.criteria,
  });

  String get description {
    final parts = <String>[];
    final keyword = _nullableText(criteria['keyword']);
    if (keyword != null) parts.add(keyword);
    final type = _nullableText(criteria['type']);
    if (type != null) parts.add(type);
    final minBeds = _nullableInteger(criteria['min_bedrooms']);
    final maxBeds = _nullableInteger(criteria['max_bedrooms']);
    if (minBeds != null || maxBeds != null) {
      parts.add(minBeds == maxBeds
          ? '$minBeds beds'
          : '${minBeds ?? 0}–${maxBeds ?? 'any'} beds');
    }
    final min = _nullableInteger(criteria['min_price']);
    final max = _nullableInteger(criteria['max_price']);
    if (min != null || max != null) parts.add('K${min ?? 0}–${max ?? 'any'}');
    final amenities = criteria['amenities'] is List
        ? (criteria['amenities'] as List).length
        : 0;
    if (amenities > 0) parts.add('$amenities amenities');
    return parts.isEmpty ? 'Saved Explore filters' : parts.join(' · ');
  }

  factory SavedSearchSummary.fromMap(Map<String, dynamic> map) =>
      SavedSearchSummary(
        id: _integer(map['id']),
        name: _text(map['name'], fallback: 'Saved search'),
        alertsEnabled:
            map['alerts_enabled'] == true || map['alerts_enabled'] == 1,
        criteria: _map(map['criteria']),
      );
}

class ChatMessage {
  final int id;
  final String body;
  final bool isMine;
  final DateTime? createdAt;
  final DateTime? deliveredAt;
  final DateTime? readAt;

  const ChatMessage(
      {required this.id,
      required this.body,
      required this.isMine,
      this.createdAt,
      this.deliveredAt,
      this.readAt});

  factory ChatMessage.fromMap(Map<String, dynamic> map) => ChatMessage(
        id: _integer(map['id']),
        body: _text(map['body']),
        isMine: _boolean(map['is_mine'] ?? map['isMine']),
        createdAt: _date(map['created_at']),
        deliveredAt: _date(map['delivered_at']) ?? _date(map['created_at']),
        readAt: _date(map['read_at']),
      );
}

class ReviewEligibility {
  final bool eligible;
  final String? reason;
  const ReviewEligibility({required this.eligible, this.reason});
}

Map<String, dynamic> _map(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};
int _integer(dynamic value) => int.tryParse('${value ?? 0}') ?? 0;
bool _boolean(dynamic value) =>
    value == true ||
    value == 1 ||
    value == '1' ||
    '${value ?? ''}'.toLowerCase() == 'true';
int? _nullableInteger(dynamic value) =>
    value == null ? null : int.tryParse('$value');
String _text(dynamic value, {String fallback = ''}) {
  final result = '${value ?? ''}'.trim();
  return result.isEmpty ? fallback : result;
}

String? _nullableText(dynamic value) {
  final result = _text(value);
  return result.isEmpty ? null : result;
}

String? _personName(Map<String, dynamic> person) {
  final first = _text(person['first_name']);
  final last = _text(person['last_name']);
  if (first.isEmpty && last.isEmpty) {
    return _nullableText(person['name'] ?? person['company']);
  }
  if (first.isEmpty) return last;
  if (last.isEmpty || first.toLowerCase() == last.toLowerCase()) return first;
  return '$first $last';
}

DateTime? _date(dynamic value) =>
    DateTime.tryParse('${value ?? ''}')?.toLocal();
