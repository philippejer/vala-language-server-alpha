namespace Vls
{
  public class BuildTarget
  {
    public string name;
    public bool exclusive;
    public bool active;
    public Gee.HashMap<string, SourceFile> source_files = new Gee.HashMap<string, SourceFile>();

    public BuildTarget(string name, bool exclusive, bool active)
    {
      this.name = name;
      this.exclusive = exclusive;
      this.active = active;
    }

    public void add_source_file(SourceFile source_file)
    {
      string key = source_file.fileuri.down();
      source_files.set(key, source_file);
    }

    public SourceFile? get_source_file(string fileuri)
    {
      string key = fileuri.down();
      SourceFile? source_file = source_files.get(key);
      return source_file;
    }

    public Gee.Collection<SourceFile> get_source_files()
    {
      return source_files.values;
    }

    public void clear()
    {
      source_files.clear();
    }
  }

  public class SourceFile
  {
    public string filename;
    public string fileuri;
    /** Whether the source file has been added from an external package */
    public bool external;
    public int version;
    public string content;
    public Vala.SourceFile? vala_file = null;
    public bool has_diagnostics = false;

    public SourceFile(string filename, string fileuri, bool external = false, int version = 0) throws Error
    {
      this.filename = filename;
      this.fileuri = fileuri;
      this.external = external;
      this.version = version;

      // By default the files are memory mapped by the compiler which seems to cause locking issues on Windows
      // Just read the file contents immediately (the file will need to be fully loaded by the compiler anyway)
      FileUtils.get_contents(filename, out content);
    }

    public void update_vala_file(Vala.SourceFile vala_file)
    {
      vala_file.content = content;
      this.vala_file = vala_file;
    }
  }

  /**
   * The point of this class is to refresh the Vala.CodeContext instead of rebuilding it from scratch.
   */
  public class Context
  {
    public Vala.CodeContext? code_context = null;
    public Gee.HashSet<string> defines = new Gee.HashSet<string>();
    public Gee.HashSet<string> packages = new Gee.HashSet<string>();
    public Gee.HashSet<string> vapi_directories = new Gee.HashSet<string>();
    public Gee.HashMap<string, SourceFile> source_files = new Gee.HashMap<string, SourceFile>();
    public Gee.HashMap<string, SourceFile> active_source_files = new Gee.HashMap<string, SourceFile>();
    public Gee.ArrayList<BuildTarget> build_targets = new Gee.ArrayList<BuildTarget>();
    public BuildTarget external_target = new BuildTarget("External sources", false, true);

    public bool disable_warnings = false;
    public bool experimental_non_null = false;

#if LIBVALA_EXP
    public bool exp_public_by_default = false;
    public bool exp_internal_by_default = false;
    public bool exp_float_by_default = false;
    public bool exp_optional_semicolons = false;
    public bool exp_optional_parens = false;
    public bool exp_conditional_attribute = false;
    public bool exp_forbid_delegate_copy = false;
    public bool exp_disable_implicit_namespace = false;
    public bool exp_integer_literal_separator = false;
    public bool exp_nullable_exemptions = false;
#endif

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
      string key = source_file.fileuri.down();
      source_files.set(key, source_file);
    }

    public SourceFile? get_source_file(string fileuri)
    {
      string key = fileuri.down();
      SourceFile? source_file = source_files.get(key);
      return source_file;
    }

    public bool has_active_source_file(SourceFile source_file)
    {
      string key = source_file.fileuri.down();
      return active_source_files.has_key(key);
    }

    public void add_active_source_file(SourceFile source_file)
    {
      string key = source_file.fileuri.down();
      active_source_files.set(key, source_file);
    }

    public SourceFile? get_active_source_file(string fileuri)
    {
      string key = fileuri.down();
      SourceFile? source_file = active_source_files.get(key);
      return source_file;
    }

    public Gee.Collection<SourceFile> get_active_source_files()
    {
      return active_source_files.values;
    }

    public void add_build_target(BuildTarget build_target)
    {
      build_targets.add(build_target);
    }

    public BuildTarget? get_build_target_for_source_file(string fileuri)
    {
      string key = fileuri.down();

      foreach (BuildTarget build_target in build_targets)
      {
        if (build_target.source_files.has_key(key))
        {
          return build_target;
        }
      }

      if (external_target.source_files.has_key(key))
      {
        return external_target;
      }

      return null;
    }

    public void activate_build_target(BuildTarget build_target)
    {
      if (build_target.exclusive)
      {
        foreach (BuildTarget other_target in build_targets)
        {
          if (other_target != build_target && other_target.exclusive && other_target.active)
          {
            if (loginfo) info(@"Deactivate build target '$(other_target.name)'");
            other_target.active = false;
          }
        }
      }

      if (loginfo) info(@"Activate build target '$(build_target.name)'");
      build_target.active = true;
    }

    public Reporter check(bool minimal = true) throws Error
    {
      if (this.code_context != null)
      {
        // The compiler uses some sort of (deprecated) StaticPrivate stack of CodeContext objects
        Vala.CodeContext.pop();
      }
      Vala.CodeContext code_context = new Vala.CodeContext();
      Vala.CodeContext.push(code_context);
      this.code_context = code_context;

      Reporter reporter = new Reporter();
      reporter.enable_warnings = !disable_warnings;
      code_context.report = reporter;

      show_elapsed_time("Build context", () => build(code_context), true);

      if (reporter.get_errors() > 0)
      {
        return reporter;
      }

      Vala.Parser vala_parser = new Vala.Parser();
      show_elapsed_time("Parse Vala", () => vala_parser.parse(code_context), true);

      Vala.Genie.Parser genie_parser = new Vala.Genie.Parser();
      show_elapsed_time("Parse Genie", () => genie_parser.parse(code_context), true);

      if (reporter.get_errors() > 0)
      {
        return reporter;
      }

#if LIBVALA_EXP
      show_elapsed_time(minimal ? "Check context (no flow analysis)" : "Check context (full)", () => code_context.check_(minimal), true);
#else
      show_elapsed_time("Context.check() -> code_context.check()", () => code_context.check(), true);
#endif

      return reporter;
    }

    private void build(Vala.CodeContext context) throws Error
    {
      context.experimental_non_null = experimental_non_null;

#if LIBVALA_EXP
      context.exp_public_by_default = exp_public_by_default;
      context.exp_internal_by_default = exp_internal_by_default;
      context.exp_float_by_default = exp_float_by_default;
      context.exp_optional_semicolons = exp_optional_semicolons;
      context.exp_optional_parens = exp_optional_parens;
      context.exp_conditional_attribute = exp_conditional_attribute;
      context.exp_forbid_delegate_copy = exp_forbid_delegate_copy;
      context.exp_disable_implicit_namespace = exp_disable_implicit_namespace;
      context.exp_integer_literal_separator = exp_integer_literal_separator;
      context.exp_nullable_exemptions = exp_nullable_exemptions;

      // This flag allows the parser to continue on trivial syntax errors
      context.exp_resilient_parser = true;
#endif

#if VALA_0_50
      context.set_target_profile (Vala.Profile.GOBJECT, true);
      context.set_target_glib_version("2.56");
#else
      context.profile = Vala.Profile.GOBJECT;
      context.add_define("GOBJECT");
      context.add_external_package("glib-2.0");
      context.add_external_package("gobject-2.0");
#endif

      foreach (string define in defines)
      {
        context.add_define(define);
      }

      context.vapi_directories = vapi_directories.to_array();

      foreach (string package in packages)
      {
        context.add_external_package(package);
      }

      active_source_files.clear();

      // Add source files from currently active targets to the compiler context
      foreach (BuildTarget build_target in build_targets)
      {
        if (!build_target.active)
        {
          if (loginfo) info(@"Build target is inactive: $(build_target.name)");
          continue;
        }

        if (loginfo) info(@"Build target is active: $(build_target.name)");
        foreach (SourceFile source_file in build_target.get_source_files())
        {
          // The source file may have already been added if it is part of several targets
          if (!has_active_source_file(source_file))
          {
            context.add_source_filename(source_file.filename);
            add_active_source_file(source_file);
          }
        }
      }

      // Associate each active source file with the corresponding Vala object
      // Also add source files which have been added implicitly to the context (VAPI files from packages)
      foreach (Vala.SourceFile vala_source_file in context.get_source_files())
      {
        unowned string filename = vala_source_file.filename;
        string fileuri = sanitize_file_name(filename);

        SourceFile? source_file = get_source_file(fileuri);

        if (source_file == null)
        {
          // This file does not come from the build targets, which means it comes from an external package
          if (loginfo) info(@"Adding external source file '$(filename)' from packages");
          source_file = new SourceFile(filename, fileuri, true);
          add_source_file(source_file);
          external_target.add_source_file(source_file);
        }

        if (source_file.external)
        {
          add_active_source_file(source_file);
        }

        source_file.update_vala_file(vala_source_file);
      }
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
      active_source_files.clear();
      build_targets.clear();
      external_target.clear();
    }
  }
}
