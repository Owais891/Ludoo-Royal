import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/storage/app_config.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/models/match_config.dart';
import '../../domain/entities/player_color.dart';

/// Setup screen for offline matches:
///  * `mode=offlineAI`  -> Play with Computer (1 human + N-1 AI by default)
///  * `mode=local`      -> Local Multiplayer (all humans by default)
///
/// Lets the user pick the seat count (2/3/4), then for each seat configure the
/// username, whether it is a Human or AI, and (when AI) the difficulty.
/// Tapping "Start Game" navigates to `/game/play` with the seat list.
class OfflineMatchSetupScreen extends ConsumerStatefulWidget {
  const OfflineMatchSetupScreen({super.key});

  @override
  ConsumerState<OfflineMatchSetupScreen> createState() =>
      _OfflineMatchSetupScreenState();
}

class _OfflineMatchSetupScreenState
    extends ConsumerState<OfflineMatchSetupScreen> {
  late GameMode _mode;
  int _seatCount = 4;
  late final List<_SeatConfig> _seats;
  bool _starting = false;

  @override
  void initState() {
    super.initState();
    final param =
        GoRouterState.of(context).uri.queryParameters['mode'] ?? 'offlineAI';
    _mode = param == 'local' ? GameMode.local : GameMode.offlineAI;
    _seats = _initialSeats();
  }

  List<_SeatConfig> _initialSeats() {
    final username = AppConfig.username ?? 'You';
    // For "Play with Computer" the host seat is the human user; the other
    // seats default to AI. For "Local Multiplayer" everyone is a human by
    // default so two-three-four friends can pass-and-play.
    return List.generate(4, (i) {
      final color = PlayerColorX.fromSeat(i);
      final isHuman = (_mode == GameMode.local) || i == 0;
      final name = i == 0
          ? username
          : (_mode == GameMode.local
              ? 'Player ${i + 1}'
              : 'AI ${_aiColorLabel(color)}');
      return _SeatConfig(
        username: name,
        isAI: !isHuman,
        aiLevel: !isHuman ? AILevel.medium : null,
        color: color,
      );
    });
  }

  String _aiColorLabel(PlayerColor c) {
    switch (c) {
      case PlayerColor.red:    return 'Red';
      case PlayerColor.green:  return 'Green';
      case PlayerColor.yellow: return 'Yellow';
      case PlayerColor.blue:   return 'Blue';
    }
  }

  String _colorLabel(PlayerColor c) => _aiColorLabel(c);

  String get _modeTitle =>
      _mode == GameMode.local ? 'Local Multiplayer' : 'Play with Computer';

  String get _modeSubtitle => _mode == GameMode.local
      ? 'Pass-and-play on this device. Each seat can be a human or AI.'
      : 'You (red) vs. the computer. Toggle any seat to Human to share the device.';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => context.go('/game/modes'),
          tooltip: 'Back',
        ),
        title: Text(_modeTitle),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF4A148C).withOpacity(0.45),
              const Color(0xFF0A0E27),
            ],
            stops: const [0.0, 0.55],
          ),
        ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
            children: [
              _ModeBanner(title: _modeTitle, subtitle: _modeSubtitle),
              const SizedBox(height: 18),
              _SectionLabel(text: 'Players'),
              const SizedBox(height: 10),
              _SeatCountSelector(
                value: _seatCount,
                onChanged: (v) => setState(() => _seatCount = v),
              ),
              const SizedBox(height: 22),
              _SectionLabel(text: 'Seats'),
              const SizedBox(height: 10),
              ...List.generate(_seatCount, (i) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _SeatCard(
                    seatIndex: i,
                    seat: _seats[i],
                    onUsernameChanged: (v) =>
                        setState(() => _seats[i] = _seats[i].copyWith(username: v)),
                    onIsAIChanged: (v) => setState(() {
                      _seats[i] = _seats[i].copyWith(
                        isAI: v,
                        aiLevel: v ? (_seats[i].aiLevel ?? AILevel.medium) : null,
                        // Reset the default name when toggling to AI in offline-AI mode
                        username: _maybeRenameSeat(i, v),
                      );
                    }),
                    onAILevelChanged: (v) =>
                        setState(() => _seats[i] = _seats[i].copyWith(aiLevel: v)),
                  ),
                );
              }),
              const SizedBox(height: 8),
              _StartGameButton(starting: _starting, onPressed: _start),
            ],
          ),
        ),
      ),
    );
  }

  String _maybeRenameSeat(int i, bool nowAI) {
    if (nowAI) {
      final c = _seats[i].color;
      final base = _seats[i].username;
      // If the seat currently has a generic player name, swap it for "AI Color"
      // (don't clobber the user's edits).
      if (base.startsWith('Player ') || base.isEmpty) {
        return 'AI ${_colorLabel(c)}';
      }
      return base;
    } else {
      final c = _seats[i].color;
      final base = _seats[i].username;
      if (base.startsWith('AI ')) {
        return i == 0 ? (AppConfig.username ?? 'You') : 'Player ${i + 1}';
      }
      return base;
    }
  }

  Future<void> _start() async {
    if (_starting) return;
    setState(() => _starting = true);
    // Brief delay so the user perceives feedback before navigating.
    await Future<void>.delayed(const Duration(milliseconds: 250));
    if (!mounted) return;

    final players = <Map<String, dynamic>>[];
    for (var i = 0; i < _seatCount; i++) {
      final s = _seats[i];
      players.add({
        'username': s.username.trim().isEmpty
            ? (i == 0
                ? (AppConfig.username ?? 'You')
                : 'Player ${i + 1}')
            : s.username.trim(),
        'isAI': s.isAI,
        'aiLevel': s.isAI ? (s.aiLevel ?? AILevel.medium).name : null,
        'color': s.color.name,
        'seat': i,
      });
    }

    if (!mounted) return;
    context.go('/game/play', extra: <String, dynamic>{
      'mode': _mode,
      'maxPlayers': _seatCount,
      'players': players,
      'isOnline': false,
    });
  }
}

