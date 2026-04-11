/*
 * This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not
 * distributed with this file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */
module gx.tilix.terminal.exvte;

import core.sys.posix.unistd;

import std.algorithm;
import std.experimental.logger;

import gdk.Event;
import gdk.RGBA;

import gobject.Signals;

import glib.Str;

import vte.Terminal;
import vtec.vtetypes;

import gx.tilix.constants;
import gx.tilix.terminal.util;

enum TerminalScreen {
    NORMAL = 0,
    ALTERNATE = 1
};

/**
 * Extends default GtKD VTE widget to support various patches
 * which provide additional features when available.
 */
class ExtendedVTE : Terminal {

private:
    bool ignoreFirstNotification = true;

public:

    /**
	 * Sets our main struct and passes it to the parent class.
	 */
    this(VteTerminal* vteTerminal, bool ownedRef = false) {
        super(vteTerminal, ownedRef);
    }

    /**
	 * Creates a new terminal widget.
	 *
	 * Return: a new #VteTerminal object
	 *
	 * Throws: ConstructionException GTK+ fails to create the object.
	 */
    this() {
        super();
    }

    debug(Destructors) {
        ~this() {
            import std.stdio: writeln;
            writeln("******** VTE Destructor");
        }
    }

	protected class OnNotificationReceivedDelegateWrapper
	{
		void delegate(string, string, Terminal) dlg;
		gulong handlerId;
		ConnectFlags flags;
		this(void delegate(string, string, Terminal) dlg, gulong handlerId, ConnectFlags flags)
		{
			this.dlg = dlg;
			this.handlerId = handlerId;
			this.flags = flags;
		}
	}
	protected OnNotificationReceivedDelegateWrapper[] onNotificationReceivedListeners;

	/**
	 * Emitted when a process running in the terminal wants to
	 * send a notification to the desktop environment.
	 *
	 * Params:
	 *     summary = The summary
	 *     bod = Extra optional text
	 */
	gulong addOnNotificationReceived(void delegate(string, string, Terminal) dlg, ConnectFlags connectFlags=cast(ConnectFlags)0)
	{
		if (Signals.lookup("notification-received", getType()) != 0) {
			onNotificationReceivedListeners ~= new OnNotificationReceivedDelegateWrapper(dlg, 0, connectFlags);
			onNotificationReceivedListeners[onNotificationReceivedListeners.length - 1].handlerId = Signals.connectData(
				this,
				"notification-received",
				cast(GCallback)&callBackNotificationReceived,
				cast(void*)onNotificationReceivedListeners[onNotificationReceivedListeners.length - 1],
				cast(GClosureNotify)&callBackNotificationReceivedDestroy,
				connectFlags);
			return onNotificationReceivedListeners[onNotificationReceivedListeners.length - 1].handlerId;
		} else {
			return 0;
		}
	}

	extern(C) static void callBackNotificationReceived(VteTerminal* terminalStruct, char* summary, char* bod,OnNotificationReceivedDelegateWrapper wrapper)
	{
		wrapper.dlg(Str.toString(summary), Str.toString(bod), wrapper.outer);
	}

	extern(C) static void callBackNotificationReceivedDestroy(OnNotificationReceivedDelegateWrapper wrapper, GClosure* closure)
	{
		wrapper.outer.internalRemoveOnNotificationReceived(wrapper);
	}

	protected void internalRemoveOnNotificationReceived(OnNotificationReceivedDelegateWrapper source)
	{
		foreach(index, wrapper; onNotificationReceivedListeners)
		{
			if (wrapper.dlg == source.dlg && wrapper.flags == source.flags && wrapper.handlerId == source.handlerId)
			{
				onNotificationReceivedListeners[index] = null;
				onNotificationReceivedListeners = std.algorithm.remove(onNotificationReceivedListeners, index);
				break;
			}
		}
	}

