import 'package:flutter/foundation.dart';

import '../../../core/network/api_client.dart';
import '../models/user_model.dart';
import '../repositories/auth_repository.dart';

class AuthProvider extends ChangeNotifier {
  final AuthRepository _repository = AuthRepository(ApiClient());

  bool isLoading = false;
  bool isAuthenticated = false;
  bool isCheckingSession = true;
  String? errorMessage;
  UserModel? currentUser;

  // Call this when the app starts.
  Future<void> checkAuthStatus() async {
    isCheckingSession = true;
    notifyListeners();

    try {
      final token = await _repository.getSavedToken();

      if (token == null || token.isEmpty) {
        isAuthenticated = false;
        currentUser = null;
        return;
      }

      currentUser = await _repository.getCurrentUser();
      isAuthenticated = true;
    } catch (_) {
      await _repository.logout();
      currentUser = null;
      isAuthenticated = false;
    } finally {
      isCheckingSession = false;
      notifyListeners();
    }
  }

  Future<bool> login({required String email, required String password}) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      await _repository.login(email: email, password: password);

      currentUser = await _repository.getCurrentUser();
      isAuthenticated = true;
      return true;
    } catch (error) {
      await _repository.logout();
      currentUser = null;
      isAuthenticated = false;
      errorMessage = error.toString().replaceFirst('Exception: ', '');
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> signup({
    required String name,
    required String email,
    required String password,
    required String role,
  }) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      await _repository.signup(
        name: name,
        email: email,
        password: password,
        role: role,
      );
      return true;
    } catch (error) {
      errorMessage = error.toString().replaceFirst('Exception: ', '');
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    await _repository.logout();
    currentUser = null;
    isAuthenticated = false;
    errorMessage = null;
    notifyListeners();
  }
}
