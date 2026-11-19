import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/services/online_game_service.dart';
import '../../data/models/match_config.dart';

final _onlineGameServiceProvider =
    Provider<OnlineGameService>((ref) => OnlineGameService());

/// Quick online matchmaking screen.
///
/// Calls `OnlineGameService.quickMatch(...)` and then routes the player into
/// `/game/play` with the resulting `matchId`. While searching, a pulsing
/// dice + radar animation is shown alongside the elapsed wait time. A Cancel
/// button aborts the search and returns to the previous screen.
class QuickMatchScreen extends ConsumerStatefulWidget {
  final int maxPlayers;

  const QuickMatchScreen({super.key, this.maxPlayers = 4});

  @override
  ConsumerState<QuickMatchScreen> createState() => _QuickMatchScreenState();
}

class _QuickMatchScreenState extends ConsumerState<QuickMatchScreen>
    with TickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final AnimationController _radarController;
  late final Animation<double> _pulse;
  late final Animation<double> _radar;

  bool _searching = true;
  bool _waitingForPlayers = false;
  String? _error;
  int _elapsedSeconds = 0;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat();

    _pulse = CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut);
    _radar = CurvedAnimation(parent: _radarController, curve: Curves.linear);

    _tickTimer();
    _search();
  }

  Future<void> _search() async {
    setState(() {
      _searching = true;
      _waitingForPlayers = false;
      _error = null;
    });
    try {
      final res =
          await ref.read(_onlineGameServiceProvider).quickMatch(
                mode: GameMode.classic,
            maxPlayers: widget.maxPlayers,
              );
      if (!mounted) return;
      final matchId = res['id'] ?? res['match_id'];
      if (matchId == null) {
        throw StateError('Server did not return a match id.');
      }
      final id = matchId is int ? matchId : int.tryParse('$matchId');
      if (id == null || id <= 0) {
        throw StateError('Server returned an invalid match id.');
      }

      setState(() => _waitingForPlayers = true);
      while (mounted && _searching) {
        final match =
            await ref.read(_onlineGameServiceProvider).state(id);
        if (!mounted || !_searching) return;
        final status = match['status']?.toString();
        if (status == 'active') {
          context.go('/game/play', extra: <String, dynamic>{
            'matchId': id,
            'maxPlayers': widget.maxPlayers,
            'isOnline': true,
          });
          return;
        }
        if (status != 'waiting') {
          throw StateError('Match is no longer available ($status).');
        }
        await Future<void>.delayed(const Duration(seconds: 1));
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _searching = false;
        _error = _humanError(e);
      });
    }
  }

  String _humanError(Object e) {
    final msg = e.toString();
    final m = RegExp(r"ApiException\(\d+\):\s*(.*)").firstMatch(msg);
    return m != null ? m.group(1)! : msg;
  }

  void _tickTimer() {
    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted || !_searching) return;
      setState(() => _elapsedSeconds++);
      _tickTimer();
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _radarController.dispose();
    super.dispose();
  }

  void _cancel() {
    if (!_searching) {
      // If search already finished (e.g. an error is shown), just go back.
      context.go('/game/modes');
      return;
    }
    setState(() => _searching = false);
    context.go('/game/modes');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: _cancel,
          tooltip: 'Cancel',
        ),
        title: const Text('Quick Match'),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF1565C0).withOpacity(0.40),
              const Color(0xFF0A0E27),
            ],
            stops: const [0.0, 0.55],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 14),
                Expanded(
                  child: Center(
                    child: _SearchVisualizer(
                      pulse: _pulse,
                      radar: _radar,
                      searching: _searching,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                _StatusLabel(
                  searching: _searching,
                  waitingForPlayers: _waitingForPlayers,
                  error: _error,
                  elapsedSeconds: _elapsedSeconds,
                ),
                const SizedBox(height: 24),
                _CancelButton(label: 'Cancel', onPressed: _cancel),
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
// Search visualizer (pulsing dice + radar rings)
// =========================================================================
class _SearchVisualizer extends StatelessWidget {
  final Animation<double> pulse;
  final Animation<double> radar;
  final bool searching;

  const _SearchVisualizer({
    required this.pulse,
    required this.radar,
    required this.searching,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 260,
      height: 260,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Radar rings expanding outward
          if (searching) ...[
            _RadarRing(radar: radar, delay: 0.0),
            _RadarRing(radar: radar, delay: 0.33),
            _RadarRing(radar: radar, delay: 0.66),
          ],
          // Pulsing dice
          AnimatedBuilder(
            animation: pulse,
            builder: (context, _) {
              final t = pulse.value;
              return Transform.scale(
                scale: 0.85 + t * 0.18,
                child: Opacity(
                  opacity: 0.7 + t * 0.3,
                  child: Container(
                    width: 130,
                    height: 130,
                    decoration: BoxDecoration(
                      gradient: AppTheme.goldGradient(),
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color:
                              const Color(0xFFFFC107).withOpacity(0.50),
                          blurRadius: 28 + t * 18,
                          spreadRadius: 2,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.casino_rounded,
                        color: Colors.black,
                        size: 64,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _RadarRing extends StatelessWidget {
  final Animation<double> radar;
  final double delay;
  const _RadarRing({required this.radar, required this.delay});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: radar,
      builder: (context, _) {
        // Compute the delay-shifted progress, wrapping around 0..1.
        double t = (radar.value - delay) % 1.0;
        if (t < 0) t += 1.0;
        final size = 100.0 + t * 160.0;
        final opacity = (1.0 - t) * 0.55;
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: const Color(0xFFFFC107).withOpacity(opacity.clamp(0.0, 1.0)),
              width: 2,
            ),
          ),
        );
      },
    );
  }
}

// =========================================================================
// Status label (searching / error)
// =========================================================================
class _StatusLabel extends StatelessWidget {
  final bool searching;
  final bool waitingForPlayers;
  final String? error;
  final int elapsedSeconds;

  const _StatusLabel({
    required this.searching,
    required this.waitingForPlayers,
    required this.error,
    required this.elapsedSeconds,
  });

  String get _timeLabel {
    final m = elapsedSeconds ~/ 60;
    final s = elapsedSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (error != null) {
      return Column(
        children: [
          const Icon(Icons.error_outline, color: AppTheme.danger, size: 32),
          const SizedBox(height: 8),
          Text(
            'Search failed',
            style: TextStyle(
              color: AppTheme.danger,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            error!,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppTheme.accent,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              waitingForPlayers
                  ? 'Waiting for players to join...'
                  : 'Searching for opponents...',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Elapsed: $_timeLabel',
          style: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          waitingForPlayers
              ? 'Your match is ready. Dice will unlock when all seats are filled.'
              : 'We are matching you with real players. This usually takes a few seconds.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 11,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

// =========================================================================
// Cancel button
// =========================================================================
class _CancelButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  const _CancelButton({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.close_rounded, size: 18),
        label: Text(label),
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
              'Quick Match defaults to 4-player Classic Ludo. To pick a different '
              'size or play offline, use the Choose Mode screen.',
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
