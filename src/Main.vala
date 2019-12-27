using Vls;

void main(string[] args)
{
  string? glib_debug = Environment.get_variable("G_MESSAGES_DEBUG");
  if (glib_debug == null || glib_debug.strip() == "")
  {
    Environment.set_variable("G_MESSAGES_DEBUG", "all", true);
  }

  loglevel = LogLevel.from_json(Environment.get_variable("VLS_DEBUG")) ?? LogLevel.INFO;
  logdebug = (loglevel >= LogLevel.DEBUG);
  loginfo = (loglevel >= LogLevel.INFO);
  logwarn = (loglevel >= LogLevel.WARN);

  method_completion_mode = MethodCompletionMode.from_json(Environment.get_variable("VLS_METHOD_COMPLETION_MODE")) ?? MethodCompletionMode.OFF;

#if WINDOWS
  message(@"Server running in Windows (API version: $(Vala.API_VERSION), BUILD version: $(Vala.BUILD_VERSION))...");
#else
  message(@"Server running in Unix (API version: $(Vala.API_VERSION), BUILD version: $(Vala.BUILD_VERSION)...");
#endif

  MainLoop loop = new MainLoop();
  Server.create_server(loop);
  loop.run();
}
