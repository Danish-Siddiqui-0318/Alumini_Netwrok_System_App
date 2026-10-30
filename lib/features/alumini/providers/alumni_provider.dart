import 'package:flutter/material.dart';

import '../models/alumni_model.dart';
import '../repositories/alumni_repository.dart';

class AlumniProvider extends ChangeNotifier {
  final AlumniRepository _repository = AlumniRepository();

  List<AlumniModel> _alumni = [];
  bool _isLoading = false;
  String? _error;

  List<AlumniModel> get alumni => _alumni;

  bool get isLoading => _isLoading;

  String? get error => _error;

  // Load all alumni
  Future<void> loadAlumni() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _alumni = await _repository.getAllAlumni();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Search alumni
  Future<void> searchAlumni(String name) async {
    if (name.trim().isEmpty) {
      await loadAlumni();
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _alumni = await _repository.searchAlumni(name);
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
