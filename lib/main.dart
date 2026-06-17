import 'package:flutter/material.dart';
import 'package:poker_phone/app/poker_phone_app.dart';
import 'package:poker_phone/features/profile/data/player_profile_storage.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(
    PokerPhoneApp(
      profileStorage: PlayerProfileStorage(),
    ),
  );
}