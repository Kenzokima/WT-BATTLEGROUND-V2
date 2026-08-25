CREATE TABLE IF NOT EXISTS wtbg_matches (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    match_id BIGINT UNSIGNED NOT NULL,
    mode VARCHAR(24) NOT NULL,
    player_count INT UNSIGNED NOT NULL DEFAULT 0,
    team_count INT UNSIGNED NOT NULL DEFAULT 0,
    winner_team_id INT NULL,
    duration_seconds INT UNSIGNED NOT NULL DEFAULT 0,

    started_at DATETIME NOT NULL,
    finished_at DATETIME NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (id),
    UNIQUE KEY uq_wtbg_matches_match_id (match_id),
    KEY idx_wtbg_matches_finished (finished_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS wtbg_match_players (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,

    match_db_id BIGINT UNSIGNED NOT NULL,
    match_id BIGINT UNSIGNED NOT NULL,

    profile_id BIGINT UNSIGNED NOT NULL,
    license VARCHAR(64) NOT NULL,
    name VARCHAR(64) NOT NULL,

    team_id INT NULL,
    placement INT UNSIGNED NOT NULL DEFAULT 0,

    kills INT UNSIGNED NOT NULL DEFAULT 0,
    deaths INT UNSIGNED NOT NULL DEFAULT 0,
    assists INT UNSIGNED NOT NULL DEFAULT 0,
    damage BIGINT UNSIGNED NOT NULL DEFAULT 0,
    headshots INT UNSIGNED NOT NULL DEFAULT 0,
    longest_kill DECIMAL(10,2) NOT NULL DEFAULT 0,

    won TINYINT(1) NOT NULL DEFAULT 0,
    disconnected TINYINT(1) NOT NULL DEFAULT 0,

    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (id),
    UNIQUE KEY uq_match_profile (match_id, profile_id),
    KEY idx_match_db_id (match_db_id),
    KEY idx_profile_id (profile_id),

    CONSTRAINT fk_wtbg_match_players_match
        FOREIGN KEY (match_db_id)
        REFERENCES wtbg_matches(id)
        ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
