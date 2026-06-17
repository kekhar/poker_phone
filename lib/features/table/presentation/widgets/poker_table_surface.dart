import 'package:flutter/material.dart';
import 'package:poker_phone/app/app_theme.dart';

class PokerTableSurface extends StatelessWidget {
  final double width;
  final double height;
  final int pot;
  final List<Widget> communityCards;
  final String streetLabel;

  const PokerTableSurface({
    super.key,
    required this.width,
    required this.height,
    required this.pot,
    required this.communityCards,
    this.streetLabel = 'Flop',
  });

  @override
  Widget build(BuildContext context) {
    final cardsMaxWidth = width * 0.62;

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: const Color(0xFF08120E),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(34),
            blurRadius: 8,
            spreadRadius: 0,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          gradient: const RadialGradient(
            center: Alignment.center,
            radius: 1.05,
            colors: [
              Color(0xFF174933),
              Color(0xFF113625),
              Color(0xFF0B2319),
            ],
          ),
          border: Border.all(
            color: AppTheme.primary.withAlpha(110),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primary.withAlpha(8),
              blurRadius: 10,
              spreadRadius: 0,
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.all(30),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: Colors.white.withAlpha(20),
                    ),
                  ),
                ),
              ),
            ),
            Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: SizedBox(
                  width: cardsMaxWidth,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        streetLabel.toUpperCase(),
                        style: TextStyle(
                          color: Colors.white.withAlpha(78),
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '$pot',
                        style: const TextStyle(
                          color: AppTheme.primary,
                          fontSize: 38,
                          height: 1,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -1,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 8,
                        runSpacing: 8,
                        children: communityCards,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
