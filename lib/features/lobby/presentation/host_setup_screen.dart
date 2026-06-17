import 'package:flutter/material.dart';
import 'package:poker_phone/app/app_theme.dart';
import 'package:poker_phone/core/widgets/player_avatar.dart';
import 'package:poker_phone/features/lobby/domain/lobby_settings.dart';
import 'package:poker_phone/features/lobby/domain/player_identity.dart';
import 'package:poker_phone/features/lobby/presentation/lobby_controller.dart';
import 'package:poker_phone/features/profile/presentation/profile_controller.dart';
import 'package:poker_phone/features/table/presentation/poker_table_preview_screen.dart';

class HostSetupScreen extends StatefulWidget {
  final ProfileController profileController;
  final LobbyController lobbyController;

  const HostSetupScreen({
    super.key,
    required this.profileController,
    required this.lobbyController,
  });

  @override
  State<HostSetupScreen> createState() => _HostSetupScreenState();
}

class _HostSetupScreenState extends State<HostSetupScreen> {
  late final TextEditingController _lobbyNameController;
  int _selectedStack = 1000;
  int _selectedSmallBlind = 10;
  int _selectedBigBlind = 20;
  int _selectedPlayers = 6;

  @override
  void initState() {
    super.initState();
    final profile = widget.profileController.profile;
    _lobbyNameController = TextEditingController(
      text: '${profile.displayName} table',
    );
  }

  @override
  void dispose() {
    _lobbyNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.profileController.profile;
    final hostIdentity = PlayerIdentity.fromProfile(profile);
    final lobbySettings = LobbySettings(
      lobbyName: _lobbyNameController.text.trim(),
      startingChips: _selectedStack,
      smallBlind: _selectedSmallBlind,
      bigBlind: _selectedBigBlind,
      seatsCount: _selectedPlayers,
      host: hostIdentity,
    );

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: const Text('Создать лобби')),
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topCenter,
            radius: 1.25,
            colors: [Color(0xFF234634), Color(0xFF10251D), Color(0xFF07110D)],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isLandscape = constraints.maxWidth > constraints.maxHeight;

