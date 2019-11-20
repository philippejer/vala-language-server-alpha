project('vala-language-server', 'vala', 'c')

sources = files([
	'src/Server.vala',
	'src/Reporter.vala',
	'src/Context.vala',
	'src/visitors/FindNode.vala',
	'src/visitors/FindNodeInFile.vala',
	'src/visitors/FindNodeInFileNop.vala',
	'src/visitors/FindNodeAtPosition.vala',
	'src/visitors/FindSymbolReferenceAtPosition.vala',
	'src/visitors/FindSymbolByName.vala',
	'src/visitors/FindSymbolReferences.vala',
	'src/visitors/FindSymbolsInFile.vala',
	'src/visitors/FindCodeLensSymbolsInFile.vala',
	'src/visitors/FindCodeLensSymbolInFile.vala',
	'src/visitors/CheckLintInFile.vala',
	'src/helpers/CodeHelpers.vala',
	'src/helpers/CompletionHelpers.vala',
	'src/helpers/DocumentSymbolHelpers.vala',
	'src/helpers/MiscHelpers.vala',
	'src/helpers/TestHelpers.vala',
	'src/protocol/Protocol.vala',
	'src/protocol/JsonSerialization.vala',
	'src/protocol/JsonSerializable.vapi',
])

valac = meson.get_compiler('vala')
cc = meson.get_compiler('c')

vala_version = run_command('valac', '--version').stdout(). strip()
libvala_version = run_command('valac', '--api-version').stdout().strip()

dependencies = [
	dependency('glib-2.0', version: '>=2.54'),
	dependency('gobject-2.0'),
	dependency('gee-0.8'),
	dependency('gio-2.0'),
	dependency('jsonrpc-glib-1.0'),
	dependency('libvala-@0@'.format(libvala_version)),
]

if host_machine.system() == 'windows'
	dependencies += dependency('gio-windows-2.0')
	sources += 'src/Windows.vapi'
	add_project_arguments(['--define=WINDOWS'], language: 'vala')
else
    dependencies += dependency('gio-unix-2.0')
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

buildtype = get_option('buildtype')
if buildtype.startswith('debug')
    add_project_arguments(['--define', 'DEBUG'], language: 'vala')
endif

message('vala_version: ' + vala_version)
if vala_version.endswith('-exp')
	add_project_arguments(['--define', 'LIBVALA_EXP'], language: 'vala')
endif

add_project_arguments(['--pkg=posix'], language: 'vala')

add_project_arguments([
		'-D', '_POSIX_C_SOURCE', '-w'
	], language: 'c')

# if not get_option('buildtype').startswith('debug')
#   add_project_arguments([
#     '-flto'
#   ], language: 'c')
# endif

executable('vala-language-server',
	dependencies: dependencies,
	sources: [sources, 'src/Main.vala'],
	install: true)

if get_option('build_tests')
	test('tests', executable('vala-language-server-tests',
			dependencies: dependencies,
			sources: [sources, 'tests/TestsMain.vala'],
			install: true))
endif
