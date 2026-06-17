import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:poker_phone/app/poker_phone_app.dart';
import 'package:poker_phone/features/profile/data/player_profile_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('Home screen renders personalized actions', (tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1.0;

    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    SharedPreferences.setMockInitialValues({
      'player_profile.name': 'Кирилл',
      'player_profile.avatar_seed': 'spade',
      'player_profile.avatar_path': '',
      'player_profile.avatar_type': 'preset',
      'player_profile.onboarding_completed': true,
    });

    await tester.pumpWidget(
      PokerPhoneApp(
        profileStorage: PlayerProfileStorage(),
        splashDuration: Duration.zero,
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Poker Phone'), findsOneWidget);
    expect(find.text('Кирилл,\nсобираем стол?'), findsOneWidget);
    expect(find.text('Создать лобби'), findsOneWidget);
    expect(find.text('Подключиться'), findsOneWidget);
    expect(find.text('Тренировочный стол'), findsOneWidget);
  });

  testWidgets('First launch shows onboarding screen', (tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1.0;

    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    SharedPreferences.setMockInitialValues({
      'player_profile.name': '',
      'player_profile.avatar_seed': 'spade',
      'player_profile.avatar_path': '',
      'player_profile.avatar_type': 'preset',
      'player_profile.onboarding_completed': false,
    });

    await tester.pumpWidget(
      PokerPhoneApp(
        profileStorage: PlayerProfileStorage(),
        splashDuration: Duration.zero,
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Первый вход'), findsOneWidget);
    expect(find.text('Как тебя\nзаписать за стол?'), findsOneWidget);
    expect(find.text('Продолжить'), findsOneWidget);
  });
}