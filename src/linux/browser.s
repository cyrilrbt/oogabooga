# Native Linux browser, entirely handwritten x86-64 assembly.
# GTK 3 / WebKitGTK 4.1 / SQLite. SysV: arguments rdi,rsi,rdx,rcx,r8,r9.
# Every function aligns rsp to 16 bytes before calls; callbacks preserve nonvolatile regs.
.intel_syntax noprefix

# Signal connection convenience: instance in rdi; optional user_data in rcx.
.macro connect signal, callback
    lea rsi, [rip + \signal]
    lea rdx, [rip + \callback]
    xor r8d, r8d
    xor r9d, r9d
    call g_signal_connect_data@PLT
.endm
# A common frame gives callbacks two preserved locals and aligned call space.
.macro enter
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    sub rsp, 32
.endm
.macro leave
    add rsp, 32
    pop r12
    pop rbx
    pop rbp
    ret
.endm

.text
.globl browser_main
.type browser_main,@function
browser_main:
    enter
    mov ebx, edi
    mov r12, rsi
    mov edi, 63                       # umask 077: profile and databases are private
    call umask@PLT
    xor edi, edi
    xor esi, esi
    call gtk_init_check@PLT
    test eax, eax
    jz .Lno_display
    call g_get_user_data_dir@PLT
    mov rdi, rax
    lea rsi, [rip + app_dir]
    xor edx, edx
    xor eax, eax
    call g_build_filename@PLT
    mov [rip + profile], rax
    mov rdi, rax
    mov esi, 448                      # 0700
    call g_mkdir_with_parents@PLT
    test eax, eax
    jnz .Lstorage_error
    call g_get_user_cache_dir@PLT
    mov rdi, rax
    lea rsi, [rip + app_dir]
    xor edx, edx
    xor eax, eax
    call g_build_filename@PLT
    mov [rip + cache], rax
    mov rdi, rax
    mov esi, 448
    call g_mkdir_with_parents@PLT
    test eax, eax
    jnz .Lstorage_error
    mov rdi, [rip + profile]
    lea rsi, [rip + history_file]
    xor edx, edx
    xor eax, eax
    call g_build_filename@PLT
    mov [rbp - 24], rax
    mov rdi, rax
    lea rsi, [rip + db]
    call history_open
    mov [rbp - 32], eax
    mov rdi, [rbp - 24]
    call g_free@PLT
    cmp DWORD PTR [rbp - 32], 0
    jne .Lstorage_error
    # Explicit data/cache directories and persistent cookie storage.
    lea rdi, [rip + prop_data]
    mov rsi, [rip + profile]
    lea rdx, [rip + prop_cache]
    mov rcx, [rip + cache]
    xor r8d, r8d
    xor eax, eax
    call webkit_website_data_manager_new@PLT
    mov [rbp - 24], rax
    mov rdi, rax
    call webkit_web_context_new_with_website_data_manager@PLT
    mov [rip + context], rax
    mov rdi, [rbp - 24]
    call g_object_unref@PLT
    mov rdi, [rip + context]
    call webkit_web_context_get_cookie_manager@PLT
    mov [rbp - 24], rax
    mov rdi, [rip + profile]
    lea rsi, [rip + cookie_file]
    xor edx, edx
    xor eax, eax
    call g_build_filename@PLT
    mov [rbp - 32], rax
    mov rdi, [rbp - 24]
    mov rsi, rax
    mov edx, 1                       # WEBKIT_COOKIE_PERSISTENT_STORAGE_SQLITE
    call webkit_cookie_manager_set_persistent_storage@PLT
    mov rdi, [rbp - 32]
    call g_free@PLT
    # Main window and vertical layout.
    xor edi, edi
    call gtk_window_new@PLT
    mov [rip + window], rax
    mov rdi, rax
    lea rsi, [rip + app_title]
    call gtk_window_set_title@PLT
    mov rdi, [rip + window]
    mov esi, 1160
    mov edx, 780
    call gtk_window_set_default_size@PLT
    mov rdi, [rip + window]
    xor ecx, ecx
    connect sig_destroy, quit
    mov rdi, [rip + window]
    xor ecx, ecx
    connect sig_key, key_pressed
    mov edi, 1                       # GTK_ORIENTATION_VERTICAL
    mov esi, 8
    call gtk_box_new@PLT
    mov [rip + root], rax
    mov rsi, rax
    mov rdi, [rip + window]
    call gtk_container_add@PLT
    xor edi, edi
    mov esi, 6
    call gtk_box_new@PLT
    mov [rip + toolbar], rax
    mov rdi, [rip + root]
    mov rsi, rax
    xor edx, edx
    xor ecx, ecx
    mov r8d, 8
    call gtk_box_pack_start@PLT
    lea rdi, [rip + back_text]
    lea rsi, [rip + back_clicked]
    call toolbar_button
    mov [rip + back_button], rax
    lea rdi, [rip + forward_text]
    lea rsi, [rip + forward_clicked]
    call toolbar_button
    mov [rip + forward_button], rax
    lea rdi, [rip + reload_text]
    lea rsi, [rip + reload_clicked]
    call toolbar_button
    call gtk_entry_new@PLT
    mov [rip + address], rax
    mov rdi, rax
    lea rsi, [rip + address_hint]
    call gtk_entry_set_placeholder_text@PLT
    mov rdi, [rip + address]
    xor ecx, ecx
    connect sig_activate, navigate
    mov rdi, [rip + toolbar]
    mov rsi, [rip + address]
    mov edx, 1
    mov ecx, 1
    xor r8d, r8d
    call gtk_box_pack_start@PLT
    lea rdi, [rip + history_text]
    lea rsi, [rip + show_history]
    call toolbar_button
    mov rdi, [rip + context]
    call webkit_web_view_new_with_context@PLT
    mov [rip + web], rax
    mov rdi, rax
    call setup_web
    mov rdi, [rip + root]
    mov rsi, [rip + web]
    mov edx, 1
    mov ecx, 1
    xor r8d, r8d
    call gtk_box_pack_start@PLT
    lea rdi, [rip + ready_text]
    call gtk_label_new@PLT
    mov [rip + status], rax
    mov rdi, [rip + root]
    mov rsi, rax
    xor edx, edx
    xor ecx, ecx
    mov r8d, 4
    call gtk_box_pack_start@PLT
    mov rdi, [rip + window]
    call gtk_widget_show_all@PLT
    lea rsi, [rip + homepage]
    cmp ebx, 1
    jle .Linitial
    mov rsi, [r12 + 8]
