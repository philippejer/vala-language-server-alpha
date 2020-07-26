namespace Vls
{
  public delegate void ActionFunc() throws Error;

  public void show_elapsed_time(string label, ActionFunc action, bool debug_level = false) throws Error
  {
    int64 time_us = get_elapsed_time(action);
    if (time_us < 10000)
    {
      if (debug_level)
      {
        if (logdebug) debug(@"$(label): $(time_us) us");
      }
      else
      {
        if (loginfo) info(@"$(label): $(time_us) us");
      }
    }
    else
    {
      if (debug_level)
      {
        if (logdebug) debug(@"$(label): $(time_us / 1000) ms");
      }
      else
      {
        if (loginfo) info(@"$(label): $(time_us / 1000) ms");
      }
    }
  }

  public int64 get_elapsed_time(ActionFunc action) throws Error
  {
    int64 start_us = get_monotonic_time();
    action();
    int64 stop_us = get_monotonic_time();
    return stop_us - start_us;
  }

  public string sanitize_file_name(string filename)
  {
    try
    {
      return sanitize_file_uri(Filename.to_uri(filename));
    }
    catch
    {
      return filename;
    }
  }

#if WINDOWS
  public string sanitize_file_uri(string fileuri)
  {
    // VS Code encodes the drive colon (known issue on Windows)
    return Uri.unescape_string(fileuri) ?? fileuri;
  }
#else
  public string sanitize_file_uri(string fileuri)
  {
    return fileuri;
  }
#endif

  public int64 get_time_us()
  {
    return get_monotonic_time();
  }
}
