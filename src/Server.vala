namespace Vls
{
  public errordomain VlsError
  {
    FAILED
  }

  public enum LogLevel
  {
    OFF = 0,
    WARN,
    INFO,
    DEBUG,
    SILLY;

    public string to_string()
    {
      return ((GLib.EnumClass) typeof(LogLevel).class_ref()).get_value(this).value_name.replace("VLS_LOG_LEVEL_", "");
    }

    public string to_json()
    {
      switch (this)
      {
      case LogLevel.OFF: return "off";
      case LogLevel.WARN: return "warn";
      case LogLevel.INFO: return "info";
      case LogLevel.DEBUG: return "debug";
      case LogLevel.SILLY: return "silly";
      default: return "???";
      }
    }

    public static LogLevel from_json(string? value)
    {
      switch (value)
      {
      case "off": return LogLevel.OFF;
      case "warn": return LogLevel.WARN;
      case "info": return LogLevel.INFO;
      case "debug": return LogLevel.DEBUG;
      case "silly": return LogLevel.SILLY;
      case "true": return LogLevel.INFO;
      default: return LogLevel.INFO;
      }
    }
  }

  public enum MethodCompletionMode
  {
    OFF = 0,
    SPACE,
    NOSPACE;

    public string to_string()
    {
      return ((GLib.EnumClass) typeof(MethodCompletionMode).class_ref()).get_value(this).value_name.replace("VLS_METHOD_COMPLETION_MODE_", "");
    }

    public string to_json()
    {
      switch (this)
      {
      case MethodCompletionMode.OFF: return "off";
      case MethodCompletionMode.SPACE: return "space";
      case MethodCompletionMode.NOSPACE: return "nospace";
      default: return "???";
      }
    }

    public static MethodCompletionMode from_json(string? value)
    {
      switch (value)
      {
      case "off": return MethodCompletionMode.OFF;
      case "space": return MethodCompletionMode.SPACE;
      case "nospace": return MethodCompletionMode.NOSPACE;
      default: return MethodCompletionMode.OFF;
      }
    }
  }

  public class ServerConfig : AbstractJsonSerializableObject
  {
    public LogLevel logLevel { get; set; default = LogLevel.WARN; }
    public MethodCompletionMode methodCompletionMode { get; set; default = MethodCompletionMode.OFF; }
    public bool referencesCodeLensEnabled { get; set; default = false; }

    public override Json.Node? serialize_property(string property_name, Value @value, ParamSpec pspec)
    {
      error("Not supported");
    }

    public override bool deserialize_property(string property_name, ref Value @value, ParamSpec pspec, Json.Node property_node)
    {
      if (pspec.value_type.is_a(typeof(LogLevel)))
      {
        LogLevel level = property_node.get_node_type() == Json.NodeType.VALUE
          ? LogLevel.from_json(property_node.get_string())
          : LogLevel.WARN;
        @value.set_enum(level);
        return true;
      }
      else if (pspec.value_type.is_a(typeof(MethodCompletionMode)))
      {
        MethodCompletionMode mode = property_node.get_node_type() == Json.NodeType.VALUE
          ? MethodCompletionMode.from_json(property_node.get_string())
          : MethodCompletionMode.OFF;
        @value.set_enum(mode);
        return true;
      }
      return base.deserialize_property(property_name, ref @value, pspec, property_node);
    }
  }

  public LogLevel loglevel = LogLevel.OFF;
  public bool logsilly = false;
  public bool logdebug = false;
  public bool loginfo = false;
  public bool logwarn = false;
  public MethodCompletionMode method_completion_mode = MethodCompletionMode.OFF;
  public bool references_code_lens_enabled = false;

  public void update_server_config(ServerConfig config)
  {
    if (loginfo) info(@"Update server config");
    loglevel = config.logLevel;
    logdebug = (loglevel >= LogLevel.DEBUG);
    loginfo = (loglevel >= LogLevel.INFO);
    logwarn = (loglevel >= LogLevel.WARN);
    method_completion_mode = config.methodCompletionMode;
    references_code_lens_enabled = config.referencesCodeLensEnabled;
  }

  public class BuildConfig : AbstractJsonSerializableObject
  {
    public JsonSerializableCollection<string> sources { get; set; }

    public string parameters { get; set; }

    protected override JsonSerializableCollection? create_collection(string property_name)
    {
      switch (property_name)
      {
      case "sources":
        return new JsonArrayList<string>();
      }
      return base.create_collection(property_name);
    }
  }

  public class MesonTarget : AbstractJsonSerializableObject, JsonSerializableObject
  {
    public string name { get; set; }

    public string type_ { get; set; } // "type" is not allowed even with an '@'

    public JsonSerializableCollection<MesonTargetSource> target_sources { get; set; }

    public override unowned ParamSpec? find_property(string name)
    {
      return base.find_property(name == "type" ? "type_" : name);
    }

    protected override JsonSerializableCollection? create_collection(string property_name)
    {
      switch (property_name)
      {
      case "target-sources":
        return new JsonArrayList<MesonTargetSource>();
      }
      return base.create_collection(property_name);
    }
  }

  public class MesonTargetSource : AbstractJsonSerializableObject
  {
    public string language { get; set; }

    public JsonSerializableCollection<string> parameters { get; set; }

    public JsonSerializableCollection<string> sources { get; set; }

    protected override JsonSerializableCollection? create_collection(string property_name)
    {
      switch (property_name)
      {
      case "parameters":
      case "sources":
        return new JsonArrayList<string>();
      }
      return base.create_collection(property_name);
    }
  }

  public enum LintSeverity
  {
    IGNORE = 0,
    HINT,
    INFO,
    WARN,
    ERROR;

    public string to_string()
    {
      return ((GLib.EnumClass) typeof(LintSeverity).class_ref()).get_value(this).value_name.replace("LINT_SEVERITY_", "");
    }

    public string to_json()
    {
      switch (this)
      {
      case LintSeverity.IGNORE: return "ignore";
      case LintSeverity.HINT: return "hint";
      case LintSeverity.INFO: return "info";
      case LintSeverity.WARN: return "warn";
      case LintSeverity.ERROR: return "error";
      default: return "???";
      }
    }

    public static LintSeverity from_json(string? value)
    {
      switch (value)
      {
      case "ignore": return LintSeverity.IGNORE;
      case "hint": return LintSeverity.HINT;
      case "info": return LintSeverity.INFO;
      case "warn": return LintSeverity.WARN;
      case "error": return LintSeverity.ERROR;
      default: return LintSeverity.IGNORE;
      }
    }
  }

  public class LintConfig : AbstractJsonSerializableObject
  {
    public LintSeverity no_implicit_this_access { get; set; default = LintSeverity.IGNORE; }
    public LintSeverity no_unqualified_static_access { get; set; default = LintSeverity.IGNORE; }

    public override Json.Node? serialize_property(string property_name, Value @value, ParamSpec pspec)
    {
      error("Not supported");
    }

    public override bool deserialize_property(string property_name, ref Value @value, ParamSpec pspec, Json.Node property_node)
    {
      if (pspec.value_type.is_a(typeof(LintSeverity)))
      {
        LintSeverity severity = property_node.get_node_type() == Json.NodeType.VALUE
          ? LintSeverity.from_json(property_node.get_string())
          : LintSeverity.IGNORE;
        @value.set_enum(severity);
        return true;
      }
      return base.deserialize_property(property_name, ref @value, pspec, property_node);
    }
  }

  public class Server
  {
    const uint check_update_context_period_ms = 200;
    const int64 update_context_delay_inc_us = 200 * 1000;
    const int64 update_context_delay_max_us = 1000 * 1000;
    const uint wait_context_update_delay_ms = 1000;
    const int monitor_file_period_ms = 2500;

    private static Server server = null;

    public static void create_server(MainLoop loop)
    {
      Server.server = new Server(loop);
    }

    MainLoop loop;
    Context context;
    Reporter reporter;
    Jsonrpc.Server rpc_server;
    LintConfig lint_config;

    private Server(MainLoop loop)
    {
      this.loop = loop;

      this.context = new Context();

      // Hack to prevent other things from corrupting JSON-RPC pipe:
      // create a new handle to stdin/stdout, and close the old ones (or move them to stderr)
#if WINDOWS
      int new_stdin_fd = Windows._dup(Posix.STDIN_FILENO);
      int new_stdout_fd = Windows._dup(Posix.STDOUT_FILENO);
      Windows._close(Posix.STDIN_FILENO);
      Windows._dup2(Posix.STDERR_FILENO, Posix.STDOUT_FILENO);
      void* new_stdin_handle = Windows._get_osfhandle(new_stdin_fd);
      void* new_stdout_handle = Windows._get_osfhandle(new_stdout_fd);
#else
      var new_stdin_fd = Posix.dup(Posix.STDIN_FILENO);
      var new_stdout_fd = Posix.dup(Posix.STDOUT_FILENO);
      Posix.close(Posix.STDIN_FILENO);
      Posix.dup2(Posix.STDERR_FILENO, Posix.STDOUT_FILENO);
#endif

      rpc_server = new Jsonrpc.Server();

#if WINDOWS
      var stdin_stream = new Win32InputStream(new_stdin_handle, false);
      var stdout_stream = new Win32OutputStream(new_stdout_handle, false);
#else
      var stdin_stream = new UnixInputStream(new_stdin_fd, false);
      var stdout_stream = new UnixOutputStream(new_stdout_fd, false);
#endif
      var ios = new SimpleIOStream(stdin_stream, stdout_stream);

      rpc_server.accept_io_stream(ios);

      rpc_server.notification.connect((client, method, @params) =>
      {
        if (logdebug) debug(@"Notification received, method: '$(method)', params: '$(params.print(true))'");
        try
        {
          switch (method)
          {
          case "$/cancelRequest":
            on_cancelRequest(client, @params);
            break;
          case "textDocument/didOpen":
            on_textDocument_didOpen(client, @params);
            break;
          case "textDocument/didChange":
            on_textDocument_didChange(client, @params);
            break;
          case "workspace/didChangeConfiguration":
            on_workspace_didChangeConfiguration(client, @params);
            break;
          case "exit":
            on_exit(client, @params);
            break;
          default:
            if (loginfo) info(@"No notification handler for method '$(method)'");
            break;
          }
        }
        catch (Error err)
        {
          if (logwarn) warning(@"Uncaught error: '$(err.message)'");
          if (logwarn) warning("Consider using 'Restart server' command (VSCode) to restart if this is a transient error");
        }
      });

      rpc_server.handle_call.connect((client, method, id, @params) =>
      {
        if (logdebug) debug(@"Call received, method: '$(method)', params: '$(params.print(true))'");
        try
        {
          switch (method)
          {
          case "initialize":
            on_initialize(client, id, @params);
            return true;
          case "shutdown":
            on_shutdown(client, id, @params);
            return true;
          case "textDocument/definition":
            on_textDocument_definition(client, id, @params);
            return true;
          case "textDocument/hover":
            on_textDocument_hover(client, id, @params);
            return true;
          case "textDocument/completion":
            on_textDocument_completion(client, id, @params);
            return true;
          case "textDocument/signatureHelp":
            on_textDocument_signatureHelp(client, id, @params);
            return true;
          case "textDocument/references":
            on_textDocument_references(client, id, @params);
            return true;
          case "textDocument/prepareRename":
            on_textDocument_prepareRename(client, id, @params);
            return true;
          case "textDocument/rename":
            on_textDocument_rename(client, id, @params);
            return true;
          case "textDocument/documentSymbol":
            on_textDocument_documentSymbol(client, id, @params);
            return true;
          case "textDocument/codeAction":
            on_textDocument_codeAction(client, id, @params);
            return true;
          case "textDocument/codeLens":
            on_textDocument_codeLens(client, id, @params);
            return true;
          case "codeLens/resolve":
            on_codeLens_resolve(client, id, @params);
            return true;
          default:
            if (loginfo) info(@"No call handler for method '$(method)'");
            return false;
          }
        }
        catch (Error err)
        {
          if (logwarn) warning(@"Uncaught error: '$(err.message)'");
          if (logwarn) warning("Consider using the 'Restart server' command (VSCode) to restart if this is a transient error");
          client.reply_error_async.begin(id, ErrorCodes.InternalError, err.message, null);
          return true;
        }
      });

      Timeout.add(check_update_context_period_ms, () =>
      {
        try
        {
          check_update_context();
        }
        catch (Error err)
        {
          error(@"Unexpected error: '$(err.message)'");
        }
        return true;
      });
    }

    private void on_initialize(Jsonrpc.Client client, Variant id, Variant @params) throws Error
    {
      var initialize_params = variant_to_object<InitializeParams>(@params);

      if (initialize_params.initializationOptions != null)
      {
        update_server_config(initialize_params.initializationOptions);
      }

      string root_uri = initialize_params.rootUri;

      string root_path = Filename.from_uri(root_uri);
      if (loginfo) info(@"Initialize request received, root path: '$(root_path)'");

      // Check for the build file with the list of sources and compilation flags
      string? build_file = find_file_in_dir(root_path, "vala-language-server.json");
      if (build_file != null)
      {
        if (loginfo) info(@"Build file found '$(build_file)', analyzing...");
        analyze_build_file(root_path, build_file);

        // Analyze again when the file changes
        monitor_file(build_file, false, () =>
        {
          if (loginfo) info(@"Build file '$(build_file)' has changed, reanalyzing...");
          analyze_build_file(root_path, build_file);
          request_update_context(client);
        });
      }
      else
      {
        if (loginfo) info(@"No build file 'vala-language-server.json' found, searching for Meson info");

        string? meson_info_dir = find_file_in_dir(root_path, "meson-info", FileTest.IS_DIR);
        if (meson_info_dir == null)
        {
          throw new VlsError.FAILED(@"Cannot find Meson info directory 'meson-info' under root path '$(root_path)'.");
        }
        string? targets_file = find_file_in_dir(meson_info_dir, "intro-targets.json", FileTest.IS_REGULAR);
        if (meson_info_dir == null)
        {
          throw new VlsError.FAILED(@"Cannot find Meson targets file 'intro-targets.json' under info directory '$(meson_info_dir)'.");
        }

        if (loginfo) info(@"Found Meson targets file '$(targets_file)'");
        analyze_meson_targets(root_path, targets_file);

        // Analyze again when the file changes
        monitor_file(targets_file, false, () =>
        {
          if (loginfo) info(@"Meson targets file '$(targets_file)' has changed, reanalyzing...");
          analyze_meson_targets(root_path, targets_file);
          request_update_context(client);
        });
      }

      string? lint_config_file = find_file_in_dir(root_path, "vala-language-server-lint.json");
      if (lint_config_file != null)
      {
        if (loginfo) info(@"Lint config file '$(lint_config_file)' found, analyzing...");
        analyze_lint_config_file(root_path, lint_config_file);

        // Analyze again when the file changes
        monitor_file(lint_config_file, false, () =>
        {
          if (loginfo) info(@"Lint config file '$(lint_config_file)' has changed, reanalyzing...");
          analyze_lint_config_file(root_path, lint_config_file);
          request_update_context(client);
        });
      }
      else
      {
        if (loginfo) info(@"No lint config file found, using default values...");
        lint_config = new LintConfig();
      }

      var completionCharacters = new JsonArrayList<string>().add_item(".");
      var signatureHelpCharacters = new JsonArrayList<string>().add_item("(");
      var codeActionKinds = new JsonArrayList<CodeActionKind>().add_item(new CodeActionKind(CodeActionKindEnum.QuickFix));
      var capabilities = new ServerCapabilities()
      {
        textDocumentSync = new TextDocumentSyncOptions()
        {
          change = TextDocumentSyncKind.Incremental
        },
        definitionProvider = true,
        hoverProvider = true,
        completionProvider = new CompletionOptions()
        {
          triggerCharacters = completionCharacters
        },
        signatureHelpProvider = new SignatureHelpOptions()
        {
          triggerCharacters = signatureHelpCharacters
        },
        referencesProvider = true,
        renameProvider = new RenameOptions()
        {
          prepareProvider = true
        },
        documentSymbolProvider = true,
        codeActionProvider = new CodeActionOptions()
        {
          codeActionKinds = codeActionKinds
        },
        codeLensProvider = new CodeLensOptions()
        {
          resolveProvider = true
        }
      };
      var result = new InitializeResult()
      {
        capabilities = capabilities
      };
      client.reply(id, object_to_variant(result));

      update_context(client);
    }

    private void monitor_file(string file, bool when_stable, owned ActionFunc action)
    {
      time_t init_file_time = get_file_time(file);
      time_t last_file_time = init_file_time;
      time_t last_action_time = init_file_time;
      Timeout.add(monitor_file_period_ms, () =>
      {
        time_t file_time = get_file_time(file);
        if (last_action_time < file_time)
        {
          if (when_stable && last_file_time != file_time)
          {
            if (loginfo) info(@"Monitored file '$(file)' has changed, will trigger when stable...");
          }
          else
          {
            last_action_time = file_time;
            try
            {
              action();
            }
            catch (Error err)
            {
              error(@"Unexpected error: '$(err.message)'");
            }
          }
        }
        last_file_time = file_time;
        return true;
      });
    }

    private time_t get_file_time(string file)
    {
      return Stat(file).st_mtime;
    }

    private string? find_file_in_dir(string dirname, string target, FileTest? test = null, bool recursive = true) throws Error
    {
      Dir dir = Dir.open(dirname, 0);
      for (string name = dir.read_name(); name != null; name = dir.read_name())
      {
        string filepath = Path.build_filename(dirname, name);
        if (name == target)
        {
          if (test != null && !FileUtils.test(filepath, test))
          {
            throw new VlsError.FAILED(@"Found file ($(filepath)) but it does not satisfy $(test)");
          }
          return filepath;
        }

        if (recursive && FileUtils.test(filepath, FileTest.IS_DIR))
        {
          filepath = find_file_in_dir(filepath, target, test, true);
          if (filepath != null)
          {
            return filepath;
          }
        }
      }

      return null;
    }

    private void analyze_build_file(string root_path, string build_file) throws Error
    {
      Json.Node build_node;
      try
      {
        build_node = parse_json_file(build_file);
      }
      catch (Error err)
      {
        throw new VlsError.FAILED(@"Could not parse build file '$(build_file)' as JSON: '$(err.message)'.");
      }

      BuildConfig config = (BuildConfig)Json.gobject_deserialize(typeof(BuildConfig), build_node);

      if (config.sources == null)
      {
        throw new VlsError.FAILED(@"Build file '$(build_file)' should contain a 'sources' element (string array), this is probably not right.");
      }
      if (config.parameters == null)
      {
        throw new VlsError.FAILED(@"Build file '$(build_file)' should contain a 'parameters' element (string), this is probably not right.");
      }

      foreach (string source in config.sources)
      {
        add_source_path(root_path, source);
      }

      parse_compiler_parameters(config.parameters.replace("\"", ""));
    }

    private void analyze_meson_targets(string root_path, string targets_file) throws Error
    {
      Json.Node targets_node;
      try
      {
        targets_node = parse_json_file(targets_file);
      }
      catch (Error err)
      {
        throw new VlsError.FAILED(@"Could not parse Meson targets file '$(targets_file)' as JSON: '$(err.message)'.");
      }
      if (targets_node.get_node_type() != Json.NodeType.ARRAY)
      {
        throw new VlsError.FAILED(@"Meson did not return an array of targets, please activate the debug logs and check the result from Meson.");
      }

      // Clear context since it will be repopulated from the targets
      context.clear();

      var targets = new JsonArrayList<MesonTarget>();
      bool deserialized = targets.deserialize(targets_node);
      if (!deserialized)
      {
        throw new VlsError.FAILED(@"Could not parse Meson targets, please activate the debug logs to check the result from Meson.");
      }

      bool has_executable_target = false;
      foreach (MesonTarget target in targets)
      {
        if (loginfo) info(@"Meson target: '$(target.name)' ($(target.type_))");

        if (target.type_ != "executable" && !target.type_.has_suffix("library"))
        {
          if (loginfo) info(@"Target is not an executable target and will be ignored");
          continue;
        }

        if (target.type_ == "executable")
        {
          if (has_executable_target)
          {
            if (logwarn) warning(@"Multiple executable targets found in Meson build file, additional executable target will be ignored: '$(target.name)' ($(target.type_)) ignored");
            continue;
          }
          has_executable_target = true;
        }

        if (target.target_sources == null)
        {
          throw new VlsError.FAILED(@"Missing sources in Meson target '$(target.name)' ($(target.type_)), please activate the debug logs to check the result from Meson.");
        }

        foreach (MesonTargetSource target_source in target.target_sources)
        {
          if (target_source.language != "vala")
          {
            continue;
          }

          if (target_source.parameters != null)
          {
            string[] parameters_array = target_source.parameters.to_array();
            string compiler_parameters = string.joinv(" ", parameters_array);
            parse_compiler_parameters(compiler_parameters);
          }

          if (target_source.sources != null)
          {
            foreach (string source in target_source.sources)
            {
              add_source_path(root_path, source);
            }
          }
        }
      }
    }

    private void add_source_path(string root_path, string filepath) throws Error
    {
      filepath = Path.is_absolute(filepath) ? filepath : Path.build_filename(root_path, filepath);

      if (FileUtils.test(filepath, FileTest.IS_DIR))
      {
        if (loginfo) info(@"Found source directory '$(filepath)'");
        Dir dir = Dir.open(filepath, 0);
        for (string name = dir.read_name(); name != null; name = dir.read_name())
        {
          string filename = Path.build_filename(filepath, name);
          add_source_path(root_path, filename);
        }
      }
      else if (is_source_file(filepath))
      {
        string uri = sanitize_file_uri(Filename.to_uri(filepath));
        if (loginfo) info(@"Found source file '$(filepath)' -> '$(uri)'");
        var source_file = new SourceFile(filepath, uri);
        context.add_source_file(source_file);
      }
    }

    private void parse_compiler_parameters(string parameters) throws Error
    {
      if (loginfo) info(@"Compiler parameters: '$(parameters)'");

      MatchInfo match_info;

      if (/--pkg[= ](\S+)/.match(parameters, (GLib.RegexMatchFlags) 0, out match_info))
      {
        do
        {
          string package = match_info.fetch(1);
          if (loginfo) info(@"Found package '$(package)'");
          context.add_package(package);
        }
        while (match_info.next());
      }

      if (/--vapidir[= ](\S+)/.match(parameters, (GLib.RegexMatchFlags) 0, out match_info))
      {
        do
        {
          string vapi_directory = match_info.fetch(1);
          if (loginfo) info(@"Found VAPI directory '$(vapi_directory)'");
          context.add_vapi_directory(vapi_directory);
        }
        while (match_info.next());
      }

      if (/(?:(?:--define[= ])|(?:-D ))(\S+)/.match(parameters, (GLib.RegexMatchFlags) 0, out match_info))
      {
        do
        {
          string define = match_info.fetch(1);
          if (loginfo) info(@"Found define '$(define)'");
          context.add_define(define);
        }
        while (match_info.next());
      }

      if (/--disable-warnings/.match(parameters, (GLib.RegexMatchFlags) 0, out match_info))
      {
        if (loginfo) info("Found '--disable-warnings' flag");
        context.disable_warnings = true;
      }

#if LIBVALA_EXP
      if (/--exp-public-by-default/.match(parameters, (GLib.RegexMatchFlags) 0, out match_info))
      {
        if (loginfo) info("Found '--exp-public-by-default' flag");
        context.exp_public_by_default = true;
      }

      if (/--exp-internal-by-default/.match(parameters, (GLib.RegexMatchFlags) 0, out match_info))
      {
        if (loginfo) info("Found '--exp-internal-by-default' flag");
        context.exp_internal_by_default = true;
      }

      if (/--exp-float-by-default/.match(parameters, (GLib.RegexMatchFlags) 0, out match_info))
      {
        if (loginfo) info("Found '--exp-float-by-default' flag");
        context.exp_float_by_default = true;
      }

      if (/--exp-optional-semicolons/.match(parameters, (GLib.RegexMatchFlags) 0, out match_info))
      {
        if (loginfo) info("Found '--exp-optional-semicolons' flag");
        context.exp_optional_semicolons = true;
      }

      if (/--exp-optional-parens/.match(parameters, (GLib.RegexMatchFlags) 0, out match_info))
      {
        if (loginfo) info("Found '--exp-optional-parens' flag");
        context.exp_optional_parens = true;
      }

      if (/--exp-conditional-attribute/.match(parameters, (GLib.RegexMatchFlags) 0, out match_info))
      {
        if (loginfo) info("Found '--exp-conditional-attribute' flag");
        context.exp_conditional_attribute = true;
      }

      if (/--exp-forbid-delegate-copy/.match(parameters, (GLib.RegexMatchFlags) 0, out match_info))
      {
        if (loginfo) info("Found '--exp-forbid-delegate-copy' flag");
        context.exp_forbid_delegate_copy = true;
      }

      if (/ --exp-disable-implicit-namespace /.match(parameters, (GLib.RegexMatchFlags) 0, out match_info))
      {
        if (loginfo) info("Found '--exp-disable-implicit-namespace' flag");
        context.exp_disable_implicit_namespace = true;
      }

      if (/--exp-integer-literal-separator/.match(parameters, (GLib.RegexMatchFlags) 0, out match_info))
      {
        if (loginfo) info("Found '--exp-integer-literal-separator' flag");
        context.exp_integer_literal_separator = true;
      }
#endif
    }

    private void analyze_lint_config_file(string root_path, string config_file) throws Error
    {
      Json.Node config_node;
      try
      {
        config_node = parse_json_file(config_file);
      }
      catch (Error err)
      {
        throw new VlsError.FAILED(@"Could not parse lint config file '$(config_file)' as JSON: '$(err.message)'.");
      }
      if (logdebug) debug(@"Lint config file parsed:\n$(Json.to_string(config_node, true))");

      lint_config = (LintConfig)Json.gobject_deserialize(typeof(LintConfig), config_node);
    }

    private void on_textDocument_didOpen(Jsonrpc.Client client, Variant @params) throws Error
    {
      var document = @params.lookup_value("textDocument", VariantType.VARDICT);

      string uri = sanitize_file_uri((string)document.lookup_value("uri", VariantType.STRING));
      string language = (string)document.lookup_value("languageId", VariantType.STRING);

      if (loginfo) info(@"Document opened, uri ($(uri)), language ($(language))");

      if (language != "vala" && language != "genie")
      {
        throw new VlsError.FAILED(@"Unsupported language '$(language)' sent to Vala Language Server.");
      }
    }

    private void on_textDocument_didChange(Jsonrpc.Client client, Variant @params) throws Error
    {
      var change_params = variant_to_object<DidChangeTextDocumentParams>(@params);
      string uri = sanitize_file_uri(change_params.textDocument.uri);
      int version = change_params.textDocument.version;

      if (loginfo) info(@"Document changed, URI: '$(uri)', version: $(version)");

      SourceFile? source_file = get_source_file(uri);
      if (source_file == null) return;

      if (source_file.version > version)
      {
        // Seems to cause issues more than anything...
        //  throw new VlsError.FAILED(@"Rejecting outdated version for URI '$(uri)'");
        if (logwarn) warning(@"Received outdated version $(version) vs. file version $(source_file.version) for URI '$(uri)'");
      }
      source_file.version = version;

      var builder = new StringBuilder(source_file.content);
      JsonSerializableCollection<TextDocumentContentChangeEvent> changes = change_params.contentChanges;
      foreach (var change in changes)
      {
        if (change.range == null)
        {
          if (loginfo) info(@"Full text change, filename: '$(source_file.filename)', text: '$(change.text.replace("\r", ""))'");
          builder.assign(change.text);
        }
        else
        {
          string current_text = builder.str;
          Position start = change.range.start, end = change.range.end;
          int start_index = get_char_byte_index(current_text, start.line, start.character);
          int end_index = get_char_byte_index(current_text, end.line, end.character);
          if (loginfo) info(@"Incremental text change, filename: '$(source_file.filename)', start: $(start.line).$(start.character) -> $(start_index), end: $(end.line).$(end.character) -> $(end_index), text '$(change.text)'");
          builder.erase(start_index, end_index - start_index);
          builder.insert(start_index, change.text);
        }
      }
      source_file.content = builder.str;

      request_update_context(client);
    }

    private void on_workspace_didChangeConfiguration(Jsonrpc.Client client, Variant @params) throws Error
    {
      var server_config = variant_to_object<ServerConfig>(@params);
      update_server_config(server_config);
    }

    private int update_context_requests = 0;
    private Jsonrpc.Client update_context_client = null;
    private int64 update_context_time_us = 0;

    private void request_update_context(Jsonrpc.Client client)
    {
      update_context_client = client;
      update_context_requests += 1;
      int64 delay_us = int64.min(update_context_delay_inc_us * update_context_requests, update_context_delay_max_us);
      update_context_time_us = get_time_us() + delay_us;
      if (logdebug) debug(@"Context update (re-)scheduled in $((int) (delay_us / 1000)) ms");
    }

    private void check_update_context() throws Error
    {
      if (update_context_requests > 0 && get_time_us() >= update_context_time_us)
      {
        update_context_requests = 0;
        update_context_time_us = 0;
        update_context(update_context_client);
      }
    }

    private void update_context(Jsonrpc.Client client) throws Error
    {
      show_elapsed_time("Check context", () => reporter = context.check());

      Gee.Collection<SourceFile> source_files = context.get_source_files();
      foreach (SourceFile source_file in source_files)
      {
        var diagnostics = new JsonArrayList<Diagnostic>();

        var errors = reporter.errors_by_file[source_file.file.filename];
        if (errors != null)
        {
          foreach (SourceError error in errors)
          {
            Diagnostic diagnostic = source_error_to_diagnostic(error, DiagnosticSeverity.Error);
            diagnostics.add(diagnostic);
          }
        }

        var warnings = reporter.warnings_by_file[source_file.file.filename];
        if (warnings != null)
        {
          foreach (SourceError error in warnings)
          {
            Diagnostic diagnostic = source_error_to_diagnostic(error, DiagnosticSeverity.Warning);
            diagnostics.add(diagnostic);
          }
        }

        var notes = reporter.notes_by_file[source_file.file.filename];
        if (notes != null)
        {
          foreach (SourceError error in notes)
          {
            Diagnostic diagnostic = source_error_to_diagnostic(error, DiagnosticSeverity.Information);
            diagnostics.add(diagnostic);
          }
        }

        var check_lint = new CheckLintInFile(source_file.file, lint_config);
        check_lint.find();
        diagnostics.add_all(check_lint.diagnostics);

        bool has_diagnostics = !diagnostics.is_empty;
        bool had_diagnostics = source_file.has_diagnostics;
        source_file.has_diagnostics = has_diagnostics;
        // Republish if there are diagnostics for this file or to clear previous diagnostics
        if (has_diagnostics || had_diagnostics)
        {
          if (loginfo) info(@"Sending diagnostics for source file '$(source_file.filename)'");
          var @params = new PublishDiagnosticsParams()
          {
            uri = source_file.uri,
            diagnostics = diagnostics
          };
          client.send_notification("textDocument/publishDiagnostics", object_to_variant(@params));
        }
      }
    }

    private class RequestId
    {
      private int64? int_value;
      private string str_value;

      public RequestId(Variant id) throws Error
      {
        if (id.is_of_type(VariantType.INT64))
        {
          int_value = id.get_int64();
        }
        else if (id.is_of_type(VariantType.STRING))
        {
          str_value = id.get_string();
        }
        else
        {
          throw new VlsError.FAILED(@"Unexpected request identifier: $(id.print(true))");
        }
      }

      public static uint hash(RequestId a)
      {
        if (a.int_value != null)
        {
          return int64_hash(a.int_value);
        }
        else
        {
          return str_hash(a.str_value);
        }
      }

      public static bool equal(RequestId a, RequestId b)
      {
        if (a.int_value != null)
        {
          return a.int_value == b.int_value;
        }
        else
        {
          return a.str_value == b.str_value;
        }
      }

      public string to_string()
      {
        if (int_value != null)
        {
          return int_value.to_string();
        }
        else
        {
          return str_value;
        }
      }
    }

    private Gee.HashSet<RequestId> pending_requests = new Gee.HashSet<RequestId>(RequestId.hash, RequestId.equal);

    private void on_cancelRequest(Jsonrpc.Client client, Variant @params) throws Error
    {
      Variant? id = @params.lookup_value("id", null);
      if (id == null)
      {
        if (logwarn) warning(@"Cannot find request identifier in 'cancel request' notification params: $(@params.print(true))");
        return;
      }

      var request_id = new RequestId(id);
      bool removed = pending_requests.remove(request_id);
      if (removed)
      {
        if (loginfo) info(@"Request ($(request_id)): removed cancelled request from pending requests");
      }
      else
      {
        if (loginfo) info(@"Request ($(request_id)): cancelled request not found in pending requests");
      }
    }

    private delegate void OnContextUpdatedFunc(bool request_cancelled) throws Error;

    private void wait_context_update(Variant id, owned OnContextUpdatedFunc on_context_updated) throws Error
    {
      if (update_context_requests == 0)
      {
        on_context_updated(false);
        return;
      }

      var request_id = new RequestId(id);
      bool added = pending_requests.add(request_id);
      if (!added)
      {
        if (logwarn) warning(@"Request ($(request_id)): request already in pending requests, this should not happen");
      }
      else
      {
        if (loginfo) info(@"Request ($(request_id)): added request to pending requests");
      }

      wait_context_update_aux(request_id, (owned)on_context_updated);
    }

    private void wait_context_update_aux(RequestId request_id, owned OnContextUpdatedFunc on_context_updated) throws Error
    {
      if (update_context_requests == 0)
      {
        bool removed = pending_requests.remove(request_id);
        if (!removed)
        {
          if (loginfo) info(@"Request ($(request_id)): context updated but cancelled");
          on_context_updated(true);
        }
        else
        {
          if (loginfo) info(@"Request ($(request_id)): context updated");
          on_context_updated(false);
        }
      }
      else
      {
        Timeout.add(wait_context_update_delay_ms, () =>
        {
          try
          {
            if (!pending_requests.contains(request_id))
            {
              pending_requests.remove(request_id);
              if (loginfo) info(@"Request ($(request_id)): cancelled before context update");
              on_context_updated(true);
            }
            else
            {
              if (loginfo) info(@"Request ($(request_id)): waiting $(wait_context_update_delay_ms) ms for context update");
              wait_context_update_aux(request_id, (owned)on_context_updated);
            }
          }
          catch (Error err)
          {
            error(@"Unexpected error: '$(err.message)'");
          }
          return false;
        });
      }
    }

    private void on_textDocument_definition(Jsonrpc.Client client, Variant id, Variant @params) throws Error
    {
      var position_params = variant_to_object<TextDocumentPositionParams>(@params);

      Vala.Symbol? symbol = find_symbol_definition_at_position(position_params.textDocument, position_params.position);
      if (symbol == null || symbol.name == null)
      {
        client.reply(id, null);
        return;
      }

      Location? location = get_symbol_location(symbol, symbol, false);
      if (location == null)
      {
        client.reply(id, null);
        return;
      }

      client.reply(id, object_to_variant(location));
    }

    private void on_textDocument_hover(Jsonrpc.Client client, Variant id, Variant @params) throws Error
    {
      var position_params = variant_to_object<TextDocumentPositionParams>(@params);

      Vala.Symbol? symbol = find_symbol_reference_at_position(position_params.textDocument, position_params.position);
      if (symbol == null)
      {
        client.reply(id, null);
        return;
      }

      string definition_code = get_symbol_definition_code_with_comment(symbol);
      if (loginfo) info(@"Found symbol definition code: '$(definition_code)'");

      var hover = new Hover();
      hover.contents = new MarkupContent()
      {
        kind = MarkupContent.KIND_MARKDOWN,
        value = @"```vala\n$(definition_code)\n```"
      };

      client.reply(id, object_to_variant(hover));
    }

    private Vala.Symbol? find_symbol_definition_at_position(TextDocumentIdentifier textDocument, Position position) throws Error
    {
      return find_symbol_reference_at_position(textDocument, position, true);
    }

    private Vala.Symbol? find_symbol_reference_at_position(TextDocumentIdentifier textDocument, Position position, bool prefer_override = false) throws Error
    {
      string uri = sanitize_file_uri(textDocument.uri);
      if (loginfo) info(@"Searching symbol, URI: '$(uri)', position: $(position.line).$(position.character)");

      SourceFile? source_file = get_source_file(uri);
      if (source_file == null) return null;

      Vala.SourceFile file = source_file.file;

      var finder = new FindSymbolReferenceAtPosition(file, position.line + 1, position.character + 1, prefer_override);
      finder.find();
      if (finder.symbols.is_empty)
      {
        if (loginfo) info(@"Cannot find symbol, filename: '$(file.filename)', position: $(position.line).$(position.character)");
        return null;
      }
      if (loginfo) info(@"Found $(finder.symbols.size) symbol(s)");

      Vala.Symbol best_symbol = finder.best_symbol;
      Vala.CodeNode best_node = finder.best_node;
      if (loginfo) info(@"Best symbol: '$(code_node_to_string(best_symbol))', best node: '$(code_node_to_string(best_node))'");

      return best_symbol;
    }

    private void on_textDocument_completion(Jsonrpc.Client client, Variant id, Variant @params) throws Error
    {
      var completion_params = variant_to_object<CompletionParams>(@params);
      CompletionList? completion_list = handle_completion(completion_params);

      if (completion_list == null)
      {
        client.reply(id, null);
        return;
      }

      client.reply(id, object_to_variant(completion_list));
    }

    private CompletionList? handle_completion(CompletionParams completion_params) throws Error
    {
      unowned TextDocumentIdentifier textDocument = completion_params.textDocument;
      string uri = sanitize_file_uri(textDocument.uri);
      unowned Position position = completion_params.position;

      if (loginfo) info(@"Attempting completion, URI: '$(uri)', position: $(position.line).$(position.character)");

      SourceFile? source_file = get_source_file(uri);
      if (source_file == null) return null;

      return CompletionHelpers.get_completion_list(context, source_file, position);
    }

    private void on_textDocument_signatureHelp(Jsonrpc.Client client, Variant id, Variant @params) throws Error
    {
      var position_params = variant_to_object<TextDocumentPositionParams>(@params);
      SignatureHelp? signature_help = handle_signatureHelp(position_params);

      if (signature_help == null)
      {
        client.reply(id, null);
        return;
      }

      client.reply(id, object_to_variant(signature_help));
    }

    private SignatureHelp? handle_signatureHelp(TextDocumentPositionParams position_params) throws Error
    {
      unowned TextDocumentIdentifier textDocument = position_params.textDocument;
      string uri = sanitize_file_uri(textDocument.uri);
      unowned Position position = position_params.position;

      if (loginfo) info(@"Attempting signature help, URI: '$(uri)', position: $(position.line).$(position.character)");

      SourceFile? source_file = get_source_file(uri);
      if (source_file == null) return null;

      return CompletionHelpers.get_signature_help(context, source_file, position);
    }

    private void on_textDocument_references(Jsonrpc.Client client, Variant id, Variant @params) throws Error
    {
      var reference_params = variant_to_object<ReferenceParams>(@params);

      JsonArrayList<Location>? locations = handle_references(reference_params);
      if (locations == null)
      {
        client.reply(id, null);
        return;
      }
      if (loginfo) info(@"Found $(locations.size) location(s)");

      // Bug workaround: sink the floating reference
      Variant result = Json.gvariant_deserialize(locations.serialize(), null);
      client.reply(id, result);
    }

    private JsonArrayList<Location>? handle_references(ReferenceParams reference_params) throws Error
    {
      Vala.Symbol? symbol = find_symbol_reference_at_position(reference_params.textDocument, reference_params.position);
      if (symbol == null || symbol.name == null)
      {
        if (logwarn) warning("Cannot find symbol at position");
        return null;
      }
      if (loginfo) info(@"Found symbol: '$(code_node_to_string(symbol))'");

      Gee.ArrayList<Vala.CodeNode> references = find_symbol_references(symbol, false);
      if (loginfo) info(@"Found $(references.size) reference(s)");

      var locations = new JsonArrayList<Location>();
      foreach (Vala.CodeNode node in references)
      {
        Location? location = get_symbol_location(node, symbol, false);
        if (location == null)
        {
          continue;
        }
        locations.add(location);
      }

      return locations;
    }

    private void on_textDocument_prepareRename(Jsonrpc.Client client, Variant id, Variant @params) throws Error
    {
      wait_context_update(id, (request_cancelled) =>
      {
        if (request_cancelled)
        {
          client.reply(id, null);
          return;
        }

        var position_params = variant_to_object<TextDocumentPositionParams>(@params);

        if (context_has_errors())
        {
          client.reply_error_async.begin(id, ErrorCodes.InvalidRequest, "Cannot rename because of compilation errors", null);
          return;
        }

        string error_message = "Rename impossible here";
        Range? symbol_range = handle_prepareRename(position_params, ref error_message);
        if (symbol_range == null)
        {
          client.reply_error_async.begin(id, ErrorCodes.InvalidRequest, error_message, null);
          return;
        }

        client.reply(id, object_to_variant(symbol_range));
      });
    }

    private Range? handle_prepareRename(TextDocumentPositionParams position_params, ref string error_message) throws Error
    {
      Vala.Symbol? symbol = find_symbol_reference_at_position(position_params.textDocument, position_params.position);
      if (symbol == null || symbol.name == null)
      {
        error_message = "Cannot find symbol under cursor";
        return null;
      }
      if (loginfo) info(@"Found symbol ($(code_node_to_string(symbol)))");

      if (symbol is Vala.TypeSymbol || symbol is Vala.CreationMethod)
      {
        error_message = @"Cannot rename type '$(get_visible_symbol_name(symbol))' (not supported yet)";
        return null;
      }

      if (is_package_code_node(symbol))
      {
        error_message = @"Cannot rename symbol '$(get_visible_symbol_name(symbol))' defined in package file '$(source_reference_basename(symbol.source_reference))'";
        return null;
      }

      Gee.ArrayList<Vala.CodeNode> references = find_symbol_references(symbol, true);
      if (loginfo) info(@"Found $(references.size) reference(s)");

      foreach (Vala.CodeNode node in references)
      {
        Location? location = get_symbol_location(node, symbol, true);

        if (location == null)
        {
          error_message = @"Found reference(s) without symbol name '$(get_visible_symbol_name(symbol))'";
          return null;
        }

        if (is_package_code_node(node))
        {
          error_message = @"Cannot rename symbol '$(get_visible_symbol_name(symbol))' referenced in package file '$(source_reference_basename(node.source_reference))'";
          return null;
        }
      }

      Location? location = get_symbol_location(symbol, symbol, false);
      if (location == null)
      {
        if (loginfo) info(@"Cannot rename symbol '$(code_node_to_string(symbol))', symbol location does not contain symbol name");
        return null;
      }

      return location.range;
    }

    private void on_textDocument_rename(Jsonrpc.Client client, Variant id, Variant @params) throws Error
    {
      var rename_params = variant_to_object<RenameParams>(@params);

      string error_message = "Rename impossible here";
      WorkspaceEdit? workspace_edit = handle_rename(rename_params, ref error_message);
      if (workspace_edit == null)
      {
        client.reply_error_async.begin(id, ErrorCodes.InvalidRequest, error_message, null);
        return;
      }
      if (loginfo) info(@"Found $(workspace_edit.changes.size) edit(s)");

      client.reply(id, object_to_variant(workspace_edit));
    }

    private WorkspaceEdit? handle_rename(RenameParams rename_params, ref string error_message) throws Error
    {
      Vala.Symbol? symbol = find_symbol_reference_at_position(rename_params.textDocument, rename_params.position);
      if (symbol == null)
      {
        error_message = "Cannot find symbol under cursor";
        return null;
      }
      if (loginfo) info(@"Found symbol: '$(code_node_to_string(symbol))'");

      Gee.ArrayList<Vala.CodeNode> references = find_symbol_references(symbol, true);
      if (loginfo) info(@"Found $(references.size) reference(s)");

      var changes = new JsonHashMap<JsonArrayList<TextEdit>>();

      foreach (Vala.CodeNode node in references)
      {
        Location? location = get_symbol_location(node, symbol, true);

        var other_symbol = get_symbol_from_code_node_scope(node, rename_params.newName);
        if (other_symbol != null)
        {
          error_message = @"There is a conflict with a $(get_symbol_type_name(other_symbol)) of the same name";
          return null;
        }

        var text_edit = new TextEdit()
        {
          range = location.range,
          newText = rename_params.newName
        };
        JsonArrayList<TextEdit>? text_edits = changes.get(location.uri);
        if (text_edits == null)
        {
          text_edits = new JsonArrayList<TextEdit>();
          changes.set(location.uri, text_edits);
        }
        text_edits.add(text_edit);
      }

      return new WorkspaceEdit()
        {
          changes = changes
        };
    }

    private Gee.ArrayList<Vala.CodeNode> find_symbol_references(Vala.Symbol target_symbol, bool include_target_symbol)
    {
      var finder = new FindSymbolReferences(context.code_context, target_symbol, include_target_symbol);
      finder.find();
      return finder.references;
    }

    private void on_textDocument_documentSymbol(Jsonrpc.Client client, Variant id, Variant @params) throws Error
    {
      wait_context_update(id, (request_cancelled) =>
      {
        if (request_cancelled)
        {
          client.reply(id, null);
          return;
        }

        var document_symbol_params = variant_to_object<DocumentSymbolParams>(@params);

        JsonSerializableCollection<DocumentSymbol>? document_symbols = handle_documentSymbol(document_symbol_params);
        if (document_symbols == null)
        {
          client.reply(id, null);
          return;
        }
        if (loginfo) info(@"Found $(document_symbols.size) symbol(s)");

        // Bug workaround: sink the floating reference
        Variant result = Json.gvariant_deserialize(document_symbols.serialize(), null);
        client.reply(id, result);
      });
    }

    private JsonSerializableCollection<DocumentSymbol>? handle_documentSymbol(DocumentSymbolParams document_symbol_params) throws Error
    {
      TextDocumentIdentifier textDocument = document_symbol_params.textDocument;

      string uri = sanitize_file_uri(textDocument.uri);
      if (loginfo) info(@"Searching symbols, URI: '$(uri)'");

      SourceFile? source_file = get_source_file(uri);
      if (source_file == null) return null;

      return DocumentSymbolHelpers.get_document_symbols(source_file);
    }

    private void on_textDocument_codeAction(Jsonrpc.Client client, Variant id, Variant @params) throws Error
    {
      wait_context_update(id, (request_cancelled) =>
      {
        if (request_cancelled)
        {
          client.reply(id, null);
          return;
        }

        var code_action_params = variant_to_object<CodeActionParams>(@params);

        JsonSerializableCollection<CodeAction>? actions = handle_codeAction(code_action_params);
        if (actions == null)
        {
          client.reply(id, null);
          return;
        }
        if (loginfo) info(@"Found $(actions.size) action(s)");

        // Bug workaround: sink the floating reference
        Variant result = Json.gvariant_deserialize(actions.serialize(), null);
        client.reply(id, result);
      });
    }

    private JsonSerializableCollection<CodeAction>? handle_codeAction(CodeActionParams code_action_params) throws Error
    {
      TextDocumentIdentifier textDocument = code_action_params.textDocument;

      string uri = sanitize_file_uri(textDocument.uri);
      if (loginfo) info(@"Searching symbols, URI: '$(uri)'");

      SourceFile? source_file = get_source_file(uri);
      if (source_file == null) return null;

      var check_lint = new CheckLintInFile(source_file.file, lint_config, code_action_params.range);
      check_lint.find();
      return check_lint.actions;
    }

    private void on_textDocument_codeLens(Jsonrpc.Client client, Variant id, Variant @params) throws Error
    {
      if (!references_code_lens_enabled)
      {
        client.reply(id, null);
        return;
      }

      wait_context_update(id, (request_cancelled) =>
      {
        if (request_cancelled)
        {
          client.reply(id, null);
          return;
        }

        var code_lens_params = variant_to_object<CodeLensParams>(@params);

        JsonSerializableCollection<CodeLens>? code_lenses = handle_codeLens(code_lens_params);
        if (code_lenses == null)
        {
          client.reply(id, null);
          return;
        }
        if (loginfo) info(@"Found $(code_lenses.size) code lens(es)");

        // Bug workaround: sink the floating reference
        Variant result = Json.gvariant_deserialize(code_lenses.serialize(), null);
        client.reply(id, result);
      });
    }

    private JsonSerializableCollection<CodeLens>? handle_codeLens(CodeLensParams code_lens_params) throws Error
    {
      unowned TextDocumentIdentifier textDocument = code_lens_params.textDocument;

      string uri = sanitize_file_uri(textDocument.uri);
      if (loginfo) info(@"Searching code lens symbols, URI: '$(uri)'");

      if (context_has_errors())
      {
        if (loginfo) info(@"Cannot search code lens because of compilation errors");
        return null;
      }

      SourceFile? source_file = get_source_file(uri);
      if (source_file == null) return null;

      if (is_package_file(source_file.file.filename))
      {
        if (loginfo) info(@"No code lens for package file, URI: '$(uri)'");
        return null;
      }

      var finder = new FindCodeLensSymbolsInFile(source_file.file);
      finder.find();

      var code_lenses = new JsonArrayList<CodeLens>();

      foreach (Vala.Symbol symbol in finder.symbols)
      {
        Range range = source_reference_to_range(symbol.source_reference);
        var data = new CodeLensData()
        {
          textDocument = textDocument
        };
        code_lenses.add(new CodeLens()
        {
          range = range,
          data = data
        });
      }

      return code_lenses;
    }

    private void on_codeLens_resolve(Jsonrpc.Client client, Variant id, Variant @params) throws Error
    {
      var code_lens = variant_to_object<CodeLens>(@params);

      Command? code_lens_command = handle_codeLens_resolve(code_lens);
      if (code_lens_command == null)
      {
        // Not answering or answering with an error will display an even uglier !!MISSING: command!! message
        code_lens.command = new Command()
        {
          title = "[could not resolve]"
        };
        client.reply(id, object_to_variant(code_lens));
        return;
      }

      code_lens.command = code_lens_command;
      client.reply(id, object_to_variant(code_lens));
    }

    private Command? handle_codeLens_resolve(CodeLens code_lens) throws Error
    {
      unowned TextDocumentIdentifier textDocument = code_lens.data.textDocument;
      unowned Range range = code_lens.range;

      string uri = sanitize_file_uri(textDocument.uri);
      if (loginfo) info(@"Resolving code lens, URI: '$(uri)', start: $(range.start.line).$(range.start.character)");

      SourceFile? source_file = get_source_file(uri);
      if (source_file == null) return null;

      var finder = new FindCodeLensSymbolInFile(source_file.file, code_lens.range.start.line + 1, code_lens.range.start.character + 1);
      finder.find();

      Vala.Symbol? symbol = finder.found_symbol;
      if (symbol == null)
      {
        if (logwarn) info(@"Could not find code lens symbol, URI: '$(uri)', start: $(range.start.line).$(range.start.character)");
        return null;
      }

      // Get the base symbol to find every reference (note: this will not return null for this input)
      Vala.Symbol? base_symbol = get_symbol_reference(symbol, false);
      Gee.ArrayList<Vala.CodeNode> references = find_symbol_references(base_symbol, false);

      if (references.size == 0)
      {
        return new Command()
        {
          title = "0 references"
        };
      }

      // Find the exact location of the symbol name to position the cursor
      Location? location = get_symbol_location(symbol, symbol, false);
      var arguments = new JsonArrayList<string>();
      arguments.add(location.range.start.line.to_string());
      arguments.add(location.range.start.character.to_string());

      return new Command()
        {
          title = @"$(references.size) reference$(references.size == 1 ? "" : "s")",
          command = "vls.show.references",
          arguments = arguments
        };
    }

    private bool context_has_errors()
    {

    #if LIBVALA_EXP
      if (reporter == null || reporter.get_errors() > 0 || reporter.get_suppr_errors() > 0)
    #else
      if (reporter == null || reporter.get_errors() > 0)
    #endif
      {
        return true;
      }
      return false;
    }

    private void on_shutdown(Jsonrpc.Client client, Variant id, Variant @params) throws Error
    {
      context.clear();
      client.reply(id, null);
    }

    private void on_exit(Jsonrpc.Client client, Variant @params)
    {
      loop.quit();
    }

    private static T? variant_to_object<T>(Variant variant)
    {
      var node = Json.gvariant_serialize(variant);
      return Json.gobject_deserialize(typeof(T), node);
    }

    private static Variant object_to_variant(Object object) throws Error
    {
      var node = Json.gobject_serialize(object);
      return Json.gvariant_deserialize(node, null);
    }

    private static Json.Node parse_json_file(string filename) throws Error
    {
      var parser = new Json.Parser.immutable_new();
      parser.load_from_file(filename);
      Json.Node? root = parser.get_root();
      if (root == null)
      {
        throw new VlsError.FAILED(@"Unexpected error (root is null)");
      }
      return root;
    }

    private static bool is_source_file(string filename)
    {
      return filename.has_suffix(".vala") || filename.has_suffix(".gs") || filename.has_suffix(".vapi") || filename.has_suffix(".gir");
    }

    private static bool is_package_file(string filename)
    {
      return filename.has_suffix(".vapi") || filename.has_suffix(".gir");
    }

    private SourceFile? get_source_file(string uri) throws Error
    {
      if (!uri.has_prefix("file:"))
      {
        return null;
      }

      SourceFile? source_file = context.get_source_file(uri);
      if (source_file == null)
      {
        if (loginfo)
        {
          info(@"Source file '$(uri)' is not part of the current analysis context.");
          info(@"If this file is supposed to belong to the current project, check that the build file has been found and analyzed correctly.");
        }
        return null;
      }

      return source_file;
    }
  }
}