.Linitial:
    mov rdi, [rip + address]
    call gtk_entry_set_text@PLT
    call navigate
    call gtk_main@PLT
    mov rdi, [rip + db]
    call sqlite3_close@PLT
    mov rdi, [rip + context]
    call g_object_unref@PLT
    mov rdi, [rip + profile]
    call g_free@PLT
    mov rdi, [rip + cache]
    call g_free@PLT
    xor eax, eax
    leave
.Lno_display:
    lea rdi, [rip + display_error]
    xor eax, eax
    call g_printerr@PLT
    mov eax, 1
    leave
.Lstorage_error:
    lea rdi, [rip + storage_error]
    xor eax, eax
    call g_printerr@PLT
    mov rdi, [rip + db]
    call sqlite3_close@PLT
    mov eax, 1
    leave
.size browser_main,.-browser_main

# GtkButton *toolbar_button(label, callback)
toolbar_button:
    enter
    mov r12, rsi
    call gtk_button_new_with_label@PLT
    mov rbx, rax
    mov rdi, rax
    lea rsi, [rip + sig_clicked]
    mov rdx, r12
    xor ecx, ecx
    xor r8d, r8d
    xor r9d, r9d
    call g_signal_connect_data@PLT
    mov rdi, [rip + toolbar]
    mov rsi, rbx
    xor edx, edx
    xor ecx, ecx
    xor r8d, r8d
    call gtk_box_pack_start@PLT
    mov rax, rbx
    leave

quit:
    jmp gtk_main_quit@PLT
back_clicked:
    mov rdi, [rip + web]
    jmp webkit_web_view_go_back@PLT
forward_clicked:
    mov rdi, [rip + web]
    jmp webkit_web_view_go_forward@PLT
reload_clicked:
    enter
    mov rdi, [rip + web]
    call webkit_web_view_is_loading@PLT
    mov rdi, [rip + web]
    test eax, eax
    jz .Lreload
    call webkit_web_view_stop_loading@PLT
    leave
.Lreload:
    call webkit_web_view_reload@PLT
    leave

