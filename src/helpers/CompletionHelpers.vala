namespace Vls
{
  /** A symbol with an order (completion priority, lower is better). */
  public class OrderedSymbol
  {
    public string name;
    public CompletionItemKind kind;
    public Vala.Symbol? symbol;
    public int order;
  }

  public class CompletionHelpers
  {
    private const string completion_symbol_name = "__completion_symbol__";
    private const string completion_wildcard_name = "__completion_wildcard__";

    /** Returns the list of completions at the specified position. */
    public static CompletionList? get_completion_list(Context context, SourceFile source_file, Position position) throws Error
    {
      string? completion_member;
      int position_index;
      bool is_creation;
      Gee.Map<string, OrderedSymbol>? symbols = get_completion_symbols(context, source_file, position.line, position.character, out completion_member, out position_index, out is_creation);
      if (symbols == null)
      {
        return null;
      }

      int non_space_index = skip_source_spaces(source_file.content, position_index);
      bool is_before_paren = (source_file.content[non_space_index] == '(');

      JsonArrayList<CompletionItem> completion_items = new JsonArrayList<CompletionItem>();
      Gee.MapIterator<string, OrderedSymbol> iter = symbols.map_iterator();
      for (bool has_next = iter.next(); has_next; has_next = iter.next())
      {
        OrderedSymbol ordered_symbol = iter.get_value();
        if (ordered_symbol.kind == CompletionItemKind.Class)
        {
          if (is_creation)
          {
            // Only suggest the constructors
            add_completion_constructors(completion_items, ordered_symbol, is_before_paren);
          }
          else
          {
            // Only suggest the class
            CompletionItem completion_item = get_completion_item(ordered_symbol.name, ordered_symbol.kind, ordered_symbol.symbol, ordered_symbol.order, is_before_paren);
            completion_items.add(completion_item);
          }
        }
        else
        {
          // Default
          CompletionItem completion_item = get_completion_item(ordered_symbol.name, ordered_symbol.kind, ordered_symbol.symbol, ordered_symbol.order, is_before_paren);
          completion_items.add(completion_item);
          add_completion_constructors(completion_items, ordered_symbol, is_before_paren);
        }
      }

      return new CompletionList()
      {
        isIncomplete = false,
        items = completion_items
      };
    }

    private static void add_completion_constructors(JsonArrayList<CompletionItem> completion_items, OrderedSymbol ordered_symbol, bool is_before_paren)
    {
      // If the symbol is a class or a struct, also add the constructors as completion items
      Vala.Symbol? symbol = ordered_symbol.symbol;
      Vala.List<Vala.Method> methods;
      if (symbol is Vala.Class)
      {
        methods = ((Vala.Class)symbol).get_methods();
      }
      else if (symbol is Vala.Struct)
      {
        methods = ((Vala.Struct)symbol).get_methods();
      }
      else
      {
        return;
      }

      string? symbol_name = symbol.name;
      if (symbol_name == null)
      {
        return;
      }

      foreach (Vala.Method method in methods)
      {
        if (!(method is Vala.CreationMethod))
        {
          continue;
        }

        string? method_name = method.name;
        if (method_name == null)
        {
          continue;
        }

        string text = method.name == DEFAULT_CONSTRUCTOR_NAME ? symbol_name : @"$(symbol_name).$(method_name)";
        CompletionItem completion_item = get_completion_item(text, CompletionItemKind.Method, method, ordered_symbol.order, is_before_paren);
        completion_items.add(completion_item);
      }
    }

    private static CompletionItem get_completion_item(string text, CompletionItemKind kind, Vala.Symbol? symbol, int order, bool is_before_paren)
    {
      CompletionItem completion_item = new CompletionItem()
      {
        label = text,
        kind = kind
      };

      if (method_completion_mode != MethodCompletionMode.OFF && !is_before_paren
        && (kind == CompletionItemKind.Function || kind == CompletionItemKind.Method || kind == CompletionItemKind.Constructor))
      {
        string completion_space = method_completion_mode == MethodCompletionMode.SPACE ? " " : "";
        if (symbol is Vala.Callable)
        {
          Vala.List<Vala.Parameter> parameters = ((Vala.Callable)symbol).get_parameters();
          if (!parameters.is_empty)
          {
            completion_item.insertText = @"$(text)$(completion_space)($${0})";
            completion_item.command = new Command()
            {
              title = "Trigger Parameter Hints",
              command = "editor.action.triggerParameterHints"
            };
          }
          else
          {
            completion_item.insertText = @"$(text)$(completion_space)()";
          }
          completion_item.insertTextFormat = InsertTextFormat.Snippet;
        }
        else
        {
          completion_item.insertText = @"$(text)$(completion_space)(";
          completion_item.insertTextFormat = InsertTextFormat.PlainText;
        }
      }
      else
      {
        completion_item.insertText = text;
        completion_item.insertTextFormat = InsertTextFormat.PlainText;
      }

      completion_item.sortText = "%03d:%s".printf(order, text);

      string? code = symbol != null ? get_symbol_definition_code(symbol) : null;
      if (code != null)
      {
        completion_item.documentation = new MarkupContent()
        {
          kind = MarkupContent.KIND_MARKDOWN,
          value = @"```vala\n$(code)\n```"
        };
      }

      return completion_item;
    }

    /**
     * Returns the completion symbols at the specified position.
     * The general strategy is to:
     * 1. Backtrack from cursor to find something which looks like a Vala 'MemberAccess' expression (e.g. 'source_fil' or 'source_file.ope').
     * 2. Temporarily modify the source to comment the incomplete line (so that the parser does not choke) and insert a variable declaration of the form:
     *    'int __completion_symbol__ = [completion_expression];'
     * 3. Rebuild the syntax tree, find the '__completion_symbol__' node and inspect it to infer a list of proposals.
     */
    private static Gee.Map<string, OrderedSymbol>? get_completion_symbols(Context context, SourceFile source_file, uint line, uint character, out string? completion_member, out int position_index, out bool is_creation) throws Error
    {
      completion_member = null;

      string original_source = source_file.content;
      try
      {
        // Extract the completion expression
        position_index = get_char_byte_index(source_file.content, line, character);
        string completion_expression = extract_completion_expression(source_file.content, position_index);

        // Used to suggest constructors instead of class names if the expression is a creation
        if (completion_expression.has_prefix("new"))
        {
          is_creation = true;
          completion_expression = completion_expression.substring(3);
        }
        else
        {
          is_creation = false;
        }

        // Count the number of lines in the expression not including leading whitespace
        // (this is used to determine how many lines to slice below)
        completion_expression = completion_expression.chug();
        int num_lines = count_lines((char*)completion_expression, (char*)completion_expression + completion_expression.length);
        completion_expression = completion_expression.chomp();
        if (completion_expression.has_suffix(".") || completion_expression == "")
        {
          // Add a fake member name otherwise the parser will choke
          completion_expression += completion_wildcard_name;
        }

        if (loginfo) info(@"Completion expression: '$(completion_expression)' (num_lines: $(num_lines))");

        // Replace the lines containing the expression by a "generic" variable declaration which can be analyzed (more) easily
        int start_index = get_char_byte_index(source_file.content, line - num_lines + 1, 0);
        start_index = skip_source_spaces(source_file.content, start_index);
        int next_line_index = get_char_byte_index(source_file.content, line + 1, 0);
        string previous_str = source_file.content.slice(start_index, next_line_index - 1);
        string completion_str = @"int $(completion_symbol_name) = $(completion_expression);";
        if (previous_str.contains("{"))
        {
          // Hack to avoid the modified source not compiling because of unbalanced braces
          completion_str += "{";
        }
        source_file.content = source_file.content.splice(start_index, next_line_index - 1, completion_str);

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
     * Backtracks from 'start_index' to find something which looks like a Vala 'MemberAccess' expression.
     * Ugly hack, ideally the parser should be modified to help with this.
     */
    private static string extract_completion_expression(string source, int start_index)
    {
      int current = start_index - 1;
      int num_delimiters = 0;
      bool in_string = false;
      bool in_triple_string = false;
      char last_char = 0;
      char last_non_space_char = 0;

      while (current >= 0)
      {
        char c = source[current];
        if (!in_string)
        {
          if (c == '"')
          {
            // Consume any (triple) string
            in_string = true;
            if (current >= 2 && source[current - 1] == '"' && source[current - 2] == '"')
            {
              in_triple_string = true;
              current -= 2;
            }
          }
          else if ((last_non_space_char == '.' || num_delimiters > 0) && (c == ')' || c == ']'))
          {
            // Consume any delimited expression inside the inner expression
            num_delimiters += 1;
          }
          else if (num_delimiters > 0 && (c == '(' || c == '['))
          {
            num_delimiters -= 1;
          }
          else if (num_delimiters == 0 && !c.isspace() && !is_identifier_char(c) && c != '.' && c != '<' && c != '>')
          {
            // Stop when encountering a non-identifier symbol other than '.' (member access)
            break;
          }
          else if (num_delimiters == 0 && last_char.isspace() && last_non_space_char != '(' && last_non_space_char != '.' && is_identifier_char(c))
          {
            // Stop when encountering an identifier after a space (unless it looks like a method call or a member access)
            break;
          }

          last_char = c;
          if (!c.isspace())
          {
            last_non_space_char = c;
          }
        }
        else
        {
          // Try to detect the end of the string
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
        current -= 1;
      }

      // If the expression is preceded by the "new" keyword, include it
      if (current >= 2 && equal_strings((char*)source + current - 2, (char*)"new", 3))
      {
        current -= 3;
      }

      return source.slice(current + 1, start_index);
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
    private static Gee.Map<string, OrderedSymbol>? compute_completion_symbols(SourceFile source_file, out string? completion_member)
    {
      completion_member = null;

      unowned Vala.SourceFile? vala_file = source_file.vala_file;
      if (vala_file == null)
      {
        return null;
      }

      Vala.Symbol? completion_symbol = find_completion_symbol(vala_file, completion_symbol_name);
      if (completion_symbol == null)
      {
        return null;
      }

      unowned Vala.Variable? completion_variable = completion_symbol as Vala.Variable;
      if (completion_variable == null)
      {
        if (logwarn) warning("Completion symbol is not a variable");
        return null;
      }

      if (loginfo) info(@"Completion symbol: '$(code_scope_to_string(completion_variable))'");
      if (loginfo) info(@"Completion symbol initializer: '$(code_node_to_string(completion_variable.initializer))'");

      unowned Vala.MemberAccess? completion_initializer = completion_variable.initializer as Vala.MemberAccess;
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
      unowned Vala.Expression? completion_inner = completion_initializer.inner;
      if (completion_inner == null)
      {
        bool in_instance = parent_method != null && parent_method.binding == Vala.MemberBinding.INSTANCE;
        if (loginfo) info(@"No inner expression: returning global symbols (in instance: $(in_instance))");
        Gee.Map<string, OrderedSymbol> global_symbols = find_global_symbols(completion_variable, in_instance ? SymbolFlags.ALL : SymbolFlags.ALL_STATIC);
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
        if (completion_inner.value_type is Vala.ArrayType)
        {
          if (loginfo) info(@"Completion inner expression is array type");
          return get_array_completion_symbols((Vala.ArrayType)completion_inner.value_type);
        }
        else
        {
          return null;
        }
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
      FindSymbolByName finder = new FindSymbolByName(file, name);
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
    private static Gee.Map<string, OrderedSymbol> find_global_symbols(Vala.CodeNode node, SymbolFlags flags)
    {
      Gee.TreeMap<string, OrderedSymbol> symbols = new Gee.TreeMap<string, OrderedSymbol>();
      add_global_symbols(node, symbols, flags, 0);

      unowned Vala.SourceReference? source_reference = node.source_reference;
      if (source_reference != null)
      {
        foreach (Vala.UsingDirective using_directive in source_reference.using_directives)
        {
          if (logdebug) debug(@"Add symbols for using directive: '$(code_node_to_string(using_directive.namespace_symbol))'");
          add_scope_symbols(using_directive.namespace_symbol, symbols, flags, 1000);
        }
      }
      return symbols;
    }

    /** Accumulates the global symbols starting from the scope of 'node' (recursively). */
    private static void add_global_symbols(Vala.CodeNode node, Gee.Map<string, OrderedSymbol> symbols, SymbolFlags flags, int order)
    {
      unowned Vala.Symbol? symbol = node as Vala.Symbol;
      if (symbol != null)
      {
        add_scope_symbols(symbol, symbols, flags, order);

        Gee.ArrayList<Vala.Symbol> base_types = get_base_types(symbol);
        foreach (Vala.Symbol base_type in base_types)
        {
          add_scope_symbols(base_type, symbols, flags & ~SymbolFlags.PRIVATE, order + 1);
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
      Gee.TreeMap<string, OrderedSymbol> symbols = new Gee.TreeMap<string, OrderedSymbol>();
      add_scope_symbols(symbol, symbols, flags, 0);

      Gee.ArrayList<Vala.Symbol> base_types = get_base_types(symbol);
      foreach (Vala.Symbol base_type in base_types)
      {
        add_scope_symbols(base_type, symbols, flags & ~SymbolFlags.PRIVATE, 1);
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

      Vala.Map<string, Vala.Symbol>? table = scope.get_symbol_table();
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

        CompletionItemKind kind = get_completion_item_kind(scope_symbol);

        symbols.set(name, new OrderedSymbol()
        {
          name = name,
          kind = kind,
          symbol = scope_symbol,
          order = order
        });
      }
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
      if (symbol is Vala.Class)
      {
        return CompletionItemKind.Class;
      }
      if (symbol is Vala.Struct)
      {
        return CompletionItemKind.Struct;
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

    public static Gee.Map<string, OrderedSymbol> get_array_completion_symbols(Vala.ArrayType array_type)
    {
      Gee.HashMap<string, OrderedSymbol> symbols = new Gee.HashMap<string, OrderedSymbol>();
      add_fake_symbol(symbols, "length", CompletionItemKind.Field);
      add_fake_symbol(symbols, "copy", CompletionItemKind.Method);
      add_fake_symbol(symbols, "move", CompletionItemKind.Method);
      if (array_type.rank == 1)
      {
        // Only mono-dimensional arrays can be resized
        add_fake_symbol(symbols, "resize", CompletionItemKind.Method);
      }
      return symbols;
    }

    private static void add_fake_symbol(Gee.Map<string, OrderedSymbol> symbols, string name, CompletionItemKind kind)
    {
      symbols.set(name, new OrderedSymbol()
      {
        name = name,
        kind = kind,
        symbol = null,
        order = 0
      });
    }

    /** Returns a verbose repesentation of 'node' (if 'node' is a symbol its children are enumerated). */
    public static string code_scope_to_string(Vala.CodeNode? node)
    {
      if (node == null)
      {
        return "null (CodeNode)";
      }

      unowned Vala.Symbol? symbol = node as Vala.Symbol;
      if (symbol != null)
      {
        return @"name: '$(symbol.name ?? "[unnamed symbol]")', type: '$(node.type_name)', source: '$(source_reference_to_string(node.source_reference))', scope: '$(symbol_scope_to_string(symbol))'";
      }
      else
      {
        return @"name: (not a symbol)', type: '$(node.type_name)', source: '$(source_reference_to_string(node.source_reference))'";
      }
    }

    /** Returns a string representation for the children symbols of 'parent_symbol'. */
    private static string symbol_scope_to_string(Vala.Symbol parent_symbol, SymbolFlags flags = SymbolFlags.ALL)
    {
      StringBuilder builder = new StringBuilder();

      Gee.Map<string, OrderedSymbol> table = get_extended_symbols(parent_symbol, flags);
      Gee.MapIterator<string, OrderedSymbol> iter = table.map_iterator();

      bool first = true;
      builder.append("(");
      for (bool has_next = iter.next(); has_next; has_next = iter.next())
      {
        OrderedSymbol ordered_symbol = iter.get_value();
        unowned Vala.Symbol? symbol = ordered_symbol.symbol;
        unowned string name = ordered_symbol.name;

        if (first)
        {
          first = false;
        }
        else
        {
          builder.append(", ");
        }

        builder.append(name);
        if (symbol != null)
        {
          builder.append(" (");
          if (symbol_is_instance_member(symbol))
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
      }
      builder.append(")");

      return builder.str;
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
      do
      {
        character -= 1;
        index -= 1;
      }
      while (index >= 0 && source[index].isspace());

      string? completion_member;
      int position_index;
      bool is_creation;
      Gee.Map<string, OrderedSymbol>? symbols = get_completion_symbols(context, source_file, line, character, out completion_member, out position_index, out is_creation);
      if (symbols == null || completion_member == null)
      {
        return null;
      }

      OrderedSymbol? ordered_symbol = symbols.get(completion_member);
      if (ordered_symbol == null)
      {
        if (logwarn) warning(@"Completion member '$(completion_member)' is not in the completion symbols");
        return null;
      }

      unowned string name = ordered_symbol.name;
      unowned Vala.Symbol? symbol = ordered_symbol.symbol;
      if (symbol == null)
      {
        // "Fake" symbol (arrays)
        return null;
      }

      // Special case for default constructors
      Vala.CreationMethod? default_constructor = null;
      if (is_creation && symbol is Vala.Class)
      {
        default_constructor = ((Vala.Class)symbol).default_construction_method;
      }
      else if (symbol is Vala.Struct)
      {
        default_constructor = ((Vala.Struct)symbol).default_construction_method;
      }
      if (default_constructor != null)
      {
        symbol = default_constructor;
      }

      unowned Vala.Method? method = symbol as Vala.Method;
      if (method == null)
      {
        if (loginfo) info(@"Completion symbol is not a valid method: '$(code_node_to_string(symbol))'");
        return null;
      }

      string? definition_code = get_symbol_definition_code_with_comment(method);
      if (definition_code == null)
      {
        return null;
      }
      if (loginfo) info(@"Found symbol definition code: '$(definition_code)'");

      SignatureInformation signature_information = new SignatureInformation();
      signature_information.label = @"$(name)()";
      signature_information.documentation = new MarkupContent()
      {
        kind = MarkupContent.KIND_MARKDOWN,
        value = @"```vala\n$(definition_code)\n```"
      };
      signature_information.parameters = new JsonArrayList<ParameterInformation>();

      SignatureHelp signature_help = new SignatureHelp();
      signature_help.signatures = new JsonArrayList<SignatureInformation>();
      signature_help.signatures.add(signature_information);
      signature_help.activeSignature = 0;

      last_signature_help = signature_help;

      return signature_help;
    }

    /** Finds the first non-space character from 'index' in 'source'. */
    private static int skip_source_spaces(string source, int index)
    {
      int length = source.length;
      while (index < length && source[index].isspace())
      {
        index += 1;
      }
      return index == length ? length - 1 : index;
    }
  }
}
