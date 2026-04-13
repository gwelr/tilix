/*
 * This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not
 * distributed with this file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */
module gx.tilix.terminal.spawn;

private:

import std.algorithm : canFind;
import std.conv : to;
import std.experimental.logger;
import std.format : format;
import std.process : environment;
import std.string : split, startsWith;

import gio.Settings : GSettings = Settings;

import gx.tilix.terminal.flatpak : captureHostToolboxCommand;
import gx.tilix.terminal.util : isFlatpak;
import gx.tilix.preferences;

package:

/**
 * Get the user's shell from the host system when running inside a Flatpak sandbox.
 *
 * In a Flatpak environment, VTE's getUserShell() returns the shell inside the sandbox,
 * not the user's actual shell. This function uses the Flatpak toolbox helper to read
 * the host's /etc/passwd entry and extract the login shell.
 *
 * Returns null if the host shell cannot be determined.
 */
string getHostShell() {
    import core.sys.posix.unistd : getuid;

    string uid = to!string(getuid());
    tracef("Asking toolbox for shell", uid);

    string passwd = captureHostToolboxCommand("get-passwd", to!string(uid), []);

    if (passwd == null) {
        warning("Failed to get host passwd entry");
        return null;
    }

    string shell = passwd.split(":")[6];
    if (shell.length == 0) {
        warning("Host shell is empty from passwd: %s", passwd);
        return null;
    }

    return shell.length > 0 ? shell : null;
}

/**
 * Set proxy environment variables from GNOME's proxy settings.
 *
 * Reads the system proxy configuration (http, https, ftp, socks) from
 * GSettings and adds the corresponding environment variables (http_proxy,
 * https_proxy, ftp_proxy, all_proxy, no_proxy) to the provided array.
 *
 * Only applies when proxy mode is "manual" and the proxy env setting is enabled.
 *
 * Params:
 *   gsSettings = Global application settings to check if proxy env is enabled.
 *   gsProxy = GNOME proxy settings (org.gnome.system.proxy), may be null.
 *   envv = Environment variable array to append proxy vars to.
 */
void setProxyEnv(GSettings gsSettings, GSettings gsProxy, ref string[] envv) {

    void addProxy(GSettings proxy, string scheme, string urlScheme, string varName) {
        GSettings gsProxyScheme = proxy.getChild(scheme);

        string host = gsProxyScheme.getString("host");
        int port = gsProxyScheme.getInt("port");
        if (host.length == 0 || port == 0) return;

        // Strip protocol prefix if already present in the host value
        foreach (prefix; ["http://", "https://", "socks://", "ftp://"]) {
            if (host.startsWith(prefix)) {
                host = host[prefix.length .. $];
                break;
            }
        }

        string value = urlScheme ~ "://";
        if (scheme == "http") {
            if (gsProxyScheme.getBoolean("use-authentication")) {
                string user = gsProxyScheme.getString("authentication-user");
                string pw = gsProxyScheme.getString("authentication-password");
                if (user.length > 0) {
                    value = value ~ "@" ~ user;
                    if (pw.length > 0) {
                        value = value ~ ":" ~ pw;
                    }
                    value = value ~ "@";
                }
            }
        }

        value = value ~ format("%s:%d/", host, port);
        envv ~= format("%s=%s", varName, value);
    }

    if (!gsSettings.getBoolean(SETTINGS_SET_PROXY_ENV_KEY)) return;

    if (gsProxy is null) return;
    if (gsProxy.getString("mode") != "manual") return;
    addProxy(gsProxy, "http", "http", "http_proxy");
    addProxy(gsProxy, "https", "http", "https_proxy");
    addProxy(gsProxy, "ftp", "http", "ftp_proxy");
    addProxy(gsProxy, "socks", "socks", "all_proxy");

    import std.string : join;
    string[] ignore = gsProxy.getStrv("ignore-hosts");
    if (ignore.length > 0) {
        envv ~= "no_proxy=" ~ join(ignore, ",");
    }
}
