import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:poker_phone/app/app_theme.dart';

class AppSplashScreen extends StatefulWidget {
  final String title;
  final String subtitle;

  const AppSplashScreen({
    super.key,
    this.title = 'Покер с друзьями',
    this.subtitle = 'Готовим стол и тасуем колоду...',
  });

  @override
  State<AppSplashScreen> createState() => _AppSplashScreenState();
}

class _AppSplashScreenState extends State<AppSplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _heroController;
  late final AnimationController _loaderController;

  late final Animation<double> _heroScale;
  late final Animation<double> _leftCardRotation;
  late final Animation<double> _rightCardRotation;
  late final Animation<double> _cardsFloat;
  late final Animation<double> _badgeScale;
  late final Animation<double> _glowScale;

  @override
  void initState() {
    super.initState();

    _heroController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    _loaderController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();

    _heroScale = Tween<double>(
      begin: 0.97,
      end: 1.03,
    ).animate(
      CurvedAnimation(
        parent: _heroController,
        curve: Curves.easeInOut,
      ),
    );

    _leftCardRotation = Tween<double>(
      begin: -0.30,
      end: -0.18,
    ).animate(
      CurvedAnimation(
        parent: _heroController,
        curve: Curves.easeInOut,
      ),
    );

    _rightCardRotation = Tween<double>(
      begin: 0.30,
      end: 0.18,
    ).animate(
      CurvedAnimation(
        parent: _heroController,
        curve: Curves.easeInOut,
      ),
    );

    _cardsFloat = Tween<double>(
      begin: -2,
      end: 6,
    ).animate(
      CurvedAnimation(
        parent: _heroController,
        curve: Curves.easeInOut,
      ),
    );

    _badgeScale = Tween<double>(
      begin: 0.97,
      end: 1.03,
    ).animate(
      CurvedAnimation(
        parent: _heroController,
        curve: Curves.easeInOut,
      ),
    );

    _glowScale = Tween<double>(
      begin: 0.92,
      end: 1.08,
    ).animate(
      CurvedAnimation(
        parent: _heroController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _heroController.dispose();
    _loaderController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topCenter,
            radius: 1.28,
            colors: [
              Color(0xFF264D3A),
              Color(0xFF10251D),
              Color(0xFF06100C),
            ],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isLandscape = constraints.maxWidth > constraints.maxHeight;
              final verticalInset = isLandscape ? 36.0 : 52.0;
              final safeMinHeight = math.max(
                0.0,
                constraints.maxHeight - verticalInset,
              );

              return Center(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    24,
                    isLandscape ? 18 : 28,
                    24,
                    isLandscape ? 18 : 24,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: safeMinHeight,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _SplashHero(
                          heroController: _heroController,
                          heroScale: _heroScale,
                          leftCardRotation: _leftCardRotation,
                          rightCardRotation: _rightCardRotation,
                          cardsFloat: _cardsFloat,
                          badgeScale: _badgeScale,
                          glowScale: _glowScale,
                          compact: isLandscape,
                        ),
                        SizedBox(height: isLandscape ? 18 : 28),
                        Text(
                          widget.title,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: isLandscape ? 28 : 34,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.8,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: isLandscape ? 360 : 460,
                          ),
                          child: Text(
                            widget.subtitle,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppTheme.mutedText,
                              fontSize: isLandscape ? 14 : 15,
                              height: 1.4,
                            ),
                          ),
                        ),
                        SizedBox(height: isLandscape ? 18 : 28),
                        AnimatedBuilder(
                          animation: _loaderController,
                          builder: (context, _) {
                            return _LoadingDeckBar(
                              progress: _loaderController.value,
                              compact: isLandscape,
                            );
                          },
                        ),
                      ],
                    ),
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

class _SplashHero extends StatelessWidget {
  final AnimationController heroController;
  final Animation<double> heroScale;
  final Animation<double> leftCardRotation;
  final Animation<double> rightCardRotation;
  final Animation<double> cardsFloat;
  final Animation<double> badgeScale;
  final Animation<double> glowScale;
  final bool compact;

