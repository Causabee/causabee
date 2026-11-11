-- A request paid from top-ups was written with its tokens on both its rows, "spend" and
-- "spend_extra": sums over both counted them twice. Its tokens stay on the "spend" row, which every
-- such request has; the "spend_extra" row keeps only the money top-ups paid. Run once; again, it changes nothing.
UPDATE ledger SET tokens_in = 0, tokens_out = 0, tokens_cached = 0, searches = 0 WHERE kind = 'spend_extra';
