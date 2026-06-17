import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:poker_phone/app/app_theme.dart';
import 'package:qr_code_scanner_plus/qr_code_scanner_plus.dart';

class QrJoinScanResult {
  final String host;
  final int port;
  final String lobbyId;

  const QrJoinScanResult({
    required this.host,
    required this.port,
    required this.lobbyId,
  });
}

class QrJoinScannerScreen extends StatefulWidget {
  const QrJoinScannerScreen({super.key});

  static QrJoinScanResult? parseRawPayload(String rawValue) {
    try {
      final decoded = jsonDecode(rawValue);
      if (decoded is! Map) {
        return null;
      }

      final type = decoded['type']?.toString();
      if (type != 'poker_phone_join') {
        return null;
      }

      final host = decoded['host']?.toString() ?? '';
      final port = (decoded['port'] as num?)?.toInt() ?? 4040;
      final lobbyId = decoded['lobbyId']?.toString() ?? '';
      if (host.isEmpty || lobbyId.isEmpty) {
        return null;
      }

      return QrJoinScanResult(
        host: host,
        port: port,
        lobbyId: lobbyId,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  State<QrJoinScannerScreen> createState() => _QrJoinScannerScreenState();
}

class _QrJoinScannerScreenState extends State<QrJoinScannerScreen>
    with WidgetsBindingObserver {
  final GlobalKey _qrKey = GlobalKey(debugLabel: 'join_qr');
  QRViewController? _controller;
  bool _handled = false;
  bool _hasPermission = true;
  String? _cameraError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_enterPortrait());
    });
  }

  Future<void> _enterPortrait() async {
    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  Future<void> _restoreAfterScanner() async {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _controller;
    if (controller == null || _handled) {
      return;
    }

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      unawaited(controller.pauseCamera());
      return;
    }

    if (state == AppLifecycleState.resumed) {
      unawaited(controller.resumeCamera());
    }
  }

  @override
  void reassemble() {
    super.reassemble();
    final controller = _controller;
    if (controller == null) {
      return;
    }
    if (Platform.isAndroid) {
      unawaited(controller.pauseCamera());
    }
    unawaited(controller.resumeCamera());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _restoreAfterScanner();
    super.dispose();
  }

  void _onViewCreated(QRViewController controller) {
    _controller = controller;
    controller.scannedDataStream.listen((scanData) {
      if (_handled) {
        return;
      }
      final raw = scanData.code;
      if (raw == null || raw.isEmpty) {
        return;
      }
      final result = QrJoinScannerScreen.parseRawPayload(raw);
      if (result == null) {
        return;
      }
      _handled = true;
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(result);
    });
  }

  void _onPermissionSet(QRViewController controller, bool granted) {
    if (!mounted) {
      return;
    }
    setState(() {
      _hasPermission = granted;
      _cameraError = granted
          ? null
          : 'Нет доступа к камере. Разреши камеру для приложения.';
    });
  }

  Future<void> _restartScanner() async {
    final controller = _controller;
    if (controller == null) {
      return;
    }
    try {
      await controller.pauseCamera();
      await Future<void>.delayed(const Duration(milliseconds: 180));
      await controller.resumeCamera();
      if (!mounted) {
        return;
      }
      setState(() {
        _cameraError = null;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _cameraError =
            'Не удалось открыть камеру. Попробуй закрыть и снова открыть сканер.';
      });
    }
  }

  Widget _buildErrorCard(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xCC08130F),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppTheme.primary.withAlpha(40)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.camera_alt_rounded,
                  color: AppTheme.primary,
                  size: 34,
                ),
                const SizedBox(height: 12),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    height: 1.45,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 14),
                FilledButton.tonal(
                  onPressed: _restartScanner,
                  child: const Text('Повторить'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cameraError = _cameraError;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Сканировать QR'),
        backgroundColor: Colors.black,
      ),
      body: Stack(
        children: [
          QRView(
            key: _qrKey,
            onQRViewCreated: _onViewCreated,
            onPermissionSet: _onPermissionSet,
            overlay: QrScannerOverlayShape(
              borderColor: AppTheme.primary,
              borderRadius: 28,
              borderLength: 32,
              borderWidth: 6,
              cutOutSize: 230,
              overlayColor: Colors.black.withAlpha(150),
            ),
          ),
          if (!_hasPermission)
            _buildErrorCard(
              'Нет доступа к камере. Разреши камеру для приложения.',
            )
          else if (cameraError != null)
            _buildErrorCard(cameraError),
          const Positioned(
            left: 24,
            right: 24,
            bottom: 32,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Color(0xCC08130F),
                borderRadius: BorderRadius.all(Radius.circular(20)),
              ),
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Наведи камеру на QR-код лобби, чтобы подключиться к столу.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    height: 1.4,
                    fontWeight: FontWeight.w700,
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
