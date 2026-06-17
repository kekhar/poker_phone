import 'package:flutter/material.dart';
import 'package:poker_phone/app/app_theme.dart';

class TableActionBar extends StatelessWidget {
  final VoidCallback onFold;
  final VoidCallback onCall;
  final VoidCallback onRaise;
  final bool isObserverMode;
  final VoidCallback? onConnectLater;
  final String foldLabel;
  final String callLabel;
  final String raiseLabel;
  final bool isEnabled;
  final bool isRaiseEnabled;

  const TableActionBar({
    super.key,
    required this.onFold,
    required this.onCall,
    required this.onRaise,
    this.isObserverMode = false,
    this.onConnectLater,
    this.foldLabel = 'Fold',
    this.callLabel = 'Call 40',
    this.raiseLabel = 'Raise',
    this.isEnabled = true,
    this.isRaiseEnabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFF08130F).withAlpha(232),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withAlpha(18)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(88),
            blurRadius: 22,
            offset: const Offset(0, 11),
          ),
        ],
      ),
      child: Row(
        children: [
          if (isObserverMode) ...[
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  color: const Color(0xFF0E2019),
                  border: Border.all(color: Colors.white.withAlpha(12)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(6),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.white.withAlpha(10)),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.visibility_rounded,
                              color: AppTheme.primary,
                              size: 14,
                            ),
                            SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                'Наблюдатель',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  height: 1,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton(
                        onPressed: onConnectLater ?? onCall,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: const Color(0xFF14100A),
                          minimumSize: const Size.fromHeight(42),
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text('Подключиться'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ] else ...[
            Expanded(
              child: OutlinedButton(
                onPressed: isEnabled ? onFold : null,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    foldLabel,
                    maxLines: 1,
                    softWrap: false,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                onPressed: isEnabled ? onCall : null,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    callLabel,
                    maxLines: 1,
                    softWrap: false,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton(
                onPressed: isEnabled && isRaiseEnabled ? onRaise : null,
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: const Color(0xFF14100A),
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    raiseLabel,
                    maxLines: 1,
                    softWrap: false,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
