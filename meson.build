project('vala-language-server', 'vala', 'c')

build_type = get_option('buildtype')
build_tests = get_option('build_tests')

common_sources = files([
	'src/Context.vala',
	'src/Reporter.vala',
	'src/Server.vala',
	'src/ServerTypes.vala',
	'src/visitors/CheckLintInFile.vala',
	'src/visitors/CheckCodeActionsInFile.vala',
	'src/visitors/FindNode.vala',
	'src/visitors/FindNodeInFile.vala',
	'src/visitors/FindNodeAtPosition.vala',
	'src/visitors/FindSymbolReferenceAtPosition.vala',
	'src/visitors/FindSymbolByName.vala',
	'src/visitors/FindSymbolReferences.vala',
	'src/visitors/FindSymbolsInFile.vala',
	'src/visitors/FindCodeLensSymbolsInFile.vala',
	'src/visitors/FindCodeLensSymbolInFile.vala',
	'src/helpers/CodeHelpers.vala',
	'src/helpers/CompletionHelpers.vala',
	'src/helpers/DocumentSymbolHelpers.vala',
	'src/helpers/MiscHelpers.vala',
	'src/helpers/TestHelpers.vala',
	'src/protocol/Protocol.vala',
	'src/protocol/JsonSerialization.vala',
])

valac = meson.get_compiler('vala')
cc = meson.get_compiler('c')

vala_version = run_command('valac', '--version').stdout(). strip()
libvala_version = run_command('valac', '--api-version').stdout().strip()

common_dependencies = [
	dependency('glib-2.0', version: '>=2.56'),
	dependency('gobject-2.0'),
	dependency('gee-0.8'),
	dependency('gio-2.0'),
	dependency('jsonrpc-glib-1.0'),
	dependency('libvala-@0@'.format(libvala_version), version: '>=0.48'),
]

if host_machine.system() == 'windows'
	common_dependencies += dependency('gio-windows-2.0')
	common_sources += 'src/Windows.vapi'
	add_project_arguments(['--define=WINDOWS'], language: 'vala')
else
    common_dependencies += dependency('gio-unix-2.0')
endif

add_project_arguments([
		'--enable-gobject-tracing',
		# '--disable-warnings',
	], language: 'vala')

# add_project_arguments([
# 		'--header=vala-language-server.h',
# 		'--internal-header=vala-language-server-internal.h',
# 		'--use-header'
# 	], language: 'vala')

if build_type.startswith('debug')
    add_project_arguments(['--define', 'DEBUG'], language: 'vala')
endif

if vala_version.endswith('-exp')
	# The compiler is a personal experimental fork of the official compiler
	add_project_arguments(['--define', 'LIBVALA_EXP'], language: 'vala')

	# Enables the non-null mode with the flag to relax the requirement to cast
	# when the compiler can statically prove that a variable is non-null
	add_project_arguments([
  	'--enable-experimental-non-null',
  	'--exp-nullable-exemptions',
	], language: 'vala')
endif

add_project_arguments(['--pkg=posix'], language: 'vala')

add_project_arguments([
		'-D', '_POSIX_C_SOURCE', '-w'
	], language: 'c')

if not build_type.startswith('debug')
	# Use link-time optimization in non-debug builds (can make a lot of difference with Vala-generated code)
  add_project_arguments([
    '-flto'
  ], language: 'c')
endif

executable('vala-language-server',
	dependencies: common_dependencies,
	sources: [common_sources, 'src/Main.vala'],
	include_directories: 'src')

if build_tests
	test('tests', executable('vala-language-server-tests',
			dependencies: common_dependencies,
			sources: [common_sources, 'tests/TestsMain.vala'],
			include_directories: 'src'))
endif

# common_library = library('vala-language-server-common',
#   sources: common_sources,
# 	dependencies: common_dependencies,
# 	vala_header: 'vala-language-server-common.h')

# dependencies = common_dependencies + [declare_dependency(link_with: common_library)]

# executable('vala-language-server',
# 	dependencies: dependencies,
# 	sources: ['src/Main.vala', 'src/protocol/JsonSerializable.vapi'])

# if build_tests
# 	test('tests', executable('vala-language-server-tests',
# 			dependencies: dependencies,
# 			sources: ['tests/TestsMain.vala', 'src/protocol/JsonSerializable.vapi']))
# endif
