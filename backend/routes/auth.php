<?php
// Auth routes
return [
    'POST /auth/register' => function () {
        $data = input_json();
        $res = AuthService::register($data);
        success($res, 'Registration successful', 201);
    },

    'POST /auth/login' => function () {
        $data = input_json();
        $login = (string)($data['login'] ?? '');
        $pass  = (string)($data['password'] ?? '');
        if ($login === '' || $pass === '') error('login and password are required.', 422);
        $res = AuthService::login($login, $pass);
        success($res, 'Login successful');
    },

    'POST /auth/logout' => function () {
        $user = AuthMiddleware::requireUser();
        AuthService::logout((int)$user['id']);
        success(null, 'Logged out');
    },

    'POST /auth/forgot-password' => function () {
        $data = input_json();
        $email = (string)($data['email'] ?? '');
        if (!validate_email($email)) error('Valid email required.', 422);
        $res = AuthService::forgotPassword($email);
        success($res, 'Reset email sent');
    },

    'POST /auth/reset-password' => function () {
        $data = input_json();
        $token = (string)($data['token'] ?? '');
        $pass  = (string)($data['password'] ?? '');
        if ($token === '' || $pass === '') error('token and password are required.', 422);
        AuthService::resetPassword($token, $pass);
        success(null, 'Password reset successful');
    },
];
