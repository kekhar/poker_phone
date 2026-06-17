import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:poker_phone/app/app_theme.dart';
import 'package:poker_phone/core/widgets/player_avatar.dart';
import 'package:poker_phone/features/profile/domain/player_profile.dart';
import 'package:poker_phone/features/profile/presentation/profile_controller.dart';
import 'package:poker_phone/core/widgets/app_toast.dart';

class SettingsScreen extends StatefulWidget {
  final ProfileController profileController;

  const SettingsScreen({
    super.key,
    required this.profileController,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _nameController;

  late String _selectedAvatarSeed;
  late String _selectedAvatarPath;
  late PlayerAvatarType _selectedAvatarType;

  @override
  void initState() {
    super.initState();

    final profile = widget.profileController.profile;

    _nameController = TextEditingController(text: profile.displayName);
    _selectedAvatarSeed = profile.avatarSeed;
    _selectedAvatarPath = profile.avatarPath;
    _selectedAvatarType = profile.avatarType;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();

    final file = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1200,
    );

    if (file == null) return;

    setState(() {
      _selectedAvatarPath = file.path;
      _selectedAvatarType = PlayerAvatarType.photo;
    });
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();

    if (name.length < 2) {
      showAppToast(
        context,
        message: 'Имя должно быть хотя бы из 2 символов',
        type: AppToastType.warning,
      );
      return;
    }

    await widget.profileController.saveProfile(
      name: name,
      avatarType: _selectedAvatarType,
      avatarSeed: _selectedAvatarSeed,
      avatarPath: _selectedAvatarPath,
    );

    if (!mounted) return;

    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final isSaving = widget.profileController.isSaving;
    final previewName = _nameController.text.trim().isEmpty
        ? 'Игрок'
        : _nameController.text.trim();

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Настройки'),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isLandscape = constraints.maxWidth > constraints.maxHeight;

            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                isLandscape ? 24 : 20,
                14,
                isLandscape ? 24 : 20,
                24,
              ),
              child: isLandscape
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(right: 24),
                          child: _SettingsHeader(
                              displayName: previewName,
                              avatarSeed: _selectedAvatarSeed,
                              avatarPath: _selectedAvatarPath,
                              avatarType: _selectedAvatarType,
                              compact: true,
                            ),
                          ),
                        ),
                        Expanded(
                          child: _SettingsForm(
                            nameController: _nameController,
                            isSaving: isSaving,
                            selectedAvatarSeed: _selectedAvatarSeed,
                            selectedAvatarType: _selectedAvatarType,
                            compact: true,
                            onAvatarTap: (seed) {
                              setState(() {
                                _selectedAvatarSeed = seed;
                                _selectedAvatarPath = '';
                                _selectedAvatarType = PlayerAvatarType.preset;
                              });
                            },
                            onPickPhoto: _pickPhoto,
                            onSave: _save,
                          ),
                        ),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SettingsHeader(
                          displayName: previewName,
                          avatarSeed: _selectedAvatarSeed,
                          avatarPath: _selectedAvatarPath,
                          avatarType: _selectedAvatarType,
                          compact: false,
                        ),
                        const SizedBox(height: 26),
                        _SettingsForm(
                          nameController: _nameController,
                          isSaving: isSaving,
                          selectedAvatarSeed: _selectedAvatarSeed,
                          selectedAvatarType: _selectedAvatarType,
                          compact: false,
                          onAvatarTap: (seed) {
                            setState(() {
                              _selectedAvatarSeed = seed;
                              _selectedAvatarPath = '';
                              _selectedAvatarType = PlayerAvatarType.preset;
                            });
                          },
                          onPickPhoto: _pickPhoto,
                          onSave: _save,
                        ),
                      ],
                    ),
            );
          },
        ),
      ),
    );
  }
}

class _SettingsHeader extends StatelessWidget {
  final String displayName;
  final String avatarSeed;
  final String avatarPath;
  final PlayerAvatarType avatarType;
  final bool compact;

