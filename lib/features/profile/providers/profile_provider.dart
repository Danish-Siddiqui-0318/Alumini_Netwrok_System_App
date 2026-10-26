import 'package:flutter/foundation.dart';

import '../../../core/network/api_client.dart';
import '../models/profile_model.dart';
import '../repositories/profile_repository.dart';

class ProfileProvider extends ChangeNotifier {
  final ProfileRepository _repository = ProfileRepository(ApiClient());

  ProfileModel? profile;
  bool isLoading = false;
  bool isSaving = false;
  String? errorMessage;

  Future<void> loadMyProfile() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      profile = await _repository.getMyProfile();
    } catch (e) {
      errorMessage = e.toString().replaceFirst('Exception: ', '');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> saveProfile(ProfileModel updatedProfile) async {
    isSaving = true;
    errorMessage = null;
    notifyListeners();

    try {
      profile = await _repository.updateMyProfile(updatedProfile);
      return true;
    } catch (e) {
      errorMessage = e.toString().replaceFirst('Exception: ', '');
      return false;
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }

  Future<ProfileModel> loadPublicProfile(int userId) {
    return _repository.getPublicProfile(userId);
  }
}
