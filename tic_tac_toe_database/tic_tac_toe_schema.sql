-- tic_tac_toe_schema.sql
-- PostgreSQL schema for Tic Tac Toe application
-- Includes tables: users, games, participation, moves, and game_history

-- USERS TABLE
CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    username TEXT NOT NULL UNIQUE,           -- App-specific username
    email TEXT NOT NULL UNIQUE,              -- For login or notifications
    password_hash TEXT NOT NULL,             -- Store hashed password, never plaintext
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- GAMES TABLE
CREATE TABLE IF NOT EXISTS games (
    id SERIAL PRIMARY KEY,
    creator_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    started_at TIMESTAMPTZ,                         -- When both players join (nullable)
    finished_at TIMESTAMPTZ,                        -- When a result is determined or resign
    status TEXT NOT NULL CHECK (status IN ('waiting', 'in_progress', 'draw', 'X_won', 'O_won', 'cancelled')),
    winner_id INTEGER REFERENCES users(id) ON DELETE SET NULL, -- Nullable, set if draw/no win
    board_state CHAR(9),                            -- Current state, nullable (for quick lookup)
    next_turn INTEGER REFERENCES users(id),         -- Whose turn it is to play
    CONSTRAINT creator_not_winner CHECK (creator_id IS DISTINCT FROM winner_id)
);

-- PARTICIPATION TABLE: Connects users to games and assigns X or O
CREATE TABLE IF NOT EXISTS participation (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    game_id INTEGER NOT NULL REFERENCES games(id) ON DELETE CASCADE,
    symbol CHAR(1) NOT NULL CHECK (symbol IN ('X', 'O')),
    joined_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT one_participation_per_game UNIQUE(user_id, game_id),
    CONSTRAINT only_two_participants CHECK (
        (SELECT COUNT(*) FROM participation WHERE game_id = participation.game_id) <= 2
    )
);

-- MOVES TABLE: Each move in a game
CREATE TABLE IF NOT EXISTS moves (
    id SERIAL PRIMARY KEY,
    game_id INTEGER NOT NULL REFERENCES games(id) ON DELETE CASCADE,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    move_index INTEGER NOT NULL CHECK (move_index BETWEEN 0 AND 8),    -- 0 = top-left, 8 = bottom-right
    symbol CHAR(1) NOT NULL CHECK (symbol IN ('X', 'O')),              -- X or O
    move_number INTEGER NOT NULL,                                      -- 1-based move order
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT one_move_per_cell UNIQUE (game_id, move_index),
    CONSTRAINT move_number_order UNIQUE (game_id, move_number)
);

-- GAME HISTORY: Optionally used for archiving or audit trail
CREATE TABLE IF NOT EXISTS game_history (
    id SERIAL PRIMARY KEY,
    game_id INTEGER NOT NULL REFERENCES games(id) ON DELETE CASCADE,
    event TEXT NOT NULL,                 -- "created", "joined", "move", "resigned", "draw", "finished", etc.
    event_data JSONB,                    -- Details of the event (e.g. move, winner, board, etc.)
    user_id INTEGER REFERENCES users(id) ON DELETE SET NULL, -- user who generated the event
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Indexing to speed up game lookups and queries
CREATE INDEX IF NOT EXISTS idx_games_status ON games(status);
CREATE INDEX IF NOT EXISTS idx_games_creator_id ON games(creator_id);
CREATE INDEX IF NOT EXISTS idx_moves_game_id ON moves(game_id);
CREATE INDEX IF NOT EXISTS idx_moves_user_id ON moves(user_id);
CREATE INDEX IF NOT EXISTS idx_participation_game_id ON participation(game_id);

-- Add some example comments
COMMENT ON TABLE users IS 'Application users (players)';
COMMENT ON TABLE games IS 'Game sessions for Tic Tac Toe (can be open, in progress, finished)';
COMMENT ON TABLE participation IS 'Links users to games, each user as X or O';
COMMENT ON TABLE moves IS 'Every move made in each game';
COMMENT ON TABLE game_history IS 'History and audit trail for game events';

-- End of schema
