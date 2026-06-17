import 'package:poker_phone/features/lobby/domain/player_identity.dart';

class LobbySettings {
  final String lobbyName;
  final int startingChips;
  final int smallBlind;
  final int bigBlind;
  final int seatsCount;
  final PlayerIdentity host;

  const LobbySettings({
    required this.lobbyName,
    required this.startingChips,
    required this.smallBlind,
    required this.bigBlind,
    required this.seatsCount,
    required this.host,
  });

  String get displayLobbyName {
    final trimmed = lobbyName.trim();
    return trimmed.isEmpty ? '${host.displayName} table' : trimmed;
  }

  LobbySettings copyWith({
    String? lobbyName,
    int? startingChips,
    int? smallBlind,
    int? bigBlind,
    int? seatsCount,
    PlayerIdentity? host,
  }) {
    return LobbySettings(
      lobbyName: lobbyName ?? this.lobbyName,
      startingChips: startingChips ?? this.startingChips,
      smallBlind: smallBlind ?? this.smallBlind,
      bigBlind: bigBlind ?? this.bigBlind,
      seatsCount: seatsCount ?? this.seatsCount,
      host: host ?? this.host,
    );
  }
}
