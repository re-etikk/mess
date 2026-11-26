class ProviderSession {
  const ProviderSession({
    required this.token,
    this.refreshToken = '',
    required this.userId,
    required this.email,
    required this.providerId,
    required this.businessName,
    this.locality = '',
    this.city = '',
  });

  final String token;
  final String refreshToken;
  final String userId;
  final String email;
  final String providerId;
  final String businessName;
  final String locality;
  final String city;

  Map<String, dynamic> toJson() => {
        'token': token,
        'refreshToken': refreshToken,
        'userId': userId,
        'email': email,
        'providerId': providerId,
        'businessName': businessName,
        'locality': locality,
        'city': city,
      };

  factory ProviderSession.fromJson(Map<String, dynamic> json) => ProviderSession(
        token: json['token'] as String? ?? '',
        refreshToken: json['refreshToken'] as String? ?? '',
        userId: json['userId'] as String? ?? '',
        email: json['email'] as String? ?? '',
        providerId: json['providerId'] as String? ?? '',
        businessName: json['businessName'] as String? ?? '',
        locality: json['locality'] as String? ?? '',
        city: json['city'] as String? ?? '',
      );
}

class DashboardMetrics {
  const DashboardMetrics({
    required this.todayScans,
    required this.totalScans,
    required this.unbilledScans,
    required this.activeSubscribers,
    required this.activePlans,
    required this.currentSlot,
    required this.todayDate,
    required this.recentRedemptions,
    this.pendingCashCount = 0,
    this.pendingCashInr = 0,
    this.onlineSettledInr = 0,
    this.averageRating,
    this.reviewsCount = 0,
    this.locality = '',
    this.city = '',
  });

  final int todayScans;
  final int totalScans;
  final int unbilledScans;
  final int activeSubscribers;
  final int activePlans;
  final String currentSlot;
  final String todayDate;
  final List<Map<String, dynamic>> recentRedemptions;
  final int pendingCashCount;
  final int pendingCashInr;
  final int onlineSettledInr;
  final double? averageRating;
  final int reviewsCount;
  final String locality;
  final String city;
}

class KitchenQueueItem {
  const KitchenQueueItem({
    required this.subscriptionId,
    required this.customerId,
    required this.customerName,
    required this.customerPhone,
    required this.planName,
    required this.slot,
    required this.serviceDate,
    required this.status,
    required this.timeWindow,
    required this.instructions,
    required this.packagingPreference,
    required this.addons,
    this.fulfillmentMode = 'pickup',
    this.deliveryAddress = '',
    this.riderId = '',
    this.riderName = '',
    this.riderPhone = '',
    this.etaMinutes,
    this.riderLat,
    this.riderLng,
  });

  final String subscriptionId;
  final String customerId;
  final String customerName;
  final String customerPhone;
  final String planName;
  final String slot;
  final String serviceDate;
  final String status;
  final String timeWindow;
  final String instructions;
  final String packagingPreference;
  final List<dynamic> addons;
  final String fulfillmentMode;
  final String deliveryAddress;
  final String riderId;
  final String riderName;
  final String riderPhone;
  final int? etaMinutes;
  final double? riderLat;
  final double? riderLng;

  factory KitchenQueueItem.fromJson(Map<String, dynamic> j) => KitchenQueueItem(
        subscriptionId: j['subscription_id']?.toString() ?? '',
        customerId: j['customer_id']?.toString() ?? '',
        customerName: j['customer_name']?.toString() ?? 'Subscriber',
        customerPhone: j['customer_phone']?.toString() ?? '',
        planName: j['plan_name']?.toString() ?? 'Plan',
        slot: j['slot']?.toString() ?? 'LUNCH',
        serviceDate: j['service_date']?.toString() ?? '',
        status: j['status']?.toString() ?? 'scheduled',
        timeWindow: j['time_window']?.toString() ?? '',
        instructions: j['instructions']?.toString() ?? '',
        packagingPreference: j['packaging_preference']?.toString() ?? 'reusable_tiffin',
        addons: (j['addons'] as List<dynamic>?) ?? const [],
        fulfillmentMode: j['fulfillment_mode']?.toString() ?? 'pickup',
        deliveryAddress: j['delivery_address']?.toString() ?? '',
        riderId: j['rider_id']?.toString() ?? '',
        riderName: j['rider_name']?.toString() ?? '',
        riderPhone: j['rider_phone']?.toString() ?? '',
        etaMinutes: (j['eta_minutes'] as num?)?.toInt(),
        riderLat: (j['rider_lat'] as num?)?.toDouble(),
        riderLng: (j['rider_lng'] as num?)?.toDouble(),
      );
}

class KitchenQueueResponse {
  const KitchenQueueResponse({
    required this.date,
    required this.slot,
    required this.total,
    required this.scheduled,
    required this.preparing,
    required this.outCount,
    required this.delivered,
    required this.skipped,
    required this.items,
    this.supportsDelivery = false,
  });

  final String date;
  final String slot;
  final int total;
  final int scheduled;
  final int preparing;
  final int outCount;
  final int delivered;
  final int skipped;
  final List<KitchenQueueItem> items;
  final bool supportsDelivery;

  factory KitchenQueueResponse.fromJson(Map<String, dynamic> j) {
    final counts = (j['counts'] as Map<String, dynamic>?) ?? const {};
    final list = (j['queue'] as List<dynamic>?) ?? const [];
    return KitchenQueueResponse(
      date: j['date']?.toString() ?? '',
      slot: j['slot']?.toString() ?? 'LUNCH',
      total: (counts['total'] as num?)?.toInt() ?? list.length,
      scheduled: (counts['scheduled'] as num?)?.toInt() ?? 0,
      preparing: (counts['preparing'] as num?)?.toInt() ?? 0,
      outCount: (counts['out'] as num?)?.toInt() ?? 0,
      delivered: (counts['delivered'] as num?)?.toInt() ?? 0,
      skipped: (counts['skipped'] as num?)?.toInt() ?? 0,
      supportsDelivery: j['supports_delivery'] == true,
      items: list.map((e) => KitchenQueueItem.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
    );
  }
}

class SubscriberRecord {
  const SubscriberRecord({
    required this.id,
    required this.name,
    required this.phone,
    required this.planName,
    required this.status,
    required this.mealsRemaining,
  });

  final String id;
  final String name;
  final String phone;
  final String planName;
  final String status;
  final int? mealsRemaining;
}
