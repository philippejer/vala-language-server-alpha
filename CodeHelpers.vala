
bool code_node_is_inside(Vala.CodeNode node1, Vala.CodeNode node2)
{
  return node1.source_reference.begin.pos >= node2.source_reference.begin.pos &&
         node1.source_reference.end.pos <= node2.source_reference.end.pos;
}

bool code_node_matches(Vala.CodeNode node1, Vala.CodeNode node2)
{
  return node1.source_reference.begin.pos == node2.source_reference.begin.pos &&
         node1.source_reference.end.pos == node2.source_reference.end.pos;
}

string get_code_node_source(Vala.CodeNode node)
{
  if (node.source_reference == null)
  {
    return "";
  }
  return get_source_reference_source(node.source_reference);
}

string get_source_reference_source(Vala.SourceReference source_reference)
{
  char* begin = source_reference.begin.pos;
  char* end = source_reference.end.pos;
  return get_string_from_pointers(begin, end);
}

string get_string_from_pointers(char* begin, char* end)
{
  return ((string)begin).substring(0, (long)(end - begin));
}

char* find_token(char* begin, char* max, char token)
{
  char* pos = begin;
  while (pos < max)
  {
    if (pos[0] == token)
    {
      break;
    }
    pos += 1;
  }
  return pos == max ? null : pos;
}

string code_path_to_string(Vala.CodeNode? node)
{
  if (node == null)
  {
    return "(NULL[CodeNode])";
  }
  Vala.CodeNode? parent = get_node_parent(node);
  if (parent != null)
  {
    return code_scope_to_string(node) + "\n-> " + code_path_to_string(parent);
  }
  else
  {
    return code_scope_to_string(node);
  }
}

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

string code_node_to_string(Vala.CodeNode? node)
{
  if (node == null)
  {
    return "(NULL[CodeNode])";
  }
  var symbol = node as Vala.Symbol;
  if (symbol != null)
  {
    return @"$(symbol.name) ($(node.type_name)) ($(ptr_to_string (node))) ($(source_reference_to_string (node.source_reference)))";
  }
  else
  {
    return @"$(ptr_to_string (node)) ($(node.type_name)) ($(source_reference_to_string (node.source_reference)))";
  }
}

string code_scope_to_string(Vala.CodeNode? node)
{
  if (node == null)
  {
    return "(NULL[CodeNode])";
  }
  var symbol = node as  Vala.Symbol;
  if (symbol != null)
  {
    return @"$(symbol.name) ($(node.type_name)) ($(ptr_to_string (node))) ($(source_reference_to_string (node.source_reference))) $(symbol_scope_to_string (symbol))";
  }
  else
  {
    return @"$(ptr_to_string (node)) ($(node.type_name)) ($(source_reference_to_string (node.source_reference)))";
  }
}

