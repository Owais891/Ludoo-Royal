<?php
return [
    'POST /multiplayer/create-room' => function () {
        $user = AuthMiddleware::requireUser();
        $data = input_json();
        $mode = $data['mode'] ?? 'classic';
        $max  = (int)($data['max_players'] ?? 4);
        $room = MultiplayerService::createRoom((int)$user['id'], $mode, $max);
        success($room, 'Room created', 201);
    },

    'POST /multiplayer/join-room' => function () {
        $user = AuthMiddleware::requireUser();
        $data = input_json();
        $code = strtoupper((string)($data['room_code'] ?? ''));
        if (strlen($code) < 4) error('Valid room_code required.', 422);
        $room = MultiplayerService::joinRoom((int)$user['id'], $code);
        success($room);
    },

    'GET /multiplayer/room-status' => function () {
        $user = AuthMiddleware::requireUser();
        $code = strtoupper((string)($_GET['room_code'] ?? ''));
        if (strlen($code) < 4) error('Valid room_code required.', 422);
        $room = MultiplayerService::roomStatus($code);
        success($room);
    },

    'POST /multiplayer/leave-room' => function () {
        $user = AuthMiddleware::requireUser();
        $data = input_json();
        $code = strtoupper((string)($data['room_code'] ?? ''));
        $res = MultiplayerService::leaveRoom((int)$user['id'], $code);
        success($res);
    },
];