	protected class OnTerminalScreenChangedDelegateWrapper
	{
		void delegate(int, Terminal) dlg;
		gulong handlerId;
		ConnectFlags flags;
		this(void delegate(int, Terminal) dlg, gulong handlerId, ConnectFlags flags)
		{
			this.dlg = dlg;
			this.handlerId = handlerId;
			this.flags = flags;
		}
	}
	protected OnTerminalScreenChangedDelegateWrapper[] onTerminalScreenChangedListeners;

	/** */
	gulong addOnTerminalScreenChanged(void delegate(int, Terminal) dlg, ConnectFlags connectFlags=cast(ConnectFlags)0)
	{
		if (Signals.lookup("terminal-screen-changed", getType()) != 0) {
			onTerminalScreenChangedListeners ~= new OnTerminalScreenChangedDelegateWrapper(dlg, 0, connectFlags);
			onTerminalScreenChangedListeners[onTerminalScreenChangedListeners.length - 1].handlerId = Signals.connectData(
				this,
				"terminal-screen-changed",
				cast(GCallback)&callBackTerminalScreenChanged,
				cast(void*)onTerminalScreenChangedListeners[onTerminalScreenChangedListeners.length - 1],
				cast(GClosureNotify)&callBackTerminalScreenChangedDestroy,
				connectFlags);
			return onTerminalScreenChangedListeners[onTerminalScreenChangedListeners.length - 1].handlerId;
		} else {
			return 0;
		}
	}

	extern(C) static void callBackTerminalScreenChanged(VteTerminal* terminalStruct, int object,OnTerminalScreenChangedDelegateWrapper wrapper)
	{
		wrapper.dlg(object, wrapper.outer);
	}

	extern(C) static void callBackTerminalScreenChangedDestroy(OnTerminalScreenChangedDelegateWrapper wrapper, GClosure* closure)
	{
		wrapper.outer.internalRemoveOnTerminalScreenChanged(wrapper);
	}

	protected void internalRemoveOnTerminalScreenChanged(OnTerminalScreenChangedDelegateWrapper source)
	{
		foreach(index, wrapper; onTerminalScreenChangedListeners)
		{
			if (wrapper.dlg == source.dlg && wrapper.flags == source.flags && wrapper.handlerId == source.handlerId)
			{
				onTerminalScreenChangedListeners[index] = null;
				onTerminalScreenChangedListeners = std.algorithm.remove(onTerminalScreenChangedListeners, index);
				break;
			}
		}
	}

    public bool getDisableBGDraw() {
		return vte_terminal_get_disable_bg_draw(vteTerminal) != 0;
    }

    public void setDisableBGDraw(bool isDisabled) {
		vte_terminal_set_disable_bg_draw(vteTerminal, isDisabled);
    }

static if (COMPILE_VTE_BACKGROUND_COLOR) {
    public void getColorBackgroundForDraw(RGBA background) {
		vte_terminal_get_color_background_for_draw(vteTerminal, background is null? null: background.getRGBAStruct());
    }
}

    /**
     * Returns the child pid running in the terminal or -1
     * if no child pid is running. May also return the VTE gpid
     * as well which also indicates no child process.
     */
    pid_t getChildPid() {
		if (isFlatpak()) {
            warning("getChildPid should not be called from a Flatpak environment.");
			return -1;
		} else {
			if (getPty() is null)
            	return false;
        	return tcgetpgrp(getPty().getFd());
		}
    }
}

/**
 * Sends text to the terminal as if pasted. Calls vte_terminal_paste_text
 * directly, providing compatibility with GtkD 3.10.x where the D binding
 * for this method is missing from vte.Terminal.
 */
void vtePasteText(ExtendedVTE terminal, string text) {
    _vtePasteText(terminal.getTerminalStruct(), Str.toStringz(text));
}

private:

import gtkc.Loader;
import vte.c.functions;

// GtkD 3.11+ already defines vte_terminal_paste_text in vte.c.functions.
// Only define our own binding when it is missing (GtkD 3.10.x).
static if (__traits(compiles, { alias _ = vte.c.functions.vte_terminal_paste_text; })) {
	alias _vtePasteText = vte.c.functions.vte_terminal_paste_text;
} else {
	__gshared extern(C) void function(VteTerminal* terminal, const(char)* text) _vtePasteText;
}

