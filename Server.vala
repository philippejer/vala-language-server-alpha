namespace VLS
{
  errordomain Error
  {
    FAILED
  }

  class Server
  {
    const int check_diagnostics_period_ms = 100;
    const int64 publish_diagnostics_delay_inc_us = 100 * 1000;
    const int64 publish_diagnostics_delay_max_us = 1000 * 1000;
    const int monitor_file_period_ms = 2500;
    const string completion_symbol_name = "__completion_symbol__";
    const string completion_wildcard_name = "__completion_wildcard__";

    static Regex package_regex;
    static Regex vapidir_regex;
    static Regex define_regex;
    static Regex disable_warnings_regex;

#if LIBVALA_EXPERIMENTAL
    static Regex exp_public_by_default_regex;
    static Regex exp_float_by_default_regex;
    static Regex exp_optional_semicolons_regex;
    static Regex exp_optional_parens_regex;
    static Regex exp_conditional_attribute_regex;
#endif

    static construct
    {
      package_regex = new Regex("--pkg[= ](\\S+)");
      vapidir_regex = new Regex("--vapidir[= ](\\S+)");
      define_regex = new Regex("(?:(?:--define[= ])|(?:-D ))(\\S+)");
      disable_warnings_regex = new Regex("--disable-warnings");
#if LIBVALA_EXPERIMENTAL
      exp_public_by_default_regex = new Regex("--exp-public-by-default");
      exp_float_by_default_regex = new Regex("--exp-float-by-default");
      exp_optional_semicolons_regex = new Regex("--exp-optional-semicolons");
      exp_optional_parens_regex = new Regex("--exp-optional-parens");
      exp_conditional_attribute_regex = new Regex("--exp-conditional-attribute");
#endif
    }

    MainLoop loop;
    Context context;
    Jsonrpc.Server server;

    public Server(MainLoop loop)
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

      this.server = new Jsonrpc.Server();

#if WINDOWS
      var stdin_stream = new Win32InputStream(new_stdin_handle, false);
      var stdout_stream = new Win32OutputStream(new_stdout_handle, false);
#else
      var stdin_stream = new UnixInputStream(new_stdin_fd, false);
      var stdout_stream = new UnixOutputStream(new_stdout_fd, false);
#endif
      var ios = new SimpleIOStream(stdin_stream, stdout_stream);

      server.accept_io_stream(ios);

      server.notification.connect((client, method, @params) =>
      {
        if (logdebug) debug(@"Notification received, method ($(method)), params ($(params.print (true)))");
        try
        {
          switch (method)
          {
          case "textDocument/didOpen":
            on_textDocument_didOpen(client, @params);
            break;
          case "textDocument/didChange":
            on_textDocument_didChange(client, @params);
            break;
          case "exit":
            on_exit(client, @params);
            break;
          default:
            if (loginfo) info(@"No notification handler for method ($(method))");
            break;
          }
        }
        catch (Error err)
        {
          error(@"Uncaught error ($(err.message)))");
        }
      });

      server.handle_call.connect((client, method, id, @params) =>
      {
        if (logdebug) debug(@"Call received, method ($(method)), params ($(params.print (true)))");
        try
        {
          switch (method)
          {
          case "initialize":
            on_initialize(client, method, id, @params);
            return true;
          case "shutdown":
            on_shutdown(client, method, id, @params);
            return true;
          case "textDocument/definition":
            on_textDocument_definition(client, method, id, @params);
            return true;
          case "textDocument/hover":
            on_textDocument_hover(client, method, id, @params);
            return true;
          case "textDocument/completion":
            on_textDocument_completion(client, method, id, @params);
            return true;
          case "textDocument/signatureHelp":
            on_textDocument_signatureHelp(client, method, id, @params);
            return true;
          case "textDocument/references":
            on_textDocument_references(client, method, id, @params);
            return true;
          case "textDocument/prepareRename":
            on_textDocument_prepareRename(client, method, id, @params);
            return true;
          case "textDocument/rename":
            on_textDocument_rename(client, method, id, @params);
            return true;
          case "textDocument/documentSymbol":
            on_textDocument_documentSymbol(client, method, id, @params);
            return true;
          default:
            if (loginfo) info(@"No call handler for method ($(method))");
            return false;
          }
        }
        catch (Error err)
        {
          error(@"Uncaught error ($(err.message)))");
        }
      });

      Timeout.add(check_diagnostics_period_ms, () =>
      {
        check_publishDiagnostics();
        return true;
      });
    }

    private void on_initialize(Jsonrpc.Client client, string method, Variant id, Variant @params)
    {
      var dict = new VariantDict(@params);

      string? root_uri;
      dict.lookup("rootUri", "s", out root_uri);
      string root_path = Filename.from_uri(root_uri);
      if (loginfo) info(@"root_uri ($(root_uri)), root_path ($(root_path))");

      string? meson_file = find_file_in_dir(root_path, "meson.build");
      if (meson_file == null)
      {
        throw new Error.FAILED("Cannot find 'meson.build'");
      }
      string? ninja_file = find_file_in_dir(root_path, "build.ninja");
      if (ninja_file == null)
      {
        throw new Error.FAILED("Cannot find 'build.ninja'");
      }
      string build_dir = Path.get_dirname(ninja_file);
      reanalyze_meson_build(client, root_path, build_dir);

      // Analyze again when the file changes
      monitor_file(ninja_file, false, () => {
        if (loginfo) info("Build file has changed, reanalyzing...");
        reanalyze_meson_build(client, root_path, build_dir);
        request_publishDiagnostics(client);
      });

      try
      {
        var completionCharacters = new JsonArrayList<string>.wrap(new string[] { "." });
        var signatureHelpCharacters = new JsonArrayList<string>.wrap(new string[] { "(" });
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
          documentSymbolProvider = true
        };
        var result = new InitializeResult()
        {
          capabilities = capabilities
        };
        client.reply(id, object_to_variant(result));
      }
      catch (Error err)
      {
        throw new Error.FAILED(@"Failed to reply to client ($(err.message)))");
      }

      send_publishDiagnostics(client);
    }

    private void monitor_file(string file, bool when_stable, owned Action action)
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
            if (loginfo) info(@"File ($(file)) has changed, will trigger when stable...");
          }
          else
          {
            last_action_time = file_time;
            action();
          }
        }
        last_file_time = file_time;
        return true;
      });
    }

    private time_t get_file_time(string file)
    {
      return new Stat(file).st_mtime;
    }

    private string? find_file_in_dir(string dirname, string target)
    {
      Dir dir = Dir.open(dirname, 0);

      string name;
      while ((name = dir.read_name()) != null)
      {
        string filepath = Path.build_filename(dirname, name);
        if (name == target)
        {
          return filepath;
        }

        if (FileUtils.test(filepath, FileTest.IS_DIR))
        {
          filepath = find_file_in_dir(filepath, target);
          if (filepath != null)
          {
            return filepath;
          }
        }
      }

      return null;
    }

    private void reanalyze_meson_build(Jsonrpc.Client? client, string rootdir, string builddir)
    {
      string[] spawn_args = { "meson", "introspect", builddir, "--indent", "--targets" };
      string proc_stdout;
      string proc_stderr;
      int proc_status;

      string meson_command = string.joinv(" ", spawn_args);
      if (loginfo) info(@"Meson introspect command ($(meson_command))");
      Process.spawn_sync(rootdir, spawn_args, null, SpawnFlags.SEARCH_PATH, null, out proc_stdout, out proc_stderr, out proc_status);
      if (proc_status != 0)
      {
        throw new Error.FAILED(@"Meson has returned non-zero status ($(proc_status)) ($(proc_stdout)))");
      }

      // Clear context since it will be repopulated from the targets
      context.clear();

      string targets_json = proc_stdout;
      Json.Node targets_node = parse_json(targets_json);
      if (loginfo) info(@"targets ($(Json.to_string (targets_node, true)))");
      Json.Array targets_array = targets_node.get_array();
      targets_array.foreach_element((array, index, target_node) =>
      {
        Json.Object target_object = target_node.get_object();
        string target_name = target_object.get_string_member("name");
        string target_type = target_object.get_string_member("type");
        if (loginfo) info(@"target ($(target_name)) ($(target_type))");

        Json.Array target_sources_array = target_object.get_array_member("target_sources");
        target_sources_array.foreach_element((array, index, target_source_node) =>
        {

          Json.Object target_source_object = target_source_node.get_object();

          string language = target_source_object.get_string_member("language");
          if (language != "vala")
          {
            return;
          }

          if (target_source_object.has_member("parameters"))
          {
            Json.Array parameters_array = target_source_object.get_array_member("parameters");
            string[] parameters = new string[parameters_array.get_length()];
            parameters_array.foreach_element((array, index, parameter_node) =>
            {
              parameters[index] = parameter_node.get_string();
            });

            MatchInfo match_info;
            string command_parameters = string.joinv(" ", parameters);
            if (loginfo) info(@"Command parameters ($(command_parameters))");
            if (package_regex.match(command_parameters, (GLib.RegexMatchFlags) 0, out match_info))
            {
              do
              {
                string package = match_info.fetch(1);
                if (loginfo) info(@"Adding package ($(package))");
                context.add_package(package);
              }
              while (match_info.next());
            }
            if (vapidir_regex.match(command_parameters, (GLib.RegexMatchFlags) 0, out match_info))
            {
              do
              {
                string vapi_directory = match_info.fetch(1);
                if (loginfo) info(@"Adding vapi directory ($(vapi_directory))");
                context.add_vapi_directory(vapi_directory);
              }
              while (match_info.next());
            }
            if (define_regex.match(command_parameters, (GLib.RegexMatchFlags) 0, out match_info))
            {
              do
              {
                string define = match_info.fetch(1);
                if (loginfo) info(@"Adding define ($(define))");
                context.add_define(define);
              }
              while (match_info.next());
            }
            if (disable_warnings_regex.match(command_parameters, (GLib.RegexMatchFlags) 0, out match_info))
            {
              if (loginfo) info("Setting disable warnings flag");
              context.disable_warnings = true;
            }
#if LIBVALA_EXPERIMENTAL
            if (exp_public_by_default_regex.match(command_parameters, (GLib.RegexMatchFlags) 0, out match_info))
            {
              if (loginfo) info("Setting public by default flag");
              context.exp_public_by_default = true;
            }
            if (exp_float_by_default_regex.match(command_parameters, (GLib.RegexMatchFlags) 0, out match_info))
            {
              if (loginfo) info("Setting float by default flag");
              context.exp_float_by_default = true;
            }
            if (exp_optional_semicolons_regex.match(command_parameters, (GLib.RegexMatchFlags) 0, out match_info))
            {
              if (loginfo) info("Setting optional semicolons flag");
              context.exp_optional_semicolons = true;
            }
            if (exp_optional_parens_regex.match(command_parameters, (GLib.RegexMatchFlags) 0, out match_info))
            {
              if (loginfo) info("Setting optional parens flag");
              context.exp_optional_parens = true;
            }
            if (exp_conditional_attribute_regex.match(command_parameters, (GLib.RegexMatchFlags) 0, out match_info))
            {
              if (loginfo) info("Setting conditional attribute flag");
              context.exp_conditional_attribute = true;
            }
#endif
          }

          if (target_source_object.has_member("sources"))
          {
            Json.Array sources_array = target_source_object.get_array_member("sources");
            sources_array.foreach_element((array, index, source_node) =>
            {
              string anotherfilename = source_node.get_string();
              if (!Path.is_absolute(anotherfilename))
              {
                anotherfilename = Path.build_filename(rootdir, anotherfilename);
              }
              if (is_source_file(anotherfilename))
              {
                string uri = sanitize_file_uri(Filename.to_uri(anotherfilename));
                if (loginfo) info(@"Adding source file ($(anotherfilename)) ($(uri))");
                var my_source_file = new SourceFile.from_internal(anotherfilename, uri);
                context.add_source_file(my_source_file);
              }
            });
          }
        });
      });
    }

    private void on_textDocument_didOpen(Jsonrpc.Client client, Variant @params)
    {
      var document = @params.lookup_value("textDocument", VariantType.VARDICT);

      string uri = sanitize_file_uri((string)document.lookup_value("uri", VariantType.STRING));
      string language = (string)document.lookup_value("languageId", VariantType.STRING);
      string text = (string)document.lookup_value("text", VariantType.STRING);

      if (loginfo) info(@"Document opened, uri ($(uri)), language ($(language))");

      if (language != "vala" && language != "genie")
      {
        throw new Error.FAILED(@"Unsupported language ($(language))) sent to Vala Language Server");
      }
    }

    private void on_textDocument_didChange(Jsonrpc.Client client, Variant @params)
    {
      var change_params = variant_to_object<DidChangeTextDocumentParams>(@params);
      string uri = sanitize_file_uri(change_params.textDocument.uri);
      int version = change_params.textDocument.version;

      if (loginfo) info(@"Document changed, uri ($(uri)), version ($(version))");

      SourceFile? source_file = get_source_file(uri);
      if (source_file == null)
      {
        return;
      }

      if (source_file.version > version)
      {
        throw new Error.FAILED(@"Rejecting outdated version ($(uri)))");
      }
      source_file.version = version;

      Variant? elem = null;
      var builder = new StringBuilder(source_file.content);
      JsonSerializableCollection<TextDocumentContentChangeEvent> changes = change_params.contentChanges;
      foreach (var change in changes)
      {
        if (change.range == null)
        {
          if (loginfo) info(@"Full text change, filename ($(source_file.filename)), text ($(change.text))");
          builder.assign(change.text);
        }
        else
        {
          string current_text = builder.str;
          Position start = change.range.start, end = change.range.end;
          int start_index = get_char_byte_index(current_text, start.line, start.character);
          int end_index = get_char_byte_index(current_text, end.line, end.character);
          if (loginfo) info(@"Incremental text change, filename ($(source_file.filename)), start ($(start.line).$(start.character) -> $(start_index)), end: ($(end.line).$(end.character) -> $(end_index)), text ($(change.text))");
          builder.erase(start_index, end_index - start_index);
          builder.insert(start_index, change.text);
        }
      }
      source_file.content = builder.str;

      request_publishDiagnostics(client);
    }

    private int publish_diagnostics_request = 0;
    private Jsonrpc.Client publish_diagnostics_client = null;
    private uint64 publish_diagnostics_time_us = 0;

    private void request_publishDiagnostics(Jsonrpc.Client client)
    {
      publish_diagnostics_client = client;
      publish_diagnostics_request += 1;
      int64 delay_us = int64.min(publish_diagnostics_delay_inc_us * publish_diagnostics_request, publish_diagnostics_delay_max_us);
      publish_diagnostics_time_us = get_time_us() + delay_us;
      if (loginfo) info(@"Re-scheduled diagnostics in ($((int) (delay_us / 1000))) ms");
    }

    private void check_publishDiagnostics()
    {
      if (publish_diagnostics_request > 0 && get_time_us() >= publish_diagnostics_time_us)
      {
        publish_diagnostics_request = 0;
        publish_diagnostics_time_us = 0;
        send_publishDiagnostics(publish_diagnostics_client);
      }
    }

    private void send_publishDiagnostics(Jsonrpc.Client client)
    {
      Reporter reporter = null;
      debug_action_time("Check context", () => reporter = context.check());

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

        bool has_diagnostics = diagnostics.size > 0;
        bool had_diagnostics = source_file.has_diagnostics;
        source_file.has_diagnostics = has_diagnostics;
        // Republish if there are diagnostics for this file or to clear previous diagnostics
        if (has_diagnostics || had_diagnostics)
        {
          if (loginfo) info(@"Sending diagnostics for source file ($(source_file.filename))");
          var @params = new PublishDiagnosticsParams()
          {
            uri = source_file.uri,
            diagnostics = diagnostics
          };
          client.send_notification("textDocument/publishDiagnostics", object_to_variant(@params));
        }
      }
    }

    private Diagnostic source_error_to_diagnostic(SourceError error, DiagnosticSeverity severity)
    {
      Vala.SourceLocation begin = error.source.begin;
      Vala.SourceLocation end = error.source.end;
      return new Diagnostic()
             {
               range = new Range()
               {
                 start = new Position()
                 {
                   line = begin.line - 1,
                   character = begin.column - 1
                 },
                 end = new Position()
                 {
                   line = end.line - 1,
                   character = end.column
                 }
               },
               severity = severity,
               message = error.message
             };
    }

    private void on_textDocument_definition(Jsonrpc.Client client, string method, Variant id, Variant @params)
    {
      var position_params = variant_to_object<TextDocumentPositionParams>(@params);

      Vala.Symbol? symbol = find_symbol_by_position(position_params.textDocument, position_params.position);
      if (symbol == null || symbol.name == null)
      {
        client.reply(id, null);
        return;
      }

      Location location = get_identifier_location(symbol, symbol.name, false);
      if (location == null)
      {
        client.reply(id, null);
        return;
      }

      client.reply(id, object_to_variant(location));
    }

    private void on_textDocument_hover(Jsonrpc.Client client, string method, Variant id, Variant @params)
    {
      var position_params = variant_to_object<TextDocumentPositionParams>(@params);

      Vala.Symbol? symbol = find_symbol_by_position(position_params.textDocument, position_params.position);
      if (symbol == null)
      {
        client.reply(id, null);
        return;
      }

      string code = get_symbol_definition_code(symbol);
      if (loginfo) info(@"Found symbol definition code ($(code))");

      var hover = new Hover();
      hover.contents = code;
      client.reply(id, object_to_variant(hover));
    }

    private Vala.Symbol? find_symbol_by_position(TextDocumentIdentifier textDocument, Position position)
    {
      string uri = sanitize_file_uri(textDocument.uri);
      if (loginfo) info(@"Searching symbol, uri ($(uri)), position: ($(position.line).$(position.character))");

      SourceFile? source_file = get_source_file(uri);
      if (source_file == null)
      {
        return null;
      }
      Vala.SourceFile file = source_file.file;

      var find_symbol = new FindSymbolByPosition(file, position.line + 1, position.character + 1);
      find_symbol.find();
      if (find_symbol.symbols.size == 0)
      {
        if (loginfo) info(@"Cannot find symbol, filename ($(file.filename)), position: ($(position.line).$(position.character))");
        return null;
      }
      if (loginfo) info(@"Found $(find_symbol.symbols.size) symbol(s)");

      Vala.Symbol best_symbol = find_symbol.best_symbol;
      if (loginfo) info(@"Best symbol ($(code_node_to_string (best_symbol)))");

      return best_symbol;
    }

    private void on_textDocument_completion(Jsonrpc.Client client, string method, Variant id, Variant @params)
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

    private CompletionList? handle_completion(CompletionParams completion_params)
    {
      TextDocumentIdentifier textDocument = completion_params.textDocument;
      string uri = sanitize_file_uri(textDocument.uri);
      Position position = completion_params.position;

      if (loginfo) info(@"Attempting completion, uri ($(uri)), position: ($(position.line).$(position.character))");

      SourceFile? source_file = get_source_file(uri);
      if (source_file == null)
      {
        return null;
      }

      string completion_member;
      Gee.Map<string, OrderedSymbol>? symbols = get_completion_symbols(source_file, position.line, position.character, out completion_member);
      if (symbols == null)
      {
        return null;
      }

      var completion_list = new CompletionList();
      completion_list.isIncomplete = false;
      var completion_items = new JsonArrayList<CompletionItem>();
      completion_list.items = completion_items;
      Gee.MapIterator<string, OrderedSymbol> iter = symbols.map_iterator();
      for (bool has_next = iter.next(); has_next; has_next = iter.next())
      {
        string name = iter.get_key();
        OrderedSymbol ordered_symbol = iter.get_value();
        Vala.Symbol symbol = ordered_symbol.symbol;
        string code = get_symbol_definition_code(symbol);
        var completion_item = new CompletionItem();
        completion_item.label = name;
        completion_item.detail = code;
        completion_item.sortText = "%03d:%s".printf(ordered_symbol.order, code);
        completion_item.insertText = name;
        completion_item.insertTextFormat = InsertTextFormat.PlainText;
        if (symbol is Vala.Field)
        {
          completion_item.kind = CompletionItemKind.Field;
        }
        if (symbol is Vala.Property)
        {
          completion_item.kind = CompletionItemKind.Property;
        }
        if (symbol is Vala.Variable || symbol is Vala.Parameter)
        {
          completion_item.kind = CompletionItemKind.Variable;
        }
        if (symbol is Vala.Method)
        {
          completion_item.kind = CompletionItemKind.Method;
        }
        if (symbol is Vala.Delegate)
        {
          completion_item.kind = CompletionItemKind.Method;
        }
        if (symbol is Vala.Class || symbol is Vala.Struct)
        {
          completion_item.kind = CompletionItemKind.Class;
        }
        if (symbol is Vala.Enum || symbol is Vala.ErrorDomain)
        {
          completion_item.kind = CompletionItemKind.Enum;
        }
        if (symbol is Vala.EnumValue || symbol is Vala.ErrorCode)
        {
          completion_item.kind = CompletionItemKind.EnumMember;
        }
        if (symbol is Vala.Interface)
        {
          completion_item.kind = CompletionItemKind.Interface;
        }
        if (symbol is Vala.Namespace)
        {
          completion_item.kind = CompletionItemKind.Module;
        }
        completion_items.add(completion_item);
      }

      return completion_list;
    }

    private void on_textDocument_signatureHelp(Jsonrpc.Client client, string method, Variant id, Variant @params)
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

    private SignatureHelp? last_signatureHelp = null;

    private SignatureHelp? handle_signatureHelp(TextDocumentPositionParams position_params)
    {
      TextDocumentIdentifier textDocument = position_params.textDocument;
      string uri = sanitize_file_uri(textDocument.uri);
      Position position = position_params.position;

      if (loginfo) info(@"Attempting signature help, uri ($(uri)), position: ($(position.line).$(position.character))");

      SourceFile? source_file = get_source_file(uri);
      if (source_file == null)
      {
        return null;
      }

      uint line = position.line, character = position.character;
      int index = get_char_byte_index(source_file.content, line, character) - 1;
      string source = source_file.content;
      if (source[index] != '(')
      {
        if (source[index] == ')')
        {
          last_signatureHelp = null;
        }
        return last_signatureHelp;
      }
      while (index >= 0 && source[index] != '\n' && !source[index].isalnum() && source[index] != '_')
      {
        character -= 1;
        index -= 1;
      }
      if (!source[index].isalnum() && source[index] != '_')
      {
        if (loginfo) info("Cannot backtrack to method name");
        return null;
      }

      string completion_member;
      Gee.Map<string, OrderedSymbol>? symbols = get_completion_symbols(source_file, line, character, out completion_member);

      if (symbols == null)
      {
        return null;
      }

      OrderedSymbol? ordered_symbol = symbols.get(completion_member);
      if (ordered_symbol == null)
      {
        warning(@"Completion member is not in the completion symbols ($(completion_member))");
        return null;
      }

      Vala.Symbol completion_symbol = ordered_symbol.symbol;
      Vala.Method? completion_method = completion_symbol as Vala.Method;
      if (completion_method == null)
      {
        warning(@"Completion symbol is not a method ($(code_node_to_string (completion_symbol)))");
        return null;
      }

      var signature_information = new SignatureInformation();
      signature_information.label = get_symbol_definition_code(completion_method);
      signature_information.parameters = new JsonArrayList<ParameterInformation>();
      Vala.List<Vala.Parameter> parameters = completion_method.get_parameters();
      var signature_help = new SignatureHelp();
      signature_help.signatures = new JsonArrayList<SignatureInformation>();
      signature_help.signatures.add(signature_information);
      signature_help.activeSignature = 0;

      last_signatureHelp = signature_help;

      return signature_help;
    }

    private bool completion_pending = false;

    private Gee.Map<string, OrderedSymbol>? get_completion_symbols(SourceFile source_file, uint line, uint character, out string completion_member)
    {
      string current_source = source_file.content;
      try
      {
        int position_index = get_char_byte_index(source_file.content, line, character);
        string completion_expression = extract_completion_expression(source_file.content, position_index);
        if (completion_expression.has_suffix(".") || completion_expression == "")
        {
          completion_expression += completion_wildcard_name;
        }
        if (loginfo) info(@"Completion expression ($(completion_expression))");

        int line_index = get_char_byte_index(source_file.content, line, 0);
        int start_index = skip_source_spaces(source_file.content, line_index);
        int next_line_index = get_char_byte_index(source_file.content, line + 1, 0);
        string line_str = source_file.content.slice(line_index, next_line_index);
        string insert_str = @"int $(completion_symbol_name) = $(completion_expression); ";
        if (line_str.contains("{"))
        {
          insert_str += "{";
        }
        insert_str += "//";
        source_file.content = source_file.content.splice(start_index, start_index, insert_str);

        context.check();
        return handle_completion_aux(source_file, out completion_member);
      }
      finally
      {
        source_file.content = current_source;
      }
    }

    private static string extract_completion_expression(string source, int index)
    {
      int current = index - 1;
      int num_delimiters = 0;
      bool in_string = false;
      bool in_triple_string = false;
      bool in_space = false;
      while (current >= 0)
      {
        char c = source[current];
        if (in_string)
        {
          if (c == '"')
          {
            if (in_triple_string && current >= 2 && source[current - 1] == '"' && source[current - 2] == '"')
            {
              in_triple_string = false;
              in_string = false;
            }
            else if (current >= 1 && source[current - 1] != '\\')
            {
              in_string = false;
            }
          }
        }
        else
        {
          if (c == '"')
          {
            in_string = true;
            if (current >= 2 && source[current - 1] == '"' && source[current - 2] == '"')
            {
              in_triple_string = true;
              current -= 2;
            }
          }
          else if (c == ')' || c == ']')
          {
            num_delimiters += 1;
          }
          else if (num_delimiters > 0 && (c == '(' || c == '['))
          {
            num_delimiters -= 1;
          }
          else if (num_delimiters == 0 && !c.isspace() && !c.isalnum() && c != '_' && c != '.')
          {
            break;
          }
          else if (num_delimiters == 0 && in_space && c.isalnum())
          {
            break;
          }
          in_space = c.isspace();
        }
        current -= 1;
      }
      return source.slice(current + 1, index).strip();
    }

    private Gee.Map<string, OrderedSymbol>? handle_completion_aux(SourceFile source_file, out string completion_member)
    {
      Vala.Symbol? completion_symbol = find_symbol_by_name(source_file.file, completion_symbol_name);
      if (completion_symbol == null)
      {
        return null;
      }

      var completion_variable = completion_symbol as Vala.Variable;
      if (completion_variable == null)
      {
        warning("Completion symbol is not a variable");
        return null;
      }

      if (loginfo) info(@"Completion symbol ($(code_scope_to_string (completion_variable)))");
      if (loginfo) info(@"Completion symbol initializer ($(code_node_to_string (completion_variable.initializer)))");

      Vala.MemberAccess? completion_initializer = completion_variable.initializer as Vala.MemberAccess;
      if (completion_initializer == null)
      {
        warning("Completion initializer is not a member access");
        return null;
      }

      Vala.TypeSymbol? parent_type = get_node_parent_of_type<Vala.TypeSymbol>(completion_variable);
      Vala.Symbol? parent_ancestor_type = get_ancestor_type(parent_type);
      Vala.Method? parent_method = get_node_parent_of_type<Vala.Method>(completion_variable);
      Vala.Namespace? parent_namespace = get_node_parent_of_type<Vala.Namespace>(completion_variable);
      if (loginfo) info(@"Completion symbol parent type ($(code_scope_to_string (parent_type)))");
      if (loginfo) info(@"Completion symbol ancestor type ($(code_scope_to_string (parent_ancestor_type)))");
      if (loginfo) info(@"Completion symbol parent method ($(code_scope_to_string (parent_method)))");
      if (loginfo) info(@"Completion symbol parent namespace ($(code_scope_to_string (parent_namespace)))");

      completion_member = completion_initializer.member_name;
      Vala.Expression? completion_inner = completion_initializer.inner;
      if (completion_inner == null)
      {
        Gee.Map<string, OrderedSymbol> global_symbols = get_global_symbols(completion_variable, SymbolFlags.ALL);
        if (completion_member != completion_wildcard_name)
        {
          filter_completion_symbols(global_symbols, completion_member);
        }
        return global_symbols;
      }
      if (loginfo) info(@"Completion inner expression ($(code_scope_to_string (completion_inner)))");

      bool is_instance;
      Vala.Symbol? completion_inner_type = get_expression_type(completion_inner, out is_instance);
      if (completion_inner_type == null)
      {
        warning("Completion inner expression has no type");
        return null;
      }
      if (loginfo) info(@"Completion inner expression type ($(is_instance ? "instance " : "class ")) ($(code_scope_to_string (completion_inner_type)))");

      Vala.Symbol? completion_inner_ancestor_type = get_ancestor_type(completion_inner_type);
      if (loginfo) info(@"Completion inner expression ancestor type ($(code_scope_to_string (completion_inner_ancestor_type)))");

      Vala.Namespace? completion_inner_namespace = get_node_parent_of_type<Vala.Namespace>(completion_inner_type);
      if (loginfo) info(@"Completion inner expression namespace ($(code_scope_to_string (completion_inner_namespace)))");

      bool is_same_type = completion_inner_type == parent_type;
      bool is_related_type = completion_inner_ancestor_type == parent_ancestor_type;
      bool is_same_namespace = completion_inner_namespace == parent_namespace;

      SymbolFlags flags = SymbolFlags.NONE;
      if (is_instance)
      {
        flags |= SymbolFlags.INSTANCE;
      }
      if (is_same_type)
      {
        flags |= SymbolFlags.PRIVATE;
      }
      if (is_related_type)
      {
        flags |= SymbolFlags.PROTECTED;
      }
      if (is_same_namespace)
      {
        flags |= SymbolFlags.INTERNAL;
      }
      if (loginfo) info(@"Available symbols ($(flags)) ($(symbol_scope_to_string (completion_inner_type, flags)))");

      return get_extended_symbols(completion_inner_type, flags);
    }

    private Vala.Symbol? find_symbol_by_name(Vala.SourceFile file, string name)
    {
      var find_symbol = new FindSymbolByName(file, name);
      find_symbol.find();
      if (find_symbol.symbols.size == 0)
      {
        if (loginfo) info("Cannot find completion symbol");
        return null;
      }
      if (find_symbol.symbols.size > 1)
      {
        warning("Multiple completion symbols");
        return null;
      }

      Gee.Iterator<Vala.Symbol> iterator = find_symbol.symbols.iterator();
      iterator.next();
      return iterator.get();
    }

    private void filter_completion_symbols(Gee.Map<string, OrderedSymbol> symbols, string name)
    {
      string name_down = name.down();
      Gee.MapIterator<string, OrderedSymbol> iter = symbols.map_iterator();
      for (bool has_next = iter.next(); has_next; has_next = iter.next())
      {
        string symbol_name = iter.get_key();
        if (!symbol_name.down().has_prefix(name_down))
        {
          iter.unset();
        }
      }
    }

    private static int skip_source_spaces(string source, int index)
    {
      while (source[index].isspace() && source[index] != '\n')
      {
        index += 1;
      }
      return index;
    }

    private void on_textDocument_references(Jsonrpc.Client client, string method, Variant id, Variant @params)
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

    private JsonArrayList<Location> handle_references(ReferenceParams reference_params)
    {
      Vala.Symbol? symbol = find_symbol_by_position(reference_params.textDocument, reference_params.position);
      if (symbol == null || symbol.name == null)
      {
        warning("Cannot find symbol at position");
        return null;
      }
      if (loginfo) info(@"Found symbol ($(code_node_to_string (symbol)))");

      Gee.ArrayList<Vala.CodeNode> references = find_symbol_references(symbol, true);
      if (loginfo) info(@"Found $(references.size) reference(s)");

      var locations = new JsonArrayList<Location>();

      foreach (Vala.CodeNode node in references)
      {
        Location location = get_identifier_location(node, symbol.name, false);
        if (location == null)
        {
          continue;
        }
        locations.add(location);
      }

      return locations;
    }

    private void on_textDocument_prepareRename(Jsonrpc.Client client, string method, Variant id, Variant @params)
    {
      var position_params = variant_to_object<TextDocumentPositionParams>(@params);

      string error_message = "Rename impossible here";
      Range? symbol_range = handle_prepareRename(position_params, ref error_message);
      if (symbol_range == null)
      {
        client.reply_error_async(id, ErrorCodes.InvalidRequest, error_message, null);
        return;
      }

      client.reply(id, object_to_variant(symbol_range));
    }

    private Range? handle_prepareRename(TextDocumentPositionParams position_params, ref string error_message)
    {
      Vala.Symbol? symbol = find_symbol_by_position(position_params.textDocument, position_params.position);
      if (symbol == null || symbol.name == null)
      {
        warning("Cannot find symbol at position");
        error_message = "Cannot identify symbol under cursor";
        return null;
      }
      if (loginfo) info(@"Found symbol ($(code_node_to_string (symbol)))");

      Gee.ArrayList<Vala.CodeNode> references = find_symbol_references(symbol, true);
      if (loginfo) info(@"Found $(references.size) reference(s)");

      foreach (Vala.CodeNode node in references)
      {
        Location? location = get_identifier_location(node, symbol.name, true);
        if (location == null)
        {
          error_message = @"Found reference(s) without symbol name ($(symbol.name))";
          return null;
        }
        if (node.source_reference.file.filename.has_suffix(".vapi"))
        {
          warning(@"Cannot rename symbol ($(symbol.name)) because it referenced in VAPI ($(node.source_reference.file.filename))");
          error_message = @"Symbol ($(symbol.name)) is referenced in VAPI";
          return null;
        }
      }

      Location? symbol_location = get_identifier_location(symbol, symbol.name, false);
      if (symbol_location == null)
      {
        warning(@"Symbol does not contain symbol name ($(code_node_to_string (symbol)))");
        return null;
      }
      return symbol_location.range;
    }

    private void on_textDocument_rename(Jsonrpc.Client client, string method, Variant id, Variant @params)
    {
      var rename_params = variant_to_object<RenameParams>(@params);

      WorkspaceEdit? workspace_edit = handle_rename(rename_params);
      if (workspace_edit == null)
      {
        client.reply(id, null);
        return;
      }
      if (loginfo) info(@"Found $( workspace_edit.changes.size) edit(s)");

      client.reply(id, object_to_variant(workspace_edit));
    }

    private WorkspaceEdit? handle_rename(RenameParams rename_params)
    {
      Vala.Symbol? symbol = find_symbol_by_position(rename_params.textDocument, rename_params.position);
      if (symbol == null)
      {
        warning("Cannot find symbol at position");
        return null;
      }
      if (loginfo) info(@"Found symbol ($(code_node_to_string (symbol)))");

      Gee.ArrayList<Vala.CodeNode> references = find_symbol_references(symbol, true);
      if (loginfo) info(@"Found $(references.size) reference(s)");

      var changes = new JsonHashMap<JsonArrayList<TextEdit>>();

      foreach (Vala.CodeNode node in references)
      {
        Location location = get_identifier_location(node, symbol.name, true);
        if (location == null)
        {
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
      var find_symbol = new FindSymbolReferences(context.code_context, target_symbol, include_target_symbol);
      find_symbol.find();
      return find_symbol.references;
    }

    private void on_textDocument_documentSymbol(Jsonrpc.Client client, string method, Variant id, Variant @params)
    {
      var document_symbol_params = variant_to_object<DocumentSymbolParams>(@params);

      JsonSerializableCollection<DocumentSymbol>? document_symbols = handle_documentSymbol(document_symbol_params);
      if (document_symbols == null)
      {
        client.reply(id, null);
        return;
      }
      if (loginfo) info(@"Found $(document_symbols.size) symbols(s)");

      // Bug workaround: sink the floating reference
      Variant result = Json.gvariant_deserialize(document_symbols.serialize(), null);
      client.reply(id, result);
    }

    private JsonSerializableCollection<DocumentSymbol>? handle_documentSymbol(DocumentSymbolParams document_symbol_params)
    {
      Gee.HashSet<Vala.Symbol> symbols = find_symbols_in_file(document_symbol_params.textDocument);

      var document_symbol_map = new Gee.HashMap<Vala.Symbol, DocumentSymbol>();
      foreach (Vala.Symbol symbol in symbols)
      {
        if (logdebug) debug(@"process symbol ($(code_node_to_string (symbol)))");
        DocumentSymbol? document_symbol = add_document_symbol_to_map(symbol, document_symbol_map);
      }

      JsonSerializableCollection<DocumentSymbol> document_symbols = null;
      foreach (Gee.Map.Entry<Vala.Symbol, DocumentSymbol> entry in document_symbol_map.entries)
      {
        Vala.Symbol symbol = entry.key;
        DocumentSymbol document_symbol = entry.value;
        if (symbol is Vala.Namespace && symbol.name == null)
        {
          if (document_symbols != null)
          {
            warning("There are several root symbols");
          }
          extend_document_symbol_range(document_symbol);
          document_symbols = document_symbol.children;
        }
      }

      return document_symbols;
    }

    private void extend_document_symbol_range(DocumentSymbol document_symbol)
    {
      foreach (DocumentSymbol child_document_symbol in document_symbol.children)
      {
        extend_document_symbol_range(child_document_symbol);
        if (document_symbol.range != null)
        {
          extend_ranges(document_symbol.range, child_document_symbol.range);
        }
      }
    }

    private DocumentSymbol add_document_symbol_to_map(Vala.Symbol symbol, Gee.HashMap<Vala.Symbol, DocumentSymbol> document_symbol_map)
    {
      DocumentSymbol? document_symbol = document_symbol_map.get(symbol);
      if (document_symbol == null)
      {
        DocumentSymbol? parent_document_symbol = null;
        if (symbol.parent_symbol != null)
        {
          parent_document_symbol = add_document_symbol_to_map(symbol.parent_symbol, document_symbol_map);
          if (parent_document_symbol == null)
          {
            return null;
          }
          if (logdebug) debug(@"created parent document symbol for $(symbol.parent_symbol.name) ($(ptr_to_string (symbol.parent_symbol)), $(symbol.parent_symbol.type_name)) -> $(symbol.name) ($(ptr_to_string (symbol)), $(symbol.type_name))");
        }
        document_symbol = symbol_to_document_symbol(symbol);
        if (document_symbol == null)
        {
          return null;
        }
        if (logdebug) debug(@"created document symbol for $(symbol.name) ($(ptr_to_string (symbol)), $(symbol.type_name))");
        if (parent_document_symbol != null)
        {
          parent_document_symbol.children.add(document_symbol);
        }
        document_symbol_map.set(symbol, document_symbol);
      }
      return document_symbol;
    }

    private DocumentSymbol? symbol_to_document_symbol(Vala.Symbol symbol)
    {
      var document_symbol = new DocumentSymbol();

      document_symbol.name = symbol.name;

      if (symbol.source_reference != null && document_symbol.range == null)
      {
        document_symbol.range = source_reference_to_range(symbol.source_reference);
      }

      if (symbol is Vala.Field)
      {
        if (symbol.name != null && symbol.name.has_prefix("_"))
        {
          if (symbol.owner.lookup((string)(&symbol.name.data[1])) != null)
          {
            if (logdebug) debug(@"Field is hidden ($(code_node_to_string (symbol))) ($(symbol.anonymous))");
            return null;
          }
        }
        document_symbol.kind = SymbolKind.Field;
      }
      else if (symbol is Vala.Property)
      {
        document_symbol.kind = SymbolKind.Property;
      }
      else if (symbol is Vala.Method)
      {
        if (symbol is Vala.CreationMethod)
        {
          if (symbol.name == ".new")
          {
            document_symbol.name = ((Vala.CreationMethod)symbol).class_name;
          }
          else
          {
            document_symbol.name = ((Vala.CreationMethod)symbol).class_name + "." + document_symbol.name;
          }
        }
        document_symbol.kind = SymbolKind.Method;
        Vala.Method method = (Vala.Method)symbol;
        if (method.body != null)
        {
          extend_ranges(document_symbol.range, source_reference_to_range(method.body.source_reference));
        }
      }
      else if (symbol is Vala.Destructor)
      {
        document_symbol.name = "~" + symbol.parent_symbol.name;
        document_symbol.kind = SymbolKind.Method;
        Vala.Destructor destructor = (Vala.Destructor)symbol;
        if (destructor.body != null)
        {
          extend_ranges(document_symbol.range, source_reference_to_range(destructor.body.source_reference));
        }
      }
      else if (symbol is Vala.Class || symbol is Vala.Struct)
      {
        document_symbol.kind = SymbolKind.Class;
      }
      else if (symbol is Vala.Enum || symbol is Vala.ErrorDomain)
      {
        document_symbol.kind = SymbolKind.Enum;
      }
      else if (symbol is Vala.EnumValue || symbol is Vala.ErrorCode)
      {
        document_symbol.kind = SymbolKind.EnumMember;
      }
      else if (symbol is Vala.Interface)
      {
        document_symbol.kind = SymbolKind.Interface;
      }
      else if (symbol is Vala.Namespace)
      {
        document_symbol.kind = SymbolKind.Module;
      }
      else
      {
        if (logdebug) debug(@"Symbol not returned ($(code_node_to_string (symbol)))");
        return null;
      }

      if (document_symbol.selectionRange == null)
      {
        document_symbol.selectionRange = document_symbol.range;
        if (symbol.name != null)
        {
          Location? location = get_identifier_location(symbol, document_symbol.name, false);
          if (location != null)
          {
            document_symbol.selectionRange = location.range;
          }
        }
      }

      document_symbol.detail = get_symbol_definition_code(symbol);
      document_symbol.children = new JsonArrayList<DocumentSymbol>();

      return document_symbol;
    }

    private Gee.HashSet<Vala.Symbol> find_symbols_in_file(TextDocumentIdentifier textDocument)
    {
      string uri = sanitize_file_uri(textDocument.uri);
      if (loginfo) info(@"Searching symbols, uri ($(uri))");

      SourceFile? source_file = get_source_file(uri);
      if (source_file == null)
      {
        return null;
      }

      var find_symbol = new FindSymbolsInFile(source_file.file);
      find_symbol.find();
      return find_symbol.symbols;
    }

    private void on_shutdown(Jsonrpc.Client client, string method, Variant id, Variant @params)
    {
      context.clear();
      client.reply(id, null);
    }

    private void on_exit(Jsonrpc.Client client, Variant @params)
    {
      loop.quit();
    }

    // Takes a (line, character) position from VS code (0-based) and returns the corresponding byte offset.
    private static int get_char_byte_index(string text, uint position_line, uint position_character)
    {
      int index = -1;
      for (uint line = 0; line < position_line; ++line)
      {
        int next_index = text.index_of_char('\n', index + 1);
        if (next_index == -1)
        {
          break;
        }
        index = next_index;
      }
      return index + 1 + text.substring(index + 1).index_of_nth_char((long)position_character);
    }

    private static T? variant_to_object<T>(Variant variant)
    {
      var node = Json.gvariant_serialize(variant);
      return Json.gobject_deserialize(typeof (T), node);
    }

    private static Variant object_to_variant(Object object) throws Error
    {
      var node = Json.gobject_serialize(object);
      return Json.gvariant_deserialize(node, null);
    }

    private static Json.Node parse_json(string json)
    {
      var parser = new Json.Parser.immutable_new();
      parser.load_from_data(json);
      return parser.get_root();
    }

    private static bool is_source_file(string filename)
    {
      return filename.has_suffix(".vapi") || filename.has_suffix(".vala") || filename.has_suffix(".gs");
    }

    private SourceFile? get_source_file(string uri)
    {
      if (!uri.has_prefix("file:"))
      {
        return null;
      }
      SourceFile? source_file = context.get_source_file(uri);
      if (source_file == null)
      {
        throw new Error.FAILED(@"Cannot get source file: $(uri)");
      }
      return source_file;
    }
  }
}
