import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:poker_phone/app/app_theme.dart';
import 'package:poker_phone/core/widgets/player_avatar.dart';
import 'package:poker_phone/features/profile/domain/player_profile.dart';
import 'package:poker_phone/features/profile/presentation/profile_controller.dart';
import 'package:poker_phone/core/widgets/app_toast.dart';

class OnboardingScreen extends StatefulWidget {
  final ProfileController profileController;

  const OnboardingScreen({
    super.key,
    required this.profileController,
  });

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final TextEditingController _nameController = TextEditingController();

  String _selectedAvatarSeed = 'card';
  String _selectedAvatarPath = '';
  PlayerAvatarType _selectedAvatarType = PlayerAvatarType.preset;

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
        message: 'Введи имя хотя бы из 2 символов',
        type: AppToastType.warning,
      );
      return;
    }

    await widget.profileController.saveProfile(
      name: name,
      avatarType: _selectedAvatarType,
      avatarSeed: _selectedAvatarSeed,
      avatarPath: _selectedAvatarPath,
      completeOnboarding: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isSaving = widget.profileController.isSaving;

    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topCenter,
            radius: 1.25,
            colors: [
              Color(0xFF264D3A),
              Color(0xFF10251D),
              Color(0xFF08110E),
            ],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isLandscape = constraints.maxWidth > constraints.maxHeight;

              return SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  isLandscape ? 24 : 22,
                  isLandscape ? 18 : 24,
                  isLandscape ? 24 : 22,
                  28,
                ),
                child: isLandscape
                    ? _OnboardingLandscapeContent(
                        nameController: _nameController,
                        isSaving: isSaving,
                        selectedAvatarSeed: _selectedAvatarSeed,
                        selectedAvatarPath: _selectedAvatarPath,
                        selectedAvatarType: _selectedAvatarType,
                        onAvatarTap: (seed) {
                          setState(() {
                            _selectedAvatarSeed = seed;
                            _selectedAvatarPath = '';
                            _selectedAvatarType = PlayerAvatarType.preset;
                          });
                        },
                        onPickPhoto: _pickPhoto,
                        onSave: _save,
                      )
                    : _OnboardingPortraitContent(
                        nameController: _nameController,
                        isSaving: isSaving,
                        selectedAvatarSeed: _selectedAvatarSeed,
                        selectedAvatarPath: _selectedAvatarPath,
                        selectedAvatarType: _selectedAvatarType,
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
              );
            },
          ),
        ),
      ),
    );
  }
}

class _OnboardingPortraitContent extends StatelessWidget {
  final TextEditingController nameController;
  final bool isSaving;
  final String selectedAvatarSeed;
  final String selectedAvatarPath;
  final PlayerAvatarType selectedAvatarType;
  final ValueChanged<String> onAvatarTap;
  final VoidCallback onPickPhoto;
  final VoidCallback onSave;

  const _OnboardingPortraitContent({
    required this.nameController,
    required this.isSaving,
    required this.selectedAvatarSeed,
    required this.selectedAvatarPath,
    required this.selectedAvatarType,
    required this.onAvatarTap,
    required this.onPickPhoto,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 18),
        const _OnboardingIntro(compact: false),
        const SizedBox(height: 30),
        _OnboardingFormSection(
          nameController: nameController,
          isSaving: isSaving,
          selectedAvatarSeed: selectedAvatarSeed,
          selectedAvatarPath: selectedAvatarPath,
          selectedAvatarType: selectedAvatarType,
          onAvatarTap: onAvatarTap,
          onPickPhoto: onPickPhoto,
          onSave: onSave,
        ),
      ],
    );
  }
}

class _OnboardingLandscapeContent extends StatelessWidget {
  final TextEditingController nameController;
  final bool isSaving;
  final String selectedAvatarSeed;
  final String selectedAvatarPath;
  final PlayerAvatarType selectedAvatarType;
  final ValueChanged<String> onAvatarTap;
  final VoidCallback onPickPhoto;
  final VoidCallback onSave;

