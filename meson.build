project('Diet-NG', 'd',
    meson_version: '>=0.40',
    license: 'MIT',
    version: '1.4.1'
)

project_soversion = '0'
project_version   = meson.project_version()

pkgc = import('pkgconfig')

#
# Sources
#
diet_src = [
    'source/diet/defs.d',
    'source/diet/dom.d',
    'source/diet/html.d',
    'source/diet/input.d',
    'source/diet/internal/html.d',
    'source/diet/internal/string.d',
    'source/diet/parser.d',
    'source/diet/traits.d',
]

src_dir = include_directories('source/')

#
# Targets
#
diet_lib = library('diet',
        [diet_src],
        include_directories: [src_dir],
        install: true,
        version: project_version,
        soversion: project_soversion
)

pkgc.generate(name: 'diet',
              libraries: [diet_lib],
              subdirs: 'd/diet',
              version: project_version,
              description: 'Next generation Diet template compiler.'
)

# for use by Vibe.d and others which embed this as subproject
diet_dep = declare_dependency(
    link_with: [diet_lib],
    include_directories: [src_dir]
)

#
# Tests
#
diet_test_exe = executable('test_diet',
    [diet_src],
    include_directories: [src_dir],
    d_args: meson.get_compiler('d').unittest_args(),
    link_args: '-main'
)
test('test_diet', diet_test_exe)

#
# Install
#
install_subdir('source/diet/', install_dir: 'include/d/diet/')
