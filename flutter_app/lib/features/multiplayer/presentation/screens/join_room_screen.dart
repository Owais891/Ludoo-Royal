import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/services/online_game_service.dart';

final _onlineGameServiceProvider =
    Provider<OnlineGameService>((ref) => OnlineGameService());

/// Join Private Room screen.
///
/// Lets a player enter a 6-character room code (auto-uppercased) and join the
/// room via `OnlineGameService.joinRoom(code)`. On success, navigates to the
/// lobby. Shows inline loading state and error messages.
class JoinRoomScreen extends ConsumerStatefulWidget {
  const JoinRoomScreen({super.key});

  @override
  ConsumerState<JoinRoomScreen> createState() => _JoinRoomScreenState();
}

class _JoinRoomScreenState extends ConsumerState<JoinRoomScreen> {
  static const _kCodeLength = 6;

  late final List<TextEditingController> _controllers;
  late final List<FocusNode> _focusNodes;
  bool _joining = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(
      _kCodeLength,
      (_) => TextEditingController(),
    );
    _focusNodes = List.generate(_kCodeLength, (i) {
      final node = FocusNode();
      node.onKeyEvent = (node, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.backspace &&
            _controllers[i].text.isEmpty &&
            i > 0) {
          // Empty cell + backspace -> jump to previous cell.
          FocusScope.of(context).requestFocus(_focusNodes[i - 1]);
          // Consume the event so the platform doesn't also pop the route.
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      };
      return node;
    });
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  String get _code => _controllers.map((c) => c.text).join().toUpperCase();

  bool get _isComplete => _controllers.every((c) => c.text.isNotEmpty);

  void _onChanged(int index, String value) {
    setState(() => _error = null);

    // Handle paste / multi-char entry: distribute across the cells.
    if (value.length > 1) {
      final chars = value.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
      for (var i = 0; i < chars.length && (index + i) < _kCodeLength; i++) {
        _controllers[index + i].text = chars[i];
      }
      final nextIndex = (index + chars.length).clamp(0, _kCodeLength - 1);
      FocusScope.of(context).requestFocus(_focusNodes[nextIndex]);
      return;
    }

    final normalized = value.toUpperCase();
    if (normalized.isNotEmpty) {
      if (_controllers[index].text != normalized) {
        _controllers[index].text = normalized;
      }
      if (index < _kCodeLength - 1) {
        FocusScope.of(context).requestFocus(_focusNodes[index + 1]);
      } else {
        FocusScope.of(context).unfocus();
      }
    }
  }

  Future<void> _join() async {
    if (_joining) return;
    final code = _code;
    if (code.length != _kCodeLength) {
      setState(() => _error = 'Room code must be $_kCodeLength characters.');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _joining = true;
      _error = null;
    });
    try {
      await ref.read(_onlineGameServiceProvider).joinRoom(code);
      if (!mounted) return;
      context.go('/rooms/lobby?code=$code');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _joining = false;
        _error = _humanError(e);
      });
    }
  }

  String _humanError(Object e) {
    final msg = e.toString();
    final m = RegExp(r"ApiException\(\d+\):\s*(.*)").firstMatch(msg);
    return m != null ? m.group(1)! : msg;
  }

  void _clearAll() {
    for (final c in _controllers) {
      c.clear();
    }
    setState(() => _error = null);
    FocusScope.of(context).requestFocus(_focusNodes[0]);
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
        title: const Text('Join Private Room'),
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
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
            children: [
              const SizedBox(height: 8),
              _HeroCard(),
              const SizedBox(height: 24),
              _SectionLabel(text: 'Enter Room Code'),
              const SizedBox(height: 6),
              const _HintText(),
              const SizedBox(height: 18),
              _CodeGrid(
                controllers: _controllers,
                focusNodes: _focusNodes,
                onChanged: _onChanged,
                disabled: _joining,
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton.icon(
                    onPressed: _joining ? null : _clearAll,
                    icon: const Icon(Icons.clear_rounded, size: 18),
                    label: const Text('Clear'),
                  ),
                ],
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                _ErrorBanner(message: _error!),
              ],
              const SizedBox(height: 24),
              _JoinButton(
                enabled: _isComplete && !_joining,
                joining: _joining,
                onPressed: _join,
              ),
              const SizedBox(height: 18),
              const _FootNote(),
            ],
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
  const _HeroCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient(),
        borderRadius: BorderRadius.circular(20),
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
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.22),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.vpn_key_rounded,
                color: Colors.white, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Have a code?',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Ask your friend for the 6-character room code and type it '
                  'in below to join.',
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

class _HintText extends StatelessWidget {
  const _HintText();

  @override
  Widget build(BuildContext context) {
    return Text(
      'Codes are 6 characters, letters A-Z and digits 0-9.',
      style: TextStyle(
        color: AppTheme.textSecondary.withOpacity(0.85),
        fontSize: 12,
      ),
    );
  }
}

// =========================================================================
// Code grid (6 separate cells)
// =========================================================================
class _CodeGrid extends StatelessWidget {
  final List<TextEditingController> controllers;
  final List<FocusNode> focusNodes;
  final void Function(int index, String value) onChanged;
  final bool disabled;

  const _CodeGrid({
    required this.controllers,
    required this.focusNodes,
    required this.onChanged,
    required this.disabled,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final spacing = 8.0;
        final totalSpacing = spacing * (controllers.length - 1);
        final cellWidth =
            ((constraints.maxWidth - totalSpacing) / controllers.length)
                .clamp(40.0, 64.0);
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(controllers.length, (i) {
            return Container(
              width: cellWidth,
              margin: EdgeInsets.only(
                  right: i == controllers.length - 1 ? 0 : spacing),
              child: _CodeCell(
                controller: controllers[i],
                focusNode: focusNodes[i],
                onChanged: (v) => onChanged(i, v),
                disabled: disabled,
              ),
            );
          }),
        );
      },
    );
  }
}

class _CodeCell extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final bool disabled;

  const _CodeCell({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.disabled,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      enabled: !disabled,
      maxLength: 1,
      textAlign: TextAlign.center,
      textCapitalization: TextCapitalization.characters,
      textInputAction: TextInputAction.next,
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
      ],
      style: const TextStyle(
        color: AppTheme.textPrimary,
        fontSize: 22,
        fontWeight: FontWeight.w800,
        letterSpacing: 0,
      ),
      decoration: InputDecoration(
        counterText: '',
        contentPadding: const EdgeInsets.symmetric(vertical: 16),
        filled: true,
        fillColor: AppTheme.cardAlt,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.10)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppTheme.accent, width: 2),
        ),
      ),
      onChanged: onChanged,
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
// Join button
// =========================================================================
class _JoinButton extends StatelessWidget {
  final bool enabled;
  final bool joining;
  final VoidCallback onPressed;
  const _JoinButton({
    required this.enabled,
    required this.joining,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: Opacity(
        opacity: enabled ? 1.0 : 0.55,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: enabled ? onPressed : null,
            child: Ink(
              decoration: BoxDecoration(
                gradient: AppTheme.goldGradient(),
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
                child: joining
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
                          Icon(Icons.login_rounded,
                              color: Colors.black, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Join Room',
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
              'Codes are case-insensitive. If you don\'t have one, ask the host '
              'to share the room code via the lobby\'s "Share Code" button.',
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
