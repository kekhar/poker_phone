import 'dart:io';
import 'dart:typed_data';

import 'package:poker_phone/features/profile/domain/player_profile.dart';

class PlayerIdentity {
  final String displayName;
  final String avatarSeed;
  final String avatarPath;
  final PlayerAvatarType avatarType;
  final Uint8List? avatarBytes;

  const PlayerIdentity({
    required this.displayName,
    required this.avatarSeed,
    required this.avatarPath,
    required this.avatarType,
    this.avatarBytes,
  });

  String get stableKey => '$displayName|$avatarSeed|$avatarPath|$avatarType';

  factory PlayerIdentity.fromProfile(
    PlayerProfile profile, {
    Uint8List? avatarBytes,
  }) {
    Uint8List? resolvedBytes = avatarBytes;
    if (resolvedBytes == null &&
        profile.avatarType == PlayerAvatarType.photo &&
        profile.avatarPath.trim().isNotEmpty) {
      final file = File(profile.avatarPath);
      if (file.existsSync()) {
        try {
          resolvedBytes = file.readAsBytesSync();
        } catch (_) {
          resolvedBytes = null;
        }
      }
    }

    return PlayerIdentity(
      displayName: profile.displayName,
      avatarSeed: profile.avatarSeed,
      avatarPath: profile.avatarPath,
      avatarType: profile.avatarType,
      avatarBytes: resolvedBytes,
    );
  }

  PlayerIdentity copyWith({
    String? displayName,
    String? avatarSeed,
    String? avatarPath,
    PlayerAvatarType? avatarType,
    Uint8List? avatarBytes,
  }) {
    return PlayerIdentity(
      displayName: displayName ?? this.displayName,
      avatarSeed: avatarSeed ?? this.avatarSeed,
      avatarPath: avatarPath ?? this.avatarPath,
      avatarType: avatarType ?? this.avatarType,
      avatarBytes: avatarBytes ?? this.avatarBytes,
    );
  }
}
