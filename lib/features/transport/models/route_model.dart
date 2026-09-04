/// Route Model
///
/// Represents a transport route with stops and schedule.
class RouteModel {
  final int? id;
  final String routeName;
  final int? vehicleId;
  final String? startPoint;
  final String? endPoint;
  final String? stops; // JSON array of stop names
  final String? departureTime;
  final String? arrivalTime;
  final double fare;
  final bool isActive;
  final String createdAt;
  final String? updatedAt;

  // Joined fields
  final String? vehicleNumber;
  final int? vehicleCapacity;

  RouteModel({
    this.id,
    required this.routeName,
    this.vehicleId,
    this.startPoint,
    this.endPoint,
    this.stops,
    this.departureTime,
    this.arrivalTime,
    this.fare = 0,
    this.isActive = true,
    required this.createdAt,
    this.updatedAt,
    this.vehicleNumber,
    this.vehicleCapacity,
  });

  /// Parse stops from JSON string
  List<String> get stopList {
    if (stops == null || stops!.isEmpty) return [];
    try {
      final decoded = List<String>.from(
        (stops as dynamic) is String
            ? (stops as String).split(',').map((s) => s.trim())
            : [],
      );
      return decoded;
    } catch (_) {
      return stops!.split(',').map((s) => s.trim()).toList();
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'routeName': routeName,
      'vehicleId': vehicleId,
      'startPoint': startPoint,
      'endPoint': endPoint,
      'stops': stops,
      'departureTime': departureTime,
      'arrivalTime': arrivalTime,
      'fare': fare,
      'isActive': isActive ? 1 : 0,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  factory RouteModel.fromMap(Map<String, dynamic> map) {
    return RouteModel(
      id: map['id'] as int?,
      routeName: map['routeName'] as String,
      vehicleId: map['vehicleId'] as int?,
      startPoint: map['startPoint'] as String?,
      endPoint: map['endPoint'] as String?,
      stops: map['stops'] as String?,
      departureTime: map['departureTime'] as String?,
      arrivalTime: map['arrivalTime'] as String?,
      fare: (map['fare'] as num?)?.toDouble() ?? 0,
      isActive: (map['isActive'] as int?) == 1,
      createdAt: map['createdAt'] as String,
      updatedAt: map['updatedAt'] as String?,
      vehicleNumber: map['vehicleNumber'] as String?,
      vehicleCapacity: map['vehicleCapacity'] as int?,
    );
  }

  RouteModel copyWith({
    int? id,
    String? routeName,
    int? vehicleId,
    String? startPoint,
    String? endPoint,
    String? stops,
    String? departureTime,
    String? arrivalTime,
    double? fare,
    bool? isActive,
    String? createdAt,
    String? updatedAt,
  }) {
    return RouteModel(
      id: id ?? this.id,
      routeName: routeName ?? this.routeName,
      vehicleId: vehicleId ?? this.vehicleId,
      startPoint: startPoint ?? this.startPoint,
      endPoint: endPoint ?? this.endPoint,
      stops: stops ?? this.stops,
      departureTime: departureTime ?? this.departureTime,
      arrivalTime: arrivalTime ?? this.arrivalTime,
      fare: fare ?? this.fare,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      vehicleNumber: vehicleNumber,
      vehicleCapacity: vehicleCapacity,
    );
  }

  @override
  String toString() => 'RouteModel(id: $id, name: $routeName, fare: $fare)';
}
