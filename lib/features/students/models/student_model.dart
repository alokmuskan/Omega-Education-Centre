import '../../fees/models/fee_model.dart';

/// Student data model.
///
/// [feeStatus] is a UI-cache label only — it must NEVER be used for
/// financial calculations. All financial math uses fee_payments records.
///
/// Computed fee status → use [FeeModel + fee_payments] via FeeRepository.
class StudentModel {
  final int? id;
  final String name;
  final String fatherName;
  final String? motherName;
  final String board;
  final String studentClass;
  final int rollNo;
  final String mobile;
  final String? address;

  /// UI display label. Computed from fee_payments — never used for math.
  /// Values: 'Paid' | 'Partially Paid' | 'Due'
  final String feeStatus;

  /// True if the student is currently enrolled.
  final bool isActive;

  /// ISO 8601 timestamp when the record was created.
  final String createdAt;

  /// ISO 8601 timestamp when the record was last updated.
  final String? updatedAt;

  /// Relative path reference to the locally stored profile photo.
  final String? profilePhotoPath;

  const StudentModel({
    this.id,
    required this.name,
    required this.fatherName,
    this.motherName,
    required this.board,
    required this.studentClass,
    required this.rollNo,
    required this.mobile,
    this.address,
    this.feeStatus = 'Due',
    this.isActive = true,
    required this.createdAt,
    this.updatedAt,
    this.profilePhotoPath,
  });

  // ── Serialisation ────────────────────────────────────────────────────

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'name': name,
      'fatherName': fatherName,
      'motherName': motherName,
      'board': board,
      'studentClass': studentClass,
      'rollNo': rollNo,
      'mobile': mobile,
      'address': address ?? '',
      'feeStatus': feeStatus,
      'isActive': isActive ? 1 : 0,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'profilePhotoPath': profilePhotoPath,
    };
    if (id != null) map['id'] = id;
    return map;
  }

  factory StudentModel.fromMap(Map<String, dynamic> map) {
    return StudentModel(
      id: map['id'] as int?,
      name: map['name'] as String,
      fatherName: map['fatherName'] as String,
      motherName: map['motherName'] as String?,
      board: map['board'] as String,
      studentClass: map['studentClass'] as String,
      rollNo: map['rollNo'] as int,
      mobile: map['mobile'] as String,
      address: map['address'] as String?,
      feeStatus: map['feeStatus'] as String? ?? 'Due',
      isActive: (map['isActive'] as int? ?? 1) == 1,
      createdAt: map['createdAt'] as String? ?? '',
      updatedAt: map['updatedAt'] as String?,
      profilePhotoPath: map['profilePhotoPath'] as String?,
    );
  }

  // ── copyWith ─────────────────────────────────────────────────────────

  StudentModel copyWith({
    int? id,
    String? name,
    String? fatherName,
    String? motherName,
    String? board,
    String? studentClass,
    int? rollNo,
    String? mobile,
    String? address,
    String? feeStatus,
    bool? isActive,
    String? createdAt,
    String? updatedAt,
    String? profilePhotoPath,
    FeeModel? feePlan, // reserved for future eager-load
  }) {
    return StudentModel(
      id: id ?? this.id,
      name: name ?? this.name,
      fatherName: fatherName ?? this.fatherName,
      motherName: motherName ?? this.motherName,
      board: board ?? this.board,
      studentClass: studentClass ?? this.studentClass,
      rollNo: rollNo ?? this.rollNo,
      mobile: mobile ?? this.mobile,
      address: address ?? this.address,
      feeStatus: feeStatus ?? this.feeStatus,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      profilePhotoPath: profilePhotoPath ?? this.profilePhotoPath,
    );
  }
}