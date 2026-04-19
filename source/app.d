/*
 * This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not
 * distributed with this file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */
import std.stdio;

import std.array;
import std.experimental.logger;
import std.file;
import std.format;
import std.process;
import std.string;

import glib.FileUtils;
import glib.Util;

import gtk.Main;
import gtk.Version;
import gtk.MessageDialog;

import gx.i18n.l10n;
import gx.gtk.util;
import gx.gtk.vte;

import gx.tilix.application;
import gx.tilix.cmdparams;
import gx.tilix.constants;

/**
 * Resolve the file path for the debug log (only used when USE_FILE_LOGGING is on).
 *
 * Prefers `$XDG_RUNTIME_DIR/ttyx.log` (typically /run/user/$UID, mode 0700
 * and owned by the user) so the log is unreadable by other local users.
 * Falls back to `$HOME/.cache/ttyx/ttyx.log` (also created mode 0700),
 * and only then to `/tmp/ttyx.log` as a last resort when neither is
 * available.
 */
private string resolveLogPath() {
    import std.path : buildPath;
    import std.file : mkdirRecurse, exists, isDir, setAttributes;
    import core.sys.posix.sys.stat : S_IRWXU;

    // Tighten permissions to 0700 on every call, not just on creation —
    // another tool may have created `~/.cache/ttyx` with looser perms.
    string tryDir(string dir, bool enforcePerms) {
        if (dir.length == 0) return null;
        try {
            if (!exists(dir)) {
                mkdirRecurse(dir);
            } else if (!isDir(dir)) {
                return null;
            }
            if (enforcePerms) setAttributes(dir, S_IRWXU);
            return buildPath(dir, "ttyx.log");
        } catch (Exception) {
            return null;
        }
    }

    // $XDG_RUNTIME_DIR is already 0700 by systemd convention — don't
    // touch its mode (it may host sockets we shouldn't clobber).
    string runtime = environment.get("XDG_RUNTIME_DIR");
    if (auto p = tryDir(runtime, /* enforcePerms */ false)) return p;

    string home = environment.get("HOME");
    if (home.length > 0) {
        if (auto p = tryDir(buildPath(home, ".cache", "ttyx"), true)) return p;
    }

    // Last-resort fallback — world-readable directory. USE_FILE_LOGGING
    // defaults off, so this only matters for developer/debug builds where
    // neither XDG_RUNTIME_DIR nor HOME is resolvable.
    return "/tmp/ttyx.log";
}