  const _SplashHero({
    required this.heroController,
    required this.heroScale,
    required this.leftCardRotation,
    required this.rightCardRotation,
    required this.cardsFloat,
    required this.badgeScale,
    required this.glowScale,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    final heroWidth = compact ? 190.0 : 230.0;
    final heroHeight = compact ? 150.0 : 185.0;
    final cardWidth = compact ? 72.0 : 84.0;
    final cardHeight = compact ? 102.0 : 118.0;

    return AnimatedBuilder(
      animation: heroController,
      builder: (context, _) {
        return Transform.scale(
          scale: heroScale.value,
          child: SizedBox(
            width: heroWidth,
            height: heroHeight,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned(
                  bottom: 8,
                  child: Transform.scale(
                    scale: glowScale.value,
                    child: Container(
                      width: compact ? 124 : 150,
                      height: compact ? 62 : 78,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primary.withAlpha(52),
                            blurRadius: 40,
                            spreadRadius: 8,
                          ),
                          BoxShadow(
                            color: const Color(0xFF0F221A).withAlpha(180),
                            blurRadius: 26,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: compact ? 34 : 42,
                  top: 20 + cardsFloat.value,
                  child: Transform.rotate(
                    angle: leftCardRotation.value,
                    child: _SplashCard(
                      value: 'A',
                      suit: '♠',
                      isRed: false,
                      width: cardWidth,
                      height: cardHeight,
                    ),
                  ),
                ),
                Positioned(
                  right: compact ? 34 : 42,
                  top: 20 - cardsFloat.value * 0.35,
                  child: Transform.rotate(
                    angle: rightCardRotation.value,
                    child: _SplashCard(
                      value: 'K',
                      suit: '♥',
                      isRed: true,
                      width: cardWidth,
                      height: cardHeight,
                    ),
                  ),
                ),
                Positioned(
                  bottom: compact ? 12 : 18,
                  child: Transform.scale(
                    scale: badgeScale.value,
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: compact ? 18 : 20,
                        vertical: compact ? 9 : 11,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.primary,
                        borderRadius: BorderRadius.circular(999),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primary.withAlpha(72),
                            blurRadius: 32,
                            offset: const Offset(0, 14),
                          ),
                        ],
                      ),
                      child: Text(
                        'LAN TABLE',
                        style: TextStyle(
                          color: const Color(0xFF14100A),
                          fontWeight: FontWeight.w900,
                          fontSize: compact ? 11 : 12,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SplashCard extends StatelessWidget {
  final String value;
  final String suit;
  final bool isRed;
  final double width;
  final double height;

  const _SplashCard({
    required this.value,
    required this.suit,
    required this.isRed,
    required this.width,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    final color = isRed ? AppTheme.redSuit : AppTheme.darkSuit;

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBF0),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(76),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(9),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 23,
                height: 1,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              suit,
              style: TextStyle(
                color: color,
                fontSize: 18,
                height: 1,
                fontWeight: FontWeight.w900,
              ),
            ),
            const Spacer(),
            Align(
              alignment: Alignment.bottomRight,
              child: Text(
                suit,
                style: TextStyle(
                  color: color,
                  fontSize: 26,
                  height: 1,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadingDeckBar extends StatelessWidget {
  final double progress;
  final bool compact;

  const _LoadingDeckBar({
    required this.progress,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: compact ? 170 : 210,
      height: compact ? 52 : 64,
      child: Stack(
        alignment: Alignment.center,
        children: [
          for (int index = 0; index < 4; index++)
            _AnimatedMiniCard(
              index: index,
              progress: progress,
              compact: compact,
            ),
        ],
      ),
    );
  }
}

class _AnimatedMiniCard extends StatelessWidget {
  final int index;
  final double progress;
  final bool compact;

  const _AnimatedMiniCard({
    required this.index,
    required this.progress,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    final phase = (progress + index * 0.14) % 1.0;

    final baseX = (compact ? -45.0 : -54.0) + index * (compact ? 30.0 : 36.0);
    final wave = math.sin(phase * math.pi);
    final floatY = -wave * (compact ? 7.0 : 9.0);
    final tilt = math.sin(phase * math.pi * 2) * 0.08;
    final scale = 0.94 + wave.abs() * 0.10;

    final suits = ['♠', '♥', '♣', '♦'];
    final values = ['A', 'K', 'Q', 'J'];
    final isRed = suits[index] == '♥' || suits[index] == '♦';

    return Transform.translate(
      offset: Offset(baseX, floatY),
      child: Transform.rotate(
        angle: tilt,
        child: Transform.scale(
          scale: scale,
          child: Container(
            width: compact ? 28 : 34,
            height: compact ? 40 : 46,
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBF0),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(42),
                  blurRadius: 14,
                  offset: const Offset(0, 7),
                ),
              ],
            ),
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                compact ? 4 : 5,
                4,
                compact ? 4 : 5,
                4,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    values[index],
                    style: TextStyle(
                      color: isRed ? AppTheme.redSuit : AppTheme.darkSuit,
                      fontSize: compact ? 8.5 : 10,
                      height: 1,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const Spacer(),
                  Align(
                    alignment: Alignment.bottomRight,
                    child: Text(
                      suits[index],
                      style: TextStyle(
                        color: isRed ? AppTheme.redSuit : AppTheme.darkSuit,
                        fontSize: compact ? 12 : 15,
                        height: 1,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
