/*
 * This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not
 * distributed with this file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */
module gx.ttyx.terminal.types;

import std.json;
import std.sumtype;
import std.typecons : Nullable, nullable;

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

/// Terminal serialization node keys — single source of truth for the
/// on-disk JSON schema. Used by both TerminalSnapshot.toJSON/fromJSON
/// and (where they are session-level) by session.d.
enum NODE_PROFILE = "profile";
enum NODE_DIRECTORY = "directory";
enum NODE_UUID = "uuid";
enum NODE_MAXIMIZED = "maximized";
enum NODE_TITLE = "title";
enum NODE_BADGE = "badge";
enum NODE_OVERRIDE_CMD = "overrideCommand";
enum NODE_READONLY = "readOnly";
enum NODE_SYNCHRONIZED_INPUT = "synchronizedInput";

/**
 * Typed serialization of a Terminal for session persistence.
 *
 * Replaces the previous ad-hoc JSON building scattered between
 * session.d (which wrote profile/directory/uuid/maximized) and
 * terminal.d (which wrote title/badge/command/readOnly/syncInput).
 * Adding a field now requires a single struct change instead of
 * coordinated edits in two files.
 *
 * **Authority for `maximized`**: this is session-level state — the
 * Terminal does not know whether it is the maximized one. The session
 * populates `snapshot.maximized` before serialising and reads it back
 * from the deserialised snapshot itself. `Terminal.snapshot()` does
 * not set it; `Terminal.restore()` does not consume it.
 *
 * **Wire format**: matches what session.d + terminal.d wrote pre-refactor,
 * verified by the golden roundtrip unittest below. Per-terminal
 * `width`/`height` writes (which were never read on the per-terminal
 * deserialisation path) are dropped — older readers ignored them, new
 * writers no longer emit them.
 *
 * **Optional fields**: `overrideTitle`, `overrideBadge`, `overrideCommand`
 * are `Nullable!string`. `isNull` means "no override set"; this replaces
 * the previous empty-string sentinel where empty meant absent. `readOnly`
 * and `synchronizedInput` are plain `bool` — the wire format always
 * carries them.
 *
 * **Lenient deserialization**: missing keys produce default-initialised
 * fields (Nullable.init = null, bool init = false). Unknown keys are
 * ignored — keeps backwards/forwards compatibility across schema drift.
 */
struct TerminalSnapshot {
    string profileUUID;
    string directory;
    string uuid;

    /// Session-level state — populated by session.d before serialising,
    /// read back by session.d after deserialising. Not set by Terminal.snapshot,
    /// not consumed by Terminal.restore.
    bool maximized;

    /// Override title, null when no override is set.
    Nullable!string overrideTitle;
    /// Override badge text, null when no override is set.
    Nullable!string overrideBadge;
    /// Override exec command, null when no override is set.
    Nullable!string overrideCommand;

    /// True when input is disabled (terminal is read-only).
    bool readOnly;
    /// Per-terminal override flag for synchronized-input behaviour.
    bool synchronizedInput;

    /// Build a JSON object representing this snapshot. Wire format
    /// matches what session.d + terminal.d wrote pre-refactor.
    JSONValue toJSON() const {
        JSONValue v;
        v[NODE_PROFILE] = JSONValue(profileUUID);
        v[NODE_DIRECTORY] = JSONValue(directory);
        v[NODE_UUID] = JSONValue(uuid);
        if (maximized) v[NODE_MAXIMIZED] = JSONValue(true);
        if (!overrideTitle.isNull) v[NODE_TITLE] = JSONValue(overrideTitle.get);
        if (!overrideBadge.isNull) v[NODE_BADGE] = JSONValue(overrideBadge.get);
        if (!overrideCommand.isNull) v[NODE_OVERRIDE_CMD] = JSONValue(overrideCommand.get);
        v[NODE_READONLY] = JSONValue(readOnly);
        v[NODE_SYNCHRONIZED_INPUT] = JSONValue(synchronizedInput);
        return v;
    }

