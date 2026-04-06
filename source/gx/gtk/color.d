/*
 * This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not
 * distributed with this file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */

module gx.gtk.color;

import std.conv;
import std.experimental.logger;
import std.format;

import gdk.RGBA;

public:

/**
 * Converts an RGBA structure to a 8 bit HEX string, i.e #2E3436
 *
 * Params:
 * RGBA	 = The color to convert
 * includeAlpha = Whether to include the alpha channel
 * includeHash = Whether to preface the color string with a #
 */
string rgbaTo8bitHex(RGBA color, bool includeAlpha = false, bool includeHash = false) {
    string prepend = includeHash ? "#" : "";
    int red = to!(int)(color.red() * 255);
    int green = to!(int)(color.green() * 255);
    int blue = to!(int)(color.blue() * 255);
    if (includeAlpha) {
        int alpha = to!(int)(color.alpha() * 255);
        return prepend ~ format("%02X%02X%02X%02X", red, green, blue, alpha);
    } else {
        return prepend ~ format("%02X%02X%02X", red, green, blue);
    }
}

/**
 * Converts an RGBA structure to a 16 bit HEX string, i.e #2E2E34343636
 * Right now this just takes an 8 bit string and repeats each channel
 *
 * Params:
 * RGBA	 = The color to convert
 * includeAlpha = Whether to include the alpha channel
 * includeHash = Whether to preface the color string with a #
 */
string rgbaTo16bitHex(RGBA color, bool includeAlpha = false, bool includeHash = false) {
    string prepend = includeHash ? "#" : "";
    int red = to!(int)(color.red() * 255);
    int green = to!(int)(color.green() * 255);
    int blue = to!(int)(color.blue() * 255);
    if (includeAlpha) {
        int alpha = to!(int)(color.alpha() * 255);
        return prepend ~ format("%02X%02X%02X%02X%02X%02X%02X%02X", red, red, green, green, blue, blue, alpha, alpha);
    } else {
        return prepend ~ format("%02X%02X%02X%02X%02X%02X", red, red, green, green, blue, blue);
    }
}

RGBA getOppositeColor(RGBA rgba) {
    RGBA result = new RGBA(1.0 - rgba.red, 1 - rgba.green, 1 - rgba.blue, rgba.alpha);
    tracef("Original: %s, New: %s", rgbaTo8bitHex(rgba, true, true), rgbaTo8bitHex(result, true, true));
    return result;
}

void contrast(double percent, RGBA rgba, out double r, out double g, out double b) {
    double brightness = ((rgba.red * 299.0) + (rgba.green * 587.0) + (rgba.blue * 114.0)) / 1000;
    if (brightness > 0.5) darken(percent, rgba, r, g, b);
    else lighten(percent, rgba, r, g, b);
}

void lighten(double percent, RGBA rgba, out double r, out double g, out double b) {
    adjustColor(percent, rgba, r, g, b);
}

void darken(double percent, RGBA rgba, out double r, out double g, out double b) {
    adjustColor(-percent, rgba, r, g, b);
}

void adjustColor(double cf, RGBA rgba, out double r, out double g, out double b) {
    if (cf < 0) {
        cf = 1 + cf;
        r = rgba.red * cf;
        g = rgba.green * cf;
        b = rgba.blue * cf;
    } else {
        r = (1 - rgba.red) * cf + rgba.red;
        g = (1 - rgba.green) * cf + rgba.green;
        b = (1 - rgba.blue) * cf + rgba.blue;
    }
}

void desaturate(double percent, RGBA rgba, out double r, out double g, out double b) {
    tracef("desaturate: %f, %f, %f, %f", percent, rgba.red, rgba.green, rgba.blue);
    double L = 0.3 * rgba.red + 0.6 * rgba.green + 0.1 * rgba.blue;
    r = rgba.red + percent * (L - rgba.red);
    g = rgba.green + percent * (L - rgba.green);
    b = rgba.blue + percent * (L - rgba.blue);
    tracef("Desaturated color: %f, %f, %f", r, g, b);
}

// --------------------------------------------------------------------------
// Unit tests for color utilities
// --------------------------------------------------------------------------

/// Helper: compare doubles with a tolerance.
/// Floating-point arithmetic is inherently imprecise, so we never use
/// `assert(x == y)` for doubles. Instead we check `abs(x - y) < epsilon`.
private bool approx(double a, double b, double eps = 0.01) {
    import std.math : abs;
    return abs(a - b) < eps;
}

