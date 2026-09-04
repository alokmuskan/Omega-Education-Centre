/// Vehicle Model
///
/// Represents a vehicle (bus/van) in the transport system.
class VehicleModel {
  final int? id;
  final String vehicleNumber;
  final String vehicleType;
  final int capacity;
  final String? driverName;
  final String? driverPhone;
  final bool isActive;
  final String createdAt;
  final String? updatedAt;

  VehicleModel({
    this.id,
    required this.vehicleNumber,
    this.vehicleType = 'Bus',
    this.capacity = 40,
    this.driverName,
    this.driverPhone,
    this.isActive = true,
    required this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'vehicleNumber': vehicleNumber,
      'vehicleType': vehicleType,
      'capacity': capacity,
      'driverName': driverName,
      'driverPhone': driverPhone,
      'isActive': isActive ? 1 : 0,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  factory VehicleModel.fromMap(Map<String, dynamic> map) {
    return VehicleModel(
      id: map['id'] as int?,
      vehicleNumber: map['vehicleNumber'] as String,
      vehicleType: map['vehicleType'] as String? ?? 'Bus',
      capacity: map['capacity'] as int? ?? 40,
      driverName: map['driverName'] as String?,
      driverPhone: map['driverPhone'] as String?,
      isActive: (map['isActive'] as int?) == 1,
      createdAt: map['createdAt'] as String,
      updatedAt: map['updatedAt'] as String?,
    );
  }

  VehicleModel copyWith({
    int? id,
    String? vehicleNumber,
    String? vehicleType,
    int? capacity,
    String? driverName,
    String? driverPhone,
    bool? isActive,
    String? createdAt,
    String? updatedAt,
  }) {
    return VehicleModel(
      id: id ?? this.id,
      vehicleNumber: vehicleNumber ?? this.vehicleNumber,
      vehicleType: vehicleType ?? this.vehicleType,
      capacity: capacity ?? this.capacity,
      driverName: driverName ?? this.driverName,
      driverPhone: driverPhone ?? this.driverPhone,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() => 'VehicleModel(id: $id, number: $vehicleNumber, type: $vehicleType)';
}
