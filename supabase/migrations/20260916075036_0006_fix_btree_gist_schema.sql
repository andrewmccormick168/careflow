-- Applied to careflow (alsgbnbzzdsfixgsaiak) 2026-09-16.
-- Security advisor flagged btree_gist installed in the public schema
-- (lint 0014_extension_in_public). Moved to the dedicated extensions
-- schema, consistent with pgcrypto/uuid-ossp already there.
alter extension btree_gist set schema extensions;