# char *destination(const char *input): owned result, HTTP(S) only or search.
.globl destination
.type destination,@function
destination:
    enter
    call g_strdup@PLT
    mov rdi, rax
    call g_strchug@PLT
    mov rdi, rax
    call g_strchomp@PLT
    mov rbx, rax
    xor r12d, r12d
    cmp BYTE PTR [rbx], 0
    je .Ldest_done
    mov rdi, rbx
    lea rsi, [rip + scheme_marker]
    call strstr@PLT
    test rax, rax
    jnz .Lexplicit
    mov rdi, rbx
    mov esi, 32
    call strchr@PLT
    test rax, rax
    jnz .Lsearch
    mov rdi, rbx
    mov esi, 46
    call strchr@PLT
    test rax, rax
    jnz .Lhost
    mov rdi, rbx
    lea rsi, [rip + localhost_text]
    call g_str_has_prefix@PLT
    test eax, eax
    jz .Lsearch
.Lhost:
    mov rdi, rbx
    lea rsi, [rip + localhost_text]
    call g_str_has_prefix@PLT
    test eax, eax
    jnz .Lhttp
    mov rdi, rbx
    lea rsi, [rip + loopback_text]
    call g_str_has_prefix@PLT
    test eax, eax
    jnz .Lhttp
    lea rsi, [rip + https_prefix]
    jmp .Lprefix
.Lhttp:
    lea rsi, [rip + http_prefix]
.Lprefix:
    lea rdi, [rip + concat_format]
    mov rdx, rbx
    xor eax, eax
    call g_strdup_printf@PLT
    mov r12, rax
    jmp .Ldest_done
.Lexplicit:
    mov rdi, rbx
    call allowed_uri
    test eax, eax
    jz .Ldest_done
    mov rdi, rbx
    call g_strdup@PLT
    mov r12, rax
    jmp .Ldest_done
.Lsearch:
    mov rdi, rbx
    xor esi, esi
    xor edx, edx
    call g_uri_escape_string@PLT
    mov r12, rax
    lea rdi, [rip + concat_format]
    lea rsi, [rip + search_prefix]
    mov rdx, rax
    xor eax, eax
    call g_strdup_printf@PLT
    mov [rbp - 24], rax
    mov rdi, r12
    call g_free@PLT
    mov r12, [rbp - 24]
.Ldest_done:
    mov rdi, rbx
    call g_free@PLT
    mov rax, r12
    leave
.size destination,.-destination

allowed_uri:
    enter
    mov rbx, rdi
    lea rsi, [rip + http_prefix]
    call g_str_has_prefix@PLT
    test eax, eax
    jnz .Lallowed
    mov rdi, rbx
    lea rsi, [rip + https_prefix]
    call g_str_has_prefix@PLT
.Lallowed:
    leave

navigate:
    enter
    mov rdi, [rip + address]
    call gtk_entry_get_text@PLT
    mov rdi, rax
    call destination
    mov rbx, rax
    test rax, rax
    jz .Linvalid
    mov rdi, [rip + web]
    mov rsi, rbx
    call webkit_web_view_load_uri@PLT
    mov rdi, rbx
    call g_free@PLT
    leave
.Linvalid:
    mov rdi, [rip + status]
    lea rsi, [rip + invalid_text]
    call gtk_label_set_text@PLT
    leave

# Connect both main and related popup views. WebKit supplies native auth/script dialogs.
setup_web:
    enter
    mov rbx, rdi
    xor ecx, ecx
    connect sig_load, load_changed
    mov rdi, rbx
    xor ecx, ecx
    connect sig_failed, load_failed
    mov rdi, rbx
    xor ecx, ecx
    connect sig_policy, decide_policy
    mov rdi, rbx
    xor ecx, ecx
    connect sig_create, create_popup
    mov rdi, rbx
    xor ecx, ecx
    connect sig_title, title_changed
    mov rdi, rbx
    xor ecx, ecx
    connect sig_terminated, process_terminated
    leave

# Keep controls and title current, including asynchronous document.title changes.
sync_view:
    enter
    mov rbx, rdi
    call webkit_web_view_get_title@PLT
    mov r12, rax
    mov rdi, rbx
    call gtk_widget_get_toplevel@PLT
    mov rdi, rax
    mov rsi, r12
    test rsi, rsi
    jnz .Ltitle
    lea rsi, [rip + app_title]
