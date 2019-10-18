namespace Vls
{
  Server server;

  bool logdebug = false;
  bool loginfo = false;
  bool logwarn = false;

  void main()
  {
    string[] environment = Environ.get();
    string vls_debug = Environ.get_variable(environment, "VLS_DEBUG");
#if WINDOWS
    stdout.printf("Running in Windows (debug mode: %s, API version: %s, BUILD version: %s)...\n", vls_debug, Vala.API_VERSION, Vala.BUILD_VERSION);
#else
    stdout.printf("Running in Unix (debug mode: %s, API version: %s, BUILD version: %s)...\n", vls_debug, Vala.API_VERSION, Vala.BUILD_VERSION);
#endif
    if (vls_debug == "debug")
    {
      logdebug = true;
      loginfo = true;
      logwarn = true;
    }
    else if (vls_debug == "info")
    {
      loginfo = true;
      logwarn = true;
    }
    else if (vls_debug == "warn")
    {
      logwarn = true;
    }
    else if (vls_debug != null && vls_debug != "" && vls_debug != "false" && vls_debug != "0")
    {
      // Info level by default when the variable is "truthy"
      logdebug = false;
      loginfo = true;
      logwarn = true;
    }

    var loop = new MainLoop();
    server = new Server(loop);
    loop.run();
  }
}
