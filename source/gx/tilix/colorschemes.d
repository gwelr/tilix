/*
 * This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not
 * distributed with this file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */
module gx.tilix.colorschemes;

import std.algorithm;
import std.conv;
import std.experimental.logger;
import std.file;
import std.json;
import std.path;
import std.uuid;

import gdk.RGBA;

import glib.Util;

import gx.gtk.color;
import gx.gtk.util;
import gx.i18n.l10n;
import gx.tilix.constants;

enum SCHEMES_FOLDER = "schemes";

enum SCHEME_KEY_NAME = "name";
enum SCHEME_KEY_COMMENT = "comment";
enum SCHEME_KEY_FOREGROUND = "foreground-color";
enum SCHEME_KEY_BACKGROUND = "background-color";
enum SCHEME_KEY_PALETTE = "palette";
enum SCHEME_KEY_USE_THEME_COLORS = "use-theme-colors";
enum SCHEME_KEY_USE_HIGHLIGHT_COLOR = "use-highlight-color";
enum SCHEME_KEY_USE_CURSOR_COLOR = "use-cursor-color";
enum SCHEME_KEY_HIGHLIGHT_FG = "highlight-foreground-color";
enum SCHEME_KEY_HIGHLIGHT_BG = "highlight-background-color";
enum SCHEME_KEY_CURSOR_FG = "cursor-foreground-color";
enum SCHEME_KEY_CURSOR_BG = "cursor-background-color";
enum SCHEME_KEY_BADGE_FG = "badge-color";
enum SCHEME_KEY_USE_BADGE_COLOR = "use-badge-color";
enum SCHEME_KEY_BOLD_COLOR = "bold-color";
enum SCHEME_KEY_USE_BOLD_COLOR = "use-bold-color";

/**
  * A Tilix color scheme.
  *
  * Unlike gnome terminal, a color scheme in Tilix encompases both the fg/bg
  * and palette colors similar to what text editor color schemes typically
  * do.
  */
class ColorScheme {
    string id;
    string name;
    string comment;
    bool useThemeColors;
    bool useHighlightColor;
    bool useCursorColor;
    bool useBadgeColor;
    bool useBoldColor;
    RGBA foreground;
    RGBA background;
    RGBA highlightFG;
    RGBA highlightBG;
    RGBA cursorFG;
    RGBA cursorBG;
    RGBA badgeColor;
    RGBA boldColor;
    RGBA[16] palette;

    this() {
        id = randomUUID().toString();
        foreground = new RGBA();
        background = new RGBA();
        highlightFG = new RGBA();
        highlightBG = new RGBA();
        cursorFG = new RGBA();
        cursorBG = new RGBA();
        badgeColor = new RGBA();
        boldColor = new RGBA();

        for (int i = 0; i < 16; i++) {
            palette[i] = new RGBA();
        }
    }

    bool equalColor(ColorScheme scheme) {
        return equal(scheme, true);
    }

    bool equal(ColorScheme scheme, bool colorOnly) {
        import gx.gtk.util: equal;

        if (!colorOnly) {
            if (!(scheme.id == this.id && scheme.name == this.name && scheme.comment == this.comment))
                return false;
        }
        if (!(
                scheme.useThemeColors == this.useThemeColors &&
                scheme.useHighlightColor == this.useHighlightColor &&
                scheme.useCursorColor == this.useCursorColor &&
                scheme.useBadgeColor == this.useBadgeColor &&
                scheme.useBoldColor == this.useBoldColor &&
                scheme.palette.length == this.palette.length)) {

            return false;
        }
        if (!useThemeColors) {
            if (!(equal(scheme.background, this.background) &&
                 equal(scheme.foreground, this.foreground))) {
                     return false;
                 }
        }
        if (useHighlightColor) {
            if (!(equal(scheme.highlightFG, this.highlightFG) &&
                  equal(scheme.highlightBG, this.highlightBG))) {
                return false;
            }
        }
        if (useCursorColor) {
            if (!(  equal(scheme.cursorFG, this.cursorFG) &&
                    equal(scheme.cursorBG, this.cursorBG))) {
                return false;
            }
        }
        if (useBadgeColor) {
            if (!equal(scheme.badgeColor, this.badgeColor)) return false;
        }
        if (useBoldColor) {
            if (!equal(scheme.boldColor, this.boldColor)) return false;
        }
        foreach (index, color; palette) {
            if (!equal(color, scheme.palette[index])) {
                return false;
            }
        }
        return true;
    }

