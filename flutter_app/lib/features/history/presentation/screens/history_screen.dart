import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/match_history_entry.dart';
import '../../../../shared/services/history_service.dart';

final _historyServiceProvider =
    Provider<HistoryService>((ref) => HistoryService());

/// Match History screen — expandable list of past matches.
class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  List<MatchHistoryEntry> _entries = const [];
  bool _loading = true;
  String? _error;
  final Set<int> _expanded = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await ref.read(_historyServiceProvider).load();
      if (!mounted) return;
      setState(() {
        _entries = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Match History')),
      body: RefreshIndicator(
        color: AppTheme.accent,
        onRefresh: _load,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return _buildSkeleton();
    if (_error != null) {
      return _StateMessage(
        icon: Icons.cloud_off,
        title: 'Failed to load history',
        message: _error!,
        actionLabel: 'Retry',
        onAction: _load,
      );
    }
    if (_entries.isEmpty) {
      return _StateMessage(
        icon: Icons.history,
        title: 'No matches yet',
        message:
            'Play your first match to start building your battle record.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      itemCount: _entries.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final entry = _entries[i];
        final expanded = _expanded.contains(entry.matchId);
        return _HistoryCard(
          entry: entry,
          expanded: expanded,
          onToggle: () {
            setState(() {
              if (expanded) {
                _expanded.remove(entry.matchId);
              } else {
                _expanded.add(entry.matchId);
              }
            });
          },
        );
      },
    );
  }

  Widget _buildSkeleton() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 8,
      itemBuilder: (_, __) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Container(
          height: 96,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.06),
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final MatchHistoryEntry entry;
  final bool expanded;
  final VoidCallback onToggle;

  const _HistoryCard({
    required this.entry,
    required this.expanded,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('d MMM yyyy · HH:mm');
    return Container(
      decoration: BoxDecoration(
        gradient: AppTheme.cardGradient(),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onToggle,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.accent.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: AppTheme.accent.withOpacity(0.5)),
                      ),
                      child: Text(
                        entry.code,
                        style: const TextStyle(
                          color: AppTheme.accent,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _ModeChip(mode: entry.modeLabel),
                    const Spacer(),
                    Icon(
                      expanded
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      color: AppTheme.textSecondary,
                      size: 22,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.emoji_events,
                        size: 16, color: AppTheme.accent),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        entry.winnerName != null
                            ? 'Winner: ${entry.winnerName}'
                            : 'No winner (draw / abandoned)',
                        style: TextStyle(
                          color: entry.winnerName != null
                              ? AppTheme.success
                              : AppTheme.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  runSpacing: 6,
                  children: [
                    _Mini(icon: Icons.group, label: '${entry.playerCount} players'),
                    _Mini(
                        icon: Icons.casino, label: '${entry.totalTurns} turns'),
                    _Mini(
                        icon: Icons.gps_fixed,
                        label: '${entry.totalCaptures} captures'),
                    _Mini(icon: Icons.timer, label: entry.durationLabel),
                    _Mini(
                        icon: Icons.calendar_today,
                        label: df.format(entry.createdAt.toLocal())),
                  ],
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeInOut,
                  child: expanded
                      ? Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: _PlayersSection(players: entry.players),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  final String mode;
  const _ModeChip({required this.mode});

  Color get _color {
    switch (mode) {
      case 'Classic':
        return const Color(0xFF42A5F5);
      case 'Quick':
        return const Color(0xFFFFCA28);
      case 'Private':
        return const Color(0xFFAB47BC);
      case 'vs Computer':
        return const Color(0xFF66BB6A);
      case 'Local':
        return const Color(0xFFFF7043);
      default:
        return AppTheme.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _color.withOpacity(0.16),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _color.withOpacity(0.5)),
      ),
      child: Text(
        mode,
        style: TextStyle(
          color: _color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _Mini extends StatelessWidget {
  final IconData icon;
  final String label;
  const _Mini({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: AppTheme.textSecondary),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _PlayersSection extends StatelessWidget {
  final List<dynamic> players;
  const _PlayersSection({required this.players});

  @override
  Widget build(BuildContext context) {
    if (players.isEmpty) {
      return const Text(
        'No player data recorded for this match.',
        style: TextStyle(
          color: AppTheme.textSecondary,
          fontSize: 12,
          fontStyle: FontStyle.italic,
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(color: Colors.white24, height: 1),
        const SizedBox(height: 8),
        const Text(
          'Players',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        ...players.map((raw) {
          final p = raw is Map<String, dynamic> ? raw : <String, dynamic>{};
          return _PlayerRow(player: p);
        }),
      ],
    );
  }
}

class _PlayerRow extends StatelessWidget {
  final Map<String, dynamic> player;
  const _PlayerRow({required this.player});

  Color _color(String? color) {
    switch (color) {
      case 'red':
        return AppTheme.redPlayer;
      case 'green':
        return AppTheme.greenPlayer;
      case 'yellow':
        return AppTheme.yellowPlayer;
      case 'blue':
        return AppTheme.bluePlayer;
      default:
        return AppTheme.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = (player['username'] ?? player['name'] ?? 'Player').toString();
    final colorName = player['color'] as String?;
    final position = player['position'] != null
        ? '${player['position']}'
        : '-';
    final isWinner = player['is_winner'] == true ||
        player['is_winner'] == 1 ||
        player['rank'] == 1;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: _color(colorName),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              name,
              style: TextStyle(
                color:
                    isWinner ? AppTheme.success : AppTheme.textPrimary,
                fontSize: 13,
                fontWeight:
                    isWinner ? FontWeight.w700 : FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (isWinner)
            const Padding(
              padding: EdgeInsets.only(right: 6),
              child: Icon(Icons.emoji_events,
                  size: 14, color: AppTheme.accent),
            ),
          Text(
            '#$position',
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _StateMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _StateMessage({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(32),
      children: [
        const SizedBox(height: 60),
        Icon(icon, size: 56, color: AppTheme.textSecondary),
        const SizedBox(height: 16),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 13,
          ),
        ),
        if (actionLabel != null && onAction != null) ...[
          const SizedBox(height: 18),
          Center(
            child: OutlinedButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.refresh, size: 18),
              label: Text(actionLabel!),
            ),
          ),
        ],
      ],
    );
  }
}
