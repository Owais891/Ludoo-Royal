<?php
return [
    'GET /profile' => function () {
        $user = AuthMiddleware::requireUser();
        $profile = AuthService::loadUser((int)$user['id']);
        success($profile);
    },

    'PUT /profile/update' => function () {
        $user = AuthMiddleware::requireUser();
        $data = input_json();
        $v = (new Validator($data))
            ->max('full_name', 100)
            ->max('avatar_url', 255)
            ->max('country_code', 5)
            ->max('bio', 255);
        if ($v->fails()) error('Validation failed', 422, $v->errors());
        $profile = AuthService::updateProfile((int)$user['id'], $v->validated());
        success($profile);
    },
];
