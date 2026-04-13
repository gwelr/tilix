/*
 * This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not
 * distributed with this file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */
module gx.tilix.terminal.types;

import gdk.Event;
import gx.tilix.preferences;

/************************************************************************
 * Public types — used by session.d and other packages
 ***********************************************************************/
public:

/// When dragging over VTE, specifies which quadrant new terminal should snap to.
enum DragQuadrant {
    LEFT,
    TOP,
    RIGHT,
    BOTTOM
}

/// The window state of the terminal.
enum TerminalWindowState {
    NORMAL,
    MAXIMIZED
}

/// Type of synchronized input event between terminals.
enum SyncInputEventType {
    INSERT_TERMINAL_NUMBER,
    INSERT_TEXT,
    KEY_PRESS,
    RESET,
    RESET_AND_CLEAR
}

/// Payload for synchronized input events between terminals.
struct SyncInputEvent {
    /// UUID of the terminal that originated this event.
    string senderUUID;
    /// The type of synchronization event.
    SyncInputEventType eventType;
    /// Raw keyboard event, set for KEY_PRESS events, null otherwise.
    Event event;
    /// Text content to insert, set for INSERT_TEXT events (paste, password, typed input), null otherwise.
    string text;
}

/************************************************************************
 * Package-private types — used only within the terminal package
 ***********************************************************************/
package:

/// Constants used in Event.key.sendEvent to flag particular situations.
enum SendEvent {
    NONE = 0,
    SYNC = 1,
    NATURAL_COPY = 2
}

/// Constant used to identify terminal drag and drop.
enum VTE_DND = "vte";

/// List of available Drop Targets for VTE.
enum DropTargets {
    URILIST,
    STRING,
    UTF8_TEXT,
    TEXT,
    COLOR,
    /// Used when one VTE is dropped on another.
    VTE,
    /// Used when session is dropped on terminal.
    SESSION
}

/// Tracks active drag state within a terminal.
struct DragInfo {
    /// Whether a drag operation is currently in progress.
    bool isDragActive;
    /// The quadrant where the drop would occur.
    DragQuadrant dq;
}

/// Actions that can be triggered by terminal regex triggers.
enum TriggerAction {
    UPDATE_STATE,
    EXECUTE_COMMAND,
    SEND_NOTIFICATION,
    UPDATE_TITLE,
    PLAY_BELL,
    SEND_TEXT,
    INSERT_PASSWORD,
    UPDATE_BADGE,
    RUN_PROCESS
}

private:

import std.regex;

package:

/// Holds definition of a trigger including its compiled regex.
class TerminalTrigger {
    /// The regex pattern string as defined by the user.
    string pattern;
    /// The action to perform when the trigger matches.
    TriggerAction action;
    /// Action-specific parameters (e.g. command to execute, text to send).
    string parameters;
    /// Compiled regex for matching against VTE buffer content.
    Regex!char compiledRegex;

    this(string pattern, string actionName, string parameters) {
        this.pattern = pattern;
        this.parameters = parameters;
        switch (actionName) {
            case SETTINGS_PROFILE_TRIGGER_UPDATE_STATE_VALUE:
                action = TriggerAction.UPDATE_STATE;
                break;
            case SETTINGS_PROFILE_TRIGGER_EXECUTE_COMMAND_VALUE:
                action = TriggerAction.EXECUTE_COMMAND;
                break;
            case SETTINGS_PROFILE_TRIGGER_SEND_NOTIFICATION_VALUE:
                action = TriggerAction.SEND_NOTIFICATION;
                break;
            case SETTINGS_PROFILE_TRIGGER_UPDATE_BADGE_VALUE:
                action = TriggerAction.UPDATE_BADGE;
                break;
            case SETTINGS_PROFILE_TRIGGER_UPDATE_TITLE_VALUE:
                action = TriggerAction.UPDATE_TITLE;
                break;
            case SETTINGS_PROFILE_TRIGGER_PLAY_BELL_VALUE:
                action = TriggerAction.PLAY_BELL;
                break;
            case SETTINGS_PROFILE_TRIGGER_SEND_TEXT_VALUE:
                action = TriggerAction.SEND_TEXT;
                break;
            case SETTINGS_PROFILE_TRIGGER_INSERT_PASSWORD_VALUE:
                action = TriggerAction.INSERT_PASSWORD;
                break;
            case SETTINGS_PROFILE_TRIGGER_RUN_PROCESS_VALUE:
                action = TriggerAction.RUN_PROCESS;
                break;
            default:
                break;
        }

        // Triggers always use multi-line mode since we are getting a buffer from VTE
        compiledRegex = regex(pattern, "m");
    }
}

/// Match result from a terminal trigger.
struct TerminalTriggerMatch {
    /// The trigger that matched.
    TerminalTrigger trigger;
    /// Captured regex groups from the match.
    string[] groups;
    /// Position of the match within the buffer.
    size_t index;
}

/// Terminal serialization node keys.
enum NODE_OVERRIDE_CMD = "overrideCommand";
enum NODE_BADGE = "badge";
enum NODE_TITLE = "title";
enum NODE_READONLY = "readOnly";
enum NODE_SYNCHRONIZED_INPUT = "synchronizedInput";

// ---------------------------------------------------------------------------
// Unit tests for TerminalTrigger
// ---------------------------------------------------------------------------

/// Test: TerminalTrigger maps action name to TriggerAction enum.
unittest {
    auto t = new TerminalTrigger("test", SETTINGS_PROFILE_TRIGGER_UPDATE_STATE_VALUE, "params");
    assert(t.action == TriggerAction.UPDATE_STATE);
    assert(t.pattern == "test");
    assert(t.parameters == "params");
}

/// Test: TerminalTrigger compiles regex in multiline mode.
unittest {
    auto t = new TerminalTrigger("^hello", SETTINGS_PROFILE_TRIGGER_SEND_TEXT_VALUE, "");
    assert(t.action == TriggerAction.SEND_TEXT);
    // Regex should match at start of any line (multiline mode)
    auto m = matchFirst("world\nhello there", t.compiledRegex);
    assert(!m.empty, "should match 'hello' at start of second line");
}

/// Test: TerminalTrigger with execute command action.
unittest {
    auto t = new TerminalTrigger("error: (.*)", SETTINGS_PROFILE_TRIGGER_EXECUTE_COMMAND_VALUE, "/usr/bin/notify");
    assert(t.action == TriggerAction.EXECUTE_COMMAND);
    auto m = matchFirst("error: disk full", t.compiledRegex);
    assert(!m.empty);
    assert(m[1] == "disk full");
}

/// Test: TerminalTrigger with unknown action name defaults (no crash).
unittest {
    auto t = new TerminalTrigger("test", "nonexistent-action", "");
    // Should not crash, action stays at default init value
}

/// Test: DragInfo initializes correctly.
unittest {
    auto di = DragInfo(true, DragQuadrant.RIGHT);
    assert(di.isDragActive);
    assert(di.dq == DragQuadrant.RIGHT);
}

/// Test: DragInfo default state.
unittest {
    DragInfo di;
    assert(!di.isDragActive);
}

/// Test: SyncInputEvent fields.
unittest {
    auto se = SyncInputEvent("uuid-123", SyncInputEventType.INSERT_TEXT, null, "hello");
    assert(se.senderUUID == "uuid-123");
    assert(se.eventType == SyncInputEventType.INSERT_TEXT);
    assert(se.text == "hello");
    assert(se.event is null);
}