    override bool opEquals(Object o) {
        if (auto scheme = cast(ColorScheme) o) {
            return equal(scheme, false);
        }
        return false;
   }

   void save(string filename) {
       saveScheme(this, filename);
   }

   override string toString() {
       return schemeToJson(this).toPrettyString();
   }
}

/**
 * Finds a matching color scheme based on colors. This is used
 * in ProfilePreference since we don't store the selected color
 * scheme, just the colors chosen.
 */
int findSchemeByColors(ColorScheme[] schemes, ColorScheme scheme) {
    foreach (i, s; schemes) {
        if (scheme.equalColor(s))
            return to!int(i);
    }
    return -1;
}

/**
 * Loads the color schemes from disk.
 *
 * Paths are scanned user-first so user customizations win over system
 * defaults when a scheme with the same filename exists in both. Duplicate
 * filenames across paths are deduplicated; only the first occurrence is
 * loaded.
 */
ColorScheme[] loadColorSchemes() {
    ColorScheme[] schemes;
    bool[string] seenFilenames;
    // User config dir takes precedence over system data dirs
    string[] paths = Util.getUserConfigDir() ~ Util.getSystemDataDirs();
    foreach (path; paths) {
        auto fullpath = buildPath(path, APPLICATION_CONFIG_FOLDER, SCHEMES_FOLDER);
        trace("Loading color schemes from " ~ fullpath);
        if (exists(fullpath)) {
            DirEntry entry = DirEntry(fullpath);
            if (entry.isDir()) {
                auto files = dirEntries(fullpath, SpanMode.shallow).filter!(f => f.name.endsWith(".json"));
                foreach (string name; files) {
                    string basename = std.path.baseName(name);
                    if (basename in seenFilenames) {
                        trace("Skipping duplicate color scheme " ~ name ~ " (already loaded from user config)");
                        continue;
                    }
                    seenFilenames[basename] = true;
                    trace("Loading color scheme " ~ name);
                    try {
                        schemes ~= loadScheme(name);
                    }
                    catch (Exception e) {
                        errorf(_("File %s is not a color scheme compliant JSON file"), name);
                        error(e.msg);
                        error(e.info.toString());
                    }
                }
            }
        }
    }
    sort!("a.name < b.name")(schemes);
    return schemes;
}

/**
 * Loads a color scheme from a JSON file
 */
private ColorScheme loadScheme(string fileName) {
    ColorScheme cs = new ColorScheme();

    string content = readText(fileName);
    JSONValue root = parseJSON(content);
    cs.name = root[SCHEME_KEY_NAME].str();
    if (SCHEME_KEY_COMMENT in root) {
        cs.comment = root[SCHEME_KEY_COMMENT].str();
    }
    cs.useThemeColors = root[SCHEME_KEY_USE_THEME_COLORS].type == JSONType.true_;
    if (SCHEME_KEY_FOREGROUND in root) {
        parseColor(cs.foreground, root[SCHEME_KEY_FOREGROUND].str());
    }
    if (SCHEME_KEY_BACKGROUND in root) {
        parseColor(cs.background, root[SCHEME_KEY_BACKGROUND].str());
    }
    if (SCHEME_KEY_USE_HIGHLIGHT_COLOR in root) {
        cs.useHighlightColor = root[SCHEME_KEY_USE_HIGHLIGHT_COLOR].type == JSONType.true_;
    }
    if (SCHEME_KEY_USE_CURSOR_COLOR in root) {
        cs.useCursorColor = root[SCHEME_KEY_USE_CURSOR_COLOR].type == JSONType.true_;
    }
    if (SCHEME_KEY_USE_BADGE_COLOR in root) {
        cs.useBadgeColor = root[SCHEME_KEY_USE_BADGE_COLOR].type == JSONType.true_;
    }
    if (SCHEME_KEY_USE_BOLD_COLOR in root) {
        cs.useBoldColor = root[SCHEME_KEY_USE_BOLD_COLOR].type == JSONType.true_;
    }
    if (SCHEME_KEY_HIGHLIGHT_FG in root) {
        parseColor(cs.highlightFG, root[SCHEME_KEY_HIGHLIGHT_FG].str());
    }
    if (SCHEME_KEY_HIGHLIGHT_BG in root) {
        parseColor(cs.highlightBG, root[SCHEME_KEY_HIGHLIGHT_BG].str());
    }
    if (SCHEME_KEY_CURSOR_FG in root) {
        parseColor(cs.cursorFG, root[SCHEME_KEY_CURSOR_FG].str());
    }
    if (SCHEME_KEY_CURSOR_BG in root) {
        parseColor(cs.cursorBG, root[SCHEME_KEY_CURSOR_BG].str());
    }
    if (SCHEME_KEY_BADGE_FG in root) {
        parseColor(cs.badgeColor, root[SCHEME_KEY_BADGE_FG].str());
    }
    if (SCHEME_KEY_BOLD_COLOR in root) {
        parseColor(cs.boldColor, root[SCHEME_KEY_BOLD_COLOR].str());
    }
    JSONValue[] rawPalette = root[SCHEME_KEY_PALETTE].array();
    if (rawPalette.length != 16) {
        throw new Exception(_("Color scheme palette requires 16 colors"));
    }
    foreach (i, value; rawPalette) {
        parseColor(cs.palette[i], value.str());
    }
    return cs;
}

