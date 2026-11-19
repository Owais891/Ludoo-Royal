import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/storage/app_config.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/services/online_game_service.dart';

final _onlineGameServiceProvider =
    Provider<OnlineGameService>((ref) => OnlineGameService());

/// Room lobby screen — shown after creating or joining a private room.
///
/// * Polls `OnlineGameService.roomStatus(code)` every 2s.
/// * Shows participants (filled seats vs. waiting).
/// * Host sees a "Start Game" button (enabled once 2+ players have joined)
///   which transitions the underlying match to `active` via `resume`.
/// * Non-host players see a "Waiting for host to start" message.
/// * Once the underlying match status becomes `active`, every client is
///   navigated to `/game/play` with the match id.
/// * "Share Code" uses `share_plus` to broadcast the room code via the
///   platform share sheet.
/// * "Leave Room" calls `OnlineGameService.leaveRoom(code)` and routes home.
class RoomLobbyScreen extends ConsumerStatefulWidget {
  final String roomCode;

  const RoomLobbyScreen({super.key, required this.roomCode});

  @override
  ConsumerState<RoomLobbyScreen> createState() => _RoomLobbyScreenState();
}

class _RoomLobbyScreenState extends ConsumerState<RoomLobbyScreen> {
  static const _pollInterval = Duration(seconds: 2);

  Map<String, dynamic>? _room;
  bool _loading = true;
  bool _starting = false;
  bool _leaving = false;
  String? _error;
  Timer? _poller;

  @override
  void initState() {
    super.initState();
    _refresh(initial: true);
    _poller = Timer.periodic(_pollInterval, (_) => _refresh());
  }

  @override
  void dispose() {
    _poller?.cancel();
    super.dispose();
  }

