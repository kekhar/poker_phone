import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:poker_phone/app/app_theme.dart';
import 'package:poker_phone/features/profile/domain/player_profile.dart';

const List<String> playerAvatarSeeds = [
  'card',
  'old_heart',
  'leaf',
  'old_diamond',
  'chip',
  'star',
  'spade',
  'heart',
  'club',
  'diamond',
  'crown',
];

class PlayerAvatar extends StatelessWidget {
  final String seed;
  final String avatarPath;
  final PlayerAvatarType avatarType;
  final Uint8List? avatarBytes;
  final double size;
  final bool isSelected;

  const PlayerAvatar({
    super.key,
    required this.seed,
    required this.avatarPath,
    required this.avatarType,
    this.avatarBytes,
    this.size = 48,
    this.isSelected = false,
  });

  Color get _backgroundColor {
    switch (seed) {
      case 'old_heart':
      case 'heart':
        return const Color(0xFF5D1F2F);
      case 'leaf':
      case 'club':
        return const Color(0xFF143A2A);
      case 'old_diamond':
      case 'diamond':
        return const Color(0xFF3D2C61);
      case 'chip':
      case 'crown':
        return const Color(0xFF4A3513);
      case 'star':
        return const Color(0xFF24365B);
      case 'card':
      case 'spade':
      default:
        return const Color(0xFF18241F);
    }
  }

  Color get _foregroundColor {
    switch (seed) {
      case 'old_heart':
      case 'heart':
        return const Color(0xFFFF5570);
      case 'leaf':
      case 'club':
        return const Color(0xFF74D49D);
      case 'old_diamond':
      case 'diamond':
        return const Color(0xFFC9A7FF);
      case 'chip':
      case 'crown':
        return AppTheme.primary;
      case 'star':
        return const Color(0xFF8DB5FF);
      case 'card':
      case 'spade':
      default:
        return AppTheme.mutedText;
    }
  }

  Widget _buildPresetContent() {
    switch (seed) {
      case 'card':
        return Icon(
          Icons.style_rounded,
          color: _foregroundColor,
          size: size * 0.44,
        );

      case 'old_heart':
        return Icon(
          Icons.favorite_rounded,
          color: _foregroundColor,
          size: size * 0.44,
        );

      case 'leaf':
        return Icon(
          Icons.eco_rounded,
          color: _foregroundColor,
          size: size * 0.44,
        );

      case 'old_diamond':
        return Icon(
          Icons.diamond_rounded,
          color: _foregroundColor,
          size: size * 0.44,
        );

      case 'chip':
        return Icon(
          Icons.casino_rounded,
          color: _foregroundColor,
          size: size * 0.44,
        );

      case 'star':
        return Icon(
          Icons.star_rounded,
          color: _foregroundColor,
          size: size * 0.46,
        );

      case 'spade':
        return _SuitText(
          value: '♠',
          size: size,
          color: _foregroundColor,
        );

      case 'heart':
        return _SuitText(
          value: '♥',
          size: size,
          color: _foregroundColor,
        );

      case 'club':
        return _SuitText(
          value: '♣',
          size: size,
          color: _foregroundColor,
        );

      case 'diamond':
        return _SuitText(
          value: '♦',
          size: size,
          color: _foregroundColor,
        );

      case 'crown':
        return Icon(
          Icons.workspace_premium_rounded,
          color: _foregroundColor,
          size: size * 0.47,
        );

      default:
        return Icon(
          Icons.person_rounded,
          color: _foregroundColor,
          size: size * 0.44,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasNetworkPhoto =
        avatarType == PlayerAvatarType.photo &&
        avatarBytes != null &&
        avatarBytes!.isNotEmpty;
    final hasPhoto = avatarType == PlayerAvatarType.photo &&
        avatarPath.trim().isNotEmpty &&
        File(avatarPath).existsSync();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: hasPhoto ? Colors.black12 : _backgroundColor,
        borderRadius: BorderRadius.circular(size * 0.38),
        border: Border.all(
          color: isSelected ? AppTheme.primary : Colors.white.withAlpha(24),
          width: isSelected ? 2 : 1,
        ),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: AppTheme.primary.withAlpha(58),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ]
            : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: hasNetworkPhoto
          ? Image.memory(
              avatarBytes!,
              fit: BoxFit.cover,
            )
          : hasPhoto
          ? Image.file(
              File(avatarPath),
              fit: BoxFit.cover,
            )
          : Center(
              child: _buildPresetContent(),
            ),
    );
  }
}

class _SuitText extends StatelessWidget {
  final String value;
  final double size;
  final Color color;

  const _SuitText({
    required this.value,
    required this.size,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: Offset(0, -size * 0.03),
      child: Text(
        value,
        style: TextStyle(
          fontSize: size * 0.46,
          height: 1,
          fontWeight: FontWeight.w900,
          color: color,
        ),
      ),
    );
  }
}
