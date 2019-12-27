namespace Vls
{
  public delegate void ActionFunc() throws Error;

  public void show_elapsed_time(string label, ActionFunc action) throws Error
  {
    Timer timer = new Timer();
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
