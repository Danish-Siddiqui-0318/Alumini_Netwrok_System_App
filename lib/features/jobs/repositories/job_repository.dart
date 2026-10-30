import '../../../core/network/api_client.dart';
import '../models/job_model.dart';

class JobRepository {
  final ApiClient _apiClient = ApiClient();

  // Get all jobs
  Future<List<JobModel>> getJobs() async {
    final response = await _apiClient.get('/api/jobs');

    final List<dynamic> data = response['jobs'] ?? [];

    return data.map((item) {
      return JobModel.fromJson(Map<String, dynamic>.from(item));
    }).toList();
  }

  // Get job details
  Future<JobModel?> getJobDetails(int jobId) async {
    final response = await _apiClient.get('/api/jobs/$jobId');

    final data = response['job'];

    if (data == null) {
      return null;
    }

    return JobModel.fromJson(Map<String, dynamic>.from(data));
  }

  // Create a job
  Future<void> createJob(Map<String, dynamic> data) async {
    await _apiClient.post('/api/jobs', body: data);
  }

  // Update a job
  Future<void> updateJob(int jobId, Map<String, dynamic> data) async {
    await _apiClient.put('/api/jobs/$jobId', body: data);
  }

  // Delete a job
  Future<void> deleteJob(int jobId) async {
    await _apiClient.delete('/api/jobs/$jobId');
  }

  // Apply for a job
  Future<void> applyForJob(int jobId) async {
    await _apiClient.post('/api/jobs/$jobId/apply');
  }
}
