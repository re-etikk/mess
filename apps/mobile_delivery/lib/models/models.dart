class DeliveryOrderModel {
  final String id;
  final String bookingId;
  final String pickupAddress;
  final String deliveryAddress;
  final String customerName;
  final String customerPhone;
  final double distanceKm;
  final double payoutInr;
  String status; // 'pending_assignment', 'accepted', 'picked_up', 'delivered'
  final String deliveryOtp;
  int failedOtpAttempts;

  DeliveryOrderModel({
    required this.id,
    required this.bookingId,
    required this.pickupAddress,
    required this.deliveryAddress,
    required this.customerName,
    required this.customerPhone,
    required this.distanceKm,
    required this.payoutInr,
    required this.status,
    required this.deliveryOtp,
    this.failedOtpAttempts = 0,
  });
}

class RiderProfileModel {
  final String id;
  final String name;
  final String vehicleNumber;
  final String phone;
  bool isOnline;
  int todayDeliveries;
  double todayEarningsInr;

  RiderProfileModel({
    required this.id,
    required this.name,
    required this.vehicleNumber,
    required this.phone,
    required this.isOnline,
    required this.todayDeliveries,
    required this.todayEarningsInr,
  });
}
