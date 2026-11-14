// Integration harness only. The shipped Linux application contains no C objects.
#include <gtk/gtk.h>
#include <webkit2/webkit2.h>
#include <sqlite3.h>
#include <assert.h>
#include <string.h>
#include <stdio.h>
#include <stdlib.h>
extern int browser_main(int, char **);
extern char *destination(const char *);
extern void __real_gtk_main(void);
static WebKitWebView *view;
static GtkWidget *main_window, *history_button, *location_entry, *search, *list, *status;
static int phase, ticks, busy, finished, authenticated;
static gboolean restart;
static const char *base = "http://127.0.0.1:8765";

static void walk(GtkWidget *w, gpointer unused) {
    (void)unused;
    if (WEBKIT_IS_WEB_VIEW(w) && !view) view = WEBKIT_WEB_VIEW(w);
    if (GTK_IS_BUTTON(w) && g_strcmp0(gtk_button_get_label(GTK_BUTTON(w)), "History") == 0) history_button = w;
    if (GTK_IS_LABEL(w) && gtk_widget_get_parent(w) == gtk_bin_get_child(GTK_BIN(main_window))) status = w;
    if (GTK_IS_ENTRY(w) && !GTK_IS_SEARCH_ENTRY(w) && !location_entry) location_entry = w;
    if (GTK_IS_SEARCH_ENTRY(w)) search = w;
    if (GTK_IS_LIST_BOX(w)) list = w;
    if (GTK_IS_CONTAINER(w)) gtk_container_foreach(GTK_CONTAINER(w), walk, NULL);
}
static void load(const char *path) {
    char *url = g_strconcat(base, path, NULL);
    finished = 0;
    webkit_web_view_load_uri(view, url);
    g_free(url);
}
static void changed(WebKitWebView *v, WebKitLoadEvent event, gpointer data) {
    (void)v; (void)data;
    if (event == WEBKIT_LOAD_FINISHED) finished = 1;
}
static gboolean auth(WebKitWebView *v, WebKitAuthenticationRequest *r, gpointer data) {
    (void)v; (void)data;
    assert(!webkit_authentication_request_is_retry(r));
    WebKitCredential *c = webkit_credential_new("test", "browser", WEBKIT_CREDENTIAL_PERSISTENCE_FOR_SESSION);
    webkit_authentication_request_authenticate(r, c);
    webkit_credential_free(c); authenticated = 1; return TRUE;
}
static void checked_text(GObject *object, GAsyncResult *result, gpointer data) {
    GError *error = NULL;
    JSCValue *value = webkit_web_view_evaluate_javascript_finish(WEBKIT_WEB_VIEW(object), result, &error);
    if (error) g_error("JavaScript check failed: %s", error->message);
    char *text = jsc_value_to_string(value);
    assert(strstr(text, (const char *)data));
    g_free(text); g_object_unref(value); busy = 0;
    if (restart) { puts("PASS: cookies survive browser process restart"); gtk_main_quit(); return; }
    if (phase == 1) { phase = 2; load("/auth"); }
    else if (phase == 2) {
        assert(authenticated);
        phase = 3;
        WebKitSettings *settings = webkit_web_view_get_settings(view);
        webkit_settings_set_javascript_can_open_windows_automatically(settings, TRUE);
        webkit_web_view_evaluate_javascript(view, "window.open('/popup','login')", -1, NULL, NULL, NULL, NULL, NULL);
    }
}
static void check_body(const char *expected) {
    busy = 1;
    webkit_web_view_evaluate_javascript(view, "document.body.innerText", -1, NULL, NULL, NULL, checked_text, (gpointer)expected);
}
static void close_popup(GObject *object, GAsyncResult *result, gpointer data) {
    (void)data;
    GError *error = NULL;
    JSCValue *v = webkit_web_view_evaluate_javascript_finish(WEBKIT_WEB_VIEW(object), result, &error);
    if (error) g_error("Popup check failed: %s", error->message);
    if (v) g_object_unref(v);
    busy = 0;
}
static gboolean tick(gpointer data) {
    (void)data;
    static int previous = -1;
    if (phase != previous) { printf("Browser phase %d: %s\n", phase, webkit_web_view_get_uri(view)); previous = phase; }
    if (++ticks > 900) g_error("Browser smoke timeout at phase %d (uri=%s)", phase, webkit_web_view_get_uri(view));
    if (busy) return G_SOURCE_CONTINUE;
    if (phase == 0 && finished) {
        if (restart) { check_body("PASS: persistent cookie received"); return G_SOURCE_CONTINUE; }
        phase = 1; load("/");
    } else if (phase == 1 && finished) {
        check_body("PASS: persistent cookie received");
    } else if (phase == 2 && finished) {
        check_body("PASS: HTTP authentication");
    } else if (phase == 3) {
        GList *windows = gtk_window_list_toplevels();
        for (GList *it = windows; it; it = it->next) {
            GtkWidget *w = it->data;
            if (w == main_window || !gtk_widget_get_visible(w)) continue;
            GtkWidget *child = gtk_bin_get_child(GTK_BIN(w));
            if (!WEBKIT_IS_WEB_VIEW(child) || webkit_web_view_is_loading(WEBKIT_WEB_VIEW(child))) continue;
            assert(gtk_accel_groups_activate(G_OBJECT(w),GDK_KEY_l,GDK_CONTROL_MASK));
            assert(gtk_window_get_focus(GTK_WINDOW(main_window))==location_entry);
            phase = 4; busy = 1;
            webkit_web_view_evaluate_javascript(WEBKIT_WEB_VIEW(child), "window.opener.document.title='Popup OK';window.close()", -1, NULL, NULL, NULL, close_popup, NULL);
            break;
        }
        g_list_free(windows);
    } else if (phase == 4 && g_strcmp0(webkit_web_view_get_title(view), "Popup OK") == 0) {
        phase = 5; load("/second");
    } else if (phase == 5 && finished) {
        assert(webkit_web_view_can_go_back(view));
        phase = 6; finished = 0; assert(gtk_accel_groups_activate(G_OBJECT(main_window),GDK_KEY_bracketleft,GDK_CONTROL_MASK));
    } else if (phase == 6 && finished) {
        assert(g_str_has_suffix(webkit_web_view_get_uri(view), "/auth"));
        assert(webkit_web_view_can_go_forward(view));
        phase = 7; finished = 0; assert(gtk_accel_groups_activate(G_OBJECT(main_window),GDK_KEY_bracketright,GDK_CONTROL_MASK));
    } else if (phase == 7 && finished) {
        assert(g_str_has_suffix(webkit_web_view_get_uri(view), "/second"));
        assert(gtk_accel_groups_activate(G_OBJECT(main_window),GDK_KEY_y,GDK_CONTROL_MASK));
        GList *windows = gtk_window_list_toplevels();
        for (GList *it = windows; it; it = it->next) if (it->data != main_window) {
            walk(it->data, NULL);
            if(search && gtk_widget_get_toplevel(search)==it->data)
                assert(gtk_accel_groups_activate(G_OBJECT(it->data),GDK_KEY_l,GDK_CONTROL_MASK));
        }
        g_list_free(windows);
        assert(search && list);
        gtk_entry_set_text(GTK_ENTRY(search), "cookie"); phase = 8;
    } else if (phase == 8) {
        GList *rows = gtk_container_get_children(GTK_CONTAINER(list));
        int count = g_list_length(rows); g_list_free(rows);
        if (count != 1) return G_SOURCE_CONTINUE;
        GtkListBoxRow *row = gtk_list_box_get_row_at_index(GTK_LIST_BOX(list), 0);
        g_signal_emit_by_name(list, "row-activated", row);
        phase = 9; finished = 0;
    } else if (phase == 9 && finished) {
        assert(g_str_has_suffix(webkit_web_view_get_uri(view), "/cookie"));
        phase = 11; finished = 0;
        assert(gtk_accel_groups_activate(G_OBJECT(main_window),GDK_KEY_r,GDK_CONTROL_MASK));
    } else if (phase == 11 && finished) {
        phase = 10; finished = 0;
        webkit_web_view_load_uri(view, "http://127.0.0.1:18765/unreachable");
    } else if (phase == 10 && finished && !webkit_web_view_is_loading(view)) {
        assert(status && strcmp(gtk_label_get_text(GTK_LABEL(status)), "Ready") != 0);
        puts("PASS: rendering, cookies, HTTP auth, popup opener/close, back/forward, history search/open, failed navigation");
        assert(gtk_accel_groups_activate(G_OBJECT(main_window),GDK_KEY_q,GDK_CONTROL_MASK)); return G_SOURCE_REMOVE;
    }
    return G_SOURCE_CONTINUE;
}
void __wrap_gtk_main(void) {
    GList *windows = gtk_window_list_toplevels();
    assert(windows);
    main_window = windows->data;
    walk(main_window, NULL); g_list_free(windows);
    assert(view && history_button && location_entry);
    GList *icons=gtk_window_get_default_icon_list(); assert(icons);
    assert(gdk_pixbuf_get_width(icons->data)==512 && gdk_pixbuf_get_height(icons->data)==512);
    g_list_free(icons);
    gtk_widget_grab_focus(GTK_WIDGET(view));
    assert(!gtk_accel_groups_activate(G_OBJECT(main_window),GDK_KEY_l,0));
    assert(!gtk_accel_groups_activate(G_OBJECT(main_window),GDK_KEY_l,GDK_SUPER_MASK));
    assert(!gtk_accel_groups_activate(G_OBJECT(main_window),GDK_KEY_l,GDK_CONTROL_MASK|GDK_SHIFT_MASK));
    assert(!gtk_accel_groups_activate(G_OBJECT(main_window),GDK_KEY_l,GDK_CONTROL_MASK|GDK_MOD1_MASK));
    assert(gtk_accel_groups_activate(G_OBJECT(main_window),GDK_KEY_l,GDK_CONTROL_MASK));
    assert(gtk_window_get_focus(GTK_WINDOW(main_window))==location_entry);
    int start,end;
    assert(gtk_editable_get_selection_bounds(GTK_EDITABLE(location_entry),&start,&end));
    assert(start==0 && end==(int)g_utf8_strlen(gtk_entry_get_text(GTK_ENTRY(location_entry)),-1));
    gtk_editable_select_region(GTK_EDITABLE(location_entry),0,0);
    assert(gtk_bindings_activate(G_OBJECT(location_entry),GDK_KEY_a,GDK_CONTROL_MASK));
    assert(gtk_editable_get_selection_bounds(GTK_EDITABLE(location_entry),&start,&end) && start==0);
    puts("PASS: native Control accelerators, modifier matching, address focus/select-all, and GTK editing binding");
    g_signal_connect(view, "load-changed", G_CALLBACK(changed), NULL);
    g_signal_connect(view, "authenticate", G_CALLBACK(auth), NULL);
    g_timeout_add(100, tick, NULL);
    __real_gtk_main();
}
int main(void) {
    struct { const char *input, *expected; } cases[] = {
        {"example.com", "https://example.com"}, {"localhost:8765", "http://localhost:8765"},
        {"  https://example.com/a  ", "https://example.com/a"},
        {"hello world", "https://duckduckgo.com/?q=hello%20world"},
        {"a&b", "https://duckduckgo.com/?q=a%26b"},
        {"file:///etc/passwd", NULL}, {"javascript://alert(1)", NULL}, {"   ", NULL}
    };
    for (size_t i = 0; i < G_N_ELEMENTS(cases); i++) {
        char *url = destination(cases[i].input);
        assert(g_strcmp0(url, cases[i].expected) == 0); g_free(url);
    }
    puts("PASS: assembly URL normalization and scheme filtering");
    setvbuf(stdout, NULL, _IONBF, 0);
    restart = g_getenv("OOGABOOGA_SMOKE_RESTART") != NULL;
    char *args[] = {"oogabooga", restart ? "http://127.0.0.1:8765/" : "http://127.0.0.1:8765/cookie", NULL};
    assert(browser_main(2, args) == 0);
    char *path = g_build_filename(g_get_user_data_dir(), "oogabooga", "history.sqlite3", NULL);
    sqlite3 *db = NULL; assert(sqlite3_open(path, &db) == SQLITE_OK);
    sqlite3_stmt *s = NULL;
    assert(sqlite3_prepare_v2(db, "SELECT count(*) FROM visits WHERE url LIKE '%unreachable%'", -1, &s, NULL) == SQLITE_OK);
    assert(sqlite3_step(s) == SQLITE_ROW && sqlite3_column_int(s, 0) == 0);
    sqlite3_finalize(s);
    assert(sqlite3_prepare_v2(db, "SELECT count(*) FROM visits WHERE length(title)>0", -1, &s, NULL) == SQLITE_OK);
    assert(sqlite3_step(s) == SQLITE_ROW && sqlite3_column_int(s, 0) > 0);
    sqlite3_finalize(s); sqlite3_close(db); g_free(path);
    return 0;
}
