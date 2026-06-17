import 'package:flutter/material.dart';
import 'package:poker_phone/app/app_theme.dart';

enum AppToastType {
  success,
  info,
  warning,
  error,
}

void showAppToast(
  BuildContext context, {
  required String message,
  AppToastType type = AppToastType.info,
}) {
  final messenger = ScaffoldMessenger.of(context);

  messenger.hideCurrentSnackBar();

  messenger.showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      elevation: 0,
      backgroundColor: Colors.transparent,
      padding: EdgeInsets.zero,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 18),
      duration: const Duration(milliseconds: 2200),
      content: _AppToastContent(
        message: message,
        type: type,
      ),
    ),
  );
}

class _AppToastContent extends StatelessWidget {
  final String message;
  final AppToastType type;

  const _AppToastContent({
    required this.message,
    required this.type,
  });

  Color get _background {
    switch (type) {
      case AppToastType.success:
        return const Color(0xFF10281D);
      case AppToastType.warning:
        return const Color(0xFF2B2111);
      case AppToastType.error:
        return const Color(0xFF2B1414);
      case AppToastType.info:
        return const Color(0xFF121F1A);
    }
  }

  Color get _border {
    switch (type) {
      case AppToastType.success:
        return const Color(0xFF3DDC84);
      case AppToastType.warning:
        return AppTheme.primary;
      case AppToastType.error:
        return const Color(0xFFFF6B6B);
      case AppToastType.info:
        return Colors.white24;
    }
  }

  IconData get _icon {
    switch (type) {
      case AppToastType.success:
        return Icons.check_circle_rounded;
      case AppToastType.warning:
        return Icons.warning_rounded;
      case AppToastType.error:
        return Icons.error_rounded;
      case AppToastType.info:
        return Icons.info_rounded;
    }
  }

  Color get _iconColor {
    switch (type) {
      case AppToastType.success:
        return const Color(0xFF3DDC84);
      case AppToastType.warning:
        return AppTheme.primary;
      case AppToastType.error:
        return const Color(0xFFFF6B6B);
      case AppToastType.info:
        return AppTheme.mutedText;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 13, 16, 13),
      decoration: BoxDecoration(
        color: _background,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: _border.withAlpha(115),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(90),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: _iconColor.withAlpha(28),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              _icon,
              color: _iconColor,
              size: 21,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 14,
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }
}