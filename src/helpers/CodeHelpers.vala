
namespace Vls
{
  /** Returns true if 'node1' is inside 'node2'. */
  bool code_node_is_inside(Vala.CodeNode node1, Vala.CodeNode node2)
  {
    return node1.source_reference.begin.pos >= node2.source_reference.begin.pos &&
           node1.source_reference.end.pos <= node2.source_reference.end.pos;
  }

  /** Returns true if 'node1' and 'node2' reference the same source. */
  bool code_node_matches(Vala.CodeNode node1, Vala.CodeNode node2)
  {
    return node1.source_reference.begin.pos == node2.source_reference.begin.pos &&
           node1.source_reference.end.pos == node2.source_reference.end.pos;
  }

  /** Returns the source code for 'node'. */
  string get_code_node_source(Vala.CodeNode node)
  {
    if (node.source_reference == null)
    {
      return "";
    }
    return get_source_reference_source(node.source_reference);
  }

  /** Returns the source code for 'source_reference'. */
  string get_source_reference_source(Vala.SourceReference source_reference)
  {
    char* begin = source_reference.begin.pos;
    char* end = source_reference.end.pos;
    return get_string_from_pointers(begin, end);
  }

  /** Extracts the substring between 'begin' and 'end'. */
  string get_string_from_pointers(char* begin, char* end)
  {
    return ((string)begin).substring(0, (long)(end - begin));
  }

  /** Searches for one of 'tokens' between 'begin' and 'max' ('max' excluded from search). */
  char* find_tokens(char* begin, char* max, char[] tokens)
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
  char* find_token_reverse(char* begin, char* min, char[] tokens)
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

  bool is_one_of_tokens(char c, char[] tokens)
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
  string code_node_to_string(Vala.CodeNode? node)
  {
    if (node == null)
    {
      return "(NULL[CodeNode])";
    }
    var symbol = node as Vala.Symbol;
    if (symbol != null && symbol.name != null)
    {
      return @"$(symbol.name) ($(node.type_name)) ($(source_reference_to_string(node.source_reference)))";
    }
    else
    {
      return @"[unnamed] ($(node.type_name)) ($(source_reference_to_string(node.source_reference)))";
    }
  }

  /** Returns a verbose repesentation of 'node' (if 'node' is a symbol its children are enumerated). */
  string code_scope_to_string(Vala.CodeNode? node)
  {
    if (node == null)
    {
      return "(NULL[CodeNode])";
    }
    var symbol = node as Vala.Symbol;
    if (symbol != null && symbol.name != null)
    {
      return @"$(symbol.name) ($(node.type_name)) ($(source_reference_to_string(node.source_reference))) $(symbol_scope_to_string(symbol))";
    }
    else
    {
      return @"[unnamed] ($(node.type_name)) ($(source_reference_to_string(node.source_reference)))";
    }
  }

  /** Convert a 'SourceReference' to string for debugging. */
  string source_reference_to_string(Vala.SourceReference? source_reference)
  {
    if (source_reference == null)
    {
      return "NULL (SourceReference)";
    }
    return @"$(source_reference.file.filename): $(source_reference.begin.line).$(source_reference.begin.column)::$(source_reference.end.line).$(source_reference.end.column)";
  }

  /** Returns the definition of 'symbol' from the source code (with the parent symbol and comment if any).  */
  string get_symbol_definition_code_with_comment(Vala.Symbol symbol)
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
  string get_symbol_definition_code(Vala.Symbol symbol)
  {
    string source = get_symbol_definition_source(symbol);

    // Add the parent symbol name for context (hack-ish but simple)
    Vala.Symbol? parent_symbol = symbol.parent_symbol;
    if (parent_symbol != null && parent_symbol.name != null)
    {
      source = @"[$(parent_symbol.name)] $(source)";
    }

    // Flatten the string otherwise display is mangled (at least in VSCode)
    return remove_extra_spaces(source);
  }

