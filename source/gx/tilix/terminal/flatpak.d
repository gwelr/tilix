/*
 * This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not
 * distributed with this file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */
module gx.tilix.terminal.flatpak;

private:

import core.memory;
import std.conv;
import std.experimental.logger;
import std.format;
import std.string;

import glib.Util;
import glib.Variant : GVariant = Variant;
import glib.VariantBuilder : GVariantBuilder = VariantBuilder;
import glib.VariantType : GVariantType = VariantType;

import gtkc.giotypes : GDBusConnection, GDBusCallFlags, GDBusConnectionFlags, GDBusSignalCallback, GDBusSignalFlags;
import gtkc.glibtypes;

import gx.util.redact : redactSensitive;

/// Delegate type for receiving host command exit notifications.
package alias HostCommandExitedCallback = void delegate(int);

/// Arguments passed to the D-Bus signal callback for HostCommandExited.
struct HostCommandExitedArgs {
    HostCommandExitedCallback callback;
    int pid = -1;
    uint signalId = 0u;
    int status = -1;
}

/**
 * Build a GVariant for the Flatpak HostCommand D-Bus call.
 *
 * Constructs the (ay aay a{uh} a{ss} u) variant expected by
 * org.freedesktop.Flatpak.Development.HostCommand.
 */
GVariant buildHostCommandVariant(string workingDir, string[] args, string[] envv, uint[] handles) {
    import gtkc.glib : g_variant_new;

    if (workingDir.length == 0) workingDir = Util.getHomeDir();

    GVariantBuilder fdBuilder = new GVariantBuilder(new GVariantType("a{uh}"));
    foreach (i, fd; handles) {
        auto entry = new GVariant(g_variant_new("{uh}",
            cast(uint) i, cast(int) fd), true);
        fdBuilder.addValue(entry);
    }
    GVariantBuilder envBuilder = new GVariantBuilder(new GVariantType("a{ss}"));
    foreach (env; envv) {
        auto eqPos = env.indexOf('=');
        if (eqPos < 1) continue;
        string key = env[0 .. eqPos];
        string val = env[eqPos + 1 .. $];
        tracef("Adding env var %s=%s", key, redactSensitive(key, val));
        auto entry = new GVariant(g_variant_new("{ss}",
            toStringz(key), toStringz(val)), true);
        envBuilder.addValue(entry);
    }

    immutable(char)* wd = toStringz(workingDir);
    immutable(char)*[] argsv;
    foreach (i, arg; args) {
        argsv ~= toStringz(arg);
    }
    argsv ~= null;

    gtkc.glibtypes.GVariant* vs = g_variant_new("(^ay^aay@a{uh}@a{ss}u)",
                      wd,
                      argsv.ptr,
                      fdBuilder.end().getVariantStruct(true),
                      envBuilder.end().getVariantStruct(true),
                      cast(uint) 1);

    return new GVariant(vs, true);
}

/// D-Bus signal callback for HostCommandExited.
extern(C) void hostCommandExitedCallback(GDBusConnection* connection, const(char)* senderName, const(char)* objectPath, const(char)* interfaceName,
                                                const(char)* signalName, gtkc.glibtypes.GVariant* parameters, HostCommandExitedArgs* args) {
    import gtkc.glib : g_variant_get;

    uint pid, status;
    g_variant_get(parameters, "(uu)", &pid, &status);

    if (args.pid == -1 || pid == args.pid) {
        import gtkc.gio : g_dbus_connection_signal_unsubscribe;

        if (args.pid == -1) {
            trace("hostCommandExitedCallback was called before spawn completed.");
            args.pid = pid;
            args.status = status;
        } else {
            g_dbus_connection_signal_unsubscribe(connection, args.signalId);
            args.callback(status);
        }

        GC.removeRoot(cast(void*) args);
    }
}

package:

/**
 * Send a command to the host via the Flatpak D-Bus Development interface.
 *
 * Returns true on success, with gpid set to the host process ID.
 */