private JSONValue schemeToJson(ColorScheme scheme) {
    JSONValue root = [SCHEME_KEY_NAME : stripExtension(baseName(scheme.name)),
                      SCHEME_KEY_COMMENT: scheme.comment,
                      SCHEME_KEY_FOREGROUND: rgbaTo8bitHex(scheme.foreground, false, true),
                      SCHEME_KEY_BACKGROUND: rgbaTo8bitHex(scheme.background, false, true),
                      SCHEME_KEY_HIGHLIGHT_FG: rgbaTo8bitHex(scheme.highlightFG, false, true),
                      SCHEME_KEY_HIGHLIGHT_BG: rgbaTo8bitHex(scheme.highlightBG, false, true),
                      SCHEME_KEY_CURSOR_FG: rgbaTo8bitHex(scheme.cursorFG, false, true),
                      SCHEME_KEY_CURSOR_BG: rgbaTo8bitHex(scheme.cursorBG, false, true),
                      SCHEME_KEY_BADGE_FG: rgbaTo8bitHex(scheme.badgeColor, false, true),
                      SCHEME_KEY_BOLD_COLOR: rgbaTo8bitHex(scheme.boldColor, false, true)
                      ];
    root[SCHEME_KEY_USE_THEME_COLORS] = JSONValue(scheme.useThemeColors);
    root[SCHEME_KEY_USE_HIGHLIGHT_COLOR] = JSONValue(scheme.useHighlightColor);
    root[SCHEME_KEY_USE_CURSOR_COLOR] = JSONValue(scheme.useCursorColor);
    root[SCHEME_KEY_USE_BADGE_COLOR] = JSONValue(scheme.useBadgeColor);
    root[SCHEME_KEY_USE_BOLD_COLOR] = JSONValue(scheme.useBoldColor);

    string[] palette;
    foreach(color; scheme.palette) {
        palette ~= rgbaTo8bitHex(color, false, true);
    }
    root.object["palette"] = palette;
    return root;
}

private void saveScheme(ColorScheme scheme, string filename) {
    JSONValue value = schemeToJson(scheme);
    value[SCHEME_KEY_NAME] = stripExtension(baseName(filename));
    string json = value.toPrettyString();
    write(filename, json);
}

private void parseColor(RGBA rgba, string value) {
    if (value.length == 0)
        return;
    rgba.parse(value);
}

// --------------------------------------------------------------------------
// Unit tests for ColorScheme
//
// These tests exercise the pure-D logic: JSON parsing, serialization,
// color comparison, and scheme matching. They don't require a running
// GTK application — just the GtkD RGBA type for color representation.
// --------------------------------------------------------------------------

