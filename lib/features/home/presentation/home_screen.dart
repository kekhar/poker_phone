import 'package:flutter/material.dart';
import 'package:poker_phone/app/app_theme.dart';
import 'package:poker_phone/core/constants/app_constants.dart';
import 'package:poker_phone/features/home/presentation/widgets/home_action_button.dart';
import 'package:poker_phone/features/home/presentation/widgets/home_logo_block.dart';
import 'package:poker_phone/features/home/presentation/widgets/home_top_bar.dart';
import 'package:poker_phone/features/lobby/presentation/lobby_controller.dart';
import 'package:poker_phone/features/lobby/presentation/host_setup_screen.dart';
import 'package:poker_phone/features/lobby/presentation/join_lobby_screen.dart';
import 'package:poker_phone/features/profile/presentation/profile_controller.dart';
import 'package:poker_phone/features/settings/presentation/settings_screen.dart';
import 'package:poker_phone/features/table/presentation/poker_table_preview_screen.dart';
import 'package:poker_phone/core/widgets/app_toast.dart';

class HomeScreen extends StatelessWidget {
  final ProfileController profileController;
  final LobbyController lobbyController;

  const HomeScreen({
    super.key,
    required this.profileController,
    required this.lobbyController,
  });

  void _openTablePreview(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            PokerTablePreviewScreen(profileController: profileController),
      ),
    );
  }

  void _openHostSetup(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => HostSetupScreen(
          profileController: profileController,
          lobbyController: lobbyController,
        ),
      ),
    );
  }

  void _openJoinLobbies(BuildContext context) {
    Navigator.of(
      context,
    ).push(
      MaterialPageRoute(
        builder: (_) => JoinLobbyScreen(
          profileController: profileController,
          lobbyController: lobbyController,
        ),
      ),
    );
  }

  Future<void> _openSettings(BuildContext context) async {
    final wasSaved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => SettingsScreen(profileController: profileController),
      ),
    );

    if (!context.mounted) return;

    if (wasSaved == true) {
      showAppToast(
        context,
        message: 'Профиль обновлён',
        type: AppToastType.success,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final playerName = profileController.profile.displayName;

    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topCenter,
            radius: 1.25,
            colors: [Color(0xFF264D3A), Color(0xFF10251D), Color(0xFF08110E)],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isLandscape = constraints.maxWidth > constraints.maxHeight;
              final horizontalPadding = isLandscape ? 24.0 : 20.0;
              final topPadding = isLandscape ? 14.0 : 18.0;
              final bottomPadding = isLandscape ? 16.0 : 22.0;

              return Padding(
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  topPadding,
                  horizontalPadding,
                  bottomPadding,
                ),
                child: SizedBox(
                  height: constraints.maxHeight - topPadding - bottomPadding,
                  child: isLandscape
                      ? _HomeLandscapeLayout(
                          playerName: playerName,
                          profileController: profileController,
                          onSettingsPressed: () => _openSettings(context),
                          onOpenTable: () => _openTablePreview(context),
                          onOpenHost: () => _openHostSetup(context),
                          onOpenJoin: () => _openJoinLobbies(context),
                        )
                      : _HomePortraitLayout(
                          playerName: playerName,
                          profileController: profileController,
                          onSettingsPressed: () => _openSettings(context),
                          onOpenTable: () => _openTablePreview(context),
                          onOpenHost: () => _openHostSetup(context),
                          onOpenJoin: () => _openJoinLobbies(context),
                        ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _HomePortraitLayout extends StatelessWidget {
  final String playerName;
  final ProfileController profileController;
  final VoidCallback onSettingsPressed;
  final VoidCallback onOpenTable;
  final VoidCallback onOpenHost;
  final VoidCallback onOpenJoin;

  const _HomePortraitLayout({
    required this.playerName,
    required this.profileController,
    required this.onSettingsPressed,
    required this.onOpenTable,
    required this.onOpenHost,
    required this.onOpenJoin,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isTight = constraints.maxHeight < 760;

        return Column(
          mainAxisSize: MainAxisSize.max,
          children: [
            HomeTopBar(
              profileController: profileController,
              onSettingsPressed: onSettingsPressed,
            ),
            SizedBox(height: isTight ? 8 : 12),
            Expanded(
              flex: isTight ? 6 : 7,
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: HomeLogoBlock(
                    playerName: playerName,
                    compact: isTight,
                  ),
                ),
              ),
            ),
            SizedBox(height: isTight ? 10 : 18),
            Expanded(
              flex: isTight ? 9 : 8,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  HomeActionButton(
                    title: 'Создать лобби',
                    subtitle: '$playerName будет хостом стола',
                    icon: Icons.add_rounded,
                    isPrimary: true,
                    onPressed: onOpenHost,
                  ),
                  SizedBox(height: isTight ? 10 : 12),
                  HomeActionButton(
                    title: 'Подключиться',
                    subtitle: 'Войти к другу по QR-коду или IP',
                    icon: Icons.wifi_tethering_rounded,
                    onPressed: onOpenJoin,
                  ),
                  SizedBox(height: isTight ? 10 : 12),
                  HomeActionButton(
                    title: 'Тренировочный стол',
                    subtitle: 'Проверим раздачу и интерфейс',
                    icon: Icons.style_rounded,
                    onPressed: onOpenTable,
                  ),
                ],
              ),
            ),
            SizedBox(height: isTight ? 10 : 14),
            Text(
              '${AppConstants.pokerMode} · 2–6 игроков · локальная сеть',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.softText,
                fontSize: isTight ? 11 : 12,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _HomeLandscapeLayout extends StatelessWidget {
  final String playerName;
  final ProfileController profileController;
  final VoidCallback onSettingsPressed;
  final VoidCallback onOpenTable;
  final VoidCallback onOpenHost;
  final VoidCallback onOpenJoin;

  const _HomeLandscapeLayout({
    required this.playerName,
    required this.profileController,
    required this.onSettingsPressed,
    required this.onOpenTable,
    required this.onOpenHost,
    required this.onOpenJoin,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isTight = constraints.maxHeight < 270;

        return Column(
          mainAxisSize: MainAxisSize.max,
          children: [
            HomeTopBar(
              profileController: profileController,
              onSettingsPressed: onSettingsPressed,
            ),
            SizedBox(height: isTight ? 8 : 12),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    flex: 10,
                    child: Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: HomeLogoBlock(
                          playerName: playerName,
                          compact: true,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: isTight ? 14 : 20),
                  Expanded(
                    flex: 11,
                    child: LayoutBuilder(
                      builder: (context, buttonConstraints) {
                        return Center(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.center,
                            child: SizedBox(
                              width: buttonConstraints.maxWidth,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  HomeActionButton(
                                    title: 'Создать лобби',
                                    subtitle: '$playerName будет хостом стола',
                                    icon: Icons.add_rounded,
                                    isPrimary: true,
                                    compact: isTight,
                                    onPressed: onOpenHost,
                                  ),
                                  SizedBox(height: isTight ? 8 : 12),
                                  HomeActionButton(
                                    title: 'Подключиться',
                                    subtitle: 'Войти к другу по QR-коду или IP',
                                    icon: Icons.wifi_tethering_rounded,
                                    compact: isTight,
                                    onPressed: onOpenJoin,
                                  ),
                                  SizedBox(height: isTight ? 8 : 12),
                                  HomeActionButton(
                                    title: 'Тренировочный стол',
                                    subtitle: 'Проверим раздачу и интерфейс',
                                    icon: Icons.style_rounded,
                                    compact: isTight,
                                    onPressed: onOpenTable,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: isTight ? 8 : 12),
            Text(
              '${AppConstants.pokerMode} · 2–6 игроков · локальная сеть',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.softText,
                fontSize: isTight ? 11 : 12,
              ),
            ),
          ],
        );
      },
    );
  }
}
