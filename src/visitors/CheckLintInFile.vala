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
        if (!is_source_code_node(node))
        {
          return;
        }

        if (node is Vala.Expression)
        {
          check_expression((Vala.Expression)node);
        }
        else if (node is Vala.LocalVariable)
        {
          check_local_variable((Vala.LocalVariable)node);
        }
      }
      catch (Error err)
      {
        if (logwarn) warning(@"Error while checking lint in file '$(file.filename)': '$(err.message)'");
      }
    }

    private void check_expression(Vala.Expression expression) throws Error
    {
      if (expression is Vala.MemberAccess)
      {
        check_member_access((Vala.MemberAccess)expression);
      }

      check_non_null_cast(expression);
    }

    private void check_member_access(Vala.MemberAccess access) throws Error
    {
      Vala.Symbol? symbol = access.symbol_reference;
      if (symbol == null)
      {
        return;
      }

      if (is_hidden_symbol(symbol) || is_backing_field_symbol(symbol))
      {
        return;
      }

      check_implicit_this_access(access);
      check_unqualified_static_access(access);
    }

    private void check_implicit_this_access(Vala.MemberAccess access) throws Error
    {
      if (this.config.no_implicit_this_access == LintSeverity.IGNORE)
      {
        return;
      }

      unowned Vala.Symbol symbol = access.symbol_reference;

      if (!symbol_is_instance_member(symbol))
      {
        return;
      }

      // The semantic checker inserts an implicit "this" inner member access if it is not present
      unowned Vala.Expression? inner = access.inner;
      if (!(inner is Vala.MemberAccess) || ((Vala.MemberAccess)inner).member_name != "this")
      {
        return;
      }

      // Heuristic: if this is an implicit "this" inserted by the semantic checker, it will share the source reference with the outer expression
      // May be broken at some point (however, the principle of an implicit node not having a "normal" source reference should hold)
      if (inner.source_reference != access.source_reference)
      {
        return;
      }

      if (logdebug) debug(@"Implicit this access, node: '$(code_node_to_string(access))', symbol reference: '$(code_node_to_string(access.symbol_reference))', inner: $(access.inner != null ? code_node_to_string(access.inner) : "null ")");
      Diagnostic? diagnostic = add_diagnostic(access, "Implicit this access", this.config.no_implicit_this_access);

      if (diagnostic != null)
      {
        on_implicit_this_access_diagnostic(access, diagnostic);
      }
    }

    protected virtual void on_implicit_this_access_diagnostic(Vala.MemberAccess access, Diagnostic diagnostic) throws Error
    {
    }

    private void check_unqualified_static_access(Vala.MemberAccess access) throws Error
    {
      if (this.config.no_unqualified_static_access == LintSeverity.IGNORE)
      {
        return;
      }

      unowned Vala.Symbol? symbol = access.symbol_reference;
      if (symbol == null || !(symbol.parent_symbol is Vala.Class) || (symbol is Vala.CreationMethod) || !symbol_is_static_member(symbol))
      {
        return;
      }

      unowned Vala.Expression? inner = access.inner;
      if (inner != null)
      {
        return;
      }

      if (logdebug) debug(@"Unqualified static access, node: '$(code_node_to_string(access))', symbol reference: '$(code_node_to_string(access.symbol_reference))'");
      Diagnostic? diagnostic = add_diagnostic(access, "Unqualified static access", this.config.no_unqualified_static_access);

      if (diagnostic != null)
      {
        on_unqualified_static_access(access, diagnostic);
      }
    }

    protected virtual void on_unqualified_static_access(Vala.MemberAccess access, Diagnostic diagnostic) throws Error
    {
    }

    private void check_non_null_cast(Vala.Expression expression) throws Error
    {
      if (this.config.no_implicit_non_null_cast == LintSeverity.IGNORE)
      {
        return;
      }

      if (!Server.context.experimental_non_null)
      {
        // Does not work properly because types are nullable by default in this case
        if (logdebug) debug(@"Non-null cast lint only works in non-null mode");
        return;
      }

      unowned Vala.DataType? value_type = expression.value_type;
      unowned Vala.DataType? target_type = expression.target_type;
      if (value_type != null && value_type.nullable && target_type != null && !target_type.nullable)
      {
#if LIBVALA_EXP
        if (expression.value_type.nullable_exemption)
        {
          return;
        }
#endif
        if (logdebug) debug(@"Implicit non-null cast, node: '$(code_node_to_string(expression))', symbol reference: '$(code_node_to_string(expression.symbol_reference))'");
        Diagnostic? diagnostic = add_diagnostic(expression, "Implicit non-null cast", this.config.no_implicit_non_null_cast);

        if (diagnostic != null)
        {
          on_non_null_cast_diagnostic(expression, diagnostic);
        }
      }
    }

    protected virtual void on_non_null_cast_diagnostic(Vala.Expression expression, Diagnostic diagnostic) throws Error
    {
    }

    private void check_local_variable(Vala.LocalVariable variable) throws Error
    {
      if (is_hidden_symbol(variable))
      {
        return;
      }

      // Ugly heuristic for local variables inserted by foreach statements
      unowned string? variable_name = variable.name;
      if (variable_name == null || is_foreach_variable_name(variable_name))
      {
        return;
      }

      check_type_inference(variable);
    }

    private bool is_foreach_variable_name(string variable_name)
    {
      return variable_name.has_prefix("_") && (variable_name.has_suffix("_it") || variable_name.has_suffix("_list") || variable_name.has_suffix("_size") || variable_name.has_suffix("_index"));
    }

    private void check_type_inference(Vala.LocalVariable variable) throws Error
    {
      if (this.config.no_type_inference == LintSeverity.IGNORE && this.config.no_type_inference_unless_evident == LintSeverity.IGNORE)
      {
        return;
      }

      // Heuristic similar as above: if the variable data type has been copied by the semantic checker
      // from the initializer type, it will share the same source reference
      unowned Vala.DataType? variable_type = variable.variable_type;
      unowned Vala.Expression? initializer = variable.initializer;
      unowned Vala.DataType? initializer_type = initializer != null ? (Vala.DataType?)initializer.value_type : null;

      // FIXME: due to bug in the compiler the source reference of pointer types is not copied along
      while (variable_type is Vala.PointerType && initializer_type is Vala.PointerType)
      {
        variable_type = ((Vala.PointerType)variable_type).base_type;
        initializer_type = ((Vala.PointerType)initializer_type).base_type;
      }

      if (variable_type != null && initializer_type != null && variable_type.source_reference == initializer_type.source_reference)
      {
        LintSeverity severity = this.config.no_type_inference;

        // Checks if the initializer makes the type "evident"
        if (variable.initializer is Vala.ObjectCreationExpression || variable.initializer is Vala.CastExpression)
        {
          if (this.config.no_type_inference == LintSeverity.IGNORE)
          {
            return;
          }
        }
        else
        {
          if (this.config.no_type_inference_unless_evident > this.config.no_type_inference)
          {
            severity = this.config.no_type_inference_unless_evident;
          }
        }

        if (logdebug) debug(@"Type inference, node: '$(code_node_to_string(variable))'");
        Diagnostic? diagnostic = add_diagnostic(variable, "Type inference", severity);

        if (diagnostic != null)
        {
          on_type_inference(variable, diagnostic);
        }
      }
    }

    protected virtual void on_type_inference(Vala.LocalVariable variable, Diagnostic diagnostic) throws Error
    {
    }

    private Diagnostic? add_diagnostic(Vala.CodeNode node, string message, LintSeverity severity)
    {
      unowned Vala.SourceReference? source_reference = node.source_reference;
      if (source_reference == null)
      {
        return null;
      }

      Diagnostic diagnostic = new Diagnostic()
      {
        range = source_reference_to_range(source_reference),
        severity = lint_severity_to_diagnostic_severity(severity),
        message = message
      };

      if (diagnostic.severity != DiagnosticSeverity.Unset)
      {
        diagnostics.add(diagnostic);
      }

      return diagnostic;
    }

    private DiagnosticSeverity lint_severity_to_diagnostic_severity(LintSeverity severity)
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
      case LintSeverity.ACTION:
      case LintSeverity.IGNORE:
      default:
        return DiagnosticSeverity.Unset;
      }
    }
  }
}
