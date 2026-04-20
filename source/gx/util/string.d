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

/**
 * Parse a `pairSep`-delimited string of `kvSep`-separated key=value
 * pairs into a map. Whitespace around keys and values is trimmed.
 * Chunks without a `kvSep` are silently skipped. Duplicate keys: the
 * last occurrence wins.
 *
 * Example: `parsePairs("a=1;b=2")` → `["a": "1", "b": "2"]`.
 */
string[string] parsePairs(string input, string pairSep = ";", string kvSep = "=") {
    string[string] result;
    if (input.length == 0) return result;
    foreach (chunk; input.split(pairSep)) {
        ptrdiff_t idx = chunk.indexOf(kvSep);
        if (idx < 0) continue;
        string key = chunk[0 .. idx].strip();
        string value = chunk[idx + kvSep.length .. $].strip();
        result[key] = value;
    }
    return result;
}

/// Test: single and multiple pairs, default separators.
unittest {
    string[string] m = parsePairs("a=1");
    assert(m.length == 1 && m["a"] == "1");

    m = parsePairs("a=1;b=2;c=3");
    assert(m.length == 3);
    assert(m["a"] == "1" && m["b"] == "2" && m["c"] == "3");
}

/// Test: whitespace around keys and values is trimmed.
unittest {
    string[string] m = parsePairs("  a  = 1 ; b=  foo bar  ");
    assert(m["a"] == "1");
    assert(m["b"] == "foo bar"); // internal whitespace preserved
}

/// Test: chunks without a kvSep are skipped silently.
unittest {
    string[string] m = parsePairs("a=1;broken;b=2");
    assert(m.length == 2);
    assert(m["a"] == "1" && m["b"] == "2");
}

/// Test: empty input and degenerate shapes.
unittest {
    assert(parsePairs("").length == 0);
    assert(parsePairs(";;;").length == 0);
    string[string] m = parsePairs("=value");  // empty key retained
    assert(m.length == 1 && m[""] == "value");
    m = parsePairs("key=");         // empty value retained
    assert(m.length == 1 && m["key"] == "");
}

/// Test: trailing/leading separator is tolerated.
unittest {
    string[string] m = parsePairs(";a=1;b=2;");
    assert(m.length == 2);
    assert(m["a"] == "1" && m["b"] == "2");
}

/// Test: duplicate keys — last wins.
unittest {
    string[string] m = parsePairs("a=1;a=2;a=3");
    assert(m["a"] == "3");
}

/// Test: the value may itself contain `=`; only the first separator splits.
unittest {
    string[string] m = parsePairs("url=http://x.example/?q=1&r=2");
    assert(m["url"] == "http://x.example/?q=1&r=2");
}

/// Test: custom separators (non-default).
unittest {
    string[string] m = parsePairs("a:1,b:2,c:3", ",", ":");
    assert(m.length == 3);
    assert(m["a"] == "1" && m["b"] == "2" && m["c"] == "3");
}

/// Test: multi-character separators (verifies kvSep.length is used, not +1).
unittest {
    string[string] m = parsePairs("a => 1 || b => 2", "||", "=>");
    assert(m.length == 2);
    assert(m["a"] == "1" && m["b"] == "2");
}

/// Test: regression anchor — the old nested getParameters used
/// `pair.length == 2` after split("="), which dropped any input
/// containing two or more `=` characters. parsePairs preserves such
/// inputs by splitting at the first kvSep only.
unittest {
    string[string] m = parsePairs("a==b");
    assert(m.length == 1);
    assert(m["a"] == "=b");
}