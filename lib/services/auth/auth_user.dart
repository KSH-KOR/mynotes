import 'package:firebase_auth/firebase_auth.dart' as FirebaseAuth show User;
import 'package:flutter/foundation.dart';

@immutable
class AuthUser {
  final bool isEmailVerified;
  const AuthUser(this.isEmailVerified);

  // create authuser from firebase user
  factory AuthUser.fromFirebase(FirebaseAuth.User user) => AuthUser(user.emailVerified);
}