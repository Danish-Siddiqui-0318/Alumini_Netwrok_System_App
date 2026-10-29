class JobModel {
  final int jobId;
  final int postedBy;
  final String title;
  final String company;
  final String description;
  final String? location;
  final String jobType;
  final String? applicationUrl;
  final String? deadline;
  final String? posterName;
  final String? createdAt;

  const JobModel({
    required this.jobId,
    required this.postedBy,
    required this.title,
    required this.company,
    required this.description,
    this.location,
    required this.jobType,
    this.applicationUrl,
    this.deadline,
    this.posterName,
    this.createdAt,
  });

  factory JobModel.fromJson(Map<String, dynamic> json) {
    return JobModel(
      jobId: int.parse(json['job_id'].toString()),
      postedBy: int.parse(json['posted_by'].toString()),
      title: json['title']?.toString() ?? '',
      company: json['company']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      location: json['location']?.toString(),
      jobType: json['job_type']?.toString() ?? '',
      applicationUrl: json['application_url']?.toString(),
      deadline: json['deadline']?.toString(),
      posterName: json['poster_name']?.toString(),
      createdAt: json['created_at']?.toString(),
    );
  }

  String get formattedJobType {
    switch (jobType) {
      case 'full_time':
        return 'Full Time';
      case 'part_time':
        return 'Part Time';
      case 'internship':
        return 'Internship';
      case 'contract':
        return 'Contract';
      default:
        return jobType;
    }
  }
}
