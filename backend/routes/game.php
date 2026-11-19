<?php
return [
    'POST /game/create' => function () {
        $user = AuthMiddleware::requireUser();
        $data = input_json();
        $mode  = $data['mode'] ?? 'classic';
        $max   = (int)($data['max_players'] ?? 4);
        $fee   = (int)($data['entry_fee'] ?? 0);
        if (!in_array($mode, ['classic','quick','private','offline_ai','local'], true)) error('Invalid mode.', 422);
        if ($max < 2 || $max > 4) error('max_players must be 2..4.', 422);
        $match = GameService::createMatch((int)$user['id'], $mode, $max, $fee);
        success($match, 'Match created', 201);
    },

    'POST /game/join' => function () {
        $user = AuthMiddleware::requireUser();
        $data = input_json();
        $matchId = (int)($data['match_id'] ?? 0);
        if ($matchId <= 0) error('match_id required.', 422);
        $match = GameService::joinMatch((int)$user['id'], $matchId);
        success($match, 'Joined match');
    },

    'POST /game/quick' => function () {
        $user = AuthMiddleware::requireUser();
        $data = input_json();
        $mode = $data['mode'] ?? 'classic';
        $max  = (int)($data['max_players'] ?? 4);
        if (!in_array($mode, ['classic','quick','private'], true)) error('Invalid mode.', 422);
        if ($max < 2 || $max > 4) error('max_players must be 2..4.', 422);
        // Try to find an open match first; otherwise create one.
        $openId = GameService::findOpenMatch((int)$user['id'], $mode, $max);
        if ($openId !== null) {
            $match = GameService::joinMatch((int)$user['id'], $openId);
        } else {
            $match = GameService::createMatch((int)$user['id'], $mode, $max, 0);
        }
        success($match, 'Quick match ready');
    },

    'POST /game/roll-dice' => function () {
        $user = AuthMiddleware::requireUser();
        $data = input_json();
        $matchId = (int)($data['match_id'] ?? 0);
        if ($matchId <= 0) error('match_id required.', 422);
        $res = GameService::rollDice($matchId, (int)$user['id']);
        success($res);
    },

    'POST /game/move-token' => function () {
        $user = AuthMiddleware::requireUser();
        $data = input_json();
        $matchId = (int)($data['match_id'] ?? 0);
        $tokenIdx = (int)($data['token_index'] ?? -1);
        if ($matchId <= 0 || $tokenIdx < 0) error('match_id and token_index required.', 422);
        $match = GameService::moveToken($matchId, (int)$user['id'], $tokenIdx);
        success($match);
    },

    'GET /game/state' => function () {
        $user = AuthMiddleware::requireUser();
        $matchId = (int)($_GET['match_id'] ?? 0);
        if ($matchId <= 0) error('match_id required.', 422);
        $match = GameService::loadMatch($matchId);
        success($match);
    },

    'POST /game/pause' => function () {
        $user = AuthMiddleware::requireUser();
        $data = input_json();
        $matchId = (int)($data['match_id'] ?? 0);
        $match = GameService::pauseMatch($matchId, (int)$user['id']);
        success($match);
    },

    'POST /game/resume' => function () {
        $user = AuthMiddleware::requireUser();
        $data = input_json();
        $matchId = (int)($data['match_id'] ?? 0);
        $match = GameService::resumeMatch($matchId, (int)$user['id']);
        success($match);
    },

    'POST /game/finish' => function () {
        $user = AuthMiddleware::requireUser();
        $data = input_json();
        $matchId = (int)($data['match_id'] ?? 0);
        $match = GameService::finish($matchId, (int)$user['id']);
        success($match);
    },
];
