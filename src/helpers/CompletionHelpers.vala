namespace Vls
{
  /** Flags to control how reachable symbols are filtered for completion. */
  [Flags]
  enum SymbolFlags
  {
    NONE = 0,
    INSTANCE,
    INTERNAL,
    PROTECTED,
    PRIVATE,
    ALL = INSTANCE | INTERNAL | PROTECTED | PRIVATE
  }

  /** A symbol with an order (completion priority, lower is better). */
  class OrderedSymbol
  {
    public Vala.Symbol symbol { get; set; }
    public int order { get; set; }
  }

  const string completion_symbol_name = "__completion_symbol__";
  const string completion_wildcard_name = "__completion_wildcard__";

  /** Returns the list of completions at the specified position. */
  CompletionList? get_completion_list(Context context, SourceFile source_file, Position position)
  {
    string completion_member;
    Gee.Map<string, OrderedSymbol>? symbols = get_completion_symbols(context, source_file, position.line, position.character, out completion_member);
    if (symbols == null)
    {
      return null;
    }

    var completion_items = new JsonArrayList<CompletionItem>();
    Gee.MapIterator<string, OrderedSymbol> iter = symbols.map_iterator();
    for (bool has_next = iter.next(); has_next; has_next = iter.next())
    {
      string name = iter.get_key();
      OrderedSymbol ordered_symbol = iter.get_value();
      Vala.Symbol symbol = ordered_symbol.symbol;
      string code = get_symbol_definition_code(symbol);
      var completion_item = new CompletionItem();
      completion_item.label = name;
      completion_item.documentation = new MarkupContent()
      {
        kind = MarkupContent.KIND_MARKDOWN,
        value = @"```vala\n$(code)\n```"
      };
      completion_item.sortText = "%03d:%s".printf(ordered_symbol.order, code);
      completion_item.insertText = name;
      completion_item.insertTextFormat = InsertTextFormat.PlainText;
      if (symbol is Vala.Field)
      {
        completion_item.kind = CompletionItemKind.Field;
      }
      if (symbol is Vala.Property)
      {
        completion_item.kind = CompletionItemKind.Property;
      }
      if (symbol is Vala.Variable || symbol is Vala.Parameter)
      {
        completion_item.kind = CompletionItemKind.Variable;
      }
      if (symbol is Vala.Method)
      {
        completion_item.kind = CompletionItemKind.Method;
      }
      if (symbol is Vala.Delegate)
      {
        completion_item.kind = CompletionItemKind.Method;
      }
      if (symbol is Vala.Class || symbol is Vala.Struct)
      {
        completion_item.kind = CompletionItemKind.Class;
      }
      if (symbol is Vala.Enum || symbol is Vala.ErrorDomain)
      {
        completion_item.kind = CompletionItemKind.Enum;
      }
      if (symbol is Vala.EnumValue || symbol is Vala.ErrorCode)
      {
        completion_item.kind = CompletionItemKind.EnumMember;
      }
      if (symbol is Vala.Interface)
      {
        completion_item.kind = CompletionItemKind.Interface;
      }
      if (symbol is Vala.Namespace)
      {
        completion_item.kind = CompletionItemKind.Module;
      }
      completion_items.add(completion_item);
    }

    return new CompletionList()
    {
      isIncomplete = false,
      items = completion_items
    };
  }

  /**
   * Returns the completion symbols at the specified position.
   * The general strategy is to:
   * 1. Backtrack from cursor to find something which looks like a Vala 'MemberAccess' expression (e.g. 'source_fil' or 'source_file.ope').
   * 2. Temporarily modify the source to comment the incomplete line (so that the parser does not choke) and insert a variable declaration of the form:
   *    'int __completion_symbol__ = [completion_expression];'
   * 3. Rebuild the syntax tree, find the '__completion_symbol__' node and inspect it to infer a list of proposals.
   */
  Gee.Map<string, OrderedSymbol>? get_completion_symbols(Context context, SourceFile source_file, uint line, uint character, out string completion_member)
  {
    string original_source = source_file.content;
    try
    {
      // Extract the completion expression
      int position_index = get_char_byte_index(source_file.content, line, character);
      string completion_expression = extract_completion_expression(source_file.content, position_index);
      if (completion_expression.has_suffix(".") || completion_expression == "")
      {
        completion_expression += completion_wildcard_name;
      }
      if (loginfo) info(@"Completion expression ($(completion_expression))");

      // Comment the incomplete line and insert the variable declaration
      int line_index = get_char_byte_index(source_file.content, line, 0);
      int start_index = skip_source_spaces(source_file.content, line_index);
      int next_line_index = get_char_byte_index(source_file.content, line + 1, 0);
      string line_str = source_file.content.slice(line_index, next_line_index);
      string insert_str = @"int $(completion_symbol_name) = $(completion_expression); ";
      if (line_str.contains("{"))
      {
        insert_str += "{";
      }
      insert_str += "//";
      source_file.content = source_file.content.splice(start_index, start_index, insert_str);

      // Rebuild the syntax tree to compute the completion symbols
      context.check();
      return compute_completion_symbols(source_file, out completion_member);
    }
    finally
    {
      // Restore the source file to its original state
      source_file.content = original_source;
    }
  }

  /**
   * Backtracks from 'index' to find something which looks like a Vala 'MemberAccess' expression.
   * Ugly hack, ideally the parser should be modified to help with this.
   */
  string extract_completion_expression(string source, int index)
  {
    int current = index - 1;
    int num_delimiters = 0;
    bool in_string = false;
    bool in_triple_string = false;
    bool in_space = false;
    while (current >= 0)
    {
      char c = source[current];
      if (in_string)
      {
        if (c == '"')
        {
          if (in_triple_string && current >= 2 && source[current - 1] == '"' && source[current - 2] == '"')
          {
            in_triple_string = false;
            in_string = false;
          }
          else if (current >= 1 && source[current - 1] != '\\')
          {
            in_string = false;
          }
        }
      }
      else
      {
        if (c == '"')
        {
          in_string = true;
          if (current >= 2 && source[current - 1] == '"' && source[current - 2] == '"')
          {
            in_triple_string = true;
            current -= 2;
          }
        }
        else if (c == ')' || c == ']')
        {
          num_delimiters += 1;
        }
        else if (num_delimiters > 0 && (c == '(' || c == '['))
        {
          num_delimiters -= 1;
        }
        else if (num_delimiters == 0 && !c.isspace() && !c.isalnum() && c != '_' && c != '.')
        {
          break;
        }
        else if (num_delimiters == 0 && in_space && c.isalnum())
        {
          break;
        }
        in_space = c.isspace();
      }
      current -= 1;
    }
    return source.slice(current + 1, index).strip();
  }



  /**
   * Returns the completion symbols at the specified position.
   * The general strategy is to:
   * 1. Backtrack from cursor to find something which looks like a Vala 'MemberAccess' expression (e.g. 'source_fil' or 'source_file.ope').
   * 2. Temporarily modify the source to comment the incomplete line (so that the parser does not choke) and insert a variable declaration of the form:
   *    'int __completion_symbol__ = [expression];'
   * 3. Re-run the compilation, find the '__completion_symbol__' node and inspect it to infer a list of proposals.
   */

  /**
   * Finds the inserted 'int __completion_symbol__ = [completion_expression];' variable declaration and inspect it to determine a list of completions.
   */
  Gee.Map<string, OrderedSymbol>? compute_completion_symbols(SourceFile source_file, out string completion_member)
  {
    Vala.Symbol? completion_symbol = find_completion_symbol(source_file.file, completion_symbol_name);
    if (completion_symbol == null)
    {
      return null;
    }

    var completion_variable = completion_symbol as Vala.Variable;
    if (completion_variable == null)
    {
      if (logwarn) warning("Completion symbol is not a variable");
      return null;
    }

    if (loginfo) info(@"Completion symbol ($(code_scope_to_string(completion_variable)))");
    if (loginfo) info(@"Completion symbol initializer ($(code_node_to_string(completion_variable.initializer)))");

    Vala.MemberAccess? completion_initializer = completion_variable.initializer as Vala.MemberAccess;
    if (completion_initializer == null)
    {
      if (logwarn) warning("Completion initializer is not a member access");
      return null;
    }

    Vala.TypeSymbol? parent_type = get_node_parent_of_type<Vala.TypeSymbol>(completion_variable);
    Vala.Symbol? parent_ancestor_type = get_ancestor_type(parent_type);
    Vala.Method? parent_method = get_node_parent_of_type<Vala.Method>(completion_variable);
    Vala.Namespace? parent_namespace = get_node_parent_of_type<Vala.Namespace>(completion_variable);
    if (loginfo) info(@"Completion symbol parent type ($(code_scope_to_string(parent_type)))");
    if (loginfo) info(@"Completion symbol ancestor type ($(code_scope_to_string(parent_ancestor_type)))");
    if (loginfo) info(@"Completion symbol parent method ($(code_scope_to_string(parent_method)))");
    if (loginfo) info(@"Completion symbol parent namespace ($(code_scope_to_string(parent_namespace)))");

    completion_member = completion_initializer.member_name;
    Vala.Expression? completion_inner = completion_initializer.inner;
    if (completion_inner == null)
    {
      Gee.Map<string, OrderedSymbol> global_symbols = find_global_symbols(completion_variable);
      if (completion_member != completion_wildcard_name)
      {
        filter_completion_symbols(global_symbols, completion_member);
      }
      return global_symbols;
    }
    if (loginfo) info(@"Completion inner expression ($(code_scope_to_string(completion_inner)))");

    bool is_instance;
    Vala.Symbol? completion_inner_type = get_expression_type(completion_inner, out is_instance);
    if (completion_inner_type == null)
    {
      if (logwarn) warning("Completion inner expression has no type");
      return null;
    }
    if (loginfo) info(@"Completion inner expression type ($(is_instance ? "instance" : "class")) ($(code_scope_to_string(completion_inner_type)))");

    Vala.Symbol? completion_inner_ancestor_type = get_ancestor_type(completion_inner_type);
    if (loginfo) info(@"Completion inner expression ancestor type ($(code_scope_to_string(completion_inner_ancestor_type)))");

    Vala.Namespace? completion_inner_namespace = get_node_parent_of_type<Vala.Namespace>(completion_inner_type);
    if (loginfo) info(@"Completion inner expression namespace ($(code_scope_to_string(completion_inner_namespace)))");

    bool is_same_type = completion_inner_type == parent_type;
    bool is_related_type = completion_inner_ancestor_type == parent_ancestor_type;
    bool is_same_namespace = completion_inner_namespace == parent_namespace;

    SymbolFlags flags = SymbolFlags.NONE;
    if (is_instance)
    {
      flags |= SymbolFlags.INSTANCE;
    }
    if (is_same_type)
    {
      flags |= SymbolFlags.PRIVATE;
    }
    if (is_related_type)
    {
      flags |= SymbolFlags.PROTECTED;
    }
    if (is_same_namespace)
    {
      flags |= SymbolFlags.INTERNAL;
    }
    if (loginfo) info(@"Available symbols ($(flags)) ($(symbol_scope_to_string(completion_inner_type, flags)))");

    return get_extended_symbols(completion_inner_type, flags);
  }

  Vala.Symbol? find_completion_symbol(Vala.SourceFile file, string name)
  {
    var find_symbol = new FindSymbolByName(file, name);
    find_symbol.find();
    if (find_symbol.symbols.size == 0)
    {
      if (loginfo) info("Cannot find completion symbol");
      return null;
    }
    if (find_symbol.symbols.size > 1)
    {
      if (logwarn) warning("Multiple completion symbols");
      return null;
    }

    Gee.Iterator<Vala.Symbol> iterator = find_symbol.symbols.iterator();
    iterator.next();
    return iterator.get();
  }

  void filter_completion_symbols(Gee.Map<string, OrderedSymbol> symbols, string name)
  {
    string name_down = name.down();
    Gee.MapIterator<string, OrderedSymbol> iter = symbols.map_iterator();
    for (bool has_next = iter.next(); has_next; has_next = iter.next())
    {
      string symbol_name = iter.get_key();
      if (!symbol_name.down().has_prefix(name_down))
      {
        iter.unset();
      }
    }
  }
  
  /**
   * Enumerates every symbol reachable from the scope of 'node'.
   * Reachable symbols are filtered for visibility based on 'flags'.
   */
  Gee.Map<string, OrderedSymbol> find_global_symbols(Vala.CodeNode node, SymbolFlags flags = SymbolFlags.ALL)
  {
    var symbols = new Gee.TreeMap<string, OrderedSymbol>();
    add_global_symbols(node, symbols, flags, 0);
    if (node.source_reference != null && node.source_reference.using_directives != null)
    {
      foreach (Vala.UsingDirective using_directive in node.source_reference.using_directives)
      {
        if (using_directive.namespace_symbol != null)
        {
          if (logdebug) debug(@"Add symbols for using directive ($(using_directive.namespace_symbol.name))");
          add_scope_symbols(using_directive.namespace_symbol, symbols, flags, 1000);
        }
      }
    }
    return symbols;
  }

  /** Accumulates the global symbols starting from the scope of 'node' (recursively). */
  void add_global_symbols(Vala.CodeNode node, Gee.Map<string, OrderedSymbol> symbols, SymbolFlags flags, int order)
  {
    Vala.Symbol? symbol = node as Vala.Symbol;
    if (symbol != null)
    {
      add_scope_symbols(symbol, symbols, flags, order);
      var base_types = get_base_types(symbol);
      if (base_types != null)
      {
        foreach (Vala.Symbol base_type in base_types)
        {
          add_scope_symbols(base_type, symbols, flags & ~SymbolFlags.PRIVATE, order + 1);
        }
      }
    }
    Vala.CodeNode? parent_node = get_node_parent(node);
    if (parent_node != null)
    {
      add_global_symbols(parent_node, symbols, flags, order);
    }
  }

  /** Returns 'parent_node' or 'parent_symbol' (second choice) of 'node'. */
  Vala.CodeNode? get_node_parent(Vala.CodeNode node)
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

  /**
   * Enumerates every symbol reachable from the scope of 'symbol'.
   * Reachable symbols are filtered for visibility based on 'flags'.
   */
  Gee.Map<string, OrderedSymbol> get_extended_symbols(Vala.Symbol symbol, SymbolFlags flags = SymbolFlags.ALL)
  {
    var symbols = new Gee.TreeMap<string, OrderedSymbol>();
    add_scope_symbols(symbol, symbols, flags, 0);
    var base_types = get_base_types(symbol);
    if (base_types != null)
    {
      foreach (Vala.Symbol base_type in base_types)
      {
        add_scope_symbols(base_type, symbols, flags & ~SymbolFlags.PRIVATE, 1);
      }
    }
    return symbols;
  }

  /** Accumulates the symbols from the scope of 'symbol'. */
  void add_scope_symbols(Vala.Symbol symbol, Gee.Map<string, OrderedSymbol> symbols, SymbolFlags flags, int order)
  {
    Vala.Scope? scope = symbol.scope;
    if (scope == null)
    {
      return;
    }
    Vala.Map<string, Vala.Symbol> table = scope.get_symbol_table();
    if (table == null)
    {
      return;
    }
    Vala.MapIterator<string, Vala.Symbol> iter = table.map_iterator();
    for (bool has_next = iter.next(); has_next; has_next = iter.next())
    {
      string name = iter.get_key();
      Vala.Symbol scope_symbol = iter.get_value();
      if (symbol_is_instance_member(symbol, scope_symbol) && !(SymbolFlags.INSTANCE in flags))
      {
        continue;
      }
      if (scope_symbol.access == Vala.SymbolAccessibility.INTERNAL && !(SymbolFlags.INTERNAL in flags))
      {
        continue;
      }
      if (scope_symbol.access == Vala.SymbolAccessibility.PROTECTED && !(SymbolFlags.PROTECTED in flags))
      {
        continue;
      }
      if (scope_symbol.access == Vala.SymbolAccessibility.PRIVATE && !(SymbolFlags.PRIVATE in flags))
      {
        // For some reason, error codes are private (seems like a Vala bug but not sure)
        if (!(scope_symbol is Vala.ErrorCode))
        {
          continue;
        }
      }
      if (scope_symbol is Vala.CreationMethod && !(SymbolFlags.PRIVATE in flags))
      {
        continue;
      }
      if (is_hidden_symbol(scope_symbol))
      {
        continue;
      }
      if (symbols.has_key(name))
      {
        continue;
      }
      symbols.set(name, new OrderedSymbol()
      {
        symbol = scope_symbol, order = order
      });
    }
  }

  /** Returns true if 'symbol' is an instance member of 'parent_symbol'. */
  bool symbol_is_instance_member(Vala.Symbol parent_symbol, Vala.Symbol symbol)
  {
    if (parent_symbol is Vala.Namespace)
    {
      return false;
    }
    bool is_type_member = false;
    if (symbol is Vala.Field)
    {
      var f = (Vala.Field)symbol;
      is_type_member = (f.binding != Vala.MemberBinding.CLASS);
    }
    else if (symbol is Vala.Method)
    {
      var m = (Vala.Method)symbol;
      if (!(m is Vala.CreationMethod))
      {
        is_type_member = (m.binding != Vala.MemberBinding.CLASS);
      }
    }
    else if (symbol is Vala.Property)
    {
      var prop = (Vala.Property)symbol;
      is_type_member = (prop.binding != Vala.MemberBinding.CLASS);
    }
    return is_type_member;
  }

  /** Returns the ancestor type (root of the class/struct tree) of 'symbol'. */
  Vala.Symbol get_ancestor_type(Vala.Symbol? symbol)
  {
    Vala.Symbol? base_type = get_parent_type(symbol);
    return base_type == null ? symbol : get_ancestor_type(base_type);
  }

  /** Returns the parent type of 'symbol'. */
  Vala.Symbol? get_parent_type(Vala.Symbol? symbol)
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

  /** Returns the base types of 'symbol' (recursively). */
  Gee.ArrayList<Vala.Symbol> get_base_types(Vala.Symbol? symbol)
  {
    var base_types = new Gee.ArrayList<Vala.Symbol>();
    add_base_types(symbol, base_types);
    return base_types;
  }

  /** Adds the base types of 'symbol' to the list (recursively). */
  void add_base_types(Vala.Symbol? symbol, Gee.ArrayList<Vala.Symbol> base_type_symbols)
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
        base_type_symbols.add(base_type.data_type);
        add_base_types(base_type.data_type, base_type_symbols);
      }
    }
    else if (symbol is Vala.Struct)
    {
      Vala.Struct struct_node = (Vala.Struct)symbol;
      if (struct_node.base_type != null)
      {
        base_type_symbols.add(struct_node.base_type.data_type);
        add_base_types(struct_node.base_type.data_type, base_type_symbols);
      }
    }
    else if (symbol is Vala.Interface)
    {
      Vala.Interface interface_node = (Vala.Interface)symbol;
      Vala.List<Vala.DataType> prerequisites = interface_node.get_prerequisites();
      foreach (Vala.DataType prerequisite in prerequisites)
      {
        base_type_symbols.add(prerequisite.data_type);
        add_base_types(prerequisite.data_type, base_type_symbols);
      }
    }
  }

  /**
   * Returns the type symbol of the specified expression.
   * Also sets 'is_instance' based on whether the expression denotes an instance of the type or the type itself.
   */
  Vala.Symbol? get_expression_type(Vala.Expression expr, out bool? is_instance = null)
  {
    Vala.Symbol? symbol = expr.symbol_reference;
    if (symbol is Vala.TypeSymbol || symbol is Vala.Namespace)
    {
      // Expression references a symbol which is a static type or namespace (not an instance of a type)
      is_instance = false;
      return symbol;
    }
    Vala.Variable? variable = symbol as Vala.Variable;
    if (variable != null && variable.variable_type != null && variable.variable_type.data_type != null)
    {
      // Expression references a symbol which is an instance of a type
      is_instance = true;
      return variable.variable_type.data_type;
    }
    if (expr.value_type != null && expr.value_type.data_type != null)
    {
      // Expression does not reference a symbol but the compiler has been able to infer its type
      is_instance = true;
      return expr.value_type.data_type;
    }
    return null;
  }

  /** Returns the first parent node of 'node' which is of the specified type. */
  T? get_node_parent_of_type<T>(Vala.CodeNode? node)
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

  /** Returns a string representation for the children symbols of 'parent_symbol'. */
  string symbol_scope_to_string(Vala.Symbol parent_symbol, SymbolFlags flags = SymbolFlags.ALL)
  {
    var builder = new StringBuilder();
    builder.append("(");
    bool first = true;
    Gee.Map<string, OrderedSymbol> table = get_extended_symbols(parent_symbol, flags);
    Gee.MapIterator<string, OrderedSymbol> iter = table.map_iterator();
    for (bool has_next = iter.next(); has_next; has_next = iter.next())
    {
      string name = iter.get_key();
      Vala.Symbol symbol = iter.get_value().symbol;
      if (first)
      {
        first = false;
      }
      else
      {
        builder.append(", ");
      }
      builder.append(name);
      builder.append(" (");
      if (symbol_is_instance_member(parent_symbol, symbol))
      {
        builder.append("ins");
      }
      else
      {
        builder.append("typ");
      }
      if (symbol.access == Vala.SymbolAccessibility.PUBLIC)
      {
        builder.append("|pub");
      }
      else if (symbol.access == Vala.SymbolAccessibility.PROTECTED)
      {
        builder.append("|pro");
      }
      else if (symbol.access == Vala.SymbolAccessibility.PRIVATE)
      {
        builder.append("|pri");
      }
      else if (symbol.access == Vala.SymbolAccessibility.INTERNAL)
      {
        builder.append("|int");
      }
      builder.append(")");
    }
    builder.append(")");
    return builder.str;
  }

  SignatureHelp? last_signature_help = null;

  /** Returns the signature help to display the method declaration for a method call at the specified position (if found). */
  SignatureHelp? get_signature_help(Context context, SourceFile source_file, Position position)
  {
    uint line = position.line, character = position.character;
    int index = get_char_byte_index(source_file.content, line, character) - 1;
    string source = source_file.content;

    // Compute the signature help only once (VSCode calls it very often and it is expensive)
    if (source[index] != '(')
    {
      if (source[index] == ')')
      {
        last_signature_help = null;
      }
      return last_signature_help;
    }

    // Backtrack from the parenthesis to find the method name (hopefully)
    while (index >= 0 && source[index] != '\n' && !source[index].isalnum() && source[index] != '_')
    {
      character -= 1;
      index -= 1;
    }
    
    if (!source[index].isalnum() && source[index] != '_')
    {
      if (loginfo) info("Cannot backtrack to method name");
      return null;
    }

    string completion_member;
    Gee.Map<string, OrderedSymbol>? symbols = get_completion_symbols(context, source_file, line, character, out completion_member);

    if (symbols == null)
    {
      return null;
    }

    OrderedSymbol? ordered_symbol = symbols.get(completion_member);
    if (ordered_symbol == null)
    {
      if (logwarn) warning(@"Completion member is not in the completion symbols ($(completion_member))");
      return null;
    }

    Vala.Symbol completion_symbol = ordered_symbol.symbol;
    Vala.Method? completion_method = completion_symbol as Vala.Method;
    if (completion_method == null)
    {
      if (logwarn) warning(@"Completion symbol is not a method ($(code_node_to_string (completion_symbol)))");
      return null;
    }

    string code = get_symbol_definition_code_with_comment(completion_method);
    if (loginfo) info(@"Found symbol definition code ($(code))");

    var signature_information = new SignatureInformation();
    signature_information.label = @"$(completion_symbol.name)()";
    signature_information.documentation = new MarkupContent()
    {
      kind = MarkupContent.KIND_MARKDOWN,
      value = @"```vala\n$(code)\n```"
    };
    signature_information.parameters = new JsonArrayList<ParameterInformation>();
    Vala.List<Vala.Parameter> parameters = completion_method.get_parameters();

    var signature_help = new SignatureHelp();
    signature_help.signatures = new JsonArrayList<SignatureInformation>();
    signature_help.signatures.add(signature_information);
    signature_help.activeSignature = 0;

    last_signature_help = signature_help;

    return signature_help;
  }
}
