project(
  'equinox_wl_backend',
  'c', 'cpp',
  default_options: [
    'cpp_std=c++20'
  ]
)

louvre_dep = dependency(
  'Louvre'
)
wayland_client_dep  = dependency('wayland-client', version: '>= 1.20.0')
wayland_egl_dep     = dependency('wayland-egl', version: '>= 18.1.0')
egl_dep             = dependency('egl', version : '>=1.5')
gl_dep              = dependency('gl', version: '>= 1.2')
srm_dep             = dependency('SRM', version : '>=0.12.0')
pixman_dep          = dependency('pixman-1')

shared_library(
    'equinoxwl',
    name_prefix : '',
    name_suffix : 'so',
    sources : [
        'EquinoxWaylandBackend.cpp',
        'xdg-decoration-unstable-v1.c',
        'xdg-shell.c'
    ],
    # include_directories : include_paths + [include_directories('./..')],
    dependencies : [
        louvre_dep,
        wayland_client_dep,
        wayland_egl_dep,
        egl_dep,
        gl_dep,
        srm_dep,
        pixman_dep
    ],
    cpp_args: ['-std=c++20'],
    install : true,
    # install_dir : join_paths(BACKENDS_INSTALL_PATH, 'graphic')
)
