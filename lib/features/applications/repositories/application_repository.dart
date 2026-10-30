
import '../../../core/network/api_client.dart';
import '../models/application_model.dart';

class ApplicationRepository {
  final ApiClient _apiClient = ApiClient();

  // Apply for a job
  Future<void> applyForJob(
      int jobId, {
        String? coverLetter,
        String? resumeUrl,
      }) async {
    await _apiClient.post(
      '/api/jobs/$jobId/apply',
      body: {
        'cover_letter': coverLetter,
        'resume_url': resumeUrl,
      },
    );
  }

  // Get applications submitted by the logged-in user
  Future<List<ApplicationModel>> getMyApplications() async {
    final response = await _apiClient.get('/api/applications/my');

    final List<dynamic> data = response['applications'] ?? [];

    return data
        .map(
          (item) => ApplicationModel.fromJson(
        Map<String, dynamic>.from(item),
      ),
    )
        .toList();
  }

  // Withdraw an application
  Future<void> withdrawApplication(int applicationId) async {
    await _apiClient.delete('/api/applications/$applicationId');
  }
}
