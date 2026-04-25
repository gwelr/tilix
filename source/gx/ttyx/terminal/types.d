/*
 * This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not
 * distributed with this file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */
module gx.ttyx.terminal.types;

import std.sumtype;

import gdk.Event;
import gx.ttyx.preferences;

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

/**
 * Synchronized-input event payloads. Each variant carries exactly the
 * fields it needs — the type itself is the discriminator, so it is
 * impossible at compile time to construct a key-press event without an
 * `Event` or a text event without a `text` payload.
 *
 * Producers construct a variant directly: `SyncTextEvent(uuid, text)`.
 * Consumers dispatch via `event.match!((SyncTextEvent e) {...}, ...)`.
 *
 * Construction invariants are enforced by the `in` contracts on each
 * variant's constructor: senderUUID must be non-empty; payload-bearing
 * variants reject null payloads.
 */

/// Sent when a key press should be replayed in a synchronized terminal.
struct SyncKeyPressEvent {
    string senderUUID;
    Event event;

    this(string senderUUID, Event event)
    in {
        assert(senderUUID !is null && senderUUID.length > 0);
        assert(event !is null);
    }
    do {
        this.senderUUID = senderUUID;
        this.event = event;
    }
}

/// Sent when text (paste, password, typed input) should be inserted in a
/// synchronized terminal.
struct SyncTextEvent {
    string senderUUID;
    string text;

    this(string senderUUID, string text)
    in {
        assert(senderUUID !is null && senderUUID.length > 0);
        assert(text !is null);
    }
    do {
        this.senderUUID = senderUUID;
        this.text = text;
    }
}

/// Sent when the receiving terminal should insert its own terminal number.
/// No payload — the receiver substitutes its local terminal ID.
struct SyncInsertTerminalNumberEvent {
    string senderUUID;

    this(string senderUUID)
    in { assert(senderUUID !is null && senderUUID.length > 0); }
    do { this.senderUUID = senderUUID; }
}

/// Sent when the receiving terminal should perform a soft reset.
struct SyncResetEvent {
    string senderUUID;

    this(string senderUUID)
    in { assert(senderUUID !is null && senderUUID.length > 0); }
    do { this.senderUUID = senderUUID; }
}

/// Sent when the receiving terminal should perform a reset and clear scrollback.
struct SyncResetAndClearEvent {
    string senderUUID;

    this(string senderUUID)
    in { assert(senderUUID !is null && senderUUID.length > 0); }
    do { this.senderUUID = senderUUID; }
}

/**
 * Tagged union of synchronized-input events. Replaces the previous
 * struct that carried all possible payloads with nullable fields and
 * an explicit `eventType` discriminator.
 */
alias SyncInputEvent = SumType!(
    SyncKeyPressEvent,
    SyncTextEvent,
    SyncInsertTerminalNumberEvent,
    SyncResetEvent,
    SyncResetAndClearEvent
);

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

/// Test: each SyncInputEvent variant carries the right fields.
unittest {
    SyncTextEvent t = SyncTextEvent("uuid-123", "hello");
    assert(t.senderUUID == "uuid-123");
    assert(t.text == "hello");

    SyncInsertTerminalNumberEvent n = SyncInsertTerminalNumberEvent("uuid-456");
    assert(n.senderUUID == "uuid-456");

    SyncResetEvent r = SyncResetEvent("uuid-789");
    assert(r.senderUUID == "uuid-789");

    SyncResetAndClearEvent rc = SyncResetAndClearEvent("uuid-abc");
    assert(rc.senderUUID == "uuid-abc");
}

/// Test: SumType wrapper accepts any variant by implicit construction
/// and dispatches via match!.
unittest {
    SyncInputEvent se = SyncTextEvent("uuid-1", "payload");
    string captured;
    se.match!(
        (SyncTextEvent e) { captured = "text:" ~ e.text; },
        (SyncInsertTerminalNumberEvent e) { captured = "num"; },
        (SyncKeyPressEvent e) { captured = "key"; },
        (SyncResetEvent e) { captured = "reset"; },
        (SyncResetAndClearEvent e) { captured = "rac"; }
    );
    assert(captured == "text:payload");
}

/// Test: SyncTextEvent rejects null text via the in-contract.
unittest {
    import core.exception : AssertError;
    bool threw = false;
    try {
        SyncTextEvent t = SyncTextEvent("uuid-1", null);
    } catch (AssertError) {
        threw = true;
    }
    assert(threw, "construction with null text should fail the in-contract");
}

/// Test: senderUUID must be non-empty across all variants.
unittest {
    import core.exception : AssertError;
    bool threw = false;
    try {
        SyncResetEvent r = SyncResetEvent("");
    } catch (AssertError) {
        threw = true;
    }
    assert(threw, "construction with empty senderUUID should fail the in-contract");
}
