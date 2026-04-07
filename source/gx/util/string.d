/*
 * This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not
 * distributed with this file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */

module gx.util.string;

import std.string;

/**
 * Escape a string to include a CSV according to the rules expected
 * by std.csv.
 */
string escapeCSV(string value) {
    if (value.length == 0) return value;
    value = value.replace("\"", "\"\"");
    if (value.indexOf('\n') >= 0 || value.indexOf(',')  >= 0 || value.indexOf("\"\"") >= 0) {
        value = "\"" ~ value ~ "\"";
    }
    return value;
}

unittest {
    assert(escapeCSV("test") == "test");
    assert(escapeCSV("gedit \"test\"") == "\"gedit \"\"test\"\"\"");
    assert(escapeCSV("test,this is") == "\"test,this is\"");
}

/// Test: escapeCSV with empty string
unittest {
    assert(escapeCSV("") == "");
}

/// Test: escapeCSV with newline — should be quoted
unittest {
    assert(escapeCSV("line1\nline2") == "\"line1\nline2\"");
}

/// Test: escapeCSV with no special characters — no quoting needed
unittest {
    assert(escapeCSV("simple text") == "simple text");
    assert(escapeCSV("12345") == "12345");
}

/// Test: escapeCSV with only quotes — doubles them and wraps
unittest {
    // Input: " (1 char). Step 1: " → "" (2 chars). Step 2: has "" → wrap: """" (4 chars).
    // In D string literals: each \" is one quote char, so 4 quotes = "\"\"\"\""
    assert(escapeCSV("\"") == "\"\"\"\"");
}

/// Test: escapeCSV with comma and quotes combined
unittest {
    string result = escapeCSV("a,\"b\"");
    // First: " → "" gives: a,""b""
    // Then: has comma and "" → wrapped: "a,""b"""
    assert(result == "\"a,\"\"b\"\"\"");
}