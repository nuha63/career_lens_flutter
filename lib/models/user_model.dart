class UserModel {
  final String id;
  final String email;
  final String name;
  final String? profilePictureUrl;
  final bool isAdmin;
  final bool isPremium;

  UserModel({
    required this.id,
    required this.email,
    required this.name,
    this.profilePictureUrl,
    this.isAdmin = false,
    this.isPremium = false,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] ?? '',
      email: json['email'] ?? '',
      name: json['name'] ?? 'User',
      profilePictureUrl: json['profilePictureUrl'],
      isAdmin: json['isAdmin'] ?? json['is_admin'] ?? false,
      isPremium: json['isPremium'] ?? json['is_premium'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'profilePictureUrl': profilePictureUrl,
      'isAdmin': isAdmin,
      'isPremium': isPremium,
    };
  }
}
