import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:poker_phone/features/lobby/domain/lobby_session.dart';
import 'package:poker_phone/features/lobby/domain/lobby_settings.dart';
import 'package:poker_phone/features/lobby/domain/lobby_wire.dart';
import 'package:poker_phone/features/lobby/domain/player_identity.dart';
import 'package:poker_phone/features/table/domain/poker_hand_evaluator.dart';

class LobbyController extends ChangeNotifier {
  static const int defaultPort = 4040;
  static const int discoveryPort = 4041;
  static const String discoveryRequest = 'POKER_PHONE_DISCOVER_V1';

  final List<LobbySession> _lobbies = [];
  final List<DiscoveredLobbyHost> _discoveredHosts = [];
  final Map<String, Timer> _startTimers = {};
  final Map<String, Timer> _turnTimers = {};
  final Map<String, Timer> _showdownTimers = {};
  final Map<String, Timer> _runoutTimers = {};
  final Map<WebSocket, PlayerIdentity> _connectedClients = {};
  final math.Random _random = math.Random();

  HttpServer? _hostServer;
  RawDatagramSocket? _discoveryResponder;
  WebSocket? _serverConnection;
  StreamSubscription? _serverSubscription;
  Completer<LobbySession>? _pendingRemoteLobbyCompleter;
  String? _hostAddress;
  String? _lastError;
  bool _isHosting = false;
  bool _isConnecting = false;
  int _hostPort = defaultPort;
  bool _isDiscovering = false;
  final List<String> _networkDebugLog = [];
  String _networkStatus = 'Ожидание сети';

  List<LobbySession> get lobbies => List.unmodifiable(_lobbies);
  List<DiscoveredLobbyHost> get discoveredHosts =>
      List.unmodifiable(_discoveredHosts);
  String? get hostAddress => _hostAddress;
  int get hostPort => _hostPort;
  String? get lastError => _lastError;
  bool get isHosting => _isHosting;
  bool get isConnectedToRemote => _serverConnection != null;
  bool get isConnecting => _isConnecting;
  bool get isDiscovering => _isDiscovering;
  List<String> get networkDebugLog => List.unmodifiable(_networkDebugLog);
  String get networkStatus => _networkStatus;
  String? get hostAddressWarning => _hostAddressWarning(_hostAddress);

  LobbySession? lobbyById(String id) {
    for (final lobby in _lobbies) {
      if (lobby.id == id) {
        return lobby;
      }
    }
    return null;
  }

  Future<LobbySession> createLobby(LobbySettings settings) async {
    _setNetworkStatus('Поднимаем локальный стол');
    await _closeClientConnection();
    await _stopHostEndpoints();
    await _startHostServer();
    await _startDiscoveryResponder();

    final hostEntry = LobbyPlayerEntry(
      identity: settings.host,
      chips: settings.startingChips,
      isHost: true,
    );
    final lobby = LobbySession(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      settings: settings,
      players: [hostEntry],
      observers: const [],
      isStarted: false,
      countdownEndsAt: null,
      demoScenarioIndex: 0,
      pendingObserverKeys: const [],
      pendingPlayerKeys: const [],
      gameState: null,
    );

    _isHosting = true;
    _lobbies
      ..clear()
      ..add(lobby);
    _appendDebug(
      'Лобби создано: ${settings.displayLobbyName}, хост ${_hostAddress ?? '-'}:$_hostPort',
    );
    final warning = _hostAddressWarning(_hostAddress);
    if (warning != null) {
      _appendDebug(warning);
      _setNetworkStatus(
        'Хост поднят, но адрес не подходит для других устройств',
      );
    } else {
      _setNetworkStatus('Стол открыт и ждёт игроков');
    }
    _clearError();
    notifyListeners();
    return lobby;
  }

  Future<LobbySession?> connectToHost({
    required String host,
    required PlayerIdentity player,
    int port = defaultPort,
    String? lobbyId,
  }) async {
    final normalizedHost = host.trim();
    if (normalizedHost.isEmpty) {
      _setError('Введи IP-адрес хоста');
      return null;
    }

    final unreachableWarning = _hostAddressWarning(normalizedHost);
    if (unreachableWarning != null) {
      _appendDebug('Подключение отменено: $unreachableWarning');
      _setNetworkStatus('Неподходящий адрес хоста');
      _setError(unreachableWarning);
      notifyListeners();
      return null;
    }

    _isConnecting = true;
    _setNetworkStatus('Подключаемся к $normalizedHost:$port');
    _appendDebug(
      'Старт подключения: host=$normalizedHost port=$port lobby=${lobbyId ?? '-'} player=${player.displayName}',
    );
    _clearError();
    notifyListeners();

    try {
      await _closeClientConnection();
      _pendingRemoteLobbyCompleter = Completer<LobbySession>();
      final socket = await WebSocket.connect('ws://$normalizedHost:$port');
      _appendDebug('WebSocket открыт: ws://$normalizedHost:$port');
      _serverConnection = socket;
      _hostAddress = normalizedHost;
      _hostPort = port;
      _isHosting = false;
      _serverSubscription = socket.listen(
        _handleServerMessage,
        onDone: _handleRemoteDisconnected,
        onError: (_) => _handleRemoteDisconnected(),
      );

      _sendToServer({
        'type': 'joinLobby',
        if (lobbyId != null && lobbyId.isNotEmpty) 'lobbyId': lobbyId,
        'player': playerIdentityToJson(player),
      });
      _appendDebug('Отправлен joinLobby');
      unawaited(
        Future<void>.delayed(const Duration(milliseconds: 450), () {
          if (_serverConnection == socket) {
            _sendToServer({
              'type': 'joinLobby',
              if (lobbyId != null && lobbyId.isNotEmpty) 'lobbyId': lobbyId,
              'player': playerIdentityToJson(player),
            });
            _appendDebug('Повторно отправлен joinLobby');
          }
        }),
      );
      final lobby = await _pendingRemoteLobbyCompleter!.future.timeout(
        const Duration(seconds: 6),
      );
      _pendingRemoteLobbyCompleter = null;
      _isConnecting = false;
      _appendDebug(
        'Snapshot получен: lobby=${lobby.id} players=${lobby.players.length} observers=${lobby.observers.length}',
      );
      _setNetworkStatus('Подключение выполнено');
      notifyListeners();
      return lobby;
    } on TimeoutException {
      _pendingRemoteLobbyCompleter = null;
      _isConnecting = false;
      _appendDebug('Таймаут: lobbySnapshot не пришёл за 6 секунд');
      _setNetworkStatus('Хост не прислал snapshot');
      _setError('Хост найден, но не прислал лобби вовремя');
      notifyListeners();
      return null;
    } on SocketException catch (error) {
      _pendingRemoteLobbyCompleter = null;
      _isConnecting = false;
      _appendDebug(
        'SocketException при подключении: ${error.osError?.message ?? error.message}',
      );
      _setNetworkStatus('Ошибка сетевого подключения');
      final message = error.osError?.message.toLowerCase() ?? '';
      if (message.contains('refused')) {
        _setError('По этому IP никто не открыл лобби');
      } else if (message.contains('timed out')) {
        _setError('Хост не ответил. Проверь Wi‑Fi и IP адрес');
      } else {
        _setError(
          'Не удалось подключиться к хосту. Проверь, что оба телефона в одной сети',
        );
      }
      notifyListeners();
      return null;
    } catch (_) {
      _pendingRemoteLobbyCompleter = null;
      _isConnecting = false;
      _appendDebug(
        'Неизвестная ошибка при подключении к $normalizedHost:$port',
      );
      _setNetworkStatus('Не удалось подключиться');
      _setError('Не удалось подключиться к хосту по адресу $normalizedHost');
      notifyListeners();
      return null;
    }
  }

  LobbySession? joinLobby(String lobbyId, PlayerIdentity player) {
    if (_isHosting) {
      return _hostJoinLobby(lobbyId, player);
    }

    _sendToServer({
      'type': 'joinLobby',
      'lobbyId': lobbyId,
      'player': playerIdentityToJson(player),
    });
    return lobbyById(lobbyId);
  }

  Future<void> leaveLobby(String lobbyId, PlayerIdentity player) async {
    if (_isHosting) {
      await _hostLeaveLobby(lobbyId, player);
      return;
    }

    _sendToServer({
      'type': 'leaveLobby',
      'lobbyId': lobbyId,
      'player': playerIdentityToJson(player),
    });
    _lobbies.clear();
    notifyListeners();
  }

  void startGame(String lobbyId) {
    if (_isHosting) {
      _hostStartGame(lobbyId);
      return;
    }

    _sendToServer({'type': 'startGame', 'lobbyId': lobbyId});
  }

