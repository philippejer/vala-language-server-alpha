namespace Vls
{
  public class CheckLintInFile : FindNodeInFile
  {
    private LintConfig config;

    private Range? range;

    private uint start_line;
    private uint start_column;
    private uint end_line;
    private uint end_column;

    public JsonArrayList<Diagnostic> diagnostics = new JsonArrayList<Diagnostic>();
    public JsonArrayList<CodeAction>? actions;
    public CodeAction? no_implicit_this_access_in_file;
    public CodeAction? no_unqualified_static_access_in_file;

    public CheckLintInFile(Vala.SourceFile file, LintConfig config, Range? range = null)
    {
      base(file);

      this.config = config;
      this.range = range;

      if (range != null)
      {
        this.start_line = range.start.line + 1;
        this.start_column = range.start.character + 1;
        this.end_line = range.end.line + 1;
        this.end_column = range.end.character + 1;
        this.actions = new JsonArrayList<CodeAction>();
      }
    }

    protected override void check_node_in_file(Vala.CodeNode node)
    {
      try
      {
        if (node is Vala.MemberAccess)
        {
          check_member_access((Vala.MemberAccess)node);
        }
      }
      catch (Error err)
      {
        if (logwarn) warning(@"Error while checking lint in file '$(file.filename)': '$(err.message)'");
      }
    }

    private void check_member_access(Vala.MemberAccess node) throws GLib.Error
    {
      Vala.Symbol symbol = node.symbol_reference;
      if (symbol == null)
      {
        return;
      }
      if (is_hidden_symbol(symbol))
      {
        return;
      }
      if (is_backing_field_symbol(symbol))
      {
        return;
      }
      check_implicit_this_access(node);
      check_unqualified_static_access(node);
    }

    private void check_implicit_this_access(Vala.MemberAccess node) throws GLib.Error
    {
      if (this.config.no_implicit_this_access == LintSeverity.IGNORE)
      {
        return;
      }

      Vala.Symbol symbol = node.symbol_reference;
      Vala.Expression inner = node.inner;

      if (!is_source_code_node(symbol) || !(inner is Vala.MemberAccess) || ((Vala.MemberAccess)inner).member_name != "this")
      {
        return;
      }

      bool is_instance = symbol_is_instance_member(symbol);
      if (!is_instance || inner.source_reference != node.source_reference)
      {
        return;
      }

      if (logdebug) debug(@"Implicit this access, node: '$(code_node_to_string(node))', symbol reference: '$(code_node_to_string(node.symbol_reference))', inner: $(node.inner != null ? code_node_to_string(node.inner) : "null ")");
      Diagnostic diagnostic = add_diagnostic(node, "Implicit this access", this.config.no_implicit_this_access);
      if (actions == null)
      {
        return;
      }
      var range = new Range()
      {
        start = new Position()
        {
          line = node.source_reference.begin.line - 1,
          character = node.source_reference.begin.column - 1
        },
        end = new Position()
        {
          line = node.source_reference.begin.line - 1,
          character = node.source_reference.begin.column - 1
        }
      };
      var text_edit = new TextEdit()
      {
        range = range,
        newText = "this."
      };
      add_action(node, diagnostic, QuickFix, text_edit, ref no_implicit_this_access_in_file);
    }

    private void check_unqualified_static_access(Vala.MemberAccess node) throws GLib.Error
    {
      if (this.config.no_unqualified_static_access == LintSeverity.IGNORE)
      {
        return;
      }

      Vala.Symbol symbol = node.symbol_reference;
      Vala.Expression inner = node.inner;

      if (!is_source_code_node(symbol) || !(symbol.parent_symbol is Vala.Class) || (symbol is Vala.CreationMethod))
      {
        return;
      }

      bool is_static = symbol_is_static_member(symbol);
      if (!is_static || inner != null)
      {
        return;
      }

      if (logdebug) debug(@"Unqualified static access, node: '$(code_node_to_string(node))', symbol reference: '$(code_node_to_string(node.symbol_reference))'");
      Diagnostic diagnostic = add_diagnostic(node, "Unqualified static access", this.config.no_unqualified_static_access);
      if (actions == null)
      {
        return;
      }
      var range = new Range()
      {
        start = new Position()
        {
          line = node.source_reference.begin.line - 1,
          character = node.source_reference.begin.column - 1
        },
        end = new Position()
        {
          line = node.source_reference.begin.line - 1,
          character = node.source_reference.begin.column - 1
        }
      };
      var text_edit = new TextEdit()
      {
        range = range,
        newText = symbol.parent_symbol.name + "."
      };
      add_action(node, diagnostic, QuickFix, text_edit, ref no_implicit_this_access_in_file);
    }

    private void add_action(Vala.CodeNode node, Diagnostic diagnostic, CodeActionKindEnum kind, TextEdit text_edit, ref CodeAction? action_in_file) throws GLib.Error
    {
      if (action_in_file == null)
      {
        action_in_file = create_action(node, diagnostic, QuickFix, text_edit);
        action_in_file.title += " in file";
      }
      else
      {
        JsonSerializableCollection<TextEdit> file_changes = first_of_map<string, JsonSerializableCollection<TextEdit>>(action_in_file.edit.changes);
        file_changes.add(text_edit);
      }
      if (is_in_range(node))
      {
        CodeAction action = create_action(node, diagnostic, QuickFix, text_edit);
        actions.add(action);
        actions.add(action_in_file);
      }
    }

    private CodeAction create_action(Vala.CodeNode node, Diagnostic diagnostic, CodeActionKindEnum kind, TextEdit text_edit) throws GLib.Error
    {
      var action = new CodeAction()
      {
        title = @"Fix '$(diagnostic.message)'",
        kind = new CodeActionKind(kind)
      };
      action.diagnostics = new JsonArrayList<Diagnostic>().add_item(diagnostic);
      var location_uri = Filename.to_uri(file.filename);
      var text_edits = new JsonArrayList<TextEdit>().add_item(text_edit);
      var changes = new JsonHashMap<JsonArrayList<TextEdit>>();
      changes.set(location_uri, text_edits);
      action.edit = new WorkspaceEdit()
      {
        changes = changes
      };
      return action;
    }

    private Diagnostic add_diagnostic(Vala.CodeNode node, string message, LintSeverity severity)
    {
      var diagnostic = new Diagnostic()
      {
        range = source_reference_to_range(node.source_reference),
        severity = lint_severity_to_diagnostic_severity(severity),
        message = message
      };
      diagnostics.add(diagnostic);
      return diagnostic;
    }

    private bool is_in_range(Vala.CodeNode node)
    {
      if (range == null)
      {
        return false;
      }

      var source_reference = node.source_reference;
      Vala.SourceLocation begin = source_reference.begin;
      Vala.SourceLocation end = source_reference.end;

      if (begin.line > end.line)
      {
        if (logwarn) warning(@"Source reference '$(source_reference)' begins after it ends");
        return false;
      }

      if (end_line < begin.line || start_line > end.line)
      {
        return false;
      }
      if (end_line == begin.line && end_column < begin.column)
      {
        return false;
      }
      if (start_line == end.line && start_column > end.column + 1)
      {
        return false;
      }

      return true;
    }

    private DiagnosticSeverity? lint_severity_to_diagnostic_severity(LintSeverity severity)
    {
      switch (severity)
      {
      case LintSeverity.ERROR:
        return DiagnosticSeverity.Error;
      case LintSeverity.WARN:
        return DiagnosticSeverity.Warning;
      case LintSeverity.INFO:
        return DiagnosticSeverity.Information;
      case LintSeverity.HINT:
        return DiagnosticSeverity.Hint;
      case LintSeverity.IGNORE:
      default:
        return null;
      }
    }
  }
}
