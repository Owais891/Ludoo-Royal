import 'dart:math' show cos, pi, sin;

import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/player_color.dart';
import 'board_geometry.dart';

/// Custom painter that draws the Ludo Royale board: 4 player base yards,
/// the cross-shaped track with safe (star) cells, and the colored home paths
/// converging on a center triangle.
class LudoBoardPainter extends CustomPainter {
  final PlayerColor? highlightColor; // current player highlight
  final Set<int> highlightCells;    // cells to mark as legal destinations
  final Set<int> captureRiskCells;

  LudoBoardPainter({
    this.highlightColor,
    this.highlightCells = const {},
    this.captureRiskCells = const {},
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / BoardGeometry.gridSize;
    final paint = Paint();

    // Background of the board
    paint.color = const Color(0xFF261845);
    canvas.drawRect(Offset.zero & size, paint);

    // Draw the 4 player base yards
    _drawBaseYard(canvas, cell, PlayerColor.red,    AppTheme.playerColor('red'),    0, 0);
    _drawBaseYard(canvas, cell, PlayerColor.green,  AppTheme.playerColor('green'),  9, 0);
    _drawBaseYard(canvas, cell, PlayerColor.yellow, AppTheme.playerColor('yellow'), 9, 9);
    _drawBaseYard(canvas, cell, PlayerColor.blue,   AppTheme.playerColor('blue'),   0, 9);

    // Draw the outer track cells
    for (var i = 0; i < 52; i++) {
      final (col, row) = BoardGeometry.outerCells[i];
      _drawTrackCell(canvas, cell, col, row, i);
    }

    // Draw the 4 colored home paths
    for (final color in PlayerColor.values) {
      final path = BoardGeometry.homePaths[color]!;
      final colorVal = AppTheme.playerColor(color.name);
      for (var i = 0; i < path.length; i++) {
        final (col, row) = path[i];
        final isFinal = i == path.length - 1;
        final p = Paint()..color = isFinal ? colorVal : colorVal.withAlpha(180);
        final rect = Rect.fromLTWH(col * cell, row * cell, cell, cell);
        canvas.drawRect(rect, p..style = PaintingStyle.fill);
        _cellBorder(canvas, rect, const Color(0xFF0A0E27));
      }
    }

    // Draw the center finishing triangle
    _drawCenter(canvas, cell);

    // Highlight legal moves
    for (final pos in highlightCells) {
      if (pos < 0) continue;
      (int, int) coord;
      if (pos < 52) {
        coord = BoardGeometry.outerCells[pos];
      } else {
        // Determine color from highlight (it's the current player's color)
        if (highlightColor == null) continue;
        final hp = BoardGeometry.homePaths[highlightColor!]!;
        if (pos - 52 >= hp.length) continue;
        coord = hp[pos - 52];
      }
      final (col, row) = coord;
      final rect = Rect.fromLTWH(col * cell, row * cell, cell, cell);
      final p = Paint()
        ..color = const Color(0xFFFFC107).withAlpha(140)
        ..style = PaintingStyle.fill;
      canvas.drawRect(rect, p);
      _cellBorder(canvas, rect, const Color(0xFFFFC107));
    }
  }

  void _drawBaseYard(Canvas canvas, double cell, PlayerColor color,
      Color baseColor, int originCol, int originRow) {
    // Outer yard
    final rect = Rect.fromLTWH(
      originCol * cell,
      originRow * cell,
      6 * cell,
      6 * cell,
    );
    canvas.drawRect(
      rect,
      Paint()..color = baseColor.withAlpha(220),
    );
    canvas.drawRect(
      rect,
      Paint()
        ..color = Colors.white.withAlpha(60)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // Inner white rounded area containing the 4 token slots
    final inner = Rect.fromLTWH(
      (originCol + 1) * cell,
      (originRow + 1) * cell,
      4 * cell,
      4 * cell,
    );
    final rrect = RRect.fromRectAndRadius(inner, const Radius.circular(12));
    canvas.drawRRect(rrect, Paint()..color = Colors.white.withAlpha(230));

    // Draw 4 inner circles where tokens sit
    final slots = BoardGeometry.baseSlots[color]!;
    for (final (sCol, sRow) in slots) {
      final center = Offset(sCol * cell + cell / 2, sRow * cell + cell / 2);
      canvas.drawCircle(
        center,
        cell * 0.45,
        Paint()..color = baseColor.withAlpha(70),
      );
      canvas.drawCircle(
        center,
        cell * 0.45,
        Paint()
          ..color = baseColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
  }

  void _drawTrackCell(Canvas canvas, double cell, int col, int row, int pos) {
    final rect = Rect.fromLTWH(col * cell, row * cell, cell, cell);

    // Color the start cells
    Color fill = const Color(0xFFFFFFFF).withAlpha(230);
    if (pos == 0)  fill = AppTheme.playerColor('red').withAlpha(220);
    if (pos == 13) fill = AppTheme.playerColor('green').withAlpha(220);
    if (pos == 26) fill = AppTheme.playerColor('yellow').withAlpha(220);
    if (pos == 39) fill = AppTheme.playerColor('blue').withAlpha(220);

    canvas.drawRect(rect, Paint()..color = fill);

    // Safe star cells
    if (BoardGeometry.safeCells.contains(pos) &&
        !const [0, 13, 26, 39].contains(pos)) {
      _drawStar(canvas, rect, const Color(0xFF1B2154));
    }

    _cellBorder(canvas, rect, const Color(0xFF0A0E27));
  }

  void _drawStar(Canvas canvas, Rect rect, Color color) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final center = rect.center;
    final r = rect.width * 0.32;
    final path = Path();
    for (var i = 0; i < 5; i++) {
      final angle = -pi / 2 + i * 4 * pi / 5;
      final x = center.dx + r * cos(angle);
      final y = center.dy + r * sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  void _drawCenter(Canvas canvas, double cell) {
    final cx = 7.5 * cell;
    final cy = 7.5 * cell;
    final half = cell * 1.5;

    // 4 triangles meeting at the center
    final colors = [
      (AppTheme.playerColor('red'),    const [Offset(-1, -1), Offset(0, 0), Offset(-1, 1)]),
      (AppTheme.playerColor('green'),  const [Offset(-1, -1), Offset(0, 0), Offset(1, -1)]),
      (AppTheme.playerColor('yellow'), const [Offset(1, -1),  Offset(0, 0), Offset(1, 1)]),
      (AppTheme.playerColor('blue'),   const [Offset(-1, 1),  Offset(0, 0), Offset(1, 1)]),
    ];

    for (final (color, dirs) in colors) {
      final path = Path();
      path.moveTo(cx + dirs[0].dx * half, cy + dirs[0].dy * half);
      path.lineTo(cx + dirs[1].dx * half, cy + dirs[1].dy * half);
      path.lineTo(cx + dirs[2].dx * half, cy + dirs[2].dy * half);
      path.close();
      canvas.drawPath(path, Paint()..color = color);
    }

    // Outline
    final r = Rect.fromLTWH(6 * cell, 6 * cell, 3 * cell, 3 * cell);
    canvas.drawRect(
      r,
      Paint()
        ..color = Colors.white.withAlpha(120)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  void _cellBorder(Canvas canvas, Rect rect, Color color) {
    canvas.drawRect(
      rect,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.6,
    );
  }

  @override
  bool shouldRepaint(covariant LudoBoardPainter old) {
    return old.highlightColor != highlightColor ||
        old.highlightCells.length != highlightCells.length ||
        old.captureRiskCells.length != captureRiskCells.length;
  }
}
