import 'package:flutter/material.dart';
import 'package:poker_phone/app/app_theme.dart';
import 'package:poker_phone/core/constants/app_constants.dart';
import 'package:poker_phone/core/widgets/player_avatar.dart';
import 'package:poker_phone/features/profile/presentation/profile_controller.dart';

class HomeTopBar extends StatelessWidget {
  final ProfileController profileController;
  final VoidCallback onSettingsPressed;

  const HomeTopBar({
    super.key,
    required this.profileController,
    required this.onSettingsPressed,
  });

  @override
  Widget build(BuildContext context) {
    final profile = profileController.profile;

    return Row(
      children: [
        PlayerAvatar(
          seed: profile.avatarSeed,
          avatarPath: profile.avatarPath,
          avatarType: profile.avatarType,
          size: 42,
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppConstants.appName,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.2,
                ),
              ),
              SizedBox(height: 2),
              Text(
                AppConstants.appSubtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.mutedText,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: onSettingsPressed,
          icon: const Icon(Icons.settings_rounded),
          color: AppTheme.mutedText,
        ),
      ],
    );
  }
}