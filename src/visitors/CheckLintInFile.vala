namespace Vls
{
  public class CheckLintInFile : FindNodeInFile
  {
    protected LintConfig config;

    // List of issues found in file
    public JsonArrayList<Diagnostic> diagnostics = new JsonArrayList<Diagnostic>();

    public CheckLintInFile(Vala.SourceFile file, LintConfig config)
    {
      base(file);

      this.config = config;
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

    private void check_member_access(Vala.MemberAccess node) throws Error
    {
      Vala.Symbol symbol = node.symbol_reference;
      if (symbol == null)
      {
        return;
      }

      if (is_hidden_symbol(symbol) || is_backing_field_symbol(symbol))
      {
        return;
      }

      check_implicit_this_access(node);
      check_unqualified_static_access(node);
    }

    private void check_implicit_this_access(Vala.MemberAccess node) throws Error
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

      on_implicit_this_access_diagnostic(node, diagnostic);
    }

    protected virtual void on_implicit_this_access_diagnostic(Vala.MemberAccess node, Diagnostic diagnostic) throws Error {}

    private void check_unqualified_static_access(Vala.MemberAccess node) throws Error
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

      on_unqualified_static_access(node, diagnostic);
    }

    protected virtual void on_unqualified_static_access(Vala.MemberAccess node, Diagnostic diagnostic) throws Error {}

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
