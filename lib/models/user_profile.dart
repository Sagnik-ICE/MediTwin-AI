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
    required this.knownConditions,
  });

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
  final String knownConditions;

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
      knownConditions: '',
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
      'knownConditions': knownConditions,
    };
  }

  factory UserProfile.fromMap(Map<String, dynamic> map) {
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
      knownConditions: (map['knownConditions'] as String?) ?? '',
    );
  }
}
