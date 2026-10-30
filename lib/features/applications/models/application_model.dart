class ApplicationModel {
  final int applicationId;
  final int jobId;
  final String? coverLetter;
  final String? resumeUrl;
  final String status;
  final String? appliedAt;
  final String? jobTitle;
  final String? company;
  final String? location;
  final String? jobType;
  final String? deadline;

  const ApplicationModel({
    required this.applicationId,
    required this.jobId,
    this.coverLetter,
    this.resumeUrl,
    required this.status,
    this.appliedAt,
    this.jobTitle,
    this.company,
    this.location,
    this.jobType,
    this.deadline,
  });

  factory ApplicationModel.fromJson(Map<String, dynamic> json) {
    return ApplicationModel(
      applicationId:
          int.tryParse(json['application_id']?.toString() ?? '') ?? 0,
      jobId: int.tryParse(json['job_id']?.toString() ?? '') ?? 0,
      coverLetter: json['cover_letter']?.toString(),
      resumeUrl: json['resume_url']?.toString(),
      status: json['status']?.toString() ?? 'pending',
      appliedAt: json['applied_at']?.toString(),
      jobTitle: json['job_title']?.toString(),
      company: json['company']?.toString(),
      location: json['location']?.toString(),
      jobType: json['job_type']?.toString(),
      deadline: json['deadline']?.toString(),
    );
  }
}
