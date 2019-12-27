namespace Vls
{
  public class SourceError
  {
    public Vala.SourceReference source;
    public string message;

    public SourceError(Vala.SourceReference source, string message)
    {
      this.source = source;
      this.message = message;
    }
  }

  public class Reporter : Vala.Report
  {
    public Gee.HashMap<string, Gee.ArrayList<SourceError>> errors_by_file = new Gee.HashMap<string, Gee.ArrayList<SourceError>>();
    public Gee.HashMap<string, Gee.ArrayList<SourceError>> warnings_by_file = new Gee.HashMap<string, Gee.ArrayList<SourceError>>();
    public Gee.HashMap<string, Gee.ArrayList<SourceError>> notes_by_file = new Gee.HashMap<string, Gee.ArrayList<SourceError>>();

    public override void note(Vala.SourceReference? source, string message)
    {
      if (!enable_warnings)
      {
        return;
      }
      else if (source == null)
      {
        if (logwarn) GLib.warning(@"Non-source note: '$(message)'");
      }
      else
      {
        add_source_error(source, "Note: " + message, ref notes_by_file);
      }
    }

    public override void depr(Vala.SourceReference? source, string message)
    {
      if (!enable_warnings)
      {
        return;
      }
      ++warnings;
      if (source == null)
      {
        if (logwarn) GLib.warning(@"Non-source deprecation: '$(message)'");
      }
      else
      {
        add_source_error(source, "Deprecated: " + message, ref notes_by_file);
      }
    }

    public override void warn(Vala.SourceReference? source, string message)
    {
      if (!enable_warnings)
      {
        return;
      }
      ++warnings;
      if (source == null)
      {
        if (logwarn) GLib.warning(@"Non-source warning: '$(message)'");
      }
      else
      {
        add_source_error(source, "Warning: " + message, ref warnings_by_file);
      }
    }

    public override void err(Vala.SourceReference? source, string message)
    {
      ++errors;
      if (source == null)
      {
        if (logwarn) GLib.warning(@"Non-source error: '$(message)'");
      }
      else
      {
        add_source_error(source, "Error: " + message, ref errors_by_file);
      }
    }

#if LIBVALA_EXP
    public override void suppr_err(Vala.SourceReference? source, string message)
    {
      ++suppr_errors;
      if (source == null)
      {
        if (logwarn) GLib.warning(@"Non-source error: '$(message)'");
      }
      else
      {
        add_source_error(source, "Suppressed error: " + message, ref errors_by_file);
      }
    }
#endif

    private static void add_source_error(Vala.SourceReference source, string message, ref Gee.HashMap<string, Gee.ArrayList<SourceError>> errors_by_file)
    {
      Gee.ArrayList<SourceError> errors;
      if (!errors_by_file.has_key(source.file.filename))
      {
        errors = new Gee.ArrayList<SourceError>();
        errors_by_file.set(source.file.filename, errors);
      }
      else
      {
        errors = errors_by_file.get(source.file.filename);
      }
      errors.add(new SourceError(source, message));
    }
  }
}