string symbol_scope_to_string(Vala.Symbol parent_symbol, SymbolFlags flags = SymbolFlags.ALL)
{
  var builder = new StringBuilder();
  builder.append("(");
  bool first = true;
  Gee.Map<string, Vala.Symbol> table = get_extended_symbols(parent_symbol, flags);
  Gee.MapIterator<string, Vala.Symbol> iter = table.map_iterator();
  for (bool has_next = iter.next(); has_next; has_next = iter.next())
  {
    string name = iter.get_key();
    Vala.Symbol symbol = iter.get_value();
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
    if (symbol_is_type_member(parent_symbol, symbol))
    {
      builder.append("typ");
    }
    else
    {
      builder.append("ins");
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

Gee.Map<string, Vala.Symbol> get_global_symbols(Vala.CodeNode node, SymbolFlags flags = SymbolFlags.ALL)
{
  var symbols = new Gee.TreeMap<string, Vala.Symbol>();
  add_global_symbols(symbols, node, flags);
  if (node.source_reference != null && node.source_reference.using_directives != null)
  {
    foreach (Vala.UsingDirective using_directive in node.source_reference.using_directives)
    {
      if (using_directive.namespace_symbol != null)
      {
        if (logdebug) debug(@"Add symbols for using directive ($(using_directive.namespace_symbol.name))");
        add_scope_symbols(using_directive.namespace_symbol, symbols, flags);
      }
    }
  }
  return symbols;
}

void add_global_symbols(Gee.Map<string, Vala.Symbol> symbols, Vala.CodeNode node, SymbolFlags flags = SymbolFlags.ALL)
{
  Vala.Symbol? symbol = node as Vala.Symbol;
  if (symbol != null)
  {
    add_scope_symbols(symbol, symbols, flags);
    var base_types = get_base_types(symbol);
    if (base_types != null)
    {
      foreach (Vala.Symbol base_type in base_types)
      {
        add_scope_symbols(base_type, symbols, flags & ~SymbolFlags.PRIVATE);
      }
    }
  }
  Vala.CodeNode? parent_node = get_node_parent(node);
  if (parent_node != null)
  {
    add_global_symbols(symbols, parent_node, flags);
  }
}

Gee.Map<string, Vala.Symbol> get_extended_symbols(Vala.Symbol symbol, SymbolFlags flags = SymbolFlags.ALL)
{
  var symbols = new Gee.TreeMap<string, Vala.Symbol>();
  add_scope_symbols(symbol, symbols, flags);
  var base_types = get_base_types(symbol);
  if (base_types != null)
  {
    foreach (Vala.Symbol base_type in base_types)
    {
      add_scope_symbols(base_type, symbols, flags & ~SymbolFlags.PRIVATE);
    }
  }
  return symbols;
}

void add_scope_symbols(Vala.Symbol parent_symbol, Gee.Map<string, Vala.Symbol> symbols, SymbolFlags flags)
{
  Vala.Scope? scope = parent_symbol.scope;
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
    Vala.Symbol symbol = iter.get_value();
    if (!symbol_is_type_member(parent_symbol, symbol) && !(SymbolFlags.INSTANCE in flags))
    {
      continue;
    }
    if (symbol.access == Vala.SymbolAccessibility.INTERNAL && !(SymbolFlags.INTERNAL in flags))
    {
      continue;
    }
    if (symbol.access == Vala.SymbolAccessibility.PROTECTED && !(SymbolFlags.PROTECTED in flags))
    {
      continue;
    }
    if (symbol.access == Vala.SymbolAccessibility.PRIVATE && !(SymbolFlags.PRIVATE in flags))
    {
      continue;
    }
    if (symbol is Vala.CreationMethod && !(SymbolFlags.PRIVATE in flags))
    {
      continue;
    }
    if (is_hidden_symbol(symbol))
    {
      continue;
    }
    if (symbols.has_key(name))
    {
      continue;
    }
    symbols.set(name, symbol);
  }
}

bool symbol_is_type_member(Vala.Symbol parent_symbol, Vala.Symbol symbol)
{
  if (parent_symbol is Vala.Namespace)
  {
    return true;
  }
  bool is_type_member = true;
  if (symbol is Vala.Field)
  {
    var f = (Vala.Field)symbol;
    is_type_member = (f.binding == Vala.MemberBinding.CLASS);
  }
  else if (symbol is Vala.Method)
  {
    var m = (Vala.Method)symbol;
    if (!(m is Vala.CreationMethod))
    {
      is_type_member = (m.binding == Vala.MemberBinding.CLASS);
    }
  }
  else if (symbol is Vala.Property)
  {
    var prop = (Vala.Property)symbol;
    is_type_member = (prop.binding == Vala.MemberBinding.CLASS);
  }
  return is_type_member;
}

Vala.Symbol get_ancestor_type(Vala.Symbol? symbol)
{
  Vala.Symbol? base_type = get_base_type(symbol);
  return base_type == null ? symbol : get_ancestor_type(base_type);
}

Vala.Symbol? get_base_type(Vala.Symbol? symbol)
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

Gee.ArrayList<Vala.Symbol> get_base_types(Vala.Symbol? symbol)
{
  var base_types = new Gee.ArrayList<Vala.Symbol>();
  add_base_types(symbol, base_types);
  return base_types;
}

void add_base_types(Vala.Symbol? symbol, Gee.ArrayList<Vala.Symbol> base_type_symbols)
{
  if (symbol == null)
  {
    return;
  }
  int start_index = base_type_symbols.size;
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

Vala.Symbol? get_expression_type(Vala.Expression expr, out bool? is_instance)
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
  is_instance = false;
  return null;
}

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

string source_reference_to_string(Vala.SourceReference? source_reference)
{
  if (source_reference == null)
  {
    return "NULL (SourceReference)";
  }
  return @"$(source_reference.file.filename): $(source_reference.begin.line).$(source_reference.begin.column)::$(source_reference.end.line).$(source_reference.end.column)";
}

string get_symbol_definition_code(Vala.Symbol symbol)
{
  if (symbol is Vala.Subroutine)
  {
    return get_code_node_source_to_token(symbol, ')');
  }
  else if (symbol is Vala.LocalVariable)
  {
    Vala.LocalVariable variable = (Vala.LocalVariable)symbol;
    if (variable.variable_type != null)
    {
      if (logdebug) debug(@"Local variable type ($(code_node_to_string (variable.variable_type))), type symbol ($(code_node_to_string (variable.variable_type.data_type)))");
      if (variable.variable_type.data_type != null && variable.variable_type.data_type.name != null)
      {
        return variable.variable_type.data_type.name + " " + get_code_node_source(symbol);
      }
    }
    else
    {
      if (logdebug) debug(@"Local variable has no type ($(code_node_to_string (variable.variable_type)))");
    }
    return get_code_node_source(symbol);
  }
  else if (symbol is Vala.Variable)
  {
    Vala.Variable variable = (Vala.Variable)symbol;
    if (variable.variable_type != null)
    {
      if (logdebug) debug(@"Variable ($(code_node_to_string (variable))), type ($(code_node_to_string (variable.variable_type))), type symbol ($(code_node_to_string (variable.variable_type.data_type)))");
    }
    return get_code_node_source(symbol);
  }
  else
  {
    return get_code_node_source(symbol);
  }
}

string get_code_node_source_to_token(Vala.CodeNode node, char token)
{
  char* begin = node.source_reference.begin.pos;
  char* max = node.source_reference.file.get_mapped_contents() + node.source_reference.file.get_mapped_length();
  char* pos = find_token(begin, max, token);
  char* end = pos == null ? node.source_reference.end.pos : pos + 1;
  return get_string_from_pointers(begin, end);
}

Vala.Symbol? get_symbol_reference(Vala.CodeNode node)
{
  Vala.Symbol? symbol = null;
  if (node is Vala.Expression && !(node is Vala.Literal))
  {
    var expr = (Vala.Expression)node;
    if (expr.symbol_reference == null || expr.symbol_reference.source_reference == null)
    {
      if (logdebug) debug(@"Expression has no symbol reference ($(code_node_to_string (node)))");
    }
    else
    {
      symbol = expr.symbol_reference;
    }
  }
  else if (node is Vala.DelegateType)
  {
    symbol = ((Vala.DelegateType)node).delegate_symbol;
  }
  else if (node is Vala.DataType)
  {
    symbol = ((Vala.DataType)node).data_type;
  }
  else if (node is Vala.Symbol)
  {
    symbol = (Vala.Symbol)node;
  }
  if (symbol != null && is_hidden_symbol(symbol))
  {
    if (loginfo) info(@"Symbol is an hidden symbol ($(code_node_to_string (node)))");
    symbol = null;
  }
  return symbol;
}

bool is_hidden_symbol(Vala.Symbol symbol)
{
  return symbol.name == null || symbol.name.has_prefix(".");
}

Location source_reference_to_location(Vala.SourceReference source_reference)
{
  return new Location()
         {
           uri = Filename.to_uri(source_reference.file.filename),
           range = source_reference_to_range(source_reference)
         };
}

Range source_reference_to_range(Vala.SourceReference source_reference)
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

Location? get_identifier_location(Vala.CodeNode node, string identifier, bool strict)
{
  Vala.SourceReference source_reference = node.source_reference;
  if (source_reference == null)
  {
    warning(@"Node has no source reference ($(code_node_to_string (node)))");
    return null;
  }
  var location = source_reference_to_location(source_reference);
  string source = get_code_node_source(node);
  if (!find_identifier_location(location.range, source, identifier))
  {
    if (loginfo) info(@"Could not find identifier ($(source)) in source ($(identifier))");
    if (strict)
    {
      return null;
    }
  }
  return location;
}

bool find_identifier_location(Range range, string source, string identifier)
{
  int source_length = source.length;
  int identifier_length = identifier.length;
  uint line = range.start.line;
  uint character = range.start.character;
  int position = 0;
  int limit = source_length - identifier_length + 1;
  while (position < limit)
  {
    bool is_candidate = (position == 0 || !source[position - 1].isalnum()) && (position == (limit - 1) || !source[position + identifier_length].isalnum());
    if (is_candidate && are_equal_strings((char*)&source.data[position], (char*)identifier, identifier_length))
    {
      range.start.line = line;
      range.start.character = character;
      range.end.line = line;
      range.end.character = character + identifier_length;
      return true;
    }
    if (source[position] == '\n')
    {
      line += 1;
      character = 0;
    }
    else
    {
      character += 1;
    }
    position += 1;
  }
  return false;
}

bool are_equal_strings(char* s1, char* s2, int length)
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

void extend_ranges(Range refRange, Range inRange)
{
  if ((refRange.start.line > inRange.start.line) || (refRange.start.line == inRange.start.line && refRange.start.character > inRange.start.character))
  {
    refRange.start.line = inRange.start.line;
    refRange.start.character = inRange.start.character;
  }
  if ((refRange.end.line < inRange.end.line) || (refRange.end.line == inRange.end.line && refRange.end.character < inRange.end.character))
  {
    refRange.end.line = inRange.end.line;
    refRange.end.character = inRange.end.character;
  }
}
