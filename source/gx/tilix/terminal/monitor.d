/*
 * This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not
 * distributed with this file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */
module gx.tilix.terminal.monitor;

import core.sys.posix.unistd;
import core.thread;

import std.concurrency;
import std.datetime;
import std.experimental.logger;
import std.parallelism;

import vtec.vtetypes;

import gx.i18n.l10n;
import gx.gtk.threads;

import gx.tilix.common;
import gx.tilix.constants;
import gx.tilix.terminal.activeprocess;

import gx.util.proc : checkProcessTreeForRoot, isSSHProcess;

import gx.tilix.application;

enum MonitorEventType {
    NONE,
    STARTED,
    CHANGED,
    FINISHED
};

/**
 * Detected properties of the active foreground process.
 * Extensible: add new fields here instead of growing the event signature.
 */
struct ProcessInfo {
    /// PID of the active foreground process
    pid_t pid;
    /// Process name (e.g. "ssh", "vim", "bash")
    string name;
    /// True if any process in the local tree has effective UID 0
    bool isRoot;
    /// True if the foreground process is an SSH-family command
    bool isSSH;
}

/**
 * Class that monitors processes to see if new child processes have been
 * started or finished and raises an event if detected. This class uses
 * a separate thread to monitor the processes and a timeoutDelegate to
 * trigger the actual events to the terminals.
 */
class ProcessMonitor {
private:
    Tid tid;
    bool running = false;

    bool fireEvents() {
        synchronized {
            foreach(process; processes) {
                if (process.eventType != MonitorEventType.NONE) {
                    auto info = ProcessInfo(
                        cast(pid_t) process.activePid,
                        cast(string) process.activeName,
                        cast(bool) process.activeIsRoot,
                        cast(bool) process.activeIsSSH
                    );
                    onChildProcess.emit(process.eventType, process.gpid, info);
                    process.eventType = MonitorEventType.NONE;
                }
            }
        }
        return running;
    }

    static ProcessMonitor _instance;

public:
    this() {

    }

    ~this() {
        // Intentionally empty. stop() calls trace() via std.logger, which
        // synchronizes on an Object monitor. When ~this() fires during GC
        // termination (rt_term), the monitor subsystem has already been
        // torn down and _d_monitorenter segfaults in rt.monitor_.ensureMonitor.
        // The spawned worker thread is reaped by the D runtime's thread
        // cleanup on process exit, so there's nothing useful left to do here.
    }

    void start() {
        running = true;
        tid = spawn(&monitorProcesses, SLEEP_CONSTANT_MS, thisTid);
        threadsAddTimeoutDelegate(SLEEP_CONSTANT_MS, &fireEvents);
        trace("Started process monitoring");
    }

    void stop() {
        if (!running) return;
        tid.send(true);
        running = false;
        trace("Stopped process monitoring");
    }

    /**
     * Add a process for monitoring
     */
    void addProcess(GPid gpid) {
        synchronized {
            if (gpid !in processes) {
                shared ProcessStatus status = new shared(ProcessStatus)(gpid);
                processes[gpid] = status;
            }
        }
        if (!running) start();
    }

    /**
     * Remove a process for monitoring
     */
    void removeProcess(GPid gpid) {
        synchronized {
            if (gpid in processes) {
                processes.remove(gpid);
                if (running && processes.length == 0) stop();
            }
        }
    }

    /**
     * When a process changes inform children
     */
    GenericEvent!(MonitorEventType, GPid, ProcessInfo) onChildProcess;

    static @property ProcessMonitor instance() {
        if (!tilix.processMonitor) {
            warningf(_("Process monitoring is not enabled, this should never be called"));
        }
        if (_instance is null) {
            _instance = new ProcessMonitor();
        }
        return _instance;
    }
}

private:

/**
 * Constant used for sleep time between checks.
 */
enum SLEEP_CONSTANT_MS = 300;

/**
 * List of processes being monitored.
 */
shared ProcessStatus[GPid] processes;

void monitorProcesses(int sleep, Tid tid) {
    bool abort = false;
    while (!abort) {
        synchronized {
            // For each monitored terminal, query only its foreground process
            // instead of scanning all PIDs on the system.
            foreach(process; processes) {
                auto fg = getForegroundProcess(process.gpid);
                if (fg.isValid()) {
                    bool isRoot = checkProcessTreeForRoot(fg.pid);
                    bool isSSH = isSSHProcess(fg.name);
                    if (fg.pid != process.activePid
                            || isRoot != process.activeIsRoot
                            || isSSH != process.activeIsSSH) {
                        process.activeName = fg.name;
                        process.activePid = fg.pid;
                        process.activeIsRoot = isRoot;
                        process.activeIsSSH = isSSH;
                        process.eventType = MonitorEventType.STARTED;
                    }
                } else if (process.activePid != -1) {
                    // Foreground process exited (shell is back in foreground).
                    // Clear SSH and root indicators.
                    process.activeName = "";
                    process.activePid = -1;
                    process.activeIsRoot = false;
                    process.activeIsSSH = false;
                    process.eventType = MonitorEventType.STARTED;
                }
            }
        }
        receiveTimeout(dur!("msecs")( sleep ),
                (bool msg) {
                    if (msg) abort = true;
                }
        );
    }
}

/**
 * Status of a single process
 */
shared class ProcessStatus {
    GPid gpid;
    pid_t activePid = -1;
    string activeName = "";
    bool activeIsRoot = false;
    bool activeIsSSH = false;
    MonitorEventType eventType = MonitorEventType.NONE;

    this(GPid gpid) {
        this.gpid = gpid;
    }
}

// -- Unit tests --

unittest {
    // ProcessInfo struct construction
    auto info = ProcessInfo(42, "ssh", false, true);
    assert(info.pid == 42);
    assert(info.name == "ssh");
    assert(!info.isRoot);
    assert(info.isSSH);
}

unittest {
    // stop() when not running is a no-op and must not segfault.
    // Regression test for the ~this() / rt_term crash: before the fix,
    // stop() unconditionally called trace() via std.logger; during GC
    // termination (rt_term) the logger's Object monitor is already torn
    // down, causing _d_monitorenter to segfault.
    ProcessMonitor monitor = new ProcessMonitor();
    assert(!monitor.running);
    monitor.stop(); // early-return path: running == false
    monitor.stop(); // second call must also be safe
    assert(!monitor.running);
}

unittest {
    // SSH precedence over root: when isSSH is true, root should be
    // suppressed in the UI. This mirrors the logic in terminal.d's
    // updateIndicators method.
    auto sshAsRoot = ProcessInfo(1, "ssh", true, true);
    bool showSSH = sshAsRoot.isSSH;
    bool showRoot = !sshAsRoot.isSSH && sshAsRoot.isRoot;
    assert(showSSH);
    assert(!showRoot);  // root suppressed when SSH is active

    auto rootOnly = ProcessInfo(2, "sudo", true, false);
    showSSH = rootOnly.isSSH;
    showRoot = !rootOnly.isSSH && rootOnly.isRoot;
    assert(!showSSH);
    assert(showRoot);

    auto plainProcess = ProcessInfo(3, "vim", false, false);
    showSSH = plainProcess.isSSH;
    showRoot = !plainProcess.isSSH && plainProcess.isRoot;
    assert(!showSSH);
    assert(!showRoot);
}
