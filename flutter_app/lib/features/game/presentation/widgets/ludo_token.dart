import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/player_color.dart';

/// Visual representation of a single Ludo token (a colored pawn).
class LudoToken extends StatelessWidget {
  final PlayerColor color;
  final bool isMovable;
  final bool isSelected;
  final bool isCaptured;
  final bool isHome;
  final VoidCallback? onTap;
  final double size;

  const LudoToken({
    super.key,
    required this.color,
    this.isMovable = false,
    this.isSelected = false,
    this.isCaptured = false,
    this.isHome = false,
    this.onTap,
    this.size = 28,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.playerColor(color.name);
    final darker = Color.lerp(c, Colors.black, 0.35)!;
    final lighter = Color.lerp(c, Colors.white, 0.4)!;

    return GestureDetector(
      onTap: isMovable ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: isMovable
                  ? const Color(0xFFFFC107).withAlpha(180)
                  : Colors.black.withAlpha(120),
              blurRadius: isMovable ? 12 : 4,
              spreadRadius: isMovable ? 2 : 0,
            ),
          ],
          border: isSelected
              ? Border.all(color: const Color(0xFFFFC107), width: 3)
              : null,
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Outer ring (darker shade)
            Container(
              width: size * 0.95,
              height: size * 0.95,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [lighter, c, darker],
                  stops: const [0.0, 0.55, 1.0],
                ),
              ),
            ),
            // Inner highlight
            Positioned(
              top: size * 0.18,
              child: Container(
                width: size * 0.35,
                height: size * 0.35,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withAlpha(120),
                ),
              ),
            ),
            // Home indicator (check mark)
            if (isHome)
              Icon(Icons.star, color: const Color(0xFFFFC107), size: size * 0.6),
            if (isMovable && !isHome)
              Positioned(
                bottom: -2,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    color: Color(0xFFFFC107),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.touch_app,
                      color: Colors.black, size: size * 0.4),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