// =========================================================================
// Seat config model
// =========================================================================
class _SeatConfig {
  final String username;
  final bool isAI;
  final AILevel? aiLevel;
  final PlayerColor color;

  const _SeatConfig({
    required this.username,
    required this.isAI,
    required this.aiLevel,
    required this.color,
  });

  _SeatConfig copyWith({
    String? username,
    bool? isAI,
    AILevel? aiLevel,
    PlayerColor? color,
  }) =>
      _SeatConfig(
        username: username ?? this.username,
        isAI: isAI ?? this.isAI,
        // Use sentinel-style null handling: if `aiLevel` is explicitly passed
        // we always store it, otherwise keep the previous value.
        aiLevel: aiLevel ?? this.aiLevel,
        color: color ?? this.color,
      );
}

// =========================================================================
// Mode banner
// =========================================================================
class _ModeBanner extends StatelessWidget {
  final String title;
  final String subtitle;
  const _ModeBanner({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: AppTheme.cardGradient(),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient(),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.videogame_asset,
                color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
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
        fontSize: 16,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

// =========================================================================
// Seat count selector
// =========================================================================
class _SeatCountSelector extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;

  const _SeatCountSelector({required this.value, required this.onChanged});

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
                  '$o Players',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: selected ? Colors.black : AppTheme.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
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
// Seat card
// =========================================================================
class _SeatCard extends StatefulWidget {
  final int seatIndex;
  final _SeatConfig seat;
  final ValueChanged<String> onUsernameChanged;
  final ValueChanged<bool> onIsAIChanged;
  final ValueChanged<AILevel> onAILevelChanged;

  const _SeatCard({
    required this.seatIndex,
    required this.seat,
    required this.onUsernameChanged,
    required this.onIsAIChanged,
    required this.onAILevelChanged,
  });

  @override
  State<_SeatCard> createState() => _SeatCardState();
}

class _SeatCardState extends State<_SeatCard> {
  late final TextEditingController _usernameCtrl;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _usernameCtrl = TextEditingController(text: widget.seat.username);
    _focusNode = FocusNode();
  }

  @override
  void didUpdateWidget(covariant _SeatCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Keep the controller in sync when the parent state mutates the
    // username (e.g. toggling AI/Human renames the seat), but never clobber
    // the user's in-progress edit.
    if (!_focusNode.hasFocus &&
        _usernameCtrl.text != widget.seat.username) {
      _usernameCtrl.value = TextEditingValue(
        text: widget.seat.username,
        selection: TextSelection.fromPosition(
          TextPosition(offset: widget.seat.username.length),
        ),
      );
    }
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Color get _playerColor => AppTheme.playerColor(widget.seat.color.name);

  @override
  Widget build(BuildContext context) {
    final seat = widget.seat;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: AppTheme.cardGradient(),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _playerColor.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: _playerColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: _playerColor.withOpacity(0.40),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    '${widget.seatIndex + 1}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _colorNameCapitalized(seat.color),
                      style: TextStyle(
                        color: _playerColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Seat ${widget.seatIndex + 1}',
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              _HumanAIToggle(
                isAI: seat.isAI,
                onChanged: widget.onIsAIChanged,
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _usernameCtrl,
            focusNode: _focusNode,
            onChanged: widget.onUsernameChanged,
            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              hintText: 'Player name',
              prefixIcon: Icon(
                seat.isAI ? Icons.smart_toy_outlined : Icons.person_outline,
                color: AppTheme.textSecondary,
                size: 18,
              ),
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            ),
          ),
          if (seat.isAI) ...[
            const SizedBox(height: 12),
            _AILevelDropdown(
              value: seat.aiLevel ?? AILevel.medium,
              onChanged: widget.onAILevelChanged,
            ),
          ],
        ],
      ),
    );
  }

