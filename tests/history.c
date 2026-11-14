#include <assert.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sqlite3.h>
extern int history_open(const char *, sqlite3 **);
extern int history_add(sqlite3 *, const char *, const char *);

extern int history_search(sqlite3 *, const char *, void (*)(void *, const char *, const char *, const char *, sqlite3_int64), void *);
extern int history_update_title(sqlite3 *, sqlite3_int64, const char *);
struct results { int count; sqlite3_int64 ids[8]; char titles[8][128]; };
static void collect(void *context, const char *url, const char *title, const char *date, sqlite3_int64 id) {
    struct results *r = context;
    assert(r->count < 8 && url && title && date && strlen(date) == 19);
    r->ids[r->count] = id;
    snprintf(r->titles[r->count], sizeof(r->titles[0]), "%s", title);
    r->count++;
}
// Linux's assembly entry resolves here; macOS tests have their own entry.
#ifdef __APPLE__
int main(void) {
#else
int browser_main(void) {
#endif
    char path[] = "/tmp/oogabooga-history-XXXXXX";
    int fd = mkstemp(path); assert(fd >= 0); close(fd);
    sqlite3 *db = NULL;
    assert(history_open(path, &db) == SQLITE_OK);
    const char *url = "https://example.com/?q='; DROP TABLE visits;--";
    const char *title = "Unicode: café 🌐 and 'quoted'";
    assert(history_add(db,url,title) == SQLITE_OK);
    assert(history_add(db,url,"second visit") == SQLITE_OK);
    assert(sqlite3_close(db) == SQLITE_OK);
    assert(history_open(path,&db) == SQLITE_OK);
    sqlite3_stmt *s = NULL;
    assert(sqlite3_prepare_v2(db,"SELECT url,title,visited_at FROM visits ORDER BY id",-1,&s,NULL) == SQLITE_OK);
    assert(sqlite3_step(s) == SQLITE_ROW);
    assert(strcmp((const char *)sqlite3_column_text(s,0),url) == 0);
    assert(strcmp((const char *)sqlite3_column_text(s,1),title) == 0);
    assert(sqlite3_column_int64(s,2) > 0);
    assert(sqlite3_step(s) == SQLITE_ROW);
    assert(strcmp((const char *)sqlite3_column_text(s,1),"second visit") == 0);
    assert(sqlite3_step(s) == SQLITE_DONE);
    sqlite3_finalize(s);
    struct results rows = {0};
    assert(history_search(db, "", collect, &rows) == SQLITE_OK);
    assert(rows.count == 2 && rows.ids[0] == 2 && rows.ids[1] == 1);
    assert(strcmp(rows.titles[0], "second visit") == 0);
    assert(history_update_title(db, 1, "Updated café 'title'") == SQLITE_OK);
    rows = (struct results){0};
    assert(history_search(db, "UPDATED", collect, &rows) == SQLITE_OK);
    assert(rows.count == 1 && rows.ids[0] == 1 && strcmp(rows.titles[0], "Updated café 'title'") == 0);
    rows = (struct results){0};
    assert(history_search(db, "second visit", collect, &rows) == SQLITE_OK);
    assert(rows.count == 1 && rows.ids[0] == 2);
    assert(history_add(db, "https://example.com/%_literal", "literal wildcard") == SQLITE_OK);
    rows = (struct results){0};
    assert(history_search(db, "%_", collect, &rows) == SQLITE_OK && rows.count == 1);
    rows = (struct results){0};
    assert(history_search(db, "'; DROP TABLE visits;--", collect, &rows) == SQLITE_OK);
    assert(sqlite3_exec(db,"PRAGMA query_only=ON",NULL,NULL,NULL) == SQLITE_OK);
    assert(history_add(db,"https://example.com","read-only") == SQLITE_READONLY);
    assert(history_update_title(db, 1, "read-only") == SQLITE_READONLY);
    assert(sqlite3_exec(db,"PRAGMA query_only=OFF; DROP TABLE visits",NULL,NULL,NULL) == SQLITE_OK);
    assert(history_search(db, "", collect, &rows) == SQLITE_ERROR);
    assert(history_update_title(db, 1, "missing table") == SQLITE_ERROR);
    sqlite3_close(db); unlink(path);
    db = NULL;
    assert(history_open("/no/such/directory/history.sqlite3",&db) != SQLITE_OK);
    sqlite3_close(db);
    puts("PASS: assembly SQLite persistence, repeated visits, Unicode, SQL binding, search ordering, literal matching, title updates, and errors");
    return 0;
}
