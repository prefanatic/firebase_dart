import 'dart:async';
import 'dart:convert';

import 'package:firebase_dart/src/auth/auth.dart';
import 'package:firebase_dart/src/auth/impl/auth.dart';
import 'package:firebase_dart/src/auth/user.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'impl/user.dart';

/// Defines the Auth user storage manager.
///
/// It provides methods to store, load and delete an authenticated current user.
/// It also provides methods to listen to external user changes (updates, sign
/// in, sign out, etc.)
class UserManager {
  final FirebaseAuthImpl auth;

  /// The Auth state's application ID
  String get appId => auth.app.options.appId;

  /// The underlying storage manager.
  late SharedPreferences _prefs;

  final StreamController<FirebaseUserImpl?> _controller =
      StreamController.broadcast();

  Timer? _pollTimer;

  Future<void>? _onReady;

  Future<void>? get onReady => _onReady;

  Stream<FirebaseUserImpl?> get onCurrentUserChanged => _controller.stream;

  UserManager(this.auth) {
    _onReady = _init();
  }

  Future<void> _init() async {
    _prefs = await SharedPreferences.getInstance();

    // Since SharedPreferences doesn't have native watching capabilities,
    // we'll use polling to detect changes.
    _startPolling();
  }

  void _startPolling() {
    FirebaseUserImpl? lastUser;

    _pollTimer = Timer.periodic(Duration(milliseconds: 500), (timer) async {
      try {
        final currentUser = await _getCurrentUserFromStorage();

        // Only emit if user actually changed
        if (_usersAreDifferent(lastUser, currentUser)) {
          lastUser = currentUser;
          _controller.add(currentUser);
        }
      } catch (e) {
        // Handle errors silently or log them
      }
    });
  }

  bool _usersAreDifferent(FirebaseUserImpl? user1, FirebaseUserImpl? user2) {
    if (user1 == null && user2 == null) return false;
    if (user1 == null || user2 == null) return true;
    return user1.uid != user2.uid;
  }

  String get _key => 'firebase_auth_user_$appId';

  /// Stores the current Auth user for the provided application ID.
  Future<void> setCurrentUser(User? currentUser) async {
    await onReady;

    if (currentUser == null) {
      await _prefs.remove(_key);
    } else {
      final jsonString = jsonEncode(currentUser.toJson());
      await _prefs.setString(_key, jsonString);
    }
  }

  /// Removes the stored current user for provided app ID.
  Future<void> removeCurrentUser() async {
    await onReady;
    await _prefs.remove(_key);
  }

  Future<FirebaseUserImpl?> getCurrentUser([String? authDomain]) async {
    await onReady;
    return _getCurrentUserFromStorage(authDomain);
  }

  Future<FirebaseUserImpl?> _getCurrentUserFromStorage(
      [String? authDomain]) async {
    final jsonString = _prefs.getString(_key);

    if (jsonString == null) return null;

    try {
      final Map<String, dynamic> userData = jsonDecode(jsonString);

      return FirebaseUserImpl.fromJson({
        ...userData,
        if (authDomain != null) 'authDomain': authDomain,
      }, auth: auth);
    } catch (e) {
      // If JSON is corrupted, remove it and return null
      await _prefs.remove(_key);
      return null;
    }
  }

  Future<void> close() async {
    await onReady;
    _pollTimer?.cancel();
    await _controller.close();
  }
}