  /** Removes consecutive spaces and replaces newline by space to make a snippet suitable for one-line display (e.g. document outline). */
  string remove_extra_spaces(string input)
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
  string get_symbol_definition_source(Vala.Symbol symbol)
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
        if (logdebug) debug(@"Local variable type ($(code_node_to_string(variable.variable_type))), type symbol ($(code_node_to_string(variable.variable_type.data_type)))");
        if (variable.variable_type.data_type != null && variable.variable_type.data_type.name != null)
        {
          return variable.variable_type.data_type.name + " " + get_code_node_source(symbol);
        }
      }
      else
      {
        if (logdebug) debug(@"Local variable has no type ($(code_node_to_string(variable.variable_type)))");
      }
      return get_code_node_source(symbol);
    }
    else if (symbol is Vala.Variable)
    {
      Vala.Variable variable = (Vala.Variable)symbol;
      if (variable.variable_type != null)
      {
        if (logdebug) debug(@"Variable ($(code_node_to_string(variable))), type ($(code_node_to_string(variable.variable_type))), type symbol ($(code_node_to_string(variable.variable_type.data_type)))");
      }
      return get_code_node_source(symbol);
    }
    else
    {
      return get_code_node_source(symbol);
    }
  }

  /** Returns the source code of 'method' including the parameters (Vala currently does not include the parameters in the source reference). */
  string get_method_declaration_source(Vala.Subroutine method)
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
  char* find_text_between_parens(char* begin, char* max)
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

  /** Returns the symbol referenced by 'node' (if any). */
  Vala.Symbol? get_referenced_symbol(Vala.CodeNode node)
  {
    Vala.Symbol? symbol = null;
    if (node is Vala.Expression && !(node is Vala.Literal))
    {
      var expr = (Vala.Expression)node;
      if (expr.symbol_reference == null || expr.symbol_reference.source_reference == null)
      {
        if (logdebug) debug(@"Expression has no symbol reference ($(code_node_to_string(node)))");
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
      if (logdebug) debug(@"Symbol is an hidden symbol ($(code_node_to_string(node)))");
      return null;
    }
    return symbol;
  }

  /** Returns true if the symbol is an hidden compiler-generated symbol. */
  bool is_hidden_symbol(Vala.Symbol symbol)
  {
    return symbol.name == null || symbol.name.has_prefix(".");
  }

  /** Converts a 'SourceReference' to a 'Location'. */
  Location source_reference_to_location(Vala.SourceReference source_reference) throws Error
  {     
    return new Location()
    {
      uri = Filename.to_uri(source_reference.file.filename),
      range = source_reference_to_range(source_reference)
    };
  }

  /** Converts a 'SourceReference' to a 'Range'. */
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

  /** 
   * Searches for 'identifier' as a "whole word" inside the source of 'node' and returns the location of that identifier.
   * If 'strict' is not set, the location of 'node' is returned if the identifier could not be found (should not happen normally).
   */
  Location? get_identifier_location(Vala.CodeNode node, string identifier, bool strict) throws Error
  {
    if (node.source_reference == null)
    {
      if (logwarn) warning(@"Node has no source reference ($(code_node_to_string(node)))");
      return null;
    }
    Location location = source_reference_to_location(node.source_reference);
    string source = get_code_node_source(node);
    if (!find_identifier_range(location.range, source, identifier))
    {
      if (loginfo) info(@"Could not find identifier ($(identifier)) in source ($(source))");
      if (strict)
      {
        return null;
      }
    }
    return location;
  }

  /**
   * Searches for 'identifier' as a "whole word" inside 'source' and updates 'range' accordingly if the identifier is found.
   * Returns true if 'identifier' is found inside 'source'.
   */
  bool find_identifier_range(Range range, string source, string identifier)
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
  void extend_ranges(Range ref_range, Range in_range)
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
  private int get_char_byte_index(string text, uint position_line, uint position_character)
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

  /** Finds the first non-space non-newline character from 'index' in 'source'. */
  int skip_source_spaces(string source, int index)
  {
    while (source[index].isspace() && source[index] != '\n')
    {
      index += 1;
    }
    return index;
  }

  /** Check C-strings for equality. */
  bool equal_strings(char* s1, char* s2, int length)
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

  bool is_identifier_char(char c)
  {
    return c.isalnum() || c == '_' || c == '@';
  }
}
