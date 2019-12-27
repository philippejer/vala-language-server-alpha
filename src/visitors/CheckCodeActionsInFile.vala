namespace Vls
{
  public class CheckCodeActionsInFile : CheckLintInFile
  {
    private string file_uri;

    private Range range;
    private uint start_line;
    private uint start_column;
    private uint end_line;
    private uint end_column;

    // List of code actions found in file
    public JsonArrayList<CodeAction> actions = new JsonArrayList<CodeAction>();

    // Global actions to solve the respective issues in the file in a single action
    public CodeAction? no_implicit_this_access_in_file;
    public CodeAction? no_unqualified_static_access_in_file;
    public CodeAction? no_type_inference_in_file;

    public CheckCodeActionsInFile(Vala.SourceFile file, LintConfig config, Range range) throws Error
    {
      base(file, config);

      this.file_uri = Filename.to_uri(file.filename);

      this.range = range;
      this.start_line = range.start.line + 1;
      this.start_column = range.start.character + 1;
      this.end_line = range.end.line + 1;
      this.end_column = range.end.character + 1;
    }

    protected override void on_implicit_this_access_diagnostic(Vala.MemberAccess access, Diagnostic diagnostic) throws Error
    {
      unowned Vala.SourceReference? source_reference = access.source_reference;
      if (source_reference == null)
      {
        return;
      }

      Range range = new Range()
      {
        start = new Position()
        {
          line = source_reference.begin.line - 1,
          character = source_reference.begin.column - 1
        },
        end = new Position()
        {
          line = source_reference.begin.line - 1,
          character = source_reference.begin.column - 1
        }
      };

      TextEdit text_edit = new TextEdit()
      {
        range = range,
        newText = "this."
      };

      add_action(access, diagnostic, QuickFix, text_edit, ref no_implicit_this_access_in_file);
    }

    protected override void on_unqualified_static_access(Vala.MemberAccess access, Diagnostic diagnostic) throws Error
    {
      unowned Vala.SourceReference? source_reference = access.source_reference;
      if (source_reference == null)
      {
        return;
      }

      Range range = new Range()
      {
        start = new Position()
        {
          line = source_reference.begin.line - 1,
          character = source_reference.begin.column - 1
        },
        end = new Position()
        {
          line = source_reference.begin.line - 1,
          character = source_reference.begin.column - 1
        }
      };

      unowned Vala.Symbol? type_symbol = access.symbol_reference.parent_symbol;
      unowned string? type_symbol_name = type_symbol != null ? type_symbol.name : null;
      if (type_symbol_name == null)
      {
        return;
      }

      TextEdit text_edit = new TextEdit()
      {
        range = range,
        newText = type_symbol_name + "."
      };

      add_action(access, diagnostic, QuickFix, text_edit, ref no_unqualified_static_access_in_file);
    }

    protected override void on_non_null_cast_diagnostic(Vala.Expression expression, Diagnostic diagnostic) throws Error
    {
      if (!is_in_range(expression))
      {
        return;
      }

      unowned Vala.SourceReference? source_reference = expression.source_reference;
      if (source_reference == null)
      {
        return;
      }

      Range range = source_reference_to_range(source_reference);
      string source = get_source_reference_source(source_reference);
      char* max = source_reference.file.get_mapped_contents() + source_reference.file.get_mapped_length();
      char* pos = source_reference.end.pos;
      pos = find_non_whitespace_position(source_reference.end.pos, max);

      string? type_symbol_name = get_type_name(expression, expression.target_type);
      if (type_symbol_name == null)
      {
        return;
      }

      string newText = pos != null && pos[0] == '.'
        ? @"(($(type_symbol_name))$(source))"
        : @"($(type_symbol_name))$(source)";

      TextEdit text_edit = new TextEdit()
      {
        range = range,
        newText = newText
      };

      CodeAction action = create_action(diagnostic, QuickFix, text_edit);
      actions.add(action);
    }

    protected override void on_type_inference(Vala.LocalVariable variable, Diagnostic diagnostic) throws Error
    {
      string? type_name = get_type_name(variable, variable.variable_type);
      if (type_name == null)
      {
        if (loginfo) info(@"Could not get type name for local variable: '$(code_node_to_string(variable))'");
        return;
      }

      unowned Vala.SourceReference? source_reference = variable.source_reference;
      if (source_reference == null)
      {
        return;
      }

      unowned string? variable_name = variable.name;
      if (variable_name == null)
      {
        return;
      }

      // Find the variable name (not always right at the beginning of the source reference)
      char* start = source_reference.begin.pos;
      char* max = source_reference.file.get_mapped_contents() + source_reference.file.get_mapped_length();
      char* pos = find_identifier_range(start, max, variable_name);

      // Find the "var" keyword which should be right before the variable name
      char* min = source_reference.file.get_mapped_contents() + 2;
      pos = find_non_whitespace_position_reverse(pos - 1, min);

      // For some reason, if the name is prefixed with '@', the position does not include the '@' but the column does (compiler bug?)
      int offset = 0;
      if (pos != null && pos[0] == '@')
      {
        pos = find_non_whitespace_position_reverse(pos - 1, min);
        offset = 1;
      }

      if (pos == null || !equal_strings(pos - 2, "var", 3))
      {
        if (loginfo) info(@"Could not find 'var' before local variable (or it is not on the same line): '$(code_node_to_string(variable))'");
        return;
      }

      Range range = new Range()
      {
        start = new Position()
        {
          line = source_reference.begin.line - 1,
          character = source_reference.begin.column - (int)(source_reference.begin.pos - pos) + offset - 3
        },
        end = new Position()
        {
          line = source_reference.begin.line - 1,
          character = source_reference.begin.column - (int)(source_reference.begin.pos - pos) + offset
        }
      };

      TextEdit text_edit = new TextEdit()
      {
        range = range,
        newText = type_name
      };

      add_action(variable, diagnostic, QuickFix, text_edit, ref no_type_inference_in_file);
    }

    private void add_action(Vala.CodeNode node, Diagnostic diagnostic, CodeActionKindEnum kind, TextEdit text_edit, ref CodeAction? action_in_file) throws GLib.Error
    {
      if (action_in_file == null)
      {
        action_in_file = create_action(diagnostic, QuickFix, text_edit);
        action_in_file.title += " in file";
      }
      else
      {
        JsonSerializableCollection<TextEdit>? file_changes = action_in_file.edit.changes.first();
        if (file_changes != null)
        {
          file_changes.add(text_edit);
        }
      }

      if (!is_in_range(node))
      {
        return;
      }

      CodeAction action = create_action(diagnostic, QuickFix, text_edit);
      actions.add(action);
      actions.add(action_in_file);
    }

    private CodeAction create_action(Diagnostic diagnostic, CodeActionKindEnum kind, TextEdit text_edit) throws GLib.Error
    {
      CodeAction action = new CodeAction()
      {
        title = @"Fix '$(diagnostic.message)'",
        kind = new CodeActionKind(kind)
      };

      action.diagnostics = new JsonArrayList<Diagnostic>.wrap_one(diagnostic);

      JsonArrayList<TextEdit> text_edits = new JsonArrayList<TextEdit>.wrap_one(text_edit);
      JsonHashMap<JsonArrayList<TextEdit>> changes = new JsonHashMap<JsonArrayList<TextEdit>>();
      changes.set(file_uri, text_edits);
      action.edit = new WorkspaceEdit()
      {
        changes = changes
      };

      return action;
    }

    private bool is_in_range(Vala.CodeNode node)
    {
      unowned Vala.SourceReference? source_reference = node.source_reference;
      if (source_reference == null)
      {
        return false;
      }

      unowned Vala.SourceLocation begin = source_reference.begin;
      unowned Vala.SourceLocation end = source_reference.end;

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
