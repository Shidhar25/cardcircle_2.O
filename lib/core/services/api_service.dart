import 'dart:convert';
import 'package:http/http.dart' as http;
import 'local_storage_service.dart';
import 'logger_service.dart';

class ApiService {
  static const String baseUrl = 'http://13.205.204.182:8080/api/v1';
  static const String cardsCatalogBaseUrl = 'http://10.105.150.152:8080/api/v1';

  static String? _accessToken;
  static String? _refreshToken;

  static Future<void> init() async {
    _accessToken = LocalStorageService.getString('@auth/accessToken');
    _refreshToken = LocalStorageService.getString('@auth/refreshToken');
    if (_accessToken != null) {
      LoggerService.info('Loaded cached access token.');
    }
  }

  static String? get accessToken => _accessToken;
  static String? get refreshTokenString => _refreshToken;

  static Map<String, String> _headers({bool requireAuth = false}) {
    final headers = {
      'accept': 'application/json',
      'Content-Type': 'application/json',
    };
    if (requireAuth && _accessToken != null) {
      headers['Authorization'] = 'Bearer $_accessToken';
    }
    return headers;
  }

  // 1. Fetch bootstrap config
  static Future<Map<String, dynamic>?> getBootstrapConfig() async {
    try {
      LoggerService.info('Fetching bootstrap config from backend...');
      final response = await http.get(
        Uri.parse('$baseUrl/bootstrap/config'),
        headers: _headers(),
      );
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        if (body['success'] == true) {
          LoggerService.debug('Bootstrap config loaded successfully.');
          return body['data'];
        }
      }
      LoggerService.warning('Failed to load bootstrap config: Status ${response.statusCode}');
    } catch (e, stack) {
      LoggerService.error('Error fetching bootstrap config', e, stack);
    }
    return null;
  }

  // 2. Send OTP
  static Future<Map<String, dynamic>?> sendOtp(String phoneNumber, String purpose) async {
    try {
      LoggerService.info('Sending OTP to $phoneNumber for $purpose...');
      final response = await http.post(
        Uri.parse('$baseUrl/otp/send'),
        headers: _headers(),
        body: jsonEncode({
          'phoneNumber': phoneNumber,
          'purpose': purpose,
        }),
      );
      final body = jsonDecode(response.body);
      if (response.statusCode == 200 && body['success'] == true) {
        LoggerService.info('OTP request sent successfully.');
        return body['data']; // requestId, expiresIn, etc.
      }
      LoggerService.warning('OTP send failed: ${body['message'] ?? response.body}');
    } catch (e, stack) {
      LoggerService.error('Error sending OTP', e, stack);
    }
    return null;
  }

  // 3. Verify OTP
  static Future<Map<String, dynamic>?> verifyOtp(String requestId, String otp) async {
    try {
      LoggerService.info('Verifying OTP for request $requestId...');
      final response = await http.post(
        Uri.parse('$baseUrl/otp/verify'),
        headers: _headers(),
        body: jsonEncode({
          'requestId': requestId,
          'otp': otp,
        }),
      );
      final body = jsonDecode(response.body);
      if (response.statusCode == 200 && body['success'] == true) {
        LoggerService.info('OTP verified successfully.');
        final data = body['data'];
        final tokens = data['tokens'];
        if (tokens != null) {
          _accessToken = tokens['accessToken'];
          _refreshToken = tokens['refreshToken'];
          await LocalStorageService.setString('@auth/accessToken', _accessToken!);
          await LocalStorageService.setString('@auth/refreshToken', _refreshToken!);
        }
        return data; // isNewUser, tokens, etc.
      }
      LoggerService.warning('OTP verification failed: ${body['message'] ?? response.body}');
    } catch (e, stack) {
      LoggerService.error('Error verifying OTP', e, stack);
    }
    return null;
  }

  // 4. Resend OTP
  static Future<Map<String, dynamic>?> resendOtp(String requestId) async {
    try {
      LoggerService.info('Resending OTP for request $requestId...');
      final response = await http.post(
        Uri.parse('$baseUrl/otp/resend'),
        headers: _headers(),
        body: jsonEncode({
          'requestId': requestId,
        }),
      );
      final body = jsonDecode(response.body);
      if (response.statusCode == 200 && body['success'] == true) {
        LoggerService.info('OTP resent successfully.');
        return body['data'];
      }
      LoggerService.warning('OTP resend failed: ${body['message'] ?? response.body}');
    } catch (e, stack) {
      LoggerService.error('Error resending OTP', e, stack);
    }
    return null;
  }

  // 5. Refresh token
  static Future<bool> refreshToken() async {
    if (_refreshToken == null) return false;
    try {
      LoggerService.info('Refreshing access token...');
      final response = await http.post(
        Uri.parse('$baseUrl/auth/refresh-token'),
        headers: _headers(),
        body: jsonEncode({
          'refreshToken': _refreshToken,
        }),
      );
      final body = jsonDecode(response.body);
      if (response.statusCode == 200 && body['success'] == true) {
        final data = body['data'];
        _accessToken = data['accessToken'];
        await LocalStorageService.setString('@auth/accessToken', _accessToken!);
        LoggerService.info('Access token refreshed successfully.');
        return true;
      }
      LoggerService.warning('Refresh token failed: ${body['message'] ?? response.body}');
      // Clear invalid tokens
      await logout();
    } catch (e, stack) {
      LoggerService.error('Error refreshing token', e, stack);
    }
    return false;
  }

  // 6. Verify token
  static Future<bool> verifyToken(String token) async {
    try {
      LoggerService.info('Verifying access token...');
      final response = await http.post(
        Uri.parse('$baseUrl/auth/verify-token'),
        headers: _headers(),
        body: jsonEncode({
          'accessToken': token,
        }),
      );
      final body = jsonDecode(response.body);
      if (response.statusCode == 200 && body['success'] == true) {
        final data = body['data'];
        return data['valid'] == true;
      }
    } catch (e, stack) {
      LoggerService.error('Error verifying token', e, stack);
    }
    return false;
  }

  // 7. Check if username is unique
  static Future<bool> checkUsername(String username) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/user/check-username'),
        headers: _headers(),
        body: jsonEncode({'username': username}),
      );
      final body = jsonDecode(response.body);
      if (response.statusCode == 200 && body['success'] == true) {
        return body['data']['isUnique'] == true;
      }
    } catch (e, stack) {
      LoggerService.error('Error checking username', e, stack);
    }
    return false;
  }

  // 8. Create user profile
  static Future<Map<String, dynamic>?> createProfile({
    required String username,
    required String name,
    required String email,
    required String phoneNumber,
    required String dateOfBirth,
  }) async {
    try {
      LoggerService.info('Creating profile for $username...');
      final response = await http.post(
        Uri.parse('$baseUrl/user/create-profile'),
        headers: _headers(),
        body: jsonEncode({
          'username': username,
          'name': name,
          'email': email,
          'phoneNumber': phoneNumber,
          'dateOfBirth': dateOfBirth,
        }),
      );
      final body = jsonDecode(response.body);
      if ((response.statusCode == 201 || response.statusCode == 200) && body['success'] == true) {
        final data = body['data'];
        final tokens = data['tokens'];
        if (tokens != null) {
          _accessToken = tokens['accessToken'];
          _refreshToken = tokens['refreshToken'];
          await LocalStorageService.setString('@auth/accessToken', _accessToken!);
          await LocalStorageService.setString('@auth/refreshToken', _refreshToken!);
        }
        return data['user'];
      }
      LoggerService.warning('Profile creation failed: ${body['message'] ?? response.body}');
    } catch (e, stack) {
      LoggerService.error('Error creating profile', e, stack);
    }
    return null;
  }

  // 9. Get current user profile
  static Future<Map<String, dynamic>?> getUserProfile() async {
    try {
      LoggerService.info('Fetching user profile...');
      final response = await http.get(
        Uri.parse('$baseUrl/user/profile'),
        headers: _headers(requireAuth: true),
      );
      final body = jsonDecode(response.body);
      if (response.statusCode == 200 && body['success'] == true) {
        return body['data'];
      }
      LoggerService.warning('Get user profile failed: ${body['message'] ?? response.body}');
    } catch (e, stack) {
      LoggerService.error('Error getting user profile', e, stack);
    }
    return null;
  }

  // 10. Update current user profile
  static Future<Map<String, dynamic>?> updateUserProfile({
    required String name,
    required String email,
    required String dateOfBirth,
    required String profilePictureUrl,
  }) async {
    try {
      LoggerService.info('Updating user profile...');
      final response = await http.put(
        Uri.parse('$baseUrl/user/profile'),
        headers: _headers(requireAuth: true),
        body: jsonEncode({
          'name': name,
          'email': email,
          'dateOfBirth': dateOfBirth,
          'profilePictureUrl': profilePictureUrl,
        }),
      );
      final body = jsonDecode(response.body);
      if (response.statusCode == 200 && body['success'] == true) {
        return body['data'];
      }
      LoggerService.warning('Update user profile failed: ${body['message'] ?? response.body}');
    } catch (e, stack) {
      LoggerService.error('Error updating user profile', e, stack);
    }
    return null;
  }

  // 11. Get all categories
  static Future<List<Map<String, dynamic>>?> getCategories() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/category/list'),
        headers: _headers(),
      );
      final body = jsonDecode(response.body);
      if (response.statusCode == 200 && body['success'] == true) {
        final List<dynamic> list = body['data']['categories'];
        return list.map((item) => item as Map<String, dynamic>).toList();
      }
    } catch (e, stack) {
      LoggerService.error('Error fetching categories', e, stack);
    }
    return null;
  }

  // 12. Tag categories to user profile
  static Future<bool> tagCategories(List<String> categoryIds) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/category/tag'),
        headers: _headers(requireAuth: true),
        body: jsonEncode({'categoryIds': categoryIds}),
      );
      final body = jsonDecode(response.body);
      if (response.statusCode == 200 && body['success'] == true) {
        return true;
      }
    } catch (e, stack) {
      LoggerService.error('Error tagging categories', e, stack);
    }
    return false;
  }

  // 13. Get all banks (catalog)
  static Future<List<Map<String, dynamic>>?> getBanks() async {
    try {
      final response = await http.get(
        Uri.parse('$cardsCatalogBaseUrl/banks'),
        headers: _headers(),
      );
      final body = jsonDecode(response.body);
      if (response.statusCode == 200 && body['success'] == true) {
        final List<dynamic> list = body['data'] ?? [];
        return list.map((item) => item as Map<String, dynamic>).toList();
      }
    } catch (e, stack) {
      LoggerService.error('Error fetching banks', e, stack);
    }
    return null;
  }

  // 14. Get cards by bank name (catalog)
  static Future<List<Map<String, dynamic>>?> getCardsByBank(String bankName) async {
    try {
      final response = await http.get(
        Uri.parse('$cardsCatalogBaseUrl/cards?banks=${Uri.encodeComponent(bankName)}&limit=200'),
        headers: _headers(),
      );
      final body = jsonDecode(response.body);
      if (response.statusCode == 200 && body['success'] == true) {
        final List<dynamic> list = body['data'] ?? [];
        return list.map((item) => item as Map<String, dynamic>).toList();
      }
    } catch (e, stack) {
      LoggerService.error('Error fetching cards for bank $bankName', e, stack);
    }
    return null;
  }

  // 15. Add user cards
  static Future<bool> addUserCards(List<Map<String, dynamic>> cards) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/user/cards'),
        headers: _headers(requireAuth: true),
        body: jsonEncode({'cards': cards}),
      );
      if (response.statusCode == 201 || response.statusCode == 200) {
        return true;
      }
    } catch (e, stack) {
      LoggerService.error('Error saving user cards', e, stack);
    }
    return false;
  }

  // 16. Get user saved cards
  static Future<List<Map<String, dynamic>>?> getUserCards() async {
    try {
      LoggerService.info('Fetching saved user cards...');
      final response = await http.get(
        Uri.parse('$baseUrl/user/cards'),
        headers: _headers(requireAuth: true),
      );
      final body = jsonDecode(response.body);
      if (response.statusCode == 200 && body['success'] == true) {
        final List<dynamic> list = body['data'];
        return list.map((item) => item as Map<String, dynamic>).toList();
      }
    } catch (e, stack) {
      LoggerService.error('Error fetching user cards', e, stack);
    }
    return null;
  }

  // 17. Get Dashboard
  static Future<Map<String, dynamic>?> getDashboard() async {
    try {
      LoggerService.info('Fetching dashboard details...');
      final response = await http.get(
        Uri.parse('$baseUrl/dashboard'),
        headers: _headers(requireAuth: true),
      );
      final body = jsonDecode(response.body);
      if (response.statusCode == 200 && body['success'] == true) {
        return body['data'];
      }
    } catch (e, stack) {
      LoggerService.error('Error fetching dashboard', e, stack);
    }
    return null;
  }

  // 18. Sync contacts
  static Future<Map<String, dynamic>?> syncContacts(Map<String, dynamic> payload) async {
    try {
      LoggerService.info('Syncing contacts...');
      final response = await http.post(
        Uri.parse('$baseUrl/user/contacts/sync'),
        headers: _headers(requireAuth: true),
        body: jsonEncode(payload),
      );
      final body = jsonDecode(response.body);
      if (body is Map<String, dynamic>) {
        return body;
      }
    } catch (e, stack) {
      LoggerService.error('Error syncing contacts', e, stack);
    }
    return null;
  }

  // 19. Get contacts directory
  static Future<List<Map<String, dynamic>>?> getContactDirectory() async {
    try {
      LoggerService.info('Fetching matched contacts directory...');
      final response = await http.get(
        Uri.parse('$baseUrl/user/contacts/directory'),
        headers: _headers(requireAuth: true),
      );
      final body = jsonDecode(response.body);
      if (response.statusCode == 200 && body['success'] == true) {
        final List<dynamic> list = body['data'];
        return list.map((item) => item as Map<String, dynamic>).toList();
      }
    } catch (e, stack) {
      LoggerService.error('Error fetching contacts directory', e, stack);
    }
    return null;
  }

  // 20. Delete user cards
  static Future<bool> deleteUserCards(List<String> userCardIds) async {
    try {
      LoggerService.info('Deleting user cards: $userCardIds');
      final response = await http.delete(
        Uri.parse('$baseUrl/user/cards'),
        headers: _headers(requireAuth: true),
        body: jsonEncode({'userCardIds': userCardIds}),
      );
      if (response.statusCode == 200 || response.statusCode == 204) {
        return true;
      }
    } catch (e, stack) {
      LoggerService.error('Error deleting user cards', e, stack);
    }
    return false;
  }

  // 21. Follow user
  static Future<bool> followUser(String recipientId) async {
    try {
      LoggerService.info('Following user $recipientId...');
      final response = await http.post(
        Uri.parse('$baseUrl/follow/requests/recipients/$recipientId'),
        headers: _headers(requireAuth: true),
        body: jsonEncode({
          "message": "Hi, I would like to follow you"
        }),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        final body = jsonDecode(response.body);
        return body['success'] == true;
      }
      LoggerService.warning('Follow user failed: ${response.statusCode} - ${response.body}');
    } catch (e, stack) {
      LoggerService.error('Error following user', e, stack);
    }
    return false;
  }

  // 22. Unfollow user
  static Future<bool> unfollowUser(String recipientId) async {
    try {
      LoggerService.info('Unfollowing user $recipientId...');
      final response = await http.delete(
        Uri.parse('$baseUrl/follow/requests/recipients/$recipientId'),
        headers: _headers(requireAuth: true),
      );
      if (response.statusCode == 200 || response.statusCode == 204) {
        if (response.body.isEmpty) return true;
        final body = jsonDecode(response.body);
        return body['success'] == true;
      }
      LoggerService.warning('Unfollow user failed: ${response.statusCode} - ${response.body}');
    } catch (e, stack) {
      LoggerService.error('Error unfollowing user', e, stack);
    }
    return false;
  }

  // 23. Get incoming follow requests
  static Future<List<Map<String, dynamic>>?> getIncomingFollowRequests() async {
    try {
      LoggerService.info('Fetching incoming follow requests...');
      final response = await http.get(
        Uri.parse('$baseUrl/follow/requests/incoming'),
        headers: _headers(requireAuth: true),
      );
      final body = jsonDecode(response.body);
      if (response.statusCode == 200 && body['success'] == true) {
        final List<dynamic> list = body['data'] ?? [];
        return list.map((item) => item as Map<String, dynamic>).toList();
      }
    } catch (e, stack) {
      LoggerService.error('Error fetching incoming follow requests', e, stack);
    }
    return null;
  }

  // 24. Get outgoing follow requests
  static Future<List<Map<String, dynamic>>?> getOutgoingFollowRequests() async {
    try {
      LoggerService.info('Fetching outgoing follow requests...');
      final response = await http.get(
        Uri.parse('$baseUrl/follow/requests/outgoing'),
        headers: _headers(requireAuth: true),
      );
      final body = jsonDecode(response.body);
      if (response.statusCode == 200 && body['success'] == true) {
        final List<dynamic> list = body['data'] ?? [];
        return list.map((item) => item as Map<String, dynamic>).toList();
      }
    } catch (e, stack) {
      LoggerService.error('Error fetching outgoing follow requests', e, stack);
    }
    return null;
  }

  // 25. Approve follow request
  static Future<bool> approveFollowRequest(String followId, List<String> allowedCardIds) async {
    try {
      LoggerService.info('Approving follow request $followId...');
      final response = await http.post(
        Uri.parse('$baseUrl/follow/requests/$followId/approve'),
        headers: _headers(requireAuth: true),
        body: jsonEncode({
          "allowed_card_ids": allowedCardIds
        }),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        final body = jsonDecode(response.body);
        return body['success'] == true;
      }
      LoggerService.warning('Approve follow request failed: ${response.statusCode} - ${response.body}');
    } catch (e, stack) {
      LoggerService.error('Error approving follow request', e, stack);
    }
    return false;
  }

  // 26. Reject follow request
  static Future<bool> rejectFollowRequest(String followId) async {
    try {
      LoggerService.info('Rejecting follow request $followId...');
      final response = await http.post(
        Uri.parse('$baseUrl/follow/requests/$followId/reject'),
        headers: _headers(requireAuth: true),
        body: jsonEncode({}),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        final body = jsonDecode(response.body);
        return body['success'] == true;
      }
      LoggerService.warning('Reject follow request failed: ${response.statusCode} - ${response.body}');
    } catch (e, stack) {
      LoggerService.error('Error rejecting follow request', e, stack);
    }
    return false;
  }

  // 27. Get followers list
  static Future<List<Map<String, dynamic>>?> getFollowers() async {
    try {
      LoggerService.info('Fetching followers list...');
      final response = await http.get(
        Uri.parse('$baseUrl/follow/followers'),
        headers: _headers(requireAuth: true),
      );
      final body = jsonDecode(response.body);
      if (response.statusCode == 200 && body['success'] == true) {
        final List<dynamic> list = body['data'] ?? [];
        return list.map((item) => item as Map<String, dynamic>).toList();
      }
    } catch (e, stack) {
      LoggerService.error('Error fetching followers list', e, stack);
    }
    return null;
  }

  // 28. Get following list
  static Future<List<Map<String, dynamic>>?> getFollowing() async {
    try {
      LoggerService.info('Fetching following list...');
      final response = await http.get(
        Uri.parse('$baseUrl/follow/following'),
        headers: _headers(requireAuth: true),
      );
      final body = jsonDecode(response.body);
      if (response.statusCode == 200 && body['success'] == true) {
        final List<dynamic> list = body['data'] ?? [];
        return list.map((item) => item as Map<String, dynamic>).toList();
      }
    } catch (e, stack) {
      LoggerService.error('Error fetching following list', e, stack);
    }
    return null;
  }

  // 29. Get My Hacks
  static Future<List<Map<String, dynamic>>?> getMyHacks() async {
    try {
      LoggerService.info('Fetching My Hacks...');
      final response = await http.get(
        Uri.parse('$baseUrl/hacks/getmyhacks'),
        headers: _headers(),
      );
      final body = jsonDecode(response.body);
      if (response.statusCode == 200 && body['success'] == true) {
        final List<dynamic> list = body['hacks'] ?? [];
        return list.map((item) => item as Map<String, dynamic>).toList();
      }
      LoggerService.warning('getMyHacks failed: ${response.statusCode} - ${response.body}');
    } catch (e, stack) {
      LoggerService.error('Error fetching My Hacks', e, stack);
    }
    return null;
  }

  // 30. Get Circle Hacks
  static Future<List<Map<String, dynamic>>?> getCircleHacks() async {
    try {
      LoggerService.info('Fetching Circle Hacks...');
      final response = await http.get(
        Uri.parse('$baseUrl/hacks/getcirclehacks'),
        headers: _headers(),
      );
      final body = jsonDecode(response.body);
      if (response.statusCode == 200 && body['success'] == true) {
        final List<dynamic> list = body['hacks'] ?? [];
        return list.map((item) => item as Map<String, dynamic>).toList();
      }
      LoggerService.warning('getCircleHacks failed: ${response.statusCode} - ${response.body}');
    } catch (e, stack) {
      LoggerService.error('Error fetching Circle Hacks', e, stack);
    }
    return null;
  }

  // 31. Get FAQ from Hack ID
  static Future<List<Map<String, dynamic>>?> getFaqFromHackId(String hackId) async {
    try {
      LoggerService.info('Fetching FAQs for hack $hackId...');
      final response = await http.get(
        Uri.parse('$baseUrl/hacks/getfaqfromhackid/$hackId'),
        headers: _headers(),
      );
      final body = jsonDecode(response.body);
      if (response.statusCode == 200 && body['success'] == true) {
        final List<dynamic> list = body['faqlist'] ?? [];
        return list.map((item) => item as Map<String, dynamic>).toList();
      }
      LoggerService.warning('getFaqFromHackId failed: ${response.statusCode} - ${response.body}');
    } catch (e, stack) {
      LoggerService.error('Error fetching FAQs for hack $hackId', e, stack);
    }
    return null;
  }

  // 32. Register Push Token
  static Future<bool> registerPushToken({
    required String token,
    String deviceType = 'ANDROID',
    String deviceName = 'Test Device',
  }) async {
    try {
      LoggerService.info('Registering push token...');
      final response = await http.post(
        Uri.parse('$baseUrl/push/tokens/register'),
        headers: _headers(requireAuth: true),
        body: jsonEncode({
          'token': token,
          'device_type': deviceType,
          'device_name': deviceName,
        }),
      );
      final body = jsonDecode(response.body);
      if (response.statusCode == 200 && body['success'] == true) {
        LoggerService.info('Push token registered successfully.');
        return true;
      }
      LoggerService.warning('Push token registration failed: ${response.statusCode} - ${response.body}');
    } catch (e, stack) {
      LoggerService.error('Error registering push token', e, stack);
    }
    return false;
  }

  // 33. Get Push Notifications
  static Future<List<Map<String, dynamic>>?> getNotifications() async {
    try {
      LoggerService.info('Fetching push notifications...');
      final response = await http.get(
        Uri.parse('$baseUrl/push/notifications'),
        headers: _headers(requireAuth: true),
      );
      final body = jsonDecode(response.body);
      if (response.statusCode == 200 && body['success'] == true) {
        final List<dynamic> list = body['data'] ?? body['notifications'] ?? [];
        return list.map((item) => item as Map<String, dynamic>).toList();
      }
      LoggerService.warning('getNotifications failed: ${response.statusCode} - ${response.body}');
    } catch (e, stack) {
      LoggerService.error('Error fetching push notifications', e, stack);
    }
    return null;
  }

  static Future<void> logout() async {
    _accessToken = null;
    _refreshToken = null;
    await LocalStorageService.remove('@auth/accessToken');
    await LocalStorageService.remove('@auth/refreshToken');
  }
}
