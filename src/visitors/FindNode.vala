namespace Vls
{
  public abstract class FindNode : Vala.CodeVisitor
  {
    private Gee.HashSet<Vala.CodeNode> visited_nodes = new Gee.HashSet<Vala.CodeNode>();

    private bool try_check_node(Vala.CodeNode node)
    {
      if (visited_nodes.contains(node))
      {
        return false;
      }
      visited_nodes.add(node);
      return check_node(node);
    }

    protected abstract bool check_node(Vala.CodeNode node);

    public override void visit_source_file(Vala.SourceFile file)
    {
      file.accept_children(this);
    }

    public override void visit_addressof_expression(Vala.AddressofExpression expr)
    {
      if (try_check_node(expr))
      {
        expr.accept_children(this);
      }
    }

    public override void visit_array_creation_expression(Vala.ArrayCreationExpression expr)
    {
      if (try_check_node(expr))
      {
        expr.accept_children(this);
      }
    }

    public override void visit_assignment(Vala.Assignment a)
    {
      if (try_check_node(a))
      {
        a.accept_children(this);
      }
    }

    public override void visit_base_access(Vala.BaseAccess expr)
    {
      if (try_check_node(expr))
      {
        expr.accept_children(this);
      }
    }

    public override void visit_binary_expression(Vala.BinaryExpression expr)
    {
      if (try_check_node(expr))
      {
        expr.accept_children(this);
      }
    }

    public override void visit_block(Vala.Block b)
    {
      b.accept_children(this);
    }

    public override void visit_boolean_literal(Vala.BooleanLiteral lit)
    {
      if (try_check_node(lit))
      {
        lit.accept_children(this);
      }
    }

    public override void visit_break_statement(Vala.BreakStatement stmt)
    {
      if (try_check_node(stmt))
      {
        stmt.accept_children(this);
      }
    }

    public override void visit_cast_expression(Vala.CastExpression expr)
    {
      if (try_check_node(expr))
      {
        expr.accept_children(this);
      }
    }

    public override void visit_catch_clause(Vala.CatchClause clause)
    {
      if (try_check_node(clause))
      {
        clause.accept_children(this);
      }
    }

    public override void visit_character_literal(Vala.CharacterLiteral lit)
    {
      if (try_check_node(lit))
      {
        lit.accept_children(this);
      }
    }

    public override void visit_class(Vala.Class cl)
    {
      if (try_check_node(cl))
      {
        cl.accept_children(this);
      }
    }

    public override void visit_conditional_expression(Vala.ConditionalExpression expr)
    {
      if (try_check_node(expr))
      {
        expr.accept_children(this);
      }
    }

    public override void visit_constant(Vala.Constant c)
    {
      if (try_check_node(c))
      {
        c.accept_children(this);
      }
    }

    public override void visit_constructor(Vala.Constructor c)
    {
      if (try_check_node(c))
      {
        c.accept_children(this);
      }
    }

    public override void visit_continue_statement(Vala.ContinueStatement stmt)
    {
      if (try_check_node(stmt))
      {
        stmt.accept_children(this);
      }
    }

    public override void visit_creation_method(Vala.CreationMethod m)
    {
      if (try_check_node(m))
      {
        m.accept_children(this);
      }
    }

    public override void visit_declaration_statement(Vala.DeclarationStatement stmt)
    {
      if (try_check_node(stmt))
      {
        stmt.accept_children(this);
      }
    }

    public override void visit_delegate(Vala.Delegate cb)
    {
      if (try_check_node(cb))
      {
        cb.accept_children(this);
      }
    }

    public override void visit_delete_statement(Vala.DeleteStatement stmt)
    {
      if (try_check_node(stmt))
      {
        stmt.accept_children(this);
      }
    }

    public override void visit_do_statement(Vala.DoStatement stmt)
    {
      if (try_check_node(stmt))
      {
        stmt.accept_children(this);
      }
    }

    public override void visit_element_access(Vala.ElementAccess expr)
    {
      if (try_check_node(expr))
      {
        expr.accept_children(this);
      }
    }

    public override void visit_empty_statement(Vala.EmptyStatement stmt)
    {
      if (try_check_node(stmt))
      {
        stmt.accept_children(this);
      }
    }

    public override void visit_enum(Vala.Enum en)
    {
      if (try_check_node(en))
      {
        en.accept_children(this);
      }
    }

    public override void visit_enum_value(Vala.EnumValue ev)
    {
      if (try_check_node(ev))
      {
        ev.accept_children(this);
      }
    }

    public override void visit_error_domain(Vala.ErrorDomain edomain)
    {
      if (try_check_node(edomain))
      {
        edomain.accept_children(this);
      }
    }

    public override void visit_error_code(Vala.ErrorCode ecode)
    {
      if (try_check_node(ecode))
      {
        ecode.accept_children(this);
      }
    }

    public override void visit_expression_statement(Vala.ExpressionStatement stmt)
    {
      if (try_check_node(stmt))
      {
        stmt.accept_children(this);
      }
    }

    public override void visit_field(Vala.Field f)
    {
      if (try_check_node(f))
      {
        f.accept_children(this);
      }
    }

    public override void visit_for_statement(Vala.ForStatement stmt)
    {
      if (try_check_node(stmt))
      {
        stmt.accept_children(this);
      }
    }

    public override void visit_foreach_statement(Vala.ForeachStatement stmt)
    {
      if (try_check_node(stmt))
      {
        stmt.accept_children(this);
      }
    }

    public override void visit_if_statement(Vala.IfStatement stmt)
    {
      if (try_check_node(stmt))
      {
        stmt.accept_children(this);
      }
    }

    public override void visit_initializer_list(Vala.InitializerList list)
    {
      if (try_check_node(list))
      {
        list.accept_children(this);
      }
    }

    public override void visit_integer_literal(Vala.IntegerLiteral lit)
    {
      if (try_check_node(lit))
      {
        lit.accept_children(this);
      }
    }

    public override void visit_interface(Vala.Interface iface)
    {
      if (try_check_node(iface))
      {
        iface.accept_children(this);
      }
    }

    public override void visit_lambda_expression(Vala.LambdaExpression expr)
    {
      if (try_check_node(expr))
      {
        expr.accept_children(this);
      }
    }

    public override void visit_local_variable(Vala.LocalVariable local)
    {
      if (try_check_node(local))
      {
        local.accept_children(this);
      }
    }

    public override void visit_lock_statement(Vala.LockStatement stmt)
    {
      if (try_check_node(stmt))
      {
        stmt.accept_children(this);
      }
    }

    public override void visit_loop(Vala.Loop stmt)
    {
      stmt.accept_children(this);
    }

    public override void visit_member_access(Vala.MemberAccess expr)
    {
      if (try_check_node(expr))
      {
        expr.accept_children(this);
      }
    }

    public override void visit_method(Vala.Method m)
    {
      if (try_check_node(m))
      {
        m.accept_children(this);
      }
    }

    public override void visit_method_call(Vala.MethodCall expr)
    {
      if (try_check_node(expr))
      {
        expr.accept_children(this);
      }
    }

    public override void visit_namespace(Vala.Namespace ns)
    {
      if (try_check_node(ns))
      {
        ns.accept_children(this);
      }
    }

    public override void visit_null_literal(Vala.NullLiteral lit)
    {
      if (try_check_node(lit))
      {
        lit.accept_children(this);
      }
    }

    public override void visit_object_creation_expression(Vala.ObjectCreationExpression expr)
    {
      if (try_check_node(expr))
      {
        expr.accept_children(this);

        // For some reason, the MemberInitializer nodes are ignored by the above (but not their initializer expression)
        foreach (Vala.MemberInitializer init in expr.get_object_initializer())
        {
          try_check_node(init);
        }
      }
    }

    public override void visit_pointer_indirection(Vala.PointerIndirection expr)
    {
      if (try_check_node(expr))
      {
        expr.accept_children(this);
      }
    }

    public override void visit_postfix_expression(Vala.PostfixExpression expr)
    {
      if (try_check_node(expr))
      {
        expr.accept_children(this);
      }
    }

    public override void visit_property(Vala.Property prop)
    {
      if (try_check_node(prop))
      {
        prop.accept_children(this);
      }
    }

    public override void visit_real_literal(Vala.RealLiteral lit)
    {
      if (try_check_node(lit))
      {
        lit.accept_children(this);
      }
    }

    public override void visit_reference_transfer_expression(Vala.ReferenceTransferExpression expr)
    {
      if (try_check_node(expr))
      {
        expr.accept_children(this);
      }
    }

    public override void visit_return_statement(Vala.ReturnStatement stmt)
    {
      if (try_check_node(stmt))
      {
        stmt.accept_children(this);
      }
    }

    public override void visit_signal(Vala.Signal sig)
    {
      if (try_check_node(sig))
      {
        sig.accept_children(this);
      }
    }

    public override void visit_sizeof_expression(Vala.SizeofExpression expr)
    {
      if (try_check_node(expr))
      {
        expr.accept_children(this);
      }
    }

    public override void visit_slice_expression(Vala.SliceExpression expr)
    {
      if (try_check_node(expr))
      {
        expr.accept_children(this);
      }
    }

    public override void visit_string_literal(Vala.StringLiteral lit)
    {
      if (try_check_node(lit))
      {
        lit.accept_children(this);
      }
    }

    public override void visit_struct(Vala.Struct st)
    {
      if (try_check_node(st))
      {
        st.accept_children(this);
      }
    }

    public override void visit_switch_label(Vala.SwitchLabel label)
    {
      if (try_check_node(label))
      {
        label.accept_children(this);
      }
    }

    public override void visit_switch_section(Vala.SwitchSection section)
    {
      if (try_check_node(section))
      {
        section.accept_children(this);
      }
    }

    public override void visit_switch_statement(Vala.SwitchStatement stmt)
    {
      if (try_check_node(stmt))
      {
        stmt.accept_children(this);
      }
    }

    public override void visit_throw_statement(Vala.ThrowStatement stmt)
    {
      if (try_check_node(stmt))
      {
        stmt.accept_children(this);
      }
    }

    public override void visit_try_statement(Vala.TryStatement stmt)
    {
      if (try_check_node(stmt))
      {
        stmt.accept_children(this);
      }
    }

    public override void visit_type_check(Vala.TypeCheck expr)
    {
      if (try_check_node(expr))
      {
        expr.accept_children(this);
      }
    }

    public override void visit_formal_parameter(Vala.Parameter p)
    {
      if (try_check_node(p))
      {
        p.accept_children(this);
      }
    }

    public override void visit_property_accessor(Vala.PropertyAccessor acc)
    {
      if (try_check_node(acc))
      {
        acc.accept_children(this);
      }
    }

    public override void visit_destructor(Vala.Destructor d)
    {
      if (try_check_node(d))
      {
        d.accept_children(this);
      }
    }

    public override void visit_type_parameter(Vala.TypeParameter p)
    {
      if (try_check_node(p))
      {
        p.accept_children(this);
      }
    }

    public override void visit_using_directive(Vala.UsingDirective ns)
    {
      if (try_check_node(ns))
      {
        ns.accept_children(this);
      }
    }

    public override void visit_data_type(Vala.DataType type)
    {
      if (try_check_node(type))
      {
        type.accept_children(this);
      }
    }

    public override void visit_while_statement(Vala.WhileStatement stmt)
    {
      if (try_check_node(stmt))
      {
        stmt.accept_children(this);
      }
    }

    public override void visit_yield_statement(Vala.YieldStatement y)
    {
      if (try_check_node(y))
      {
        y.accept_children(this);
      }
    }

    public override void visit_unlock_statement(Vala.UnlockStatement stmt)
    {
      if (try_check_node(stmt))
      {
        stmt.accept_children(this);
      }
    }

    public override void visit_expression(Vala.Expression expr)
    {
      if (try_check_node(expr))
      {
        expr.accept_children(this);
      }
    }

    public override void visit_regex_literal(Vala.RegexLiteral lit)
    {
      if (try_check_node(lit))
      {
        lit.accept_children(this);
      }
    }

    public override void visit_template(Vala.Template tmpl)
    {
      if (try_check_node(tmpl))
      {
        tmpl.accept_children(this);
      }
    }

    public override void visit_tuple(Vala.Tuple tuple)
    {
      if (try_check_node(tuple))
      {
        tuple.accept_children(this);
      }
    }

    public override void visit_typeof_expression(Vala.TypeofExpression expr)
    {
      if (try_check_node(expr))
      {
        expr.accept_children(this);
      }
    }

    public override void visit_unary_expression(Vala.UnaryExpression expr)
    {
      if (try_check_node(expr))
      {
        expr.accept_children(this);
      }
    }

    public override void visit_named_argument(Vala.NamedArgument expr)
    {
      if (try_check_node(expr))
      {
        expr.accept_children(this);
      }
    }

    public override void visit_end_full_expression(Vala.Expression expr)
    {
      if (try_check_node(expr))
      {
        expr.accept_children(this);
      }
    }
  }
}