/// Helper: build a minimal valid scheme JSON string for testing.
/// This avoids depending on files on disk.
private string buildTestSchemeJson(
    string name = "Test",
    string fg = "#FFFFFF",
    string bg = "#000000",
    bool useThemeColors = false
) {
    import std.format : format;
    return format(`{
        "name": "%s",
        "comment": "test scheme",
        "use-theme-colors": %s,
        "foreground-color": "%s",
        "background-color": "%s",
        "palette": [
            "#000000", "#AA0000", "#00AA00", "#AA5500",
            "#0000AA", "#AA00AA", "#00AAAA", "#AAAAAA",
            "#555555", "#FF5555", "#55FF55", "#FFFF55",
            "#5555FF", "#FF55FF", "#55FFFF", "#FFFFFF"
        ]
    }`, name, useThemeColors ? "true" : "false", fg, bg);
}

/// Helper: load a ColorScheme from a JSON string by writing to a temp file.
/// We need this because loadScheme() reads from a file path.
private ColorScheme loadSchemeFromString(string json) {
    import std.file : write, remove, tempDir;
    import std.path : buildPath;
    string tmpFile = buildPath(tempDir(), "ttyx_test_scheme.json");
    write(tmpFile, json);
    scope(exit) remove(tmpFile);
    return loadScheme(tmpFile);
}

/// Test: load a minimal color scheme from JSON
unittest {
    auto cs = loadSchemeFromString(buildTestSchemeJson("Dracula", "#F8F8F2", "#282A36"));

    assert(cs.name == "Dracula");
    assert(cs.comment == "test scheme");
    assert(!cs.useThemeColors);

    // Verify foreground was parsed — RGBA stores as 0.0-1.0 floats.
    // #F8 = 248, 248/255 ≈ 0.9725. #F2 = 242, 242/255 ≈ 0.9490.
    // We use a tolerance check because float comparison is imprecise.
    assert(cs.foreground.red > 0.97 && cs.foreground.red < 0.98,
        "expected foreground red ≈ 0.973");
    assert(cs.foreground.green > 0.97 && cs.foreground.green < 0.98,
        "expected foreground green ≈ 0.973");
    assert(cs.foreground.blue > 0.94 && cs.foreground.blue < 0.96,
        "expected foreground blue ≈ 0.949");
}

/// Test: palette must have exactly 16 colors
unittest {
    import std.exception : assertThrown;

    string badJson = `{
        "name": "Bad",
        "use-theme-colors": false,
        "foreground-color": "#FFFFFF",
        "background-color": "#000000",
        "palette": ["#000000", "#111111"]
    }`;

    // assertThrown checks that the expression throws the given exception type.
    // This is D's idiomatic way to test error conditions.
    assertThrown!Exception(loadSchemeFromString(badJson));
}

/// Test: use-theme-colors flag is parsed correctly
unittest {
    auto cs1 = loadSchemeFromString(buildTestSchemeJson("A", "#FFF", "#000", false));
    assert(!cs1.useThemeColors);

    auto cs2 = loadSchemeFromString(buildTestSchemeJson("B", "#FFF", "#000", true));
    assert(cs2.useThemeColors);
}

/// Test: optional fields (highlight, cursor, badge, bold colors)
unittest {
    string json = `{
        "name": "Full",
        "comment": "all optional fields",
        "use-theme-colors": false,
        "foreground-color": "#FFFFFF",
        "background-color": "#000000",
        "use-highlight-color": true,
        "highlight-foreground-color": "#FF0000",
        "highlight-background-color": "#00FF00",
        "use-cursor-color": true,
        "cursor-foreground-color": "#0000FF",
        "cursor-background-color": "#FFFF00",
        "use-badge-color": true,
        "badge-color": "#FF00FF",
        "use-bold-color": true,
        "bold-color": "#00FFFF",
        "palette": [
            "#000000", "#AA0000", "#00AA00", "#AA5500",
            "#0000AA", "#AA00AA", "#00AAAA", "#AAAAAA",
            "#555555", "#FF5555", "#55FF55", "#FFFF55",
            "#5555FF", "#FF55FF", "#55FFFF", "#FFFFFF"
        ]
    }`;

    auto cs = loadSchemeFromString(json);
    assert(cs.useHighlightColor);
    assert(cs.useCursorColor);
    assert(cs.useBadgeColor);
    assert(cs.useBoldColor);

    // #FF0000 → red=1.0, green=0.0, blue=0.0
    assert(cs.highlightFG.red > 0.99);
    assert(cs.highlightFG.green < 0.01);

    // #0000FF → red=0.0, green=0.0, blue=1.0
    assert(cs.cursorFG.blue > 0.99);
    assert(cs.cursorFG.red < 0.01);
}

