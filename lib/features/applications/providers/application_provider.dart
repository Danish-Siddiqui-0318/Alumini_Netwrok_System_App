import 'package:flutter/foundation.dart';

import '../../../core/network/api_client.dart';
import '../models/application_model.dart';

class ApplicationProvider extends ChangeNotifier {
  final ApiClient _apiClient = ApiClient();

  List<ApplicationModel> _applications = [];
  bool _isLoading = false;
  bool _isApplying = false;
  String? _error;

  List<ApplicationModel> get applications => _applications;

  bool get isLoading => _isLoading;

  bool get isApplying => _isApplying;

  String? get error => _error;

  Future<bool> applyForJob(
    int jobId, {
    String? coverLetter,
    String? resumeUrl,
  }) async {
    _isApplying = true;
    _error = null;
    notifyListeners();

    try {
      await _apiClient.post(
        '/api/jobs/$jobId/apply',
        body: {'cover_letter': coverLetter, 'resume_url': resumeUrl},
      );

      await loadMyApplications();
      return true;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      return false;
    } finally {
      _isApplying = false;
      notifyListeners();
    }
  }

  Future<void> loadMyApplications() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _apiClient.get('/api/applications/my');
      final List<dynamic> data = response['applications'] ?? [];

      _applications = data
          .map(
            (item) =>
                ApplicationModel.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList();
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> withdrawApplication(int applicationId) async {
    _error = null;

    try {
      await _apiClient.delete('/api/applications/$applicationId');

      _applications.removeWhere(
        (application) => application.applicationId == applicationId,
      );

      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  bool hasAppliedFor(int jobId) {
    return _applications.any((application) => application.jobId == jobId);
  }
}
