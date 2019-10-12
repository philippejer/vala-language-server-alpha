namespace VLS
{
  Server server;

  bool logdebug;
  bool loginfo;

  void main()
  {
    string[] environment = Environ.get();
    string vls_debug = Environ.get_variable(environment, "VLS_DEBUG");
    if (vls_debug != null)
    {
#if WINDOWS
      stdout.printf("Running in Windows (debug build)...\n");
#else
      stdout.printf("Running in Unix (debug build)...\n");
#endif
      logdebug = false;
      loginfo = true;
    }
    else
    {
#if WINDOWS
      stdout.printf("Running in Windows (release build)...\n");
#else
      stdout.printf("Running in Unix (release build)...\n");
#endif
      logdebug = false;
      loginfo = false;
    }

    var loop = new MainLoop();
    server = new Server(loop);
    loop.run();
  }
}