  const _OnboardingLandscapeContent({
    required this.nameController,
    required this.isSaving,
    required this.selectedAvatarSeed,
    required this.selectedAvatarPath,
    required this.selectedAvatarType,
    required this.onAvatarTap,
    required this.onPickPhoto,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: 24, top: 12),
            child: _OnboardingIntro(compact: true),
          ),
        ),
        Expanded(
          child: _OnboardingFormSection(
            nameController: nameController,
            isSaving: isSaving,
            selectedAvatarSeed: selectedAvatarSeed,
            selectedAvatarPath: selectedAvatarPath,
            selectedAvatarType: selectedAvatarType,
            onAvatarTap: onAvatarTap,
            onPickPhoto: onPickPhoto,
            onSave: onSave,
          ),
        ),
      ],
    );
  }
}

class _OnboardingIntro extends StatelessWidget {
  final bool compact;

  const _OnboardingIntro({
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Первый вход',
          style: TextStyle(
            color: AppTheme.mutedText,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          compact ? 'Как тебя\nзаписать?' : 'Как тебя\nзаписать за стол?',
          style: TextStyle(
            fontSize: compact ? 32 : 40,
            height: 1.04,
            fontWeight: FontWeight.w900,
            letterSpacing: -1.1,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'Это имя увидят друзья в лобби и за покерным столом. Потом его можно поменять в настройках.',
          style: TextStyle(
            color: AppTheme.mutedText,
            fontSize: compact ? 14 : 15,
            height: 1.45,
          ),
        ),
      ],
    );
  }
}

class _OnboardingFormSection extends StatelessWidget {
  final TextEditingController nameController;
  final bool isSaving;
  final String selectedAvatarSeed;
  final String selectedAvatarPath;
  final PlayerAvatarType selectedAvatarType;
  final ValueChanged<String> onAvatarTap;
  final VoidCallback onPickPhoto;
  final VoidCallback onSave;

  const _OnboardingFormSection({
    required this.nameController,
    required this.isSaving,
    required this.selectedAvatarSeed,
    required this.selectedAvatarPath,
    required this.selectedAvatarType,
    required this.onAvatarTap,
    required this.onPickPhoto,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: nameController,
          keyboardType: TextInputType.name,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.done,
          maxLength: 16,
          onSubmitted: (_) => onSave(),
          decoration: InputDecoration(
            counterText: '',
            hintText: 'Например, Масик!',
            labelText: 'Твоё имя',
            filled: true,
            fillColor: Colors.white.withAlpha(16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(22),
              borderSide: BorderSide(
                color: Colors.white.withAlpha(22),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(22),
              borderSide: BorderSide(
                color: Colors.white.withAlpha(22),
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
        const SizedBox(height: 24),
        const Text(
          'Выбери аватар',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final seed in playerAvatarSeeds)
              GestureDetector(
                onTap: () => onAvatarTap(seed),
                child: PlayerAvatar(
                  seed: seed,
                  avatarPath: '',
                  avatarType: PlayerAvatarType.preset,
                  size: 58,
                  isSelected:
                      selectedAvatarType == PlayerAvatarType.preset &&
                          selectedAvatarSeed == seed,
                ),
              ),
          ],
        ),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: onPickPhoto,
            icon: const Icon(Icons.photo_library_rounded),
            label: const Text('Выбрать фото'),
          ),
        ),
        if (selectedAvatarType == PlayerAvatarType.photo &&
            selectedAvatarPath.isNotEmpty) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(14),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: AppTheme.primary.withAlpha(90),
              ),
            ),
            child: Row(
              children: [
                PlayerAvatar(
                  seed: selectedAvatarSeed,
                  avatarPath: selectedAvatarPath,
                  avatarType: PlayerAvatarType.photo,
                  size: 58,
                  isSelected: true,
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Выбрано пользовательское фото',
                    style: TextStyle(
                      color: AppTheme.mutedText,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 36),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: isSaving ? null : onSave,
            child: Text(
              isSaving ? 'Сохраняем...' : 'Продолжить',
            ),
          ),
        ),
      ],
    );
  }
}
