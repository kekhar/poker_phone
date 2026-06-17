import 'package:flutter/material.dart';
import 'package:poker_phone/app/app_theme.dart';

class PlayingCardView extends StatefulWidget {
  final String rank;
  final String suit;
  final double width;
  final double height;
  final bool isFaceDown;
  final bool isMuted;
  final bool isHighlighted;

  const PlayingCardView({
    super.key,
    required this.rank,
    required this.suit,
    this.width = 54,
    this.height = 74,
    this.isFaceDown = false,
    this.isMuted = false,
    this.isHighlighted = false,
  });

  @override
  State<PlayingCardView> createState() => _PlayingCardViewState();
}

class _PlayingCardViewState extends State<PlayingCardView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  bool get _isRed => widget.suit == '♥' || widget.suit == '♦';

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1050),
      lowerBound: 0.0,
      upperBound: 1.0,
    );
    _syncPulse();
  }

  @override
  void didUpdateWidget(covariant PlayingCardView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isHighlighted != widget.isHighlighted) {
      _syncPulse();
    }
  }

  void _syncPulse() {
    if (widget.isHighlighted) {
      _pulseController.repeat(reverse: true);
    } else {
      _pulseController
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isHighlighted) {
      return _buildCard(pulse: 0);
    }

    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, _) => CustomPaint(
        foregroundPainter: _CardPulseBorderPainter(
          progress: _pulseController.value,
          borderRadius: widget.width * 0.22,
        ),
        child: _buildCard(pulse: _pulseController.value),
      ),
    );
  }

  Widget _buildCard({required double pulse}) {
    final borderRadius = BorderRadius.circular(widget.width * 0.22);
    final borderWidth = 1.0;

    if (widget.isFaceDown) {
      return Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: widget.isMuted
              ? const Color(0xFF2A2F2C)
              : const Color(0xFF18241F),
          borderRadius: borderRadius,
          border: Border.all(
            color: widget.isMuted
                ? Colors.white.withAlpha(26)
                : widget.isHighlighted
                ? AppTheme.primary.withAlpha(160)
                : AppTheme.primary.withAlpha(90),
            width: borderWidth,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(70),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Center(
          child: Text(
            '♠',
            style: TextStyle(
              color: widget.isMuted
                  ? Colors.white.withAlpha(42)
                  : widget.isHighlighted
                  ? AppTheme.primary.withAlpha(210)
                  : AppTheme.primary.withAlpha(160),
              fontSize: widget.width * 0.34,
              height: 1,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      );
    }

    final color = widget.isMuted
        ? Colors.black.withAlpha(120)
        : (_isRed ? AppTheme.redSuit : AppTheme.darkSuit);

    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: widget.isMuted
            ? const Color(0xFFB8BBB2)
            : const Color(0xFFFFFBF0),
        borderRadius: borderRadius,
        border: Border.all(
          color: widget.isMuted
              ? Colors.white.withAlpha(36)
              : widget.isHighlighted
              ? AppTheme.primary.withAlpha(160)
              : Colors.white.withAlpha(80),
          width: borderWidth,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(62),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(widget.width * 0.13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.rank,
              style: TextStyle(
                color: color,
                fontSize: widget.width * 0.30,
                height: 1,
                fontWeight: FontWeight.w900,
              ),
            ),
            const Spacer(),
            Align(
              alignment: Alignment.bottomRight,
              child: Text(
                widget.suit,
                style: TextStyle(
                  color: color,
                  fontSize: widget.width * 0.36,
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

class _CardPulseBorderPainter extends CustomPainter {
  final double progress;
  final double borderRadius;

  const _CardPulseBorderPainter({
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
      rect.deflate(0.6),
      Radius.circular(borderRadius),
    );

    final pulseAlpha = (120 + progress * 70).round();
    final outerAlpha = (62 + progress * 36).round();
    final innerAlpha = (168 + progress * 55).round();
    final outerRect = RRect.fromRectAndRadius(
      rect.inflate(1.1),
      Radius.circular(borderRadius + 1.2),
    );

    final outerPaint = Paint()
      ..color = AppTheme.primary.withAlpha(outerAlpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;

    final glowPaint = Paint()
      ..color = AppTheme.primary.withAlpha((52 + progress * 28).round())
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.6
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);

    final paint = Paint()
      ..color = AppTheme.primary.withAlpha(innerAlpha > pulseAlpha ? innerAlpha : pulseAlpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.3;

    canvas.drawRRect(outerRect, outerPaint);
    canvas.drawRRect(rrect, glowPaint);
    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(covariant _CardPulseBorderPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.borderRadius != borderRadius;
  }
}
