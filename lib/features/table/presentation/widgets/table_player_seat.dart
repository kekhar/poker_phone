import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:poker_phone/app/app_theme.dart';
import 'package:poker_phone/core/widgets/player_avatar.dart';
import 'package:poker_phone/features/profile/domain/player_profile.dart';
import 'package:poker_phone/features/table/presentation/widgets/playing_card_view.dart';

class TableSeatCard {
  final String rank;
  final String suit;

  const TableSeatCard({required this.rank, required this.suit});
}

class TablePlayerSeat extends StatelessWidget {
  final String name;
  final int chips;
  final String avatarSeed;
  final String avatarPath;
  final PlayerAvatarType avatarType;
  final Uint8List? avatarBytes;
  final String? statusLabel;
  final bool isActive;
  final bool isDealer;
  final bool showCards;
  final bool isFolded;
  final double width;
  final double? turnProgress;
  final List<TableSeatCard>? revealedCards;

  const TablePlayerSeat({
    super.key,
    required this.name,
    required this.chips,
    required this.avatarSeed,
    required this.avatarPath,
    required this.avatarType,
    this.avatarBytes,
    this.statusLabel,
    this.isActive = false,
    this.isDealer = false,
    this.showCards = true,
    this.isFolded = false,
    this.width = 148,
    this.turnProgress,
    this.revealedCards,
  });

  @override
  Widget build(BuildContext context) {
    final isCompact = width < 136;
    final horizontalPadding = isCompact ? 8.0 : 10.0;
    final verticalPadding = isCompact ? 8.0 : 9.0;
    final avatarSize = isCompact ? 36.0 : 42.0;
    final avatarGap = isCompact ? 7.0 : 9.0;
    final nameFontSize = isCompact ? 12.0 : 13.0;
    final chipsFontSize = isCompact ? 10.0 : 11.0;
    final cardsWidth = isCompact ? 21.0 : 25.0;
    final cardsHeight = isCompact ? 30.0 : 35.0;
    final cardsTopOffset = isCompact ? -20.0 : -24.0;

    final borderColor = isFolded
        ? Colors.white.withAlpha(18)
        : isActive
        ? AppTheme.primary.withAlpha(180)
        : Colors.white.withAlpha(24);

    final panelColor = isFolded
        ? const Color(0xFF101612).withAlpha(205)
        : const Color(0xFF0C1C16).withAlpha(235);
    final progress = turnProgress?.clamp(0.0, 1.0) ?? 0.0;

    return SizedBox(
      width: width,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          CustomPaint(
            foregroundPainter: isActive && !isFolded
                ? _SeatTurnBorderPainter(
                    progress: progress == 0 ? 0.72 : progress,
                    borderRadius: 22,
                  )
                : null,
            child: Container(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                verticalPadding,
                horizontalPadding,
                verticalPadding,
              ),
              decoration: BoxDecoration(
                color: panelColor,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: borderColor,
                  width: isActive && !isFolded ? 1.4 : 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(isFolded ? 38 : 54),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Row(
                children: [
                  PlayerAvatar(
                    seed: avatarSeed,
                    avatarPath: avatarPath,
                    avatarType: avatarType,
                    avatarBytes: avatarBytes,
                    size: avatarSize,
                    isSelected: isActive && !isFolded,
                  ),
                  SizedBox(width: avatarGap),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: isFolded
                                ? Colors.white.withAlpha(120)
                                : Colors.white,
                            fontSize: nameFontSize,
                            fontWeight: FontWeight.w900,
                            height: 1.05,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$chips фишек',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: isFolded
                                ? Colors.white.withAlpha(74)
                                : AppTheme.mutedText,
                            fontSize: chipsFontSize,
                            fontWeight: FontWeight.w600,
                            height: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (showCards)
            Positioned(
              right: 8,
              top: cardsTopOffset,
              child: Row(
                children: [
                  PlayingCardView(
                    rank: revealedCards?[0].rank ?? '',
                    suit: revealedCards?[0].suit ?? '',
                    width: cardsWidth,
                    height: cardsHeight,
                    isFaceDown: revealedCards == null,
                    isMuted: isFolded,
                  ),
                  const SizedBox(width: 3),
                  PlayingCardView(
                    rank: revealedCards?[1].rank ?? '',
                    suit: revealedCards?[1].suit ?? '',
                    width: cardsWidth,
                    height: cardsHeight,
                    isFaceDown: revealedCards == null,
                    isMuted: isFolded,
                  ),
                ],
              ),
            ),
          if (statusLabel != null && statusLabel!.trim().isNotEmpty)
            Positioned(
              left: 14,
              bottom: -17,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: isFolded
                      ? const Color(0xFF1A201C)
                      : isActive
                      ? AppTheme.primary
                      : const Color(0xFF17261F),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: isFolded
                        ? Colors.white.withAlpha(20)
                        : isActive
                        ? AppTheme.primary
                        : Colors.white.withAlpha(20),
                  ),
                ),
                child: Text(
                  statusLabel!,
                  style: TextStyle(
                    color: isFolded
                        ? Colors.white.withAlpha(130)
                        : isActive
                        ? const Color(0xFF14100A)
                        : Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
              ),
            ),
          if (isDealer && !isFolded)
            Positioned(
              right: -5,
              bottom: -6,
              child: Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBF0),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppTheme.primary, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(70),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: const Center(
                  child: Text(
                    'D',
                    style: TextStyle(
                      color: Color(0xFF14100A),
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SeatTurnBorderPainter extends CustomPainter {
  final double progress;
  final double borderRadius;

  const _SeatTurnBorderPainter({
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
      rect.deflate(0.7),
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
  bool shouldRepaint(covariant _SeatTurnBorderPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.borderRadius != borderRadius;
  }
}
