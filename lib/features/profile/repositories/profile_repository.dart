import '../../../core/network/api_client.dart';
import '../models/profile_model.dart';

class ProfileRepository {
  final ApiClient _apiClient;

  ProfileRepository(this._apiClient);

  Map<String, dynamic> _extractProfile(Map<String, dynamic> response) {
    final value = response['profile'];

    if (value is Map<String, dynamic>) {
      return value;
    }

    return response;
  }

  Future<ProfileModel> getMyProfile() async {
    try {
      final response = await _apiClient.get('/profiles/me');
      return ProfileModel.fromJson(_extractProfile(response));
    } catch (error) {
      final message = error.toString();

      // Only create a profile when the backend specifically
      // reports that the profile does not exist.
      if (!message.contains('404') &&
          !message.toLowerCase().contains('profile not found')) {
        rethrow;
      }

      await _apiClient.put('/profiles/me', body: const {});

      final response = await _apiClient.get('/profiles/me');
      return ProfileModel.fromJson(_extractProfile(response));
    }
  }

  Future<ProfileModel> updateMyProfile(ProfileModel profile) async {
    await _apiClient.put('/profiles/me', body: profile.toJson());

    return getMyProfile();
  }

  Future<ProfileModel> getPublicProfile(int userId) async {
    final response = await _apiClient.get('/profiles/$userId');

    return ProfileModel.fromJson(_extractProfile(response));
  }
}
