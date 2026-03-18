// Wizardry Desktop Host - Linux native WebView wrapper
// Minimal C implementation using GTK3 + WebKit2GTK
// Build: gcc -O2 main.c -o wizardry-host `pkg-config --cflags --libs gtk+-3.0 webkit2gtk-4.1`

#include <gtk/gtk.h>
#include <webkit2/webkit2.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/wait.h>
#include <unistd.h>

#define WINDOW_MIN_WIDTH 420
#define WINDOW_MIN_HEIGHT 320
#define MAIN_DEFAULT_WIDTH 1024
#define MAIN_DEFAULT_HEIGHT 768
#define POPUP_DEFAULT_WIDTH 980
#define POPUP_DEFAULT_HEIGHT 720

typedef struct _AppState AppState;
typedef struct _WindowContext WindowContext;

struct _AppState {
    char *app_path;
    char *app_name;
    char *index_uri;
    GList *windows;
    WindowContext *main_context;
    gboolean keep_running_in_background;
    gboolean show_status_icon;
    GtkStatusIcon *status_icon;
};

struct _WindowContext {
    AppState *state;
    GtkWidget *window;
    WebKitWebView *web_view;
};

static void message_received_cb(WebKitUserContentManager *manager,
                                WebKitJavascriptResult *js_result,
                                gpointer user_data);
static WebKitWebView *web_view_create_cb(WebKitWebView *web_view,
                                         WebKitNavigationAction *navigation_action,
                                         gpointer user_data);
static void window_destroy_cb(GtkWidget *window, gpointer user_data);
static gboolean window_delete_event_cb(GtkWidget *window, GdkEvent *event, gpointer user_data);
static WindowContext *create_window_context(AppState *state,
                                            const char *title,
                                            int width,
                                            int height,
                                            GtkWindow *transient_for);
static void update_status_icon(AppState *state);
static void apply_background_mode(AppState *state, gboolean enabled, gboolean show_icon);

static const char *DESKTOP_BRIDGE_BOOTSTRAP =
    "(function () {"
    "  window.__wizardry_callbacks = window.__wizardry_callbacks || {};"
    "  function nextId() { return Math.random().toString(36).slice(2); }"
    "  function post(message) {"
    "    if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.wizardry) {"
    "      window.webkit.messageHandlers.wizardry.postMessage(message);"
    "      return true;"
    "    }"
    "    if (window.WizardryBridge && typeof window.WizardryBridge.postMessage === 'function') {"
    "      window.WizardryBridge.postMessage(JSON.stringify(message));"
    "      return true;"
    "    }"
    "    return false;"
    "  }"
    "  function execCommand(argv) {"
    "    if (!Array.isArray(argv)) {"
    "      return Promise.reject(new Error('argv must be an array'));"
    "    }"
    "    return new Promise(function (resolve) {"
    "      var id = nextId();"
    "      window.__wizardry_callbacks[id] = function (payload) {"
    "        resolve(payload || { stdout: '', stderr: '', exit_code: 0, error: null });"
    "      };"
    "      if (!post({ id: id, command: argv })) {"
    "        setTimeout(function () {"
    "          if (window.__wizardry_callbacks[id]) {"
    "            window.__wizardry_callbacks[id]({ stdout: '', stderr: 'native bridge unavailable', exit_code: 1, error: null });"
    "            delete window.__wizardry_callbacks[id];"
    "          }"
    "        }, 0);"
    "      }"
    "    });"
    "  }"
    "  function rpcBridge(method, payload) {"
    "    if (method !== 'bridge.exec') {"
    "      return Promise.reject(new Error('unsupported rpc method: ' + String(method || '')));"
    "    }"
    "    var argv = payload;"
    "    if (payload && typeof payload === 'object' && Array.isArray(payload.argv)) {"
    "      argv = payload.argv;"
    "    }"
    "    return execCommand(argv);"
    "  }"
    "  window.wizardry = window.wizardry || {};"
    "  if (typeof window.wizardry.exec !== 'function') {"
    "    window.wizardry.exec = execCommand;"
    "  }"
    "  if (typeof window.wizardry.rpc !== 'function') {"
    "    window.wizardry.rpc = rpcBridge;"
    "  }"
    "})();";

