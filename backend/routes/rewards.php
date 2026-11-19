<?php
return [
    'GET /rewards/daily' => function () {
        $user = AuthMiddleware::requireUser();
        $status = RewardService::status((int)$user['id']);
        $history = RewardService::history((int)$user['id'], 30);
        success(['status' => $status, 'history' => $history]);
    },

    'POST /rewards/claim' => function () {
        $user = AuthMiddleware::requireUser();
        $res = RewardService::claim((int)$user['id']);
        success($res, 'Reward claimed');
    },
];
