import 'package:poker_phone/features/lobby/domain/lobby_settings.dart';
import 'package:poker_phone/features/lobby/domain/player_identity.dart';

class LobbyPlayerEntry {
  final PlayerIdentity identity;
  final int chips;
  final bool isHost;

  const LobbyPlayerEntry({
    required this.identity,
    required this.chips,
    required this.isHost,
  });

  LobbyPlayerEntry copyWith({
    PlayerIdentity? identity,
    int? chips,
    bool? isHost,
  }) {
    return LobbyPlayerEntry(
      identity: identity ?? this.identity,
      chips: chips ?? this.chips,
      isHost: isHost ?? this.isHost,
    );
  }
}

class LobbySession {
  final String id;
  final LobbySettings settings;
  final List<LobbyPlayerEntry> players;
  final List<PlayerIdentity> observers;
  final bool isStarted;
  final DateTime? countdownEndsAt;
  final int demoScenarioIndex;
  final List<String> pendingObserverKeys;
  final List<String> pendingPlayerKeys;
  final PokerGameState? gameState;

  const LobbySession({
    required this.id,
    required this.settings,
    required this.players,
    required this.observers,
    required this.isStarted,
    required this.countdownEndsAt,
    required this.demoScenarioIndex,
    required this.pendingObserverKeys,
    required this.pendingPlayerKeys,
    required this.gameState,
  });

  int get connectedPlayersCount => players.length;
  int get observersCount => observers.length;
  bool get isCountingDown => countdownEndsAt != null && !isStarted;

  bool get hasFreeSeats => connectedPlayersCount < settings.seatsCount;

  LobbySession copyWith({
    String? id,
    LobbySettings? settings,
    List<LobbyPlayerEntry>? players,
    List<PlayerIdentity>? observers,
    bool? isStarted,
    DateTime? countdownEndsAt,
    bool clearCountdownEndsAt = false,
    int? demoScenarioIndex,
    List<String>? pendingObserverKeys,
    List<String>? pendingPlayerKeys,
    PokerGameState? gameState,
    bool clearGameState = false,
  }) {
    return LobbySession(
      id: id ?? this.id,
      settings: settings ?? this.settings,
      players: players ?? this.players,
      observers: observers ?? this.observers,
      isStarted: isStarted ?? this.isStarted,
      countdownEndsAt: clearCountdownEndsAt
          ? null
          : countdownEndsAt ?? this.countdownEndsAt,
      demoScenarioIndex: demoScenarioIndex ?? this.demoScenarioIndex,
      pendingObserverKeys: pendingObserverKeys ?? this.pendingObserverKeys,
      pendingPlayerKeys: pendingPlayerKeys ?? this.pendingPlayerKeys,
      gameState: clearGameState ? null : gameState ?? this.gameState,
    );
  }
}

class PokerGameState {
  final String street;
  final int pot;
  final int currentBet;
  final String dealerKey;
  final String activePlayerKey;
  final DateTime? turnEndsAt;
  final bool isShowdown;
  final DateTime? showdownEndsAt;
  final String winnerKey;
  final String winnerLabel;
  final List<PokerGamePlayerState> players;
  final List<PokerCardState> communityCards;

  const PokerGameState({
    required this.street,
    required this.pot,
    required this.currentBet,
    required this.dealerKey,
    required this.activePlayerKey,
    required this.turnEndsAt,
    required this.isShowdown,
    required this.showdownEndsAt,
    required this.winnerKey,
    required this.winnerLabel,
    required this.players,
    required this.communityCards,
  });

  PokerGameState copyWith({
    String? street,
    int? pot,
    int? currentBet,
    String? dealerKey,
    String? activePlayerKey,
    DateTime? turnEndsAt,
    bool clearTurnEndsAt = false,
    bool? isShowdown,
    DateTime? showdownEndsAt,
    bool clearShowdownEndsAt = false,
    String? winnerKey,
    String? winnerLabel,
    List<PokerGamePlayerState>? players,
    List<PokerCardState>? communityCards,
  }) {
    return PokerGameState(
      street: street ?? this.street,
      pot: pot ?? this.pot,
      currentBet: currentBet ?? this.currentBet,
      dealerKey: dealerKey ?? this.dealerKey,
      activePlayerKey: activePlayerKey ?? this.activePlayerKey,
      turnEndsAt: clearTurnEndsAt ? null : turnEndsAt ?? this.turnEndsAt,
      isShowdown: isShowdown ?? this.isShowdown,
      showdownEndsAt: clearShowdownEndsAt
          ? null
          : showdownEndsAt ?? this.showdownEndsAt,
      winnerKey: winnerKey ?? this.winnerKey,
      winnerLabel: winnerLabel ?? this.winnerLabel,
      players: players ?? this.players,
      communityCards: communityCards ?? this.communityCards,
    );
  }
}

class PokerGamePlayerState {
  final String playerKey;
  final int chips;
  final bool isFolded;
  final bool isDealer;
  final int streetContribution;
  final int handContribution;
  final String lastAction;
  final bool isRevealed;
  final List<PokerCardState> holeCards;

  const PokerGamePlayerState({
    required this.playerKey,
    required this.chips,
    required this.isFolded,
    required this.isDealer,
    required this.streetContribution,
    required this.handContribution,
    required this.lastAction,
    required this.isRevealed,
    required this.holeCards,
  });

  PokerGamePlayerState copyWith({
    String? playerKey,
    int? chips,
    bool? isFolded,
    bool? isDealer,
    int? streetContribution,
    int? handContribution,
    String? lastAction,
    bool? isRevealed,
    List<PokerCardState>? holeCards,
  }) {
    return PokerGamePlayerState(
      playerKey: playerKey ?? this.playerKey,
      chips: chips ?? this.chips,
      isFolded: isFolded ?? this.isFolded,
      isDealer: isDealer ?? this.isDealer,
      streetContribution: streetContribution ?? this.streetContribution,
      handContribution: handContribution ?? this.handContribution,
      lastAction: lastAction ?? this.lastAction,
      isRevealed: isRevealed ?? this.isRevealed,
      holeCards: holeCards ?? this.holeCards,
    );
  }
}

class PokerCardState {
  final String rank;
  final String suit;

  const PokerCardState({required this.rank, required this.suit});
}
