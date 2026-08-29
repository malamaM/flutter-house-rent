class ConversationSummary {
  final int id;
  final String title;
  final String? imagePath;
  final String lastMessage;
  final int unreadCount;
  final DateTime? updatedAt;

  const ConversationSummary({
    required this.id,
    required this.title,
    required this.lastMessage,
    required this.unreadCount,
    this.imagePath,
    this.updatedAt,
  });

  factory ConversationSummary.fromMap(Map<String, dynamic> map) {
    final house = _map(map['house']);
    final messages = map['messages'] as List? ?? const [];
    final last =
        messages.isEmpty ? const <String, dynamic>{} : _map(messages.first);
    return ConversationSummary(
      id: _integer(map['id']),
      title: _text(house['title'], fallback: 'Property conversation'),
      imagePath: house['image-cover']?.toString(),
      lastMessage: _text(last['body'], fallback: 'Conversation started'),
      unreadCount: _integer(map['unread_count']),
      updatedAt: _date(map['last_message_at'] ?? map['updated_at']),
    );
  }
}

enum ViewingRole { renter, lister }

class ViewingSummary {
  final int id;
  final String title;
  final String location;
  final String status;
  final ViewingRole role;
  final DateTime? requestedAt;
  final String? note;
  final String? listerResponse;

  const ViewingSummary({
    required this.id,
    required this.title,
    required this.location,
    required this.status,
    required this.role,
    this.requestedAt,
    this.note,
    this.listerResponse,
  });

  bool get isOpen => status == 'pending' || status == 'confirmed';

  factory ViewingSummary.fromMap(Map<String, dynamic> map) {
    final house = _map(map['house']);
    final district = _text(house['district']);
    final city = _text(house['city']);
    return ViewingSummary(
      id: _integer(map['id']),
      title: _text(house['title'], fallback: 'Rental home'),
      location: [district, city].where((part) => part.isNotEmpty).join(', '),
      status: _text(map['status'], fallback: 'pending'),
      role: map['viewer_role'] == 'lister'
          ? ViewingRole.lister
          : ViewingRole.renter,
      requestedAt: _date(map['requested_at']),
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

  const HavenNotification({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
    required this.isRead,
    this.createdAt,
    this.houseId,
    this.conversationId,
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

  const ChatMessage(
      {required this.id,
      required this.body,
      required this.isMine,
      this.createdAt});

  factory ChatMessage.fromMap(Map<String, dynamic> map) => ChatMessage(
        id: _integer(map['id']),
        body: _text(map['body']),
        isMine: map['is_mine'] == true || map['is_mine'] == 1,
        createdAt: _date(map['created_at']),
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

DateTime? _date(dynamic value) =>
    DateTime.tryParse('${value ?? ''}')?.toLocal();