// Escape string for JSON usage in callback payloads.
static char *escape_json(const char *str) {
    if (!str) {
        return g_strdup("");
    }

    size_t len = strlen(str);
    char *escaped = g_malloc(len * 2 + 1);
    char *cursor = escaped;
    for (size_t i = 0; i < len; i++) {
        switch (str[i]) {
            case '\\':
                *cursor++ = '\\';
                *cursor++ = '\\';
                break;
            case '"':
                *cursor++ = '\\';
                *cursor++ = '"';
                break;
            case '\n':
                *cursor++ = '\\';
                *cursor++ = 'n';
                break;
            case '\r':
                *cursor++ = '\\';
                *cursor++ = 'r';
                break;
            case '\t':
                *cursor++ = '\\';
                *cursor++ = 't';
                break;
            default:
                *cursor++ = str[i];
                break;
        }
    }
    *cursor = '\0';
    return escaped;
}

static int parse_dimension_or_default(const char *raw_value, int fallback, int minimum) {
    if (!raw_value || !*raw_value) {
        return fallback;
    }
    char *end = NULL;
    long parsed = strtol(raw_value, &end, 10);
    if (end == raw_value || (end && *end != '\0')) {
        return fallback;
    }
    if (parsed < minimum) {
        return minimum;
    }
    if (parsed > 4000) {
        return 4000;
    }
    return (int)parsed;
}

static void send_result_to_web_view(WebKitWebView *web_view,
                                    const char *message_id,
                                    const char *stdout_str,
                                    const char *stderr_str,
                                    int exit_code,
                                    const char *error_str) {
    if (!web_view || !message_id || !*message_id) {
        return;
    }

    char *esc_id = escape_json(message_id);
    char *esc_stdout = escape_json(stdout_str);
    char *esc_stderr = escape_json(stderr_str);
    char *esc_error = error_str ? escape_json(error_str) : NULL;
    char *error_payload = esc_error ? g_strdup_printf("\"%s\"", esc_error) : g_strdup("null");

    char *js_code = g_strdup_printf(
        "if (window.__wizardry_callbacks && window.__wizardry_callbacks['%s']) { "
        "  window.__wizardry_callbacks['%s']({ "
        "    stdout: \"%s\", "
        "    stderr: \"%s\", "
        "    exit_code: %d, "
        "    error: %s "
        "  }); "
        "  delete window.__wizardry_callbacks['%s']; "
        "}",
        esc_id,
        esc_id,
        esc_stdout,
        esc_stderr,
        exit_code,
        error_payload,
        esc_id);

    webkit_web_view_run_javascript(web_view, js_code, NULL, NULL, NULL);

    g_free(esc_id);
    g_free(esc_stdout);
    g_free(esc_stderr);
    g_free(esc_error);
    g_free(error_payload);
    g_free(js_code);
}

static void execute_command(const char **argv,
                            int argc,
                            char **stdout_str,
                            char **stderr_str,
                            int *exit_code) {
    gchar **spawn_argv = g_new0(gchar *, (gsize)argc + 1);
    for (int i = 0; i < argc; i++) {
        spawn_argv[i] = g_strdup(argv[i]);
    }
    spawn_argv[argc] = NULL;

    gchar *captured_stdout = NULL;
    gchar *captured_stderr = NULL;
    gint status = 0;
    GError *error = NULL;
    gboolean ok = g_spawn_sync(NULL,
                               spawn_argv,
                               NULL,
                               G_SPAWN_SEARCH_PATH,
                               NULL,
                               NULL,
                               &captured_stdout,
                               &captured_stderr,
                               &status,
                               &error);

    if (!ok) {
        *stdout_str = g_strdup("");
        *stderr_str = g_strdup((error && error->message) ? error->message : "failed to launch command");
        *exit_code = 127;
    } else {
        *stdout_str = captured_stdout ? g_strdup(captured_stdout) : g_strdup("");
        *stderr_str = captured_stderr ? g_strdup(captured_stderr) : g_strdup("");
        if (WIFEXITED(status)) {
            *exit_code = WEXITSTATUS(status);
        } else {
            *exit_code = -1;
        }
    }

    if (error) {
        g_error_free(error);
    }
    g_free(captured_stdout);
    g_free(captured_stderr);
    for (int i = 0; i < argc; i++) {
        g_free(spawn_argv[i]);
    }
    g_free(spawn_argv);
}

