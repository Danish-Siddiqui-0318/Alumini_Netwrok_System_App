import '../../../core/network/api_client.dart';
import '../models/alumni_model.dart';

class AlumniRepository {
  final ApiClient _apiClient = ApiClient();

  // Get all alumni
  Future<List<AlumniModel>> getAllAlumni() async {
    final response = await _apiClient.get('/users/alumni');

    final List<dynamic> data = response['alumni'] ?? [];

    return data
        .map((item) => AlumniModel.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  // Search alumni by name
  Future<List<AlumniModel>> searchAlumni(String name) async {
    final encodedName = Uri.encodeQueryComponent(name.trim());

    final response = await _apiClient.get('/users/search?name=$encodedName');

    final List<dynamic> data = response['users'] ?? [];

    return data
        .map((item) => AlumniModel.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }
}
