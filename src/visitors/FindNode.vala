namespace Vls
{
  abstract class FindNode : Vala.CodeVisitor
  {
    protected abstract void check_node(Vala.CodeNode node);

    public override void visit_source_file(Vala.SourceFile file)
    {
      file.accept_children(this);
    }

    public override void visit_addressof_expression(Vala.AddressofExpression expr)
    {
      this.check_node(expr);
      expr.accept_children(this);
    }

    public override void visit_array_creation_expression(Vala.ArrayCreationExpression expr)
    {
      this.check_node(expr);
      expr.accept_children(this);
    }

    public override void visit_assignment(Vala.Assignment a)
    {
      this.check_node(a);
      a.accept_children(this);
    }

    public override void visit_base_access(Vala.BaseAccess expr)
    {
      this.check_node(expr);
      expr.accept_children(this);
    }

    public override void visit_binary_expression(Vala.BinaryExpression expr)
    {
      this.check_node(expr);
      expr.accept_children(this);
    }

    public override void visit_block(Vala.Block b)
    {
      b.accept_children(this);
    }

    public override void visit_boolean_literal(Vala.BooleanLiteral lit)
    {
      this.check_node(lit);
      lit.accept_children(this);
    }

    public override void visit_break_statement(Vala.BreakStatement stmt)
    {
      this.check_node(stmt);
      stmt.accept_children(this);
    }

    public override void visit_cast_expression(Vala.CastExpression expr)
    {
      this.check_node(expr);
      expr.accept_children(this);
    }

    public override void visit_catch_clause(Vala.CatchClause clause)
    {
      this.check_node(clause);
      clause.accept_children(this);
    }

    public override void visit_character_literal(Vala.CharacterLiteral lit)
    {
      this.check_node(lit);
      lit.accept_children(this);
    }

    public override void visit_class(Vala.Class cl)
    {
      //  debug("visit_class: %s", code_node_to_string(cl));
      this.check_node(cl);
      cl.accept_children(this);
    }

    public override void visit_conditional_expression(Vala.ConditionalExpression expr)
    {
      this.check_node(expr);
      expr.accept_children(this);
    }

    public override void visit_constant(Vala.Constant c)
    {
      this.check_node(c);
      c.accept_children(this);
    }

    public override void visit_constructor(Vala.Constructor c)
    {
      this.check_node(c);
      c.accept_children(this);
    }

    public override void visit_continue_statement(Vala.ContinueStatement stmt)
    {
      this.check_node(stmt);
      stmt.accept_children(this);
    }

    public override void visit_creation_method(Vala.CreationMethod m)
    {
      this.check_node(m);
      m.accept_children(this);
    }

    public override void visit_declaration_statement(Vala.DeclarationStatement stmt)
    {
      this.check_node(stmt);
      stmt.accept_children(this);
    }

    public override void visit_delegate(Vala.Delegate cb)
    {
      this.check_node(cb);
      cb.accept_children(this);
    }

    public override void visit_delete_statement(Vala.DeleteStatement stmt)
    {
      this.check_node(stmt);
      stmt.accept_children(this);
    }

    public override void visit_do_statement(Vala.DoStatement stmt)
    {
      this.check_node(stmt);
      stmt.accept_children(this);
    }

    public override void visit_element_access(Vala.ElementAccess expr)
    {
      this.check_node(expr);
      expr.accept_children(this);
    }

    public override void visit_empty_statement(Vala.EmptyStatement stmt)
    {
      this.check_node(stmt);
      stmt.accept_children(this);
    }

    public override void visit_enum(Vala.Enum en)
    {
      debug("visit_enum: %s", code_node_to_string(en));
      this.check_node(en);
      en.accept_children(this);
    }

    public override void visit_enum_value(Vala.EnumValue ev)
    {
      debug("visit_enum_value: %s", code_node_to_string(ev));
      this.check_node(ev);
      ev.accept_children(this);
    }

    public override void visit_error_domain(Vala.ErrorDomain edomain)
    {
      this.check_node(edomain);
      edomain.accept_children(this);
    }

    public override void visit_error_code(Vala.ErrorCode ecode)
    {
      this.check_node(ecode);
      ecode.accept_children(this);
    }

    public override void visit_expression_statement(Vala.ExpressionStatement stmt)
    {
      this.check_node(stmt);
      stmt.accept_children(this);
    }

    public override void visit_field(Vala.Field f)
    {
      this.check_node(f);
      f.accept_children(this);
    }

    public override void visit_for_statement(Vala.ForStatement stmt)
    {
      this.check_node(stmt);
      stmt.accept_children(this);
    }

    public override void visit_foreach_statement(Vala.ForeachStatement stmt)
    {
      this.check_node(stmt);
      stmt.accept_children(this);
    }

    public override void visit_if_statement(Vala.IfStatement stmt)
    {
      this.check_node(stmt);
      stmt.accept_children(this);
    }

    public override void visit_initializer_list(Vala.InitializerList list)
    {
      this.check_node(list);
      list.accept_children(this);
    }

    public override void visit_integer_literal(Vala.IntegerLiteral lit)
    {
      this.check_node(lit);
      lit.accept_children(this);
    }

    public override void visit_interface(Vala.Interface iface)
    {
      this.check_node(iface);
      iface.accept_children(this);
    }

    public override void visit_lambda_expression(Vala.LambdaExpression expr)
    {
      this.check_node(expr);
      expr.accept_children(this);
    }

    public override void visit_local_variable(Vala.LocalVariable local)
    {
      this.check_node(local);
      local.accept_children(this);
    }

    public override void visit_lock_statement(Vala.LockStatement stmt)
    {
      this.check_node(stmt);
      stmt.accept_children(this);
    }

    public override void visit_loop(Vala.Loop stmt)
    {
      stmt.accept_children(this);
    }

    public override void visit_member_access(Vala.MemberAccess expr)
    {
      this.check_node(expr);
      expr.accept_children(this);
    }

    public override void visit_method(Vala.Method m)
    {
      //  debug("visit_method: %s", code_node_to_string(m));
      this.check_node(m);
      m.accept_children(this);
    }

    public override void visit_method_call(Vala.MethodCall expr)
    {
      this.check_node(expr);
      expr.accept_children(this);
    }

    public override void visit_namespace(Vala.Namespace ns)
    {
      this.check_node(ns);
      ns.accept_children(this);
    }

    public override void visit_null_literal(Vala.NullLiteral lit)
    {
      this.check_node(lit);
      lit.accept_children(this);
    }

    public override void visit_object_creation_expression(Vala.ObjectCreationExpression expr)
    {
      this.check_node(expr);
      expr.accept_children(this);
    }

    public override void visit_pointer_indirection(Vala.PointerIndirection expr)
    {
      this.check_node(expr);
      expr.accept_children(this);
    }

    public override void visit_postfix_expression(Vala.PostfixExpression expr)
    {
      this.check_node(expr);
      expr.accept_children(this);
    }

    public override void visit_property(Vala.Property prop)
    {
      this.check_node(prop);
      prop.accept_children(this);
    }

    public override void visit_real_literal(Vala.RealLiteral lit)
    {
      this.check_node(lit);
      lit.accept_children(this);
    }

    public override void visit_reference_transfer_expression(Vala.ReferenceTransferExpression expr)
    {
      this.check_node(expr);
      expr.accept_children(this);
    }

    public override void visit_return_statement(Vala.ReturnStatement stmt)
    {
      this.check_node(stmt);
      stmt.accept_children(this);
    }

    public override void visit_signal(Vala.Signal sig)
    {
      this.check_node(sig);
      sig.accept_children(this);
    }

    public override void visit_sizeof_expression(Vala.SizeofExpression expr)
    {
      this.check_node(expr);
      expr.accept_children(this);
    }

    public override void visit_slice_expression(Vala.SliceExpression expr)
    {
      this.check_node(expr);
      expr.accept_children(this);
    }

    public override void visit_string_literal(Vala.StringLiteral lit)
    {
      this.check_node(lit);
      lit.accept_children(this);
    }

    public override void visit_struct(Vala.Struct st)
    {
      this.check_node(st);
      st.accept_children(this);
    }

    public override void visit_switch_label(Vala.SwitchLabel label)
    {
      this.check_node(label);
      label.accept_children(this);
    }

    public override void visit_switch_section(Vala.SwitchSection section)
    {
      this.check_node(section);
      section.accept_children(this);
    }

    public override void visit_switch_statement(Vala.SwitchStatement stmt)
    {
      this.check_node(stmt);
      stmt.accept_children(this);
    }

    public override void visit_throw_statement(Vala.ThrowStatement stmt)
    {
      this.check_node(stmt);
      stmt.accept_children(this);
    }

    public override void visit_try_statement(Vala.TryStatement stmt)
    {
      this.check_node(stmt);
      stmt.accept_children(this);
    }

    public override void visit_type_check(Vala.TypeCheck expr)
    {
      this.check_node(expr);
      expr.accept_children(this);
    }

    public override void visit_formal_parameter(Vala.Parameter p)
    {
      this.check_node(p);
      p.accept_children(this);
    }

    public override void visit_property_accessor(Vala.PropertyAccessor acc)
    {
      this.check_node(acc);
      acc.accept_children(this);
    }

    public override void visit_destructor(Vala.Destructor d)
    {
      this.check_node(d);
      d.accept_children(this);
    }

    public override void visit_type_parameter(Vala.TypeParameter p)
    {
      this.check_node(p);
      p.accept_children(this);
    }

    public override void visit_using_directive(Vala.UsingDirective ns)
    {
      this.check_node(ns);
      ns.accept_children(this);
    }

    public override void visit_data_type(Vala.DataType type)
    {
      this.check_node(type);
      type.accept_children(this);
    }

    public override void visit_while_statement(Vala.WhileStatement stmt)
    {
      this.check_node(stmt);
      stmt.accept_children(this);
    }

    public override void visit_yield_statement(Vala.YieldStatement y)
    {
      this.check_node(y);
      y.accept_children(this);
    }

    public override void visit_unlock_statement(Vala.UnlockStatement stmt)
    {
      this.check_node(stmt);
      stmt.accept_children(this);
    }

    public override void visit_expression(Vala.Expression expr)
    {
      this.check_node(expr);
      expr.accept_children(this);
    }

    public override void visit_regex_literal(Vala.RegexLiteral lit)
    {
      this.check_node(lit);
      lit.accept_children(this);
    }

    public override void visit_template(Vala.Template tmpl)
    {
      this.check_node(tmpl);
      tmpl.accept_children(this);
    }

    public override void visit_tuple(Vala.Tuple tuple)
    {
      this.check_node(tuple);
      tuple.accept_children(this);
    }

    public override void visit_typeof_expression(Vala.TypeofExpression expr)
    {
      this.check_node(expr);
      expr.accept_children(this);
    }

    public override void visit_unary_expression(Vala.UnaryExpression expr)
    {
      this.check_node(expr);
      expr.accept_children(this);
    }

    public override void visit_named_argument(Vala.NamedArgument expr)
    {
      this.check_node(expr);
      expr.accept_children(this);
    }

    public override void visit_end_full_expression(Vala.Expression expr)
    {
      this.check_node(expr);
      expr.accept_children(this);
    }
  }
}
