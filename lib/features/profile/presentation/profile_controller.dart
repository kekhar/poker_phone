import 'package:flutter/foundation.dart';
import 'package:poker_phone/features/profile/data/player_profile_storage.dart';
import 'package:poker_phone/features/profile/domain/player_profile.dart';

class ProfileController extends ChangeNotifier {
  final PlayerProfileStorage profileStorage;

  PlayerProfile _profile;
  bool _isSaving = false;

  ProfileController({
    required this.profileStorage,
    required PlayerProfile initialProfile,
  }) : _profile = initialProfile;

  PlayerProfile get profile => _profile;

  bool get isSaving => _isSaving;

  Future<void> saveProfile({
    required String name,
    required PlayerAvatarType avatarType,
    String avatarSeed = 'spade',
    String avatarPath = '',
    bool completeOnboarding = false,
  }) async {
    final updatedProfile = _profile.copyWith(
      name: name.trim(),
      avatarSeed: avatarSeed,
      avatarPath: avatarPath,
      avatarType: avatarType,
      isOnboardingCompleted:
          completeOnboarding ? true : _profile.isOnboardingCompleted,
    );

    _isSaving = true;
    notifyListeners();

    try {
      await profileStorage.save(updatedProfile);
      _profile = updatedProfile;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }
}