    /// Parse a JSON object into a snapshot. Lenient: missing keys
    /// produce default-initialised fields, unknown keys are ignored.
    static TerminalSnapshot fromJSON(JSONValue v) {
        TerminalSnapshot s;
        if (NODE_PROFILE in v) s.profileUUID = v[NODE_PROFILE].str();
        if (NODE_DIRECTORY in v) s.directory = v[NODE_DIRECTORY].str();
        if (NODE_UUID in v) s.uuid = v[NODE_UUID].str();
        if (NODE_MAXIMIZED in v && v[NODE_MAXIMIZED].type == JSONType.true_) s.maximized = true;
        if (NODE_TITLE in v) s.overrideTitle = v[NODE_TITLE].str().nullable;
        if (NODE_BADGE in v) s.overrideBadge = v[NODE_BADGE].str().nullable;
        if (NODE_OVERRIDE_CMD in v) s.overrideCommand = v[NODE_OVERRIDE_CMD].str().nullable;
        if (NODE_READONLY in v) s.readOnly = (v[NODE_READONLY].type == JSONType.true_);
        if (NODE_SYNCHRONIZED_INPUT in v) s.synchronizedInput = (v[NODE_SYNCHRONIZED_INPUT].type == JSONType.true_);
        return s;
    }
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

// ---------------------------------------------------------------------------
// Unit tests for TerminalSnapshot
// ---------------------------------------------------------------------------

/// Test: golden roundtrip — JSON shape produced by ttyx 1.1.x must
/// deserialize cleanly and serialize back to an equivalent shape.
unittest {
    // Hand-crafted JSON, NOT generated by toJSON, so this verifies
    // wire compatibility with what previous versions actually wrote.
    enum string golden = `{
        "profile": "abc-123-prof",
        "directory": "/home/user/work",
        "uuid": "term-uuid-1",
        "title": "custom title",
        "badge": "build",
        "overrideCommand": "ssh host",
        "readOnly": false,
        "synchronizedInput": false
    }`;
    JSONValue parsed = parseJSON(golden);
    TerminalSnapshot s = TerminalSnapshot.fromJSON(parsed);
    assert(s.profileUUID == "abc-123-prof");
    assert(s.directory == "/home/user/work");
    assert(s.uuid == "term-uuid-1");
    assert(!s.overrideTitle.isNull && s.overrideTitle.get == "custom title");
    assert(!s.overrideBadge.isNull && s.overrideBadge.get == "build");
    assert(!s.overrideCommand.isNull && s.overrideCommand.get == "ssh host");
    assert(!s.readOnly);
    assert(!s.synchronizedInput);
    assert(!s.maximized); // omitted in golden, defaults to false

    // Roundtrip: every key in the golden input is present and equal in toJSON output.
    JSONValue rt = s.toJSON();
    foreach (string key, ref JSONValue val; parsed.object) {
        assert(key in rt, "key '" ~ key ~ "' missing from roundtrip output");
        assert(rt[key].toString() == val.toString(),
            "key '" ~ key ~ "' value drift: " ~ val.toString() ~ " -> " ~ rt[key].toString());
    }
}

/// Test: missing optional keys deserialize as Nullable.init (null).
unittest {
    enum string minimal = `{
        "profile": "p",
        "directory": "/",
        "uuid": "u"
    }`;
    TerminalSnapshot s = TerminalSnapshot.fromJSON(parseJSON(minimal));
    assert(s.overrideTitle.isNull);
    assert(s.overrideBadge.isNull);
    assert(s.overrideCommand.isNull);
    assert(!s.readOnly);
    assert(!s.synchronizedInput);
    assert(!s.maximized);
}

/// Test: unknown keys in JSON are ignored (forwards compat).
unittest {
    enum string withUnknown = `{
        "profile": "p",
        "directory": "/",
        "uuid": "u",
        "futureField": "ignored",
        "anotherUnknown": 42
    }`;
    TerminalSnapshot s = TerminalSnapshot.fromJSON(parseJSON(withUnknown));
    assert(s.profileUUID == "p");
    assert(s.uuid == "u");
    // No assertion failure — unknown keys silently dropped.
}

/// Test: maximized field roundtrips correctly when true.
unittest {
    TerminalSnapshot s;
    s.profileUUID = "p";
    s.directory = "/";
    s.uuid = "u";
    s.maximized = true;
    JSONValue v = s.toJSON();
    assert(NODE_MAXIMIZED in v);
    assert(v[NODE_MAXIMIZED].type == JSONType.true_);

    TerminalSnapshot s2 = TerminalSnapshot.fromJSON(v);
    assert(s2.maximized);
}

/// Test: maximized=false is omitted from JSON (matches pre-refactor behavior).
unittest {
    TerminalSnapshot s;
    s.profileUUID = "p";
    s.directory = "/";
    s.uuid = "u";
    s.maximized = false;
    JSONValue v = s.toJSON();
    assert(NODE_MAXIMIZED !in v,
        "maximized=false should not be written; pre-refactor behavior was to write only when true");
}

/// Test: nullable override fields are omitted from JSON when null.
unittest {
    TerminalSnapshot s;
    s.profileUUID = "p";
    s.directory = "/";
    s.uuid = "u";
    // overrideTitle, overrideBadge, overrideCommand all null
    JSONValue v = s.toJSON();
    assert(NODE_TITLE !in v);
    assert(NODE_BADGE !in v);
    assert(NODE_OVERRIDE_CMD !in v);
}

/// Test: readOnly=true wire format. Pre-refactor wrote `JSONValue(!vte.getInputEnabled())` —
/// readOnly:true means input is disabled. Match that convention exactly.
unittest {
    TerminalSnapshot s;
    s.profileUUID = "p";
    s.directory = "/";
    s.uuid = "u";
    s.readOnly = true;
    JSONValue v = s.toJSON();
    assert(v[NODE_READONLY].type == JSONType.true_);

    TerminalSnapshot s2 = TerminalSnapshot.fromJSON(v);
    assert(s2.readOnly);
}