/// Test: JSON round-trip (load → toJson → load again → compare)
unittest {
    string json = buildTestSchemeJson("RoundTrip", "#AABBCC", "#112233");
    auto original = loadSchemeFromString(json);

    // Convert back to JSON, then reload
    JSONValue jsonValue = schemeToJson(original);
    string rewritten = jsonValue.toPrettyString();
    auto reloaded = loadSchemeFromString(rewritten);

    // The palette should survive the round-trip exactly
    foreach (i; 0 .. 16) {
        assert(original.palette[i].equal(reloaded.palette[i]),
            "palette color mismatch at index " ~ to!string(i));
    }
    // FG/BG should survive too
    assert(original.foreground.equal(reloaded.foreground));
    assert(original.background.equal(reloaded.background));
}

/// Test: ColorScheme.equal — identical schemes
unittest {
    string json = buildTestSchemeJson("Same", "#FFFFFF", "#000000");
    auto a = loadSchemeFromString(json);
    auto b = loadSchemeFromString(json);

    // Different id (randomUUID) but same colors — equalColor should match
    assert(a.equalColor(b), "identical color schemes should be equalColor");

    // Full equal (including id/name) won't match because IDs differ
    // (each loadScheme generates a new randomUUID)
    assert(!a.equal(b, false), "different IDs should fail full equality");
}

/// Test: ColorScheme.equal — different foreground color
unittest {
    auto a = loadSchemeFromString(buildTestSchemeJson("A", "#FFFFFF", "#000000"));
    auto b = loadSchemeFromString(buildTestSchemeJson("B", "#AAAAAA", "#000000"));

    // useThemeColors is false, so fg/bg are compared
    assert(!a.equalColor(b), "different foreground should not match");
}

/// Test: ColorScheme.equal — useThemeColors skips fg/bg comparison
unittest {
    // When useThemeColors is true, fg/bg colors are ignored in comparison
    auto a = loadSchemeFromString(buildTestSchemeJson("A", "#FFFFFF", "#000000", true));
    auto b = loadSchemeFromString(buildTestSchemeJson("B", "#AAAAAA", "#333333", true));

    // Despite different fg/bg, equalColor should match because
    // useThemeColors=true means fg/bg come from the GTK theme, not the scheme
    assert(a.equalColor(b),
        "with useThemeColors=true, fg/bg differences should be ignored");
}

/// Test: findSchemeByColors
unittest {
    auto dracula = loadSchemeFromString(buildTestSchemeJson("Dracula", "#F8F8F2", "#282A36"));
    auto monokai = loadSchemeFromString(buildTestSchemeJson("Monokai", "#F8F8F0", "#272822"));
    auto schemes = [dracula, monokai];

    // Search for a scheme matching Dracula's colors
    auto needle = loadSchemeFromString(buildTestSchemeJson("X", "#F8F8F2", "#282A36"));
    int idx = findSchemeByColors(schemes, needle);
    assert(idx == 0, "should find Dracula at index 0");

    // Search for a scheme that doesn't exist
    auto unknown = loadSchemeFromString(buildTestSchemeJson("X", "#123456", "#654321"));
    int idx2 = findSchemeByColors(schemes, unknown);
    assert(idx2 == -1, "should return -1 for no match");
}

/// Test: parseColor with empty string should not crash
unittest {
    RGBA color = new RGBA();
    parseColor(color, "");
    // Should not crash — color remains at default (0,0,0,0)
    assert(color.red == 0.0);
}

/// Test: parseColor with valid hex
unittest {
    RGBA color = new RGBA();
    parseColor(color, "#FF0000");
    assert(color.red > 0.99);
    assert(color.green < 0.01);
    assert(color.blue < 0.01);
}
