enum PlayerAvatarType {
  preset,
  photo,
}

class PlayerProfile {
  final String name;
  final String avatarSeed;
  final String avatarPath;
  final PlayerAvatarType avatarType;
  final bool isOnboardingCompleted;

  const PlayerProfile({
    required this.name,
    required this.avatarSeed,
    required this.avatarPath,
    required this.avatarType,
    required this.isOnboardingCompleted,
  });

  factory PlayerProfile.empty() {
    return const PlayerProfile(
      name: '',
      avatarSeed: 'card',
      avatarPath: '',
      avatarType: PlayerAvatarType.preset,
      isOnboardingCompleted: false,
    );
  }

  String get displayName {
    final trimmed = name.trim();
    return trimmed.isEmpty ? 'Игрок' : trimmed;
  }

  PlayerProfile copyWith({
    String? name,
    String? avatarSeed,
    String? avatarPath,
    PlayerAvatarType? avatarType,
    bool? isOnboardingCompleted,
  }) {
    return PlayerProfile(
      name: name ?? this.name,
      avatarSeed: avatarSeed ?? this.avatarSeed,
      avatarPath: avatarPath ?? this.avatarPath,
      avatarType: avatarType ?? this.avatarType,
      isOnboardingCompleted:
          isOnboardingCompleted ?? this.isOnboardingCompleted,
    );
  }
}