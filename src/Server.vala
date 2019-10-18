namespace Vls
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
        if (logdebug) debug(@"Notification received, method ($(method)), params ($(params.print(true)))");
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
        if (logdebug) debug(@"Call received, method ($(method)), params ($(params.print(true)))");
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
      monitor_file(ninja_file, false, () =>
      {
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
      if (logdebug) debug(@"targets ($(Json.to_string(targets_node, true)))");
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

      string code = get_symbol_definition_code_with_comment(symbol);
      if (loginfo) info(@"Found symbol definition code ($(code))");

      var hover = new Hover();
      hover.contents = new MarkupContent()
      {
        kind = MarkupContent.KIND_MARKDOWN,
        value = @"```vala\n$(code)\n```"
      };

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
      if (loginfo) info(@"Best symbol ($(code_node_to_string(best_symbol)))");

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

      return get_completion_list(context, source_file, position);
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

      return get_signature_help(context, source_file, position);
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
        if (logwarn) warning("Cannot find symbol at position");
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
        if (logwarn) warning("Cannot find symbol at position");
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
          if (logwarn) warning(@"Cannot rename symbol ($(symbol.name)) because it referenced in VAPI ($(node.source_reference.file.filename))");
          error_message = @"Symbol ($(symbol.name)) is referenced in VAPI";
          return null;
        }
      }

      Location? symbol_location = get_identifier_location(symbol, symbol.name, false);
      if (symbol_location == null)
      {
        if (logwarn) warning(@"Symbol does not contain symbol name ($(code_node_to_string (symbol)))");
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
        if (logwarn) warning("Cannot find symbol at position");
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
      TextDocumentIdentifier textDocument = document_symbol_params.textDocument;

      string uri = sanitize_file_uri(textDocument.uri);
      if (loginfo) info(@"Searching symbols, uri ($(uri))");

      SourceFile? source_file = get_source_file(uri);
      if (source_file == null)
      {
        return null;
      }

      return get_document_symbols(source_file);
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
