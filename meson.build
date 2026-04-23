project(
    'ttyx', 'd',
    version: '1.1.2',
    license: 'MPL-2.0',
    meson_version: '>= 0.56'
)

compiler = meson.get_compiler('d')
if compiler.get_id() == 'llvm'
  d_extra_args = ['-vcolumns']
  d_link_args = []
else
  d_extra_args = []
  d_link_args = []
endif

# In release builds (debug=false), add D-specific '-release' flag to disable
# runtime bounds checks and contract assertions for better performance.
if not get_option('debug')
  d_extra_args += ['-release']
endif

project_id = 'io.github.gwelr.ttyx'
project_name = meson.project_name()

gnome = import('gnome')
i18n = import('i18n')

prefix = get_option('prefix')
bindir = prefix / get_option('bindir')
datadir = prefix / get_option('datadir')
pkgdatadir = datadir / project_name.to_lower()
schemadir = datadir / 'glib-2.0' / 'schemas'
iconsdir = datadir / 'icons' / 'hicolor'
appdir = datadir / 'applications'

ttyx_sources = [
    'source/gx/gtk/actions.d',
    'source/gx/gtk/cairo.d',
    'source/gx/gtk/clipboard.d',
    'source/gx/gtk/color.d',
    'source/gx/gtk/dialog.d',
    'source/gx/gtk/resource.d',
    'source/gx/gtk/settings.d',
    'source/gx/gtk/threads.d',
    'source/gx/gtk/util.d',
    'source/gx/gtk/vte.d',
    'source/gx/gtk/x11.d',
    'source/gx/i18n/l10n.d',
    'source/gx/ttyx/bookmark/bmchooser.d',
    'source/gx/ttyx/bookmark/bmeditor.d',
    'source/gx/ttyx/bookmark/bmtreeview.d',
    'source/gx/ttyx/bookmark/manager.d',
    'source/gx/ttyx/prefeditor/advdialog.d',
    'source/gx/ttyx/prefeditor/bookmarkeditor.d',
    'source/gx/ttyx/prefeditor/common.d',
    'source/gx/ttyx/prefeditor/prefdialog.d',
    'source/gx/ttyx/prefeditor/profileeditor.d',
    'source/gx/ttyx/prefeditor/titleeditor.d',
    'source/gx/ttyx/terminal/actions.d',
    'source/gx/ttyx/terminal/activeprocess.d',
    'source/gx/ttyx/terminal/advpaste.d',
    'source/gx/ttyx/terminal/exvte.d',
    'source/gx/ttyx/terminal/layout.d',
    'source/gx/ttyx/terminal/monitor.d',
    'source/gx/ttyx/terminal/password.d',
    'source/gx/ttyx/terminal/process.d',
    'source/gx/ttyx/terminal/clipboard.d',
    'source/gx/ttyx/terminal/context.d',
    'source/gx/ttyx/terminal/flatpak.d',
    'source/gx/ttyx/terminal/regex.d',
    'source/gx/ttyx/terminal/renderer.d',
    'source/gx/ttyx/terminal/search.d',
    'source/gx/ttyx/terminal/spawn.d',
    'source/gx/ttyx/terminal/state.d',
    'source/gx/ttyx/terminal/terminal.d',
    'source/gx/ttyx/terminal/test_integration.d',
    'source/gx/ttyx/terminal/types.d',
    'source/gx/ttyx/terminal/util.d',
    'source/gx/ttyx/application.d',
    'source/gx/ttyx/appwindow.d',
    'source/gx/ttyx/closedialog.d',
    'source/gx/ttyx/cmdparams.d',
    'source/gx/ttyx/colorschemes.d',
    'source/gx/ttyx/common.d',
    'source/gx/ttyx/constants.d',
    'source/gx/ttyx/customtitle.d',
    'source/gx/ttyx/encoding.d',
    'source/gx/ttyx/preferences.d',
    'source/gx/ttyx/session.d',
    'source/gx/ttyx/shortcuts.d',
    'source/gx/ttyx/sidebar.d',
    'source/gx/util/array.d',
    'source/gx/util/geometry.d',
    'source/gx/util/path.d',
    'source/gx/util/proc.d',
    'source/gx/util/redact.d',
    'source/gx/util/string.d',
    'source/secret/Collection.d',
    'source/secret/Item.d',
    'source/secret/Prompt.d',
    'source/secret/Schema.d',
    'source/secret/SchemaAttribute.d',
    'source/secret/Secret.d',
    'source/secret/Service.d',
    'source/secret/Value.d',
    'source/secretc/secret.d',
    'source/secretc/secrettypes.d',
    'source/x11/X.d',
    'source/x11/Xlib.d',
    'source/app.d'
]

sources_dir = include_directories('source/')

# Dependencies
gtkd_dep = dependency('gtkd-3', version: '>=3.10.0')
vted_dep = dependency('vted-3', version: '>=3.10.0')
xlib_dep = dependency('x11')
libsecret_dep = dependency('libsecret-1', required: false)

subdir('po')
subdir('data')

# Build & Test
executable('ttyx',
    [ttyx_sources, gresource],
    include_directories : sources_dir,
    dependencies : [gtkd_dep,
                    vted_dep,
                    xlib_dep,
                    libsecret_dep],
    d_args: d_extra_args,
    d_module_versions: ['StdLoggerDisableTrace'],
    link_args: d_link_args,
    install : true
)

ttyx_test_exe = executable('ttyx_test',
    [ttyx_sources],
    include_directories : [sources_dir],
    dependencies : [gtkd_dep,
                    vted_dep,
                    xlib_dep],
    d_args: d_extra_args,
    link_args: d_link_args,
    d_unittest: true
)
test('ttyx_test', ttyx_test_exe)

meson.add_install_script('meson_post_install.py')
