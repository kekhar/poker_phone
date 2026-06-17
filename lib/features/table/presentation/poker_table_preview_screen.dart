import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:poker_phone/app/app_theme.dart';
import 'package:poker_phone/core/widgets/app_toast.dart';
import 'package:poker_phone/core/widgets/player_avatar.dart';
import 'package:poker_phone/features/lobby/domain/lobby_session.dart';
import 'package:poker_phone/features/lobby/domain/player_identity.dart';
import 'package:poker_phone/features/lobby/presentation/lobby_controller.dart';
import 'package:poker_phone/features/profile/domain/player_profile.dart';
import 'package:poker_phone/features/profile/presentation/profile_controller.dart';
import 'package:poker_phone/features/table/domain/poker_hand_evaluator.dart';
import 'package:poker_phone/features/table/presentation/widgets/playing_card_view.dart';
import 'package:poker_phone/features/table/presentation/widgets/poker_table_surface.dart';
import 'package:poker_phone/features/table/presentation/widgets/table_action_bar.dart';
import 'package:poker_phone/features/table/presentation/widgets/table_player_seat.dart';
import 'package:qr_flutter/qr_flutter.dart';

class PokerTablePreviewScreen extends StatefulWidget {
  final ProfileController profileController;
  final LobbyController? lobbyController;
  final String? lobbyId;

  const PokerTablePreviewScreen({
    super.key,
    required this.profileController,
    this.lobbyController,
    this.lobbyId,
  });

  @override
  State<PokerTablePreviewScreen> createState() =>
      _PokerTablePreviewScreenState();
}

class _PokerTablePreviewScreenState extends State<PokerTablePreviewScreen> {
  bool _didLeaveLobby = false;

  bool get _isLobbyMode =>
      widget.lobbyController != null && widget.lobbyId != null;

  @override
  void initState() {
    super.initState();
    _enterLandscape();
  }

  Future<void> _enterLandscape() async {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    if (_isLobbyMode && !_didLeaveLobby) {
      _didLeaveLobby = true;
      unawaited(
        widget.lobbyController!.leaveLobby(
          widget.lobbyId!,
          PlayerIdentity.fromProfile(widget.profileController.profile),
        ),
      );
    }
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  void _showDemoAction(String action) {
    showAppToast(
      context,
      message: '$action пока в демо-режиме',
      type: AppToastType.info,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLobbyMode) {
      return ListenableBuilder(
        listenable: widget.lobbyController!,
        builder: (context, _) {
          final lobby = widget.lobbyController!.lobbyById(widget.lobbyId!);
          if (lobby == null) {
            return Scaffold(
              backgroundColor: AppTheme.background,
              body: Center(
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Лобби не найдено'),
                ),
              ),
            );
          }

          return _TableScene(
            profileController: widget.profileController,
            lobbyController: widget.lobbyController,
            lobby: lobby,
            onDemoAction: _showDemoAction,
          );
        },
      );
    }

    return _TrainingTableScene(
      profileController: widget.profileController,
    );
  }
}

class _TableScene extends StatelessWidget {
  final ProfileController profileController;
  final LobbyController? lobbyController;
  final LobbySession? lobby;
  final ValueChanged<String> onDemoAction;

  const _TableScene({
    required this.profileController,
    required this.onDemoAction,
    this.lobbyController,
    this.lobby,
  });

  bool get _isLobbyMode => lobby != null;

  bool get _isGameStarted => lobby?.isStarted ?? true;
  bool get _isStarting => lobby?.isCountingDown ?? false;
  PokerGameState? get _networkGame => lobby?.gameState;
  PokerGamePlayerState? get _heroNetworkState =>
      _networkPlayerState(_currentPlayerKey);
  bool get _isNetworkShowdown => _networkGame?.isShowdown ?? false;
  bool get _isHeroTurn =>
      _networkGame != null &&
      !_isNetworkShowdown &&
      _networkGame!.activePlayerKey == _currentPlayerKey;
  bool get _canRevealHeroHand =>
      _isNetworkShowdown && _heroNetworkState?.isRevealed != true;

  String get _currentPlayerKey {
    final current = profileController.profile;
    return '${current.displayName}|${current.avatarSeed}|${current.avatarPath}|${current.avatarType}';
  }

  PlayerIdentity get _currentIdentity =>
      PlayerIdentity.fromProfile(profileController.profile);

  String? get _qrPayload {
    if (!_isLobbyMode) {
      return null;
    }

    final hostAddress = lobbyController?.hostAddress;
    if (hostAddress == null || hostAddress.isEmpty) {
      return null;
    }

    return jsonEncode({
      'type': 'poker_phone_join',
      'host': hostAddress,
      'port': lobbyController?.hostPort ?? LobbyController.defaultPort,
      'lobbyId': lobby!.id,
    });
  }

  String? get _hostShareWarning => lobbyController?.hostAddressWarning;

  bool get _isHost {
    return lobby?.settings.host.stableKey == _currentPlayerKey;
  }

  bool get _isObserver {
    if (!_isLobbyMode) {
      return false;
    }

    return lobby!.observers.any(
      (observer) => observer.stableKey == _currentPlayerKey,
    );
  }

  bool get _isObserverPending {
    if (!_isLobbyMode) {
      return false;
    }

    return lobby!.pendingObserverKeys.contains(_currentPlayerKey);
  }

  bool get _isPlayerPending {
    if (!_isLobbyMode) {
      return false;
    }

    return lobby!.pendingPlayerKeys.contains(_currentPlayerKey);
  }

  int get _networkCallAmount {
    final heroState = _heroNetworkState;
    final game = _networkGame;
    if (heroState == null || game == null) {
      return 0;
    }
    return math.max(0, game.currentBet - heroState.streetContribution);
  }

  int get _networkMaxRaiseExtra {
    final heroState = _heroNetworkState;
    if (heroState == null) {
      return 0;
    }
    if (heroState.chips <= _networkCallAmount) {
      return 0;
    }
    return heroState.chips;
  }

  int get _networkMinRaiseExtra {
    if (_heroNetworkState == null) {
      return lobby?.settings.bigBlind ?? 20;
    }
    return _networkCallAmount + lobby!.settings.bigBlind;
  }

  bool get _heroCanRaise => _networkMaxRaiseExtra >= _networkMinRaiseExtra;

  double get _heroTurnProgress => _seatTurnProgressFor(_currentPlayerKey) ?? 0;

  int get _showdownRemaining {
    final endsAt = _networkGame?.showdownEndsAt;
    if (endsAt == null) {
      return 0;
    }
    final diff = endsAt.difference(DateTime.now());
    if (diff.isNegative) {
      return 0;
    }
    return ((diff.inMilliseconds + 999) ~/ 1000).clamp(0, 7);
  }

  List<_TrainingCard>? get _networkHeroCards {
    final heroState = _heroNetworkState;
    if (heroState == null || heroState.holeCards.length < 2) {
      return null;
    }
    return heroState.holeCards
        .map((card) => _TrainingCard(rank: card.rank, suit: card.suit))
        .toList();
  }

  String get _networkCallLabel =>
      _networkCallAmount == 0
      ? 'Check'
      : (_heroNetworkState != null &&
                _heroNetworkState!.chips < _networkCallAmount
            ? 'All-in ${_heroNetworkState!.chips}'
            : 'Call $_networkCallAmount');
  String get _networkRaiseLabel =>
      _networkCallAmount == 0 ? 'Bet' : 'Raise';

  String get _winnerBanner => _networkGame?.winnerLabel ?? '';

