<?php
// api.php - aggregated route registration (kept for reference; the actual
// dispatcher is public/index.php which scans all files in routes/).
return array_merge(
    require __DIR__ . '/auth.php',
    require __DIR__ . '/profile.php',
    require __DIR__ . '/game.php',
    require __DIR__ . '/multiplayer.php',
    require __DIR__ . '/leaderboard.php',
    require __DIR__ . '/rewards.php',
    require __DIR__ . '/history.php',
    require __DIR__ . '/wallet.php'
);
