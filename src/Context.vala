namespace Vls
{
  class SourceFile : Object
  {
    public string filename;
    public string uri;
    public bool external;
    public int version;
    public string content;
    public Vala.SourceFile file = null;
    public bool has_diagnostics = false;

    public SourceFile(string filename, string uri, bool external, int version = 0) throws ConvertError
    {
      this.filename = filename;
      this.uri = uri;
      this.external = external;
      this.version = version;

      // By default the files are memory mapped by the compiler which seems to cause locking issues on Windows
      // Just read the file contents immediately (the file will need to be fully loaded by the compiler anyway)
      FileUtils.get_contents(filename, out content);
    }

    public SourceFile.from_internal(string filename, string uri, int version = 0) throws ConvertError
    {
      this(filename, uri, false, version);
    }

    public SourceFile.from_external(string filename, string uri, int version = 0) throws ConvertError
    {
      this(filename, uri, true, version);
    }

    public void set_file(Vala.SourceFile file)
    {
      this.file = file;
      file.content = content;
    }
  }

/**
 * The point of this class is to refresh the Vala.CodeContext instead of rebuilding it from scratch.
 */
  class Context
  {

    public Vala.CodeContext code_context { get; private set; }

    Gee.HashSet<string> defines = new Gee.HashSet<string>();
    Gee.HashSet<string> packages = new Gee.HashSet<string>();
    Gee.HashSet<string> vapi_directories = new Gee.HashSet<string>();
    Gee.HashMap<string, SourceFile> source_files = new Gee.HashMap<string, SourceFile>();

    public bool disable_warnings { get; set; default = false; }

#if LIBVALA_EXPERIMENTAL
    public bool exp_public_by_default { get; set; default = false; }
    public bool exp_float_by_default { get; set; default = false; }
    public bool exp_optional_semicolons { get; set; default = false; }
    public bool exp_optional_parens { get; set; default = false; }
    public bool exp_conditional_attribute { get; set; default = false; }
#endif

    public Context()
    {
    }

    public void add_define(string define)
    {
      defines.add(define);
    }

    public void add_package(string package)
    {
      packages.add(package);
    }

    public void add_vapi_directory(string vapi_directory)
    {
      vapi_directories.add(vapi_directory);
    }

    public void add_source_file(SourceFile source_file)
    {
      string key = source_file.uri.down();
      source_files[key] = source_file;
    }

    public SourceFile? get_source_file(string uri)
    {
      string key = uri.down();
      if (!source_files.has_key(key))
      {
        return null;
      }
      return source_files[key];
    }

    public Gee.Collection<SourceFile> get_source_files()
    {
      return source_files.values;
    }

    public void clear()
    {
      if (code_context != null)
      {
        Vala.CodeContext.pop();
        code_context = null;
      }
      defines.clear();
      packages.clear();
      vapi_directories.clear();
      source_files.clear();
    }

    public Reporter check()
    {
      if (code_context != null)
      {
        // The compiler uses some sort of (deprecated) StaticPrivate stack of CodeContext objects
        Vala.CodeContext.pop();
      }

      code_context = new Vala.CodeContext();
      Vala.CodeContext.push(code_context);

      var reporter = new Reporter();
      build_code_context(code_context, reporter);

      if (reporter.get_errors() > 0)
      {
        return reporter;
      }

      var vala_parser = new Vala.Parser();
      vala_parser.parse(code_context);

      var genie_parser = new Vala.Genie.Parser();
      genie_parser.parse(code_context);

      if (reporter.get_errors() > 0)
      {
        return reporter;
      }

      code_context.check();

      return reporter;
    }

    private void build_code_context(Vala.CodeContext code_context, Reporter reporter)
    {
      reporter.enable_warnings = !disable_warnings;
      code_context.report = reporter;
      
#if LIBVALA_EXPERIMENTAL
      code_context.exp_public_by_default = exp_public_by_default;
      code_context.exp_float_by_default = exp_float_by_default;
      code_context.exp_optional_semicolons = exp_optional_semicolons;
      code_context.exp_optional_parens = exp_optional_parens;
      code_context.exp_conditional_attribute = exp_conditional_attribute;

      // This flag allows the parser to continue on trivial syntax errors
      code_context.exp_resilient_parser = true;
#endif

      code_context.profile = Vala.Profile.GOBJECT;
      code_context.add_define("GOBJECT");

      foreach (string define in defines)
      {
        code_context.add_define(define);
      }

      code_context.set_target_glib_version("2.56");

      code_context.vapi_directories = vapi_directories.to_array();

      code_context.add_external_package("glib-2.0");
      code_context.add_external_package("gobject-2.0");

      foreach (string package in packages)
      {
        code_context.add_external_package(package);
      }

      foreach (SourceFile source_file in source_files.values)
      {
        // External source files have already been added to the context at this point
        if (!source_file.external)
        {
          code_context.add_source_filename(source_file.filename);
        }
      }

      Vala.List<Vala.SourceFile> files = code_context.get_source_files();
      foreach (Vala.SourceFile file in files)
      {
        unowned string filename = file.filename;
        string uri = sanitize_file_uri(Filename.to_uri(filename));
        SourceFile source_file = get_source_file(uri);
        if (source_file == null)
        {
          // Source file was not added from build file analysis, but from an external package
          if (loginfo) info(@"Adding source file from packages ($(filename)) ($(uri))");
          source_file = new SourceFile.from_external(filename, uri);
          add_source_file(source_file);
        }
        source_file.set_file(file);
      }
    }
  }
}