static void free_argv(char **argv, int argc) {
    if (!argv) {
        return;
    }
    for (int i = 0; i < argc; i++) {
        g_free(argv[i]);
    }
    g_free(argv);
}

static void handle_open_window_command(WindowContext *context,
                                       const char *message_id,
                                       char **argv,
                                       int argc) {
    const char *url = (argc >= 2) ? argv[1] : "";
    if (!url || !*url) {
        send_result_to_web_view(context->web_view, message_id, "", "missing window URL", 1, NULL);
        return;
    }

    const char *fallback_title = gtk_window_get_title(GTK_WINDOW(context->window));
    const char *title = (argc >= 3 && argv[2] && argv[2][0]) ? argv[2] : fallback_title;
    int width = parse_dimension_or_default((argc >= 4) ? argv[3] : NULL, POPUP_DEFAULT_WIDTH, WINDOW_MIN_WIDTH);
    int height = parse_dimension_or_default((argc >= 5) ? argv[4] : NULL, POPUP_DEFAULT_HEIGHT, WINDOW_MIN_HEIGHT);

    WindowContext *popup = create_window_context(context->state,
                                                 title,
                                                 width,
                                                 height,
                                                 GTK_WINDOW(context->window));
    if (!popup) {
        send_result_to_web_view(context->web_view, message_id, "", "failed to create popup window", 1, NULL);
        return;
    }

    webkit_web_view_load_uri(popup->web_view, url);
    gtk_widget_show_all(popup->window);
    gtk_window_present(GTK_WINDOW(popup->window));
    send_result_to_web_view(context->web_view, message_id, "ok", "", 0, NULL);
}

static void show_main_window(AppState *state) {
    if (!state || !state->main_context || !state->main_context->window) {
        return;
    }
    gtk_widget_show_all(state->main_context->window);
    gtk_window_present(GTK_WINDOW(state->main_context->window));
    update_status_icon(state);
}

static void toggle_main_window(AppState *state) {
    if (!state || !state->main_context || !state->main_context->window) {
        return;
    }
    if (gtk_widget_get_visible(state->main_context->window)) {
        gtk_widget_hide(state->main_context->window);
    } else {
        show_main_window(state);
    }
    update_status_icon(state);
}

static void tray_activate_cb(GtkStatusIcon *status_icon, gpointer user_data) {
    (void)status_icon;
    toggle_main_window((AppState *)user_data);
}

static void tray_show_cb(GtkMenuItem *item, gpointer user_data) {
    (void)item;
    show_main_window((AppState *)user_data);
}

static void tray_hide_cb(GtkMenuItem *item, gpointer user_data) {
    (void)item;
    AppState *state = (AppState *)user_data;
    if (!state || !state->main_context || !state->main_context->window) {
        return;
    }
    gtk_widget_hide(state->main_context->window);
    update_status_icon(state);
}

static void tray_quit_cb(GtkMenuItem *item, gpointer user_data) {
    (void)item;
    (void)user_data;
    gtk_main_quit();
}

