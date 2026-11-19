-- =====================================================================
-- LUDO ROYALE - MySQL Database Schema
-- Database: ludo_royale
-- Engine: InnoDB (for transactions and foreign keys)
-- Charset: utf8mb4 (full Unicode support incl. emoji)
-- =====================================================================

DROP DATABASE IF EXISTS `ludo_royale`;
CREATE DATABASE `ludo_royale`
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;
USE `ludo_royale`;

SET FOREIGN_KEY_CHECKS = 0;

-- =====================================================================
-- 1. users - Authentication accounts
-- =====================================================================
CREATE TABLE `users` (
  `id`              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `full_name`       VARCHAR(100)    NOT NULL,
  `username`        VARCHAR(50)     NOT NULL,
  `email`           VARCHAR(150)    NOT NULL,
  `password_hash`   VARCHAR(255)    NOT NULL,
  `avatar_url`      VARCHAR(255)    DEFAULT NULL,
  `auth_token`      VARCHAR(128)    DEFAULT NULL,
  `token_expires`   DATETIME        DEFAULT NULL,
  `reset_token`     VARCHAR(128)    DEFAULT NULL,
  `reset_expires`   DATETIME        DEFAULT NULL,
  `is_online`       TINYINT(1)      NOT NULL DEFAULT 0,
  `is_banned`       TINYINT(1)      NOT NULL DEFAULT 0,
  `last_login_at`   DATETIME        DEFAULT NULL,
  `last_seen_at`   DATETIME        DEFAULT NULL,
  `created_at`      DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at`      DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uniq_username` (`username`),
  UNIQUE KEY `uniq_email` (`email`),
  UNIQUE KEY `uniq_auth_token` (`auth_token`),
  KEY `idx_reset_token` (`reset_token`),
  KEY `idx_is_online` (`is_online`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =====================================================================
-- 2. user_profiles - Player display / bio info
-- =====================================================================
CREATE TABLE `user_profiles` (
  `user_id`        BIGINT UNSIGNED NOT NULL,
  `avatar_url`     VARCHAR(255)    DEFAULT NULL,
  `country_code`   VARCHAR(5)      DEFAULT NULL,
  `bio`            VARCHAR(255)    DEFAULT NULL,
  `player_level`   INT UNSIGNED    NOT NULL DEFAULT 1,
  `experience`     INT UNSIGNED    NOT NULL DEFAULT 0,
  `updated_at`     DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`user_id`),
  CONSTRAINT `fk_profile_user` FOREIGN KEY (`user_id`)
    REFERENCES `users`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =====================================================================
-- 3. player_stats - Aggregated match stats
-- =====================================================================
CREATE TABLE `player_stats` (
  `user_id`            BIGINT UNSIGNED NOT NULL,
  `total_matches`      INT UNSIGNED    NOT NULL DEFAULT 0,
  `total_wins`         INT UNSIGNED    NOT NULL DEFAULT 0,
  `total_losses`       INT UNSIGNED    NOT NULL DEFAULT 0,
  `total_captures`     INT UNSIGNED    NOT NULL DEFAULT 0,
  `total_captured`     INT UNSIGNED    NOT NULL DEFAULT 0,
  `total_dice_rolls`   INT UNSIGNED    NOT NULL DEFAULT 0,
  `best_win_streak`    INT UNSIGNED    NOT NULL DEFAULT 0,
  `current_win_streak` INT UNSIGNED    NOT NULL DEFAULT 0,
  `updated_at`         DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`user_id`),
  CONSTRAINT `fk_stats_user` FOREIGN KEY (`user_id`)
    REFERENCES `users`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =====================================================================
-- 4. wallets - Player coin / gem balances
-- =====================================================================
CREATE TABLE `wallets` (
  `user_id`      BIGINT UNSIGNED NOT NULL,
  `coins`        BIGINT           NOT NULL DEFAULT 500,
  `gems`         BIGINT           NOT NULL DEFAULT 10,
  `updated_at`   DATETIME         NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`user_id`),
  CONSTRAINT `fk_wallet_user` FOREIGN KEY (`user_id`)
    REFERENCES `users`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =====================================================================
-- 5. wallet_transactions - Append-only ledger
-- =====================================================================
CREATE TABLE `wallet_transactions` (
  `id`            BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `user_id`       BIGINT UNSIGNED NOT NULL,
  `type`          ENUM('credit','debit') NOT NULL,
  `currency`      ENUM('coin','gem')    NOT NULL,
  `amount`        BIGINT           NOT NULL,
  `balance_after` BIGINT           NOT NULL,
  `reason`        VARCHAR(50)     NOT NULL,
  `reference_id`  VARCHAR(80)     DEFAULT NULL,
  `created_at`    DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_wallet_user` (`user_id`),
  KEY `idx_wallet_ref` (`reference_id`),
  CONSTRAINT `fk_tx_user` FOREIGN KEY (`user_id`)
    REFERENCES `users`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =====================================================================
-- 6. matches - Game match metadata
-- =====================================================================
CREATE TABLE `matches` (
  `id`             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `code`           VARCHAR(12)     NOT NULL,
  `mode`           ENUM('classic','quick','private','offline_ai','local') NOT NULL DEFAULT 'classic',
  `max_players`    TINYINT UNSIGNED NOT NULL DEFAULT 4,
  `status`         ENUM('waiting','active','paused','finished','abandoned') NOT NULL DEFAULT 'waiting',
  `winner_id`      BIGINT UNSIGNED DEFAULT NULL,
  `host_id`        BIGINT UNSIGNED NOT NULL,
  `entry_fee`      INT UNSIGNED    NOT NULL DEFAULT 0,
  `prize_pool`     INT UNSIGNED    NOT NULL DEFAULT 0,
  `turn_number`    INT UNSIGNED    NOT NULL DEFAULT 0,
  `current_player` TINYINT UNSIGNED NOT NULL DEFAULT 0,
  `six_counter`    TINYINT UNSIGNED NOT NULL DEFAULT 0,
  `started_at`     DATETIME        DEFAULT NULL,
  `finished_at`    DATETIME        DEFAULT NULL,
  `created_at`     DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at`     DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uniq_match_code` (`code`),
  KEY `idx_match_status` (`status`),
  KEY `idx_match_host` (`host_id`),
  KEY `idx_match_winner` (`winner_id`),
  CONSTRAINT `fk_match_host` FOREIGN KEY (`host_id`)
    REFERENCES `users`(`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_match_winner` FOREIGN KEY (`winner_id`)
    REFERENCES `users`(`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =====================================================================
-- 7. match_players - Players participating in a match
-- =====================================================================
CREATE TABLE `match_players` (
  `id`           BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `match_id`     BIGINT UNSIGNED NOT NULL,
  `user_id`      BIGINT UNSIGNED DEFAULT NULL,
  `player_color` ENUM('red','green','yellow','blue') NOT NULL,
  `seat`         TINYINT UNSIGNED NOT NULL,
  `is_ai`        TINYINT(1)      NOT NULL DEFAULT 0,
  `ai_level`     ENUM('easy','medium','hard') DEFAULT NULL,
  `is_ready`     TINYINT(1)      NOT NULL DEFAULT 0,
  `is_connected` TINYINT(1)      NOT NULL DEFAULT 1,
  `final_rank`   TINYINT UNSIGNED DEFAULT NULL,
  `final_score`  INT             NOT NULL DEFAULT 0,
  `captures`     INT UNSIGNED    NOT NULL DEFAULT 0,
  `joined_at`    DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uniq_match_seat` (`match_id`, `seat`),
  UNIQUE KEY `uniq_match_color` (`match_id`, `player_color`),
  KEY `idx_mp_user` (`user_id`),
  CONSTRAINT `fk_mp_match` FOREIGN KEY (`match_id`)
    REFERENCES `matches`(`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_mp_user` FOREIGN KEY (`user_id`)
    REFERENCES `users`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =====================================================================
-- 8. game_states - Authoritative snapshot of an active match
-- =====================================================================
CREATE TABLE `game_states` (
  `match_id`        BIGINT UNSIGNED NOT NULL,
  `current_player`  TINYINT UNSIGNED NOT NULL DEFAULT 0,
  `dice_value`      TINYINT UNSIGNED DEFAULT NULL,
  `phase`           ENUM('waiting','rolling','moving','finished') NOT NULL DEFAULT 'waiting',
  `turn_number`     INT UNSIGNED    NOT NULL DEFAULT 0,
  `six_counter`     TINYINT UNSIGNED NOT NULL DEFAULT 0,
  `tokens_json`     JSON            NOT NULL,
  `version`         INT UNSIGNED    NOT NULL DEFAULT 1,
  `updated_at`      DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`match_id`),
  CONSTRAINT `fk_state_match` FOREIGN KEY (`match_id`)
    REFERENCES `matches`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =====================================================================
-- 9. game_moves - Move-by-move audit log (server authoritative)
-- =====================================================================
CREATE TABLE `game_moves` (
  `id`           BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `match_id`     BIGINT UNSIGNED NOT NULL,
  `player_seat`  TINYINT UNSIGNED NOT NULL,
  `move_type`    ENUM('roll','move','capture','extra_turn','forfeit','win') NOT NULL,
  `dice_value`   TINYINT UNSIGNED DEFAULT NULL,
  `token_index`  TINYINT UNSIGNED DEFAULT NULL,
  `from_pos`     SMALLINT DEFAULT NULL,
  `to_pos`       SMALLINT DEFAULT NULL,
  `extra_data`   JSON DEFAULT NULL,
  `created_at`   DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_moves_match` (`match_id`),
  CONSTRAINT `fk_moves_match` FOREIGN KEY (`match_id`)
    REFERENCES `matches`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =====================================================================
-- 10. game_history - Summary of finished matches
-- =====================================================================
CREATE TABLE `game_history` (
  `id`            BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `match_id`      BIGINT UNSIGNED NOT NULL,
  `winner_id`     BIGINT UNSIGNED DEFAULT NULL,
  `mode`          VARCHAR(20)     NOT NULL,
  `player_count`  TINYINT UNSIGNED NOT NULL,
  `total_turns`   INT UNSIGNED    NOT NULL DEFAULT 0,
  `total_captures` INT UNSIGNED   NOT NULL DEFAULT 0,
  `duration_sec`  INT UNSIGNED    NOT NULL DEFAULT 0,
  `players_json`  JSON            NOT NULL,
  `created_at`    DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uniq_history_match` (`match_id`),
  KEY `idx_history_winner` (`winner_id`),
  CONSTRAINT `fk_history_match` FOREIGN KEY (`match_id`)
    REFERENCES `matches`(`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_history_winner` FOREIGN KEY (`winner_id`)
    REFERENCES `users`(`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =====================================================================
-- 11. friendships - Friend links (bidirectional via status)
-- =====================================================================
CREATE TABLE `friendships` (
  `id`          BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `user_id`     BIGINT UNSIGNED NOT NULL,
  `friend_id`   BIGINT UNSIGNED NOT NULL,
  `status`      ENUM('pending','accepted','blocked') NOT NULL DEFAULT 'pending',
  `created_at`  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at`  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uniq_friendship_pair` (`user_id`, `friend_id`),
  KEY `idx_friend_status` (`friend_id`, `status`),
  CONSTRAINT `fk_friend_user`   FOREIGN KEY (`user_id`)
    REFERENCES `users`(`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_friend_friend` FOREIGN KEY (`friend_id`)
    REFERENCES `users`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =====================================================================
-- 12. private_rooms - Private play rooms
-- =====================================================================
CREATE TABLE `private_rooms` (
  `id`            BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `room_code`     VARCHAR(12)     NOT NULL,
  `host_id`       BIGINT UNSIGNED NOT NULL,
  `max_players`   TINYINT UNSIGNED NOT NULL DEFAULT 4,
  `mode`          VARCHAR(20)     NOT NULL DEFAULT 'classic',
  `status`        ENUM('open','started','closed') NOT NULL DEFAULT 'open',
  `match_id`      BIGINT UNSIGNED DEFAULT NULL,
  `created_at`    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at`    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uniq_room_code` (`room_code`),
  KEY `idx_room_host` (`host_id`),
  KEY `idx_room_status` (`status`),
  CONSTRAINT `fk_room_host`  FOREIGN KEY (`host_id`)
    REFERENCES `users`(`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_room_match` FOREIGN KEY (`match_id`)
    REFERENCES `matches`(`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =====================================================================
-- 13. daily_rewards - Reward ladder config
-- =====================================================================
CREATE TABLE `daily_rewards` (
  `day`         TINYINT UNSIGNED NOT NULL,
  `reward_type` ENUM('coin','gem') NOT NULL DEFAULT 'coin',
  `amount`      INT UNSIGNED    NOT NULL,
  `is_active`   TINYINT(1)      NOT NULL DEFAULT 1,
  `updated_at`  DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`day`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =====================================================================
-- 14. reward_claims - Per-user reward claim log
-- =====================================================================
CREATE TABLE `reward_claims` (
  `id`           BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `user_id`      BIGINT UNSIGNED NOT NULL,
  `claim_date`   DATE NOT NULL,
  `streak_day`   TINYINT UNSIGNED NOT NULL,
  `reward_type`  ENUM('coin','gem') NOT NULL,
  `amount`       INT UNSIGNED    NOT NULL,
  `created_at`   DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uniq_user_claim_day` (`user_id`, `claim_date`),
  KEY `idx_claim_user` (`user_id`),
  CONSTRAINT `fk_claim_user` FOREIGN KEY (`user_id`)
    REFERENCES `users`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =====================================================================
-- 15. notifications - User notifications
-- =====================================================================
CREATE TABLE `notifications` (
  `id`          BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `user_id`     BIGINT UNSIGNED NOT NULL,
  `type`        VARCHAR(40)     NOT NULL,
  `title`       VARCHAR(150)   NOT NULL,
  `body`        VARCHAR(500)   NOT NULL,
  `is_read`     TINYINT(1)     NOT NULL DEFAULT 0,
  `extra`       JSON DEFAULT NULL,
  `created_at`  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_notif_user_read` (`user_id`, `is_read`),
  CONSTRAINT `fk_notif_user` FOREIGN KEY (`user_id`)
    REFERENCES `users`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

SET FOREIGN_KEY_CHECKS = 1;

-- =====================================================================
-- Initial data: Daily reward ladder (7-day cycle)
-- =====================================================================
INSERT INTO `daily_rewards` (`day`, `reward_type`, `amount`) VALUES
  (1, 'coin', 100),
  (2, 'coin', 200),
  (3, 'gem',  2),
  (4, 'coin', 400),
  (5, 'coin', 600),
  (6, 'gem',  5),
  (7, 'coin', 1000);

-- =====================================================================
-- Optional: Demo / admin user (password = "admin123")
-- Remove in production.
-- =====================================================================
INSERT INTO `users` (`full_name`, `username`, `email`, `password_hash`, `auth_token`, `is_online`)
VALUES ('Ludo Admin', 'admin', 'admin@ludoroyale.local',
        '$2y$10$N9qo8uLOickgx2ZMRZoMy.Mrq9qIc4nWDQpZ7qJqDJK4nH5e6mZ6e',
        'demo-admin-token-1234567890', 0);

SET @uid := LAST_INSERT_ID();
INSERT INTO `user_profiles` (`user_id`, `player_level`, `experience`) VALUES (@uid, 99, 99999);
INSERT INTO `player_stats` (`user_id`, `total_matches`, `total_wins`, `total_losses`)
VALUES (@uid, 50, 35, 15);
INSERT INTO `wallets` (`user_id`, `coins`, `gems`) VALUES (@uid, 99999, 999);

-- =====================================================================
-- END OF SCHEMA
-- =====================================================================