int main(string[] args) {
    static if (USE_FILE_LOGGING) {
        // FileLogger's constructors aren't `shared`, so build an unshared
        // instance and cast — sharedLog is __gshared in current Phobos.
        sharedLog = cast(shared) new FileLogger(resolveLogPath());
    }

    bool newProcess = false;
    string group;

    string cwd = Util.getCurrentDir();
    string pwd;
    string de;
    trace("CWD = " ~ cwd);
    try {
        pwd = environment["PWD"];
        de = environment["XDG_CURRENT_DESKTOP"];
        trace("PWD = " ~ pwd);
    } catch (Exception e) {
        trace("No PWD environment variable found");
    }
    try {
        environment.remove("WINDOWID");
    } catch (Exception e) {
        error("Unexpected error occurred", e);
    }

    string uhd = Util.getHomeDir();
    trace("UHD = " ~ uhd);

    //Debug args
    foreach(i, arg; args) {
        tracef("args[%d]=%s", i, arg);
    }

    // Look for execute command and convert it into a normal -e
    // We do this because this switch means take everything after
    // the switch as a command which GApplication options cannot handle
    // without a callback which D doesn't expose at this time.
    foreach(i, arg; args) {
        if (arg == "-x" || arg == "-e") {
            string executeCommand;
            // Are we dealing with a single command that either
            // has no spaces or been escaped by the user or a string
            // of multiple commands
            if (args.length == i + 2) {
                trace("Single command");
                executeCommand = args[i + 1];
            } else {
                for(size_t j=i+1; j<args.length; j++) {
                    if (j > i + 1) {
                        executeCommand ~= " ";
                    }
                    if (args[j].indexOf(" ") > 0) {
                        executeCommand ~= "\"" ~ replace(args[j], "\"", "\\\"") ~ "\"";
                    } else {
                        executeCommand ~= args[j];
                    }
                }
            }
            trace("Execute Command: " ~ executeCommand);
            args = args[0..i];
            if (arg == "-x") {
                args ~= "-e";
            } else {
                args ~= arg;
            }
            args ~= executeCommand;
            break;
        }
    }

    //textdomain
    textdomain(TTYX_DOMAIN);
    // Set application ID for GTK3 on Wayland
    Util.setPrgname(APPLICATION_ID);
    // Init GTK early so localization is available
    // Note used to pass empty args but was interfering with GTK default args
    Main.init(args);

    trace(format("Starting ttyx with %d arguments...", args.length));
    foreach(i, arg; args) {
        trace(format("arg[%d] = %s",i, arg));
        // Workaround issue with Unity and older Gnome Shell when DBusActivatable sometimes CWD is set to /, see #285
        if (arg == "--gapplication-service" && pwd == uhd && cwd == "/") {
            info("Detecting DBusActivatable with improper directory, correcting by setting CWD to PWD");
            infof("CWD = %s", cwd);
            infof("PWD = %s", pwd);
            cwd = pwd;
            FileUtils.chdir(cwd);
        } else if (arg == "--new-process") {
            newProcess = true;
        } else if (arg == "-g") {
            group = args[i+1];
        } else if (arg.startsWith("--group")) {
            group = arg[8..$];
        } else if (arg == "-v" || arg == "--version") {
            outputVersions();
            return 0;
        }
    }
    //append terminal UUID to args if present (check TTYX_ID first, TILIX_ID for backwards compat)
    try {
        string terminalUUID;
        try { terminalUUID = environment["TTYX_ID"]; } catch (Exception) {}
        if (terminalUUID is null) {
            try { terminalUUID = environment["TILIX_ID"]; } catch (Exception) {}
        }
        if (terminalUUID !is null) {
            trace("Inserting terminal UUID " ~ terminalUUID);
            args ~= ("--" ~ CMD_TERMINAL_UUID ~ "=" ~ terminalUUID);
        }
    }
    catch (Exception e) {
        trace("No terminal UUID found");
    }

    //Version checking cribbed from grestful, thanks!
    string gtkError = Version.checkVersion(GTK_VERSION_MAJOR, GTK_VERSION_MINOR, GTK_VERSION_PATCH);
    if (gtkError !is null) {
        MessageDialog dialog = new MessageDialog(null, DialogFlags.MODAL, MessageType.ERROR, ButtonsType.OK,
                format(_("Your GTK version is too old, you need at least GTK %d.%d.%d!"), GTK_VERSION_MAJOR, GTK_VERSION_MINOR, GTK_VERSION_PATCH), null);
        dialog.setDefaultResponse(ResponseType.OK);

        dialog.run();
        return 1;
    }

    // check minimum VTE version
    if (!checkVTEVersion(VTE_VERSION_MINIMAL)) {
        MessageDialog dialog = new MessageDialog(null, DialogFlags.MODAL, MessageType.ERROR, ButtonsType.OK,
                format(_("Your VTE version is too old, you need at least VTE %d.%d!"), VTE_VERSION_MINIMAL[0], VTE_VERSION_MINIMAL[1]), null);
        dialog.setDefaultResponse(ResponseType.OK);

        dialog.run();
        return 1;
    }

    trace("Creating app");
    auto tilixApp = new Tilix(newProcess, group);
    int result;
    try {
        trace("Running application...");
        result = tilixApp.run(args);
        trace("App completed...");
    }
    catch (Exception e) {
        error(_("Unexpected exception occurred"));
        error(_("Error: ") ~ e.msg);
    }
    return result;
}

private:
    void outputVersions() {
        import gx.gtk.vte: getVTEVersion, checkVTEFeature, TerminalFeature, isVTEBackgroundDrawEnabled;
        import gtk.Version: Version;

        writeln(_("Versions"));
        writeln("\t" ~ format(_("ttyx_ version: %s"), APPLICATION_VERSION));
        writeln("\t" ~ format(_("VTE version: %s"), getVTEVersion()));
        writeln("\t" ~ format(_("GTK Version: %d.%d.%d") ~ "\n", Version.getMajorVersion(), Version.getMinorVersion(), Version.getMicroVersion()));
        writeln(_("ttyx_ Special Features"));
        writeln("\t" ~ format(_("Notifications enabled=%b"), checkVTEFeature(TerminalFeature.EVENT_NOTIFICATION)));
        writeln("\t" ~ format(_("Triggers enabled=%b"), checkVTEFeature(TerminalFeature.EVENT_SCREEN_CHANGED)));
        writeln("\t" ~ format(_("Badges enabled=%b"), isVTEBackgroundDrawEnabled));
    }
