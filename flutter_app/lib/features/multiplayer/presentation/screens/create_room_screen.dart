import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/services/online_game_service.dart';
import '../../../game/data/models/match_config.dart';

final _onlineGameServiceProvider =
    Provider<OnlineGameService>((ref) => OnlineGameService());

/// Create Private Room screen.
///
/// Lets the host pick a mode (Classic/Quick), a max player count (2/3/4) and an
/// optional entry fee. Calls `OnlineGameService.createRoom(...)` and then
/// routes to the lobby.
class CreateRoomScreen extends ConsumerStatefulWidget {
  const CreateRoomScreen({super.key});

  @override
  ConsumerState<CreateRoomScreen> createState() => _CreateRoomScreenState();
}

class _CreateRoomScreenState extends ConsumerState<CreateRoomScreen> {
  final _formKey = GlobalKey<FormState>();
  final _entryFeeCtrl = TextEditingController(text: '0');

  GameMode _mode = GameMode.classic;
  int _maxPlayers = 4;
  bool _creating = false;
  String? _error;

  @override
  void dispose() {
    _entryFeeCtrl.dispose();
    super.dispose();
  }

  String? _validateEntryFee(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final n = int.tryParse(value.trim());
    if (n == null) return 'Enter a valid number';
    if (n < 0) return 'Entry fee cannot be negative';
    if (n > 100000) return 'Too high';
    return null;
  }

