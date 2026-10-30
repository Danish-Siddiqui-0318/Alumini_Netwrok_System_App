import 'package:flutter/foundation.dart';

import '../models/job_model.dart';
import '../repositories/job_repository.dart';

class JobProvider extends ChangeNotifier {
  final JobRepository _repository = JobRepository();

  List<JobModel> _jobs = [];
  bool _isLoading = false;
  String? _error;

  List<JobModel> get jobs => _jobs;

  bool get isLoading => _isLoading;

  String? get error => _error;

  // Load all jobs
  Future<void> loadJobs() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _jobs = await _repository.getJobs();
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Get job details
  Future<JobModel?> getJobDetails(int jobId) async {
    try {
      return await _repository.getJobDetails(jobId);
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      rethrow;
    }
  }

  // Create a job
  Future<bool> createJob(Map<String, dynamic> data) async {
    try {
      _error = null;

      await _repository.createJob(data);
      await loadJobs();

      return true;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  // Update a job
  Future<bool> updateJob(int jobId, Map<String, dynamic> data) async {
    try {
      _error = null;

      await _repository.updateJob(jobId, data);
      await loadJobs();

      return true;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  // Delete a job
  Future<bool> deleteJob(int jobId) async {
    try {
      _error = null;

      await _repository.deleteJob(jobId);
      _jobs.removeWhere((job) => job.jobId == jobId);

      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  // Apply for a job
  Future<bool> applyForJob(int jobId) async {
    try {
      _error = null;

      await _repository.applyForJob(jobId);

      return true;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      rethrow;
    }
  }
}
