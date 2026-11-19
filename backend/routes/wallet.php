<?php
return [
    'GET /wallet' => function () {
        $user = AuthMiddleware::requireUser();
        $bal = WalletService::getBalance((int)$user['id']);
        success($bal);
    },

    'GET /wallet/transactions' => function () {
        $user = AuthMiddleware::requireUser();
        $limit = (int)($_GET['limit'] ?? 50);
        $limit = max(5, min($limit, 200));
        $txs = WalletService::transactions((int)$user['id'], $limit);
        success(['transactions' => $txs]);
    },
];
