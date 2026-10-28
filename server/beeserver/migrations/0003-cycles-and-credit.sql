-- Step 3: a subscriber's month from the day Pro was bought, the subscription's first transaction
-- to find the account by when Apple writes, and accounts of top-ups without Pro.
ALTER TABLE accounts ADD COLUMN anchor TEXT;
ALTER TABLE accounts ADD COLUMN orig_tx TEXT;
CREATE INDEX IF NOT EXISTS accounts_orig_tx ON accounts(orig_tx);
UPDATE accounts SET orig_tx = substr(id, 7) WHERE id LIKE 'apple:%';
UPDATE accounts SET anchor = created WHERE kind = 'apple';
