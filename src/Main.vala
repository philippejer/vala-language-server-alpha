namespace Vls
{
  void main(string[] args)
  {
    debug_level = get_debug_level();

#if WINDOWS
    stdout.printf("Server running in Windows (debug level: %s, API version: %s, BUILD version: %s)...\n", debug_level.to_string(), Vala.API_VERSION, Vala.BUILD_VERSION);
#else
    stdout.printf("Server running in Unix (debug level: %s, API version: %s, BUILD version: %s)...\n", debug_level.to_string(), Vala.API_VERSION, Vala.BUILD_VERSION);
#endif

    logdebug = (debug_level >= DebugLevel.DEBUG);
    loginfo = (debug_level >= DebugLevel.INFO);
    logwarn = (debug_level >= DebugLevel.WARN);

    var loop = new MainLoop();
    vls_server = new Server(loop);
    loop.run();
  }

  private DebugLevel get_debug_level()
  {
    string[] environment = Environ.get();
    string vls_debug = Environ.get_variable(environment, "VLS_DEBUG");
    switch (vls_debug)
    {
    case "debug":
      return DebugLevel.DEBUG;
    case "info":
      return DebugLevel.INFO;
    case "warn":
      return DebugLevel.WARN;
    case "off":
      return DebugLevel.OFF;
    case "true":
    case "1":
      return DebugLevel.INFO;
    default:
      return DebugLevel.OFF;
    }
  }
}
