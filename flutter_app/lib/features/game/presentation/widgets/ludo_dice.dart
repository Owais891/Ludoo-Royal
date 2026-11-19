import 'package:flutter/material.dart';

/// Animated dice widget that displays a value (1..6) with pip dots.
class LudoDice extends StatefulWidget {
  final int value;
  final bool isRolling;
  final Color color;
  final VoidCallback? onTap;
  final double size;

  const LudoDice({
    super.key,
    required this.value,
    this.isRolling = false,
    this.color = const Color(0xFFFFC107),
    this.onTap,
    this.size = 72,
  });

  @override
  State<LudoDice> createState() => _LudoDiceState();
}

class _LudoDiceState extends State<LudoDice>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.isRolling ? null : widget.onTap,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final t = widget.isRolling ? _controller.value : 0.0;
          return Transform.rotate(
            angle: widget.isRolling ? t * 2 : 0,
            child: Transform.scale(
              scale: widget.isRolling ? 0.85 + 0.15 * (0.5 + 0.5 * t) : 1.0,
              child: child,
            ),
          );
        },
        child: Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(widget.size * 0.18),
            border: Border.all(color: widget.color, width: 2.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(160),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
              BoxShadow(
                color: widget.color.withAlpha(80),
                blurRadius: 14,
                spreadRadius: 1,
              ),
            ],
          ),
          child: _pips(widget.isRolling ? ((DateTime.now().millisecond % 6) + 1) : widget.value),
        ),
      ),
    );
  }

  Widget _pips(int v) {
    // Build a 3x3 grid; place dots at standard dice positions.
    final positions = <int>[];
    switch (v) {
      case 1: positions.addAll([4]); break;
      case 2: positions.addAll([0, 8]); break;
      case 3: positions.addAll([0, 4, 8]); break;
      case 4: positions.addAll([0, 2, 6, 8]); break;
      case 5: positions.addAll([0, 2, 4, 6, 8]); break;
      case 6: positions.addAll([0, 2, 3, 5, 6, 8]); break;
      default: positions.addAll([4]);
    }
    return GridView.count(
      crossAxisCount: 3,
      padding: EdgeInsets.all(widget.size * 0.14),
      mainAxisSpacing: 0,
      crossAxisSpacing: 0,
      physics: const NeverScrollableScrollPhysics(),
      children: List.generate(9, (i) {
        final hasDot = positions.contains(i);
        return Center(
          child: Container(
            width: widget.size * 0.16,
            height: widget.size * 0.16,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: hasDot ? const Color(0xFF1A1033) : Colors.transparent,
            ),
          ),
        );
      }),
    );
  }
}