.Ltitle:
    call gtk_window_set_title@PLT
    cmp rbx, [rip + web]
    jne .Lsync_done
    mov rdi, rbx
    call webkit_web_view_get_uri@PLT
    test rax, rax
    jz .Lcontrols
    mov rdi, [rip + address]
    mov rsi, rax
    call gtk_entry_set_text@PLT
.Lcontrols:
    mov rdi, rbx
    call webkit_web_view_can_go_back@PLT
    mov rdi, [rip + back_button]
    mov esi, eax
    call gtk_widget_set_sensitive@PLT
    mov rdi, rbx
    call webkit_web_view_can_go_forward@PLT
    mov rdi, [rip + forward_button]
    mov esi, eax
    call gtk_widget_set_sensitive@PLT
.Lsync_done:
    leave

title_changed:
    enter
    mov rbx, rdi
    call sync_view
    # Update only this view's latest completed visit (row ID kept on the view).
    mov rdi, rbx
    lea rsi, [rip + visit_key]
    call g_object_get_data@PLT
    test rax, rax
    jz .Ltitle_done
    mov r12, [rax]
    mov rdi, rbx
    call webkit_web_view_get_title@PLT
    test rax, rax
    jz .Ltitle_done
    mov [rbp - 24], rax
    mov rdi, [rip + db]
    lea rsi, [rip + title_sql]
    mov edx, -1
    lea rcx, [rbp - 32]
    xor r8d, r8d
    call sqlite3_prepare_v2@PLT
    test eax, eax
    jnz .Ltitle_done
    mov rbx, [rbp - 32]
    mov rdi, rbx
    mov esi, 1
    mov rdx, [rbp - 24]
    mov ecx, -1
    mov r8, -1
    call sqlite3_bind_text@PLT
    mov rdi, rbx
    mov esi, 2
    mov rdx, r12
    call sqlite3_bind_int64@PLT
    mov rdi, rbx
    call sqlite3_step@PLT
    mov rdi, rbx
    call sqlite3_finalize@PLT
.Ltitle_done:
    leave

load_changed:
    enter
    mov rbx, rdi
    mov r12d, esi
    test esi, esi                     # WEBKIT_LOAD_STARTED
    jnz .Lload_later
    lea rsi, [rip + failed_key]
    xor edx, edx
    call g_object_set_data@PLT
    mov rdi, rbx
    lea rsi, [rip + visit_key]
    xor edx, edx
    call g_object_set_data@PLT
    cmp rbx, [rip + web]
    jne .Lload_done
    mov rdi, [rip + status]
    lea rsi, [rip + loading_text]
    call gtk_label_set_text@PLT
    jmp .Lload_done
.Lload_later:
    mov rdi, rbx
    call sync_view
    cmp r12d, 3                       # WEBKIT_LOAD_FINISHED
    jne .Lload_done
    mov rdi, rbx
    lea rsi, [rip + failed_key]
    call g_object_get_data@PLT
    test rax, rax
    jnz .Lload_done
    mov rdi, rbx
    call webkit_web_view_get_uri@PLT
    test rax, rax
    jz .Lload_done
    mov [rbp - 24], rax
    mov rdi, rax
    call allowed_uri
    test eax, eax
    jz .Lload_done
    mov rdi, rbx
    call webkit_web_view_get_title@PLT
    mov rdx, rax
    test rdx, rdx
    jnz .Lrecord
    lea rdx, [rip + empty_text]
.Lrecord:
    mov rdi, [rip + db]
    mov rsi, [rbp - 24]
    call history_add
    test eax, eax
    jnz .Lhistory_failed
    mov rdi, [rip + db]
    call sqlite3_last_insert_rowid@PLT
    mov r12, rax
    mov edi, 8
    call g_malloc@PLT
    mov [rax], r12
    mov rdi, rbx
    lea rsi, [rip + visit_key]
    mov rdx, rax
    mov rcx, QWORD PTR [rip + g_free@GOTPCREL]
    call g_object_set_data_full@PLT
    lea rsi, [rip + ready_text]
    jmp .Lload_status
.Lhistory_failed:
    lea rsi, [rip + history_error]
.Lload_status:
    cmp rbx, [rip + web]
    jne .Lload_done
    mov rdi, [rip + status]
    call gtk_label_set_text@PLT
.Lload_done:
    leave

