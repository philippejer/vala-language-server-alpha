namespace Vls
{
  delegate void Action() throws Error;

  void debug_action_time(string label, Action action) throws Error
  {
    var timer = new Timer();
    timer.start();
    action();
    timer.stop();
    ulong micros;
    timer.elapsed(out micros);
    if (micros < 10000)
    {
      if (loginfo) info(@"$(label): $(micros) us");
    }
    else
    {
      if (loginfo) info(@"$(label): $(micros / 1000) ms");
    }
  }

#if WINDOWS
  string sanitize_file_uri(string uri)
  {
    // VS Code encodes the drive colon (known issue on Windows)
    return Uri.unescape_string(uri);
  }
#else
  string sanitize_file_uri(string uri)
  {
    return uri;
  }
#endif

  int64 get_time_us()
  {
    return get_monotonic_time();
  }  

  //  delegate T ThrowsFunc<T>() throws Error;

  //  T check_func_error<T>(ThrowsFunc func)
  //  {
  //    try
  //    {
  //      return func();
  //    }
  //    catch (Error err)
  //    {
  //      error("Unexpected error: %s", err.message);
  //    }
  //  }

  //  delegate void ThrowsAction() throws Error;

  //  void check_action_error(ThrowsAction action)
  //  {
  //    try
  //    {
  //      action();
  //    }
  //    catch (Error err)
  //    {
  //      error("Unexpected error: %s", err.message);
  //    }
  //  }
}
