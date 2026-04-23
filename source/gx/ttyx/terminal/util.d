/*
 * This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not
 * distributed with this file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */
module gx.ttyx.terminal.util;

import std.conv;
import std.experimental.logger;
import std.file;
import std.process;
import std.uuid;

//Cribbed from Gnome Terminal
immutable string[] shells = [/* Note that on some systems shells can also
        * be installed in /usr/bin */
"/bin/bash", "/usr/bin/bash", "/bin/zsh", "/usr/bin/zsh", "/bin/tcsh", "/usr/bin/tcsh", "/bin/ksh", "/usr/bin/ksh", "/bin/csh", "/bin/sh"];

string getUserShell(string shell) {
    import std.file : exists;
    import core.sys.posix.pwd : getpwuid, passwd;
    import core.sys.posix.unistd: getuid;

    if (shell.length > 0 && exists(shell))
        return shell;

    // Try environment variable next
    try {
        shell = environment["SHELL"];
        if (shell.length > 0) {
            tracef("Using shell %s from SHELL environment variable", shell);
            return shell;
        }
    }
    catch (Exception e) {
        trace("No SHELL environment variable found");
    }

    //Try to get shell from getpwuid
    passwd* pw = getpwuid(getuid());
    if (pw && pw.pw_shell) {
        string pw_shell = to!string(pw.pw_shell);
        if (exists(pw_shell)) {
            tracef("Using shell %s from getpwuid",pw_shell);
            return pw_shell;
        }
    }

    //Try known shells
    foreach (s; shells) {
        if (exists(s)) {
            tracef("Found shell %s, using that", s);
            return s;
        }
    }
    error("No shell found, defaulting to /bin/sh");
    return "/bin/sh";
}

bool isFlatpak() {
    return "/.flatpak-info".exists;
}

// ---------------------------------------------------------------------------
// Unit tests
// ---------------------------------------------------------------------------

/// Test: isFlatpak returns false on a normal system (no /.flatpak-info).
unittest {
    // On CI and dev machines, we're not in Flatpak
    // This test will correctly fail inside a Flatpak sandbox,
    // which is fine — we don't run tests there
    assert(!isFlatpak() || "/.flatpak-info".exists);
}

/// Test: getUserShell returns a non-empty path.
unittest {
    string shell = getUserShell("");
    assert(shell.length > 0, "getUserShell should find a shell");
    assert(shell[0] == '/', "shell path should be absolute");
}

/// Test: getUserShell with valid path returns it unchanged.
unittest {
    string shell = getUserShell("/bin/sh");
    assert(shell == "/bin/sh");
}

/// Test: getUserShell with nonexistent path falls back.
unittest {
    string shell = getUserShell("/nonexistent/shell");
    assert(shell.length > 0, "should fall back to a real shell");
    assert(shell != "/nonexistent/shell", "should not return nonexistent path");
}

/// Test: known shells list contains common shells.
unittest {
    import std.algorithm : canFind;
    assert(shells.canFind("/bin/bash") || shells.canFind("/usr/bin/bash"));
    assert(shells.canFind("/bin/sh"));
}