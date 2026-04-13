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

import gx.gtk.clipboard : GDK_SELECTION_CLIPBOARD;
import gx.i18n.l10n;

import gx.tilix.constants : USE_COMMIT_SYNCHRONIZATION;
import gx.tilix.preferences;
import gx.tilix.terminal.advpaste;
import gx.tilix.terminal.context;
import gx.tilix.terminal.exvte : vtePasteText;
import gx.tilix.terminal.types;

package:

/**
 * Tests if the paste content is potentially unsafe.
 *
 * Currently checks for sudo combined with a newline, which would
 * execute a privileged command immediately on paste.
 */
bool isPasteUnsafe(string text) {
    import std.string : indexOf;
    return (text.indexOf("sudo") > -1) && (text.indexOf("\n") > -1);
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

    /// Whether the user has dismissed the unsafe paste warning for this session.
    bool _unsafePasteIgnored;

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

        bool stripTrailingWhitespace = _ctx.contextGsSettings().getBoolean(SETTINGS_STRIP_TRAILING_WHITESPACE);
        if (stripTrailingWhitespace) {
            pasteText = pasteText.stripRight();
        }

        if (pasteText.length == 0) return;

        if (isPasteUnsafe(pasteText)) {
            if (!_unsafePasteIgnored && _ctx.contextGsSettings().getBoolean(SETTINGS_UNSAFE_PASTE_ALERT_KEY)) {
                UnsafePasteDialog dialog = new UnsafePasteDialog(
                    cast(Window) _ctx.toplevelWidget(), chomp(pasteText));
                scope(exit) {
                    dialog.destroy();
                }
                if (dialog.run() == 0)
                    _unsafePasteIgnored = true;
                else
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

/// Test: sudo with newline is unsafe.
unittest {
    assert(isPasteUnsafe("sudo rm -rf /\n"));
}

/// Test: sudo without newline is safe (won't auto-execute).
unittest {
    assert(!isPasteUnsafe("sudo rm -rf /"));
}

/// Test: newline without sudo is safe.
unittest {
    assert(!isPasteUnsafe("echo hello\necho world\n"));
}

/// Test: empty string is safe.
unittest {
    assert(!isPasteUnsafe(""));
}

/// Test: sudo buried in multiline command is unsafe.
unittest {
    assert(isPasteUnsafe("echo hello\nsudo apt install malware\necho done"));
}

/// Test: "sudo" as substring of another word with newline is flagged (known limitation).
unittest {
    // "visudo" contains "sudo" — current implementation flags it
    assert(isPasteUnsafe("visudo /etc/sudoers\n"));
}

/// Test: only newline, no sudo.
unittest {
    assert(!isPasteUnsafe("\n"));
}

/// Test: sudo at start with immediate newline.
unittest {
    assert(isPasteUnsafe("sudo\n"));
}
