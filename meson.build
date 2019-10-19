project('vala-language-server', 'vala', 'c')

sources = files([
	'src/Server.vala',
	'src/Reporter.vala',
	'src/Context.vala',
	'src/visitors/FindNode.vala',
	'src/visitors/FindNodeInFile.vala',
	'src/visitors/FindNodeByPosition.vala',
	'src/visitors/FindSymbolByPosition.vala',
	'src/visitors/FindSymbolByName.vala',
	'src/visitors/FindSymbolReferences.vala',
	'src/visitors/FindSymbolsInFile.vala',
	'src/helpers/CodeHelpers.vala',
	'src/helpers/CompletionHelpers.vala',
	'src/helpers/DocumentSymbolHelpers.vala',
	'src/helpers/MiscHelpers.vala',
	'src/helpers/TestHelpers.vala',
	'src/protocol/Protocol.vala',
	'src/protocol/JsonSerialization.vala',
	'src/protocol/JsonSerializable.vapi'
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
		'--disable-warnings',
	], language: 'vala')

buildtype = get_option('buildtype')
if buildtype.startswith('debug')
    add_project_arguments(['--define', 'DEBUG'], language: 'vala')
endif
if buildtype.startswith('release')
    add_project_arguments(['--define', 'NDEBUG'], language: 'vala')
endif

message('vala_version: ' + vala_version)
if vala_version.endswith('-exp')
	add_project_arguments(['--define', 'LIBVALA_EXPERIMENTAL'], language: 'vala')
endif

add_project_arguments(['--pkg=posix'], language: 'vala')

add_project_arguments([
		'-D', '_POSIX_C_SOURCE',
	], language: 'c')

executable('vala-language-server',
	dependencies: dependencies,
	sources: [sources, 'src/Main.vala'],
	install: true)

executable('vala-language-server-tests',
	dependencies: dependencies,
	sources: [sources, 'src/TestMain.vala'],
	install: true)
