import 'package:flutter/foundation.dart';

import '../models/application_model.dart';
import '../repositories/application_repository.dart';

class ApplicationProvider extends ChangeNotifier {
  final ApplicationRepository _repository = ApplicationRepository();

  List<ApplicationModel> _applications = [];

  bool _isLoading = false;
  bool _isApplying = false;
  String? _error;

  List<ApplicationModel> get applications => _applications;

  bool get isLoading => _isLoading;

  bool get isApplying => _isApplying;

  String? get error => _error;

  // Apply for a job
  Future<bool> applyForJob(
    int jobId, {
    String? coverLetter,
    String? resumeUrl,
  }) async {
    _isApplying = true;
    _error = null;
    notifyListeners();

    try {
      await _repository.applyForJob(
        jobId,
        coverLetter: coverLetter,
        resumeUrl: resumeUrl,
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

  // Load current user's applications
  Future<void> loadMyApplications() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _applications = await _repository.getMyApplications();
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Withdraw an application
  Future<bool> withdrawApplication(int applicationId) async {
    _error = null;

    try {
      await _repository.withdrawApplication(applicationId);

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

  // Check whether user has already applied
  bool hasAppliedFor(int jobId) {
    return _applications.any((application) => application.jobId == jobId);
  }
}