__gshared extern(C) {
	int function(VteTerminal* terminal) c_vte_terminal_get_disable_bg_draw;
	void function(VteTerminal* terminal, int isAudible) c_vte_terminal_set_disable_bg_draw;

	static if (COMPILE_VTE_BACKGROUND_COLOR) {
		void function(VteTerminal* terminal, GdkRGBA* color) c_vte_terminal_get_color_background_for_draw;
	}
}

alias vte_terminal_get_disable_bg_draw = c_vte_terminal_get_disable_bg_draw;
alias vte_terminal_set_disable_bg_draw = c_vte_terminal_set_disable_bg_draw;

static if (COMPILE_VTE_BACKGROUND_COLOR) {
	alias vte_terminal_get_color_background_for_draw = c_vte_terminal_get_color_background_for_draw;
}

shared static this() {
	Linker.link(vte_terminal_get_disable_bg_draw, "vte_terminal_get_disable_bg_draw", LIBRARY_VTE);
	Linker.link(vte_terminal_set_disable_bg_draw, "vte_terminal_set_disable_bg_draw", LIBRARY_VTE);

	// Only link our own binding if GtkD doesn't provide it
	static if (!__traits(compiles, { alias _ = vte.c.functions.vte_terminal_paste_text; })) {
		Linker.link(_vtePasteText, "vte_terminal_paste_text", LIBRARY_VTE);
	}

	static if (COMPILE_VTE_BACKGROUND_COLOR) {
		Linker.link(vte_terminal_get_color_background_for_draw, "vte_terminal_get_color_background_for_draw", LIBRARY_VTE);
	}
}

// ---------------------------------------------------------------------------
// VTE enum conversion helpers
// ---------------------------------------------------------------------------

package:

import gx.tilix.preferences;

/// Convert a text blink mode settings string to VTE enum.
VteTextBlinkMode getTextBlinkMode(string mode) {
    import std.algorithm : countUntil;
    long i = countUntil(SETTINGS_PROFILE_TEXT_BLINK_MODE_VALUES, mode);
    return cast(VteTextBlinkMode) i;
}

/// Convert a cursor blink mode settings string to VTE enum.
VteCursorBlinkMode getBlinkMode(string mode) {
    import std.algorithm : countUntil;
    long i = countUntil(SETTINGS_PROFILE_CURSOR_BLINK_MODE_VALUES, mode);
    return cast(VteCursorBlinkMode) i;
}

/// Convert an erase binding settings string to VTE enum.
VteEraseBinding getEraseBinding(string binding) {
    import std.algorithm : countUntil;
    long i = countUntil(SETTINGS_PROFILE_ERASE_BINDING_VALUES, binding);
    return cast(VteEraseBinding) i;
}

/// Convert a cursor shape settings string to VTE enum.
VteCursorShape getCursorShape(string shape) {
    final switch (shape) {
    case SETTINGS_PROFILE_CURSOR_SHAPE_BLOCK_VALUE:
        return VteCursorShape.BLOCK;
    case SETTINGS_PROFILE_CURSOR_SHAPE_IBEAM_VALUE:
        return VteCursorShape.IBEAM;
    case SETTINGS_PROFILE_CURSOR_SHAPE_UNDERLINE_VALUE:
        return VteCursorShape.UNDERLINE;
    }
}

// ---------------------------------------------------------------------------
// Unit tests for VTE enum converters
// ---------------------------------------------------------------------------

/// Test: getCursorShape converts all shape values.
unittest {
    assert(getCursorShape(SETTINGS_PROFILE_CURSOR_SHAPE_BLOCK_VALUE) == VteCursorShape.BLOCK);
    assert(getCursorShape(SETTINGS_PROFILE_CURSOR_SHAPE_IBEAM_VALUE) == VteCursorShape.IBEAM);
    assert(getCursorShape(SETTINGS_PROFILE_CURSOR_SHAPE_UNDERLINE_VALUE) == VteCursorShape.UNDERLINE);
}
