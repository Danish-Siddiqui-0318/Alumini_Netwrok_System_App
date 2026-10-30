class ApiConfig {
  static const String baseUrl =
      'https://palegoldenrod-squid-456461.hostingersite.com';

  static const String login = '/auth/login';
  static const String register = '/auth/register';
  static const String me = '/auth/me';
  static const String posts = '/posts';
  static const String profiles = '/profiles';
  static const String users = '/users';

  // Routes mounted under /api in server.js
  static const String comments = '/api/posts';
  static const String likes = '/api/posts';
  static const String jobs = '/api/jobs';
  static const String messages = '/api/messages';
  static const String notifications = '/api/notifications';
}
