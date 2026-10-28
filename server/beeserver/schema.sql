-- The beeserver's database (Cloudflare D1, kept in the EU). Three tables. No question, answer,
-- mail text or name is ever stored: only who asked, which model, how many tokens, what it cost.

CREATE TABLE IF NOT EXISTS accounts (
  id TEXT PRIMARY KEY,                 -- a name given by hand; "app:" and the app's id for the Apple Account; or "apple:" and a first transaction
  created TEXT NOT NULL,
  allowance_micros INTEGER NOT NULL,   -- the month's allowance in micro-dollars: 3_000_000 is $3
  blocked INTEGER NOT NULL DEFAULT 0,
  kind TEXT NOT NULL DEFAULT 'hand',   -- hand | apple | credit (top-ups without Pro)
  expires TEXT,                        -- apple: when the subscription ends, as the App Store last said
  anchor TEXT,                         -- apple: when Pro was first bought — its months run from that day
  orig_tx TEXT                         -- apple: the subscription's first transaction, as notifications name it
);
CREATE INDEX IF NOT EXISTS accounts_orig_tx ON accounts(orig_tx);

CREATE TABLE IF NOT EXISTS tokens (
  hash TEXT PRIMARY KEY,               -- SHA-256 of the token: the token itself is never kept
  account TEXT NOT NULL REFERENCES accounts(id),
  label TEXT NOT NULL,
  created TEXT NOT NULL,
  revoked INTEGER NOT NULL DEFAULT 0
);

-- The balance is the sum of the ledger: nothing else holds money, so everything can be checked.
CREATE TABLE IF NOT EXISTS ledger (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  account TEXT NOT NULL REFERENCES accounts(id),
  period TEXT NOT NULL,                -- the month it counts in, "2026-10"
  kind TEXT NOT NULL,                  -- spend | spend_extra | topup | grant | refund
  micros INTEGER NOT NULL,             -- spend positive; a topup or grant adds to what may be spent
  ref TEXT UNIQUE,                     -- the request's id, or the purchase's: never counted twice
  model TEXT,
  tokens_in INTEGER, tokens_out INTEGER, tokens_cached INTEGER, searches INTEGER,
  time TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS ledger_account_period ON ledger(account, period);
