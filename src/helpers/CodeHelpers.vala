namespace Vls
{
  /** Flags to control how reachable symbols are filtered for completion. */
  [Flags]
  public enum SymbolFlags
  {
    NONE = 0,
    INSTANCE,
    INTERNAL,
    PROTECTED,
    PRIVATE,
    ALL_STATIC = INTERNAL | PROTECTED | PRIVATE,
    ALL = INSTANCE | INTERNAL | PROTECTED | PRIVATE,
  }

  /** Returns true if 'node1' is inside 'node2'. */
  public bool code_node_is_inside(Vala.CodeNode node1, Vala.CodeNode node2)
  {
    unowned Vala.SourceReference? source_reference1 = node1.source_reference;
    unowned Vala.SourceReference? source_reference2 = node2.source_reference;
    if (source_reference1 == null || source_reference2 == null)
    {
      return false;
    }
    return source_reference1.begin.pos >= source_reference2.begin.pos &&
      source_reference1.end.pos <= source_reference2.end.pos;
  }

  /** Returns true if 'node1' and 'node2' reference the same source. */
  public bool code_node_matches(Vala.CodeNode node1, Vala.CodeNode node2)
  {
    unowned Vala.SourceReference? source_reference1 = node1.source_reference;
    unowned Vala.SourceReference? source_reference2 = node2.source_reference;
    if (source_reference1 == null || source_reference2 == null)
    {
      return false;
    }
    return source_reference1.begin.pos == source_reference2.begin.pos &&
      source_reference1.end.pos == source_reference2.end.pos;
  }

  /** Returns the source code for 'node'. */
  public string get_code_node_source(Vala.CodeNode node)
  {
    unowned Vala.SourceReference? source_reference = node.source_reference;
    if (source_reference == null)
    {
      return "";
    }

    return get_source_reference_source(source_reference);
  }

  /** Returns the source code for 'source_reference'. */
  public string get_source_reference_source(Vala.SourceReference source_reference)
  {
    char* begin = source_reference.begin.pos;
    char* end = source_reference.end.pos;
    return get_string_from_pointers(begin, end);
  }

  /** Extracts the substring between 'start' and 'end'. */
  public string get_string_from_pointers(char* start, char* end)
  {
    return ((string)start).substring(0, (long)(end - start));
  }

  public char* find_non_whitespace_position_reverse(char* source, char* min)
  {
    char* pos = source;
    while (pos >= min && pos[0].isspace() && pos[0] != '\n')
    {
      pos -= 1;
    }
    return pos >= min ? pos : null;
  }

  public char* find_non_whitespace_position(char* source, char* max)
  {
    char* pos = source;
    while (pos < max && pos[0].isspace() && pos[0] != '\n')
    {
      pos += 1;
    }
    return pos < max ? pos : null;
  }

  /** Searches for one of 'tokens' between 'start' and 'max' ('max' excluded from search). */
  public char* find_tokens(char* start, char* max, char[] tokens)
  {
    char* pos = start;
    while (pos < max)
    {
      if (is_one_of_tokens(pos[0], tokens))
      {
        break;
      }
      pos += 1;
    }
    return pos == max ? null : pos;
  }

  /** Searches for 'token' in reverse between 'start' and 'min' ('min' included in search). */
  public char* find_token_reverse(char* start, char* min, char[] tokens)
  {
    char* pos = start;
    while (pos >= min)
    {
      if (is_one_of_tokens(pos[0], tokens))
      {
        break;
      }
      pos -= 1;
    }
    return pos == min - 1 ? null : pos;
  }

  public bool is_one_of_tokens(char c, char[] tokens)
  {
    for (int i = 0; i < tokens.length; i++)
    {
      if (tokens[i] == c)
      {
        return true;
      }
    }
    return false;
  }

  /** Returns a string representation for 'node'. */
  public string code_node_to_string(Vala.CodeNode? node)
  {
    if (node == null)
    {
      return "null (CodeNode)";
    }

    unowned Vala.Symbol? symbol = node as Vala.Symbol;
    if (symbol != null)
    {
      return @"name: '$(symbol.name ?? "[unnamed symbol]")', type: '$(node.type_name)', source: '$(source_reference_to_string(node.source_reference))'";
    }
    else
    {
      return @"name: (not a symbol), type: '$(node.type_name)', source: '$(source_reference_to_string(node.source_reference))'";
    }
  }

  /** Convert a 'SourceReference' to string for debugging. */
  public string source_reference_to_string(Vala.SourceReference? source_reference)
  {
    if (source_reference == null)
    {
      return "NULL (SourceReference)";
    }

    return @"$(source_reference.file.filename): $(source_reference.begin.line).$(source_reference.begin.column)::$(source_reference.end.line).$(source_reference.end.column)";
  }

  public string source_reference_basename(Vala.SourceReference? source_reference)
  {
    if (source_reference == null)
    {
      return "NULL (SourceReference)";
    }
    return Path.get_basename(source_reference.file.filename);
  }

  /** Returns the definition of 'symbol' from the source code (with the parent symbol and comment if any).  */
  public string? get_symbol_definition_code_with_comment(Vala.Symbol symbol)
  {
    string? code = get_symbol_definition_code(symbol);
    if (code == null)
    {
      return null;
    }

    unowned Vala.SourceReference? source_reference = symbol.source_reference;
    unowned Vala.Comment? comment = symbol.comment;
    if (source_reference != null && comment != null)
    {
      // Backtrack to begin of line for proper alignment of multiline comments
      char* comment_begin = find_token_reverse(comment.source_reference.begin.pos, comment.source_reference.file.get_mapped_contents(), { '\r', '\n' });
      comment_begin = comment_begin == null ? comment.source_reference.begin.pos : comment_begin + 1;

      // The comment source reference end is not valid for some reason (Vala 0.46)
      string comment_code = get_string_from_pointers(comment_begin, source_reference.begin.pos);
      code = @"$(comment_code)$(code)";
    }

    return code;
  }

  /** Returns the definition of 'symbol' from the source code (with the parent symbol for context).  */
  public string? get_symbol_definition_code(Vala.Symbol symbol)
  {
    string? source = get_symbol_definition_source(symbol);
    if (source == null)
    {
      return null;
    }

    // Add the parent type or namespace for context
    unowned Vala.Symbol? parent_symbol = symbol.parent_symbol;
    if (parent_symbol is Vala.TypeSymbol || parent_symbol is Vala.Namespace)
    {
      string? parent_symbol_name = get_visible_symbol_name(parent_symbol);
      if (parent_symbol_name != null)
      {
        source = @"[$(parent_symbol_name)] $(source)";
      }
    }

    // Flatten the string otherwise display is mangled (at least in VSCode)
    return remove_extra_spaces(source);
  }

  /** Removes consecutive spaces and replaces newline by space to make a snippet suitable for one-line display (e.g. document outline). */
  public string remove_extra_spaces(string input)
  {
    StringBuilder builder = new StringBuilder();
    char* data = input.data;
    char last_char = 0;
    while (data[0] != 0)
    {
      char cur_char = data[0];
      if (cur_char == '\t')
      {
        cur_char = ' ';
      }
      if (cur_char != '\r' && cur_char != '\n' && (last_char != ' ' || cur_char != ' '))
      {
        builder.append_c(cur_char);
      }
      last_char = cur_char;
      data += 1;
    }
    return builder.str;
  }

  /** Returns the definition of 'symbol' from the source code.  */
  public string? get_symbol_definition_source(Vala.Symbol symbol)
  {
    if (symbol is Vala.Subroutine)
    {
      return get_method_declaration_source((Vala.Subroutine)symbol);
    }
    else if (symbol is Vala.LocalVariable)
    {
      return get_local_variable_definition_source((Vala.LocalVariable)symbol);
    }
    else
    {
      return get_code_node_source(symbol);
    }
  }

  private string get_local_variable_definition_source(Vala.LocalVariable variable)
  {
    string? type_name = get_type_name(variable, variable.variable_type);
    if (type_name != null)
    {
      if (logdebug) debug(@"Local variable type: '$(type_name)'");
      return type_name + " " + get_code_node_source(variable);
    }
    else
    {
      if (logdebug) debug(@"Local variable has no type: '$(code_node_to_string(variable.variable_type))'");
      return get_code_node_source(variable);
    }
  }

  private string? get_type_name(Vala.CodeNode node, Vala.DataType? data_type)
  {
    if (data_type == null)
    {
      return null;
    }

    if (data_type is Vala.GenericType)
    {
      unowned Vala.GenericType generic_type = ((Vala.GenericType)data_type);
      return generic_type.type_parameter.name;
    }
    else if (data_type is Vala.PointerType)
    {
      unowned Vala.DataType base_type = ((Vala.PointerType)data_type).base_type;
      string? type_name = get_type_symbol_name(node, base_type.data_type);
      if (type_name == null)
      {
        return null;
      }

      if (base_type.has_type_arguments())
      {
        type_name += "<";
        bool first = true;
        foreach (Vala.DataType argument_data_type in base_type.get_type_arguments())
        {
          string? argument_type_name = get_type_name(node, argument_data_type);
          if (argument_type_name == null)
          {
            return null;
          }

          if (first)
          {
            first = false;
          }
          else
          {
            type_name += ", ";
          }
          type_name += argument_type_name;
        }
        type_name += ">";
      }

      return type_name + "*";
    }
    else
    {
      string? type_name = get_type_symbol_name(node, data_type.data_type);
      if (type_name == null)
      {
        return null;
      }

      if (data_type.has_type_arguments())
      {
        type_name += "<";
        bool first = true;
        foreach (Vala.DataType argument_data_type in data_type.get_type_arguments())
        {
          string? argument_type_name = get_type_name(node, argument_data_type);
          if (argument_type_name == null)
          {
            return null;
          }

          if (first)
          {
            first = false;
          }
          else
          {
            type_name += ", ";
          }
          type_name += argument_type_name;
        }
        type_name += ">";
      }

      if (data_type.nullable)
      {
        type_name += "?";
      }

      return type_name;
    }
  }

  public string? get_type_symbol_name(Vala.CodeNode node, Vala.TypeSymbol? type_symbol)
  {
    if (type_symbol == null)
    {
      return null;
    }

    string? type_symbol_name = type_symbol.name;
    if (type_symbol_name == null)
    {
      return null;
    }

    unowned Vala.Symbol? parent_symbol = type_symbol.parent_symbol;
    while (parent_symbol != null)
    {
      string? parent_name = parent_symbol.name;
      if (parent_name == null || symbol_is_visible(node, parent_symbol))
      {
        break;
      }
      type_symbol_name = @"$(parent_name).$(type_symbol_name)";
      parent_symbol = parent_symbol.parent_symbol;
    }

    return type_symbol_name;
  }

  public bool symbol_is_visible(Vala.CodeNode node, Vala.Symbol symbol)
  {
    bool is_namespace = (symbol is Vala.Namespace);

    Vala.CodeNode? parent = get_node_parent(node);
    while (parent != null)
    {
      if (is_namespace)
      {
        if ((parent is Vala.Namespace) && ((Vala.Namespace)parent).name == symbol.name)
        {
          // Same namespace
          return true;
        }
      }
      else
      {
        if ((parent is Vala.Symbol) && ((Vala.Symbol)parent).name == symbol.name)
        {
          // Same outer type
          return true;
        }
      }
      parent = get_node_parent(parent);
    }

    if (is_namespace)
    {
      unowned Vala.SourceReference? source_reference = node.source_reference;
      if (source_reference != null)
      {
        foreach (Vala.UsingDirective using_directive in source_reference.using_directives)
        {
          if (using_directive.namespace_symbol.name == symbol.name)
          {
            // Namespace has a using statement
            return true;
          }
        }
      }
    }

    return false;
  }

  public string? get_node_namespace(Vala.CodeNode node)
  {
    Vala.CodeNode? parent = get_node_parent(node);
    while (parent != null)
    {
      if (parent is Vala.Namespace)
      {
        return ((Vala.Namespace)parent).name;
      }
      parent = get_node_parent(parent);
    }
    return null;
  }

  /** Returns the source code of 'method' including the parameters (Vala currently does not include the parameters in the source reference). */
  public string? get_method_declaration_source(Vala.Subroutine method)
  {
    unowned Vala.SourceReference? source_reference = method.source_reference;
    if (source_reference == null)
    {
      return null;
    }

    char* start = source_reference.begin.pos;
    char* max = source_reference.file.get_mapped_contents() + source_reference.file.get_mapped_length();

    // Go to the end of the method arguments
    char* end = find_method_arguments(start, max);

    // Go the end of the method declaration (semicolon) or definition (brace)
    end = end != null ? find_tokens(end, max, { '{', ';' }) : null;
    end = end == null ? source_reference.end.pos : end;

    return get_string_from_pointers(start, end);
  }

  /**
   * Searches for the arguments of a method declaration or definition, delimited by parentheses,
   * between 'start' and 'max' ('max' excluded from search).
   * Returns the position after the last parenthesis.
   */
  public char* find_method_arguments(char* start, char* max)
  {
    char* pos = start;
    int num_delimiters = 0;
    while (pos < max)
    {
      if (pos[0] == '(')
      {
        num_delimiters += 1;
      }
      else if (pos[0] == ')')
      {
        num_delimiters -= 1;
        if (num_delimiters == 0)
        {
          break;
        }
      }
      pos += 1;
    }
    return pos == max ? null : pos + 1;
  }

  /** Returns the first parent node of 'node' which is of the specified type. */
  public T? get_node_parent_of_type<T>(Vala.CodeNode? node)
  {
    if (node == null)
    {
      return null;
    }

    if (node is T)
    {
      return (T)node;
    }

    Vala.CodeNode? parent = get_node_parent(node);
    return get_node_parent_of_type<T>(parent);
  }

  /** Returns 'parent_node' or 'parent_symbol' (second choice) of 'node'. */
  public Vala.CodeNode? get_node_parent(Vala.CodeNode node)
  {
    unowned Vala.CodeNode? parent = node.parent_node;
    if (parent == null)
    {
      unowned Vala.Symbol? symbol = node as Vala.Symbol;
      if (symbol != null)
      {
        parent = symbol.parent_symbol;
      }
    }

    return parent;
  }

  /** Returns the symbol referenced by 'node' (if any). */
  public Vala.Symbol? get_symbol_reference(Vala.CodeNode node, bool prefer_override)
  {
    Vala.Symbol? symbol = get_symbol_reference_aux(node, prefer_override);

    if (symbol != null && is_hidden_symbol(symbol))
    {
      if (logdebug) debug(@"Symbol is an hidden symbol: '$(code_node_to_string(node))'");
      return null;
    }

    return symbol;
  }

  /** Returns the symbol referenced by 'node' (if any). */
  private Vala.Symbol? get_symbol_reference_aux(Vala.CodeNode node, bool prefer_override)
  {
    if (prefer_override && node is Vala.MemberAccess)
    {
      unowned Vala.MemberAccess expr = (Vala.MemberAccess)node;
      unowned Vala.Expression? inner = expr.inner;
      if (inner != null)
      {
        bool is_instance;
        Vala.Symbol? inner_type = get_expression_type(inner, out is_instance);
        if (inner_type != null)
        {
          // Specific case for MemberAccess expressions: search for a more specific definition of the member
          // (Otherwise the symbol for the expression will be the top-level declaration)
          Vala.Symbol? symbol = null;
          if (probe_symbol_table_with_base_types(inner_type, expr.member_name, SymbolFlags.ALL, ref symbol))
          {
            if (logdebug) debug(@"MemberAccess has symbol reference: '$(code_node_to_string(node))'");
            return symbol;
          }
        }
      }
    }
    if (node is Vala.Expression && !(node is Vala.Literal))
    {
      unowned Vala.Expression expr = (Vala.Expression)node;
      unowned Vala.Symbol? symbol_reference = expr.symbol_reference;
      if (symbol_reference == null || symbol_reference.source_reference == null)
      {
        if (logsilly) debug(@"Expression has no symbol reference: '$(code_node_to_string(node))'");
      }
      else
      {
        return expr.symbol_reference;
      }
    }
    else if (node is Vala.MemberInitializer)
    {
      unowned Vala.MemberInitializer initializer = (Vala.MemberInitializer)node;
      unowned Vala.Symbol? symbol_reference = initializer.symbol_reference;
      if (symbol_reference == null || symbol_reference.source_reference == null)
      {
        if (logdebug) debug(@"MemberInitializer has no symbol reference: '$(code_node_to_string(node))'");
      }
      else
      {
        return symbol_reference;
      }
    }
    else if (node is Vala.DelegateType)
    {
      return ((Vala.DelegateType)node).delegate_symbol;
    }
    else if (node is Vala.DataType)
    {
      return ((Vala.DataType)node).data_type;
    }
    else if (node is Vala.Symbol)
    {
      if (!prefer_override && node is Vala.Method)
      {
        unowned Vala.Method? base_method = ((Vala.Method)node).base_method;
        if (base_method != null)
        {
          return base_method;
        }
      }
      return (Vala.Symbol)node;
    }
    return null;
  }

  /** Returns true if the symbol is an hidden compiler-generated symbol. */
  public bool is_hidden_symbol(Vala.Symbol symbol, bool hide_default_constructor = false)
  {
    string? name = symbol.name;
    return name == null || (name.has_prefix(".") && (hide_default_constructor || name != ".new"));
  }

  /** Returns true if 'symbol' is an instance member. */
  public bool symbol_is_instance_member(Vala.Symbol? symbol)
  {
    Vala.MemberBinding? binding = get_symbol_member_binding(symbol);
    return binding == Vala.MemberBinding.INSTANCE;
  }

  /** Returns true if 'symbol' is a static member. */
  public bool symbol_is_static_member(Vala.Symbol symbol)
  {
    Vala.MemberBinding? binding = get_symbol_member_binding(symbol);
    return binding == Vala.MemberBinding.STATIC;
  }

  /** Returns the member binding type of 'symbol'. */
  public Vala.MemberBinding? get_symbol_member_binding(Vala.Symbol? symbol)
  {
    if (symbol is Vala.Field)
    {
      unowned Vala.Field f = (Vala.Field)symbol;
      return f.binding;
    }
    else if (symbol is Vala.Method && !(symbol is Vala.CreationMethod))
    {
      unowned Vala.Method m = (Vala.Method)symbol;
      return m.binding;
    }
    else if (symbol is Vala.Property)
    {
      unowned Vala.Property p = (Vala.Property)symbol;
      return p.binding;
    }
    return null;
  }

  public bool is_backing_field_symbol(Vala.Symbol? symbol)
  {
    unowned Vala.Field? field = symbol as Vala.Field;
    return field != null ? is_backing_field(field) : false;
  }

  public bool is_backing_field(Vala.Field? field)
  {
    string? field_name = field != null ? field.name : null;
    if (field == null || field_name == null)
    {
      return false;
    }

    if (field_name.has_prefix("_"))
    {
      // Heuristic to detect compiler-generated field for properties
      if (field.owner.lookup((string)(&field_name.data[1])) != null)
      {
        if (logdebug) debug(@"Ignoring property-backing field: '$(code_node_to_string(field))'");
        return true;
      }
    }

    return false;
  }

  public Vala.Symbol? get_symbol_from_code_node_scope(Vala.CodeNode node, string name, SymbolFlags flags = SymbolFlags.ALL)
  {
    Vala.Symbol? result = null;
    if (get_symbol_from_code_node_scope_aux(node, name, flags, ref result))
    {
      return result;
    }

    unowned Vala.SourceReference? source_reference = node.source_reference;
    if (source_reference == null)
    {
      return null;
    }

    foreach (Vala.UsingDirective using_directive in source_reference.using_directives)
    {
      if (probe_symbol_table(using_directive.namespace_symbol, name, flags, ref result))
      {
        return result;
      }
    }

    return null;
  }

  private bool get_symbol_from_code_node_scope_aux(Vala.CodeNode node, string name, SymbolFlags flags, ref Vala.Symbol? result)
  {
    Vala.Symbol? symbol = node as Vala.Symbol;
    if (symbol != null)
    {
      if (probe_symbol_table_with_base_types(symbol, name, flags, ref result))
      {
        return true;
      }
    }

    Vala.CodeNode? parent_node = get_node_parent(node);
    if (parent_node != null)
    {
      if (get_symbol_from_code_node_scope_aux(parent_node, name, flags, ref result))
      {
        return true;
      }
    }

    return false;
  }

  private bool probe_symbol_table_with_base_types(Vala.Symbol symbol, string name, SymbolFlags flags, ref Vala.Symbol? result)
  {
    if (probe_symbol_table(symbol, name, flags, ref result))
    {
      return true;
    }

    Gee.ArrayList<Vala.Symbol> base_types = get_base_types(symbol);
    foreach (Vala.Symbol base_type in base_types)
    {
      if (probe_symbol_table(base_type, name, flags & ~SymbolFlags.PRIVATE, ref result))
      {
        return true;
      }
    }

    return false;
  }

  private bool probe_symbol_table(Vala.Symbol symbol, string name, SymbolFlags flags, ref Vala.Symbol? result)
  {
    Vala.Map<string, Vala.Symbol>? symbol_table = symbol.scope.get_symbol_table();
    if (symbol_table == null)
    {
      return false;
    }

    if (logdebug) debug(@"Check symbol table for symbol: '$(code_node_to_string(symbol))'");

    Vala.Symbol? scope_symbol = symbol_table.get(name);
    if (scope_symbol == null)
    {
      return false;
    }
    if (!is_symbol_compatible_with_flags(scope_symbol, flags))
    {
      return false;
    }

    result = scope_symbol;
    return true;
  }

  private bool is_symbol_compatible_with_flags(Vala.Symbol symbol, SymbolFlags flags)
  {
    if (symbol_is_instance_member(symbol) && !(SymbolFlags.INSTANCE in flags))
    {
      return false;
    }
    if (symbol.access == Vala.SymbolAccessibility.INTERNAL && !(SymbolFlags.INTERNAL in flags))
    {
      return false;
    }
    if (symbol.access == Vala.SymbolAccessibility.PROTECTED && !(SymbolFlags.PROTECTED in flags))
    {
      return false;
    }
    if (symbol.access == Vala.SymbolAccessibility.PRIVATE && !(SymbolFlags.PRIVATE in flags))
    {
      // For some reason, error codes are private static (seems like a Vala bug but not sure)
      if (!(symbol is Vala.ErrorCode))
      {
        return false;
      }
    }

    return true;
  }

  /** Returns the base types of 'symbol' (recursively). */
  public Gee.ArrayList<Vala.Symbol> get_base_types(Vala.Symbol? symbol)
  {
    Gee.ArrayList<Vala.Symbol> base_types = new Gee.ArrayList<Vala.Symbol>();

    add_base_types(symbol, base_types);

    return base_types;
  }

  /** Adds the base types of 'symbol' to the list (recursively). */
  public void add_base_types(Vala.Symbol? symbol, Gee.ArrayList<Vala.Symbol> base_type_symbols)
  {
    if (symbol == null)
    {
      return;
    }

    if (symbol is Vala.Class)
    {
      unowned Vala.Class class_symbol = (Vala.Class)symbol;
      Vala.List<Vala.DataType> base_types = class_symbol.get_base_types();
      foreach (Vala.DataType base_type in base_types)
      {
        unowned Vala.TypeSymbol? base_type_symbol = base_type.data_type;
        if (base_type_symbol != null)
        {
          base_type_symbols.add(base_type_symbol);
          add_base_types(base_type_symbol, base_type_symbols);
        }
      }
    }
    else if (symbol is Vala.Struct)
    {
      unowned Vala.Struct struct_symbol = (Vala.Struct)symbol;
      unowned Vala.DataType? base_type = struct_symbol.base_type;
      unowned Vala.TypeSymbol? base_type_symbol = base_type != null ? (Vala.TypeSymbol?)base_type.data_type : null;
      if (base_type_symbol != null)
      {
        base_type_symbols.add(base_type_symbol);
        add_base_types(base_type_symbol, base_type_symbols);
      }
    }
    else if (symbol is Vala.Interface)
    {
      unowned Vala.Interface interface_symbol = (Vala.Interface)symbol;
      Vala.List<Vala.DataType> base_types = interface_symbol.get_prerequisites();
      foreach (Vala.DataType base_type in base_types)
      {
        unowned Vala.TypeSymbol? base_type_symbol = base_type.data_type;
        if (base_type_symbol != null)
        {
          base_type_symbols.add(base_type_symbol);
          add_base_types(base_type_symbol, base_type_symbols);
        }
      }
    }
  }

  private Gee.Map<Type, unowned string>? symbol_type_readable_names = null;

  public unowned string get_symbol_type_readable_name(Vala.Symbol symbol)
  {
    Gee.Map<Type, unowned string>? names = symbol_type_readable_names;

    if (names == null)
    {
      names = new Gee.HashMap<Type, unowned string>();
      names.set(typeof(Vala.Namespace), "namespace");
      names.set(typeof(Vala.Parameter), "parameter");
      names.set(typeof(Vala.LocalVariable), "local variable");
      names.set(typeof(Vala.Method), "method");
      names.set(typeof(Vala.Field), "field");
      names.set(typeof(Vala.Property), "property");
      names.set(typeof(Vala.Signal), "signal");
      names.set(typeof(Vala.Constant), "constant");
      names.set(typeof(Vala.Class), "class");
      names.set(typeof(Vala.Struct), "struct");
      names.set(typeof(Vala.Enum), "enum");
      names.set(typeof(Vala.EnumValue), "enum value");
      names.set(typeof(Vala.ErrorDomain), "error domain");
      names.set(typeof(Vala.ErrorCode), "error code");
      symbol_type_readable_names = names;
    }

    Type symbol_type = Type.from_instance(symbol);
    unowned string? symbol_type_name = names.get(symbol_type);
    return symbol_type_name ?? symbol_type.name();
  }

  /** Returns the ancestor type (root of the class/struct tree) of 'symbol'. */
  public Vala.Symbol get_ancestor_type(Vala.Symbol? symbol)
  {
    Vala.Symbol? base_type = get_parent_type(symbol);
    return base_type == null ? symbol : get_ancestor_type(base_type);
  }

  /** Returns the parent type of 'symbol'. */
  public Vala.Symbol? get_parent_type(Vala.Symbol? symbol)
  {
    if (symbol == null)
    {
      return null;
    }
    if (symbol is Vala.Class)
    {
      return ((Vala.Class)symbol).base_class;
    }
    if (symbol is Vala.Struct)
    {
      return ((Vala.Struct)symbol).base_struct;
    }

    return null;
  }

  /**
   * Returns the type symbol of the specified expression.
   * Also sets 'is_instance' based on whether the expression denotes an instance of the type or the type itself.
   */
  public Vala.Symbol? get_expression_type(Vala.Expression expression, out bool is_instance)
  {
    is_instance = false;

    unowned Vala.Symbol? symbol_reference = expression.symbol_reference;
    if (symbol_reference is Vala.TypeSymbol || symbol_reference is Vala.Namespace)
    {
      // Expression references a symbol which is a static type or namespace (not an instance of a type)
      if (logdebug) debug(@"Expression references static type: '$(code_node_to_string(symbol_reference))'");
      if (expression is Vala.BaseAccess)
      {
        // Special case for 'base' access
        is_instance = true;
      }
      return symbol_reference;
    }

    if (symbol_reference is Vala.Variable)
    {
      unowned Vala.DataType? variable_type = ((Vala.Variable)symbol_reference).variable_type;
      if (variable_type != null && ((Vala.TypeSymbol?)variable_type.data_type) != null)
      {
        // Expression references a symbol which is an instance of a type
        if (logdebug) debug(@"Expression references a variable: '$(code_node_to_string(symbol_reference))'");
        is_instance = true;
        return variable_type.data_type;
      }
    }

    unowned Vala.DataType? value_type = expression.value_type;
    if (value_type != null && ((Vala.TypeSymbol?)value_type.data_type) != null)
    {
      // Expression does not reference a symbol but the compiler has been able to infer its type
      if (logdebug) debug(@"Expression does not reference a symbol but has a type: '$(code_node_to_string(value_type.data_type))'");
      is_instance = true;
      return value_type.data_type;
    }

    return null;
  }

  /** Converts a 'SourceReference' to a 'Location'. */
  public Location source_reference_to_location(Vala.SourceReference source_reference) throws Error
  {
    return new Location()
    {
      uri = Filename.to_uri(source_reference.file.filename),
      range = source_reference_to_range(source_reference)
    };
  }

  /** Converts a 'SourceReference' to a 'Range'. */
  public Range source_reference_to_range(Vala.SourceReference source_reference)
  {
    return new Range()
    {
      start = new Position()
      {
        line = source_reference.begin.line - 1,
        character = source_reference.begin.column - 1
      },
      end = new Position()
      {
        line = source_reference.end.line - 1,
        character = source_reference.end.column
      }
    };
  }

  public Diagnostic source_error_to_diagnostic(SourceError error, DiagnosticSeverity severity)
  {
    return new Diagnostic()
    {
      range = source_reference_to_range(error.source),
      severity = severity,
      message = error.message
    };
  }

  /**
   * Searches for 'identifier' as a "whole word" inside the source of 'node' and returns the location of that identifier.
   * If 'strict' is not set, the location of 'node' is returned if the identifier could not be found (should not happen normally).
   */
  public Location? get_symbol_location(Vala.CodeNode node, Vala.Symbol symbol, bool strict) throws Error
  {
    string? symbol_name = get_visible_symbol_name(symbol);
    if (symbol_name == null)
    {
      return null;
    }

    unowned Vala.SourceReference? source_reference = node.source_reference;
    if (source_reference == null)
    {
      if (logwarn) warning(@"Node has no source reference: '$(code_node_to_string(node))'");
      return null;
    }

    Location location = source_reference_to_location(source_reference);

    // Try to find the identifier in the source and update the location to point to the identifier
    char* start = source_reference.begin.pos;
    char* max = source_reference.file.get_mapped_contents() + source_reference.file.get_mapped_length();
    char* identifier_pos = find_identifier_range(start, max, symbol_name, location.range);
    if (identifier_pos == null)
    {
      if (loginfo) info(@"Could not find identifier '$(symbol_name)' in source of node '$(code_node_to_string(node))'");
      if (strict)
      {
        return null;
      }
    }

    return location;
  }

  /** Retuns the symbol name as it appears in the source code */
  public string? get_visible_symbol_name(Vala.Symbol symbol)
  {
    unowned string? symbol_name = symbol.name;

    if (symbol_name != null)
    {
      if (symbol is Vala.CreationMethod)
      {
        if (symbol_name == ".new")
        {
          return ((Vala.CreationMethod)symbol).class_name;
        }
        else
        {
          return ((Vala.CreationMethod)symbol).class_name + "." + symbol_name;
        }
      }
    }

    return symbol_name;
  }

  public bool is_package_code_node(Vala.CodeNode node)
  {
    unowned Vala.SourceReference? source_reference = node.source_reference;
    return source_reference != null && source_reference.file.file_type == Vala.SourceFileType.PACKAGE;
  }

  public bool is_source_code_node(Vala.CodeNode node)
  {
    unowned Vala.SourceReference? source_reference = node.source_reference;
    return source_reference != null && source_reference.file.file_type == Vala.SourceFileType.SOURCE;
  }

  /**
   * Searches for 'identifier' as a "whole word" between 'start' and 'max', updates 'range' accordingly if it is found
   * and returns a pointer to the identifier.
   */
  public char* find_identifier_range(char* start, char* max, string identifier, Range? range = null)
  {
    int identifier_length = identifier.length;
    uint line = range != null ? range.start.line : 0;
    uint character = range != null ? range.start.character : 0;
    char* pos = start;
    while (pos < max)
    {
      bool is_candidate = (pos == start || !is_identifier_char(pos[-1]) || pos[-1] == '@') && (pos == (max - 1) || !is_identifier_char(pos[identifier_length]));
      if (is_candidate && equal_strings(pos, (char*)identifier, identifier_length))
      {
        if (range != null)
        {
          range.start.line = line;
          range.start.character = character;
          range.end.line = line;
          range.end.character = character + identifier_length;
        }
        return pos;
      }
      if (pos[0] == '\n')
      {
        line += 1;
        character = 0;
      }
      else
      {
        character += 1;
      }
      pos += 1;
    }
    return null;
  }

  /** Takes a position from VS code (0-based) and returns the byte offset in 'text'. */
  public int get_char_byte_index(string text, uint position_line, uint position_character)
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

  /** Check C-strings for equality. */
  public bool equal_strings(char* s1, char* s2, int length)
  {
    for (int i = 0; i < length; i++)
    {
      if (s1[i] != s2[i])
      {
        return false;
      }
    }
    return true;
  }

  public bool is_identifier_char(char c)
  {
    return c.isalnum() || c == '_' || c == '@';
  }
}