  @override
  Widget build(BuildContext context) {
    final profile = profileController.profile;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: const RadialGradient(
            center: Alignment(0, -0.18),
            radius: 1.15,
            colors: [Color(0xFF0F3A26), Color(0xFF0B2B1C), Color(0xFF081E14)],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final screenWidth = constraints.maxWidth;
              final screenHeight = constraints.maxHeight;
              final isCompactLandscape = screenHeight < 390;
              final actionWidth = math.min(
                isCompactLandscape ? 312.0 : 360.0,
                screenWidth * 0.40,
              );
              final seatWidth = math.min(
                isCompactLandscape ? 120.0 : 148.0,
                screenWidth * 0.17,
              );
              final tableWidth = math.min(screenWidth * 0.70, 760.0);
              final tableHeight = math.min(
                screenHeight * 0.60,
                isCompactLandscape ? 272.0 : 304.0,
              );
              final heroWidth = math.min(
                isCompactLandscape ? 212.0 : 232.0,
                screenWidth * 0.26,
              );
              final tableLeft = (screenWidth - tableWidth) / 2;
              final tableTop = math.max(
                68.0,
                (screenHeight - tableHeight) / 2 - 2,
              );
              final topLeftSeatX = tableLeft + tableWidth * 0.02;
              final topCenterSeatX = tableLeft + (tableWidth - seatWidth) / 2;
              final topRightSeatX =
                  tableLeft + tableWidth - seatWidth - tableWidth * 0.02;
              final topLeftSeatY = math.max(8.0, tableTop - 44);
              final topCenterSeatY = math.max(4.0, tableTop - 46);
              final topRightSeatY = math.max(8.0, tableTop - 44);
              final leftSeatX = math.max(10.0, tableLeft - seatWidth * 0.50);
              final leftSeatY = tableTop + tableHeight * 0.42;
              final rightSeatX = math.min(
                screenWidth - seatWidth - 10,
                tableLeft + tableWidth - seatWidth * 0.18,
              );
              final rightSeatY = tableTop + tableHeight * 0.28;
              final bottomSeatX = tableLeft + (tableWidth - seatWidth) / 2;
              final bottomSeatY = tableTop + tableHeight + 2;
              final heroBottom = 10.0;
              final heroLeft = math.max(
                34.0,
                (screenWidth - actionWidth - heroWidth - 6) / 2,
              );

              final lobbySeats = [
                _SeatLayout(left: bottomSeatX, top: bottomSeatY),
                _SeatLayout(left: leftSeatX, top: leftSeatY),
                _SeatLayout(left: topLeftSeatX, top: topLeftSeatY),
                _SeatLayout(left: topCenterSeatX, top: topCenterSeatY),
                _SeatLayout(left: topRightSeatX, top: topRightSeatY),
                _SeatLayout(left: rightSeatX, top: rightSeatY),
              ];

              return _TableAutoRefresh(
                enabled: _isLobbyMode && (_isStarting || _networkGame != null),
                builder: (context) => Stack(
                  children: [
                    Positioned(
                      left: tableLeft,
                      top: tableTop,
                      child: PokerTableSurface(
                        width: tableWidth,
                        height: tableHeight,
                        pot: _tablePot,
                        streetLabel: _tableStreetLabel,
                        communityCards: _tableCommunityCards,
                      ),
                    ),
                    Positioned(
                      top: 8,
                      left: 8,
                      child: _TableBackButton(
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ),
                    if (_isLobbyMode)
                      ..._buildLobbySeats(lobbySeats, seatWidth)
                    else
                      ..._buildDemoSeats(
                        seatWidth: seatWidth,
                        topLeftSeatX: topLeftSeatX,
                        topLeftSeatY: topLeftSeatY,
                        topCenterSeatX: topCenterSeatX,
                        topCenterSeatY: topCenterSeatY,
                        topRightSeatX: topRightSeatX,
                        topRightSeatY: topRightSeatY,
                        leftSeatX: leftSeatX,
                        leftSeatY: leftSeatY,
                        rightSeatX: rightSeatX,
                        rightSeatY: rightSeatY,
                      ),
                    Positioned(
                      top: 10,
                      right: 14,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if ((_qrPayload ?? '').isNotEmpty) ...[
                            _TopQrButton(
                              onPressed: () {
                                final warning = _hostShareWarning;
                                if (warning != null) {
                                  _showQrUnavailableDialog(
                                    context,
                                    message: warning,
                                  );
                                  return;
                                }
                                _showQrDialog(context, qrPayload: _qrPayload!);
                              },
                            ),
                            const SizedBox(width: 8),
                          ],
                          _ObserverToggleButton(
                            observersCount: _isLobbyMode
                                ? lobby!.observersCount
                                : 0,
                            isObserver: _isObserver,
                            isPending: _isObserverPending,
                            onPressed: _isLobbyMode
                                ? () {
                                    final message = _isObserver
                                        ? 'Вы уже наблюдаете за столом'
                                        : _isObserverPending
                                        ? 'Переход в наблюдатели уже ожидает завершения раунда'
                                        : _isGameStarted
                                        ? 'Переход в наблюдатели будет после завершения раунда'
                                        : 'Вы перешли в режим наблюдателя';
                                    lobbyController!.requestObserverMode(
                                      lobby!.id,
                                      _resolveCurrentLobbyIdentity(),
                                    );

                                    showAppToast(
                                      context,
                                      message: message,
                                      type: AppToastType.info,
                                    );
                                  }
                                : () {
                                    showAppToast(
                                      context,
                                      message:
                                          'Режим наблюдателя появится в сетевой игре',
                                      type: AppToastType.info,
                                    );
                                  },
                          ),
                        ],
                      ),
                    ),
                    if ((!_isLobbyMode || _isGameStarted) && !_isObserver)
                      Positioned(
                        left: heroLeft,
                        bottom: heroBottom,
                        child: _HeroPlayerPanel(
                          width: heroWidth,
                          profile: profile,
                          isObserverMode: false,
                          chips: _heroNetworkState?.chips ?? _currentPlayerChips,
                          isDealer:
                              _isGameStarted &&
                              (_networkGame?.dealerKey ??
                                      _startedLobbyState.dealerKey) ==
                                  _currentPlayerKey,
                          isActive: _isHeroTurn,
                          turnProgress: _heroTurnProgress,
                          cards: _networkHeroCards,
                          comboLabel: '',
                        ),
                      ),
                    if (_winnerBanner.trim().isNotEmpty)
                      Positioned.fill(
                        child: IgnorePointer(
                          child: Center(
                            child: Transform.translate(
                              offset: const Offset(0, -18),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 18,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF08130F).withAlpha(230),
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: AppTheme.primary.withAlpha(80),
                                  ),
                                ),
                                child: Text(
                                  _winnerBanner,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    if (_isLobbyMode && !_isGameStarted)
                      Positioned.fill(
                        child: Center(
                          child: _LobbyCenterCard(
                            lobby: lobby!,
                            isHost: _isHost,
                            canHostStart: _isHost && !_isObserver,
                            isStarting: _isStarting,
                            onStart: _isHost && !_isObserver
                                ? () => lobbyController!.startGame(lobby!.id)
                                : null,
                          ),
                        ),
                      )
                    else if (!_isObserver)
                      Positioned(
                        right: 14,
                        bottom: heroBottom,
                        width: actionWidth,
                        height: isCompactLandscape ? 58 : 64,
                        child: _buildNetworkActionBar(context),
                      ),
                    if (_isObserver)
                      Positioned(
                        right: 14,
                        bottom: heroBottom,
                        width: actionWidth,
                        height: isCompactLandscape ? 58 : 64,
                        child: TableActionBar(
                          onFold: () => onDemoAction('Fold'),
                          onCall: () => onDemoAction('Call'),
                          onRaise: () => onDemoAction('Raise'),
                          isObserverMode: true,
                          onConnectLater: () {
                            if (_isPlayerPending) {
                              showAppToast(
                                context,
                                message:
                                    'Подключение к столу уже ожидает следующего раунда',
                                type: AppToastType.info,
                              );
                              return;
                            }

                            final result = lobbyController!.requestPlayerMode(
                              lobby!.id,
                              _resolveCurrentLobbyIdentity(),
                            );

                            if (result == null) {
                              showAppToast(
                                context,
                                message: 'Свободных мест за столом больше нет',
                                type: AppToastType.error,
                              );
                              return;
                            }

                            showAppToast(
                              context,
                              message: _isGameStarted
                                  ? 'Вы подключитесь к столу в следующем раунде'
                                  : 'Вы снова сели за стол',
                              type: AppToastType.info,
                            );
                          },
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildNetworkActionBar(BuildContext context) {
    if (!_isLobbyMode || !_isGameStarted || _networkGame == null) {
      return const SizedBox.shrink();
    }

    if (_isNetworkShowdown) {
      if (!_canRevealHeroHand) {
        return const SizedBox.shrink();
      }
      return _TrainingSingleActionBar(
        label: 'Показать карты • $_showdownRemaining',
        onPressed: () {
          lobbyController!.revealHand(lobby!.id, _resolveCurrentLobbyIdentity());
        },
      );
    }

    if (!_isHeroTurn) {
      return const SizedBox.shrink();
    }

    return TableActionBar(
      onFold: () {
        lobbyController!.submitGameAction(
          lobby!.id,
          _resolveCurrentLobbyIdentity(),
          action: 'fold',
        );
      },
      onCall: () {
        lobbyController!.submitGameAction(
          lobby!.id,
          _resolveCurrentLobbyIdentity(),
          action: _networkCallAmount == 0 ? 'check' : 'call',
        );
      },
      onRaise: () => _openNetworkRaiseSheet(context),
      callLabel: _networkCallLabel,
      raiseLabel: _networkRaiseLabel,
      isEnabled: true,
      isRaiseEnabled: _heroCanRaise,
    );
  }

  Future<void> _openNetworkRaiseSheet(BuildContext context) async {
    if (!_isHeroTurn ||
        _networkGame == null ||
        _heroNetworkState == null ||
        !_heroCanRaise) {
      return;
    }

    final minimum = _networkMinRaiseExtra;
    final maximum = _networkMaxRaiseExtra;
    var tempRaise = minimum;
    final result = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: const Color(0xFF08130F),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _networkCallAmount == 0 ? 'Bet' : 'Raise',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Размер докида',
                          style: TextStyle(
                            color: AppTheme.mutedText,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Text(
                        tempRaise >= maximum ? 'ALL IN' : '$tempRaise',
                        style: const TextStyle(
                          color: AppTheme.primary,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    value: tempRaise.toDouble(),
                    min: minimum.toDouble(),
                    max: maximum.toDouble(),
                    divisions: math.max(1, (maximum - minimum) ~/ 10).toInt(),
                    onChanged: (value) {
                      setModalState(() {
                        tempRaise = value.round();
                      });
                    },
                  ),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => Navigator.of(context).pop(tempRaise),
                      child: const Text('Подтвердить raise'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (!context.mounted || result == null) {
      return;
    }

    lobbyController!.submitGameAction(
      lobby!.id,
      _resolveCurrentLobbyIdentity(),
      action: 'raise',
      raiseAmount: result - _networkCallAmount,
    );
  }

  List<Widget> _buildLobbySeats(List<_SeatLayout> positions, double seatWidth) {
    final seatsCount = lobby!.settings.seatsCount.clamp(2, positions.length);
    final visiblePositions = (_isGameStarted
            ? positions.skip(1)
            : positions)
        .take(_isGameStarted ? math.max(seatsCount - 1, 0) : seatsCount)
        .toList();
    final players = _displayedTablePlayers();

    return [
      for (var i = 0; i < visiblePositions.length; i++)
        Positioned(
          left: visiblePositions[i].left,
          top: visiblePositions[i].top,
          child: i < players.length
              ? TablePlayerSeat(
                  width: seatWidth,
                  name: players[i].identity.displayName,
                  chips: players[i].chips,
                  avatarSeed: players[i].identity.avatarSeed,
                  avatarPath: players[i].identity.avatarPath,
                  avatarType: players[i].identity.avatarType,
                  avatarBytes: players[i].identity.avatarBytes,
                  isDealer:
                      _isGameStarted &&
                      (_networkGame?.dealerKey ??
                              _startedLobbyState.dealerKey) ==
                          players[i].identity.stableKey,
                  showCards: _isGameStarted,
                  isActive: _isGameStarted
                      ? (_networkGame?.activePlayerKey ??
                                _startedLobbyState.activePlayerKey) ==
                            players[i].identity.stableKey
                      : players[i].identity.stableKey == _currentPlayerKey,
                  statusLabel: _isGameStarted
                      ? (_networkPlayerState(players[i].identity.stableKey)
                                  ?.lastAction
                                  .isNotEmpty ==
                              true
                          ? _networkPlayerState(players[i].identity.stableKey)!
                              .lastAction
                          : _startedLobbyState.statusByPlayerKey[players[i]
                                    .identity
                                    .stableKey] ??
                                'check')
                      : (players[i].isHost ? 'хост' : 'в лобби'),
                  turnProgress: _seatTurnProgressFor(
                    players[i].identity.stableKey,
                  ),
                  revealedCards: _networkPlayerState(
                                players[i].identity.stableKey,
                              )
                              ?.isRevealed ==
                          true
                      ? _networkPlayerState(players[i].identity.stableKey)!
                          .holeCards
                          .map(
                            (card) => TableSeatCard(
                              rank: card.rank,
                              suit: card.suit,
                            ),
                          )
                          .toList()
                      : null,
                )
              : _EmptyLobbySeat(width: seatWidth),
        ),
    ];
  }

  PokerGamePlayerState? _networkPlayerState(String playerKey) {
    if (_networkGame == null) {
      return null;
    }
    for (final player in _networkGame!.players) {
      if (player.playerKey == playerKey) {
        return player;
      }
    }
    return null;
  }

  double? _seatTurnProgressFor(String playerKey) {
    if (!_isGameStarted) {
      return null;
    }
    if (_networkGame?.activePlayerKey == playerKey &&
        _networkGame?.turnEndsAt != null) {
      final left = _networkGame!.turnEndsAt!
          .difference(DateTime.now())
          .inMilliseconds;
      return (left / 10000).clamp(0.0, 1.0);
    }
    return _startedLobbyState.activePlayerKey == playerKey ? 0.72 : null;
  }

  List<LobbyPlayerEntry> _displayedTablePlayers() {
    final ordered = _orderedPlayersForViewer();
    if (!_isGameStarted || ordered.isEmpty) {
      return ordered;
    }

    if (ordered.first.identity.stableKey == _currentPlayerKey) {
      return ordered.skip(1).toList();
    }

    return ordered;
  }

  List<LobbyPlayerEntry> _orderedPlayersForViewer() {
    final players = [...lobby!.players];
    if (players.isEmpty) {
      return players;
    }

    final currentIndex = players.indexWhere(
      (entry) => entry.identity.stableKey == _currentPlayerKey,
    );
    if (currentIndex <= 0) {
      return players;
    }

    return [
      ...players.sublist(currentIndex),
      ...players.sublist(0, currentIndex),
    ];
  }

  PlayerIdentity _resolveCurrentLobbyIdentity() {
    for (final entry in lobby!.players) {
      if (entry.identity.stableKey == _currentPlayerKey) {
        return entry.identity;
      }
    }

    for (final observer in lobby!.observers) {
      if (observer.stableKey == _currentPlayerKey) {
        return observer;
      }
    }

    return _currentIdentity;
  }

  int get _currentPlayerChips {
    final currentEntries = lobby?.players.where(
      (entry) => entry.identity.stableKey == _currentPlayerKey,
    );
    if (currentEntries == null || currentEntries.isEmpty) {
      return lobby?.settings.startingChips ?? 1000;
    }
    return currentEntries.first.chips;
  }

  int get _tablePot =>
      _isGameStarted ? (_networkGame?.pot ?? _startedLobbyState.pot) : 0;

  String get _tableStreetLabel {
    if (!_isGameStarted) {
      return _isStarting ? 'Game starts' : 'Lobby';
    }

    return _networkGame?.street ?? _startedLobbyState.streetLabel;
  }

  List<Widget> get _tableCommunityCards {
    if (!_isGameStarted) {
      return const [];
    }

    if (_networkGame != null) {
      return _networkGame!.communityCards
          .map(
            (card) => PlayingCardView(
              rank: card.rank,
              suit: card.suit,
              width: 42,
              height: 58,
            ),
          )
          .toList();
    }
    return _startedLobbyState.communityCards;
  }

  _StartedLobbyState get _startedLobbyState {
    final players = lobby?.players ?? const <LobbyPlayerEntry>[];
    if (players.isEmpty) {
      return const _StartedLobbyState.empty();
    }

    final scenario =
        _demoScenarios[(lobby?.demoScenarioIndex ?? 0) % _demoScenarios.length];
    final dealerKey =
        players[scenario.dealerIndex % players.length].identity.stableKey;
    final activeKey =
        players[scenario.activeIndex % players.length].identity.stableKey;

    final statuses = <String, String>{};
    for (var i = 0; i < players.length; i++) {
      statuses[players[i].identity.stableKey] =
          scenario.statuses[i % scenario.statuses.length];
    }

    return _StartedLobbyState(
      pot: scenario.pot,
      streetLabel: scenario.streetLabel,
      communityCards: scenario.communityCards,
      dealerKey: dealerKey,
      activePlayerKey: activeKey,
      statusByPlayerKey: statuses,
    );
  }

  List<Widget> _buildDemoSeats({
    required double seatWidth,
    required double topLeftSeatX,
    required double topLeftSeatY,
    required double topCenterSeatX,
    required double topCenterSeatY,
    required double topRightSeatX,
    required double topRightSeatY,
    required double leftSeatX,
    required double leftSeatY,
    required double rightSeatX,
    required double rightSeatY,
  }) {
    return [
      Positioned(
        top: topLeftSeatY,
        left: topLeftSeatX,
        child: TablePlayerSeat(
          width: seatWidth,
          name: 'Масик',
          chips: 1280,
          avatarSeed: 'crown',
          avatarPath: '',
          avatarType: PlayerAvatarType.preset,
          statusLabel: 'думает',
          isActive: true,
          isDealer: true,
          turnProgress: 0.72,
        ),
      ),
      Positioned(
        top: topCenterSeatY,
        left: topCenterSeatX,
        child: TablePlayerSeat(
          width: seatWidth,
          name: 'Данил',
          chips: 950,
          avatarSeed: 'old_heart',
          avatarPath: '',
          avatarType: PlayerAvatarType.preset,
          statusLabel: 'check',
        ),
      ),
      Positioned(
        top: topRightSeatY,
        left: topRightSeatX,
        child: TablePlayerSeat(
          width: seatWidth,
          name: 'Alex',
          chips: 1540,
          avatarSeed: 'diamond',
          avatarPath: '',
          avatarType: PlayerAvatarType.preset,
          statusLabel: 'call',
        ),
      ),
      Positioned(
        left: leftSeatX,
        top: leftSeatY,
        child: TablePlayerSeat(
          width: seatWidth,
          name: 'Rok',
          chips: 820,
          avatarSeed: 'leaf',
          avatarPath: '',
          avatarType: PlayerAvatarType.preset,
          statusLabel: 'fold',
          isFolded: true,
        ),
      ),
      Positioned(
        left: rightSeatX,
        top: rightSeatY,
        child: TablePlayerSeat(
          width: seatWidth,
          name: 'Dmitry',
          chips: 1110,
          avatarSeed: 'spade',
          avatarPath: '',
          avatarType: PlayerAvatarType.preset,
          statusLabel: 'raise',
        ),
      ),
    ];
  }

  void _showQrDialog(BuildContext context, {required String qrPayload}) {
    final hostAddress = lobbyController?.hostAddress ?? '';
    final hostPort = lobbyController?.hostPort ?? LobbyController.defaultPort;
    final lobbyId = lobby?.id ?? '';
    final manualCode = hostAddress.isNotEmpty
        ? '$hostAddress:$hostPort${lobbyId.isNotEmpty ? '#$lobbyId' : ''}'
        : '';
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withAlpha(42),
      builder: (context) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 24,
          ),
          backgroundColor: const Color(0xFF081712),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'QR подключения',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Этот код можно будет сканировать для быстрого входа в стол.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.mutedText, height: 1.4),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: QrImageView(
                    data: qrPayload,
                    size: 180,
                    backgroundColor: Colors.white,
                  ),
                ),
                if (manualCode.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0E2019),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.white.withAlpha(12)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Ручной код подключения',
                          style: TextStyle(
                            color: AppTheme.mutedText,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        SelectableText(
                          manualCode,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  void _showQrUnavailableDialog(
    BuildContext context, {
    required String message,
  }) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withAlpha(42),
      builder: (context) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 24,
          ),
          backgroundColor: const Color(0xFF081712),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  color: AppTheme.primary,
                  size: 34,
                ),
                const SizedBox(height: 12),
                const Text(
                  'QR сейчас недоступен',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 10),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppTheme.mutedText,
                    height: 1.45,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Для проверки LAN запусти хост на реальном телефоне в одной Wi-Fi сети или на устройстве, которое раздаёт точку доступа.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.mutedText, height: 1.4),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _TableAutoRefresh extends StatefulWidget {
  final bool enabled;
  final WidgetBuilder builder;

  const _TableAutoRefresh({
    required this.enabled,
    required this.builder,
  });

  @override
  State<_TableAutoRefresh> createState() => _TableAutoRefreshState();
}

class _TableAutoRefreshState extends State<_TableAutoRefresh> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _syncTicker();
  }

  @override
  void didUpdateWidget(covariant _TableAutoRefresh oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.enabled != widget.enabled) {
      _syncTicker();
    }
  }

  void _syncTicker() {
    _ticker?.cancel();
    if (!widget.enabled) {
      return;
    }
    _ticker = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context);
}

class _TrainingTableScene extends StatefulWidget {
  final ProfileController profileController;

  const _TrainingTableScene({required this.profileController});

  @override
  State<_TrainingTableScene> createState() => _TrainingTableSceneState();
}

class _TrainingTableSceneState extends State<_TrainingTableScene> {
  static const int _smallBlind = 10;
  static const int _bigBlind = 20;
  static const Duration _turnDuration = Duration(seconds: 10);
  static const Duration _showdownDuration = Duration(seconds: 7);

  final math.Random _random = math.Random();
  late final List<_TrainingPlayerState> _players;
  Timer? _turnTicker;
  Timer? _botActionTimer;
  Timer? _nextHandTimer;
  Timer? _showdownTicker;
  Timer? _runoutTimer;
  late DateTime _turnEndsAt;
  DateTime? _showdownEndsAt;
  int _dealerIndex = 0;
  int _activeIndex = 0;
  int _pot = 0;
  int _currentBet = 0;
  _TrainingStreet _street = _TrainingStreet.preflop;
  List<_TrainingCard> _communityCards = const [];
  List<int> _pendingPlayers = <int>[];
  bool _handLocked = false;
  bool _isShowdownPhase = false;
  final Set<int> _revealedPlayers = <int>{};
  List<int> _showdownPendingPlayers = <int>[];
  String _winnerBanner = '';
  int _selectedRaiseExtra = _bigBlind;

  @override
  void initState() {
    super.initState();
    _players = _buildPlayers();
    _startNewHand(keepDealer: true);
  }

  @override
  void dispose() {
    _turnTicker?.cancel();
    _botActionTimer?.cancel();
    _nextHandTimer?.cancel();
    _showdownTicker?.cancel();
    _runoutTimer?.cancel();
    super.dispose();
  }

  List<_TrainingPlayerState> _buildPlayers() {
    final profile = widget.profileController.profile;

    return [
      _TrainingPlayerState(
        identity: PlayerIdentity.fromProfile(profile),
        chips: 1000,
        cards: _dealHoleCards(),
        isHero: true,
      ),
      _TrainingPlayerState(
        identity: const PlayerIdentity(
          displayName: 'Масик',
          avatarSeed: 'crown',
          avatarPath: '',
          avatarType: PlayerAvatarType.preset,
        ),
        chips: 1000,
        cards: _dealHoleCards(),
      ),
      _TrainingPlayerState(
        identity: const PlayerIdentity(
          displayName: 'Данил',
          avatarSeed: 'old_heart',
          avatarPath: '',
          avatarType: PlayerAvatarType.preset,
        ),
        chips: 1000,
        cards: _dealHoleCards(),
      ),
      _TrainingPlayerState(
        identity: const PlayerIdentity(
          displayName: 'Alex',
          avatarSeed: 'diamond',
          avatarPath: '',
          avatarType: PlayerAvatarType.preset,
        ),
        chips: 1000,
        cards: _dealHoleCards(),
      ),
      _TrainingPlayerState(
        identity: const PlayerIdentity(
          displayName: 'Rok',
          avatarSeed: 'leaf',
          avatarPath: '',
          avatarType: PlayerAvatarType.preset,
        ),
        chips: 1000,
        cards: _dealHoleCards(),
      ),
      _TrainingPlayerState(
        identity: const PlayerIdentity(
          displayName: 'Dmitry',
          avatarSeed: 'spade',
          avatarPath: '',
          avatarType: PlayerAvatarType.preset,
        ),
        chips: 1000,
        cards: _dealHoleCards(),
      ),
    ];
  }

  List<_TrainingCard> _dealHoleCards() {
    return [_drawCard(), _drawCard()];
  }

  _TrainingCard _drawCard() {
    const ranks = ['A', 'K', 'Q', 'J', '10', '9', '8', '7', '6', '5', '4', '3', '2'];
    const suits = ['♠', '♥', '♣', '♦'];
    return _TrainingCard(
      rank: ranks[_random.nextInt(ranks.length)],
      suit: suits[_random.nextInt(suits.length)],
    );
  }

  void _startNewHand({bool keepDealer = false}) {
    _nextHandTimer?.cancel();
    _botActionTimer?.cancel();
    _turnTicker?.cancel();
    _showdownTicker?.cancel();

    if (!keepDealer) {
      _dealerIndex = (_dealerIndex + 1) % _players.length;
    }

    for (var i = 0; i < _players.length; i++) {
      final player = _players[i];
      player
        ..cards = _dealHoleCards()
        ..isFolded = false
        ..streetContribution = 0
        ..handContribution = 0
        ..lastAction = ''
        ..isDealer = i == _dealerIndex;
    }

    final sbIndex = _nextEligibleIndex(_dealerIndex);
    final bbIndex = _nextEligibleIndex(sbIndex);

    _pot = 0;
    _currentBet = _bigBlind;
    _street = _TrainingStreet.preflop;
    _communityCards = const [];
    _handLocked = false;
    _isShowdownPhase = false;
    _revealedPlayers.clear();
    _showdownPendingPlayers = <int>[];
    _showdownEndsAt = null;
    _winnerBanner = '';

    _postBlind(sbIndex, _smallBlind, 'small blind');
    _postBlind(bbIndex, _bigBlind, 'big blind');

    _pendingPlayers = _eligiblePlayers();
    _activeIndex = _nextPendingAfter(bbIndex);
    _startTurn();
    setState(() {});
  }

  void _postBlind(int index, int amount, String label) {
    final player = _players[index];
    final paid = math.min(player.chips, amount);
    player
      ..chips -= paid
      ..streetContribution += paid
      ..handContribution += paid
      ..lastAction = label;
    _pot += paid;
  }

  List<int> _eligiblePlayers() {
    final result = <int>[];
    for (var i = 0; i < _players.length; i++) {
      if (!_players[i].isFolded && _players[i].chips > 0) {
        result.add(i);
      }
    }
    return result;
  }

  int _nextEligibleIndex(int from) {
    final hasEligible = _players.any(
      (player) => !player.isFolded && player.chips > 0,
    );
    if (!hasEligible) {
      return 0;
    }
    var cursor = from;
    while (true) {
      cursor = (cursor + 1) % _players.length;
      if (!_players[cursor].isFolded && _players[cursor].chips > 0) {
        return cursor;
      }
    }
  }

  int _nextPendingAfter(int from) {
    if (_pendingPlayers.isEmpty) {
      return 0;
    }
    var cursor = from;
    while (true) {
      cursor = (cursor + 1) % _players.length;
      if (_pendingPlayers.contains(cursor) && !_players[cursor].isFolded) {
        return cursor;
      }
    }
  }

  void _startTurn() {
    _turnTicker?.cancel();
    _botActionTimer?.cancel();
    _showdownTicker?.cancel();
    _runoutTimer?.cancel();
    _turnEndsAt = DateTime.now().add(_turnDuration);
    _turnTicker = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (!mounted || _handLocked) {
        return;
      }
      final now = DateTime.now();
      if (now.isAfter(_turnEndsAt)) {
        _handleTimeout();
        return;
      }
      setState(() {});
    });

    if (!_players[_activeIndex].isHero) {
      _botActionTimer = Timer(
        Duration(milliseconds: 1200 + _random.nextInt(1200)),
        () {
          if (!mounted || _handLocked) {
            return;
          }
          _performBotAction();
        },
      );
    }
  }

  void _handleTimeout() {
    final callAmount = _callAmountFor(_activeIndex);
    if (_players[_activeIndex].isHero) {
      _applyAction(
        _activeIndex,
        callAmount == 0 ? _TrainingAction.check : _TrainingAction.fold,
      );
      return;
    }
    _performBotAction(forceTimeout: true);
  }

  int _callAmountFor(int playerIndex) {
    return math.max(0, _currentBet - _players[playerIndex].streetContribution);
  }

  int get _maxRaiseExtra {
    final hero = _players.first;
    if (hero.chips <= _callAmountFor(0)) {
      return 0;
    }
    return hero.chips;
  }

  int get _minRaiseExtra {
    return _callAmountFor(0) + _bigBlind;
  }

  void _performBotAction({bool forceTimeout = false}) {
    final callAmount = _callAmountFor(_activeIndex);
    late _TrainingAction action;

    if (forceTimeout) {
      action = callAmount == 0 ? _TrainingAction.check : _TrainingAction.fold;
    } else if (callAmount == 0) {
      action = _random.nextInt(100) < 28
          ? _TrainingAction.raise
          : _TrainingAction.check;
    } else {
      final roll = _random.nextInt(100);
      if (roll < 18) {
        action = _TrainingAction.fold;
      } else if (roll < 38) {
        action = _TrainingAction.raise;
      } else {
        action = _TrainingAction.call;
      }
    }

    _applyAction(_activeIndex, action);
  }

  void _applyAction(int playerIndex, _TrainingAction action) {
    if (_handLocked || _isShowdownPhase || playerIndex != _activeIndex) {
      return;
    }

    final player = _players[playerIndex];
    final callAmount = _callAmountFor(playerIndex);

    switch (action) {
      case _TrainingAction.fold:
        player
          ..isFolded = true
          ..lastAction = 'fold';
        _pendingPlayers.remove(playerIndex);
        break;
      case _TrainingAction.check:
      case _TrainingAction.call:
        final paid = math.min(player.chips, callAmount);
        player
          ..chips -= paid
          ..streetContribution += paid
          ..handContribution += paid
          ..lastAction = callAmount == 0 && paid > 0
              ? 'bet'
              : callAmount == 0
              ? 'check'
              : 'call';
        _pot += paid;
        _pendingPlayers.remove(playerIndex);
        break;
      case _TrainingAction.raise:
        final extra = playerIndex == 0
            ? (_selectedRaiseExtra.clamp(_minRaiseExtra, _maxRaiseExtra) -
                callAmount)
            : _bigBlind;
        final targetBet = _currentBet + extra;
        final paid = math.min(
          player.chips,
          math.max(0, targetBet - player.streetContribution),
        );
        player
          ..chips -= paid
          ..streetContribution += paid
          ..handContribution += paid
          ..lastAction = callAmount == 0 ? 'bet' : 'raise';
        _pot += paid;
        _currentBet = player.streetContribution;
        _pendingPlayers = _eligiblePlayers()
            .where((index) => index != playerIndex)
            .toList();
        break;
    }

    _refundUnmatchedExcess();
    if (_tryStartAllInRunout()) {
      setState(() {});
      return;
    }

    final livePlayers = _players.where((item) => !item.isFolded).toList();
    if (livePlayers.length == 1) {
      _finishHandWithWinner(
        _players.indexWhere((item) => !item.isFolded),
        'wins',
      );
      return;
    }

    if (_pendingPlayers.isEmpty) {
      _advanceStreet();
      return;
    }

    _activeIndex = _nextPendingAfter(playerIndex);
    _startTurn();
    setState(() {});
  }

  void _advanceStreet() {
    for (final player in _players) {
      if (!player.isFolded) {
        player.lastAction = '';
      }
      player.streetContribution = 0;
    }

    _currentBet = 0;
    switch (_street) {
      case _TrainingStreet.preflop:
        _street = _TrainingStreet.flop;
        _communityCards = [_drawCard(), _drawCard(), _drawCard()];
        break;
      case _TrainingStreet.flop:
        _street = _TrainingStreet.turn;
        _communityCards = [..._communityCards, _drawCard()];
        break;
      case _TrainingStreet.turn:
        _street = _TrainingStreet.river;
        _communityCards = [..._communityCards, _drawCard()];
        break;
      case _TrainingStreet.river:
        _startShowdown();
        return;
    }

    _pendingPlayers = _eligiblePlayers();
    _activeIndex = _nextPendingAfter(_dealerIndex);
    _startTurn();
    setState(() {});
  }

  void _finishHandWithWinner(int winnerIndex, String label) {
    _handLocked = true;
    _turnTicker?.cancel();
    _botActionTimer?.cancel();
    _showdownTicker?.cancel();
    _runoutTimer?.cancel();
    _players[winnerIndex]
      ..chips += _pot
      ..lastAction = label;
    _activeIndex = winnerIndex;
    _isShowdownPhase = false;
    _showdownEndsAt = null;
    _winnerBanner = '${_players[winnerIndex].identity.displayName} выиграл банк';
    setState(() {});
    _nextHandTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) {
        return;
      }
      _startNewHand();
    });
  }

  void _refundUnmatchedExcess() {
    final livePlayers = _players.where((item) => !item.isFolded).toList();
    final actionablePlayers = livePlayers.where((item) => item.chips > 0).toList();
    if (livePlayers.length < 2 || actionablePlayers.length > 1) {
      return;
    }
    final sortedContributions = livePlayers
        .map((item) => item.streetContribution)
        .toList()
      ..sort();
    final cap = sortedContributions.length >= 2
        ? sortedContributions[sortedContributions.length - 2]
        : sortedContributions.last;
    for (final player in livePlayers) {
      if (player.streetContribution <= cap) {
        continue;
      }
      final refund = player.streetContribution - cap;
      player
        ..streetContribution = cap
        ..handContribution -= refund
        ..chips += refund;
      _pot -= refund;
    }
    _currentBet = cap;
  }

  bool get _isHeroActive => _activeIndex == 0 && !_handLocked;

  double get _currentTurnProgressValue {
    final total = _turnDuration.inMilliseconds;
    final left = _turnEndsAt.difference(DateTime.now()).inMilliseconds;
    return (left / total).clamp(0.0, 1.0);
  }

  double get _heroTurnProgress {
    if (!_isHeroActive) {
      return 0;
    }
    return _currentTurnProgressValue;
  }

  double? _seatTurnProgress(int playerIndex) {
    if (_activeIndex != playerIndex || _handLocked) {
      return null;
    }
    return _currentTurnProgressValue;
  }

  String get _callButtonLabel {
    final amount = _callAmountFor(0);
    if (amount == 0) {
      return 'Check';
    }
    final heroChips = _players.first.chips;
    return heroChips < amount ? 'All-in $heroChips' : 'Call $amount';
  }

  String get _raiseButtonLabel {
    return _callAmountFor(0) == 0 ? 'Bet' : 'Raise';
  }

  String get _singleActionLabel => 'Показать карты';

  _HeroHandInsight get _heroHandInsight {
    final heroCards = _players.first.cards;
    final all = <_CardSpot>[
      for (var i = 0; i < heroCards.length; i++)
        _CardSpot(
          zone: _CardZone.hero,
          index: i,
          card: heroCards[i],
        ),
      for (var i = 0; i < _communityCards.length; i++)
        _CardSpot(
          zone: _CardZone.board,
          index: i,
          card: _communityCards[i],
        ),
    ];

    if (all.isEmpty) {
      return const _HeroHandInsight(
        label: 'High Card',
        highlightedHeroIndexes: {},
        highlightedBoardIndexes: {},
      );
    }

    final rankGroups = <int, List<_CardSpot>>{};
    final suitGroups = <String, List<_CardSpot>>{};
    for (final spot in all) {
      rankGroups.putIfAbsent(spot.card.rankValue, () => []).add(spot);
      suitGroups.putIfAbsent(spot.card.suit, () => []).add(spot);
    }

    final sortedRanks = rankGroups.keys.toList()..sort((a, b) => b.compareTo(a));
    final quads = sortedRanks.where((rank) => rankGroups[rank]!.length >= 4).toList();
    final trips = sortedRanks.where((rank) => rankGroups[rank]!.length >= 3).toList();
    final pairs = sortedRanks.where((rank) => rankGroups[rank]!.length >= 2).toList();

    List<_CardSpot>? straightFlushCards;
    for (final suitEntry in suitGroups.entries) {
      if (suitEntry.value.length < 5) {
        continue;
      }
      final straightFlush = _findStraightCards(suitEntry.value);
      if (straightFlush != null) {
        straightFlushCards = straightFlush;
        break;
      }
    }
    if (straightFlushCards != null) {
      return _buildInsight('Straight Flush', straightFlushCards);
    }

    if (quads.isNotEmpty) {
      return _buildInsight(
        'Four of a Kind',
        rankGroups[quads.first]!.take(4).toList(),
      );
    }

    if (trips.isNotEmpty && (pairs.isNotEmpty || trips.length > 1)) {
      final tripRank = trips.first;
      final pairRank = pairs.where((rank) => rank != tripRank).isNotEmpty
          ? pairs.firstWhere((rank) => rank != tripRank)
          : trips.firstWhere((rank) => rank != tripRank);
      return _buildInsight(
        'Full House',
        [
          ...rankGroups[tripRank]!.take(3),
          ...rankGroups[pairRank]!.take(2),
        ],
      );
    }

    final flushGroup = suitGroups.values.where((cards) => cards.length >= 5).toList();
    if (flushGroup.isNotEmpty) {
      final flushCards = [...flushGroup.first]
        ..sort((a, b) => b.card.rankValue.compareTo(a.card.rankValue));
      return _buildInsight('Flush', flushCards.take(5).toList());
    }

    final straightCards = _findStraightCards(all);
    if (straightCards != null) {
      return _buildInsight('Straight', straightCards);
    }

    if (trips.isNotEmpty) {
      return _buildInsight(
        'Three of a Kind',
        rankGroups[trips.first]!.take(3).toList(),
      );
    }

    if (pairs.length >= 2) {
      final topPair = pairs[0];
      final secondPair = pairs[1];
      return _buildInsight(
        'Two Pair',
        [
          ...rankGroups[topPair]!.take(2),
          ...rankGroups[secondPair]!.take(2),
        ],
      );
    }

    if (pairs.isNotEmpty) {
      final pairRank = pairs.first;
      return _buildInsight(
        'One Pair',
        rankGroups[pairRank]!.take(2).toList(),
      );
    }

    final topCard = [...all]..sort((a, b) => b.card.rankValue.compareTo(a.card.rankValue));
    final label = 'High Card ${topCard.first.card.rank}';
    return _buildInsight(label, [topCard.first]);
  }

  List<_CardSpot>? _findStraightCards(List<_CardSpot> spots) {
    final rankMap = <int, _CardSpot>{};
    for (final spot in spots) {
      rankMap.putIfAbsent(spot.card.rankValue, () => spot);
      if (spot.card.rankValue == 14) {
        rankMap.putIfAbsent(1, () => spot);
      }
    }
    final ranks = rankMap.keys.toList()..sort((a, b) => b.compareTo(a));
    for (var i = 0; i < ranks.length; i++) {
      final start = ranks[i];
      final straight = <_CardSpot>[];
      var expected = start;
      while (rankMap.containsKey(expected)) {
        straight.add(rankMap[expected]!);
        if (straight.length == 5) {
          return straight;
        }
        expected -= 1;
      }
    }
    return null;
  }

  _HeroHandInsight _buildInsight(String label, List<_CardSpot> cards) {
    final hero = <int>{};
    final board = <int>{};
    for (final spot in cards) {
      if (spot.zone == _CardZone.hero) {
        hero.add(spot.index);
      } else {
        board.add(spot.index);
      }
    }
    return _HeroHandInsight(
      label: label,
      highlightedHeroIndexes: hero,
      highlightedBoardIndexes: board,
    );
  }

  List<Widget> get _communityCardViews => _communityCards
      .map(
        (card) {
          final index = _communityCards.indexOf(card);
          return PlayingCardView(
            rank: card.rank,
            suit: card.suit,
            width: 42,
            height: 58,
            isHighlighted: _heroHandInsight.highlightedBoardIndexes.contains(index),
          );
        },
      )
      .toList();

  String get _streetLabel => switch (_street) {
    _TrainingStreet.preflop => 'Preflop',
    _TrainingStreet.flop => 'Flop',
    _TrainingStreet.turn => 'Turn',
    _TrainingStreet.river => 'River',
  };

  int get _showdownRemaining {
    if (_showdownEndsAt == null) {
      return 0;
    }
    final diff = _showdownEndsAt!.difference(DateTime.now());
    if (diff.isNegative) {
      return 0;
    }
    return ((diff.inMilliseconds + 999) ~/ 1000).clamp(0, 7);
  }

  Future<void> _openRaiseSheet() async {
    if (!_isHeroActive) {
      return;
    }

    if (_maxRaiseExtra < _minRaiseExtra) {
      return;
    }

    var tempRaise = _selectedRaiseExtra.clamp(_minRaiseExtra, _maxRaiseExtra);
    final result = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: const Color(0xFF08130F),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _callAmountFor(0) == 0 ? 'Bet' : 'Raise',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Размер докида',
                          style: TextStyle(
                            color: AppTheme.mutedText,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Text(
                        tempRaise >= _maxRaiseExtra ? 'ALL IN' : '$tempRaise',
                        style: const TextStyle(
                          color: AppTheme.primary,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    value: tempRaise.toDouble(),
                    min: _minRaiseExtra.toDouble(),
                    max: _maxRaiseExtra.toDouble(),
                    divisions: math.max(
                      1,
                      ((_maxRaiseExtra - _minRaiseExtra) ~/ 10),
                    ).toInt(),
                    onChanged: (value) {
                      setModalState(() {
                        tempRaise = value.round();
                      });
                    },
                  ),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => Navigator.of(context).pop(tempRaise),
                      child: const Text('Подтвердить raise'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (!mounted || result == null) {
      return;
    }

    setState(() {
      _selectedRaiseExtra = result;
    });
    _applyAction(0, _TrainingAction.raise);
  }

  bool _tryStartAllInRunout() {
    final livePlayers = _players.where((item) => !item.isFolded).toList();
    if (livePlayers.length < 2) {
      return false;
    }
    final anyAllIn = livePlayers.any((item) => item.chips <= 0);
    final actionablePlayers = livePlayers.where((item) => item.chips > 0).toList();
    final allMatched = livePlayers.every(
      (item) => item.streetContribution == _currentBet,
    );
    if (!anyAllIn || actionablePlayers.length >= 2 || !allMatched) {
      return false;
    }

    _turnTicker?.cancel();
    _botActionTimer?.cancel();
    _showdownTicker?.cancel();
    _runoutTimer?.cancel();
    _handLocked = true;
    _activeIndex = -1;
    _scheduleAllInRunoutStep();
    return true;
  }

  void _scheduleAllInRunoutStep() {
    _runoutTimer?.cancel();
    _runoutTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted) {
        return;
      }

      if (_communityCards.length >= 5) {
        _startShowdown();
        return;
      }

      setState(() {
        if (_communityCards.length < 3) {
          _street = _TrainingStreet.flop;
          _communityCards = [_drawCard(), _drawCard(), _drawCard()];
        } else if (_communityCards.length == 3) {
          _street = _TrainingStreet.turn;
          _communityCards = [..._communityCards, _drawCard()];
        } else {
          _street = _TrainingStreet.river;
          _communityCards = [..._communityCards, _drawCard()];
        }
      });

      _scheduleAllInRunoutStep();
    });
  }

  void _startShowdown() {
    _handLocked = false;
    _isShowdownPhase = true;
    _showdownPendingPlayers = [for (var i = 0; i < _players.length; i++) i];
    _revealedPlayers.clear();
    _showdownEndsAt = DateTime.now().add(_showdownDuration);
    _showdownTicker?.cancel();
    _showdownTicker = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (!mounted) {
        return;
      }
      if (_showdownEndsAt != null && DateTime.now().isAfter(_showdownEndsAt!)) {
        _resolveShowdownTimeout();
        return;
      }
      setState(() {});
    });
    _scheduleBotShowdowns();
    setState(() {});
  }

  void _scheduleBotShowdowns() {
    for (final index in _showdownPendingPlayers.where((item) => item != 0)) {
      Future<void>.delayed(
        Duration(milliseconds: 800 + _random.nextInt(2200)),
        () {
          if (!mounted ||
              !_isShowdownPhase ||
              !_showdownPendingPlayers.contains(index)) {
            return;
          }
          _revealPlayerCards(index);
        },
      );
    }
  }

  void _revealPlayerCards(int playerIndex) {
    if (!_isShowdownPhase || !_showdownPendingPlayers.contains(playerIndex)) {
      return;
    }
    _showdownPendingPlayers.remove(playerIndex);
    _revealedPlayers.add(playerIndex);
    _players[playerIndex].lastAction = 'show';
    _finishShowdownIfReady();
    setState(() {});
  }

  void _resolveShowdownTimeout() {
    _showdownTicker?.cancel();
    for (final index in List<int>.from(_showdownPendingPlayers)) {
      _players[index].lastAction = 'hide';
    }
    _showdownPendingPlayers.clear();
    _finishShowdownIfReady();
    setState(() {});
  }

  void _finishShowdownIfReady() {
    if (_showdownPendingPlayers.isNotEmpty) {
      return;
    }
    final revealedLive = <int>{
      for (var i = 0; i < _players.length; i++)
        if (!_players[i].isFolded && _revealedPlayers.contains(i)) i,
    };
    if (revealedLive.isNotEmpty) {
      for (var i = 0; i < _players.length; i++) {
        if (!_players[i].isFolded && !revealedLive.contains(i)) {
          _players[i]
            ..isFolded = true
            ..lastAction = 'hide';
        }
      }
    }

    final pots = _buildTrainingSidePots();
    final payouts = <int, int>{};
    for (final pot in pots) {
      final contenders = pot.eligibleIndexes
          .where((index) => !_players[index].isFolded)
          .toList();
      if (contenders.isEmpty) {
        continue;
      }
      final ranked = <int, PokerHandEvaluation>{
        for (final index in contenders) index: _evaluateTrainingHand(index),
      };
      var winners = <int>[contenders.first];
      var best = ranked[contenders.first]!;
      for (final contender in contenders.skip(1)) {
        final compare = comparePokerHands(ranked[contender]!, best);
        if (compare > 0) {
          winners = [contender];
          best = ranked[contender]!;
        } else if (compare == 0) {
          winners.add(contender);
        }
      }
      final share = pot.amount ~/ winners.length;
      var remainder = pot.amount % winners.length;
      for (final winner in winners) {
        payouts[winner] = (payouts[winner] ?? 0) + share + (remainder > 0 ? 1 : 0);
        if (remainder > 0) {
          remainder -= 1;
        }
      }
    }

    final winnerIndexes = payouts.entries
        .where((entry) => entry.value > 0)
        .map((entry) => entry.key)
        .toList();
    for (final entry in payouts.entries) {
      _players[entry.key]
        ..chips += entry.value
        ..lastAction = 'wins';
    }
    _handLocked = true;
    _isShowdownPhase = false;
    _showdownEndsAt = null;
    _activeIndex = winnerIndexes.isNotEmpty ? winnerIndexes.first : 0;
    _winnerBanner = winnerIndexes.isEmpty
        ? 'Банк разыгран'
        : winnerIndexes.length == 1
        ? '${_players[winnerIndexes.first].identity.displayName} выиграл банк'
        : '${winnerIndexes.map((i) => _players[i].identity.displayName).join(', ')} поделили банк';
    _showdownTicker?.cancel();
    _runoutTimer?.cancel();
    setState(() {});
    _nextHandTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) {
        return;
      }
      _startNewHand();
    });
  }

  List<_TrainingSidePot> _buildTrainingSidePots() {
    final contributors = <int>[
      for (var i = 0; i < _players.length; i++)
        if (_players[i].handContribution > 0) i,
    ];
    if (contributors.isEmpty) {
      return const [];
    }
    final levels = contributors
        .map((index) => _players[index].handContribution)
        .toSet()
        .toList()
      ..sort();
    final pots = <_TrainingSidePot>[];
    var previous = 0;
    for (final level in levels) {
      final participants = contributors
          .where((index) => _players[index].handContribution >= level)
          .toList();
      final amount = (level - previous) * participants.length;
      if (amount > 0) {
        pots.add(
          _TrainingSidePot(
            amount: amount,
            eligibleIndexes: [
              for (final index in participants)
                if (!_players[index].isFolded) index,
            ],
          ),
        );
      }
      previous = level;
    }
    return pots;
  }

  PokerHandEvaluation _evaluateTrainingHand(int playerIndex) {
    return evaluateBestPokerHand([
      for (final card in _players[playerIndex].cards)
        PokerEvalCard(rank: card.rankValue, suit: card.suit),
      for (final card in _communityCards)
        PokerEvalCard(rank: card.rankValue, suit: card.suit),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.profileController.profile;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.18),
            radius: 1.15,
            colors: [Color(0xFF0F3A26), Color(0xFF0B2B1C), Color(0xFF081E14)],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final screenWidth = constraints.maxWidth;
              final screenHeight = constraints.maxHeight;
              final isCompactLandscape = screenHeight < 390;
              final actionWidth = math.min(
                isCompactLandscape ? 312.0 : 360.0,
                screenWidth * 0.40,
              );
              final seatWidth = math.min(
                isCompactLandscape ? 120.0 : 148.0,
                screenWidth * 0.17,
              );
              final tableWidth = math.min(screenWidth * 0.70, 760.0);
              final tableHeight = math.min(
                screenHeight * 0.60,
                isCompactLandscape ? 272.0 : 304.0,
              );
              final heroWidth = math.min(
                isCompactLandscape ? 244.0 : 276.0,
                screenWidth * 0.31,
              );
              final tableLeft = (screenWidth - tableWidth) / 2;
              final tableTop = math.max(
                68.0,
                (screenHeight - tableHeight) / 2 - 2,
              );
              final topLeftSeatX = tableLeft + tableWidth * 0.02;
              final topCenterSeatX = tableLeft + (tableWidth - seatWidth) / 2;
              final topRightSeatX =
                  tableLeft + tableWidth - seatWidth - tableWidth * 0.02;
              final topLeftSeatY = math.max(8.0, tableTop - 44);
              final topCenterSeatY = math.max(4.0, tableTop - 46);
              final topRightSeatY = math.max(8.0, tableTop - 44);
              final leftSeatX = math.max(10.0, tableLeft - seatWidth * 0.50);
              final leftSeatY = tableTop + tableHeight * 0.42;
              final rightSeatX = math.min(
                screenWidth - seatWidth - 10,
                tableLeft + tableWidth - seatWidth * 0.18,
              );
              final rightSeatY = tableTop + tableHeight * 0.28;
              final heroBottom = 10.0;
              final heroLeft = math.max(
                14.0,
                (screenWidth - actionWidth - heroWidth - 34) / 2,
              );

              final positions = [
                _SeatLayout(left: leftSeatX, top: leftSeatY),
                _SeatLayout(left: topLeftSeatX, top: topLeftSeatY),
                _SeatLayout(left: topCenterSeatX, top: topCenterSeatY),
                _SeatLayout(left: topRightSeatX, top: topRightSeatY),
                _SeatLayout(left: rightSeatX, top: rightSeatY),
              ];

              return Stack(
                children: [
                  Positioned(
                    left: tableLeft,
                    top: tableTop,
                    child: PokerTableSurface(
                      width: tableWidth,
                      height: tableHeight,
                      pot: _pot,
                      streetLabel: _streetLabel,
                      communityCards: _communityCardViews,
                    ),
                  ),
                  Positioned(
                    top: 8,
                    left: 8,
                    child: _TableBackButton(
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                  for (var i = 0; i < positions.length; i++)
                    Positioned(
                      left: positions[i].left,
                      top: positions[i].top,
                      child: TablePlayerSeat(
                        width: seatWidth,
                        name: _players[i + 1].identity.displayName,
                        chips: _players[i + 1].chips,
                        avatarSeed: _players[i + 1].identity.avatarSeed,
                        avatarPath: _players[i + 1].identity.avatarPath,
                        avatarType: _players[i + 1].identity.avatarType,
                        avatarBytes: _players[i + 1].identity.avatarBytes,
                        statusLabel: _players[i + 1].lastAction,
                        isActive: _activeIndex == i + 1 && !_handLocked,
                        isDealer: _players[i + 1].isDealer,
                        isFolded: _players[i + 1].isFolded,
                        turnProgress: _seatTurnProgress(i + 1),
                        revealedCards: _revealedPlayers.contains(i + 1)
                            ? _players[i + 1].cards
                                .map(
                                  (card) => TableSeatCard(
                                    rank: card.rank,
                                    suit: card.suit,
                                  ),
                                )
                                .toList()
                            : null,
                      ),
                    ),
                  Positioned(
                    left: heroLeft,
                    bottom: heroBottom,
                    child: _HeroPlayerPanel(
                      width: heroWidth,
                      profile: profile,
                      isObserverMode: false,
                      chips: _players.first.chips,
                      isDealer: _players.first.isDealer,
                      isActive: _isHeroActive,
                      turnProgress: _heroTurnProgress,
                      cards: _players.first.cards,
                      comboLabel: _heroHandInsight.label,
                      highlightedCardIndexes: _heroHandInsight.highlightedHeroIndexes,
                    ),
                  ),
                  if (_winnerBanner.isNotEmpty)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: Center(
                          child: Transform.translate(
                            offset: const Offset(0, -18),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF08130F).withAlpha(230),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: AppTheme.primary.withAlpha(80),
                                ),
                              ),
                              child: Text(
                                _winnerBanner,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  Positioned(
                    right: 14,
                    bottom: heroBottom,
                    width: actionWidth,
                    height: isCompactLandscape ? 58 : 64,
                    child: _buildTrainingActionBar(),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildTrainingActionBar() {
    if (_isShowdownPhase) {
      return _TrainingSingleActionBar(
        label: '$_singleActionLabel • $_showdownRemaining',
        onPressed: () => _revealPlayerCards(0),
      );
    }

    if (!_isHeroActive) {
      return const SizedBox.shrink();
    }

    return TableActionBar(
      onFold: () => _applyAction(0, _TrainingAction.fold),
      onCall: () => _applyAction(
        0,
        _callAmountFor(0) == 0 ? _TrainingAction.check : _TrainingAction.call,
      ),
      onRaise: _openRaiseSheet,
      callLabel: _callButtonLabel,
      raiseLabel: _raiseButtonLabel,
      isEnabled: true,
      isRaiseEnabled: _maxRaiseExtra >= _minRaiseExtra,
    );
  }
}

class _TableBackButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _TableBackButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF07100D).withAlpha(210),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withAlpha(20)),
          ),
          child: const Icon(
            Icons.arrow_back_rounded,
            color: Colors.white,
            size: 18,
          ),
        ),
      ),
    );
  }
}

