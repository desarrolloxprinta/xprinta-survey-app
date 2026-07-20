ALTER TABLE projects ADD COLUMN IF NOT EXISTS client_rating INTEGER CHECK (client_rating >= 1 AND client_rating <= 5);
ALTER TABLE projects ADD COLUMN IF NOT EXISTS client_rating_comment TEXT;
