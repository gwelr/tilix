---
title: VTE Configuration
parent: Manual
nav_order: 9
layout: default
---

## Background

ttyx_ uses a GTK+ 3 widget called **VTE** (Virtual Terminal Emulator), originally built as the back-end for GNOME Terminal and now used by most GTK-based terminal emulators including ttyx_.

VTE relies on a helper script — typically `/etc/profile.d/vte.sh` — to hook the shell's `PROMPT_COMMAND` and emit terminal control codes that tell the emulator what directory the shell is in. Earlier VTE versions read this from `/proc/<pid>/cwd`, but that approach had [reliability issues](https://bugzilla.gnome.org/show_bug.cgi?id=697475), so VTE moved to the script-based approach.

The catch: different distributions treat `/etc/profile.d/` differently. On Fedora, scripts there run for both login and non-login shells; on Ubuntu and Arch, they only run for login shells. Since most terminal emulators — including ttyx_ — don't launch shells as login shells by default, the VTE hook never fires.

## Impact

When the VTE helper doesn't run, the current directory stops being reported. Concretely: splitting a terminal in ttyx_ opens the split in your home directory instead of inheriting the parent's cwd.

## Fixing it

Pick whichever is easiest.

### Option 1 — Use the bundled ttyx_ integration script

ttyx_ ships its own integration script at `/usr/share/ttyx/scripts/ttyx_int.sh` that does the same job as `vte.sh`: it hooks `PROMPT_COMMAND` to emit OSC 7 sequences telling the emulator the shell's cwd. Source it from your rc file:

{% highlight bash %}
# ~/.bashrc or ~/.zshrc
. /usr/share/ttyx/scripts/ttyx_int.sh
{% endhighlight %}

This is also the recommended approach for [remote hosts over SSH]({{ site.baseurl }}/manual/profileswitch/#remote-configuration).

### Option 2 — Source vte.sh manually

Add this to `~/.bashrc` (or `~/.zshrc`):

{% highlight bash %}
if [ "$TTYX_ID" ] || [ "$TILIX_ID" ] || [ "$VTE_VERSION" ]; then
    source /etc/profile.d/vte.sh
fi
{% endhighlight %}

On older Ubuntu releases a symlink may be missing:

{% highlight bash %}
sudo ln -s /etc/profile.d/vte-2.91.sh /etc/profile.d/vte.sh
{% endhighlight %}

If you use a custom `PROMPT_COMMAND` instead of simply overriding `PS1`, your `PROMPT_COMMAND` needs to append working-directory information. Calling `__vte_osc7` (defined by `vte-2.91.sh`) does this:

{% highlight bash %}
function custom_prompt() {
  __git_ps1 "\[\033[0;31m\]\u \[\033[0;36m\]\h:\w\[\033[00m\]" " \n\[\033[0;31m\]>\[\033[00m\] " " %s"
  VTE_PWD_THING="$(__vte_osc7)"
  PS1="$PS1$VTE_PWD_THING"
}
PROMPT_COMMAND=custom_prompt
{% endhighlight %}

### Option 3 — Run the shell as a login shell

Enable **Preferences → Profile → Command → Run command as login shell**. Login shells run `/etc/profile.d/*` scripts on any distribution, so this fixes the issue at the cost of running your full login environment every time you open a terminal.
