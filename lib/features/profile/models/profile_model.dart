class ProfileModel {
  final int? userId;
  final String name;
  final String? role;
  final bool isVerified;
  final String? profilePicture;
  final String? bio;
  final String? phone;
  final String? department;
  final String? degree;
  final int? graduationYear;
  final String? currentCompany;
  final String? jobTitle;
  final String? location;
  final String? skills;
  final String? linkedinUrl;
  final String? githubUrl;

  const ProfileModel({
    this.userId,
    this.name = '',
    this.role,
    this.isVerified = false,
    this.profilePicture,
    this.bio,
    this.phone,
    this.department,
    this.degree,
    this.graduationYear,
    this.currentCompany,
    this.jobTitle,
    this.location,
    this.skills,
    this.linkedinUrl,
    this.githubUrl,
  });

  factory ProfileModel.fromJson(Map<String, dynamic> json) {
    return ProfileModel(
      userId: int.tryParse('${json['user_id'] ?? ''}'),
      name: json['name']?.toString() ?? '',
      role: json['role']?.toString(),
      isVerified:
          json['is_verified'] == true || json['is_verified']?.toString() == '1',
      profilePicture: json['profile_picture']?.toString(),
      bio: json['bio']?.toString(),
      phone: json['phone']?.toString(),
      department: json['department']?.toString(),
      degree: json['degree']?.toString(),
      graduationYear: int.tryParse('${json['graduation_year'] ?? ''}'),
      currentCompany: json['current_company']?.toString(),
      jobTitle: json['job_title']?.toString(),
      location: json['location']?.toString(),
      skills: json['skills']?.toString(),
      linkedinUrl: json['linkedin_url']?.toString(),
      githubUrl: json['github_url']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'profile_picture': profilePicture,
      'bio': bio,
      'phone': phone,
      'department': department,
      'degree': degree,
      'graduation_year': graduationYear,
      'current_company': currentCompany,
      'job_title': jobTitle,
      'location': location,
      'skills': skills,
      'linkedin_url': linkedinUrl,
      'github_url': githubUrl,
    };
  }
}
