/*
 * This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not
 * distributed with this file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */
module gx.util.path;

import std.path;
import std.process;
import std.string;

/**
 * Resolves the path by converting tilde and environment
 * variables in the path.
 */
string resolvePath(string path) {
    string result = expandTilde(path);
    string[string] env = environment.toAA();
    foreach(name; env.keys) {
        result = result.replace('$' ~ name, env[name]);
        result = result.replace("${" ~ name ~ "}", env[name]);
    }
    return result;
}

// --------------------------------------------------------------------------
// Unit tests for path utilities
// --------------------------------------------------------------------------

/// Test: tilde expansion resolves to HOME
unittest {
    // expandTilde is from std.path — it replaces ~ with $HOME.
    // Since resolvePath calls expandTilde first, ~/foo should
    // become /home/user/foo (or whatever HOME is set to).
    string home = environment.get("HOME", "");
    if (home.length > 0) {
        string result = resolvePath("~/Documents");
        assert(result == home ~ "/Documents",
            "expected " ~ home ~ "/Documents, got " ~ result);
    }
}

/// Test: environment variable substitution with $VAR syntax
unittest {
    string home = environment.get("HOME", "");
    if (home.length > 0) {
        string result = resolvePath("$HOME/test");
        assert(result == home ~ "/test",
            "expected " ~ home ~ "/test, got " ~ result);
    }
}

/// Test: environment variable substitution with ${VAR} syntax
unittest {
    string home = environment.get("HOME", "");
    if (home.length > 0) {
        string result = resolvePath("${HOME}/test");
        assert(result == home ~ "/test",
            "expected " ~ home ~ "/test, got " ~ result);
    }
}

/// Test: absolute path without variables passes through unchanged
unittest {
    string result = resolvePath("/usr/bin/tilix");
    assert(result == "/usr/bin/tilix");
}

/// Test: empty string returns empty
unittest {
    string result = resolvePath("");
    assert(result == "");
}
