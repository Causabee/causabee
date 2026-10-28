-- Step 2: accounts from App Store subscriptions. Run once on the database made by step 1.
ALTER TABLE accounts ADD COLUMN kind TEXT NOT NULL DEFAULT 'hand';
ALTER TABLE accounts ADD COLUMN expires TEXT;
