import 'package:flutter/material.dart';
import 'package:poker_phone/app/app_theme.dart';

class HomeActionButton extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool isPrimary;
  final bool compact;
  final VoidCallback onPressed;

  const HomeActionButton({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onPressed,
    this.isPrimary = false,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final background = isPrimary ? AppTheme.primary : Colors.white.withAlpha(16);
    final foreground = isPrimary ? const Color(0xFF14100A) : Colors.white;
    final borderRadius = compact ? 20.0 : 24.0;
    final padding = compact ? 12.0 : 16.0;
    final iconSize = compact ? 40.0 : 46.0;
    final iconRadius = compact ? 14.0 : 17.0;
    final titleSize = compact ? 15.0 : 16.0;
    final subtitleSize = compact ? 11.5 : 12.5;

    return SizedBox(
      width: double.infinity,
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(borderRadius),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(borderRadius),
          child: Container(
            padding: EdgeInsets.all(padding),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border.all(
                color: isPrimary ? AppTheme.primary : Colors.white.withAlpha(22),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: iconSize,
                  height: iconSize,
                  decoration: BoxDecoration(
                    color: isPrimary
                        ? Colors.black.withAlpha(22)
                        : Colors.white.withAlpha(16),
                    borderRadius: BorderRadius.circular(iconRadius),
                  ),
                  child: Icon(
                    icon,
                    color: foreground,
                  ),
                ),
                SizedBox(width: compact ? 11 : 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: foreground,
                          fontSize: titleSize,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: compact ? 2 : 3),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isPrimary
                              ? const Color(0xFF4B3C17)
                              : AppTheme.mutedText,
                          fontSize: subtitleSize,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_rounded,
                  color: foreground,
                  size: compact ? 24 : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
