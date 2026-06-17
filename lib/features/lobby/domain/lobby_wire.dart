import 'dart:convert';

import 'package:poker_phone/features/lobby/domain/lobby_session.dart';
import 'package:poker_phone/features/lobby/domain/lobby_settings.dart';
import 'package:poker_phone/features/lobby/domain/player_identity.dart';
import 'package:poker_phone/features/profile/domain/player_profile.dart';

Map<String, dynamic> playerIdentityToJson(PlayerIdentity player) {
  return {
    'displayName': player.displayName,
    'avatarSeed': player.avatarSeed,
    'avatarPath': player.avatarPath,
    'avatarType': player.avatarType.name,
    'avatarBytes': player.avatarBytes == null
        ? null
        : base64Encode(player.avatarBytes!),
  };
}

PlayerIdentity playerIdentityFromJson(Map<String, dynamic> json) {
  final avatarBytesEncoded = json['avatarBytes'] as String?;
  return PlayerIdentity(
    displayName: json['displayName'] as String? ?? 'Игрок',
    avatarSeed: json['avatarSeed'] as String? ?? 'spade',
    avatarPath: json['avatarPath'] as String? ?? '',
    avatarType: _avatarTypeFromName(json['avatarType'] as String?),
    avatarBytes: avatarBytesEncoded == null || avatarBytesEncoded.isEmpty
        ? null
        : base64Decode(avatarBytesEncoded),
  );
}

Map<String, dynamic> lobbySettingsToJson(LobbySettings settings) {
  return {
    'lobbyName': settings.lobbyName,
    'startingChips': settings.startingChips,
    'smallBlind': settings.smallBlind,
    'bigBlind': settings.bigBlind,
    'seatsCount': settings.seatsCount,
    'host': playerIdentityToJson(settings.host),
  };
}

LobbySettings lobbySettingsFromJson(Map<String, dynamic> json) {
  return LobbySettings(
    lobbyName: json['lobbyName'] as String? ?? '',
    startingChips: (json['startingChips'] as num?)?.toInt() ?? 1000,
    smallBlind: (json['smallBlind'] as num?)?.toInt() ?? 10,
    bigBlind: (json['bigBlind'] as num?)?.toInt() ?? 20,
    seatsCount: (json['seatsCount'] as num?)?.toInt() ?? 6,
    host: playerIdentityFromJson(
      Map<String, dynamic>.from(json['host'] as Map),
    ),
  );
}

Map<String, dynamic> lobbyPlayerEntryToJson(LobbyPlayerEntry entry) {
  return {
    'identity': playerIdentityToJson(entry.identity),
    'chips': entry.chips,
    'isHost': entry.isHost,
  };
}

LobbyPlayerEntry lobbyPlayerEntryFromJson(Map<String, dynamic> json) {
  return LobbyPlayerEntry(
    identity: playerIdentityFromJson(
      Map<String, dynamic>.from(json['identity'] as Map),
    ),
    chips: (json['chips'] as num?)?.toInt() ?? 1000,
    isHost: json['isHost'] as bool? ?? false,
  );
}

Map<String, dynamic> lobbySessionToJson(
  LobbySession session, {
  String? hostAddress,
  int? hostPort,
}) {
  return {
    'id': session.id,
    'settings': lobbySettingsToJson(session.settings),
    'players': session.players.map(lobbyPlayerEntryToJson).toList(),
    'observers': session.observers.map(playerIdentityToJson).toList(),
    'isStarted': session.isStarted,
    'countdownEndsAt': session.countdownEndsAt?.toUtc().toIso8601String(),
    'demoScenarioIndex': session.demoScenarioIndex,
    'pendingObserverKeys': session.pendingObserverKeys,
    'pendingPlayerKeys': session.pendingPlayerKeys,
    'gameState': session.gameState == null
        ? null
        : pokerGameStateToJson(session.gameState!),
    'hostAddress': hostAddress,
    'hostPort': hostPort,
  };
}

LobbySession lobbySessionFromJson(Map<String, dynamic> json) {
  final playersJson = (json['players'] as List<dynamic>? ?? const [])
      .map((item) => Map<String, dynamic>.from(item as Map))
      .toList();
  final observersJson = (json['observers'] as List<dynamic>? ?? const [])
      .map((item) => Map<String, dynamic>.from(item as Map))
      .toList();

  return LobbySession(
    id: json['id'] as String? ?? '',
    settings: lobbySettingsFromJson(
      Map<String, dynamic>.from(json['settings'] as Map),
    ),
    players: playersJson.map(lobbyPlayerEntryFromJson).toList(),
    observers: observersJson.map(playerIdentityFromJson).toList(),
    isStarted: json['isStarted'] as bool? ?? false,
    countdownEndsAt: _dateTimeFromWire(json['countdownEndsAt'] as String?),
    demoScenarioIndex: (json['demoScenarioIndex'] as num?)?.toInt() ?? 0,
    pendingObserverKeys:
        (json['pendingObserverKeys'] as List<dynamic>? ?? const [])
            .map((item) => item.toString())
            .toList(),
    pendingPlayerKeys:
        (json['pendingPlayerKeys'] as List<dynamic>? ?? const [])
            .map((item) => item.toString())
            .toList(),
    gameState: json['gameState'] is Map
        ? pokerGameStateFromJson(Map<String, dynamic>.from(json['gameState'] as Map))
        : null,
  );
}

