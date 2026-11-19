import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';

/// Screen shown after a match finishes - shows winner, stats, and CTA buttons.
class MatchResultScreen extends StatelessWidget {
  final Map<String, dynamic> args;
  const MatchResultScreen({super.key, required this.args});

  @override
  Widget build(BuildContext context) {
    final winnerName = (args['winner'] as String?) ?? 'red';
    final color = AppTheme.playerColor(winnerName);
    final stats = (args['stats'] as Map<String, dynamic>?) ?? <String, dynamic>{};

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [color.withAlpha(180), const Color(0xFF0A0E27)],
        ),
        ),
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.emoji_events,
                    color: Color(0xFFFFC107), size: 100),
                const SizedBox(height: 16),
                const Text(
                  'VICTORY!',
                  style: TextStyle(
                    color: Color(0xFFFFC107),
                    fontSize: 42,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 4,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${winnerName.toUpperCase()} player wins',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 32),
                Card(
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  color: AppTheme.cardBackground,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Match Statistics',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _statRow('Total Turns',
                            '${stats['totalTurns'] ?? 0}'),
                        _statRow('Total Captures',
                            '${stats['totalCaptures'] ?? 0}'),
                        _statRow('Dice Rolls',
                            '${stats['totalDiceRolls'] ?? 0}'),
                        _statRow('Duration', _durationLabel(stats)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => context.go('/game/modes'),
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Play Again'),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: () => context.go('/home'),
                      icon: const Icon(Icons.home),
                      label: const Text('Home'),
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

  Widget _statRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  String _durationLabel(Map stats) {
    final started = stats['startedAt'] as String?;
    final finished = stats['finishedAt'] as String?;
    if (started == null || finished == null) return 'N/A';
    final s = DateTime.tryParse(started);
    final f = DateTime.tryParse(finished);
    if (s == null || f == null) return 'N/A';
    final sec = f.difference(s).inSeconds;
    return '${sec ~/ 60}m ${sec % 60}s';
  }
}