bool sendHostCommand(string workingDir, string[] args, string[] envv, int[] stdio_fds, out int gpid, HostCommandExitedCallback exitedCallback) {
    import std.process : environment;

    import gio.DBusConnection;
    import gio.UnixFDList;

    import gtkc.glib : g_variant_get;

    uint[] handles;

    UnixFDList outFdList;
    UnixFDList inFdList = new UnixFDList();
    foreach (i, fd; stdio_fds) {
        handles ~= inFdList.append(fd);
        if (handles[i] == -1) {
            warning("Error creating fd list handles");
        }
    }

    DBusConnection connection = new DBusConnection(
        environment.get("DBUS_SESSION_BUS_ADDRESS"),
        GDBusConnectionFlags.AUTHENTICATION_CLIENT | GDBusConnectionFlags.MESSAGE_BUS_CONNECTION,
        null,
        null
    );
    connection.setExitOnClose(false);
    connection.doref();

    auto callbackArgs = new HostCommandExitedArgs();
    callbackArgs.callback = exitedCallback;
    GC.addRoot(cast(void*) callbackArgs);

    uint signalId = connection.signalSubscribe(
        "org.freedesktop.Flatpak",
        "org.freedesktop.Flatpak.Development",
        "HostCommandExited",
        "/org/freedesktop/Flatpak/Development",
        null,
        DBusSignalFlags.NONE,
        cast(GDBusSignalCallback) &hostCommandExitedCallback,
        cast(void*) callbackArgs,
        null,
    );

    GVariant reply = connection.callWithUnixFdListSync(
        "org.freedesktop.Flatpak",
        "/org/freedesktop/Flatpak/Development",
        "org.freedesktop.Flatpak.Development",
        "HostCommand",
        buildHostCommandVariant(workingDir, args, envv, handles),
        new GVariantType("(u)"),
        GDBusCallFlags.NONE,
        -1,
        inFdList,
        outFdList,
        null
    );

    if (reply is null) {
        warning("No reply from flatpak dbus service");
        connection.signalUnsubscribe(signalId);
        return false;
    } else {
        uint pid;
        g_variant_get(reply.getVariantStruct(), "(u)", &pid);
        gpid = pid;

        if (callbackArgs.pid != -1) {
            trace("HostCommandExited was already emitted");
            connection.signalUnsubscribe(signalId);
            exitedCallback(callbackArgs.status);
        } else {
            callbackArgs.pid = pid;
            callbackArgs.signalId = signalId;
        }

        return true;
    }
}

/**
 * Run a ttyx-flatpak-toolbox command on the host and capture its stdout output.
 *
 * This is a thin wrapper over sendHostCommand that launches the toolbox binary
 * from the Flatpak app-path and waits for it to complete.
 */
string captureHostToolboxCommand(string command, string arg, int[] extra_fds) {
    import std.process : Pipe, pipe;
    import glib.MainContext;
    import glib.KeyFile;
    import gtkc.glibtypes : GKeyFileFlags;

    KeyFile kf = new KeyFile();
    kf.loadFromFile("/.flatpak-info", GKeyFileFlags.NONE);

    string hostRoot = kf.getString("Instance", "app-path");
    string[] args = [format("%s/bin/ttyx-flatpak-toolbox", hostRoot), command, arg];

    Pipe output = pipe();
    scope(exit) pipe.close();

    int gpid, status = -1;

    void commandExited(int command_status) {
        status = command_status;
    }

    int[] stdio_fds = [0, output.writeEnd.fileno, 2] ~ extra_fds;

    if (!sendHostCommand("/", args, [], stdio_fds, gpid, &commandExited)) {
        return null;
    }

    MainContext ctx = MainContext.getThreadDefault();
    if (ctx is null) {
        // https://github.com/gtkd-developers/GtkD/issues/247
        ctx = MainContext.default_();
    }

    trace("captureHostToolboxCommand is waiting for status to be filled...");
    while (status == -1) {
        ctx.iteration(true);
    }

    if (status != 0) {
        return null;
    }

    return output.readEnd.readln().strip();
}