Map<String, dynamic> pokerGameStateToJson(PokerGameState state) {
  return {
    'street': state.street,
    'pot': state.pot,
    'currentBet': state.currentBet,
    'dealerKey': state.dealerKey,
    'activePlayerKey': state.activePlayerKey,
    'turnEndsAt': state.turnEndsAt?.toUtc().toIso8601String(),
    'isShowdown': state.isShowdown,
    'showdownEndsAt': state.showdownEndsAt?.toUtc().toIso8601String(),
    'winnerKey': state.winnerKey,
    'winnerLabel': state.winnerLabel,
    'players': state.players.map(pokerGamePlayerStateToJson).toList(),
    'communityCards': state.communityCards.map(pokerCardStateToJson).toList(),
  };
}

PokerGameState pokerGameStateFromJson(Map<String, dynamic> json) {
  final playersJson = (json['players'] as List<dynamic>? ?? const [])
      .map((item) => Map<String, dynamic>.from(item as Map))
      .toList();
  final cardsJson = (json['communityCards'] as List<dynamic>? ?? const [])
      .map((item) => Map<String, dynamic>.from(item as Map))
      .toList();

  return PokerGameState(
    street: json['street'] as String? ?? 'preflop',
    pot: (json['pot'] as num?)?.toInt() ?? 0,
    currentBet: (json['currentBet'] as num?)?.toInt() ?? 0,
    dealerKey: json['dealerKey'] as String? ?? '',
    activePlayerKey: json['activePlayerKey'] as String? ?? '',
    turnEndsAt: _dateTimeFromWire(json['turnEndsAt'] as String?),
    isShowdown: json['isShowdown'] as bool? ?? false,
    showdownEndsAt: _dateTimeFromWire(json['showdownEndsAt'] as String?),
    winnerKey: json['winnerKey'] as String? ?? '',
    winnerLabel: json['winnerLabel'] as String? ?? '',
    players: playersJson.map(pokerGamePlayerStateFromJson).toList(),
    communityCards: cardsJson.map(pokerCardStateFromJson).toList(),
  );
}

Map<String, dynamic> pokerGamePlayerStateToJson(PokerGamePlayerState state) {
  return {
    'playerKey': state.playerKey,
    'chips': state.chips,
    'isFolded': state.isFolded,
    'isDealer': state.isDealer,
    'streetContribution': state.streetContribution,
    'handContribution': state.handContribution,
    'lastAction': state.lastAction,
    'isRevealed': state.isRevealed,
    'holeCards': state.holeCards.map(pokerCardStateToJson).toList(),
  };
}

PokerGamePlayerState pokerGamePlayerStateFromJson(Map<String, dynamic> json) {
  final cardsJson = (json['holeCards'] as List<dynamic>? ?? const [])
      .map((item) => Map<String, dynamic>.from(item as Map))
      .toList();
  return PokerGamePlayerState(
    playerKey: json['playerKey'] as String? ?? '',
    chips: (json['chips'] as num?)?.toInt() ?? 0,
    isFolded: json['isFolded'] as bool? ?? false,
    isDealer: json['isDealer'] as bool? ?? false,
    streetContribution: (json['streetContribution'] as num?)?.toInt() ?? 0,
    handContribution: (json['handContribution'] as num?)?.toInt() ?? 0,
    lastAction: json['lastAction'] as String? ?? '',
    isRevealed: json['isRevealed'] as bool? ?? false,
    holeCards: cardsJson.map(pokerCardStateFromJson).toList(),
  );
}

Map<String, dynamic> pokerCardStateToJson(PokerCardState card) {
  return {'rank': card.rank, 'suit': card.suit};
}

PokerCardState pokerCardStateFromJson(Map<String, dynamic> json) {
  return PokerCardState(
    rank: json['rank'] as String? ?? '',
    suit: json['suit'] as String? ?? '',
  );
}

DateTime? _dateTimeFromWire(String? value) {
  if (value == null || value.isEmpty) {
    return null;
  }

  return DateTime.tryParse(value)?.toLocal();
}

PlayerAvatarType _avatarTypeFromName(String? name) {
  for (final value in PlayerAvatarType.values) {
    if (value.name == name) {
      return value;
    }
  }

  return PlayerAvatarType.preset;
}
