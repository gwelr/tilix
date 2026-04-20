/*
 * This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not
 * distributed with this file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */

module gx.util.proc;

import core.sys.posix.unistd : pid_t;

/// SSH-family process names that indicate a remote connection.
immutable string[] SSH_PROCESS_NAMES = ["ssh", "scp", "sftp", "mosh", "sshfs"];

/// Returns true if `name` is one of the SSH-family commands.
bool isSSHProcess(string name) {
    import std.algorithm : canFind;
    return SSH_PROCESS_NAMES.canFind(name);
}

/// Parsed fields from `/proc/[pid]/status` that we care about.
/// `uid` is the effective UID; -1 signals a read/parse failure.
struct ProcStatus {
    int uid = -1;
    pid_t ppid = 0;

    bool isValid() const { return uid >= 0; }
}

/**
 * Read `/proc/[pid]/status` and return the effective UID + PPid.
 * Returns `ProcStatus.init` (uid = -1) if the file is missing,
 * unreadable, or malformed.
 */
ProcStatus readProcStatus(pid_t pid) {
    import std.conv : to;
    import std.file : read, exists;
    import std.format : format;
    import std.string : splitLines, startsWith, split;

    if (pid <= 0) return ProcStatus.init;
    auto path = format("/proc/%d/status", pid);
    if (!exists(path)) return ProcStatus.init;
    try {
        string data = to!string(cast(char[]) read(path));
        ProcStatus result;
        bool sawUid = false;
        foreach (line; data.splitLines()) {
            if (line.startsWith("Uid:")) {
                auto fields = line.split();
                if (fields.length >= 3) {
                    result.uid = to!int(fields[2]);
                    sawUid = true;
                }
            } else if (line.startsWith("PPid:")) {
                auto fields = line.split();
                if (fields.length >= 2) {
                    result.ppid = to!pid_t(fields[1]);
                }
            }
        }
        return sawUid ? result : ProcStatus.init;
    } catch (Exception) {
        return ProcStatus.init;
    }
}

/**
 * Walk up the process tree from `startPid`, returning true if any
 * non-init ancestor has effective UID 0 (root). Stops at pid <= 1
 * or when a process in the chain no longer exists. Bounded depth
 * prevents pathological loops (shouldn't happen on a sane system
 * but guards against surprises).
 */
bool checkProcessTreeForRoot(pid_t startPid) {
    pid_t currentPid = startPid;
    for (int depth = 0; depth < 10; depth++) {
        if (currentPid <= 1) break;
        auto status = readProcStatus(currentPid);
        if (!status.isValid()) break;
        if (status.uid == 0) return true;
        currentPid = status.ppid;
    }
    return false;
}

// -- tests --------------------------------------------------------------

unittest {
    // SSH process detection
    assert(isSSHProcess("ssh"));
    assert(isSSHProcess("scp"));
    assert(isSSHProcess("sftp"));
    assert(isSSHProcess("mosh"));
    assert(isSSHProcess("sshfs"));

    assert(!isSSHProcess("bash"));
    assert(!isSSHProcess("vim"));
    assert(!isSSHProcess("sudo"));
    assert(!isSSHProcess("sshd"));      // daemon, not client
    assert(!isSSHProcess("ssh-agent"));
    assert(!isSSHProcess(""));
}

unittest {
    // ProcStatus default is invalid.
    auto s = ProcStatus.init;
    assert(!s.isValid());
    assert(s.uid == -1);
}

unittest {
    // Init (pid 1) always runs as root on Linux and has no parent.
    auto s = readProcStatus(1);
    assert(s.isValid());
    assert(s.uid == 0);
    assert(s.ppid == 0);
}

unittest {
    // The current process exists and is parseable.
    import core.sys.posix.unistd : getpid;
    auto s = readProcStatus(getpid());
    assert(s.isValid());
    assert(s.ppid > 0);
}

unittest {
    // Non-existent / invalid pids return the invalid sentinel.
    assert(!readProcStatus(999_999_999).isValid());
    assert(!readProcStatus(0).isValid());
    assert(!readProcStatus(-1).isValid());
}

unittest {
    // checkProcessTreeForRoot skips init and invalid pids by guard.
    assert(!checkProcessTreeForRoot(1));
    assert(!checkProcessTreeForRoot(0));
    assert(!checkProcessTreeForRoot(-1));
    assert(!checkProcessTreeForRoot(999_999_999));
}

unittest {
    // If the test runner itself isn't root, walking up from the
    // current PID must return false. If it is root, the result is
    // true and we skip the assertion to keep the test portable.
    import core.sys.posix.unistd : getpid, geteuid;
    if (geteuid() != 0) {
        assert(!checkProcessTreeForRoot(getpid()));
    }
}
