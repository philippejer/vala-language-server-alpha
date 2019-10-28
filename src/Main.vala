namespace Vls
{
  void main(string[] args)
  {
    string[] environment = Environ.get();
    debug_level = get_debug_level(environment);
    method_completion_mode = get_method_completion_mode(environment);

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

  private DebugLevel get_debug_level(string[] environment)
  {
    string vls_debug = Environ.get_variable(environment, "VLS_DEBUG");
    switch (vls_debug)
    {
    case "debug":
      return DebugLevel.DEBUG;
    case "info":
      return DebugLevel.INFO;
    case "warn":
      return DebugLevel.WARN;
    case "true":
    case "1":
      return DebugLevel.INFO;
    case "off":
    default:
      return DebugLevel.OFF;
    }
  }

  private MethodCompletionMode get_method_completion_mode(string[] environment)
  {
    string vls_debug = Environ.get_variable(environment, "VLS_METHOD_COMPLETION_MODE");
    switch (vls_debug)
    {
    case "space":
      return MethodCompletionMode.SPACE;
    case "nospace":
      return MethodCompletionMode.NOSPACE;
    case "off":
    default:
      return MethodCompletionMode.OFF;
    }
  }
}
