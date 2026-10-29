import 'package:flutter/foundation.dart';

import '../../../core/network/api_client.dart';
import '../models/job_model.dart';

class JobProvider extends ChangeNotifier {
  final ApiClient _apiClient = ApiClient();

  List<JobModel> _jobs = [];
  bool _isLoading = false;
  String? _error;

  List<JobModel> get jobs => _jobs;

  bool get isLoading => _isLoading;

  String? get error => _error;

  Future<void> loadJobs() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _apiClient.get('/api/jobs');
      final List<dynamic> data = response['jobs'] ?? [];

      _jobs = data
          .map((item) => JobModel.fromJson(Map<String, dynamic>.from(item)))
          .toList();
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<JobModel?> getJobDetails(int jobId) async {
    try {
      final response = await _apiClient.get('/api/jobs/$jobId');

      final data = response['job'];
      if (data == null) return null;

      return JobModel.fromJson(Map<String, dynamic>.from(data));
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      rethrow;
    }
  }

  Future<bool> createJob(Map<String, dynamic> data) async {
    try {
      await _apiClient.post('/api/jobs', body: data);
      await loadJobs();
      return true;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateJob(int jobId, Map<String, dynamic> data) async {
    try {
      await _apiClient.put('/api/jobs/$jobId', body: data);
      await loadJobs();
      return true;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteJob(int jobId) async {
    try {
      await _apiClient.delete('/api/jobs/$jobId');
      await loadJobs();
      return true;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  Future<bool> applyForJob(int jobId) async {
    try {
      await _apiClient.post('/api/jobs/$jobId/apply');
      return true;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      rethrow;
    }
  }
}
