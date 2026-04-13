/*
 * This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not
 * distributed with this file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */
module gx.tilix.terminal.process;

private:

import core.sys.posix.unistd : pid_t;

import std.conv : to;
import std.experimental.logger;
import std.format : format;
import std.string : indexOf, lastIndexOf, replace;

import gx.i18n.l10n;
import gx.tilix.terminal.util : isFlatpak;
import gx.tilix.terminal.context;
import gx.tilix.terminal.flatpak : captureHostToolboxCommand;

package:

/**
 * Queries the state of child processes running inside a terminal.
 *
 * Responsible for:
 * - Determining whether a child process (beyond the shell itself) is running
 * - Retrieving the child process PID and name
 * - Handling Flatpak sandbox differences (host toolbox vs /proc)
 *
 * This is a candidate for security features (#27): SSH session detection (#22),
 * privilege escalation monitoring, unexpected process alerts.
 */
class TerminalProcessQuery {

private:
    ITerminalContext _ctx;

public:
    /**
     * Construct a TerminalProcessQuery.
     *
     * Params:
     *   ctx = Terminal context providing VTE widget access.
     */
    this(ITerminalContext ctx) {
        _ctx = ctx;
    }

    /**
     * Determines if a child process is running in the terminal.
     *
     * Returns true if there is an active child process beyond the shell
     * itself (i.e., `childPid != shellPid`).
     *
     * Params:
     *   shellPid = PID of the terminal's shell process.
     */
    bool isProcessRunning(int shellPid) {
        pid_t dummy;
        return isProcessRunning(shellPid, dummy);
    }

    /**
     * Determines if a child process is running in the terminal,
     * and returns the child PID.
     *
     * Params:
     *   shellPid = PID of the terminal's shell process.
     *   childPid = Output: PID of the active child process, or -1 if none.
     */
    bool isProcessRunning(int shellPid, out pid_t childPid) {
        auto vte = _ctx.contextVte();
        if (vte.getPty() is null)
            return false;

        if (isFlatpak()) {
            childPid = getChildPidFromHost();
        } else {
            childPid = vte.getChildPid();
        }

        tracef("childPid=%d shellPid=%d", childPid, shellPid);
        return (childPid != -1 && childPid != shellPid);
    }

    /**
     * Determines if a child process is running in the terminal,
     * and returns the process name.
     *
     * Params:
     *   shellPid = PID of the terminal's shell process.
     *   name = Output: name of the active child process, or "Unknown" if unavailable.
     */
    bool isProcessRunning(int shellPid, out string name) {
        auto vte = _ctx.contextVte();
        if (vte.getPty() is null)
            return false;

        pid_t childPid;
        bool result = isProcessRunning(shellPid, childPid);

        if (childPid == -1) {
            return false;
        }

        import std.file : read, FileException;
        try {
            string data;
            if (isFlatpak()) {
                data = captureHostToolboxCommand("get-proc-stat", to!string(childPid), []);
            } else {
                data = to!string(cast(char[]) read(format("/proc/%d/stat", childPid)));
            }

            size_t rpar = data.lastIndexOf(")");
            name = data[data.indexOf("(") + 1 .. rpar];
        } catch (FileException fe) {
            name = _("Unknown");
            warning(fe);
        }
        name = replace(name, "\0", " ");

        return result;
    }

private:
    /**
     * Get the child PID from the host via the Flatpak toolbox.
     * Used when running inside a Flatpak sandbox where /proc is not
     * directly accessible for the host process tree.
     */
    pid_t getChildPidFromHost() {
        string result = captureHostToolboxCommand("get-child-pid", "",
            [_ctx.contextVte().getPty().getFd()]);
        if (result == null) {
            warning("Failed to get child pid from host");
            return -1;
        }
        return to!pid_t(result);
    }
}
