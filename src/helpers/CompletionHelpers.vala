namespace Vls
{
  /** A symbol with an order (completion priority, lower is better). */
  public class OrderedSymbol
  {
    public Vala.Symbol symbol { get; set; }
    public int order { get; set; }
  }

  public class CompletionHelpers
  {
    private const string completion_symbol_name = "__completion_symbol__";
    private const string completion_wildcard_name = "__completion_wildcard__";

    /** Returns the list of completions at the specified position. */
    public static CompletionList? get_completion_list(Context context, SourceFile source_file, Position position) throws Error
    {
      string completion_member;
      int position_index;
      Gee.Map<string, OrderedSymbol>? symbols = get_completion_symbols(context, source_file, position.line, position.character, out completion_member, out position_index);
      if (symbols == null)
      {
        return null;
      }

      int non_space_index = skip_source_spaces(source_file.content, position_index);
      bool is_before_paren = source_file.content[non_space_index] == '(';
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
        if (method_completion_mode != MethodCompletionMode.OFF && !is_before_paren && (symbol is Vala.Callable))
        {
          completion_item.insertTextFormat = InsertTextFormat.Snippet;
          string completion_space = method_completion_mode == MethodCompletionMode.SPACE ? " " : "";
          Vala.List<Vala.Parameter> parameters = ((Vala.Callable)symbol).get_parameters();
          if (!parameters.is_empty)
          {
            completion_item.insertText = @"$(name)$(completion_space)($${0})";
            completion_item.command = new Command()
            {
              title = "Trigger Parameter Hints",
              command = "editor.action.triggerParameterHints"
            };
          }
          else
          {
            completion_item.insertText = @"$(name)$(completion_space)()";
          }
        }
        else
        {
          completion_item.insertText = name;
          completion_item.insertTextFormat = InsertTextFormat.PlainText;
        }
        completion_item.kind = get_completion_item_kind(symbol);
        completion_items.add(completion_item);
      }

      return new CompletionList()
      {
        isIncomplete = false,
        items = completion_items
      };
    }

    private static CompletionItemKind get_completion_item_kind(Vala.Symbol symbol)
    {
      if (symbol is Vala.Field)
      {
        return CompletionItemKind.Field;
      }
      if (symbol is Vala.Property)
      {
        return CompletionItemKind.Property;
      }
      if (symbol is Vala.Variable || symbol is Vala.Parameter)
      {
        return CompletionItemKind.Variable;
      }
      if (symbol is Vala.Method)
      {
        return CompletionItemKind.Method;
      }
      if (symbol is Vala.Delegate)
      {
        return CompletionItemKind.Method;
      }
      if (symbol is Vala.Class || symbol is Vala.Struct)
      {
        return CompletionItemKind.Class;
      }
      if (symbol is Vala.Enum || symbol is Vala.ErrorDomain)
      {
        return CompletionItemKind.Enum;
      }
      if (symbol is Vala.EnumValue || symbol is Vala.ErrorCode)
      {
        return CompletionItemKind.EnumMember;
      }
      if (symbol is Vala.Interface)
      {
        return CompletionItemKind.Interface;
      }
      if (symbol is Vala.Namespace)
      {
        return CompletionItemKind.Module;
      }
      if (symbol is Vala.Constant)
      {
        return CompletionItemKind.Constant;
      }
      if (symbol is Vala.Signal)
      {
        return CompletionItemKind.Event;
      }
      return CompletionItemKind.Text;
    }

    /**
     * Returns the completion symbols at the specified position.
     * The general strategy is to:
     * 1. Backtrack from cursor to find something which looks like a Vala 'MemberAccess' expression (e.g. 'source_fil' or 'source_file.ope').
     * 2. Temporarily modify the source to comment the incomplete line (so that the parser does not choke) and insert a variable declaration of the form:
     *    'int __completion_symbol__ = [completion_expression];'
     * 3. Rebuild the syntax tree, find the '__completion_symbol__' node and inspect it to infer a list of proposals.
     */
    private static Gee.Map<string, OrderedSymbol>? get_completion_symbols(Context context, SourceFile source_file, uint line, uint character, out string completion_member, out int position_index) throws Error
    {
      completion_member = null;
      string original_source = source_file.content;
      try
      {
        // Extract the completion expression
        position_index = get_char_byte_index(source_file.content, line, character);
        string completion_expression = extract_completion_expression(source_file.content, position_index);
        if (completion_expression.has_suffix(".") || completion_expression == "")
        {
          completion_expression += completion_wildcard_name;
        }
        if (loginfo) info(@"Completion expression: '$(completion_expression)'");

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
    private static string extract_completion_expression(string source, int index)
    {
      int current = index - 1;
      int num_delimiters = 0;
      bool in_string = false;
      bool in_triple_string = false;
      char last_char = 0;
      char last_non_space_char = 0;
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
          else if ((last_non_space_char == '.' || num_delimiters > 0) && (c == ')' || c == ']'))
          {
            num_delimiters += 1;
          }
          else if (num_delimiters > 0 && (c == '(' || c == '['))
          {
            num_delimiters -= 1;
          }
          else if (num_delimiters == 0 && !c.isspace() && !is_identifier_char(c) && c != '.')
          {
            break;
          }
          else if (num_delimiters == 0 && last_char.isspace() && last_non_space_char != '(' && is_identifier_char(c))
          {
            break;
          }
          last_char = c;
          if (!c.isspace())
          {
            last_non_space_char = c;
          }
        }
        current -= 1;
      }
      return source.slice(current + 1, index).strip();
    }

    public static void test_extract_completion_expression()
    {
      Test.add_func("/CompletionHelpers/extract_completion_expression/1", () =>
        test_equal_strings("foo.ba", extract_completion_expression("some_method(foo.ba", "some_method(foo.ba".length)));
      Test.add_func("/CompletionHelpers/extract_completion_expression/2", () =>
        test_equal_strings("debu", extract_completion_expression("() debu", "() debu".length)));
      Test.add_func("/CompletionHelpers/extract_completion_expression/3", () =>
        test_equal_strings("(a + b).complete_me", extract_completion_expression(", (a + b).complete_me", ", (a + b).complete_me".length)));
      Test.add_func("/CompletionHelpers/extract_completion_expression/4", () =>
        test_equal_strings("complete_me", extract_completion_expression(", (a + b)complete_me", ", (a + b)complete_me".length)));
      Test.add_func("/CompletionHelpers/extract_completion_expression/5", () =>
        test_equal_strings("some_method(foo.bar).baz", extract_completion_expression("something + some_method(foo.bar).baz", "something + some_method(foo.bar).baz".length)));
      Test.add_func("/CompletionHelpers/extract_completion_expression/6", () =>
        test_equal_strings("some_method (foo.bar).baz", extract_completion_expression("something + some_method (foo.bar).baz", "something + some_method (foo.bar).baz".length)));
      Test.add_func("/CompletionHelpers/extract_completion_expression/7", () =>
          test_equal_strings("some_method (foo.bar).@baz", extract_completion_expression("something + some_method (foo.bar).@baz", "something + some_method (foo.bar).@baz".length)));
    }

    /**
     * Finds the inserted 'int __completion_symbol__ = [completion_expression];' variable declaration and inspect it to determine a list of completions.
     */
    private static Gee.Map<string, OrderedSymbol>? compute_completion_symbols(SourceFile source_file, out string completion_member)
    {
      completion_member = null;
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

      if (loginfo) info(@"Completion symbol: '$(code_scope_to_string(completion_variable))'");
      if (loginfo) info(@"Completion symbol initializer: '$(code_node_to_string(completion_variable.initializer))'");

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
      if (loginfo) info(@"Completion symbol parent type: '$(code_scope_to_string(parent_type))'");
      if (loginfo) info(@"Completion symbol ancestor type: '$(code_scope_to_string(parent_ancestor_type))'");
      if (loginfo) info(@"Completion symbol parent method: '$(code_scope_to_string(parent_method))'");
      if (loginfo) info(@"Completion symbol parent namespace: '$(code_scope_to_string(parent_namespace))'");

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
      if (loginfo) info(@"Completion inner expression: '$(code_scope_to_string(completion_inner))'");

      bool is_instance;
      Vala.Symbol? completion_inner_type = get_expression_type(completion_inner, out is_instance);
      if (completion_inner_type == null)
      {
        if (loginfo) info(@"Completion inner expression has no type: '$(code_scope_to_string(completion_inner))'");
        return null;
      }
      if (loginfo) info(@"Completion inner expression type: '$(is_instance ? "instance" : "class")' ($(code_scope_to_string(completion_inner_type))'");

      Vala.Symbol? completion_inner_ancestor_type = get_ancestor_type(completion_inner_type);
      if (loginfo) info(@"Completion inner expression ancestor type: '$(code_scope_to_string(completion_inner_ancestor_type))'");

      Vala.Namespace? completion_inner_namespace = get_node_parent_of_type<Vala.Namespace>(completion_inner_type);
      if (loginfo) info(@"Completion inner expression namespace: '$(code_scope_to_string(completion_inner_namespace))'");

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
      if (loginfo) info(@"Available symbols for flags $(flags): '$(symbol_scope_to_string(completion_inner_type, flags))'");

      return get_extended_symbols(completion_inner_type, flags);
    }

    private static Vala.Symbol? find_completion_symbol(Vala.SourceFile file, string name)
    {
      var finder = new FindSymbolByName(file, name);
      finder.find();
      if (finder.symbols.is_empty)
      {
        if (loginfo) info("Cannot find completion symbol");
        return null;
      }
      if (finder.symbols.size > 1)
      {
        if (logwarn) warning("Multiple completion symbols");
        return null;
      }

      Gee.Iterator<Vala.Symbol> iterator = finder.symbols.iterator();
      iterator.next();
      return iterator.get();
    }

    private static void filter_completion_symbols(Gee.Map<string, OrderedSymbol> symbols, string name)
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
    private static Gee.Map<string, OrderedSymbol> find_global_symbols(Vala.CodeNode node, SymbolFlags flags = SymbolFlags.ALL)
    {
      var symbols = new Gee.TreeMap<string, OrderedSymbol>();
      add_global_symbols(node, symbols, flags, 0);
      if (node.source_reference != null && node.source_reference.using_directives != null)
      {
        foreach (Vala.UsingDirective using_directive in node.source_reference.using_directives)
        {
          if (using_directive.namespace_symbol != null)
          {
            if (logdebug) debug(@"Add symbols for using directive: '$(using_directive.namespace_symbol.name)'");
            add_scope_symbols(using_directive.namespace_symbol, symbols, flags, 1000);
          }
        }
      }
      return symbols;
    }

    /** Accumulates the global symbols starting from the scope of 'node' (recursively). */
    private static void add_global_symbols(Vala.CodeNode node, Gee.Map<string, OrderedSymbol> symbols, SymbolFlags flags, int order)
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

    /**
     * Enumerates every symbol reachable from the scope of 'symbol'.
     * Reachable symbols are filtered for visibility based on 'flags'.
     */
    private static Gee.Map<string, OrderedSymbol> get_extended_symbols(Vala.Symbol symbol, SymbolFlags flags = SymbolFlags.ALL)
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
    private static void add_scope_symbols(Vala.Symbol symbol, Gee.Map<string, OrderedSymbol> symbols, SymbolFlags flags, int order)
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
        if (!is_symbol_compatible_with_flags(scope_symbol, flags))
        {
          continue;
        }
        if (is_hidden_symbol(scope_symbol, true))
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

    /** Returns the ancestor type (root of the class/struct tree) of 'symbol'. */
    private static Vala.Symbol get_ancestor_type(Vala.Symbol? symbol)
    {
      Vala.Symbol? base_type = get_parent_type(symbol);
      return base_type == null ? symbol : get_ancestor_type(base_type);
    }

    /** Returns the parent type of 'symbol'. */
    private static Vala.Symbol? get_parent_type(Vala.Symbol? symbol)
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
    private static Vala.Symbol? get_expression_type(Vala.Expression expr, out bool is_instance)
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

    /** Returns a verbose repesentation of 'node' (if 'node' is a symbol its children are enumerated). */
    public static string code_scope_to_string(Vala.CodeNode? node)
    {
      if (node == null)
      {
        return "(NULL[CodeNode])";
      }
      var symbol = node as Vala.Symbol;
      if (symbol != null)
      {
        return @"name: '$(symbol.name ?? "[unnamed symbol]")', type: '$(node.type_name)', source: '$(source_reference_to_string(node.source_reference))', scope: '$(symbol_scope_to_string(symbol))'";
      }
      else
      {
        return @"name: [not a symbol]', type: '$(node.type_name)', source: '$(source_reference_to_string(node.source_reference))'";
      }
    }

    /** Returns a string representation for the children symbols of 'parent_symbol'. */
    private static string symbol_scope_to_string(Vala.Symbol parent_symbol, SymbolFlags flags = SymbolFlags.ALL)
    {
      var builder = new StringBuilder();
      builder.append("(");
      bool first = true;
      Gee.Map<string, OrderedSymbol> table = get_extended_symbols(parent_symbol, flags);
      Gee.MapIterator<string, OrderedSymbol> iter = table.map_iterator();
      for (bool has_next = iter.next(); has_next; has_next = iter.next())
      {
        Vala.Symbol symbol = iter.get_value().symbol;
        if (first)
        {
          first = false;
        }
        else
        {
          builder.append(", ");
        }
        builder.append(symbol_to_string_extended(symbol));
      }
      builder.append(")");
      return builder.str;
    }

    private static string symbol_to_string_extended(Vala.Symbol symbol)
    {
      string name = symbol.name;
      string result = name + " (";
      if (symbol_is_instance_member(symbol))
      {
        result += "ins";
      }
      else
      {
        result += "typ";
      }
      if (symbol.access == Vala.SymbolAccessibility.PUBLIC)
      {
        result += "|pub";
      }
      else if (symbol.access == Vala.SymbolAccessibility.PROTECTED)
      {
        result += "|pro";
      }
      else if (symbol.access == Vala.SymbolAccessibility.PRIVATE)
      {
        result += "|pri";
      }
      else if (symbol.access == Vala.SymbolAccessibility.INTERNAL)
      {
        result += "|int";
      }
      result += ")";
      return result;
    }

    private static SignatureHelp? last_signature_help = null;

    /** Returns the signature help to display the method declaration for a method call at the specified position (if found). */
    public static SignatureHelp? get_signature_help(Context context, SourceFile source_file, Position position) throws Error
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
      int position_index;
      Gee.Map<string, OrderedSymbol>? symbols = get_completion_symbols(context, source_file, line, character, out completion_member, out position_index);
      if (symbols == null)
      {
        return null;
      }

      OrderedSymbol? ordered_symbol = symbols.get(completion_member);
      if (ordered_symbol == null)
      {
        if (logwarn) warning(@"Completion member '$(completion_member)' is not in the completion symbols");
        return null;
      }

      Vala.Symbol completion_symbol = ordered_symbol.symbol;
      Vala.Method? completion_method = completion_symbol as Vala.Method;
      if (completion_method == null)
      {
        if (logwarn) warning(@"Completion symbol is not a method: '$(code_node_to_string(completion_symbol))'");
        return null;
      }

      string definition_code = get_symbol_definition_code_with_comment(completion_method);
      if (loginfo) info(@"Found symbol definition code: '$(definition_code)'");

      var signature_information = new SignatureInformation();
      signature_information.label = @"$(completion_symbol.name)()";
      signature_information.documentation = new MarkupContent()
      {
        kind = MarkupContent.KIND_MARKDOWN,
        value = @"```vala\n$(definition_code)\n```"
      };
      signature_information.parameters = new JsonArrayList<ParameterInformation>();

      var signature_help = new SignatureHelp();
      signature_help.signatures = new JsonArrayList<SignatureInformation>();
      signature_help.signatures.add(signature_information);
      signature_help.activeSignature = 0;

      last_signature_help = signature_help;

      return signature_help;
    }

    /** Finds the first non-space and non-newline character from 'index' in 'source'. */
    private static int skip_source_spaces(string source, int index)
    {
      int length = source.length;
      while (index < length && source[index].isspace() && source[index] != '\n')
      {
        index += 1;
      }
      return index == length ? length - 1 : index;
    }
  }
}
