import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../data/models/match_config.dart';

/// Lets the player pick a player count, then choose between Classic / Quick /
/// Private Room / Offline Ludo. Each card routes to its corresponding setup
/// screen with the selected player count propagated as needed.
class GameModeSelectionScreen extends StatefulWidget {
  const GameModeSelectionScreen({super.key});

  @override
  State<GameModeSelectionScreen> createState() =>
      _GameModeSelectionScreenState();
}

class _GameModeSelectionScreenState extends State<GameModeSelectionScreen> {
  int _playerCount = 4;

  static const _playerOptions = <int>[2, 3, 4];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => context.go('/home'),
          tooltip: 'Back',
        ),
        title: const Text('Choose Mode'),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF4A148C).withOpacity(0.55),
              const Color(0xFF0A0E27),
            ],
            stops: const [0.0, 0.45],
          ),
        ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            children: [
              _SectionLabel(text: 'Players'),
              const SizedBox(height: 10),
              _PlayerCountSelector(
                value: _playerCount,
                options: _playerOptions,
                onChanged: (v) => setState(() => _playerCount = v),
              ),
              const SizedBox(height: 22),
              _SectionLabel(text: 'Game Modes'),
              const SizedBox(height: 12),
              _ModeGrid(
                playerCount: _playerCount,
                onClassic: _startOnlineClassic,
                onQuick: _startQuickMatch,
                onPrivateRoom: _openPrivateRoom,
                onOffline: _openOfflineSetup,
              ),
              const SizedBox(height: 18),
              const _FootNote(),
            ],
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------------
  // Navigation handlers
  // ------------------------------------------------------------------

  void _startOnlineClassic() {
    context.go('/game/quick-match', extra: <String, dynamic>{
      'maxPlayers': _playerCount,
    });
  }

  void _startQuickMatch() {
    context.go('/game/quick-match', extra: <String, dynamic>{
      'maxPlayers': _playerCount,
    });
  }

  void _openPrivateRoom() {
    context.go('/rooms/create');
  }

  void _openOfflineSetup() {
    context.go('/game/offline-setup');
  }
}

// =========================================================================
// Section label
// =========================================================================
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
        letterSpacing: 0.3,
      ),
    );
  }
}

// =========================================================================
// Player count segmented selector
// =========================================================================
class _PlayerCountSelector extends StatelessWidget {
  final int value;
  final List<int> options;
  final ValueChanged<int> onChanged;

  const _PlayerCountSelector({
    required this.value,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
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
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.people_alt_outlined,
                      size: 16,
                      color: selected ? Colors.black : AppTheme.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '$o Players',
                      style: TextStyle(
                        color:
                            selected ? Colors.black : AppTheme.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
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
// Mode grid
// =========================================================================
class _ModeGrid extends StatelessWidget {
  final int playerCount;
  final VoidCallback onClassic;
  final VoidCallback onQuick;
  final VoidCallback onPrivateRoom;
  final VoidCallback onOffline;

  const _ModeGrid({
    required this.playerCount,
    required this.onClassic,
    required this.onQuick,
    required this.onPrivateRoom,
    required this.onOffline,
  });

  @override
  Widget build(BuildContext context) {
    final cards = <_ModeCardData>[
      _ModeCardData(
        title: 'Classic Ludo',
        description: 'Play online with real opponents across the world.',
        icon: Icons.public_rounded,
        gradient: const [Color(0xFF6A1B9A), Color(0xFFAB47BC)],
        actionLabel: 'Play Online',
        onTap: onClassic,
      ),
      _ModeCardData(
        title: 'Quick Ludo',
        description: 'Auto-matchmaking into the next available seat.',
        icon: Icons.bolt_rounded,
        gradient: const [Color(0xFFEF6C00), Color(0xFFFFB74D)],
        actionLabel: 'Play Now',
        onTap: onQuick,
      ),
      _ModeCardData(
        title: 'Private Room',
        description: 'Create a room and invite friends with a code.',
        icon: Icons.group_add_rounded,
        gradient: const [Color(0xFF1565C0), Color(0xFF42A5F5)],
        actionLabel: 'Create Room',
        onTap: onPrivateRoom,
      ),
      _ModeCardData(
        title: 'Offline Ludo',
        description: 'Play vs. AI or pass-and-play with friends.',
        icon: Icons.smart_toy_outlined,
        gradient: const [Color(0xFF2E7D32), Color(0xFF66BB6A)],
        actionLabel: 'Setup',
        onTap: onOffline,
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: cards.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.92,
      ),
      itemBuilder: (context, i) => _ModeCard(data: cards[i]),
    );
  }
}

class _ModeCardData {
  final String title;
  final String description;
  final IconData icon;
  final List<Color> gradient;
  final String actionLabel;
  final VoidCallback onTap;

  const _ModeCardData({
    required this.title,
    required this.description,
    required this.icon,
    required this.gradient,
    required this.actionLabel,
    required this.onTap,
  });
}

class _ModeCard extends StatelessWidget {
  final _ModeCardData data;
  const _ModeCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: data.onTap,
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: data.gradient,
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: data.gradient.last.withOpacity(0.30),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Container(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(data.icon, color: Colors.white, size: 22),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      data.description,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.86),
                        fontSize: 11,
                        height: 1.25,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.28),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              data.actionLabel,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
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
              'Player count applies to Classic and Private Room matches. Quick '
              'match defaults to 4 players. Offline mode lets you configure each '
              'seat on the next screen.',
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
