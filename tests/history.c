#include <assert.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sqlite3.h>
extern int history_open(const char *, sqlite3 **);
extern int history_add(sqlite3 *, const char *, const char *);
// The assembly entry point resolves here in the test executable.
int browser_main(void) {
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
    assert(sqlite3_exec(db,"PRAGMA query_only=ON",NULL,NULL,NULL) == SQLITE_OK);
    assert(history_add(db,"https://example.com","read-only") == SQLITE_READONLY);
    sqlite3_close(db); unlink(path);
    db = NULL;
    assert(history_open("/no/such/directory/history.sqlite3",&db) != SQLITE_OK);
    sqlite3_close(db);
    puts("PASS: assembly SQLite persistence, repeated visits, Unicode, SQL binding, and errors");
    return 0;
}
