/// Student Transport Model
///
/// Represents a student's assignment to a transport route.
class StudentTransportModel {
  final int? id;
  final int studentId;
  final int routeId;
  final String? stopName;
  final String pickupOrDrop; // 'Pickup', 'Drop', 'Both'
  final double monthlyFee;
  final bool isActive;
  final String createdAt;
  final String? updatedAt;

  // Joined fields
  final String? studentName;
  final int? studentRollNo;
  final String? studentClass;
  final String? routeName;
  final String? vehicleNumber;

  StudentTransportModel({
    this.id,
    required this.studentId,
    required this.routeId,
    this.stopName,
    this.pickupOrDrop = 'Both',
    this.monthlyFee = 0,
    this.isActive = true,
    required this.createdAt,
    this.updatedAt,
    this.studentName,
    this.studentRollNo,
    this.studentClass,
    this.routeName,
    this.vehicleNumber,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'studentId': studentId,
      'routeId': routeId,
      'stopName': stopName,
      'pickupOrDrop': pickupOrDrop,
      'monthlyFee': monthlyFee,
      'isActive': isActive ? 1 : 0,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  factory StudentTransportModel.fromMap(Map<String, dynamic> map) {
    return StudentTransportModel(
      id: map['id'] as int?,
      studentId: map['studentId'] as int,
      routeId: map['routeId'] as int,
      stopName: map['stopName'] as String?,
      pickupOrDrop: map['pickupOrDrop'] as String? ?? 'Both',
      monthlyFee: (map['monthlyFee'] as num?)?.toDouble() ?? 0,
      isActive: (map['isActive'] as int?) == 1,
      createdAt: map['createdAt'] as String,
      updatedAt: map['updatedAt'] as String?,
      studentName: map['studentName'] as String?,
      studentRollNo: map['studentRollNo'] as int?,
      studentClass: map['studentClass'] as String?,
      routeName: map['routeName'] as String?,
      vehicleNumber: map['vehicleNumber'] as String?,
    );
  }

  StudentTransportModel copyWith({
    int? id,
    int? studentId,
    int? routeId,
    String? stopName,
    String? pickupOrDrop,
    double? monthlyFee,
    bool? isActive,
    String? createdAt,
    String? updatedAt,
  }) {
    return StudentTransportModel(
      id: id ?? this.id,
      studentId: studentId ?? this.studentId,
      routeId: routeId ?? this.routeId,
      stopName: stopName ?? this.stopName,
      pickupOrDrop: pickupOrDrop ?? this.pickupOrDrop,
      monthlyFee: monthlyFee ?? this.monthlyFee,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      studentName: studentName,
      studentRollNo: studentRollNo,
      studentClass: studentClass,
      routeName: routeName,
      vehicleNumber: vehicleNumber,
    );
  }

  @override
  String toString() => 'StudentTransportModel(id: $id, student: $studentId, route: $routeId)';
}