static void tray_popup_menu_cb(GtkStatusIcon *status_icon,
                               guint button,
                               guint activate_time,
                               gpointer user_data) {
    (void)status_icon;
    AppState *state = (AppState *)user_data;
    gboolean visible = state && state->main_context && state->main_context->window &&
                       gtk_widget_get_visible(state->main_context->window);
    GtkWidget *menu = gtk_menu_new();
    GtkWidget *toggle_item = gtk_menu_item_new_with_label(visible ? "Hide Window" : "Show Window");
    g_signal_connect(toggle_item, "activate", G_CALLBACK(visible ? tray_hide_cb : tray_show_cb), state);
    gtk_menu_shell_append(GTK_MENU_SHELL(menu), toggle_item);
    gtk_menu_shell_append(GTK_MENU_SHELL(menu), gtk_separator_menu_item_new());
    GtkWidget *quit_item = gtk_menu_item_new_with_label("Quit");
    g_signal_connect(quit_item, "activate", G_CALLBACK(tray_quit_cb), state);
    gtk_menu_shell_append(GTK_MENU_SHELL(menu), quit_item);
    gtk_widget_show_all(menu);
    gtk_menu_popup(GTK_MENU(menu), NULL, NULL, gtk_status_icon_position_menu, status_icon, button, activate_time);
}

static void update_status_icon(AppState *state) {
    if (!state) {
        return;
    }
    gboolean wants_icon = state->keep_running_in_background && state->show_status_icon;
    if (!wants_icon) {
        if (state->status_icon) {
            gtk_status_icon_set_visible(state->status_icon, FALSE);
            g_object_unref(state->status_icon);
            state->status_icon = NULL;
        }
        return;
    }
    if (!state->status_icon) {
        state->status_icon = gtk_status_icon_new_from_icon_name("network-server");
        g_signal_connect(state->status_icon, "activate", G_CALLBACK(tray_activate_cb), state);
        g_signal_connect(state->status_icon, "popup-menu", G_CALLBACK(tray_popup_menu_cb), state);
    }
    gtk_status_icon_set_visible(state->status_icon, TRUE);
    gtk_status_icon_set_tooltip_text(state->status_icon, state->app_name ? state->app_name : "Wizardry");
}

static void apply_background_mode(AppState *state, gboolean enabled, gboolean show_icon) {
    if (!state) {
        return;
    }
    state->keep_running_in_background = enabled;
    state->show_status_icon = enabled && show_icon;
    update_status_icon(state);
}

static void message_received_cb(WebKitUserContentManager *manager,
                                WebKitJavascriptResult *js_result,
                                gpointer user_data) {
    (void)manager;
    WindowContext *context = (WindowContext *)user_data;
    if (!context || !context->web_view) {
        return;
    }

    JSCValue *value = webkit_javascript_result_get_js_value(js_result);
    if (!jsc_value_is_object(value)) {
        g_warning("wizardry bridge message is not an object");
        return;
    }

    JSCValue *id_val = jsc_value_object_get_property(value, "id");
    JSCValue *cmd_val = jsc_value_object_get_property(value, "command");
    if (!jsc_value_is_string(id_val) || !jsc_value_is_array(cmd_val)) {
        g_warning("wizardry bridge message has invalid shape");
        g_object_unref(id_val);
        g_object_unref(cmd_val);
        return;
    }

    char *msg_id = jsc_value_to_string(id_val);
    JSCValue *length_val = jsc_value_object_get_property(cmd_val, "length");
    int cmd_len = jsc_value_to_int32(length_val);
    g_object_unref(length_val);

    if (cmd_len <= 0) {
        send_result_to_web_view(context->web_view, msg_id, "", "command array is empty", 1, NULL);
        g_free(msg_id);
        g_object_unref(id_val);
        g_object_unref(cmd_val);
        return;
    }

    char **argv = g_new0(char *, (gsize)cmd_len + 1);
    for (int i = 0; i < cmd_len; i++) {
        char index_key[16];
        snprintf(index_key, sizeof(index_key), "%d", i);
        JSCValue *elem = jsc_value_object_get_property(cmd_val, index_key);
        argv[i] = jsc_value_to_string(elem);
        g_object_unref(elem);
    }
    argv[cmd_len] = NULL;

    if (strcmp(argv[0], "__wizardry_host_open_window") == 0) {
        handle_open_window_command(context, msg_id, argv, cmd_len);
    } else if (strcmp(argv[0], "__wizardry_host_set_background_mode") == 0) {
        gboolean enabled = FALSE;
        gboolean show_icon = FALSE;
        if (cmd_len >= 2 && argv[1]) {
            enabled = g_ascii_strcasecmp(argv[1], "1") == 0 ||
                      g_ascii_strcasecmp(argv[1], "true") == 0 ||
                      g_ascii_strcasecmp(argv[1], "yes") == 0 ||
                      g_ascii_strcasecmp(argv[1], "on") == 0;
        }
        if (cmd_len >= 3 && argv[2]) {
            show_icon = g_ascii_strcasecmp(argv[2], "1") == 0 ||
                        g_ascii_strcasecmp(argv[2], "true") == 0 ||
                        g_ascii_strcasecmp(argv[2], "yes") == 0 ||
                        g_ascii_strcasecmp(argv[2], "on") == 0;
        }
        apply_background_mode(context->state, enabled, show_icon);
        send_result_to_web_view(context->web_view, msg_id, "", "", 0, NULL);
    } else {
        char *stdout_str = NULL;
        char *stderr_str = NULL;
        int exit_code = 0;
        execute_command((const char **)argv, cmd_len, &stdout_str, &stderr_str, &exit_code);
        send_result_to_web_view(context->web_view, msg_id, stdout_str, stderr_str, exit_code, NULL);
        g_free(stdout_str);
        g_free(stderr_str);
    }

    free_argv(argv, cmd_len);
    g_free(msg_id);
    g_object_unref(id_val);
    g_object_unref(cmd_val);
}