/// Test: rgbaTo8bitHex basic conversion
unittest {
    // Pure red: RGBA(1.0, 0.0, 0.0)
    auto red = new RGBA(1.0, 0.0, 0.0, 1.0);
    assert(rgbaTo8bitHex(red) == "FF0000");
    assert(rgbaTo8bitHex(red, false, true) == "#FF0000");
    assert(rgbaTo8bitHex(red, true, true) == "#FF0000FF");
}

/// Test: rgbaTo8bitHex with mid-range colors
unittest {
    // RGBA(0.5, 0.5, 0.5) → each channel = 127 = 0x7F
    auto grey = new RGBA(0.5, 0.5, 0.5, 1.0);
    string hex = rgbaTo8bitHex(grey, false, true);
    // 0.5 * 255 = 127.5, truncated to 127 = 0x7F
    assert(hex == "#7F7F7F", "got: " ~ hex);
}

/// Test: rgbaTo8bitHex black and white
unittest {
    auto black = new RGBA(0.0, 0.0, 0.0, 1.0);
    assert(rgbaTo8bitHex(black, false, true) == "#000000");

    auto white = new RGBA(1.0, 1.0, 1.0, 1.0);
    assert(rgbaTo8bitHex(white, false, true) == "#FFFFFF");
}

/// Test: rgbaTo16bitHex doubles each byte
unittest {
    auto red = new RGBA(1.0, 0.0, 0.0, 1.0);
    // 16-bit doubles each channel: FF → FFFF, 00 → 0000
    assert(rgbaTo16bitHex(red, false, true) == "#FFFF00000000");
}

/// Test: getOppositeColor inverts RGB, preserves alpha
unittest {
    auto color = new RGBA(0.2, 0.3, 0.4, 0.8);
    auto opposite = getOppositeColor(color);

    assert(approx(opposite.red, 0.8));
    assert(approx(opposite.green, 0.7));
    assert(approx(opposite.blue, 0.6));
    assert(approx(opposite.alpha, 0.8));
}

/// Test: lighten increases RGB values toward 1.0
unittest {
    auto color = new RGBA(0.4, 0.2, 0.6, 1.0);
    double r, g, b;
    lighten(0.5, color, r, g, b);

    // Lightening by 50%: new = (1 - old) * 0.5 + old
    // red:   (1 - 0.4) * 0.5 + 0.4 = 0.7
    // green: (1 - 0.2) * 0.5 + 0.2 = 0.6
    // blue:  (1 - 0.6) * 0.5 + 0.6 = 0.8
    assert(approx(r, 0.7));
    assert(approx(g, 0.6));
    assert(approx(b, 0.8));
}

/// Test: darken decreases RGB values toward 0.0
unittest {
    auto color = new RGBA(0.4, 0.2, 0.6, 1.0);
    double r, g, b;
    darken(0.5, color, r, g, b);

    // Darkening by 50%: cf = 1 - 0.5 = 0.5, new = old * 0.5
    // red:   0.4 * 0.5 = 0.2
    // green: 0.2 * 0.5 = 0.1
    // blue:  0.6 * 0.5 = 0.3
    assert(approx(r, 0.2));
    assert(approx(g, 0.1));
    assert(approx(b, 0.3));
}

/// Test: contrast auto-selects lighten or darken based on brightness
unittest {
    // Dark color (brightness < 0.5) → should lighten
    auto dark = new RGBA(0.1, 0.1, 0.1, 1.0);
    double r, g, b;
    contrast(0.3, dark, r, g, b);
    assert(r > 0.1 && g > 0.1 && b > 0.1, "dark color should be lightened");

    // Light color (brightness > 0.5) → should darken
    auto light = new RGBA(0.9, 0.9, 0.9, 1.0);
    contrast(0.3, light, r, g, b);
    assert(r < 0.9 && g < 0.9 && b < 0.9, "light color should be darkened");
}

/// Test: desaturate moves colors toward grey
unittest {
    auto color = new RGBA(1.0, 0.0, 0.0, 1.0);  // pure red
    double r, g, b;
    desaturate(1.0, color, r, g, b);

    // Full desaturation (100%): all channels become the luminance L.
    // L = 0.3*1.0 + 0.6*0.0 + 0.1*0.0 = 0.3
    assert(approx(r, 0.3));
    assert(approx(g, 0.3));
    assert(approx(b, 0.3));
}

/// Test: desaturate at 0% leaves color unchanged
unittest {
    auto color = new RGBA(0.8, 0.4, 0.2, 1.0);
    double r, g, b;
    desaturate(0.0, color, r, g, b);

    assert(approx(r, 0.8));
    assert(approx(g, 0.4));
    assert(approx(b, 0.2));
}