  void submitGameAction(
    String lobbyId,
    PlayerIdentity player, {
    required String action,
    int raiseAmount = 0,
  }) {
    if (_isHosting) {
      _hostSubmitGameAction(
        lobbyId,
        player,
        action: action,
        raiseAmount: raiseAmount,
      );
      return;
    }

    _sendToServer({
      'type': 'gameAction',
      'lobbyId': lobbyId,
      'player': playerIdentityToJson(player),
      'action': action,
      'raiseAmount': raiseAmount,
    });
  }

  void revealHand(String lobbyId, PlayerIdentity player) {
    if (_isHosting) {
      _hostRevealHand(lobbyId, player);
      return;
    }

    _sendToServer({
      'type': 'revealHand',
      'lobbyId': lobbyId,
      'player': playerIdentityToJson(player),
    });
  }

  void requestObserverMode(String lobbyId, PlayerIdentity player) {
    if (_isHosting) {
      _hostRequestObserverMode(lobbyId, player);
      return;
    }

    _sendToServer({
      'type': 'requestObserverMode',
      'lobbyId': lobbyId,
      'player': playerIdentityToJson(player),
    });
  }

  LobbySession? requestPlayerMode(String lobbyId, PlayerIdentity player) {
    if (_isHosting) {
      return _hostRequestPlayerMode(lobbyId, player);
    }

    _sendToServer({
      'type': 'requestPlayerMode',
      'lobbyId': lobbyId,
      'player': playerIdentityToJson(player),
    });
    return lobbyById(lobbyId);
  }

  Future<void> disposeNetwork() async {
    for (final timer in _startTimers.values) {
      timer.cancel();
    }
    _startTimers.clear();
    for (final timer in _turnTimers.values) {
      timer.cancel();
    }
    _turnTimers.clear();
    for (final timer in _showdownTimers.values) {
      timer.cancel();
    }
    _showdownTimers.clear();
    for (final timer in _runoutTimers.values) {
      timer.cancel();
    }
    _runoutTimers.clear();
    for (final socket in _connectedClients.keys.toList()) {
      await socket.close();
    }
    _connectedClients.clear();
    await _closeClientConnection();
    await _stopHostEndpoints();
  }

  Future<void> _stopHostEndpoints() async {
    _discoveryResponder?.close();
    _discoveryResponder = null;
    await _hostServer?.close(force: true);
    _hostServer = null;
  }