# load-failed(view,event,uri,GError*,data); GError.message at +8 on x86-64.
load_failed:
    enter
    mov rbx, rdi
    mov r12, rcx
    lea rsi, [rip + failed_key]
    mov edx, 1
    call g_object_set_data@PLT
    cmp rbx, [rip + web]
    jne .Lfailed_done
    mov rdi, [rip + status]
    mov rsi, [r12 + 8]
    call gtk_label_set_text@PLT
.Lfailed_done:
    mov eax, 1                       # keep the page/status; suppress alternate error-page loads
    leave

process_terminated:
    enter
    cmp rdi, [rip + web]
    jne .Lterminated_done
    mov rdi, [rip + status]
    lea rsi, [rip + process_error]
    call gtk_label_set_text@PLT
.Lterminated_done:
    leave

# Block external application schemes; retain WebKit's standard TLS handling.
decide_policy:
    enter
    mov rbx, rsi
    test edx, edx                     # NAVIGATION_ACTION only
    jnz .Lpolicy_default
    mov rdi, rbx
    call webkit_navigation_policy_decision_get_navigation_action@PLT
    mov rdi, rax
    call webkit_navigation_action_get_request@PLT
    mov rdi, rax
    call webkit_uri_request_get_uri@PLT
    mov r12, rax
    mov rdi, rax
    call allowed_uri
    test eax, eax
    jnz .Lpolicy_default
    mov rdi, r12
    lea rsi, [rip + about_prefix]
    call g_str_has_prefix@PLT
    test eax, eax
    jnz .Lpolicy_default
    mov rdi, rbx
    call webkit_policy_decision_ignore@PLT
    mov eax, 1
    leave
.Lpolicy_default:
    xor eax, eax
    leave

create_popup:
    enter
    call webkit_web_view_new_with_related_view@PLT
    mov rbx, rax
    mov rdi, rax
    call setup_web
    xor edi, edi
    call gtk_window_new@PLT
    mov r12, rax
    mov rdi, rax
    mov esi, 760
    mov edx, 720
    call gtk_window_set_default_size@PLT
    mov rdi, r12
    lea rsi, [rip + app_title]
    call gtk_window_set_title@PLT
    mov rdi, r12
    mov rsi, rbx
    call gtk_container_add@PLT
    mov rdi, rbx
    mov rcx, r12
    connect sig_ready, popup_ready
    mov rdi, rbx
    mov rcx, r12
    connect sig_close, popup_close
    mov rax, rbx
    leave
popup_ready:
    mov rdi, rsi                     # user_data is the owning GtkWindow
    jmp gtk_widget_show_all@PLT
popup_close:
    mov rdi, rsi
    jmp gtk_widget_destroy@PLT

# Keyboard shortcuts, using GDK accessor functions rather than event struct offsets.
key_pressed:
    enter
    mov rbx, rsi
    mov rdi, rsi
    lea rsi, [rbp - 24]
    call gdk_event_get_state@PLT
    test DWORD PTR [rbp - 24], 4     # GDK_CONTROL_MASK
    jz .Lkey_default
    mov rdi, rbx
    lea rsi, [rbp - 28]
    call gdk_event_get_keyval@PLT
    mov edi, [rbp - 28]
    call gdk_keyval_to_lower@PLT
    cmp eax, 108                      # l
    je .Lfocus
    cmp eax, 114                      # r
    je .Lkey_reload
    cmp eax, 121                      # y
    je .Lkey_history
    cmp eax, 113                      # q
    je .Lkey_quit
    cmp eax, 91
    je .Lkey_back
    cmp eax, 93
    je .Lkey_forward
.Lkey_default:
    xor eax, eax
    leave
.Lfocus:
    mov rdi, [rip + address]
    call gtk_widget_grab_focus@PLT
    mov rdi, [rip + address]
    xor esi, esi
    mov edx, -1
    call gtk_editable_select_region@PLT
    jmp .Lkey_handled
.Lkey_reload:
    call reload_clicked
    jmp .Lkey_handled
.Lkey_history:
    call show_history
    jmp .Lkey_handled
.Lkey_quit:
    call gtk_main_quit@PLT
    jmp .Lkey_handled
.Lkey_back:
    call back_clicked
    jmp .Lkey_handled
.Lkey_forward:
    call forward_clicked
.Lkey_handled:
    mov eax, 1
    leave

