import 'package:flutter/material.dart';
import 'package:poker_phone/app/app_theme.dart';

class HomeLogoBlock extends StatefulWidget {
  final String playerName;
  final bool compact;

  const HomeLogoBlock({
    super.key,
    required this.playerName,
    this.compact = false,
  });

  @override
  State<HomeLogoBlock> createState() => _HomeLogoBlockState();
}

class _HomeLogoBlockState extends State<HomeLogoBlock>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  late final Animation<double> _leftRotation;
  late final Animation<double> _rightRotation;
  late final Animation<double> _leftFloat;
  late final Animation<double> _rightFloat;
  late final Animation<double> _badgeScale;
  late final Animation<double> _glowOpacity;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat(reverse: true);

    _leftRotation = Tween<double>(
      begin: -0.22,
      end: -0.16,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );

    _rightRotation = Tween<double>(
      begin: 0.22,
      end: 0.16,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );

    _leftFloat = Tween<double>(
      begin: 0,
      end: 4,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );

    _rightFloat = Tween<double>(
      begin: 0,
      end: -3,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );

    _badgeScale = Tween<double>(
      begin: 0.985,
      end: 1.015,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );

    _glowOpacity = Tween<double>(
      begin: 0.18,
      end: 0.30,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String get _safeName {
    final trimmed = widget.playerName.trim();
    if (trimmed.length <= 14) return trimmed;
    return '${trimmed.substring(0, 14)}…';
  }

  @override
  Widget build(BuildContext context) {
    final isCompact = widget.compact;
    final logoWidth = isCompact ? 138.0 : 174.0;
    final logoHeight = isCompact ? 112.0 : 138.0;
    final cardWidth = isCompact ? 60.0 : 74.0;
    final cardHeight = isCompact ? 84.0 : 104.0;
    final titleSize = isCompact ? 26.0 : 38.0;
    final subtitleSize = isCompact ? 13.0 : 15.0;
    final titleGap = isCompact ? 18.0 : 26.0;
    final textGap = isCompact ? 10.0 : 14.0;

    final title = _safeName == 'Игрок'
        ? 'Покер рядом\nс друзьями'
        : '$_safeName,\nсобираем стол?';

    final subtitle = _safeName == 'Игрок'
        ? 'Создавай лобби по Wi‑Fi, подключай игроков\nи играй за одним столом с телефона.'
        : 'Создай своё лобби, позови друзей\nи запускай раздачу по Wi‑Fi.';

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Column(
          children: [
            SizedBox(
              width: logoWidth,
              height: logoHeight,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned(
                    bottom: 8,
                    child: Container(
                      width: isCompact ? 96 : 112,
                      height: isCompact ? 38 : 44,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primary.withAlpha(
                              (_glowOpacity.value * 150).round(),
                            ),
                            blurRadius: 28,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 12,
                    top: 18 + _leftFloat.value,
                    child: Transform.rotate(
                      angle: _leftRotation.value,
                      child: _PokerCard(
                        value: 'A',
                        suit: '♠',
                        isDark: true,
                        width: cardWidth,
                        height: cardHeight,
                        compact: isCompact,
                      ),
                    ),
                  ),
                  Positioned(
                    right: 12,
                    top: 18 + _rightFloat.value,
                    child: Transform.rotate(
                      angle: _rightRotation.value,
                      child: _PokerCard(
                        value: 'K',
                        suit: '♥',
                        isDark: false,
                        width: cardWidth,
                        height: cardHeight,
                        compact: isCompact,
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    child: Transform.scale(
                      scale: _badgeScale.value,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 9,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.primary,
                          borderRadius: BorderRadius.circular(999),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primary.withAlpha(64),
                              blurRadius: 28,
                              offset: const Offset(0, 12),
                            ),
                          ],
                        ),
                        child: const Text(
                          'LAN TABLE',
                          style: TextStyle(
                            color: Color(0xFF14100A),
                            fontWeight: FontWeight.w900,
                            fontSize: 11,
                            letterSpacing: 1.4,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: titleGap),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: titleSize,
                height: 1.05,
                fontWeight: FontWeight.w900,
                letterSpacing: -1.2,
              ),
            ),
            SizedBox(height: textGap),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: subtitleSize,
                height: 1.45,
                color: AppTheme.mutedText,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _PokerCard extends StatelessWidget {
  final String value;
  final String suit;
  final bool isDark;
  final double width;
  final double height;
  final bool compact;

  const _PokerCard({
    required this.value,
    required this.suit,
    required this.isDark,
    required this.width,
    required this.height,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    final accentColor = isDark ? AppTheme.darkSuit : AppTheme.redSuit;
    final cardColor = isDark ? const Color(0xFFF7F0DA) : const Color(0xFFFFFBF0);

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(70),
            blurRadius: 22,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(compact ? 7 : 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: TextStyle(
                color: accentColor,
                fontSize: compact ? 18 : 22,
                height: 1,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              suit,
              style: TextStyle(
                color: accentColor,
                fontSize: compact ? 14 : 16,
                height: 1,
                fontWeight: FontWeight.w800,
              ),
            ),
            const Spacer(),
            Align(
              alignment: Alignment.bottomRight,
              child: Text(
                suit,
                style: TextStyle(
                  color: accentColor,
                  fontSize: compact ? 20 : 24,
                  height: 1,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