class _TrainingSingleActionBar extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const _TrainingSingleActionBar({
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFF08130F).withAlpha(232),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withAlpha(18)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(88),
            blurRadius: 22,
            offset: const Offset(0, 11),
          ),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: AppTheme.primary,
            foregroundColor: const Color(0xFF14100A),
          ),
          child: Text(label),
        ),
      ),
    );
  }
}

class _HeroPlayerPanel extends StatelessWidget {
  final double width;
  final PlayerProfile profile;
  final bool isObserverMode;
  final int chips;
  final bool isDealer;
  final bool isActive;
  final double turnProgress;
  final List<_TrainingCard>? cards;
  final String comboLabel;
  final Set<int> highlightedCardIndexes;

  const _HeroPlayerPanel({
    required this.width,
    required this.profile,
    required this.isObserverMode,
    required this.chips,
    this.isDealer = false,
    this.isActive = false,
    this.turnProgress = 0,
    this.cards,
    this.comboLabel = 'High Card',
    this.highlightedCardIndexes = const {},
  });

  @override
  Widget build(BuildContext context) {
    final isCompact = width < 250;
    final hasComboLabel = comboLabel.trim().isNotEmpty;
    final avatarSize = isCompact ? 42.0 : 48.0;
    final nameFontSize = isCompact ? 13.0 : 14.0;
    final chipsFontSize = isCompact ? 10.0 : 11.0;
    final cardWidth = isCompact ? 28.0 : 34.0;
    final cardHeight = isCompact ? 40.0 : 48.0;

    return SizedBox(
      width: width,
      child: CustomPaint(
        foregroundPainter: isActive
            ? _HeroTurnBorderPainter(
                progress: turnProgress == 0 ? 0.72 : turnProgress,
                borderRadius: 26,
              )
            : null,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          decoration: BoxDecoration(
            color: const Color(0xFF08130F).withAlpha(235),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(
              color: isActive
                  ? AppTheme.primary.withAlpha(180)
                  : AppTheme.primary.withAlpha(110),
            ),
            boxShadow: [
              BoxShadow(
                color: isActive
                    ? AppTheme.primary.withAlpha(60)
                    : Colors.black.withAlpha(95),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              if (isDealer)
                const Positioned(
                  top: -8,
                  right: -6,
                  child: _HeroDealerChip(),
                ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      PlayerAvatar(
                        seed: profile.avatarSeed,
                        avatarPath: profile.avatarPath,
                        avatarType: profile.avatarType,
                        size: avatarSize,
                        isSelected: true,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              profile.displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: nameFontSize,
                                height: 1,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              '$chips фишек',
                              style: TextStyle(
                                color: AppTheme.mutedText,
                                fontSize: chipsFontSize,
                                height: 1,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (isObserverMode)
                              const _HeroObserverHint()
                            else
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerLeft,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        PlayingCardView(
                                          rank: cards?[0].rank ?? 'J',
                                          suit: cards?[0].suit ?? '♣',
                                          width: cardWidth,
                                          height: cardHeight,
                                          isHighlighted:
                                              highlightedCardIndexes.contains(0),
                                        ),
                                        SizedBox(width: isCompact ? 5 : 7),
                                        PlayingCardView(
                                          rank: cards?[1].rank ?? '10',
                                          suit: cards?[1].suit ?? '♣',
                                          width: cardWidth,
                                          height: cardHeight,
                                          isHighlighted:
                                              highlightedCardIndexes.contains(1),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (hasComboLabel) ...[
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.only(bottom: 2),
                                        child: Text(
                                          comboLabel,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: AppTheme.primary,
                                            fontSize: isCompact ? 11 : 12,
                                            height: 1.15,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroTurnBorderPainter extends CustomPainter {
  final double progress;
  final double borderRadius;

  const _HeroTurnBorderPainter({
    required this.progress,
    required this.borderRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) {
      return;
    }

    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(
      rect.deflate(0.8),
      Radius.circular(borderRadius),
    );

    final metrics = (Path()..addRRect(rrect)).computeMetrics().toList();
    if (metrics.isEmpty) {
      return;
    }

    final metric = metrics.first;
    final activePath = metric.extractPath(
      0,
      metric.length * progress.clamp(0.0, 1.0),
    );

    final glowPaint = Paint()
      ..color = AppTheme.primary.withAlpha(70)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

    final paint = Paint()
      ..color = AppTheme.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(activePath, glowPaint);
    canvas.drawPath(activePath, paint);
  }

  @override
  bool shouldRepaint(covariant _HeroTurnBorderPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.borderRadius != borderRadius;
  }
}

class _HeroDealerChip extends StatelessWidget {
  const _HeroDealerChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBF0),
        shape: BoxShape.circle,
        border: Border.all(color: AppTheme.primary, width: 1.7),
      ),
      child: const Center(
        child: Text(
          'D',
          style: TextStyle(
            color: Color(0xFF14100A),
            fontSize: 10,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _HeroObserverHint extends StatelessWidget {
  const _HeroObserverHint();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0F2018),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withAlpha(10)),
      ),
      child: const Row(
        children: [
          Icon(Icons.wifi_tethering_rounded, color: AppTheme.primary, size: 16),
          SizedBox(width: 7),
          Expanded(
            child: Text(
              'Сейчас вы смотрите стол. Карты появятся после подключения к игре.',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white,
                fontSize: 10,
                height: 1.2,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LobbyCenterCard extends StatelessWidget {
  final LobbySession lobby;
  final bool isHost;
  final bool canHostStart;
  final bool isStarting;
  final VoidCallback? onStart;

  const _LobbyCenterCard({
    required this.lobby,
    required this.isHost,
    required this.canHostStart,
    required this.isStarting,
    required this.onStart,
  });

  @override
  Widget build(BuildContext context) {
    final canStart = lobby.connectedPlayersCount >= 2;

    return Container(
      constraints: const BoxConstraints(maxWidth: 280),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF0A1712).withAlpha(236),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: AppTheme.primary.withAlpha(70)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(90),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isStarting) ...[
            _CountdownStatus(endAt: lobby.countdownEndsAt!),
          ] else if (!canStart) ...[
            const Text(
              'Ожидание игроков',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            ),
          ] else ...[
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: canHostStart ? onStart : null,
                style: FilledButton.styleFrom(
                  backgroundColor: canHostStart
                      ? AppTheme.primary
                      : Colors.white.withAlpha(10),
                  foregroundColor: canHostStart
                      ? const Color(0xFF14100A)
                      : Colors.white,
                ),
                child: Text(
                  isHost
                      ? (canHostStart ? 'Начать игру' : 'Вернитесь за стол')
                      : 'Ждём хоста',
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TopQrButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _TopQrButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF091611).withAlpha(232),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withAlpha(18)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.qr_code_rounded, color: AppTheme.primary, size: 16),
              SizedBox(width: 6),
              Text(
                'QR',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ObserverToggleButton extends StatelessWidget {
  final int observersCount;
  final bool isObserver;
  final bool isPending;
  final VoidCallback onPressed;

  const _ObserverToggleButton({
    required this.observersCount,
    required this.isObserver,
    required this.isPending,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final showCount = observersCount > 0;

    return Material(
      color: const Color(0xFF091611).withAlpha(232),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: showCount ? 12 : 10,
            vertical: 7,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: (isObserver || isPending)
                  ? AppTheme.primary.withAlpha(100)
                  : Colors.white.withAlpha(18),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isObserver
                    ? Icons.visibility
                    : isPending
                    ? Icons.schedule_rounded
                    : Icons.visibility_outlined,
                color: AppTheme.primary,
                size: 16,
              ),
              if (showCount) ...[
                const SizedBox(width: 6),
                Text(
                  '$observersCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyLobbySeat extends StatelessWidget {
  final double width;

  const _EmptyLobbySeat({required this.width});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0C1612).withAlpha(200),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: Colors.white.withAlpha(16),
          style: BorderStyle.solid,
        ),
      ),
      child: const Row(
        children: [
          Icon(Icons.person_add_alt_1_rounded, color: AppTheme.mutedText),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Свободно',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppTheme.mutedText,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SeatLayout {
  final double left;
  final double top;

  const _SeatLayout({required this.left, required this.top});
}

class _CountdownStatus extends StatelessWidget {
  final DateTime endAt;

  const _CountdownStatus({required this.endAt});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: Stream.periodic(
        const Duration(seconds: 1),
        (_) => DateTime.now().millisecondsSinceEpoch,
      ),
      initialData: DateTime.now().millisecondsSinceEpoch,
      builder: (context, snapshot) {
        final now = DateTime.now();
        final diff = endAt.difference(now);
        final remaining = diff.isNegative
            ? 0
            : ((diff.inMilliseconds + 999) ~/ 1000).clamp(0, 3);

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Игра началась',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(
              'Старт через $remaining',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppTheme.mutedText,
                height: 1.4,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        );
      },
    );
  }
}

enum _TrainingStreet { preflop, flop, turn, river }

enum _TrainingAction { fold, check, call, raise }

class _TrainingCard {
  final String rank;
  final String suit;

  const _TrainingCard({required this.rank, required this.suit});

  int get rankValue => switch (rank) {
    'A' => 14,
    'K' => 13,
    'Q' => 12,
    'J' => 11,
    '10' => 10,
    '9' => 9,
    '8' => 8,
    '7' => 7,
    '6' => 6,
    '5' => 5,
    '4' => 4,
    '3' => 3,
    '2' => 2,
    _ => 0,
  };
}

class _TrainingPlayerState {
  final PlayerIdentity identity;
  final bool isHero;
  int chips;
  bool isFolded = false;
  bool isDealer = false;
  int streetContribution = 0;
  int handContribution = 0;
  String lastAction = '';
  List<_TrainingCard> cards;

  _TrainingPlayerState({
    required this.identity,
    required this.chips,
    required this.cards,
    this.isHero = false,
  });
}

enum _CardZone { hero, board }

class _CardSpot {
  final _CardZone zone;
  final int index;
  final _TrainingCard card;

  const _CardSpot({
    required this.zone,
    required this.index,
    required this.card,
  });
}

class _HeroHandInsight {
  final String label;
  final Set<int> highlightedHeroIndexes;
  final Set<int> highlightedBoardIndexes;

  const _HeroHandInsight({
    required this.label,
    required this.highlightedHeroIndexes,
    required this.highlightedBoardIndexes,
  });
}

class _TrainingSidePot {
  final int amount;
  final List<int> eligibleIndexes;

  const _TrainingSidePot({
    required this.amount,
    required this.eligibleIndexes,
  });
}

class _StartedLobbyState {
  final int pot;
  final String streetLabel;
  final List<Widget> communityCards;
  final String dealerKey;
  final String activePlayerKey;
  final Map<String, String> statusByPlayerKey;

  const _StartedLobbyState({
    required this.pot,
    required this.streetLabel,
    required this.communityCards,
    required this.dealerKey,
    required this.activePlayerKey,
    required this.statusByPlayerKey,
  });

  const _StartedLobbyState.empty()
    : pot = 0,
      streetLabel = 'Lobby',
      communityCards = const [],
      dealerKey = '',
      activePlayerKey = '',
      statusByPlayerKey = const {};
}

class _DemoScenario {
  final int pot;
  final String streetLabel;
  final int dealerIndex;
  final int activeIndex;
  final List<String> statuses;
  final List<Widget> communityCards;

  const _DemoScenario({
    required this.pot,
    required this.streetLabel,
    required this.dealerIndex,
    required this.activeIndex,
    required this.statuses,
    required this.communityCards,
  });
}

const List<_DemoScenario> _demoScenarios = [
  _DemoScenario(
    pot: 120,
    streetLabel: 'Flop',
    dealerIndex: 0,
    activeIndex: 1,
    statuses: ['check', 'думает', 'call', 'fold', 'raise'],
    communityCards: [
      PlayingCardView(rank: 'A', suit: '♠', width: 42, height: 58),
      PlayingCardView(rank: '10', suit: '♥', width: 42, height: 58),
      PlayingCardView(rank: '4', suit: '♣', width: 42, height: 58),
    ],
  ),
  _DemoScenario(
    pot: 260,
    streetLabel: 'Turn',
    dealerIndex: 1,
    activeIndex: 2,
    statuses: ['call', 'check', 'думает', 'raise', 'fold'],
    communityCards: [
      PlayingCardView(rank: 'K', suit: '♦', width: 42, height: 58),
      PlayingCardView(rank: '9', suit: '♣', width: 42, height: 58),
      PlayingCardView(rank: '9', suit: '♠', width: 42, height: 58),
      PlayingCardView(rank: '2', suit: '♥', width: 42, height: 58),
    ],
  ),
  _DemoScenario(
    pot: 420,
    streetLabel: 'River',
    dealerIndex: 2,
    activeIndex: 0,
    statuses: ['думает', 'fold', 'check', 'call', 'all-in'],
    communityCards: [
      PlayingCardView(rank: 'Q', suit: '♠', width: 42, height: 58),
      PlayingCardView(rank: 'Q', suit: '♥', width: 42, height: 58),
      PlayingCardView(rank: '7', suit: '♦', width: 42, height: 58),
      PlayingCardView(rank: '5', suit: '♣', width: 42, height: 58),
      PlayingCardView(rank: 'A', suit: '♣', width: 42, height: 58),
    ],
  ),
  _DemoScenario(
    pot: 80,
    streetLabel: 'Preflop',
    dealerIndex: 0,
    activeIndex: 3,
    statuses: ['small blind', 'big blind', 'call', 'думает', 'fold'],
    communityCards: [],
  ),
];
