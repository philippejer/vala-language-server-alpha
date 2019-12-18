
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
    return node1.source_reference.begin.pos >= node2.source_reference.begin.pos &&
           node1.source_reference.end.pos <= node2.source_reference.end.pos;
  }

  /** Returns true if 'node1' and 'node2' reference the same source. */
  public bool code_node_matches(Vala.CodeNode node1, Vala.CodeNode node2)
  {
    return node1.source_reference.begin.pos == node2.source_reference.begin.pos &&
           node1.source_reference.end.pos == node2.source_reference.end.pos;
  }

  /** Returns the source code for 'node'. */
  public string get_code_node_source(Vala.CodeNode node)
  {
    if (node.source_reference == null)
    {
      return "";
    }
    return get_source_reference_source(node.source_reference);
  }

  /** Returns the source code for 'source_reference'. */
  public string get_source_reference_source(Vala.SourceReference source_reference)
  {
    char* begin = source_reference.begin.pos;
    char* end = source_reference.end.pos;
    return get_string_from_pointers(begin, end);
  }

  /** Extracts the substring between 'begin' and 'end'. */
  public string get_string_from_pointers(char* begin, char* end)
  {
    return ((string)begin).substring(0, (long)(end - begin));
  }

  /** Searches for one of 'tokens' between 'begin' and 'max' ('max' excluded from search). */
  public char* find_tokens(char* begin, char* max, char[] tokens)
  {
    char* pos = begin;
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

  /** Searches for 'token' in reverse between 'begin' and 'min' ('min' included in search). */
  public char* find_token_reverse(char* begin, char* min, char[] tokens)
  {
    char* pos = begin;
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
    var symbol = node as Vala.Symbol;
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
  public string get_symbol_definition_code_with_comment(Vala.Symbol symbol)
  {
    string code = get_symbol_definition_code(symbol);

    if (symbol.comment != null)
    {
      // Backtrack to begin of line for proper alignment of multiline comments
      char* comment_begin = find_token_reverse(symbol.comment.source_reference.begin.pos, symbol.comment.source_reference.file.get_mapped_contents(), { '\r', '\n' });
      comment_begin = comment_begin == null ? symbol.comment.source_reference.begin.pos : comment_begin + 1;

      // The comment source reference end is not valid for some reason (Vala 0.46)
      string comment_code = get_string_from_pointers(comment_begin, symbol.source_reference.begin.pos);
      code = @"$(comment_code)$(code)";
    }

    return code;
  }

  /** Returns the definition of 'symbol' from the source code (with the parent symbol for context).  */
  public string get_symbol_definition_code(Vala.Symbol symbol)
  {
    string source = get_symbol_definition_source(symbol);

    // Add the parent symbol name for context (hack-ish but simple)
    Vala.Symbol? parent_symbol = symbol.parent_symbol;
    if (parent_symbol != null && parent_symbol.name != null)
    {
      source = @"[$(get_visible_symbol_name(parent_symbol))] $(source)";
    }

    // Flatten the string otherwise display is mangled (at least in VSCode)
    return remove_extra_spaces(source);
  }

  /** Removes consecutive spaces and replaces newline by space to make a snippet suitable for one-line display (e.g. document outline). */
  public string remove_extra_spaces(string input)
  {
    var builder = new StringBuilder();
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
  public string get_symbol_definition_source(Vala.Symbol symbol)
  {
    if (symbol is Vala.Subroutine)
    {
      return get_method_declaration_source((Vala.Subroutine)symbol);
    }
    else if (symbol is Vala.LocalVariable)
    {
      Vala.LocalVariable variable = (Vala.LocalVariable)symbol;
      if (variable.variable_type != null)
      {
        if (logdebug) debug(@"Local variable type: '$(code_node_to_string(variable.variable_type))', type symbol: '$(code_node_to_string(variable.variable_type.data_type))'");
        if (variable.variable_type.data_type != null && variable.variable_type.data_type.name != null)
        {
          return variable.variable_type.data_type.name + " " + get_code_node_source(symbol);
        }
      }
      else
      {
        if (logdebug) debug(@"Local variable has no type: '$(code_node_to_string(variable.variable_type))'");
      }
      return get_code_node_source(symbol);
    }
    else if (symbol is Vala.Variable)
    {
      Vala.Variable variable = (Vala.Variable)symbol;
      if (variable.variable_type != null)
      {
        if (logdebug) debug(@"Variable: '$(code_node_to_string(variable))', type: '$(code_node_to_string(variable.variable_type))', type symbol: '$(code_node_to_string(variable.variable_type.data_type))'");
      }
      return get_code_node_source(symbol);
    }
    else
    {
      return get_code_node_source(symbol);
    }
  }

  /** Returns the source code of 'method' including the parameters (Vala currently does not include the parameters in the source reference). */
  public string get_method_declaration_source(Vala.Subroutine method)
  {
    char* begin = method.source_reference.begin.pos;
    char* max = method.source_reference.file.get_mapped_contents() + method.source_reference.file.get_mapped_length();
    char* pos = find_text_between_parens(begin, max);
    pos = pos != null ? find_tokens(pos, max, { '{', ';' }) : null;
    char* end = pos == null ? method.source_reference.end.pos : pos;
    return get_string_from_pointers(begin, end);
  }

  /**
   * Searches for a text fragment delimited by parentheses between 'begin' and 'max' ('max' excluded from search).
   * Returns the position after the last parenthesis.
   */
  public char* find_text_between_parens(char* begin, char* max)
  {
    int num_delimiters = 0;
    char* pos = begin;
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
    Vala.CodeNode? parent = node.parent_node;
    if (parent == null)
    {
      var symbol = node as Vala.Symbol;
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
      var expr = (Vala.MemberAccess)node;
      if (expr.inner != null)
      {
        Vala.Symbol? inner_type = get_expression_type(expr.inner);
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
      var expr = (Vala.Expression)node;
      if (expr.symbol_reference == null || expr.symbol_reference.source_reference == null)
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
      var init = (Vala.MemberInitializer)node;
      if (init.symbol_reference == null || init.symbol_reference.source_reference == null)
      {
        if (logdebug) debug(@"MemberInitializer has no symbol reference: '$(code_node_to_string(node))'");
      }
      else
      {
        return init.symbol_reference;
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
        var base_method = ((Vala.Method)node).base_method;
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
    return symbol.name == null || (symbol.name.has_prefix(".") && (hide_default_constructor || symbol.name != ".new"));
  }

  /** Returns true if 'symbol' is an instance member. */
  public bool symbol_is_instance_member(Vala.Symbol symbol)
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
  public Vala.MemberBinding? get_symbol_member_binding(Vala.Symbol symbol)
  {
    if (symbol is Vala.Field)
    {
      var f = (Vala.Field)symbol;
      return f.binding;
    }
    else if (symbol is Vala.Method && !(symbol is Vala.CreationMethod))
    {
      var m = (Vala.Method)symbol;
      return m.binding;
    }
    else if (symbol is Vala.Property)
    {
      var p = (Vala.Property)symbol;
      return p.binding;
    }
    return null;
  }

  public bool is_backing_field_symbol(Vala.Symbol symbol)
  {
    var field = symbol as Vala.Field;
    return field != null ? is_backing_field(field) : false;
  }

  public bool is_backing_field(Vala.Field field)
  {
    if (field.name != null && field.name.has_prefix("_"))
    {
      // Heuristic to detect compiler-generated field for properties
      if (field.owner.lookup((string)(&field.name.data[1])) != null)
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
    if (node.source_reference != null && node.source_reference.using_directives != null)
    {
      foreach (Vala.UsingDirective using_directive in node.source_reference.using_directives)
      {
        if (using_directive.namespace_symbol != null)
        {
          if (probe_symbol_table(using_directive.namespace_symbol, name, flags, ref result))
          {
            return result;
          }
        }
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
    var base_types = get_base_types(symbol);
    if (base_types != null)
    {
      foreach (Vala.Symbol base_type in base_types)
      {
        if (probe_symbol_table(base_type, name, flags & ~SymbolFlags.PRIVATE, ref result))
        {
          return true;
        }
      }
    }
    return false;
  }

  private bool probe_symbol_table(Vala.Symbol symbol, string name, SymbolFlags flags, ref Vala.Symbol? result)
  {
    Vala.Map<string, Vala.Symbol> symbol_table = symbol.scope.get_symbol_table();
    if (symbol_table == null)
    {
      return false;
    }
    if (logdebug) debug(@"Check symbol table for symbol: '$(code_node_to_string(symbol))'");
    Vala.Symbol? scope_symbol = symbol_table[name];
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
    var base_types = new Gee.ArrayList<Vala.Symbol>();
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
      Vala.Class class_node = (Vala.Class)symbol;
      Vala.List<Vala.DataType> base_types = class_node.get_base_types();
      foreach (Vala.DataType base_type in base_types)
      {
        if (base_type.data_type != null)
        {
          base_type_symbols.add(base_type.data_type);
          add_base_types(base_type.data_type, base_type_symbols);
        }
      }
    }
    else if (symbol is Vala.Struct)
    {
      Vala.Struct struct_node = (Vala.Struct)symbol;
      if (struct_node.base_type != null && struct_node.base_type.data_type != null)
      {
        base_type_symbols.add(struct_node.base_type.data_type);
        add_base_types(struct_node.base_type.data_type, base_type_symbols);
      }
    }
    else if (symbol is Vala.Interface)
    {
      Vala.Interface interface_node = (Vala.Interface)symbol;
      Vala.List<Vala.DataType> base_types = interface_node.get_prerequisites();
      foreach (Vala.DataType base_type in base_types)
      {
        if (base_type.data_type != null)
        {
          base_type_symbols.add(base_type.data_type);
          add_base_types(base_type.data_type, base_type_symbols);
        }
      }
    }
  }

  private Gee.Map<Type, unowned string> symbol_type_names = null;

  public unowned string get_symbol_type_name(Vala.Symbol symbol)
  {
    if (symbol_type_names == null)
    {
      symbol_type_names = new Gee.HashMap<Type, unowned string>();
      symbol_type_names.set(typeof(Vala.Namespace), "namespace");
      symbol_type_names.set(typeof(Vala.Parameter), "parameter");
      symbol_type_names.set(typeof(Vala.LocalVariable), "local variable");
      symbol_type_names.set(typeof(Vala.Method), "method");
      symbol_type_names.set(typeof(Vala.Field), "field");
      symbol_type_names.set(typeof(Vala.Property), "property");
      symbol_type_names.set(typeof(Vala.Signal), "signal");
      symbol_type_names.set(typeof(Vala.Constant), "constant");
      symbol_type_names.set(typeof(Vala.Class), "class");
      symbol_type_names.set(typeof(Vala.Struct), "struct");
      symbol_type_names.set(typeof(Vala.Enum), "enum");
      symbol_type_names.set(typeof(Vala.EnumValue), "enum value");
      symbol_type_names.set(typeof(Vala.ErrorDomain), "error domain");
      symbol_type_names.set(typeof(Vala.ErrorCode), "error code");
    }
    Type symbol_type = Type.from_instance(symbol);
    unowned string name = symbol_type_names[symbol_type];
    return name ?? symbol_type.name();
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
  public Vala.Symbol? get_expression_type(Vala.Expression expr, out bool? is_instance = null)
  {
    is_instance = false;
    Vala.Symbol? symbol = expr.symbol_reference;
    if (symbol is Vala.TypeSymbol || symbol is Vala.Namespace)
    {
      // Expression references a symbol which is a static type or namespace (not an instance of a type)
      if (logdebug) debug(@"Expression references static type: '$(code_node_to_string(symbol))'");
      if (expr is Vala.BaseAccess)
      {
        // Special case for 'base' access
        is_instance = true;
      }
      return symbol;
    }
    Vala.Variable? variable = symbol as Vala.Variable;
    if (variable != null && variable.variable_type != null && variable.variable_type.data_type != null)
    {
      // Expression references a symbol which is an instance of a type
      if (logdebug) debug(@"Expression references a variable: '$(code_node_to_string(variable))'");
      is_instance = true;
      return variable.variable_type.data_type;
    }
    if (expr.value_type != null && expr.value_type.data_type != null)
    {
      // Expression does not reference a symbol but the compiler has been able to infer its type
      if (logdebug) debug(@"Expression does not reference a symbol but has a type: '$(code_node_to_string(expr.value_type.data_type))'");
      is_instance = true;
      return expr.value_type.data_type;
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
    string symbol_name = get_visible_symbol_name(symbol);
    if (symbol_name == null)
    {
      return null;
    }

    if (node.source_reference == null)
    {
      if (logwarn) warning(@"Node has no source reference: '$(code_node_to_string(node))'");
      return null;
    }

    Location location = source_reference_to_location(node.source_reference);
    string source = get_code_node_source(node);
    if (!find_identifier_range(location.range, source, symbol_name))
    {
      if (loginfo) info(@"Could not find identifier '$(symbol_name)' in source '$(source)'");
      if (strict)
      {
        return null;
      }
    }

    return location;
  }

  /** Retuns the symbol name as it appears in the source code */
  public string get_visible_symbol_name(Vala.Symbol symbol)
  {
    if (symbol is Vala.CreationMethod)
    {
      if (symbol.name == ".new")
      {
        return ((Vala.CreationMethod)symbol).class_name;
      }
      else
      {
        return ((Vala.CreationMethod)symbol).class_name + "." + symbol.name;
      }
    }
    return symbol.name;
  }

  public bool is_package_code_node(Vala.CodeNode node)
  {
    return node.source_reference != null && node.source_reference.file.file_type == Vala.SourceFileType.PACKAGE;
  }

  public bool is_source_code_node(Vala.CodeNode node)
  {
    return node.source_reference != null && node.source_reference.file.file_type == Vala.SourceFileType.SOURCE;
  }

  /**
   * Searches for 'identifier' as a "whole word" inside 'source' and updates 'range' accordingly if the identifier is found.
   * Returns true if 'identifier' is found inside 'source'.
   */
  public bool find_identifier_range(Range range, string source, string identifier)
  {
    int source_length = source.length;
    int identifier_length = identifier.length;
    uint line = range.start.line;
    uint character = range.start.character;
    int pos = 0;
    int end = source_length - identifier_length + 1;
    while (pos < end)
    {
      char prev = source[pos - 1];
      char next = source[pos + identifier_length];
      bool is_candidate = (pos == 0 || !is_identifier_char(prev) || prev == '@') && (pos == (end - 1) || !is_identifier_char(next));
      if (is_candidate && equal_strings((char*)&source.data[pos], (char*)identifier, identifier_length))
      {
        range.start.line = line;
        range.start.character = character;
        range.end.line = line;
        range.end.character = character + identifier_length;
        return true;
      }
      if (source[pos] == '\n')
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
    return false;
  }

  /** Extends 'in_range' into 'ref_range'. */
  public void extend_ranges(Range ref_range, Range in_range)
  {
    if ((ref_range.start.line > in_range.start.line) || (ref_range.start.line == in_range.start.line && ref_range.start.character > in_range.start.character))
    {
      ref_range.start.line = in_range.start.line;
      ref_range.start.character = in_range.start.character;
    }
    if ((ref_range.end.line < in_range.end.line) || (ref_range.end.line == in_range.end.line && ref_range.end.character < in_range.end.character))
    {
      ref_range.end.line = in_range.end.line;
      ref_range.end.character = in_range.end.character;
    }
  }

  /** Takes a position from VS code (0-based) and returns the corresponding byte offset. */
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
