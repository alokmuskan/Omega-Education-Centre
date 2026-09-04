class BranchModel {
  final int? id;
  final String name;
  final String? address;
  final String? phone;
  final String? email;
  final String? managerName;
  final String? managerPhone;
  final bool isActive;
  final String createdAt;
  final String? updatedAt;

  const BranchModel({
    this.id,
    required this.name,
    this.address,
    this.phone,
    this.email,
    this.managerName,
    this.managerPhone,
    this.isActive = true,
    required this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'address': address,
        'phone': phone,
        'email': email,
        'managerName': managerName,
        'managerPhone': managerPhone,
        'isActive': isActive ? 1 : 0,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
      };

  factory BranchModel.fromMap(Map<String, dynamic> map) => BranchModel(
        id: map['id'] as int?,
        name: map['name'] as String? ?? '',
        address: map['address'] as String?,
        phone: map['phone'] as String?,
        email: map['email'] as String?,
        managerName: map['managerName'] as String?,
        managerPhone: map['managerPhone'] as String?,
        isActive: (map['isActive'] as int?) == 1,
        createdAt: map['createdAt'] as String? ?? '',
        updatedAt: map['updatedAt'] as String?,
      );

  BranchModel copyWith({
    int? id,
    String? name,
    String? address,
    String? phone,
    String? email,
    String? managerName,
    String? managerPhone,
    bool? isActive,
    String? createdAt,
    String? updatedAt,
  }) {
    return BranchModel(
      id: id ?? this.id,
      name: name ?? this.name,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      managerName: managerName ?? this.managerName,
      managerPhone: managerPhone ?? this.managerPhone,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