  Future<void> discoverHosts() async {
    _isDiscovering = true;
    _setNetworkStatus('Ищем столы в локальной сети');
    _clearError();
    notifyListeners();

    RawDatagramSocket? socket;
    final found = <String, DiscoveredLobbyHost>{};

    try {
      socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        0,
        reuseAddress: true,
        reusePort: false,
      );
      socket.broadcastEnabled = true;

      socket.listen((event) {
        if (event != RawSocketEvent.read) {
          return;
        }
        final datagram = socket?.receive();
        if (datagram == null) {
          return;
        }
        final decoded = _decodePayload(utf8.decode(datagram.data));
        if (decoded == null || decoded['type'] != 'hostAnnouncement') {
          return;
        }

        final sessionMap = decoded['lobby'];
        if (sessionMap is! Map) {
          return;
        }

        final lobby = lobbySessionFromJson(
          Map<String, dynamic>.from(sessionMap),
        );
        final host = DiscoveredLobbyHost(
          // The UDP packet source is usually more reliable than a self-reported
          // address when VPN or extra Android interfaces are present.
          address: datagram.address.address,
          port: (decoded['hostPort'] as num?)?.toInt() ?? defaultPort,
          lobby: lobby,
        );
        found['${host.address}:${host.port}'] = host;
        _appendDebug(
          'Найден ответ: ${host.address}:${host.port} lobby=${lobby.settings.displayLobbyName}',
        );
      });

      final requestBytes = utf8.encode(discoveryRequest);
      final broadcastTargets = await _discoveryBroadcastTargets();
      _appendDebug(
        'Поиск отправлен в: ${broadcastTargets.map((item) => item.address).join(', ')}',
      );
      var sentAny = false;
      for (final target in broadcastTargets) {
        try {
          final sentBytes = socket.send(requestBytes, target, discoveryPort);
          if (sentBytes > 0) {
            sentAny = true;
          }
        } on SocketException {
          _appendDebug('Не удалось отправить discovery в ${target.address}');
          continue;
        }
      }

      if (!sentAny) {
        _appendDebug('Ни одна broadcast-цель не приняла discovery-запрос');
        _setNetworkStatus('Поиск не удалось отправить');
        _setError(
          'Не удалось отправить поиск по локальной сети. Проверь Wi-Fi или точку доступа.',
        );
        return;
      }

      await Future.delayed(const Duration(seconds: 2));
      if (found.isEmpty) {
        final directHosts = await _probeHostsDirectly();
        for (final host in directHosts) {
          found['${host.address}:${host.port}'] = host;
        }
      }
      if (found.isEmpty) {
        _appendDebug('Ответов на discovery не получено');
        _setNetworkStatus('Столы не найдены');
      } else {
        final orderedHosts = found.values.toList()
          ..sort((a, b) {
            final nameCompare = a.lobby.settings.displayLobbyName
                .toLowerCase()
                .compareTo(b.lobby.settings.displayLobbyName.toLowerCase());
            if (nameCompare != 0) {
              return nameCompare;
            }
            return '${a.address}:${a.port}'.compareTo('${b.address}:${b.port}');
          });
        _discoveredHosts
          ..clear()
          ..addAll(orderedHosts);
        _setNetworkStatus('Найдено столов: ${found.length}');
        notifyListeners();
      }
    } catch (_) {
      _appendDebug('Ошибка во время поиска столов');
      _setNetworkStatus('Ошибка поиска');
      _setError('Не удалось выполнить поиск хостов в локальной сети');
    } finally {
      socket?.close();
      _isDiscovering = false;
      notifyListeners();
    }
  }

  Future<List<DiscoveredLobbyHost>> _probeHostsDirectly() async {
    final probeTargets = <String>{
      ...await _likelyDirectHostAddresses(),
      '192.168.43.1',
      '192.168.137.1',
      '192.168.232.1',
      '172.20.10.1',
      '10.0.0.1',
    };
    final found = <String, DiscoveredLobbyHost>{};
    final addresses = probeTargets.toList();
    const batchSize = 24;
    for (var start = 0; start < addresses.length; start += batchSize) {
      final batch = addresses.skip(start).take(batchSize).toList();
      final results = await Future.wait(
        batch.map(_probeSingleHost),
      );
      for (final result in results) {
        if (result == null) {
          continue;
        }
        found['${result.address}:${result.port}'] = result;
      }
      if (found.isNotEmpty) {
        break;
      }
    }

    return found.values.toList();
  }

  Future<DiscoveredLobbyHost?> _probeSingleHost(String address) async {
    try {
      _appendDebug('Прямой probe хоста: $address:$defaultPort');
      final socket = await WebSocket.connect(
        'ws://$address:$defaultPort',
      ).timeout(const Duration(milliseconds: 500));
      final payload = await socket.first.timeout(
        const Duration(milliseconds: 700),
      );
      await socket.close();

      final decoded = _decodePayload(payload);
      if (decoded == null || decoded['type'] != 'lobbySnapshot') {
        return null;
      }
      final sessionMap = decoded['lobby'];
      if (sessionMap is! Map) {
        return null;
      }
      final lobby = lobbySessionFromJson(Map<String, dynamic>.from(sessionMap));
      _appendDebug(
        'Прямой probe нашёл стол: $address:$defaultPort lobby=${lobby.settings.displayLobbyName}',
      );
      return DiscoveredLobbyHost(
        address: address,
        port: (decoded['hostPort'] as num?)?.toInt() ?? defaultPort,
        lobby: lobby,
      );
    } catch (_) {
      return null;
    }
  }

  Future<Set<String>> _likelyDirectHostAddresses() async {
    final candidates = await _privateLanCandidates();
    final result = <String>{};
    for (final candidate in candidates) {
      final octets = candidate.address.address.split('.');
      if (octets.length != 4) {
        continue;
      }
      final prefix = '${octets[0]}.${octets[1]}.${octets[2]}.';
      final selfLast = int.tryParse(octets[3]) ?? 0;
      for (var i = 1; i <= 254; i++) {
        if (i == selfLast) {
          continue;
        }
        result.add('$prefix$i');
      }
    }
    return result;
  }

  Future<void> _startHostServer() async {
    _hostAddress = await _resolveLocalAddress();
    if (_hostServer != null) {
      _appendDebug('Хост-адрес обновлён: ${_hostAddress ?? '-'}:$_hostPort');
      return;
    }
    _hostServer = await HttpServer.bind(InternetAddress.anyIPv4, defaultPort);
    _hostPort = defaultPort;
    _appendDebug('Хост-сервер поднят на ${_hostAddress ?? '-'}:$_hostPort');

    unawaited(
      _hostServer!.forEach((request) async {
        if (!WebSocketTransformer.isUpgradeRequest(request)) {
          request.response.statusCode = HttpStatus.badRequest;
          await request.response.close();
          return;
        }

        final socket = await WebSocketTransformer.upgrade(request);
        _appendDebug('Клиент открыл WebSocket: ${socket.hashCode}');
        socket.listen(
          (data) => _handleClientMessage(socket, data),
          onDone: () => _handleClientDisconnected(socket),
          onError: (_) => _handleClientDisconnected(socket),
        );
        _sendSnapshotToSocket(socket);
      }),
    );
  }

  Future<void> _startDiscoveryResponder() async {
    if (_discoveryResponder != null) {
      return;
    }

    _discoveryResponder = await RawDatagramSocket.bind(
      InternetAddress.anyIPv4,
      discoveryPort,
      reuseAddress: true,
      reusePort: false,
    );
    _discoveryResponder!.broadcastEnabled = true;
    _appendDebug('UDP discovery слушает порт $discoveryPort');
    _discoveryResponder!.listen((event) {
      if (event != RawSocketEvent.read) {
        return;
      }

      final datagram = _discoveryResponder!.receive();
      if (datagram == null) {
        return;
      }

      final message = utf8.decode(datagram.data);
      if (message != discoveryRequest || _lobbies.isEmpty) {
        return;
      }
      _appendDebug(
        'Получен discovery от ${datagram.address.address}:${datagram.port}',
      );

      final payload = jsonEncode({
        'type': 'hostAnnouncement',
        'hostAddress': _hostAddress,
        'hostPort': _hostPort,
        'lobby': lobbySessionToJson(
          _lobbies.first,
          hostAddress: _hostAddress,
          hostPort: _hostPort,
        ),
      });

      _discoveryResponder!.send(
        utf8.encode(payload),
        datagram.address,
        datagram.port,
      );
      _appendDebug(
        'Отправлен hostAnnouncement -> ${datagram.address.address}:${datagram.port}',
      );
    });
  }

  Future<String> _resolveLocalAddress() async {
    final candidates = await _privateLanCandidates();
    if (candidates.isEmpty) {
      return '127.0.0.1';
    }

    candidates.sort((a, b) => b.score.compareTo(a.score));
    _appendDebug(
      'Выбран локальный IP: ${candidates.first.address.address} (${candidates.first.interfaceName})',
    );
    return candidates.first.address.address;
  }

  Future<List<InternetAddress>> _discoveryBroadcastTargets() async {
    final targets = <String>{'255.255.255.255'};

    final candidates = await _privateLanCandidates();
    for (final candidate in candidates) {
      final octets = candidate.address.address.split('.');
      if (octets.length != 4) {
        continue;
      }
      targets.add('${octets[0]}.${octets[1]}.${octets[2]}.255');
      targets.add('${octets[0]}.${octets[1]}.${octets[2]}.1');
    }

    return targets.map(InternetAddress.new).toList();
  }

  Future<List<_LanCandidate>> _privateLanCandidates() async {
    final interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
      includeLoopback: false,
    );

    final candidates = <_LanCandidate>[];
    for (final interface in interfaces) {
      final interfaceName = interface.name.toLowerCase();
      final isVpn =
          interfaceName.contains('tun') ||
          interfaceName.contains('ppp') ||
          interfaceName.contains('tap') ||
          interfaceName.contains('vpn');
      final isCellular =
          interfaceName.contains('rmnet') ||
          interfaceName.contains('ccmni') ||
          interfaceName.contains('radio') ||
          interfaceName.contains('cell');
      final isWifiLike =
          interfaceName.contains('wlan') ||
          interfaceName.contains('wifi') ||
          interfaceName.contains('ap') ||
          interfaceName.contains('swlan');

      for (final address in interface.addresses) {
        final ip = address.address;
        if (!_isPrivateLanIp(ip) || ip.startsWith('169.254.')) {
          continue;
        }

        var score = 0;
        if (isWifiLike) {
          score += 100;
        }
        if (!isVpn) {
          score += 20;
        }
        if (!isCellular) {
          score += 10;
        }
        if (ip.startsWith('192.168.')) {
          score += 10;
        }
        if (ip.startsWith('10.')) {
          score += 8;
        }

        candidates.add(
          _LanCandidate(
            address: address,
            interfaceName: interface.name,
            score: score,
          ),
        );
      }
    }

    return candidates;
  }

  bool _isPrivateLanIp(String ip) {
    return ip.startsWith('192.168.') ||
        ip.startsWith('10.') ||
        RegExp(r'^172\.(1[6-9]|2\d|3[0-1])\.').hasMatch(ip);
  }

  void _handleClientMessage(WebSocket socket, dynamic raw) {
    final payload = _decodePayload(raw);
    if (payload == null) {
      return;
    }

    final type = payload['type'] as String? ?? '';
    _appendDebug('Host получил сообщение: $type');
    final playerJson = payload['player'] as Map<String, dynamic>?;
    final player = playerJson == null
        ? null
        : playerIdentityFromJson(playerJson);

    switch (type) {
      case 'joinLobby':
        if (player != null) {
          _connectedClients[socket] = player;
          final lobby = _hostJoinLobby(
            payload['lobbyId'] as String? ?? _currentLobbyId,
            player,
          );
          if (lobby != null) {
            _appendDebug(
              'Игрок ${player.displayName} добавлен в lobby=${lobby.id}',
            );
            _sendSnapshotToSocket(socket);
          } else {
            _appendDebug('Host не нашёл лобби для joinLobby');
          }
        }
        break;
      case 'requestObserverMode':
        if (player != null) {
          _hostRequestObserverMode(
            payload['lobbyId'] as String? ?? _currentLobbyId,
            player,
          );
        }
        break;
      case 'requestPlayerMode':
        if (player != null) {
          _hostRequestPlayerMode(
            payload['lobbyId'] as String? ?? _currentLobbyId,
            player,
          );
        }
        break;
      case 'startGame':
        _hostStartGame(payload['lobbyId'] as String? ?? _currentLobbyId);
        break;
      case 'leaveLobby':
        if (player != null) {
          unawaited(
            _hostLeaveLobby(
              payload['lobbyId'] as String? ?? _currentLobbyId,
              player,
            ),
          );
        }
        break;
      case 'gameAction':
        if (player != null) {
          _hostSubmitGameAction(
            payload['lobbyId'] as String? ?? _currentLobbyId,
            player,
            action: payload['action'] as String? ?? '',
            raiseAmount: (payload['raiseAmount'] as num?)?.toInt() ?? 0,
          );
        }
        break;
      case 'revealHand':
        if (player != null) {
          _hostRevealHand(
            payload['lobbyId'] as String? ?? _currentLobbyId,
            player,
          );
        }
        break;
      default:
        break;
    }
  }

  void _handleServerMessage(dynamic raw) {
    final payload = _decodePayload(raw);
    if (payload == null) {
      return;
    }

    final type = payload['type'] as String? ?? '';
    if (type != 'lobbySnapshot') {
      _appendDebug('Клиент получил сообщение: $type');
      return;
    }

    final sessionJson = payload['lobby'] as Map<String, dynamic>;
    final lobby = lobbySessionFromJson(sessionJson);
    _appendDebug(
      'Клиент получил snapshot: lobby=${lobby.id} players=${lobby.players.length} observers=${lobby.observers.length}',
    );
    _hostAddress = payload['hostAddress'] as String? ?? _hostAddress;
    _hostPort = (payload['hostPort'] as num?)?.toInt() ?? _hostPort;
    _lobbies
      ..clear()
      ..add(lobby);
    if (_pendingRemoteLobbyCompleter != null &&
        !_pendingRemoteLobbyCompleter!.isCompleted) {
      _pendingRemoteLobbyCompleter!.complete(lobby);
    }
    _clearError();
    notifyListeners();
  }

  void _handleClientDisconnected(WebSocket socket) {
    final player = _connectedClients.remove(socket);
    _appendDebug(
      'Клиент отключился: ${player?.displayName ?? 'unknown'} (${socket.hashCode})',
    );
    if (player == null || _lobbies.isEmpty) {
      return;
    }

    final lobby = _lobbies.first;
    final updatedLobby = lobby.copyWith(
      players: lobby.players
          .where((entry) => entry.identity.stableKey != player.stableKey)
          .toList(),
      observers: lobby.observers
          .where((observer) => observer.stableKey != player.stableKey)
          .toList(),
      pendingObserverKeys: lobby.pendingObserverKeys
          .where((key) => key != player.stableKey)
          .toList(),
      pendingPlayerKeys: lobby.pendingPlayerKeys
          .where((key) => key != player.stableKey)
          .toList(),
    );
    _replaceLobby(updatedLobby);
    _broadcastState();
  }

  void _handleRemoteDisconnected() {
    _appendDebug('Соединение с хостом разорвано');
    _setNetworkStatus('Соединение с хостом потеряно');
    _serverConnection = null;
    if (_pendingRemoteLobbyCompleter != null &&
        !_pendingRemoteLobbyCompleter!.isCompleted) {
      _pendingRemoteLobbyCompleter!.completeError(
        StateError('Disconnected before lobby snapshot'),
      );
    }
    _pendingRemoteLobbyCompleter = null;
    _serverSubscription?.cancel();
    _serverSubscription = null;
    _lobbies.clear();
    _setError('Соединение с хостом прервано');
    notifyListeners();
  }

  void _broadcastState() {
    if (_lobbies.isEmpty) {
      return;
    }

    for (final socket in _connectedClients.keys) {
      _sendSnapshotToSocket(socket);
    }
    notifyListeners();
  }

  void _sendSnapshotToSocket(WebSocket socket) {
    if (_lobbies.isEmpty) {
      return;
    }

    final lobby = _lobbies.first;
    _appendDebug(
      'Host отправил snapshot: lobby=${lobby.id} players=${lobby.players.length} observers=${lobby.observers.length}',
    );
    socket.add(
      jsonEncode({
        'type': 'lobbySnapshot',
        'hostAddress': _hostAddress,
        'hostPort': _hostPort,
        'lobby': lobbySessionToJson(
          lobby,
          hostAddress: _hostAddress,
          hostPort: _hostPort,
        ),
      }),
    );
  }

  LobbySession? _hostJoinLobby(String lobbyId, PlayerIdentity player) {
    final lobby = lobbyById(lobbyId);
    if (lobby == null) {
      return null;
    }

    final existingPlayerIndex = lobby.players.indexWhere(
      (entry) => entry.identity.stableKey == player.stableKey,
    );
    if (existingPlayerIndex != -1) {
      _broadcastState();
      return lobby;
    }

    if (!lobby.hasFreeSeats) {
      return null;
    }

    final updatedLobby = lobby.copyWith(
      players: [
        ...lobby.players,
        LobbyPlayerEntry(
          identity: player,
          chips: lobby.settings.startingChips,
          isHost: lobby.settings.host.stableKey == player.stableKey,
        ),
      ],
      observers: lobby.observers
          .where((observer) => observer.stableKey != player.stableKey)
          .toList(),
      pendingPlayerKeys: lobby.pendingPlayerKeys
          .where((key) => key != player.stableKey)
          .toList(),
    );
    _replaceLobby(updatedLobby);
    _broadcastState();
    return updatedLobby;
  }

  Future<void> _hostLeaveLobby(String lobbyId, PlayerIdentity player) async {
    final lobby = lobbyById(lobbyId);
    if (lobby == null) {
      return;
    }

    final playerKey = player.stableKey;
    final updatedLobby = lobby.copyWith(
      players: lobby.players
          .where((entry) => entry.identity.stableKey != playerKey)
          .toList(),
      observers: lobby.observers
          .where((observer) => observer.stableKey != playerKey)
          .toList(),
      pendingObserverKeys: lobby.pendingObserverKeys
          .where((key) => key != playerKey)
          .toList(),
      pendingPlayerKeys: lobby.pendingPlayerKeys
          .where((key) => key != playerKey)
          .toList(),
    );

    final isEmpty =
        updatedLobby.players.isEmpty && updatedLobby.observers.isEmpty;
    if (isEmpty) {
      _lobbies.clear();
      for (final timer in _startTimers.values) {
        timer.cancel();
      }
      _startTimers.clear();
      _turnTimers.remove(lobbyId)?.cancel();
      _showdownTimers.remove(lobbyId)?.cancel();
      _runoutTimers.remove(lobbyId)?.cancel();
      _broadcastState();
      await disposeNetwork();
      _isHosting = false;
      notifyListeners();
      return;
    }

    if (updatedLobby.isStarted) {
      final normalized = _normalizeActiveLobbyAfterPlayerChange(updatedLobby);
      _replaceLobby(normalized);
      _broadcastState();
      return;
    }

    _replaceLobby(updatedLobby);
    _broadcastState();
  }

  void _hostStartGame(String lobbyId) {
    final lobby = lobbyById(lobbyId);
    if (lobby == null || lobby.isStarted || lobby.isCountingDown) {
      return;
    }

    final countdownEndsAt = DateTime.now().add(const Duration(seconds: 3));
    final updatedLobby = lobby.copyWith(
      countdownEndsAt: countdownEndsAt,
      isStarted: false,
    );
    _replaceLobby(updatedLobby);
    _startTimers[lobbyId]?.cancel();
    _startTimers[lobbyId] = Timer(const Duration(seconds: 3), () {
      _finishGameStart(lobbyId);
    });
    _broadcastState();
  }

  void _finishGameStart(String lobbyId) {
    final lobby = lobbyById(lobbyId);
    if (lobby == null) {
      return;
    }

    final preparedLobby = lobby.copyWith(
      players: _applyPendingPlayerMoves(lobby),
      observers: _applyPendingObservers(lobby),
      pendingObserverKeys: const [],
      pendingPlayerKeys: const [],
    );
    if (preparedLobby.players.length < 2) {
      final waitingLobby = preparedLobby.copyWith(
        isStarted: false,
        clearCountdownEndsAt: true,
        clearGameState: true,
      );
      _replaceLobby(waitingLobby);
      _startTimers.remove(lobbyId)?.cancel();
      _turnTimers.remove(lobbyId)?.cancel();
      _showdownTimers.remove(lobbyId)?.cancel();
      _runoutTimers.remove(lobbyId)?.cancel();
      _broadcastState();
      return;
    }

    final updatedLobby = preparedLobby.copyWith(
      isStarted: true,
      clearCountdownEndsAt: true,
      demoScenarioIndex: _random.nextInt(4),
      gameState: _createInitialGameState(
        preparedLobby,
      ),
    );

    _replaceLobby(updatedLobby);
    _startTimers.remove(lobbyId)?.cancel();
    _scheduleTurnTimeout(lobbyId, updatedLobby.gameState!);
    _broadcastState();
  }

  void _hostRequestObserverMode(String lobbyId, PlayerIdentity player) {
    final lobby = lobbyById(lobbyId);
    if (lobby == null) {
      return;
    }

    final playerKey = player.stableKey;
    final isAlreadyObserver = lobby.observers.any(
      (observer) => observer.stableKey == playerKey,
    );
    if (isAlreadyObserver) {
      return;
    }

    LobbySession updatedLobby;
    if (!lobby.isStarted) {
      final updatedPlayers = lobby.players
          .where((entry) => entry.identity.stableKey != playerKey)
          .toList();
      updatedLobby = lobby.copyWith(
        players: updatedPlayers,
        observers: [...lobby.observers, player],
        pendingPlayerKeys: lobby.pendingPlayerKeys
            .where((key) => key != playerKey)
            .toList(),
      );
    } else {
      if (lobby.pendingObserverKeys.contains(playerKey)) {
        return;
      }
      updatedLobby = lobby.copyWith(
        pendingObserverKeys: [...lobby.pendingObserverKeys, playerKey],
      );
    }

    final normalized = (!lobby.isStarted)
        ? updatedLobby
        : _normalizeActiveLobbyAfterPlayerChange(updatedLobby);
    _replaceLobby(normalized);
    _broadcastState();
  }

  LobbySession? _hostRequestPlayerMode(String lobbyId, PlayerIdentity player) {
    final lobby = lobbyById(lobbyId);
    if (lobby == null) {
      return null;
    }

    final playerKey = player.stableKey;
    final isAlreadyPlayer = lobby.players.any(
      (entry) => entry.identity.stableKey == playerKey,
    );
    if (isAlreadyPlayer) {
      return lobby;
    }

    if (!lobby.hasFreeSeats) {
      return null;
    }

    LobbySession updatedLobby;
    if (!lobby.isStarted) {
      updatedLobby = lobby.copyWith(
        players: [
          ...lobby.players,
          LobbyPlayerEntry(
            identity: player,
            chips: lobby.settings.startingChips,
            isHost: lobby.settings.host.stableKey == playerKey,
          ),
        ],
        observers: lobby.observers
            .where((observer) => observer.stableKey != playerKey)
            .toList(),
        pendingObserverKeys: lobby.pendingObserverKeys
            .where((key) => key != playerKey)
            .toList(),
        pendingPlayerKeys: lobby.pendingPlayerKeys
            .where((key) => key != playerKey)
            .toList(),
      );
    } else {
      if (lobby.pendingPlayerKeys.contains(playerKey)) {
        return lobby;
      }
      updatedLobby = lobby.copyWith(
        pendingPlayerKeys: [...lobby.pendingPlayerKeys, playerKey],
        pendingObserverKeys: lobby.pendingObserverKeys
            .where((key) => key != playerKey)
            .toList(),
      );
    }

    _replaceLobby(updatedLobby);
    _broadcastState();
    return updatedLobby;
  }

  List<LobbyPlayerEntry> _applyPendingPlayerMoves(LobbySession lobby) {
    var players = [...lobby.players];

    for (final observerKey in lobby.pendingObserverKeys) {
      players = players
          .where((entry) => entry.identity.stableKey != observerKey)
          .toList();
    }

    for (final playerKey in lobby.pendingPlayerKeys) {
      final alreadyPlayer = players.any(
        (entry) => entry.identity.stableKey == playerKey,
      );
      if (alreadyPlayer || players.length >= lobby.settings.seatsCount) {
        continue;
      }

      final observer = lobby.observers.where(
        (item) => item.stableKey == playerKey,
      );
      if (observer.isEmpty) {
        continue;
      }

      final identity = observer.first;
      players.add(
        LobbyPlayerEntry(
          identity: identity,
          chips: lobby.settings.startingChips,
          isHost: lobby.settings.host.stableKey == playerKey,
        ),
      );
    }

    return players;
  }

  List<PlayerIdentity> _applyPendingObservers(LobbySession lobby) {
    final observers = [...lobby.observers];

    for (final observerKey in lobby.pendingObserverKeys) {
      final player = lobby.players.where(
        (entry) => entry.identity.stableKey == observerKey,
      );
      if (player.isNotEmpty &&
          observers.every((item) => item.stableKey != observerKey)) {
        observers.add(player.first.identity);
      }
    }

    return observers
        .where(
          (observer) => !lobby.pendingPlayerKeys.contains(observer.stableKey),
        )
        .toList();
  }

  PokerGameState _createInitialGameState(
    LobbySession lobby, {
    String? previousDealerKey,
  }) {
    final players = lobby.players;
    if (players.isEmpty) {
      return const PokerGameState(
        street: 'preflop',
        pot: 0,
        currentBet: 0,
        dealerKey: '',
        activePlayerKey: '',
        turnEndsAt: null,
        isShowdown: false,
        showdownEndsAt: null,
        winnerKey: '',
        winnerLabel: '',
        players: [],
        communityCards: [],
      );
    }
    var dealerIndex = 0;
    if (previousDealerKey != null && previousDealerKey.isNotEmpty) {
      final previousIndex = players.indexWhere(
        (entry) => entry.identity.stableKey == previousDealerKey,
      );
      if (previousIndex != -1) {
        dealerIndex = (previousIndex + 1) % players.length;
      }
    }
    final dealerKey = players[dealerIndex].identity.stableKey;
    final sbIndex = players.length > 1 ? 1 : 0;
    final bbIndex = players.length > 2 ? 2 : (players.length > 1 ? 1 : 0);
    final playerStates = <PokerGamePlayerState>[];
    var pot = 0;

    for (var i = 0; i < players.length; i++) {
      var chips = players[i].chips;
      var contribution = 0;
      var action = '';
      if (i == sbIndex && players.length > 1) {
        contribution = math.min(chips, lobby.settings.smallBlind);
        chips -= contribution;
        action = 'small blind';
      }
      if (i == bbIndex && players.length > 1) {
        contribution = math.min(chips, lobby.settings.bigBlind);
        chips -= contribution;
        action = 'big blind';
      }
      pot += contribution;
      playerStates.add(
        PokerGamePlayerState(
          playerKey: players[i].identity.stableKey,
          chips: chips,
          isFolded: false,
          isDealer: i == dealerIndex,
          streetContribution: contribution,
          handContribution: contribution,
          lastAction: action,
          isRevealed: false,
          holeCards: [_drawCardState(), _drawCardState()],
        ),
      );
    }

    final activeIndex = players.length > 2 ? 0 : (players.length > 1 ? 1 : 0);
    return PokerGameState(
      street: 'preflop',
      pot: pot,
      currentBet: lobby.settings.bigBlind,
      dealerKey: dealerKey,
      activePlayerKey: playerStates[activeIndex].playerKey,
      turnEndsAt: DateTime.now().add(const Duration(seconds: 10)),
      isShowdown: false,
      showdownEndsAt: null,
      winnerKey: '',
      winnerLabel: '',
      players: playerStates,
      communityCards: const [],
    );
  }

  PokerCardState _drawCardState() {
    const ranks = ['A', 'K', 'Q', 'J', '10', '9', '8', '7', '6', '5', '4', '3', '2'];
    const suits = ['♠', '♥', '♣', '♦'];
    return PokerCardState(
      rank: ranks[_random.nextInt(ranks.length)],
      suit: suits[_random.nextInt(suits.length)],
    );
  }

  void _hostSubmitGameAction(
    String lobbyId,
    PlayerIdentity player, {
    required String action,
    required int raiseAmount,
  }) {
    final lobby = lobbyById(lobbyId);
    final game = lobby?.gameState;
    if (lobby == null || game == null || game.isShowdown) {
      return;
    }
    if (game.activePlayerKey != player.stableKey) {
      return;
    }

    final playerIndex = game.players.indexWhere(
      (item) => item.playerKey == player.stableKey,
    );
    if (playerIndex == -1) {
      return;
    }

    final players = [...game.players];
    final current = players[playerIndex];
    final callAmount = math.max(0, game.currentBet - current.streetContribution);
    PokerGamePlayerState updatedCurrent = current;
    var pot = game.pot;
    var currentBet = game.currentBet;
    var effectiveAction = action;

    switch (action) {
      case 'fold':
        updatedCurrent = current.copyWith(isFolded: true, lastAction: 'fold');
        break;
      case 'check':
      case 'call':
        final paid = math.min(current.chips, callAmount);
        updatedCurrent = current.copyWith(
          chips: current.chips - paid,
          streetContribution: current.streetContribution + paid,
          handContribution: current.handContribution + paid,
          lastAction: callAmount == 0 && paid > 0
              ? 'bet'
              : callAmount == 0
              ? 'check'
              : 'call',
        );
        pot += paid;
        break;
      case 'raise':
        if (current.chips <= callAmount) {
          final paid = math.min(current.chips, callAmount);
          updatedCurrent = current.copyWith(
            chips: current.chips - paid,
            streetContribution: current.streetContribution + paid,
            handContribution: current.handContribution + paid,
            lastAction: paid < callAmount ? 'all-in' : 'call',
          );
          pot += paid;
          effectiveAction = 'call';
          break;
        }
        final extra = math.max(lobby.settings.bigBlind, raiseAmount);
        final targetBet = game.currentBet + extra;
        final paid = math.min(
          current.chips,
          math.max(0, targetBet - current.streetContribution),
        );
        updatedCurrent = current.copyWith(
          chips: current.chips - paid,
          streetContribution: current.streetContribution + paid,
          handContribution: current.handContribution + paid,
          lastAction: callAmount == 0 ? 'bet' : 'raise',
        );
        pot += paid;
        currentBet = updatedCurrent.streetContribution;
        break;
      default:
        return;
    }
    players[playerIndex] = updatedCurrent;
    final normalizedPlayers = players;

    final allInRunoutState = _buildAllInRunoutState(
      game.copyWith(
        pot: pot,
        currentBet: currentBet,
        players: normalizedPlayers,
      ),
    );
    if (allInRunoutState != null) {
      _replaceLobby(lobby.copyWith(gameState: allInRunoutState));
      _scheduleNetworkRunoutStep(lobbyId);
      _broadcastState();
      return;
    }
    final livePlayers = normalizedPlayers.where((item) => !item.isFolded).toList();
    if (livePlayers.length == 1) {
      final showdownState = _startNetworkShowdown(
        game.copyWith(
          pot: pot,
          currentBet: currentBet,
          players: normalizedPlayers,
          winnerKey: livePlayers.first.playerKey,
          winnerLabel: '${_displayNameByKey(lobby, livePlayers.first.playerKey)} забрал банк',
        ),
      );
      _replaceLobby(lobby.copyWith(gameState: showdownState));
      _scheduleTurnTimeout(lobbyId, showdownState);
      _broadcastState();
      return;
    }

    final nextState = _advanceNetworkTurn(
      lobby,
      game.copyWith(
        pot: pot,
        currentBet: currentBet,
        players: normalizedPlayers,
      ),
      justRaised: effectiveAction == 'raise',
      actorKey: current.playerKey,
    );
    _replaceLobby(lobby.copyWith(gameState: nextState));
    _scheduleTurnTimeout(lobbyId, nextState);
    _broadcastState();
  }

  PokerGameState _advanceNetworkTurn(
    LobbySession lobby,
    PokerGameState game, {
    required bool justRaised,
    required String actorKey,
  }) {
    final players = [...game.players];
    final actingIndexes = <int>[
      for (var i = 0; i < players.length; i++) if (_canActInHand(players[i])) i,
    ];
    if (actingIndexes.isEmpty) {
      return _advanceNetworkStreet(lobby, game);
    }
    final allMatched = actingIndexes.every(
      (i) => players[i].streetContribution == game.currentBet,
    );
    if (allMatched && !justRaised) {
      return _advanceNetworkStreet(lobby, game);
    }

    final actorIndex = players.indexWhere((item) => item.playerKey == actorKey);
    var nextIndex = actorIndex;
    do {
      nextIndex = (nextIndex + 1) % players.length;
    } while (!_canActInHand(players[nextIndex]));

    return game.copyWith(
      activePlayerKey: players[nextIndex].playerKey,
      turnEndsAt: DateTime.now().add(const Duration(seconds: 10)),
      winnerLabel: '',
      winnerKey: '',
    );
  }

  PokerGameState _advanceNetworkStreet(LobbySession lobby, PokerGameState game) {
    final players = game.players
        .map(
          (item) => item.copyWith(
            streetContribution: 0,
            lastAction: '',
          ),
        )
        .toList();
    switch (game.street) {
      case 'preflop':
        return game.copyWith(
          street: 'flop',
          currentBet: 0,
          communityCards: [_drawCardState(), _drawCardState(), _drawCardState()],
          players: players,
          activePlayerKey: _nextLivePlayerKey(players, game.dealerKey),
          turnEndsAt: DateTime.now().add(const Duration(seconds: 10)),
        );
      case 'flop':
        return game.copyWith(
          street: 'turn',
          currentBet: 0,
          communityCards: [...game.communityCards, _drawCardState()],
          players: players,
          activePlayerKey: _nextLivePlayerKey(players, game.dealerKey),
          turnEndsAt: DateTime.now().add(const Duration(seconds: 10)),
        );
      case 'turn':
        return game.copyWith(
          street: 'river',
          currentBet: 0,
          communityCards: [...game.communityCards, _drawCardState()],
          players: players,
          activePlayerKey: _nextLivePlayerKey(players, game.dealerKey),
          turnEndsAt: DateTime.now().add(const Duration(seconds: 10)),
        );
      case 'river':
        return _startNetworkShowdown(game);
      default:
        return game;
    }
  }

  PokerGameState _startNetworkShowdown(PokerGameState game) {
    final players = game.players
        .map(
          (item) => item.copyWith(
            lastAction: item.isFolded ? item.lastAction : '',
            isRevealed: item.isFolded ? item.isRevealed : false,
          ),
        )
        .toList();
    return game.copyWith(
      isShowdown: true,
      showdownEndsAt: DateTime.now().add(const Duration(seconds: 7)),
      clearTurnEndsAt: true,
      activePlayerKey: '',
      players: players,
    );
  }

  void _hostRevealHand(String lobbyId, PlayerIdentity player) {
    final lobby = lobbyById(lobbyId);
    final game = lobby?.gameState;
    if (lobby == null || game == null || !game.isShowdown) {
      return;
    }
    final playerIndex = game.players.indexWhere(
      (item) => item.playerKey == player.stableKey,
    );
    if (playerIndex == -1) {
      return;
    }
    final players = [...game.players];
    players[playerIndex] = players[playerIndex].copyWith(
      isRevealed: true,
      lastAction: 'show',
    );
    final updated = game.copyWith(players: players);
    _replaceLobby(lobby.copyWith(gameState: updated));
    _broadcastState();
    if (players.where((item) => !item.isRevealed).isEmpty) {
      final winnerKey = updated.winnerKey.isNotEmpty
          ? updated.winnerKey
          : players.firstWhere((item) => !item.isFolded, orElse: () => players.first).playerKey;
      _finishNetworkHand(
        lobbyId,
        winnerKey: winnerKey,
        players: players,
        pot: updated.pot,
      );
    }
  }

  void _scheduleTurnTimeout(String lobbyId, PokerGameState state) {
    _turnTimers.remove(lobbyId)?.cancel();
    _showdownTimers.remove(lobbyId)?.cancel();
    _runoutTimers.remove(lobbyId)?.cancel();
    if (state.isShowdown) {
      _showdownTimers[lobbyId] = Timer(const Duration(seconds: 7), () {
        final lobby = lobbyById(lobbyId);
        final game = lobby?.gameState;
        if (lobby == null ||
            game == null ||
            !game.isShowdown ||
            game.players.isEmpty) {
          return;
        }
        final revealed = game.players
            .where((item) => item.isRevealed && !item.isFolded)
            .toList();
        final winnerKey = game.winnerKey.isNotEmpty
            ? game.winnerKey
            : (revealed.isNotEmpty
                  ? revealed.first.playerKey
                  : game.players.where((item) => !item.isFolded).first.playerKey);
        _finishNetworkHand(
          lobbyId,
          winnerKey: winnerKey,
          players: game.players,
          pot: game.pot,
        );
      });
      return;
    }
    if (state.activePlayerKey.isEmpty) {
      return;
    }
    _turnTimers[lobbyId] = Timer(const Duration(seconds: 10), () {
      final lobby = lobbyById(lobbyId);
      final game = lobby?.gameState;
      if (lobby == null ||
          game == null ||
          game.isShowdown ||
          game.activePlayerKey.isEmpty) {
        return;
      }
      final playerEntry = lobby.players.where(
        (item) => item.identity.stableKey == game.activePlayerKey,
      );
      final playerStateEntry = game.players.where(
        (item) => item.playerKey == game.activePlayerKey,
      );
      if (playerEntry.isEmpty || playerStateEntry.isEmpty) {
        return;
      }
      final playerIdentity = playerEntry.first.identity;
      final playerState = playerStateEntry.first;
      final callAmount = math.max(0, game.currentBet - playerState.streetContribution);
      _hostSubmitGameAction(
        lobbyId,
        playerIdentity,
        action: callAmount == 0 ? 'check' : 'fold',
        raiseAmount: 0,
      );
    });
  }

  String _nextLivePlayerKey(List<PokerGamePlayerState> players, String dealerKey) {
    final dealerIndex = players.indexWhere((item) => item.playerKey == dealerKey);
    final hasActor = players.any(_canActInHand);
    if (!hasActor) {
      return players.firstWhere((item) => !item.isFolded, orElse: () => players.first).playerKey;
    }
    var cursor = dealerIndex;
    do {
      cursor = (cursor + 1) % players.length;
    } while (!_canActInHand(players[cursor]));
    return players[cursor].playerKey;
  }

  PokerGameState? _buildAllInRunoutState(PokerGameState game) {
    final normalized = _refundUnmatchedExcess(game.players);
    final livePlayers = normalized.players.where((item) => !item.isFolded).toList();
    if (livePlayers.length < 2) {
      return null;
    }
    final anyAllIn = livePlayers.any((item) => item.chips <= 0);
    if (!anyAllIn) {
      return null;
    }
    final actionablePlayers = livePlayers.where((item) => item.chips > 0).toList();
    if (actionablePlayers.length >= 2) {
      return null;
    }
    final allMatched = livePlayers.every(
      (item) => item.streetContribution == normalized.currentBet,
    );
    if (!allMatched) {
      return null;
    }
    return game.copyWith(
      pot: normalized.pot,
      currentBet: normalized.currentBet,
      players: normalized.players,
      activePlayerKey: '',
      clearTurnEndsAt: true,
      winnerLabel: '',
      winnerKey: '',
    );
  }

  void _scheduleNetworkRunoutStep(String lobbyId) {
    _turnTimers.remove(lobbyId)?.cancel();
    _showdownTimers.remove(lobbyId)?.cancel();
    _runoutTimers.remove(lobbyId)?.cancel();
    _runoutTimers[lobbyId] = Timer(const Duration(seconds: 2), () {
      final lobby = lobbyById(lobbyId);
      final game = lobby?.gameState;
      if (lobby == null || game == null || game.isShowdown) {
        return;
      }
      if (game.communityCards.length >= 5) {
        final showdown = _startNetworkShowdown(game);
        _replaceLobby(lobby.copyWith(gameState: showdown));
        _scheduleTurnTimeout(lobbyId, showdown);
        _broadcastState();
        return;
      }

      List<PokerCardState> nextCards;
      String nextStreet;
      if (game.communityCards.length < 3) {
        nextCards = [_drawCardState(), _drawCardState(), _drawCardState()];
        nextStreet = 'flop';
      } else if (game.communityCards.length == 3) {
        nextCards = [...game.communityCards, _drawCardState()];
        nextStreet = 'turn';
      } else {
        nextCards = [...game.communityCards, _drawCardState()];
        nextStreet = 'river';
      }

      final updated = game.copyWith(
        communityCards: nextCards,
        street: nextStreet,
        activePlayerKey: '',
        clearTurnEndsAt: true,
      );
      _replaceLobby(lobby.copyWith(gameState: updated));
      _broadcastState();
      _scheduleNetworkRunoutStep(lobbyId);
    });
  }

  void _finishNetworkHand(
    String lobbyId, {
    required String winnerKey,
    required List<PokerGamePlayerState> players,
    required int pot,
  }) {
    final lobby = lobbyById(lobbyId);
    if (lobby == null || lobby.players.isEmpty) {
      return;
    }
    final resolution = lobby.gameState != null &&
            (lobby.gameState!.isShowdown ||
                players.where((item) => !item.isFolded).length > 1)
        ? _resolveNetworkShowdown(
            lobby: lobby,
            players: players,
            fallbackWinnerKey: winnerKey,
          )
        : _NetworkHandResolution(
            players: players.map((item) {
              if (item.playerKey == winnerKey) {
                return item.copyWith(
                  chips: item.chips + pot,
                  lastAction: 'wins',
                );
              }
              return item;
            }).toList(),
            winnerKeys: [winnerKey],
            winnerLabel: '${_displayNameByKey(lobby, winnerKey)} выиграл банк',
          );
    final updatedPlayersState = resolution.players;
    final primaryWinnerKey = resolution.winnerKeys.isNotEmpty
        ? resolution.winnerKeys.first
        : winnerKey;
    final updatedLobbyPlayers = lobby.players.map((entry) {
      final state = updatedPlayersState.firstWhere(
        (item) => item.playerKey == entry.identity.stableKey,
        orElse: () => PokerGamePlayerState(
          playerKey: entry.identity.stableKey,
          chips: entry.chips,
          isFolded: false,
          isDealer: false,
          streetContribution: 0,
          handContribution: 0,
          lastAction: '',
          isRevealed: false,
          holeCards: const [],
        ),
      );
      return entry.copyWith(chips: state.chips);
    }).toList();
    final bustedKeys = updatedLobbyPlayers
        .where((entry) => entry.chips <= 0)
        .map((entry) => entry.identity.stableKey)
        .toSet();
    final activeLobbyPlayers = updatedLobbyPlayers
        .where((entry) => entry.chips > 0)
        .toList();
    final activeGamePlayers = updatedPlayersState
        .where((item) => !bustedKeys.contains(item.playerKey))
        .toList();
    final observerMap = <String, PlayerIdentity>{
      for (final observer in lobby.observers) observer.stableKey: observer,
    };
    for (final busted in updatedLobbyPlayers.where((entry) => entry.chips <= 0)) {
      observerMap[busted.identity.stableKey] = busted.identity;
    }
    final game = lobby.gameState!;
    final finalGame = game.copyWith(
      players: activeGamePlayers,
      isShowdown: false,
      clearShowdownEndsAt: true,
      clearTurnEndsAt: true,
      winnerKey: primaryWinnerKey,
      winnerLabel: resolution.winnerLabel,
      activePlayerKey: primaryWinnerKey,
    );
    _replaceLobby(
      lobby.copyWith(
        players: activeLobbyPlayers,
        observers: observerMap.values.toList(),
        gameState: finalGame,
      ),
    );
    _turnTimers.remove(lobbyId)?.cancel();
    _showdownTimers.remove(lobbyId)?.cancel();
    _runoutTimers.remove(lobbyId)?.cancel();
    _broadcastState();
    _showdownTimers[lobbyId] = Timer(const Duration(seconds: 3), () {
      final latestLobby = lobbyById(lobbyId);
      if (latestLobby == null || latestLobby.gameState == null) {
        return;
      }
      if (latestLobby.players.length < 2) {
        final waitingLobby = latestLobby.copyWith(
          isStarted: false,
          pendingObserverKeys: const [],
          pendingPlayerKeys: const [],
          clearGameState: true,
        );
        _replaceLobby(waitingLobby);
        _broadcastState();
        return;
      }
      final nextGame = _createInitialGameState(
        latestLobby.copyWith(
          gameState: null,
          clearGameState: true,
        ),
        previousDealerKey: latestLobby.gameState!.dealerKey,
      );
      _replaceLobby(latestLobby.copyWith(gameState: nextGame));
      _scheduleTurnTimeout(lobbyId, nextGame);
      _broadcastState();
    });
  }

  LobbySession _normalizeActiveLobbyAfterPlayerChange(LobbySession lobby) {
    if (!lobby.isStarted) {
      return lobby;
    }
    if (lobby.players.length < 2) {
      _turnTimers.remove(lobby.id)?.cancel();
      _showdownTimers.remove(lobby.id)?.cancel();
      _startTimers.remove(lobby.id)?.cancel();
      return lobby.copyWith(
        isStarted: false,
        clearCountdownEndsAt: true,
        pendingObserverKeys: const [],
        pendingPlayerKeys: const [],
        clearGameState: true,
      );
    }

    final game = lobby.gameState;
    if (game == null) {
      return lobby;
    }

    final validKeys = lobby.players.map((item) => item.identity.stableKey).toSet();
    final filteredPlayers = game.players
        .where((item) => validKeys.contains(item.playerKey))
        .toList();
    if (filteredPlayers.length < 2) {
      _turnTimers.remove(lobby.id)?.cancel();
      _showdownTimers.remove(lobby.id)?.cancel();
      return lobby.copyWith(
        isStarted: false,
        clearCountdownEndsAt: true,
        pendingObserverKeys: const [],
        pendingPlayerKeys: const [],
        clearGameState: true,
      );
    }

    final nextActiveKey = validKeys.contains(game.activePlayerKey)
        ? game.activePlayerKey
        : filteredPlayers.firstWhere((item) => !item.isFolded, orElse: () => filteredPlayers.first).playerKey;
    final nextDealerKey = validKeys.contains(game.dealerKey)
        ? game.dealerKey
        : filteredPlayers.first.playerKey;

    return lobby.copyWith(
      gameState: game.copyWith(
        dealerKey: nextDealerKey,
        activePlayerKey: nextActiveKey,
        players: filteredPlayers,
        winnerKey: validKeys.contains(game.winnerKey) ? game.winnerKey : '',
      ),
    );
  }

  String _displayNameByKey(LobbySession lobby, String playerKey) {
    if (lobby.players.isEmpty) {
      return 'Игрок';
    }
    for (final player in lobby.players) {
      if (player.identity.stableKey == playerKey) {
        return player.identity.displayName;
      }
    }
    return 'Игрок';
  }

  bool _canActInHand(PokerGamePlayerState player) {
    return !player.isFolded && player.chips > 0;
  }

  _NormalizedPotState _refundUnmatchedExcess(List<PokerGamePlayerState> players) {
    final livePlayers = players.where((item) => !item.isFolded).toList();
    final actionablePlayers = livePlayers.where((item) => item.chips > 0).toList();
    final currentBet = players.fold<int>(
      0,
      (maxValue, item) => item.streetContribution > maxValue ? item.streetContribution : maxValue,
    );
    final pot = players.fold<int>(0, (sum, item) => sum + item.handContribution);
    if (livePlayers.length < 2 || actionablePlayers.length > 1) {
      return _NormalizedPotState(players: players, currentBet: currentBet, pot: pot);
    }

    final sortedContributions = livePlayers
        .map((item) => item.streetContribution)
        .toList()
      ..sort();
    final cap = sortedContributions.length >= 2
        ? sortedContributions[sortedContributions.length - 2]
        : sortedContributions.last;
    final updatedPlayers = players.map((item) {
      if (item.isFolded || item.streetContribution <= cap) {
        return item;
      }
      final refund = item.streetContribution - cap;
      return item.copyWith(
        chips: item.chips + refund,
        streetContribution: cap,
        handContribution: item.handContribution - refund,
      );
    }).toList();
    return _NormalizedPotState(
      players: updatedPlayers,
      currentBet: cap,
      pot: updatedPlayers.fold<int>(0, (sum, item) => sum + item.handContribution),
    );
  }

  List<_NetworkSidePot> _buildNetworkSidePots(List<PokerGamePlayerState> players) {
    final positive = players.where((item) => item.handContribution > 0).toList();
    if (positive.isEmpty) {
      return const [];
    }
    final levels = positive.map((item) => item.handContribution).toSet().toList()
      ..sort();
    final pots = <_NetworkSidePot>[];
    var previous = 0;
    for (final level in levels) {
      final participants = positive.where((item) => item.handContribution >= level).toList();
      final amount = (level - previous) * participants.length;
      if (amount > 0) {
        pots.add(
          _NetworkSidePot(
            amount: amount,
            eligibleKeys: [
              for (final player in participants)
                if (!player.isFolded) player.playerKey,
            ],
          ),
        );
      }
      previous = level;
    }
    return pots;
  }

  _NetworkHandResolution _resolveNetworkShowdown({
    required LobbySession lobby,
    required List<PokerGamePlayerState> players,
    required String fallbackWinnerKey,
  }) {
    final normalized = _refundUnmatchedExcess(players);
    var workingPlayers = normalized.players;
    final revealedLiveKeys = workingPlayers
        .where((item) => !item.isFolded && item.isRevealed)
        .map((item) => item.playerKey)
        .toSet();
    if (revealedLiveKeys.isNotEmpty) {
      workingPlayers = workingPlayers
          .map(
            (item) => !item.isFolded && !item.isRevealed
                ? item.copyWith(isFolded: true, lastAction: 'hide')
                : item,
          )
          .toList();
    }

    final communityCards = lobby.gameState?.communityCards ?? const <PokerCardState>[];
    final evaluations = <String, PokerHandEvaluation>{};
    for (final player in workingPlayers.where((item) => !item.isFolded)) {
      evaluations[player.playerKey] = evaluateBestPokerHand([
        for (final card in player.holeCards)
          PokerEvalCard(rank: _rankValue(card.rank), suit: card.suit),
        for (final card in communityCards)
          PokerEvalCard(rank: _rankValue(card.rank), suit: card.suit),
      ]);
    }

    final sidePots = _buildNetworkSidePots(workingPlayers);
    if (sidePots.isEmpty) {
      return _NetworkHandResolution(
        players: workingPlayers,
        winnerKeys: [fallbackWinnerKey],
        winnerLabel: '${_displayNameByKey(lobby, fallbackWinnerKey)} выиграл банк',
      );
    }

    final payouts = <String, int>{};
    for (final sidePot in sidePots) {
      final contenders = sidePot.eligibleKeys
          .where((key) => evaluations.containsKey(key))
          .toList();
      if (contenders.isEmpty) {
        continue;
      }
      var winners = <String>[contenders.first];
      var best = evaluations[contenders.first]!;
      for (final contender in contenders.skip(1)) {
        final compare = comparePokerHands(evaluations[contender]!, best);
        if (compare > 0) {
          winners = [contender];
          best = evaluations[contender]!;
        } else if (compare == 0) {
          winners.add(contender);
        }
      }
      final share = sidePot.amount ~/ winners.length;
      var remainder = sidePot.amount % winners.length;
      for (final winner in winners) {
        payouts[winner] = (payouts[winner] ?? 0) + share + (remainder > 0 ? 1 : 0);
        if (remainder > 0) {
          remainder -= 1;
        }
      }
    }

    final updatedPlayers = workingPlayers.map((item) {
      final won = payouts[item.playerKey] ?? 0;
      if (won <= 0) {
        return item;
      }
      return item.copyWith(
        chips: item.chips + won,
        lastAction: 'wins',
      );
    }).toList();
    final winnerKeys = payouts.entries
        .where((entry) => entry.value > 0)
        .map((entry) => entry.key)
        .toList();
    final winnerLabel = winnerKeys.isEmpty
        ? '${_displayNameByKey(lobby, fallbackWinnerKey)} выиграл банк'
        : winnerKeys.length == 1
        ? '${_displayNameByKey(lobby, winnerKeys.first)} выиграл банк'
        : '${winnerKeys.map((key) => _displayNameByKey(lobby, key)).join(', ')} поделили банк';
    return _NetworkHandResolution(
      players: updatedPlayers,
      winnerKeys: winnerKeys.isEmpty ? [fallbackWinnerKey] : winnerKeys,
      winnerLabel: winnerLabel,
    );
  }

  int _rankValue(String rank) {
    return switch (rank) {
      'A' => 14,
      'K' => 13,
      'Q' => 12,
      'J' => 11,
      '10' => 10,
      '9' => 9,
      '8' => 8,
      '7' => 7,
      '6' => 6,
      '5' => 5,
      '4' => 4,
      '3' => 3,
      '2' => 2,
      _ => 0,
    };
  }

  Map<String, dynamic>? _decodePayload(dynamic raw) {
    if (raw is! String) {
      return null;
    }
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      return null;
    }
    return decoded.map((key, value) => MapEntry(key.toString(), value));
  }

  void _replaceLobby(LobbySession updatedLobby) {
    final index = _lobbies.indexWhere((item) => item.id == updatedLobby.id);
    if (index == -1) {
      _lobbies
        ..clear()
        ..add(updatedLobby);
      return;
    }

    _lobbies[index] = updatedLobby;
  }

  String get _currentLobbyId => _lobbies.isEmpty ? '' : _lobbies.first.id;

  void _sendToServer(Map<String, dynamic> payload) {
    _serverConnection?.add(jsonEncode(payload));
  }

  Future<void> _closeClientConnection() async {
    await _serverSubscription?.cancel();
    _serverSubscription = null;
    await _serverConnection?.close();
    _serverConnection = null;
  }

  void recordExternalDebug(String message) {
    _appendDebug(message);
    notifyListeners();
  }

  void _setError(String message) {
    _lastError = message;
  }

  void _clearError() {
    _lastError = null;
  }

  String? _hostAddressWarning(String? host) {
    if (host == null || host.isEmpty) {
      return null;
    }

    if (host == '127.0.0.1' ||
        host == '0.0.0.0' ||
        host == 'localhost' ||
        host.startsWith('10.0.2.') ||
        host.startsWith('10.0.3.')) {
      return 'Этот адрес принадлежит эмулятору или локальному устройству. Другой телефон по нему не подключится.';
    }

    return null;
  }

  void _setNetworkStatus(String value) {
    _networkStatus = value;
  }

  void _appendDebug(String message) {
    final now = DateTime.now();
    final hh = now.hour.toString().padLeft(2, '0');
    final mm = now.minute.toString().padLeft(2, '0');
    final ss = now.second.toString().padLeft(2, '0');
    _networkDebugLog.add('[$hh:$mm:$ss] $message');
    if (_networkDebugLog.length > 18) {
      _networkDebugLog.removeRange(0, _networkDebugLog.length - 18);
    }
  }

  @override
  void dispose() {
    unawaited(disposeNetwork());
    super.dispose();
  }
}

class DiscoveredLobbyHost {
  final String address;
  final int port;
  final LobbySession lobby;

  const DiscoveredLobbyHost({
    required this.address,
    required this.port,
    required this.lobby,
  });
}

class _LanCandidate {
  final InternetAddress address;
  final String interfaceName;
  final int score;

  const _LanCandidate({
    required this.address,
    required this.interfaceName,
    required this.score,
  });
}

class _NormalizedPotState {
  final List<PokerGamePlayerState> players;
  final int currentBet;
  final int pot;

  const _NormalizedPotState({
    required this.players,
    required this.currentBet,
    required this.pot,
  });
}

class _NetworkSidePot {
  final int amount;
  final List<String> eligibleKeys;

  const _NetworkSidePot({
    required this.amount,
    required this.eligibleKeys,
  });
}

class _NetworkHandResolution {
  final List<PokerGamePlayerState> players;
  final List<String> winnerKeys;
  final String winnerLabel;

  const _NetworkHandResolution({
    required this.players,
    required this.winnerKeys,
    required this.winnerLabel,
  });
}
