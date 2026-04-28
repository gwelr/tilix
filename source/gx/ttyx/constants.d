/*
 * This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not
 * distributed with this file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */
module gx.ttyx.constants;

import std.path;

import gx.i18n.l10n;

/****************************************************************
 * Compilation Flags, these are used to test various things or
 * to turn off work that is in process
 ****************************************************************/

/**
 * Whether to use a pixbuf for drag and Drop image
 */
immutable bool USE_PIXBUF_DND = false;

/**
 * Renders clipboard options as buttons in context menu
 */
immutable bool CLIPBOARD_BTN_IN_CONTEXT = false;

/**
 * All logs go to the file /tmp/ttyx.log, useful
 * when debugging launchers or other spots where
 * stdout isn't easily viewed.
 */
immutable bool USE_FILE_LOGGING = false;

/**
 * Determines whether synchronization of multiple terminals
 * is driven off of the commit event or by keystrokes. The commit
 * event allows for IME to work but causes some issues with
 * certain programs like VIM. See #888
 */
immutable bool USE_COMMIT_SYNCHRONIZATION = false;

/**************************************
 * Application Constants
 **************************************/

// GTK Version required
enum GTK_VERSION_MAJOR = 3;
enum GTK_VERSION_MINOR = 18;
enum GTK_VERSION_PATCH = 0;

// GTK version required for scrolledwindow
enum GTK_SCROLLEDWINDOW_VERSION = 22;

// GetText Domain
enum TTYX_DOMAIN = "ttyx";

/**
 * Application ID
 */
enum APPLICATION_ID = "io.github.gwelr.ttyx";

// Application values used in About Dialog
enum APPLICATION_NAME = "ttyx_";
enum APPLICATION_VERSION = "1.1.2";
enum APPLICATION_AUTHOR = "gwelr";
enum APPLICATION_COPYRIGHT = "Copyright \xc2\xa9 2026 " ~ APPLICATION_AUTHOR;
enum APPLICATION_COMMENTS = N_("A tiling terminal emulator for Linux, forked from Tilix");
enum APPLICATION_LICENSE = N_("This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not distributed with this file, You can obtain one at http://mozilla.org/MPL/2.0/.");
enum APPLICATION_ICON_NAME = "io.github.gwelr.ttyx";

immutable string[] APPLICATION_AUTHORS = [APPLICATION_AUTHOR];
string[] APPLICATION_CREDITS = [
    N_("Gerald Nunn and the Tilix contributors, whose work ttyx_ is built upon"),
    N_("GTK VTE widget team, ttyx_ would not be possible without their work"),
    N_("GtkD for providing such an excellent GTK wrapper"),
    N_("Dlang.org for such an excellent language, D")
];
immutable string[] APPLICATION_ARTISTS = [];
immutable string[] APPLICATION_DOCUMENTERS = [];

//GTK Settings
enum GTK_APP_PREFER_DARK_THEME = "gtk-application-prefer-dark-theme";
enum GTK_MENU_BAR_ACCEL = "gtk-menu-bar-accel";
enum GTK_ENABLE_ACCELS = "gtk-enable-accels";
enum GTK_DECORATION_LAYOUT = "gtk_decoration_layout";
enum GTK_SHELL_SHOWS_APP_MENU = "gtk-shell-shows-app-menu";
enum GTK_DOUBLE_CLICK_TIME = "gtk-double-click-time";

//Action Prefixes
enum ACTION_PREFIX_WIN = "win";
enum ACTION_PREFIX_APP = "app";
enum ACTION_PREFIX_SESSION = "session";
enum ACTION_PREFIX_TERMINAL = "terminal";
enum ACTION_PREFIX_NAUTILUS = "nautilus";

//Actions that need to be referenced globally
enum ACTION_PROFILE_SELECT = "profile-select";

enum ACTION_PREFERENCES = "preferences";
enum ACTION_ABOUT = "about";
enum ACTION_SHORTCUTS = "shortcuts";
enum ACTION_NEW_WINDOW = "new-window";

//Config Folder
enum APPLICATION_CONFIG_FOLDER = "ttyx";

