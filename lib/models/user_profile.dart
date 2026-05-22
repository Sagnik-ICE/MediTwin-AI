class UserProfile {
  UserProfile({
    required this.name,
    required this.email,
    required this.age,
    required this.gender,
    required this.bloodGroup,
    required this.isBloodDonor,
    required this.donorContactInfo,
    required this.heightCm,
    required this.weightKg,
    required this.healthGoals,
    String? contactInfo,
    String? knownConditions,
    this.division = '',
    this.district = '',
    this.accountType = 'patient',
  }) : contactInfo = contactInfo ?? knownConditions ?? '';

  final String name;
  final String email;
  final int age;
  final String gender;
  final String bloodGroup;
  final bool isBloodDonor;
  final String donorContactInfo;
  final double heightCm;
  final double weightKg;
  final String healthGoals;
  final String accountType;
  final String contactInfo;
  final String division;
  final String district;

  String get knownConditions => contactInfo;

  factory UserProfile.empty() => UserProfile(
      name: '',
      email: '',
      age: 0,
      gender: '',
      bloodGroup: '',
      isBloodDonor: false,
      donorContactInfo: '',
      heightCm: 0,
      weightKg: 0,
      healthGoals: '',
      contactInfo: '',
      division: '',
      district: '',
      accountType: 'patient',
      );

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'age': age,
      'gender': gender,
      'bloodGroup': bloodGroup,
      'isBloodDonor': isBloodDonor,
      'donorContactInfo': donorContactInfo,
      'heightCm': heightCm,
      'weightKg': weightKg,
      'healthGoals': healthGoals,
      'contactInfo': contactInfo,
      'knownConditions': contactInfo,
      'division': division,
      'district': district,
      'accountType': accountType,
    };
  }

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    final contact = (map['contactInfo'] as String?) ?? (map['knownConditions'] as String?) ?? '';
    return UserProfile(
      name: (map['name'] as String?) ?? '',
      email: (map['email'] as String?) ?? '',
      age: (map['age'] as num?)?.toInt() ?? 0,
      gender: (map['gender'] as String?) ?? '',
      bloodGroup: (map['bloodGroup'] as String?) ?? '',
      isBloodDonor: (map['isBloodDonor'] as bool?) ?? false,
      donorContactInfo: (map['donorContactInfo'] as String?) ?? '',
      heightCm: (map['heightCm'] as num?)?.toDouble() ?? 0,
      weightKg: (map['weightKg'] as num?)?.toDouble() ?? 0,
      healthGoals: (map['healthGoals'] as String?) ?? '',
      contactInfo: contact,
      division: (map['division'] as String?) ?? '',
      district: (map['district'] as String?) ?? '',
      accountType: (map['accountType'] as String?) ?? 'patient',
    );
  }
}