  String _colorNameCapitalized(PlayerColor c) {
    switch (c) {
      case PlayerColor.red:    return 'Red';
      case PlayerColor.green:  return 'Green';
      case PlayerColor.yellow: return 'Yellow';
      case PlayerColor.blue:   return 'Blue';
    }
  }
}

// =========================================================================
// Human / AI toggle (segmented)
// =========================================================================
class _HumanAIToggle extends StatelessWidget {
  final bool isAI;
  final ValueChanged<bool> onChanged;
  const _HumanAIToggle({required this.isAI, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.30),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _toggleButton(
            label: 'Human',
            selected: !isAI,
            color: AppTheme.success,
            onTap: () => onChanged(false),
          ),
          _toggleButton(
            label: 'AI',
            selected: isAI,
            color: AppTheme.accent,
            onTap: () => onChanged(true),
          ),
        ],
      ),
    );
  }

  Widget _toggleButton({
    required String label,
    required bool selected,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.black : AppTheme.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

// =========================================================================
// AI level dropdown
// =========================================================================
class _AILevelDropdown extends StatelessWidget {
  final AILevel value;
  final ValueChanged<AILevel> onChanged;
  const _AILevelDropdown({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppTheme.cardAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<AILevel>(
          value: value,
          isExpanded: true,
          dropdownColor: AppTheme.cardBackground,
          icon: const Icon(Icons.keyboard_arrow_down_rounded,
              color: AppTheme.textSecondary, size: 20),
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
          items: const [
            DropdownMenuItem(
              value: AILevel.easy,
              child: Row(children: [
                Icon(Icons.sentiment_satisfied, color: Colors.greenAccent, size: 18),
                SizedBox(width: 8),
                Text('Easy'),
              ]),
            ),
            DropdownMenuItem(
              value: AILevel.medium,
              child: Row(children: [
                Icon(Icons.sentiment_neutral, color: AppTheme.accent, size: 18),
                SizedBox(width: 8),
                Text('Medium'),
              ]),
            ),
            DropdownMenuItem(
              value: AILevel.hard,
              child: Row(children: [
                Icon(Icons.whatshot, color: AppTheme.danger, size: 18),
                SizedBox(width: 8),
                Text('Hard'),
              ]),
            ),
          ],
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ),
    );
  }
}

// =========================================================================
// Start game button
// =========================================================================
class _StartGameButton extends StatelessWidget {
  final bool starting;
  final VoidCallback onPressed;
  const _StartGameButton({required this.starting, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: Opacity(
        opacity: starting ? 0.75 : 1.0,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: starting ? null : onPressed,
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
                child: starting
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
                          Icon(Icons.play_arrow_rounded,
                              color: Colors.black, size: 22),
                          SizedBox(width: 8),
                          Text(
                            'Start Game',
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

