namespace Vls
{
  public class DocumentSymbolHelpers
  {
    public static JsonSerializableCollection<DocumentSymbol>? get_document_symbols(SourceFile source_file) throws Error
    {
      Gee.Set<Vala.Symbol>? symbols = find_symbols_in_file(source_file);
      if (symbols == null)
      {
        return null;
      }

      Gee.HashMap<Vala.Symbol, DocumentSymbol> document_symbol_map = new Gee.HashMap<Vala.Symbol, DocumentSymbol>();
      foreach (Vala.Symbol symbol in symbols)
      {
        add_document_symbol_to_map(symbol, document_symbol_map);
      }

      JsonSerializableCollection<DocumentSymbol>? document_symbols = null;
      foreach (Gee.Map.Entry<Vala.Symbol, DocumentSymbol> entry in document_symbol_map.entries)
      {
        unowned Vala.Symbol symbol = entry.key;
        unowned DocumentSymbol document_symbol = entry.value;

        // Check if this is the root namespace
        if (symbol is Vala.Namespace && symbol.name == null)
        {
          if (document_symbols != null)
          {
            if (logwarn) warning("There are several root namespaces");
          }

          // The range must be include every children
          extend_document_symbol_range(document_symbol);

          document_symbols = document_symbol.children;
        }
      }

      return document_symbols;
    }

    private static void extend_document_symbol_range(DocumentSymbol document_symbol)
    {
      foreach (DocumentSymbol child_document_symbol in document_symbol.children)
      {
        extend_document_symbol_range(child_document_symbol);

        unowned Range? range = document_symbol.range;
        unowned Range? child_range = child_document_symbol.range;
        if (range != null && child_range != null)
        {
          extend_ranges(range, child_range);
        }
      }
    }

    /** Extends 'in_range' into 'ref_range'. */
    private static void extend_ranges(Range ref_range, Range in_range)
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

    private static DocumentSymbol? add_document_symbol_to_map(Vala.Symbol symbol, Gee.HashMap<Vala.Symbol, DocumentSymbol> document_symbol_map) throws Error
    {
      if (logdebug) debug(@"Process symbol: '$(code_node_to_string(symbol))'");
      DocumentSymbol? document_symbol = document_symbol_map.get(symbol);

      if (document_symbol == null)
      {
        DocumentSymbol? parent_document_symbol = null;

        unowned Vala.Symbol? parent_symbol = symbol.parent_symbol;
        if (parent_symbol != null)
        {
          if (logdebug) debug(@"Process parent symbol: '$(code_node_to_string(symbol.parent_symbol))'");
          parent_document_symbol = add_document_symbol_to_map(parent_symbol, document_symbol_map);
          if (parent_document_symbol == null)
          {
            return null;
          }
        }

        document_symbol = symbol_to_document_symbol(symbol);
        if (document_symbol == null)
        {
          // Ignore this symbol
          return null;
        }

        if (parent_document_symbol != null)
        {
          parent_document_symbol.children.add(document_symbol);
        }

        document_symbol_map.set(symbol, document_symbol);
      }

      return document_symbol;
    }

    private static DocumentSymbol? symbol_to_document_symbol(Vala.Symbol symbol) throws Error
    {
      DocumentSymbol document_symbol = new DocumentSymbol();

      // Can be null for the root namespace
      string? symbol_name = get_visible_symbol_name(symbol);
      if (symbol_name != null)
      {
        document_symbol.name = symbol_name;
      }

      // Can be null for the root namespace
      unowned Vala.SourceReference? source_reference = symbol.source_reference;
      if (source_reference != null)
      {
        document_symbol.range = source_reference_to_range(source_reference);
      }

      if (symbol is Vala.Field)
      {
        if (is_backing_field_symbol(symbol))
        {
          if (logdebug) debug(@"Field looks like a property-backing field: '$(code_node_to_string (symbol))'");
          return null;
        }
        document_symbol.kind = SymbolKind.Field;
      }
      else if (symbol is Vala.Property)
      {
        document_symbol.kind = SymbolKind.Property;
      }
      else if (symbol is Vala.Method)
      {
        if (symbol is Vala.CreationMethod)
        {
          unowned Vala.Symbol? parent_symbol = symbol.parent_symbol;
          if (parent_symbol != null && parent_symbol.source_reference == symbol.source_reference)
          {
            // Ignore automatically added default constructor
            return null;
          }
        }
        document_symbol.kind = SymbolKind.Method;

        unowned Range? range = document_symbol.range;
        unowned Vala.Method method = (Vala.Method)symbol;
        unowned Vala.Block? body = method.body;
        unowned Vala.SourceReference? body_source_reference = body != null ? body.source_reference : null;
        if (range != null && body_source_reference != null)
        {
          extend_ranges(range, source_reference_to_range(body_source_reference));
        }
      }
      else if (symbol is Vala.Destructor)
      {
        unowned Vala.Symbol? parent_symbol = symbol.parent_symbol;
        unowned string? type_name = parent_symbol != null ? parent_symbol.name : null;
        if (type_name == null)
        {
          return null;
        }
        document_symbol.name = "~" + type_name;
        document_symbol.kind = SymbolKind.Method;

        unowned Range? range = document_symbol.range;
        unowned Vala.Destructor destructor = (Vala.Destructor)symbol;
        unowned Vala.Block? body = destructor.body;
        unowned Vala.SourceReference? body_source_reference = body != null ? body.source_reference : null;
        if (range != null && body_source_reference != null)
        {
          extend_ranges(range, source_reference_to_range(body_source_reference));
        }
      }
      else if (symbol is Vala.Delegate)
      {
        document_symbol.kind = SymbolKind.Interface;
      }
      else if (symbol is Vala.Class)
      {
        document_symbol.kind = SymbolKind.Class;
      }
      else if (symbol is Vala.Struct)
      {
        document_symbol.kind = SymbolKind.Struct;
      }
      else if (symbol is Vala.Enum || symbol is Vala.ErrorDomain)
      {
        document_symbol.kind = SymbolKind.Enum;
      }
      else if (symbol is Vala.EnumValue || symbol is Vala.ErrorCode)
      {
        document_symbol.kind = SymbolKind.EnumMember;
      }
      else if (symbol is Vala.Interface)
      {
        document_symbol.kind = SymbolKind.Interface;
      }
      else if (symbol is Vala.Namespace)
      {
        document_symbol.kind = SymbolKind.Module;
      }
      else if (symbol is Vala.Constant)
      {
        document_symbol.kind = SymbolKind.Constant;
      }
      else if (symbol is Vala.Signal)
      {
        document_symbol.kind = SymbolKind.Event;
      }
      else
      {
        if (logdebug) debug(@"Symbol is ignored: '$(code_node_to_string(symbol))'");
        return null;
      }

      document_symbol.selectionRange = document_symbol.range;
      if (symbol_name != null)
      {
        Location? location = get_symbol_location(symbol, symbol, false);
        if (location != null)
        {
          document_symbol.selectionRange = location.range;
        }
      }

      document_symbol.detail = get_symbol_definition_code(symbol);
      document_symbol.children = new JsonArrayList<DocumentSymbol>();

      return document_symbol;
    }

    public static Gee.Set<Vala.Symbol>? find_symbols_in_file(SourceFile source_file)
    {
      unowned Vala.SourceFile? vala_file = source_file.vala_file;
      if (vala_file == null)
      {
        return null;
      }

      FindSymbolsInFile finder = new FindSymbolsInFile(vala_file);
      finder.find();
      return finder.symbols;
    }
  }
}
