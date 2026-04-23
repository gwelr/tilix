module gx.ttyx.terminal.activeprocess;

import core.sys.posix.unistd;
import core.thread;

import std.algorithm;
import std.array;
import std.conv;
import std.experimental.logger;
import std.file;
import std.path;
import std.string;

import gx.util.proc : readProcStatus;


/**
* A stripped-down (plus extended) version of psutil's Process class.
*/
class Process {

    pid_t pid;
    string[] processStat;
    static Process[pid_t] processMap;
    static Process[][pid_t] sessionMap;

    this(pid_t p)
    {
        pid = p;
        processStat = parseStatFile();
    }

    @property string name() {
        return processStat[0];
    }

    @property pid_t ppid() {
        return to!pid_t(processStat[2]);
    }

    /// True if the process has effective UID 0 (root).
    bool isRoot() {
        return readProcStatus(pid).uid == 0;
    }

    string[] parseStatFile() {
        try {
            string data = to!string(cast(char[])read(format("/proc/%d/stat", pid)));
            size_t rpar = data.lastIndexOf(")");
            string name = data[data.indexOf("(") + 1..rpar];
            string[] other  = data[rpar + 2..data.length].split;
            return name ~ other;
        } catch (FileException fe) {
            warning(fe);
            }
        return "? 0 0 0 0 0 0".split;
    }

    /**
    * Foreground process has a controlling terminal and
    * process group id == terminal process group id.
    */
    bool isForeground() {
        if (!Process.pidExists(pid)) {
            return false;
        }
        // Need updated version.
        string[] tempStat = parseStatFile();
        long pgrp = to!long(tempStat[3]);
        long tty = to!long(tempStat[5]);
        long tpgid = to!long(tempStat[6]);
        return tty > 0 && pgrp == tpgid;
    }

    bool hasTTY() {
        return to!long(processStat[5]) > 0;
    }

    /**
    * Shell PID == session ID
    */
    pid_t sessionID() {
        return to!pid_t(processStat[4]);
    }

    /**
    * Return true if this process has any foreground child process.
    * Note that `Process.sessionMap` contains foreground processes only.
    */
    bool hasForegroundChildren() {
        foreach (p; Process.sessionMap.get(sessionID(), [])) {
            if (p.ppid == pid) {
                return true;
            }
        }
        return false;
    }

    /**
    * Get all running PIDs.
    */
    static pid_t[] pids() {
        return std.file.dirEntries("/proc", SpanMode.shallow)
            .filter!(a => std.path.baseName(a.name).isNumeric)
            .map!(a => to!pid_t(std.path.baseName(a.name)))
            .array;
    }

    static bool pidExists(pid_t p) {
            return exists(format("/proc/%d", p));
    }

    /**
    * Create `Process` object of all PIDs and store them in
    * `Process.processMap` and store foreground processes
    * in `Process.sessionMap` using session id as their key.
    */
    static void updateMap() {

        Process add(pid_t p) {
            auto proc = new Process(p);
            Process.processMap[p] = proc;
            return proc;
        }

        void remove(pid_t p) {
            Process.processMap.remove(p);
        }

        auto pids = Process.pids().sort();
        auto pmapKeys = Process.processMap.keys.sort();
        auto gonePids = setDifference(pmapKeys, pids);

        foreach(p; gonePids) {
            remove(p);
        }

        Process.processMap.rehash;
        Process proc;
        Process.sessionMap.clear;

        foreach(p; pids) {
            if (p in Process.processMap) {
                proc = Process.processMap[p]; // Cached process.
            } else if (Process.pidExists(p)) {
                proc = add(p); // New Process.
            }
            // Taking advantages of short-circuit operator `&&` using `proc.hasTTY()`
            // to reduce calling on `proc.isForeground()`.
            if (proc !is null && proc.hasTTY() && proc.isForeground()) {
                Process.sessionMap[proc.sessionID()] ~= proc;
            }
        }
    }
}


/**
 * Get active process list of all terminals.
 * `Process.sessionMap` contains foreground processes of all
 * open terminals using session id (shell PID) as their key. We are
 * iterating through all processes for each session id and trying
 * to find their active process and finally returning all active process.
 * Returning all active process is very efficient when there are too
 * many open terminals comparing to find the active process of several
 * terminals one by one.
 */
Process[pid_t] getActiveProcessList() {
    //  Update `Process.sessionMap` and `Process.processMap`.
    Process.updateMap();
    Process[pid_t] ret;
    foreach(shellChild; Process.sessionMap.byValue()) {
         // The shell process has only one foreground
         // process, so, it is an active process.
        if (shellChild.length == 1) {
            auto proc = shellChild[0];
            ret[proc.sessionID()] = proc;
        } else {
            // Probably, the last item is the active process.
            foreach_reverse(proc; shellChild) {
                // If a foreground process has no foreground
                // child process then it is an active process.
                if (!proc.hasForegroundChildren()) {
                    ret[proc.sessionID()] = proc;
                    break;
                }
            }
        }
    }
    return ret;
}

/**
 * Get the foreground process for a specific shell PID by reading
 * only the shell's /proc entry to find the terminal foreground
 * process group, then locating the process leader of that group.
 *
 * This is much cheaper than getActiveProcessList() which scans
 * all PIDs on the system. Reads 2-3 /proc files per shell instead
 * of hundreds.
 */
ForegroundProcessInfo getForegroundProcess(pid_t shellPid) {
    try {
        // Read the shell's stat to get the foreground process group (tpgid)
        string statData = to!string(cast(char[]) read(format("/proc/%d/stat", shellPid)));
        size_t rpar = statData.lastIndexOf(")");
        if (rpar == -1) return ForegroundProcessInfo.init;
        string[] fields = statData[rpar + 2 .. $].split;
        if (fields.length < 6) return ForegroundProcessInfo.init;

        pid_t tpgid = to!pid_t(fields[5]); // field 8 in stat = index 5 after name
        if (tpgid <= 0) return ForegroundProcessInfo.init;

        // If the foreground process group is the shell itself, nothing interesting is running
        if (tpgid == shellPid) return ForegroundProcessInfo.init;

        // Read the foreground process's stat to get its name
        string fgStatData = to!string(cast(char[]) read(format("/proc/%d/stat", tpgid)));
        size_t fgRpar = fgStatData.lastIndexOf(")");
        if (fgRpar == -1) return ForegroundProcessInfo.init;
        string fgName = fgStatData[fgStatData.indexOf("(") + 1 .. fgRpar];

        return ForegroundProcessInfo(tpgid, fgName);
    } catch (Exception e) {
        // Process may have exited between checks
        return ForegroundProcessInfo.init;
    }
}

/**
 * Lightweight result from getForegroundProcess — just PID and name,
 * no full Process object needed.
 */
struct ForegroundProcessInfo {
    pid_t pid = -1;
    string name;

    bool isValid() const { return pid > 0; }
}

// -- Unit tests --

unittest {
    // getForegroundProcess on PID 1 (init) should return invalid
    auto info = getForegroundProcess(1);
    assert(!info.isValid());
}

unittest {
    // getForegroundProcess on non-existent PID should return invalid
    auto info = getForegroundProcess(999_999_999);
    assert(!info.isValid());
}

unittest {
    // ForegroundProcessInfo default is invalid
    auto info = ForegroundProcessInfo.init;
    assert(!info.isValid());
    assert(info.pid == -1);
}

unittest {
    // Process.isRoot delegates to gx.util.proc.readProcStatus; verify
    // the wiring against init (pid 1), which always runs as root.
    auto p = new Process(1);
    assert(p.isRoot());
}