  const _SettingsHeader({
    required this.displayName,
    required this.avatarSeed,
    required this.avatarPath,
    required this.avatarType,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFF0C1D16).withAlpha(235),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: Colors.white.withAlpha(10),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(70),
              blurRadius: 22,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Профиль игрока',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Имя и аватар видны в лобби и за столом.',
              style: TextStyle(
                color: AppTheme.mutedText,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF091510),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: AppTheme.primary.withAlpha(40),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primary.withAlpha(40),
                          blurRadius: 20,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: PlayerAvatar(
                      seed: avatarSeed,
                      avatarPath: avatarPath,
                      avatarType: avatarType,
                      size: 76,
                      isSelected: true,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withAlpha(20),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Text(
                            'Готов к игре',
                            style: TextStyle(
                              color: AppTheme.primary,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: EdgeInsets.all(compact ? 22 : 24),
      decoration: BoxDecoration(
        color: const Color(0xFF0C1D16).withAlpha(235),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: Colors.white.withAlpha(10),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(70),
            blurRadius: 26,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: compact
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.center,
        children: [
          Align(
            alignment: compact ? Alignment.centerLeft : Alignment.center,
            child: Text(
              'Профиль игрока',
              style: TextStyle(
                fontSize: compact ? 24 : 28,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.6,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Имя и аватар будут показываться в лобби, за столом и в списке игроков.',
            textAlign: compact ? TextAlign.left : TextAlign.center,
            style: const TextStyle(
              color: AppTheme.mutedText,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 28),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFF091510),
              borderRadius: BorderRadius.circular(26),
              border: Border.all(
                color: AppTheme.primary.withAlpha(46),
              ),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primary.withAlpha(52),
                        blurRadius: 26,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: PlayerAvatar(
                    seed: avatarSeed,
                    avatarPath: avatarPath,
                    avatarType: avatarType,
                    size: compact ? 96 : 108,
                    isSelected: true,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withAlpha(22),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    'Готов к игре',
                    style: TextStyle(
                      color: AppTheme.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
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

class _SettingsForm extends StatelessWidget {
  final TextEditingController nameController;
  final bool isSaving;
  final String selectedAvatarSeed;
  final PlayerAvatarType selectedAvatarType;
  final bool compact;
  final ValueChanged<String> onAvatarTap;
  final VoidCallback onPickPhoto;
  final VoidCallback onSave;

  const _SettingsForm({
    required this.nameController,
    required this.isSaving,
    required this.selectedAvatarSeed,
    required this.selectedAvatarType,
    required this.compact,
    required this.onAvatarTap,
    required this.onPickPhoto,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(compact ? 18 : 22),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1813).withAlpha(235),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: Colors.white.withAlpha(10),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(68),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Редактирование',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            compact
                ? 'Имя и аватар, которые будут видны за столом.'
                : 'Обнови имя и выбери аватар, который будет виден за столом.',
            style: const TextStyle(
              color: AppTheme.mutedText,
              height: 1.4,
            ),
          ),
          SizedBox(height: compact ? 18 : 22),
          TextField(
            controller: nameController,
            keyboardType: TextInputType.name,
            textCapitalization: TextCapitalization.words,
            maxLength: 16,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => onSave(),
            decoration: InputDecoration(
              counterText: '',
              labelText: 'Имя игрока',
              hintText: 'Например, Масик!',
              filled: true,
              fillColor: Colors.white.withAlpha(8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(22),
                borderSide: BorderSide(
                  color: Colors.white.withAlpha(18),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(22),
                borderSide: BorderSide(
                  color: Colors.white.withAlpha(18),
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
          ),
          SizedBox(height: compact ? 18 : 24),
          const Text(
            'Аватар',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: compact ? 4 : 6),
          Text(
            compact
                ? 'Выбери пресет или свое фото.'
                : 'Можно выбрать один из пресетов или поставить свое фото.',
            style: const TextStyle(
              color: AppTheme.mutedText,
              fontSize: 13,
              height: 1.35,
            ),
          ),
          SizedBox(height: compact ? 12 : 14),
          Wrap(
            spacing: compact ? 10 : 12,
            runSpacing: compact ? 10 : 12,
            children: [
              for (final seed in playerAvatarSeeds)
                GestureDetector(
                  onTap: () => onAvatarTap(seed),
                  child: PlayerAvatar(
                    seed: seed,
                    avatarPath: '',
                    avatarType: PlayerAvatarType.preset,
                    size: compact ? 52 : 58,
                    isSelected:
                        selectedAvatarType == PlayerAvatarType.preset &&
                            selectedAvatarSeed == seed,
                  ),
                ),
            ],
          ),
          SizedBox(height: compact ? 14 : 18),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onPickPhoto,
              icon: const Icon(Icons.photo_library_rounded),
              label: const Text('Выбрать фото'),
            ),
          ),
          SizedBox(height: compact ? 20 : 30),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: isSaving ? null : onSave,
              child: Text(
                isSaving ? 'Сохраняем...' : 'Сохранить',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