# Searchable history in GTK; all query, binding, and list construction is assembly.
show_history:
    enter
    cmp QWORD PTR [rip + history_window], 0
    jne .Lhistory_present
    xor edi, edi
    call gtk_window_new@PLT
    mov [rip + history_window], rax
    mov rdi, rax
    lea rsi, [rip + history_title]
    call gtk_window_set_title@PLT
    mov rdi, [rip + history_window]
    mov esi, 850
    mov edx, 480
    call gtk_window_set_default_size@PLT
    mov rdi, [rip + history_window]
    mov rsi, [rip + window]
    call gtk_window_set_transient_for@PLT
    mov rdi, [rip + history_window]
    mov esi, 1
    call gtk_window_set_destroy_with_parent@PLT
    mov rdi, [rip + history_window]
    lea rcx, [rip + history_window]
    connect sig_destroy, history_destroyed
    mov edi, 1
    mov esi, 8
    call gtk_box_new@PLT
    mov rbx, rax
    mov rdi, [rip + history_window]
    mov rsi, rax
    call gtk_container_add@PLT
    call gtk_search_entry_new@PLT
    mov [rip + history_search], rax
    mov rdi, rax
    xor ecx, ecx
    connect sig_search, refresh_history
    mov rdi, rbx
    mov rsi, [rip + history_search]
    xor edx, edx
    xor ecx, ecx
    mov r8d, 4
    call gtk_box_pack_start@PLT
    xor edi, edi
    xor esi, esi
    call gtk_scrolled_window_new@PLT
    mov r12, rax
    mov rdi, rbx
    mov rsi, rax
    mov edx, 1
    mov ecx, 1
    xor r8d, r8d
    call gtk_box_pack_start@PLT
    call gtk_list_box_new@PLT
    mov [rip + history_list], rax
    mov rdi, rax
    mov esi, 0                       # double click / Enter activates, not single click
    call gtk_list_box_set_activate_on_single_click@PLT
    mov rdi, [rip + history_list]
    xor ecx, ecx
    connect sig_row, open_history
    mov rdi, r12
    mov rsi, [rip + history_list]
    call gtk_container_add@PLT
.Lhistory_present:
    call refresh_history
    mov rdi, [rip + history_window]
    call gtk_widget_show_all@PLT
    mov rdi, [rip + history_window]
    call gtk_window_present@PLT
    leave
history_destroyed:
    mov QWORD PTR [rip + history_window], 0
    ret

refresh_history:
    enter
    mov rdi, [rip + history_list]
    call gtk_container_get_children@PLT
    mov rdi, rax
    mov rsi, QWORD PTR [rip + gtk_widget_destroy@GOTPCREL]
    call g_list_free_full@PLT
    mov rdi, [rip + db]
    lea rsi, [rip + history_sql]
    mov edx, -1
    lea rcx, [rbp - 24]
    xor r8d, r8d
    call sqlite3_prepare_v2@PLT
    test eax, eax
    jnz .Lrefresh_done
    mov rbx, [rbp - 24]
    mov rdi, [rip + history_search]
    call gtk_entry_get_text@PLT
    mov rdi, rbx
    mov esi, 1
    mov rdx, rax
    mov ecx, -1
    mov r8, -1
    call sqlite3_bind_text@PLT
.Lrows:
    mov rdi, rbx
    call sqlite3_step@PLT
    cmp eax, 100
    jne .Lrows_done
    mov rdi, rbx
    xor esi, esi
    call sqlite3_column_text@PLT
    mov [rbp - 32], rax
    mov rdi, rbx
    mov esi, 1
    call sqlite3_column_text@PLT
    mov [rbp - 40], rax
    mov rdi, rbx
    mov esi, 2
    call sqlite3_column_text@PLT
    lea rdi, [rip + row_format]
    mov rsi, [rbp - 32]
    mov rdx, [rbp - 40]
    mov rcx, rax
    xor eax, eax
    call g_strdup_printf@PLT
    mov [rbp - 48], rax
    mov rdi, rax
    call gtk_label_new@PLT
    mov r12, rax
    mov rdi, [rbp - 48]
    call g_free@PLT
    mov rdi, r12
    pxor xmm0, xmm0
    call gtk_label_set_xalign@PLT
    mov rdi, r12
    mov esi, 3                       # PANGO_ELLIPSIZE_END
    call gtk_label_set_ellipsize@PLT
    call gtk_list_box_row_new@PLT
    mov [rbp - 48], rax
    mov rdi, rax
    mov rsi, r12
    call gtk_container_add@PLT
    mov rdi, [rbp - 40]
    call g_strdup@PLT
    mov rdi, [rbp - 48]
    lea rsi, [rip + url_key]
    mov rdx, rax
    mov rcx, QWORD PTR [rip + g_free@GOTPCREL]
    call g_object_set_data_full@PLT
    mov rdi, [rip + history_list]
    mov rsi, [rbp - 48]
    call gtk_container_add@PLT
    jmp .Lrows
