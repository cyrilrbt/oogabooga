// Shared SQLite schema and insert statement for Darwin ARM64 and Linux x86-64.
schema:
.asciz "PRAGMA journal_mode=WAL; PRAGMA busy_timeout=3000; CREATE TABLE IF NOT EXISTS visits(id INTEGER PRIMARY KEY, url TEXT NOT NULL, title TEXT NOT NULL, visited_at INTEGER NOT NULL DEFAULT (unixepoch())); CREATE INDEX IF NOT EXISTS visits_time ON visits(visited_at DESC,id DESC); PRAGMA user_version=1;"
insert_sql:
.asciz "INSERT INTO visits(url,title) VALUES(?1,?2)"
