import '../../../shared/constants/app_constants.dart';

/// Model representing Institute Profile configuration settings.
class InstituteProfileModel {
  final String name;
  final String address;
  final String phone;
  final String email;
  final String principalName;
  final String academicYear;
  final String logoPath;

  const InstituteProfileModel({
    required this.name,
    required this.address,
    required this.phone,
    required this.email,
    required this.principalName,
    required this.academicYear,
    this.logoPath = '',
  });

  /// Factory creating default institute settings from AppConstants
  factory InstituteProfileModel.defaultSettings() {
    return const InstituteProfileModel(
      name: AppConstants.appName,
      address: 'Samastipur, Bihar',
      phone: '+91 9876543210',
      email: 'info@omegaeducation.com',
      principalName: 'Director Name',
      academicYear: '2026-27',
      logoPath: '',
    );
  }

  Map<String, String> toMap() {
    return {
      'inst_name': name,
      'inst_address': address,
      'inst_phone': phone,
      'inst_email': email,
      'principal_name': principalName,
      'academic_year': academicYear,
      'inst_logo': logoPath,
    };
  }

  factory InstituteProfileModel.fromMap(Map<String, String?> map) {
    final defaultInst = InstituteProfileModel.defaultSettings();
    return InstituteProfileModel(
      name: map['inst_name'] ?? defaultInst.name,
      address: map['inst_address'] ?? defaultInst.address,
      phone: map['inst_phone'] ?? defaultInst.phone,
      email: map['inst_email'] ?? defaultInst.email,
      principalName: map['principal_name'] ?? defaultInst.principalName,
      academicYear: map['academic_year'] ?? defaultInst.academicYear,
      logoPath: map['inst_logo'] ?? defaultInst.logoPath,
    );
  }

  InstituteProfileModel copyWith({
    String? name,
    String? address,
    String? phone,
    String? email,
    String? principalName,
    String? academicYear,
    String? logoPath,
  }) {
    return InstituteProfileModel(
      name: name ?? this.name,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      principalName: principalName ?? this.principalName,
      academicYear: academicYear ?? this.academicYear,
      logoPath: logoPath ?? this.logoPath,
    );
  }
}