  Future<void> _refresh({bool initial = false}) async {
    if (initial) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final res = ref
          .read(_onlineGameServiceProvider)
          .roomStatus(widget.roomCode);
      final room = await res;
      if (!mounted) return;
      setState(() {
        _room = room;
        _loading = false;
        _error = null;
      });
      _maybeNavigateToActive(room);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = initial;
        _error = _humanError(e);
      });
    }
  }

  void _maybeNavigateToActive(Map<String, dynamic> room) {
    final matchStatus = room['match_status']?.toString() ?? '';
    if (matchStatus == 'active') {
      _poller?.cancel();
      final matchId = room['match_id'];
      final id = matchId is int ? matchId : int.tryParse('$matchId') ?? 0;
      context.go('/game/play', extra: <String, dynamic>{
        'matchId': id,
        'isOnline': true,
      });
    }
  }

  String _humanError(Object e) {
    final msg = e.toString();
    final m = RegExp(r"ApiException\(\d+\):\s*(.*)").firstMatch(msg);
    return m != null ? m.group(1)! : msg;
  }

  bool get _isHost {
    final hostId = _room?['host_id'];
    if (hostId == null) return false;
    final h = hostId is int ? hostId : int.tryParse('$hostId');
    final me = AppConfig.userId;
    return h != null && me != null && h == me;
  }

  int get _maxPlayers {
    final m = _room?['max_players'];
    if (m == null) return 4;
    return m is int ? m : (int.tryParse('$m') ?? 4);
  }

  String get _modeLabel {
    final m = _room?['mode']?.toString() ?? 'classic';
    switch (m) {
      case 'quick':  return 'Quick Ludo';
      case 'private':return 'Private Room';
      default:       return 'Classic Ludo';
    }
  }

  List<Map<String, dynamic>> get _participants {
    final list = _room?['participants'];
    if (list is! List) return const [];
    return list
        .map((e) => (e as Map<String, dynamic>).cast<String, dynamic>())
        .toList();
  }

  int get _joinedCount => _participants.length;

  Future<void> _shareCode() async {
    final code = widget.roomCode;
    await Share.share(
      'Join me in Ludo Royale! Room code: $code',
      subject: 'Ludo Royale Private Room',
    );
  }

  Future<void> _startGame() async {
    if (_starting) return;
    final matchId = _room?['match_id'];
    if (matchId == null) return;
    final id = matchId is int ? matchId : int.tryParse('$matchId') ?? 0;
    setState(() {
      _starting = true;
      _error = null;
    });
    try {
      // Host transitions the underlying match from `waiting` -> `active`.
      await ref.read(_onlineGameServiceProvider).resume(id);
      if (!mounted) return;
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _starting = false;
        _error = _humanError(e);
      });
    }
  }

  Future<void> _leaveRoom() async {
    if (_leaving) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardBackground,
        title: const Text('Leave Room?'),
        content: const Text(
          'You will be removed from this room. You can rejoin later with the '
          'same code if the room is still open.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.danger,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _leaving = true);
    try {
      await ref.read(_onlineGameServiceProvider).leaveRoom(widget.roomCode);
    } catch (_) {
      // Best effort — navigate home even if the API call failed (e.g. room
      // already deleted). The user clearly wants out.
    }
    if (!mounted) return;
    _poller?.cancel();
    context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => context.go('/home'),
          tooltip: 'Back',
        ),
        title: Text('Room: ${widget.roomCode}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: 'Share Code',
            onPressed: _shareCode,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () => _refresh(initial: true),
          ),
        ],
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
          child: _buildBody(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return _buildSkeleton();
    }
    if (_error != null && _room == null) {
      return _StateMessage(
        icon: Icons.cloud_off,
        title: 'Couldn\'t load room',
        message: _error!,
        actionLabel: 'Retry',
        onAction: () => _refresh(initial: true),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
      children: [
        _CodeCard(code: widget.roomCode, modeLabel: _modeLabel),
        const SizedBox(height: 18),
        _SectionLabel(text: 'Participants'),
        const SizedBox(height: 6),
        _HintText(text: '$_joinedCount/$_maxPlayers joined'),
        const SizedBox(height: 12),
        _ParticipantsList(
          maxPlayers: _maxPlayers,
          participants: _participants,
          hostId: _room?['host_id'],
        ),
        const SizedBox(height: 18),
        if (_error != null) ...[
          _ErrorBanner(message: _error!),
          const SizedBox(height: 14),
        ],
        const SizedBox(height: 6),
        if (_isHost)
          _StartGameButton(
            enabled: _joinedCount >= 2 && !_starting,
            starting: _starting,
            joinedCount: _joinedCount,
            maxPlayers: _maxPlayers,
            onPressed: _startGame,
          )
        else
          _WaitingForHost(joinedCount: _joinedCount, maxPlayers: _maxPlayers),
        const SizedBox(height: 14),
        _LeaveRoomButton(loading: _leaving, onPressed: _leaveRoom),
        const SizedBox(height: 14),
        const _FootNote(),
      ],
    );
  }

  Widget _buildSkeleton() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          height: 110,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.06),
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        const SizedBox(height: 18),
        ...List.generate(
          4,
          (_) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Container(
              height: 70,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// =========================================================================
// Code card (hero)
// =========================================================================
class _CodeCard extends StatelessWidget {
  final String code;
  final String modeLabel;
  const _CodeCard({required this.code, required this.modeLabel});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient(),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4A148C).withOpacity(0.40),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.vpn_key_rounded, color: Colors.white70, size: 16),
              const SizedBox(width: 8),
              Text(
                'ROOM CODE',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.85),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.30),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  modeLabel,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Center(
            child: ShaderMask(
              shaderCallback: (bounds) =>
                  AppTheme.goldGradient().createShader(bounds),
              child: Text(
                code,
                style: const TextStyle(
                  fontSize: 42,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 8,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              'Share this code with friends to invite them.',
              style: TextStyle(
                color: Colors.white.withOpacity(0.78),
                fontSize: 12,
              ),
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

class _HintText extends StatelessWidget {
  final String text;
  const _HintText({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: AppTheme.textSecondary.withOpacity(0.85),
        fontSize: 12,
      ),
    );
  }
}

// =========================================================================
// Participants list
// =========================================================================
class _ParticipantsList extends StatelessWidget {
  final int maxPlayers;
  final List<Map<String, dynamic>> participants;
  final dynamic hostId;

  const _ParticipantsList({
    required this.maxPlayers,
    required this.participants,
    required this.hostId,
  });

  @override
  Widget build(BuildContext context) {
    // Pad with empty seats up to maxPlayers.
    final slots = <Map<String, dynamic>?>[];
    for (var i = 0; i < maxPlayers; i++) {
      slots.add(i < participants.length ? participants[i] : null);
    }
    return Column(
      children: slots.asMap().entries.map((entry) {
        final idx = entry.key;
        final p = entry.value;
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _ParticipantTile(
            seatIndex: idx,
            participant: p,
            isHost: p != null && hostId != null && p['user_id'] == hostId,
          ),
        );
      }).toList(),
    );
  }
}

class _ParticipantTile extends StatelessWidget {
  final int seatIndex;
  final Map<String, dynamic>? participant;
  final bool isHost;

  const _ParticipantTile({
    required this.seatIndex,
    required this.participant,
    required this.isHost,
  });

  Color get _seatColor {
    const colors = [
      AppTheme.redPlayer,
      AppTheme.greenPlayer,
      AppTheme.yellowPlayer,
      AppTheme.bluePlayer,
    ];
    if (seatIndex < colors.length) return colors[seatIndex];
    return AppTheme.textSecondary;
  }

  @override
  Widget build(BuildContext context) {
    final isFilled = participant != null;
    final username = participant?['username']?.toString() ?? '';
    final avatarUrl = participant?['avatar_url']?.toString();
    final initial = username.isNotEmpty ? username[0].toUpperCase() : '';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        gradient: AppTheme.cardGradient(),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isFilled
              ? _seatColor.withOpacity(0.45)
              : Colors.white.withOpacity(0.06),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: isFilled ? _seatColor : Colors.white.withOpacity(0.05),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withOpacity(0.18),
                width: 1.5,
              ),
            ),
            child: isFilled
                ? Center(
                    child: (avatarUrl ?? '').isNotEmpty
                        ? ClipOval(
                            child: Image.network(
                              avatarUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Text(
                                initial,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          )
                        : Text(
                            initial,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                  )
                : Icon(
                    Icons.hourglass_top_rounded,
                    color: Colors.white.withOpacity(0.30),
                    size: 20,
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isFilled) ...[
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          username,
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isHost) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.accent.withOpacity(0.22),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: AppTheme.accent.withOpacity(0.6)),
                          ),
                          child: const Text(
                            'HOST',
                            style: TextStyle(
                              color: AppTheme.accent,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Seat ${seatIndex + 1}',
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ] else ...[
                  Text(
                    'Waiting for player...',
                    style: TextStyle(
                      color: AppTheme.textSecondary.withOpacity(0.65),
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Seat ${seatIndex + 1}',
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Icon(
            isFilled ? Icons.check_circle : Icons.circle_outlined,
            color: isFilled ? AppTheme.success : AppTheme.textSecondary,
            size: 20,
          ),
        ],
      ),
    );
  }
}

// =========================================================================
// Start Game button (host only)
// =========================================================================
class _StartGameButton extends StatelessWidget {
  final bool enabled;
  final bool starting;
  final int joinedCount;
  final int maxPlayers;
  final VoidCallback onPressed;

  const _StartGameButton({
    required this.enabled,
    required this.starting,
    required this.joinedCount,
    required this.maxPlayers,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final label = starting
        ? 'Starting...'
        : (joinedCount >= 2
            ? 'Start Game'
            : 'Need 2+ Players');

    return SizedBox(
      height: 56,
      child: Opacity(
        opacity: enabled ? 1.0 : 0.55,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: enabled && !starting ? onPressed : null,
            child: Ink(
              decoration: BoxDecoration(
                gradient: enabled ? AppTheme.goldGradient() : null,
                color: enabled ? null : AppTheme.cardAlt,
                borderRadius: BorderRadius.circular(16),
                boxShadow: enabled
                    ? [
                        BoxShadow(
                          color: const Color(0xFFFFC107).withOpacity(0.30),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ]
                    : null,
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
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.play_arrow_rounded,
                              color: enabled ? Colors.black : AppTheme.textSecondary,
                              size: 22),
                          const SizedBox(width: 8),
                          Text(
                            label,
                            style: TextStyle(
                              color: enabled ? Colors.black : AppTheme.textSecondary,
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
// Waiting-for-host banner (non-host)
// =========================================================================
class _WaitingForHost extends StatelessWidget {
  final int joinedCount;
  final int maxPlayers;
  const _WaitingForHost({required this.joinedCount, required this.maxPlayers});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppTheme.cardGradient(),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppTheme.accent,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Waiting for host to start',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$joinedCount/$maxPlayers players joined. The game will start '
                  'automatically once the host presses Start.',
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 11,
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

// =========================================================================
// Leave Room button
// =========================================================================
class _LeaveRoomButton extends StatelessWidget {
  final bool loading;
  final VoidCallback onPressed;
  const _LeaveRoomButton({required this.loading, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton.icon(
        onPressed: loading ? null : onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppTheme.danger,
          side: BorderSide(color: AppTheme.danger.withOpacity(0.55)),
        ),
        icon: loading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppTheme.danger,
                ),
              )
            : const Icon(Icons.logout_rounded, size: 18),
        label: Text(loading ? 'Leaving...' : 'Leave Room'),
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
              'This page auto-refreshes every 2 seconds. Once the host starts '
              'the game you will be redirected automatically.',
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

// =========================================================================
// State message (error placeholder)
// =========================================================================
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