.Lrows_done:
    mov rdi, rbx
    call sqlite3_finalize@PLT
    mov rdi, [rip + history_list]
    call gtk_widget_show_all@PLT
.Lrefresh_done:
    leave

open_history:
    enter
    mov rdi, rsi                     # selected GtkListBoxRow
    lea rsi, [rip + url_key]
    call g_object_get_data@PLT
    test rax, rax
    jz .Lopen_history_done
    mov rdi, [rip + web]
    mov rsi, rax
    call webkit_web_view_load_uri@PLT
    mov rdi, [rip + window]
    call gtk_window_present@PLT
.Lopen_history_done:
    leave

.section .rodata
app_dir: .asciz "oogabooga"
app_title: .asciz "Oogabooga"
history_file: .asciz "history.sqlite3"
cookie_file: .asciz "cookies.sqlite3"
prop_data: .asciz "base-data-directory"
prop_cache: .asciz "base-cache-directory"
homepage: .asciz "https://example.com"
back_text: .asciz "←"
forward_text: .asciz "→"
reload_text: .asciz "Reload / Stop"
history_text: .asciz "History"
address_hint: .asciz "Search or enter address"
ready_text: .asciz "Ready"
loading_text: .asciz "Loading…"
invalid_text: .asciz "Enter an HTTP(S) address or search terms."
history_error: .asciz "Page loaded; history could not be saved."
process_error: .asciz "Page process stopped. Press Ctrl+R to reload."
storage_error: .asciz "Oogabooga: cannot open profile/history storage. Check XDG_DATA_HOME and XDG_CACHE_HOME.\n"
display_error: .asciz "Oogabooga: cannot open display. Run inside a graphical Linux session.\n"
empty_text: .asciz ""
http_prefix: .asciz "http://"
https_prefix: .asciz "https://"
about_prefix: .asciz "about:"
localhost_text: .asciz "localhost"
loopback_text: .asciz "127."
scheme_marker: .asciz "://"
concat_format: .asciz "%s%s"
search_prefix: .asciz "https://duckduckgo.com/?q="
failed_key: .asciz "oogabooga-load-failed"
visit_key: .asciz "oogabooga-visit-id"
url_key: .asciz "oogabooga-url"
history_title: .asciz "History — double-click or press Enter to open"
row_format: .asciz "%s\n%s   •   %s"
history_sql: .asciz "SELECT title,url,datetime(visited_at,'unixepoch','localtime') FROM visits WHERE instr(lower(url),lower(?1)) OR instr(lower(title),lower(?1)) ORDER BY visited_at DESC,id DESC LIMIT 1000"
title_sql: .asciz "UPDATE visits SET title=?1 WHERE id=?2"
sig_destroy: .asciz "destroy"
sig_key: .asciz "key-press-event"
sig_clicked: .asciz "clicked"
sig_activate: .asciz "activate"
sig_load: .asciz "load-changed"
sig_failed: .asciz "load-failed"
sig_policy: .asciz "decide-policy"
sig_create: .asciz "create"
sig_title: .asciz "notify::title"
sig_terminated: .asciz "web-process-terminated"
sig_ready: .asciz "ready-to-show"
sig_close: .asciz "close"
sig_search: .asciz "search-changed"
sig_row: .asciz "row-activated"
.section .bss
.p2align 3
window: .zero 8
web: .zero 8
address: .zero 8
status: .zero 8
back_button: .zero 8
forward_button: .zero 8
root: .zero 8
toolbar: .zero 8
context: .zero 8
profile: .zero 8
cache: .zero 8
db: .zero 8
history_window: .zero 8
history_list: .zero 8
history_search: .zero 8
.section .note.GNU-stack,"",@progbits
