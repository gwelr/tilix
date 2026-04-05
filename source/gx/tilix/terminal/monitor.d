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

import gx.tilix.application;

enum MonitorEventType {
    NONE,
    STARTED,
    CHANGED,
    FINISHED
};

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
                    onChildProcess.emit(process.eventType, process.gpid, process.activePid, process.activeName, process.activeIsRoot);
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
        stop();
    }

    void start() {
        running = true;
        tid = spawn(&monitorProcesses, SLEEP_CONSTANT_MS, thisTid);
        threadsAddTimeoutDelegate(SLEEP_CONSTANT_MS, &fireEvents);
        trace("Started process monitoring");
    }

    void stop() {
        if (running) tid.send(true);
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
    GenericEvent!(MonitorEventType, GPid, pid_t, string, bool) onChildProcess;

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

/**
 * Walk up the process tree from the given PID, checking if any
 * process has effective UID 0 (root). Stops at init (pid 1) or
 * when the process no longer exists.
 */
bool checkProcessTreeForRoot(pid_t startPid) {
    import std.conv : to;
    import std.file : read, exists;
    import std.format : format;
    import std.string : splitLines, startsWith, split;

    pid_t currentPid = startPid;
    for (int depth = 0; depth < 10; depth++) {
        if (currentPid <= 1) break;
        auto path = format("/proc/%d/status", currentPid);
        if (!exists(path)) break;
        try {
            string data = to!string(cast(char[]) read(path));
            pid_t ppid = 0;
            foreach (line; data.splitLines()) {
                if (line.startsWith("Uid:")) {
                    auto fields = line.split();
                    if (fields.length >= 3 && fields[2] == "0") {
                        return true;
                    }
                }
                if (line.startsWith("PPid:")) {
                    auto fields = line.split();
                    if (fields.length >= 2) {
                        ppid = to!pid_t(fields[1]);
                    }
                }
            }
            currentPid = ppid;
        } catch (Exception e) {
            break;
        }
    }
    return false;
}

void monitorProcesses(int sleep, Tid tid) {
    bool abort = false;
    while (!abort) {
        synchronized {
            // At this point we have a list of active processes of
            // all open terminals. We need to get these using shell
            // PID and will store them to raise events for each terminal.
            auto activeProcesses = getActiveProcessList();
            foreach(process; processes) {
                auto activeProcess  = activeProcesses.get(process.gpid, null);
                // No need to raise event for same process.
                if (activeProcess !is null) {
                    // Check if active process or any of its ancestors is root
                    bool isRoot = checkProcessTreeForRoot(activeProcess.pid);
                    if (activeProcess.pid != process.activePid || isRoot != process.activeIsRoot) {
                        process.activeName = activeProcess.name;
                        process.activePid = activeProcess.pid;
                        process.activeIsRoot = isRoot;
                        process.eventType = MonitorEventType.STARTED;
                    }
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
    MonitorEventType eventType = MonitorEventType.NONE;

    this(GPid gpid) {
        this.gpid = gpid;
    }
}
