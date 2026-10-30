class AlumniModel {
  final int userId;
  final String name;
  final String? email;
  final String? role;
  final int? isVerified;
  final String? profilePicture;
  final String? bio;
  final String? department;
  final String? degree;
  final int? graduationYear;
  final String? currentCompany;
  final String? jobTitle;
  final String? location;
  final String? skills;
  final String? linkedinUrl;
  final String? githubUrl;

  AlumniModel({
    required this.userId,
    required this.name,
    this.email,
    this.role,
    this.isVerified,
    this.profilePicture,
    this.bio,
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

  factory AlumniModel.fromJson(Map<String, dynamic> json) {
    return AlumniModel(
      userId: int.tryParse(json['user_id'].toString()) ?? 0,
      name: json['name']?.toString() ?? 'Unknown',
      email: json['email']?.toString(),
      role: json['role']?.toString(),
      isVerified: int.tryParse(json['is_verified']?.toString() ?? ''),
      profilePicture: json['profile_picture']?.toString(),
      bio: json['bio']?.toString(),
      department: json['department']?.toString(),
      degree: json['degree']?.toString(),
      graduationYear: int.tryParse(json['graduation_year']?.toString() ?? ''),
      currentCompany: json['current_company']?.toString(),
      jobTitle: json['job_title']?.toString(),
      location: json['location']?.toString(),
      skills: json['skills']?.toString(),
      linkedinUrl: json['linkedin_url']?.toString(),
      githubUrl: json['github_url']?.toString(),
    );
  }
}
