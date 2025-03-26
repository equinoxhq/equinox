project(
  'equinox_wl_backend',
  'c', 'cpp',
  default_options: [
    'cpp_std=c++20'
  ]
)

sources = run_command('find', '.', '-maxdepth', '1', '-type', 'f', '-name', '*[.c,.cpp,.h,.hpp]', check : false).stdout().strip().split('\n')
louvre_dep = dependency(
  'Louvre'
)
wayland_client_dep  = dependency('wayland-client', version: '>= 1.20.0')
wayland_egl_dep     = dependency('wayland-egl', version: '>= 18.1.0')
egl_dep             = dependency('egl', version : '>=1.5')
gl_dep              = dependency('gl', version: '>= 1.2')
srm_dep             = dependency('SRM', version : '>=0.12.0')
pixman_dep          = dependency('pixman-1')

executable(
    'equinox_comp',
    sources : sources,
    dependencies : [
        louvre_dep,
        gl_dep,
    ],
    install_dir: '../../'
)
