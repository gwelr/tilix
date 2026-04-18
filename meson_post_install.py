#!/usr/bin/env python3
from os import environ, path
from subprocess import call

if not environ.get('DESTDIR', ''):
    PREFIX = environ.get('MESON_INSTALL_PREFIX', '/usr/local')
    DATA_DIR = path.join(PREFIX, 'share')
    ICONS_DIR = path.join(DATA_DIR, 'icons/hicolor')

    # gtk-update-icon-cache requires an index.theme file to recognize a
    # directory as an icon theme. When installing to a custom prefix like
    # /usr/local (default on most distros), this file doesn't exist.
    # Write a minimal index.theme that lists only the directories we
    # actually install into. Copying the system hicolor index.theme
    # wouldn't work because it references hundreds of directories that
    # don't exist at our prefix, and gtk-update-icon-cache validates them.
    index_theme = path.join(ICONS_DIR, 'index.theme')
    if not path.exists(index_theme):
        print(f'Installing icon theme index at {index_theme}')
        try:
            with open(index_theme, 'w') as f:
                f.write(
                    '[Icon Theme]\n'
                    'Name=Hicolor\n'
                    'Comment=Fallback icon theme\n'
                    'Hidden=true\n'
                    'Directories=scalable/apps,symbolic/apps\n'
                    '\n'
                    '[scalable/apps]\n'
                    'Size=48\n'
                    'MinSize=8\n'
                    'MaxSize=512\n'
                    'Type=Scalable\n'
                    'Context=Applications\n'
                    '\n'
                    '[symbolic/apps]\n'
                    'Size=16\n'
                    'MinSize=8\n'
                    'MaxSize=512\n'
                    'Type=Scalable\n'
                    'Context=Applications\n'
                )
        except PermissionError:
            print(f'Warning: could not write {index_theme} (need sudo?)')

    print('Updating icon cache...')
    call(['gtk-update-icon-cache', '-qtf', ICONS_DIR])
    print('Compiling new schemas')
    call(['glib-compile-schemas', path.join(DATA_DIR, 'glib-2.0/schemas/')])
    print('Updating desktop database')
    call(['update-desktop-database', path.join(DATA_DIR, 'applications')])
