import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:poker_phone/app/app_theme.dart';
import 'package:poker_phone/core/widgets/app_toast.dart';
import 'package:poker_phone/core/widgets/player_avatar.dart';
import 'package:poker_phone/features/lobby/domain/player_identity.dart';
import 'package:poker_phone/features/lobby/presentation/lobby_controller.dart';
import 'package:poker_phone/features/lobby/presentation/qr_join_scanner_screen.dart';
import 'package:poker_phone/features/profile/presentation/profile_controller.dart';
import 'package:poker_phone/features/table/presentation/poker_table_preview_screen.dart';

class JoinLobbyScreen extends StatefulWidget {
  final ProfileController profileController;
  final LobbyController lobbyController;

  const JoinLobbyScreen({
    super.key,
    required this.profileController,
    required this.lobbyController,
  });

  @override
  State<JoinLobbyScreen> createState() => _JoinLobbyScreenState();
}

class _JoinLobbyScreenState extends State<JoinLobbyScreen> {
  Timer? _autoDiscoverTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _discoverHosts(showEmptyToast: false);
    });
    _autoDiscoverTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (!mounted ||
          widget.lobbyController.isDiscovering ||
          widget.lobbyController.isConnecting) {
        return;
      }
      _discoverHosts(showEmptyToast: false);
    });
  }

  @override
  void dispose() {
    _autoDiscoverTimer?.cancel();
    super.dispose();
  }

  Future<void> _connectToHostAddress(DiscoveredLobbyHost host) async {
    final lobby = await widget.lobbyController.connectToHost(
      host: host.address,
      port: host.port,
      player: PlayerIdentity.fromProfile(widget.profileController.profile),
      lobbyId: host.lobby.id,
    );

    if (!mounted) {
      return;
    }

    if (lobby == null) {
      showAppToast(
        context,
        message: widget.lobbyController.lastError ?? 'Не удалось открыть лобби',
        type: AppToastType.error,
      );
      return;
    }

    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    if (!mounted) {
      return;
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => PokerTablePreviewScreen(
          profileController: widget.profileController,
          lobbyController: widget.lobbyController,
          lobbyId: lobby.id,
        ),
      ),
    );
  }

  Future<void> _discoverHosts({required bool showEmptyToast}) async {
    await widget.lobbyController.discoverHosts();
    if (!mounted) {
      return;
    }

    if (widget.lobbyController.discoveredHosts.isEmpty &&
        (widget.lobbyController.lastError ?? '').isEmpty &&
        showEmptyToast) {
      showAppToast(
        context,
        message: 'Активные хосты в локальной сети не найдены',
        type: AppToastType.info,
      );
    }
  }

  Future<void> _scanQrCode() async {
    final result = await Navigator.of(context).push<QrJoinScanResult>(
      MaterialPageRoute(builder: (_) => const QrJoinScannerScreen()),
    );

    if (!mounted || result == null) {
      return;
    }

    final lobby = await widget.lobbyController.connectToHost(
      host: result.host,
      port: result.port,
      player: PlayerIdentity.fromProfile(widget.profileController.profile),
      lobbyId: result.lobbyId,
    );

    if (!mounted) {
      return;
    }

    if (lobby == null) {
      showAppToast(
        context,
        message:
            widget.lobbyController.lastError ?? 'Не удалось подключиться по QR',
        type: AppToastType.error,
      );
      return;
    }

    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    if (!mounted) {
      return;
    }

    final targetLobbyId = result.lobbyId.isNotEmpty ? result.lobbyId : lobby.id;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => PokerTablePreviewScreen(
          profileController: widget.profileController,
          lobbyController: widget.lobbyController,
          lobbyId: targetLobbyId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: const Text('Подключиться')),
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topCenter,
            radius: 1.24,
            colors: [Color(0xFF204130), Color(0xFF0F231B), Color(0xFF06100C)],
          ),
        ),
        child: SafeArea(
          child: ListenableBuilder(
            listenable: widget.lobbyController,
            builder: (context, _) {
              final discoveredHosts = widget.lobbyController.discoveredHosts;
              final showEmptyDiscoveryHint =
                  !widget.lobbyController.isDiscovering &&
                  discoveredHosts.isEmpty;

              return ListView(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0B1914).withAlpha(235),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: Colors.white.withAlpha(10)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Вход по LAN',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          discoveredHosts.isEmpty
                              ? 'Ищем столы автоматически. Если стол не найден, подключись через QR-код.'
                              : 'Найденные столы появятся ниже. Если нужно, можно сразу подключиться через QR-код.',
                          style: const TextStyle(
                            color: AppTheme.mutedText,
                            height: 1.45,
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.tonal(
                            onPressed: _scanQrCode,
                            style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(54),
                            ),
                            child: const Text('QR-код'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  if (showEmptyDiscoveryHint)
                    const _EmptyDiscoveryCard()
                  else ...[
                    const Text(
                      'Найдено в сети',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 12),
                    for (final host in discoveredHosts) ...[
                      _DiscoveredHostCard(
                        host: host,
                        onConnect: () {
                          _connectToHostAddress(host);
                        },
                      ),
                      const SizedBox(height: 12),
                    ],
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _EmptyDiscoveryCard extends StatelessWidget {
  const _EmptyDiscoveryCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFF0A1712).withAlpha(235),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: Colors.white.withAlpha(10)),
      ),
      child: const Column(
        children: [
          Icon(Icons.wifi_find_rounded, color: AppTheme.primary, size: 38),
          SizedBox(height: 12),
          Text(
            'Столы не найдены',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
          ),
          SizedBox(height: 8),
          Text(
            'Попробуйте подключение через QR-код или проверьте, что оба устройства в одной сети Wi-Fi.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.mutedText, height: 1.45),
          ),
        ],
      ),
    );
  }
}

class _DiscoveredHostCard extends StatelessWidget {
  final DiscoveredLobbyHost host;
  final VoidCallback onConnect;

  const _DiscoveredHostCard({required this.host, required this.onConnect});

  @override
  Widget build(BuildContext context) {
    final lobby = host.lobby;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF0A1712).withAlpha(235),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: Colors.white.withAlpha(10)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withAlpha(10),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppTheme.primary.withAlpha(50)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(3),
                  child: PlayerAvatar(
                    seed: lobby.settings.host.avatarSeed,
                    avatarPath: lobby.settings.host.avatarPath,
                    avatarType: lobby.settings.host.avatarType,
                    avatarBytes: lobby.settings.host.avatarBytes,
                    size: 46,
                    isSelected: true,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lobby.settings.displayLobbyName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Хост: ${lobby.settings.host.displayName}',
                      style: const TextStyle(
                        color: AppTheme.mutedText,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${lobby.connectedPlayersCount}/${lobby.settings.seatsCount}',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onConnect,
              child: const Text('Войти'),
            ),
          ),
        ],
      ),
    );
  }
}