static WebKitWebView *web_view_create_cb(WebKitWebView *web_view,
                                         WebKitNavigationAction *navigation_action,
                                         gpointer user_data) {
    (void)web_view;
    (void)navigation_action;
    WindowContext *source = (WindowContext *)user_data;
    if (!source || !source->state) {
        return NULL;
    }

    const char *source_title = gtk_window_get_title(GTK_WINDOW(source->window));
    WindowContext *popup = create_window_context(source->state,
                                                 source_title,
                                                 POPUP_DEFAULT_WIDTH,
                                                 POPUP_DEFAULT_HEIGHT,
                                                 GTK_WINDOW(source->window));
    if (!popup) {
        return NULL;
    }

    gtk_widget_show_all(popup->window);
    gtk_window_present(GTK_WINDOW(popup->window));
    return popup->web_view;
}

static void window_destroy_cb(GtkWidget *window, gpointer user_data) {
    WindowContext *context = (WindowContext *)user_data;
    if (!context || !context->state) {
        g_free(context);
        return;
    }

    if (context->state->main_context == context) {
        context->state->main_context = NULL;
    }
    context->state->windows = g_list_remove(context->state->windows, window);
    if (context->state->windows == NULL) {
        gtk_main_quit();
    }
    g_free(context);
}

static gboolean window_delete_event_cb(GtkWidget *window, GdkEvent *event, gpointer user_data) {
    (void)event;
    WindowContext *context = (WindowContext *)user_data;
    if (!context || !context->state) {
        return FALSE;
    }
    if (context == context->state->main_context && context->state->keep_running_in_background) {
        gtk_widget_hide(window);
        update_status_icon(context->state);
        return TRUE;
    }
    return FALSE;
}