              return SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  isLandscape ? 24 : 20,
                  18,
                  isLandscape ? 24 : 20,
                  24,
                ),
                child: isLandscape
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(right: 20),
                              child: _HostSetupPreviewCard(
                                settings: lobbySettings,
                              ),
                            ),
                          ),
                          Expanded(
                            child: _HostSetupControls(
                              lobbyNameController: _lobbyNameController,
                              selectedStack: _selectedStack,
                              selectedSmallBlind: _selectedSmallBlind,
                              selectedBigBlind: _selectedBigBlind,
                              selectedPlayers: _selectedPlayers,
                              onLobbyNameChanged: () {
                                setState(() {});
                              },
                              onStackChanged: (value) {
                                setState(() => _selectedStack = value);
                              },
                              onSmallBlindChanged: (value) {
                                setState(() {
                                  _selectedSmallBlind = value;
                                  if (_selectedBigBlind < value * 2) {
                                    _selectedBigBlind = value * 2;
                                  }
                                });
                              },
                              onBigBlindChanged: (value) {
                                setState(() {
                                  _selectedBigBlind = value < _selectedSmallBlind * 2
                                      ? _selectedSmallBlind * 2
                                      : value;
                                });
                              },
                              onPlayersChanged: (value) {
                                setState(() => _selectedPlayers = value);
                              },
                              onCreateLobby: () async {
                                final lobby = await widget.lobbyController.createLobby(
                                  lobbySettings,
                                );
                                if (!context.mounted) {
                                  return;
                                }
                                Navigator.of(context).pushReplacement(
                                  MaterialPageRoute(
                                    builder: (_) => PokerTablePreviewScreen(
                                      profileController:
                                          widget.profileController,
                                      lobbyController: widget.lobbyController,
                                      lobbyId: lobby.id,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      )
                    : Column(
                        children: [
                          _HostSetupPreviewCard(
                            settings: lobbySettings,
                          ),
                          const SizedBox(height: 18),
                          _HostSetupControls(
                            lobbyNameController: _lobbyNameController,
                            selectedStack: _selectedStack,
                            selectedSmallBlind: _selectedSmallBlind,
                            selectedBigBlind: _selectedBigBlind,
                            selectedPlayers: _selectedPlayers,
                            onLobbyNameChanged: () {
                              setState(() {});
                            },
                            onStackChanged: (value) {
                              setState(() => _selectedStack = value);
                            },
                            onSmallBlindChanged: (value) {
                              setState(() {
                                _selectedSmallBlind = value;
                                if (_selectedBigBlind < value * 2) {
                                  _selectedBigBlind = value * 2;
                                }
                              });
                            },
                            onBigBlindChanged: (value) {
                              setState(() {
                                _selectedBigBlind = value < _selectedSmallBlind * 2
                                    ? _selectedSmallBlind * 2
                                    : value;
                              });
                            },
                            onPlayersChanged: (value) {
                              setState(() => _selectedPlayers = value);
                            },
                            onCreateLobby: () async {
                              final lobby = await widget.lobbyController.createLobby(
                                lobbySettings,
                              );
                              if (!context.mounted) {
                                return;
                              }
                              Navigator.of(context).pushReplacement(
                                MaterialPageRoute(
                                  builder: (_) => PokerTablePreviewScreen(
                                    profileController:
                                        widget.profileController,
                                    lobbyController: widget.lobbyController,
                                    lobbyId: lobby.id,
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _HostSetupPreviewCard extends StatelessWidget {
  final LobbySettings settings;

  const _HostSetupPreviewCard({
    required this.settings,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1B15).withAlpha(235),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withAlpha(10)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(70),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Старт раздачи',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          const Text(
            'Подготовь стол, задай фишки и блайнды. Пока это демо-визуал для выбора сценария хоста.',
            style: TextStyle(color: AppTheme.mutedText, height: 1.45),
          ),
          const SizedBox(height: 22),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(6),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.white.withAlpha(10)),
            ),
            child: Row(
              children: [
                PlayerAvatar(
                  seed: settings.host.avatarSeed,
                  avatarPath: settings.host.avatarPath,
                  avatarType: settings.host.avatarType,
                  size: 54,
                  isSelected: true,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        settings.displayLobbyName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Хост: ${settings.host.displayName}',
                        style: const TextStyle(
                          color: AppTheme.mutedText,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFF102019),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppTheme.primary.withAlpha(30)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _SetupStatChip(
                        label: 'Стек',
                        value: '${settings.startingChips}',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _SetupStatChip(
                        label: 'Места',
                        value: '${settings.seatsCount}',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _SetupStatChip(
                        label: 'SB',
                        value: '${settings.smallBlind}',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _SetupStatChip(
                        label: 'BB',
                        value: '${settings.bigBlind}',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFE9B949), Color(0xFFC79327)],
              ),
              borderRadius: BorderRadius.circular(22),
            ),
            child: const Row(
              children: [
                Icon(Icons.wifi_tethering_rounded, color: Color(0xFF14100A)),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Хост создаст локальное лобби и покажет игрокам код подключения.',
                    style: TextStyle(
                      color: Color(0xFF14100A),
                      fontWeight: FontWeight.w800,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HostSetupControls extends StatelessWidget {
  final TextEditingController lobbyNameController;
  final int selectedStack;
  final int selectedSmallBlind;
  final int selectedBigBlind;
  final int selectedPlayers;
  final VoidCallback onLobbyNameChanged;
  final ValueChanged<int> onStackChanged;
  final ValueChanged<int> onSmallBlindChanged;
  final ValueChanged<int> onBigBlindChanged;
  final ValueChanged<int> onPlayersChanged;
  final VoidCallback onCreateLobby;

  const _HostSetupControls({
    required this.lobbyNameController,
    required this.selectedStack,
    required this.selectedSmallBlind,
    required this.selectedBigBlind,
    required this.selectedPlayers,
    required this.onLobbyNameChanged,
    required this.onStackChanged,
    required this.onSmallBlindChanged,
    required this.onBigBlindChanged,
    required this.onPlayersChanged,
    required this.onCreateLobby,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFF102018).withAlpha(235),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withAlpha(10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Настройки стола',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: lobbyNameController,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: 'Название лобби',
              hintText: 'Например, Домашний стол',
              filled: true,
              fillColor: Colors.white.withAlpha(8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(22),
                borderSide: BorderSide(
                  color: Colors.white.withAlpha(12),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(22),
                borderSide: BorderSide(
                  color: Colors.white.withAlpha(12),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(22),
                borderSide: const BorderSide(
                  color: AppTheme.primary,
                  width: 2,
                ),
              ),
            ),
            onChanged: (_) {
              onLobbyNameChanged();
            },
          ),
          const SizedBox(height: 18),
          _SliderSettingCard(
            title: 'Стартовые фишки',
            valueLabel: '$selectedStack',
            value: selectedStack.toDouble(),
            min: 500,
            max: 10000,
            divisions: 19,
            onChanged: onStackChanged,
            minLabel: '500',
            maxLabel: '10 000',
          ),
          const SizedBox(height: 18),
          _SliderSettingCard(
            title: 'Small blind',
            valueLabel: '$selectedSmallBlind',
            value: selectedSmallBlind.toDouble(),
            min: 5,
            max: 200,
            divisions: 39,
            onChanged: onSmallBlindChanged,
            minLabel: '5',
            maxLabel: '200',
          ),
          const SizedBox(height: 18),
          _SliderSettingCard(
            title: 'Big blind',
            valueLabel: '$selectedBigBlind',
            value: selectedBigBlind.toDouble(),
            min: 10,
            max: 400,
            divisions: 39,
            onChanged: onBigBlindChanged,
            minLabel: '10',
            maxLabel: '400',
          ),
          const SizedBox(height: 18),
          _SliderSettingCard(
            title: 'Количество мест',
            valueLabel: '$selectedPlayers игроков',
            value: selectedPlayers.toDouble(),
            min: 2,
            max: 6,
            divisions: 4,
            onChanged: onPlayersChanged,
            minLabel: '2',
            maxLabel: '6',
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onCreateLobby,
              child: const Text('Создать стол'),
            ),
          ),
        ],
      ),
    );
  }
}

class _SliderSettingCard extends StatelessWidget {
  final String title;
  final String valueLabel;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<int> onChanged;
  final String minLabel;
  final String maxLabel;

  const _SliderSettingCard({
    required this.title,
    required this.valueLabel,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
    required this.minLabel,
    required this.maxLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(6),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: Colors.white.withAlpha(10),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withAlpha(18),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  valueLabel,
                  style: const TextStyle(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: AppTheme.primary,
              inactiveTrackColor: Colors.white.withAlpha(10),
              thumbColor: AppTheme.primary,
              overlayColor: AppTheme.primary.withAlpha(24),
              trackHeight: 5,
            ),
            child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              divisions: divisions,
              onChanged: (newValue) => onChanged(newValue.round()),
            ),
          ),
          Row(
            children: [
              Text(
                minLabel,
                style: const TextStyle(
                  color: AppTheme.mutedText,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                maxLabel,
                style: const TextStyle(
                  color: AppTheme.mutedText,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SetupStatChip extends StatelessWidget {
  final String label;
  final String value;

  const _SetupStatChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(6),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withAlpha(10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.mutedText,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}
