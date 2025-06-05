import 'auth_service.dart';
import 'database_service.dart';
import '../models/user.dart';

class ProfileService {
  static final ProfileService _instance = ProfileService._internal();
  final DatabaseService _db = DatabaseService();
  factory ProfileService() => _instance;
  ProfileService._internal();

  Future<bool> updateProfile({
    String? username,
    String? email,
    String? profilePicPath,
  }) async {
    try {
      final User? user = AuthService().currentUser;
      if (user == null) return false;

      final oldUsername = user.username;
      bool usernameChanged = false;

      if (username != null && username != oldUsername) {
        if (_db.userBox.containsKey(username)) {
          throw Exception('Username already exists');
        }
        usernameChanged = true;
        user.username = username;
      }

      if (email != null) {
        user.email = email;
      }

      if (profilePicPath != null) {
        user.profilePicPath = profilePicPath;
      }

      if (usernameChanged) {
        // Update in database with new username key
        await _db.userBox.delete(oldUsername);
        await _db.userBox.put(username!, user);

        // Update related data
        final gameStats = _db.gameStatsBox.get(oldUsername);
        if (gameStats != null) {
          await _db.gameStatsBox.delete(oldUsername);
          await _db.gameStatsBox.put(username, gameStats);
        }
      } else {
        // Just save the updated user data
        await user.save();
      }

      return true;
    } catch (e) {
      rethrow;
    }
  }
}
