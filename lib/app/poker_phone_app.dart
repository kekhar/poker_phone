import 'package:flutter/material.dart';
import 'package:poker_phone/app/app_theme.dart';
import 'package:poker_phone/features/home/presentation/home_screen.dart';
import 'package:poker_phone/features/lobby/presentation/lobby_controller.dart';
import 'package:poker_phone/features/onboarding/presentation/onboarding_screen.dart';
import 'package:poker_phone/features/profile/data/player_profile_storage.dart';
import 'package:poker_phone/features/profile/presentation/profile_controller.dart';
import 'package:poker_phone/features/splash/presentation/app_splash_screen.dart';

class PokerPhoneApp extends StatefulWidget {
  final PlayerProfileStorage profileStorage;
  final Duration splashDuration;

  const PokerPhoneApp({
    super.key,
    required this.profileStorage,
    this.splashDuration = const Duration(seconds: 5),
  });

  @override
  State<PokerPhoneApp> createState() => _PokerPhoneAppState();
}

class _PokerPhoneAppState extends State<PokerPhoneApp> {
  late final Future<ProfileController> _bootstrapFuture;
  late final LobbyController _lobbyController;

  @override
  void initState() {
    super.initState();
    _lobbyController = LobbyController();
    _bootstrapFuture = _bootstrap();
  }

  Future<ProfileController> _bootstrap() async {
    final startedAt = DateTime.now();
    final profile = await widget.profileStorage.load();

    final elapsed = DateTime.now().difference(startedAt);
    final remaining = widget.splashDuration - elapsed;

    if (remaining > Duration.zero) {
      await Future.delayed(remaining);
    }

    return ProfileController(
      profileStorage: widget.profileStorage,
      initialProfile: profile,
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Покер с друзьями',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: FutureBuilder<ProfileController>(
        future: _bootstrapFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const AppSplashScreen();
          }

          if (snapshot.hasError || !snapshot.hasData) {
            return const AppSplashScreen(
              title: 'Не удалось загрузить профиль',
              subtitle: 'Перезапусти приложение или попробуй позже',
            );
          }

          final profileController = snapshot.data!;

          return ListenableBuilder(
            listenable: profileController,
            builder: (context, _) {
              final profile = profileController.profile;

              if (!profile.isOnboardingCompleted) {
                return OnboardingScreen(
                  profileController: profileController,
                );
              }

              return HomeScreen(
                profileController: profileController,
                lobbyController: _lobbyController,
              );
            },
          );
        },
      ),
    );
  }
}