static WindowContext *create_window_context(AppState *state,
                                            const char *title,
                                            int width,
                                            int height,
                                            GtkWindow *transient_for) {
    if (!state) {
        return NULL;
    }

    WindowContext *context = g_new0(WindowContext, 1);
    context->state = state;

    GtkWidget *window = gtk_window_new(GTK_WINDOW_TOPLEVEL);
    context->window = window;
    gtk_window_set_title(GTK_WINDOW(window), (title && *title) ? title : "Wizardry");
    gtk_window_set_default_size(GTK_WINDOW(window),
                                width > WINDOW_MIN_WIDTH ? width : WINDOW_MIN_WIDTH,
                                height > WINDOW_MIN_HEIGHT ? height : WINDOW_MIN_HEIGHT);
    gtk_widget_set_size_request(window, WINDOW_MIN_WIDTH, WINDOW_MIN_HEIGHT);
    if (transient_for) {
        gtk_window_set_transient_for(GTK_WINDOW(window), transient_for);
    } else {
        gtk_window_set_position(GTK_WINDOW(window), GTK_WIN_POS_CENTER);
    }

    g_signal_connect(window, "delete-event", G_CALLBACK(window_delete_event_cb), context);
    g_signal_connect(window, "destroy", G_CALLBACK(window_destroy_cb), context);

    WebKitUserContentManager *content_manager = webkit_user_content_manager_new();
    if (!webkit_user_content_manager_register_script_message_handler(content_manager, "wizardry")) {
        g_warning("failed to register wizardry script message handler");
    }

    WebKitUserScript *bridge_bootstrap = webkit_user_script_new(
        DESKTOP_BRIDGE_BOOTSTRAP,
        WEBKIT_USER_CONTENT_INJECT_TOP_FRAME,
        WEBKIT_USER_SCRIPT_INJECT_AT_DOCUMENT_START,
        NULL,
        NULL);
    webkit_user_content_manager_add_script(content_manager, bridge_bootstrap);
    webkit_user_script_unref(bridge_bootstrap);
    g_signal_connect(content_manager,
                     "script-message-received::wizardry",
                     G_CALLBACK(message_received_cb),
                     context);

    context->web_view = WEBKIT_WEB_VIEW(webkit_web_view_new_with_user_content_manager(content_manager));
    g_object_unref(content_manager);

    if (!context->web_view) {
        gtk_widget_destroy(window);
        return NULL;
    }

    WebKitSettings *settings = webkit_web_view_get_settings(context->web_view);
    if (settings) {
        g_object_set(G_OBJECT(settings), "javascript-can-open-windows-automatically", TRUE, NULL);
    }

    g_signal_connect(context->web_view, "create", G_CALLBACK(web_view_create_cb), context);
    gtk_container_add(GTK_CONTAINER(window), GTK_WIDGET(context->web_view));
    state->windows = g_list_prepend(state->windows, window);
    if (!transient_for) {
        state->main_context = context;
    }
    return context;
}

int main(int argc, char *argv[]) {
    if (argc < 2) {
        fprintf(stderr, "Usage: %s <app-directory>\n", argv[0]);
        return 1;
    }

    const char *app_path = argv[1];
    char *index_path = g_build_filename(app_path, "index.html", NULL);
    if (access(index_path, F_OK) != 0) {
        fprintf(stderr, "Error: index.html not found at %s\n", index_path);
        g_free(index_path);
        return 1;
    }

    const char *leaf = strrchr(app_path, '/');
    const char *app_slug = leaf ? (leaf + 1) : app_path;
    char *window_title = g_strdup_printf("Wizardry - %s", app_slug);

    GError *uri_error = NULL;
    char *index_uri = g_filename_to_uri(index_path, NULL, &uri_error);
    if (!index_uri) {
        fprintf(stderr, "Error: failed to resolve app URI: %s\n",
                (uri_error && uri_error->message) ? uri_error->message : "unknown error");
        if (uri_error) {
            g_error_free(uri_error);
        }
        g_free(index_path);
        g_free(window_title);
        return 1;
    }

    gtk_init(&argc, &argv);

    AppState state = {0};
    state.app_path = g_strdup(app_path);
    state.app_name = window_title;
    state.index_uri = index_uri;
    state.windows = NULL;

    WindowContext *main_context = create_window_context(&state,
                                                        state.app_name,
                                                        MAIN_DEFAULT_WIDTH,
                                                        MAIN_DEFAULT_HEIGHT,
                                                        NULL);
    if (!main_context) {
        fprintf(stderr, "Error: failed to create main window\n");
        g_free(state.index_uri);
        g_free(state.app_name);
        g_free(state.app_path);
        g_free(index_path);
        return 1;
    }

    webkit_web_view_load_uri(main_context->web_view, state.index_uri);
    gtk_widget_show_all(main_context->window);
    gtk_window_present(GTK_WINDOW(main_context->window));
    gtk_main();

    g_free(state.index_uri);
    g_free(state.app_name);
    g_free(state.app_path);
    g_free(index_path);
    return 0;
}
