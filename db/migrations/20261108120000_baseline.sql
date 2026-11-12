-- ============================================
-- Migration: 20261108120000_baseline
-- Description: Initial schema of the HollyList database
--              (people, gifts, updated_at function and triggers).
-- Author: Floris Robart
-- ============================================



-- migrate:up

-- ------------------------------------------
-- Functions
-- ------------------------------------------

-- Function to update the updated_at field
-- This function will be called by a trigger before each update
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;



-- ------------------------------------------
-- Table: peoples
-- ------------------------------------------

-- The people a user gives gifts to
CREATE TABLE peoples (
    id INTEGER PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    first_name VARCHAR(255) NOT NULL,
    last_name VARCHAR(255) DEFAULT NULL,
    date_of_birth DATE,

    user_id INTEGER NOT NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    -- Target of the foreign key of gifts, which checks that a gift and its person belong to the same user
    CONSTRAINT peoples_id_user_id_key UNIQUE (id, user_id)
);

-- Every request of the API only reads the rows of one user
CREATE INDEX peoples_user_id_idx ON peoples (user_id);



-- ------------------------------------------
-- Table: gifts
-- ------------------------------------------

-- The gifts given, or to give, to a person
CREATE TABLE gifts (
    id INTEGER PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    gift_name VARCHAR(255) NOT NULL,
    gift_description TEXT,
    gift_year INTEGER,
    price NUMERIC(12, 2) NOT NULL DEFAULT 0,
    link VARCHAR(2048),

    people_id INTEGER NOT NULL,
    user_id INTEGER NOT NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT check_gifts_price_not_negative CHECK (price >= 0),

    -- A gift can only belong to a person of the same user, whatever the API sends
    CONSTRAINT gifts_people_id_user_id_fkey FOREIGN KEY (people_id, user_id)
        REFERENCES peoples (id, user_id) ON DELETE CASCADE
);

-- Serves both the requests of the API, which read the rows of one user,
-- and the foreign key, which looks for the gifts of a deleted person
CREATE INDEX gifts_user_id_people_id_idx ON gifts (user_id, people_id);



-- ------------------------------------------
-- Triggers: keep updated_at up to date
-- ------------------------------------------

CREATE TRIGGER update_peoples_updated_at
BEFORE UPDATE ON peoples
FOR EACH ROW
EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER update_gifts_updated_at
BEFORE UPDATE ON gifts
FOR EACH ROW
EXECUTE FUNCTION update_updated_at();



-- migrate:down

-- Dropping a table also drops its triggers and its indexes
DROP TABLE IF EXISTS gifts;
DROP TABLE IF EXISTS peoples;

DROP FUNCTION IF EXISTS update_updated_at();
