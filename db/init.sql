-- Create schema + sample data
CREATE TABLE IF NOT EXISTS users (
  id SERIAL PRIMARY KEY,
  name TEXT NOT NULL,
  email TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS orders (
  id SERIAL PRIMARY KEY,
  user_id INTEGER REFERENCES users(id),
  product TEXT NOT NULL,
  total NUMERIC(10,2) NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now()
);

INSERT INTO users (name, email) VALUES
  ('Ada Lovelace', 'ada@example.com'),
  ('Alan Turing',  'alan@example.com')
ON CONFLICT DO NOTHING;

INSERT INTO orders (user_id, product, total) VALUES
  (1, 'Notebook', 19.99),
  (2, 'Mechanical Keyboard', 129.00)
ON CONFLICT DO NOTHING;
