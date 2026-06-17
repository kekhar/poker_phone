import 'package:poker_phone/features/profile/domain/player_profile.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PlayerProfileStorage {
  static const String _nameKey = 'player_profile.name';
  static const String _avatarSeedKey = 'player_profile.avatar_seed';
  static const String _avatarPathKey = 'player_profile.avatar_path';
  static const String _avatarTypeKey = 'player_profile.avatar_type';
  static const String _onboardingKey = 'player_profile.onboarding_completed';

  Future<PlayerProfile> load() async {
    final prefs = await SharedPreferences.getInstance();

    final avatarTypeRaw = prefs.getString(_avatarTypeKey) ?? 'preset';

    return PlayerProfile(
      name: (prefs.getString(_nameKey) ?? '').trim(),
      avatarSeed: prefs.getString(_avatarSeedKey) ?? 'card',
      avatarPath: prefs.getString(_avatarPathKey) ?? '',
      avatarType: avatarTypeRaw == 'photo'
          ? PlayerAvatarType.photo
          : PlayerAvatarType.preset,
      isOnboardingCompleted: prefs.getBool(_onboardingKey) ?? false,
    );
  }

  Future<void> save(PlayerProfile profile) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(_nameKey, profile.name.trim());
    await prefs.setString(_avatarSeedKey, profile.avatarSeed);
    await prefs.setString(_avatarPathKey, profile.avatarPath);
    await prefs.setString(
      _avatarTypeKey,
      profile.avatarType == PlayerAvatarType.photo ? 'photo' : 'preset',
    );
    await prefs.setBool(_onboardingKey, profile.isOnboardingCompleted);
  }
}