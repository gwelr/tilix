/*
 * This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not
 * distributed with this file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */

module gx.util.redact;

import std.regex : regex, replaceAll;
import std.string : indexOf, toLower;

enum string REDACTED = "[redacted]";

private immutable string[] SENSITIVE_KEY_FRAGMENTS = [
    "password", "passwd", "token", "secret", "api_key", "apikey",
    "auth", "credential",
];

private immutable string[] PROXY_KEY_FRAGMENTS = [
    "proxy",
];

/**
 * Redact sensitive portions of an environment variable value for logging.
 *
 * - Keys containing a password/token/secret/auth fragment have the whole
 *   value replaced with a placeholder.
 * - Keys containing "proxy" have the userinfo segment of any URL-shaped
 *   value stripped, keeping `scheme://host[:port]/...` so the log remains
 *   useful for debugging connectivity.
 * - Other keys pass through unchanged.
 *
 * Matching is case-insensitive and fragment-based: both `HTTP_PROXY` and
 * `http_proxy`, both `API_TOKEN` and `apikey`, are recognized.
 */
string redactSensitive(string key, string value) {
    if (value.length == 0) return value;

    string lowerKey = key.toLower;

    foreach (fragment; SENSITIVE_KEY_FRAGMENTS) {
        if (lowerKey.indexOf(fragment) >= 0) return REDACTED;
    }

    foreach (fragment; PROXY_KEY_FRAGMENTS) {
        if (lowerKey.indexOf(fragment) >= 0) return stripUrlUserinfo(value);
    }

    return value;
}

/**
 * Remove the userinfo segment (user:password@) from a URL-shaped string.
 * If the input is not URL-shaped or contains no userinfo, it is returned
 * verbatim.
 */
string stripUrlUserinfo(string url) {
    // scheme://userinfo@rest  -->  scheme://rest
    static auto re = regex(r"^([a-zA-Z][a-zA-Z0-9+.-]*://)[^/@]+@");
    return url.replaceAll(re, "$1");
}

// -- tests --------------------------------------------------------------

unittest {
    assert(redactSensitive("PATH", "/usr/bin:/bin") == "/usr/bin:/bin");
    assert(redactSensitive("HOME", "/home/user") == "/home/user");
    assert(redactSensitive("SHELL", "/bin/bash") == "/bin/bash");
}

unittest {
    assert(redactSensitive("PASSWORD", "hunter2") == REDACTED);
    assert(redactSensitive("MY_PASSWD", "x") == REDACTED);
    assert(redactSensitive("API_TOKEN", "abcd") == REDACTED);
    assert(redactSensitive("github_token", "ghp_...") == REDACTED);
    assert(redactSensitive("CLIENT_SECRET", "shh") == REDACTED);
    assert(redactSensitive("API_KEY", "k") == REDACTED);
    assert(redactSensitive("BASIC_AUTH", "dXNlcjpwdw==") == REDACTED);
}

unittest {
    // Empty value: no-op even for sensitive keys.
    assert(redactSensitive("PASSWORD", "") == "");
}

unittest {
    // Proxy URL with credentials: userinfo is stripped, host/port retained.
    assert(redactSensitive("http_proxy", "http://user:pw@proxy.local:8080/")
        == "http://proxy.local:8080/");
    assert(redactSensitive("HTTPS_PROXY", "https://alice:secret@proxy.corp:3128/")
        == "https://proxy.corp:3128/");
    assert(redactSensitive("all_proxy", "socks://u:p@s.example:1080/")
        == "socks://s.example:1080/");
}

unittest {
    // Proxy URL without credentials is preserved as-is.
    assert(redactSensitive("http_proxy", "http://proxy.local:8080/")
        == "http://proxy.local:8080/");
    // no_proxy is a comma list, not a URL — must not be mangled.
    assert(redactSensitive("no_proxy", "localhost,127.0.0.1,.corp")
        == "localhost,127.0.0.1,.corp");
}

unittest {
    // Non-URL value with a proxy-shaped key is returned untouched by the
    // strip (no regex match), so the fragment policy degrades safely.
    assert(stripUrlUserinfo("not-a-url") == "not-a-url");
    assert(stripUrlUserinfo("") == "");
    assert(stripUrlUserinfo("http://host/path") == "http://host/path");
}