//RESOURCES
enum APPLICATION_RESOURCES = buildPath(APPLICATION_CONFIG_FOLDER, "resources/ttyx.gresource");
enum APPLICATION_RESOURCE_ROOT = "/io/github/gwelr/ttyx";
immutable string[] APPLICATION_CSS_RESOURCES = ["css/ttyx.base.css","css/ttyx.base320.css"];
immutable string[] THEME_CSS_RESOURCES = ["css/ttyx.base.theme.css"];

immutable string SHORTCUT_UI_RESOURCE = APPLICATION_RESOURCE_ROOT ~ "/ui/shortcuts.ui";
immutable string SHORTCUT_LOCALIZATION_CONTEXT = "shortcut window";

// Constants used for the various variables permitted when defining
// the terminal title.
enum VARIABLE_TERMINAL_TITLE = "${title}";
enum VARIABLE_TERMINAL_ICON_TITLE = "${iconTitle}";
enum VARIABLE_TERMINAL_ID = "${id}";
enum VARIABLE_TERMINAL_DIR = "${directory}";
enum VARIABLE_TERMINAL_COLUMNS = "${columns}";
enum VARIABLE_TERMINAL_ROWS = "${rows}";
enum VARIABLE_TERMINAL_HOSTNAME = "${hostname}";
enum VARIABLE_TERMINAL_USERNAME = "${username}";
enum VARIABLE_TERMINAL_PROCESS = "${process}";
enum VARIABLE_TERMINAL_STATUS_READONLY = "${status.readonly}";
enum VARIABLE_TERMINAL_STATUS_SILENCE = "${status.silence}";
enum VARIABLE_TERMINAL_STATUS_INPUT_SYNC = "${status.input-sync}";


immutable string[] VARIABLE_TERMINAL_VALUES = [
    VARIABLE_TERMINAL_TITLE,
    VARIABLE_TERMINAL_ICON_TITLE ,
    VARIABLE_TERMINAL_ID,
    VARIABLE_TERMINAL_DIR,
    VARIABLE_TERMINAL_HOSTNAME,
    VARIABLE_TERMINAL_USERNAME,
    VARIABLE_TERMINAL_COLUMNS,
    VARIABLE_TERMINAL_ROWS,
    VARIABLE_TERMINAL_PROCESS,
    VARIABLE_TERMINAL_STATUS_READONLY,
    VARIABLE_TERMINAL_STATUS_SILENCE,
    VARIABLE_TERMINAL_STATUS_INPUT_SYNC
];

immutable string[] VARIABLE_TERMINAL_LOCALIZED = [
    N_("Title"),
    N_("Icon title"),
    N_("ID"),
    N_("Directory"),
    N_("Hostname"),
    N_("Username"),
    N_("Columns"),
    N_("Rows"),
    N_("Process"),
    N_("Status.Read-Only"),
    N_("Status.Silence"),
    N_("Status.Input-Sync")
];

// Session Title tokens
enum VARIABLE_TERMINAL_COUNT = "${terminalCount}";
enum VARIABLE_TERMINAL_NUMBER = "${terminalNumber}";
enum VARIABLE_ACTIVE_TERMINAL_TITLE = "${activeTerminalTitle}";

immutable string[] VARIABLE_SESSION_VALUES = [
    VARIABLE_TERMINAL_COUNT,
    VARIABLE_TERMINAL_NUMBER,
    VARIABLE_ACTIVE_TERMINAL_TITLE
];

immutable string[] VARIABLE_SESSION_LOCALIZED = [
    N_("Terminal count"),
    N_("Terminal number"),
    N_("Active terminal title")
];

// Application Window Title tokens
enum VARIABLE_APP_NAME = "${appName}";
enum VARIABLE_SESSION_NAME = "${sessionName}";
enum VARIABLE_SESSION_NUMBER = "${sessionNumber}";
enum VARIABLE_SESSION_COUNT = "${sessionCount}";

immutable string[] VARIABLE_WINDOW_VALUES = [
    VARIABLE_APP_NAME,
    VARIABLE_SESSION_NAME,
    VARIABLE_SESSION_NUMBER,
    VARIABLE_SESSION_COUNT
];

immutable string[] VARIABLE_WINDOW_LOCALIZED = [
    N_("Application name"),
    N_("Session name"),
    N_("Session number"),
    N_("Session count")
];
