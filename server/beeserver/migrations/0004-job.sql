-- F004: each request's job (read | digest | brief | chat | unknown) and the tier OpenAI answered on
-- (flex | default). Rows from before stay NULL and count as "unknown". Run before the server that writes them.
ALTER TABLE ledger ADD COLUMN job TEXT;
ALTER TABLE ledger ADD COLUMN tier TEXT;