  Future<void> _create() async {
    if (_creating) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();

    setState(() {
      _creating = true;
      _error = null;
    });

    try {
      final res = await ref.read(_onlineGameServiceProvider).createRoom(
            mode: _mode,
            maxPlayers: _maxPlayers,
          );
      if (!mounted) return;
      final code = res['room_code']?.toString() ?? '';
      if (code.isEmpty) {
        throw StateError('Server did not return a room code.');
      }
      context.go('/rooms/lobby?code=$code');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _creating = false;
        _error = _humanError(e);
      });
    }
  }

  String _humanError(Object e) {
    final msg = e.toString();
    final m = RegExp(r"ApiException\(\d+\):\s*(.*)").firstMatch(msg);
    return m != null ? m.group(1)! : msg;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => context.go('/game/modes'),
          tooltip: 'Back',
        ),
        title: const Text('Create Private Room'),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF1565C0).withOpacity(0.45),
              const Color(0xFF0A0E27),
            ],
            stops: const [0.0, 0.55],
          ),
        ),
        child: SafeArea(
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
              children: [
                _HeroCard(),
                const SizedBox(height: 18),
                _SectionLabel(text: 'Game Mode'),
                const SizedBox(height: 10),
                _ModeSelector(
                  value: _mode,
                  onChanged: (v) => setState(() => _mode = v),
                ),
                const SizedBox(height: 18),
                _SectionLabel(text: 'Max Players'),
                const SizedBox(height: 10),
                _PlayerCountSelector(
                  value: _maxPlayers,
                  onChanged: (v) => setState(() => _maxPlayers = v),
                ),
                const SizedBox(height: 18),
                _SectionLabel(text: 'Entry Fee (optional)'),
                const SizedBox(height: 10),
                _EntryFeeField(controller: _entryFeeCtrl, validator: _validateEntryFee),
                if (_error != null) ...[
                  const SizedBox(height: 14),
                  _ErrorBanner(message: _error!),
                ],
                const SizedBox(height: 24),
                _CreateButton(creating: _creating, onPressed: _create),
                const SizedBox(height: 14),
                const _FootNote(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// =========================================================================
// Hero card
// =========================================================================
class _HeroCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient(),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1565C0).withOpacity(0.35),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.20),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.group_add_rounded,
                color: Colors.white, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Private Room',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'You\'ll get a 6-character code to share with friends. They join '
                  'from the Join Private Room screen.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    height: 1.35,
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

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: AppTheme.textPrimary,
        fontSize: 15,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

// =========================================================================
// Mode selector (Classic / Quick)
// =========================================================================
class _ModeSelector extends StatelessWidget {
  final GameMode value;
  final ValueChanged<GameMode> onChanged;
  const _ModeSelector({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final options = <_ModeOption>[
      _ModeOption(
        mode: GameMode.classic,
        title: 'Classic Ludo',
        subtitle: 'Full-length match',
        icon: Icons.public_rounded,
        gradient: const [Color(0xFF6A1B9A), Color(0xFFAB47BC)],
      ),
      _ModeOption(
        mode: GameMode.quick,
        title: 'Quick Ludo',
        subtitle: 'Fast & punchy',
        icon: Icons.bolt_rounded,
        gradient: const [Color(0xFFEF6C00), Color(0xFFFFB74D)],
      ),
    ];

    return Row(
      children: [
        Expanded(
          child: _ModeTile(
            option: options[0],
            selected: options[0].mode == value,
            onTap: () => onChanged(options[0].mode),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ModeTile(
            option: options[1],
            selected: options[1].mode == value,
            onTap: () => onChanged(options[1].mode),
          ),
        ),
      ],
    );
  }
}

class _ModeOption {
  final GameMode mode;
  final String title;
  final String subtitle;
  final IconData icon;
  final List<Color> gradient;

  const _ModeOption({
    required this.mode,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.gradient,
  });
}

class _ModeTile extends StatelessWidget {
  final _ModeOption option;
  final bool selected;
  final VoidCallback onTap;
  const _ModeTile({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: selected
                  ? option.gradient
                  : [AppTheme.cardBackground, AppTheme.cardAlt],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected
                  ? Colors.transparent
                  : Colors.white.withOpacity(0.06),
              width: 1,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: option.gradient.last.withOpacity(0.35),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Icon(
                      option.icon,
                      color: selected ? Colors.white : AppTheme.textSecondary,
                      size: 18,
                    ),
                    if (selected)
                      const Icon(Icons.check_circle,
                          color: Colors.white, size: 16),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  option.title,
                  style: TextStyle(
                    color: selected ? Colors.white : AppTheme.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  option.subtitle,
                  style: TextStyle(
                    color: selected
                        ? Colors.white.withOpacity(0.85)
                        : AppTheme.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// =========================================================================
// Player count selector
// =========================================================================
class _PlayerCountSelector extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;
  const _PlayerCountSelector({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    const options = [2, 3, 4];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.cardAlt.withOpacity(0.55),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Row(
        children: options.map((o) {
          final selected = o == value;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(o),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  gradient: selected ? AppTheme.goldGradient() : null,
                  color: selected ? null : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$o',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: selected ? Colors.black : AppTheme.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          );
        }).toList(growable: false),
      ),
    );
  }
}

// =========================================================================
// Entry fee field
// =========================================================================
class _EntryFeeField extends StatelessWidget {
  final TextEditingController controller;
  final String? Function(String?) validator;
  const _EntryFeeField({required this.controller, required this.validator});

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: TextInputType.number,
      style: const TextStyle(color: AppTheme.textPrimary, fontSize: 15),
      decoration: const InputDecoration(
        hintText: '0',
        prefixIcon: Icon(Icons.monetization_on_outlined,
            color: AppTheme.accent, size: 20),
        suffixText: 'coins',
        suffixStyle: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
      ),
    );
  }
}

// =========================================================================
// Error banner
// =========================================================================
class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.danger.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.danger.withOpacity(0.45)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppTheme.danger, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppTheme.danger,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =========================================================================
// Create button
// =========================================================================
class _CreateButton extends StatelessWidget {
  final bool creating;
  final VoidCallback onPressed;
  const _CreateButton({required this.creating, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: Opacity(
        opacity: creating ? 0.75 : 1.0,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: creating ? null : onPressed,
            child: Ink(
              decoration: BoxDecoration(
                gradient: AppTheme.goldGradient(),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFFC107).withOpacity(0.30),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Container(
                alignment: Alignment.center,
                child: creating
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.black,
                        ),
                      )
                    : const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add_circle_outline_rounded,
                              color: Colors.black, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Create Room',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// =========================================================================
// Footnote
// =========================================================================
class _FootNote extends StatelessWidget {
  const _FootNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: AppTheme.textSecondary, size: 16),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Entry fee is deducted from each player\'s wallet when they join '
              'and added to the prize pool. Set to 0 for a friendly match.',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 11,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
