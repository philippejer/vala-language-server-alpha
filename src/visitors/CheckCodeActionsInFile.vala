namespace Vls
{
  public class CheckCodeActionsInFile : CheckLintInFile
  {
    private Range? range;

    private uint start_line;
    private uint start_column;
    private uint end_line;
    private uint end_column;

    // List of code actions found in file
    public JsonArrayList<CodeAction>? actions;

    // Global actions to solve the respective issues in the file in a single action
    public CodeAction? no_implicit_this_access_in_file;
    public CodeAction? no_unqualified_static_access_in_file;

    public CheckCodeActionsInFile(Vala.SourceFile file, LintConfig config, Range range)
    {
      base(file, config);

      this.range = range;
      this.start_line = range.start.line + 1;
      this.start_column = range.start.character + 1;
      this.end_line = range.end.line + 1;
      this.end_column = range.end.character + 1;
      this.actions = new JsonArrayList<CodeAction>();
    }

    protected override void on_implicit_this_access_diagnostic(Vala.MemberAccess node, Diagnostic diagnostic) throws Error
    {
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

    protected override void on_unqualified_static_access(Vala.MemberAccess node, Diagnostic diagnostic) throws Error
    {
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

      Vala.Symbol type_symbol = node.symbol_reference.parent_symbol;

      var text_edit = new TextEdit()
      {
        range = range,
        newText = type_symbol.name + "."
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
  }
}
