/// Teacher data model for Omega Education Centre ERP.
///
/// Stores teacher details including [subjects], supporting multiple assigned subjects
/// per teacher, and [payPerHour], which is used to compute earned wages.
class TeacherModel {
  final int? id;
  final String name;
  final String mobile;
  final List<String> subjects;
  final String? qualification;
  final double payPerHour;
  final String joiningDate; // YYYY-MM-DD
  final bool isActive;
  final String createdAt;
  final String? updatedAt;
  final String? profilePhotoPath;

  TeacherModel({
    this.id,
    required this.name,
    required this.mobile,
    List<String>? subjects,
    String? subject,
    this.qualification,
    required this.payPerHour,
    required this.joiningDate,
    this.isActive = true,
    required this.createdAt,
    this.updatedAt,
    this.profilePhotoPath,
  })  : subjects = subjects ??
            (subject != null && subject.isNotEmpty
                ? (subject.contains(',')
                    ? subject.split(',')
                    : subject.split('•'))
                        .map((s) => s.trim())
                        .where((s) => s.isNotEmpty)
                        .toList()
                : const []);

  /// Formatted subject display string (e.g., "Mathematics • Physics • Chemistry")
  String get subject => subjects.isNotEmpty ? subjects.join(' • ') : '';

  /// Joined comma-separated string for DB storage (e.g., "Mathematics, Physics, Chemistry")
  String get subjectsJoined => subjects.join(', ');

  /// Status display label: 'Active' or 'Inactive'
  String get status => isActive ? 'Active' : 'Inactive';

  // ── Serialisation ────────────────────────────────────────────────────

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'name': name,
      'mobile': mobile,
      'subject': subjectsJoined,
      'qualification': qualification,
      'payPerHour': payPerHour,
      'joiningDate': joiningDate,
      'isActive': isActive ? 1 : 0,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'profilePhotoPath': profilePhotoPath,
    };
    if (id != null) map['id'] = id;
    return map;
  }

  factory TeacherModel.fromMap(Map<String, dynamic> map) {
    final rawSubject = map['subject'] as String? ?? '';
    final parsedSubjects = rawSubject.isNotEmpty
        ? (rawSubject.contains(',')
            ? rawSubject.split(',')
            : rawSubject.split('•'))
                .map((s) => s.trim())
                .where((s) => s.isNotEmpty)
                .toList()
        : <String>[];

    return TeacherModel(
      id: map['id'] as int?,
      name: map['name'] as String,
      mobile: map['mobile'] as String,
      subjects: parsedSubjects,
      qualification: map['qualification'] as String?,
      payPerHour: (map['payPerHour'] as num).toDouble(),
      joiningDate: map['joiningDate'] as String,
      isActive: (map['isActive'] as int? ?? 1) == 1,
      createdAt: map['createdAt'] as String? ?? '',
      updatedAt: map['updatedAt'] as String?,
      profilePhotoPath: map['profilePhotoPath'] as String?,
    );
  }

  // ── copyWith ─────────────────────────────────────────────────────────

  TeacherModel copyWith({
    int? id,
    String? name,
    String? mobile,
    List<String>? subjects,
    String? subject,
    String? qualification,
    double? payPerHour,
    String? joiningDate,
    bool? isActive,
    String? createdAt,
    String? updatedAt,
    String? profilePhotoPath,
  }) {
    return TeacherModel(
      id: id ?? this.id,
      name: name ?? this.name,
      mobile: mobile ?? this.mobile,
      subjects: subjects ?? (subject != null ? null : this.subjects),
      subject: subject,
      qualification: qualification ?? this.qualification,
      payPerHour: payPerHour ?? this.payPerHour,
      joiningDate: joiningDate ?? this.joiningDate,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      profilePhotoPath: profilePhotoPath ?? this.profilePhotoPath,
    );
  }
}
