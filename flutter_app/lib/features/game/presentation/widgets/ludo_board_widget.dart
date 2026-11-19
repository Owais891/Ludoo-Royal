import 'package:flutter/material.dart';
import '../../domain/entities/player.dart';
import '../../domain/entities/player_color.dart';
import '../../domain/entities/token.dart';
import 'board_geometry.dart';
import 'ludo_board_painter.dart';
import 'ludo_token.dart';

/// Wraps the painted board with interactive token overlays.
class LudoBoardWidget extends StatelessWidget {
  final List<Player> players;
  final PlayerColor? currentPlayer;
  final Set<int> movableTokenIndices; // indices into current player's tokens
  final int? selectedTokenIndex;
  final void Function(int tokenIndex)? onTokenTap;

  const LudoBoardWidget({
    super.key,
    required this.players,
    this.currentPlayer,
    this.movableTokenIndices = const {},
    this.selectedTokenIndex,
    this.onTokenTap,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.of(context).size.shortestSide * 0.92;
        return SizedBox(
          width: size,
          height: size,
          child: Stack(
            children: [
              // The painted board
              CustomPaint(
                size: Size(size, size),
                painter: LudoBoardPainter(
                  highlightColor: currentPlayer,
                ),
              ),
              // Tokens overlay
              ..._buildTokens(size),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _buildTokens(double boardPx) {
    final cell = boardPx / BoardGeometry.gridSize;
    final list = <Widget>[];

    for (final player in players) {
      for (var i = 0; i < player.tokens.length; i++) {
        final token = player.tokens[i];
        final isCurrent = player.color == currentPlayer;
        final movable = isCurrent && movableTokenIndices.contains(i);
        final selected = selectedTokenIndex == i && isCurrent;

        // Compute target cell
        final (cCol, cRow) = BoardGeometry.cellFor(
          color: player.color,
          tokenIndex: i,
          position: token.position,
        );

        // Handle overlapping tokens: if multiple tokens on the same outer
        // cell, stagger them slightly.
        var offsetDx = 0.0, offsetDy = 0.0;
        if (token.position >= 0 && token.position < 52) {
          final sameCellCount = players
              .where((p) => p.tokens.any(
                  (t) => t.position == token.position))
              .fold<int>(0, (acc, p) => acc + p.tokens.where((t) => t.position == token.position).length);
          if (sameCellCount > 1) {
            offsetDx = (i - 1.5) * cell * 0.12;
            offsetDy = (sameCellCount - 1) * cell * 0.04;
          }
        }

        final left = cCol * cell + cell * 0.1 + offsetDx;
        final top  = cRow * cell + cell * 0.1 + offsetDy;
        final tokenSize = cell * 0.8;

        list.add(Positioned(
          left: left,
          top: top,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: LudoToken(
              key: ValueKey('${player.color.name}_$i@${token.position}'),
              color: player.color,
              isMovable: movable,
              isSelected: selected,
              isHome: token.isHome,
              onTap: movable && onTokenTap != null ? () => onTokenTap!(i) : null,
              size: tokenSize,
            ),
          ),
        ));
      }
    }
    return list;
  }
}
