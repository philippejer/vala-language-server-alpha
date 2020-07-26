namespace Vls
{
  public class SourceError
  {
    public Vala.SourceReference source_reference;
    public string message;

    public SourceError(Vala.SourceReference source_reference, string message)
    {
      this.source_reference = source_reference;
      this.message = message;
    }
  }

  public class Reporter : Vala.Report
  {
    public Gee.HashMap<string, Gee.ArrayList<SourceError>> errors_by_file = new Gee.HashMap<string, Gee.ArrayList<SourceError>>();
    public Gee.HashMap<string, Gee.ArrayList<SourceError>> warnings_by_file = new Gee.HashMap<string, Gee.ArrayList<SourceError>>();
    public Gee.HashMap<string, Gee.ArrayList<SourceError>> notes_by_file = new Gee.HashMap<string, Gee.ArrayList<SourceError>>();

    public override void note(Vala.SourceReference? source_reference, string message)
    {
      if (!enable_warnings)
      {
        return;
      }
      else if (source_reference == null)
      {
        if (loginfo) GLib.info(@"Non-source note: '$(message)'");
      }
      else
      {
        add_source_error(source_reference, "Note: " + message, ref notes_by_file);
      }
    }

    public override void depr(Vala.SourceReference? source_reference, string message)
    {
      if (!enable_warnings)
      {
        return;
      }
      ++warnings;
      if (source_reference == null)
      {
        if (loginfo) GLib.info(@"Non-source deprecation: '$(message)'");
      }
      else
      {
        add_source_error(source_reference, "Deprecated: " + message, ref notes_by_file);
      }
    }

    public override void warn(Vala.SourceReference? source_reference, string message)
    {
      if (!enable_warnings)
      {
        return;
      }
      ++warnings;
      if (source_reference == null)
      {
        if (loginfo) GLib.info(@"Non-source warning: '$(message)'");
      }
      else
      {
        add_source_error(source_reference, "Warning: " + message, ref warnings_by_file);
      }
    }

    public override void err(Vala.SourceReference? source_reference, string message)
    {
      ++errors;
      if (source_reference == null)
      {
        if (loginfo) GLib.info(@"Error without source reference: '$(message)'");
      }
      else
      {
        add_source_error(source_reference, "Error: " + message, ref errors_by_file);
      }
    }

#if LIBVALA_EXP
    public override void suppr_err(Vala.SourceReference? source_reference, string message)
    {
      ++suppr_errors;
      if (source_reference == null)
      {
        if (loginfo) GLib.info(@"Error without source reference: '$(message)'");
      }
      else
      {
        add_source_error(source_reference, "Suppressed error: " + message, ref errors_by_file);
      }
    }
#endif

    private static void add_source_error(Vala.SourceReference source_reference, string message, ref Gee.HashMap<string, Gee.ArrayList<SourceError>> errors_by_file)
    {
      string fileuri = sanitize_file_name(source_reference.file.filename);
      Gee.ArrayList<SourceError> errors;
      if (!errors_by_file.has_key(fileuri))
      {
        errors = new Gee.ArrayList<SourceError>();
        errors_by_file.set(fileuri, errors);
      }
      else
      {
        errors = errors_by_file.get(fileuri);
      }
      errors.add(new SourceError(source_reference, message));
    }
  }
}
