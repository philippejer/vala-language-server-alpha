namespace Vls
{
  public class DocumentSymbolHelpers
  {  
    public static JsonSerializableCollection<DocumentSymbol>? get_document_symbols(SourceFile source_file) throws Error
    {
      Gee.Set<Vala.Symbol> symbols = find_symbols_in_file(source_file);

      var document_symbol_map = new Gee.HashMap<Vala.Symbol, DocumentSymbol>();
      foreach (Vala.Symbol symbol in symbols)
      {
        add_document_symbol_to_map(symbol, document_symbol_map);
      }

      JsonSerializableCollection<DocumentSymbol> document_symbols = null;
      foreach (Gee.Map.Entry<Vala.Symbol, DocumentSymbol> entry in document_symbol_map.entries)
      {
        Vala.Symbol symbol = entry.key;
        DocumentSymbol document_symbol = entry.value;
        if (symbol is Vala.Namespace && symbol.name == null)
        {
          if (document_symbols != null)
          {
            if (logwarn) warning("There are several root symbols");
          }
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
        if (document_symbol.range != null)
        {
          extend_ranges(document_symbol.range, child_document_symbol.range);
        }
      }
    }

    private static DocumentSymbol? add_document_symbol_to_map(Vala.Symbol symbol, Gee.HashMap<Vala.Symbol, DocumentSymbol> document_symbol_map) throws Error
    {
      if (logdebug) debug(@"Process symbol: '$(code_node_to_string(symbol))'");
      DocumentSymbol? document_symbol = document_symbol_map.get(symbol);
      if (document_symbol == null)
      {
        DocumentSymbol? parent_document_symbol = null;
        if (symbol.parent_symbol != null)
        {
          if (logdebug) debug(@"Process parent symbol: '$(code_node_to_string(symbol.parent_symbol))'");
          parent_document_symbol = add_document_symbol_to_map(symbol.parent_symbol, document_symbol_map);
          if (parent_document_symbol == null)
          {
            return null;
          }
        }
        document_symbol = symbol_to_document_symbol(symbol);
        if (document_symbol == null)
        {
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
      var document_symbol = new DocumentSymbol();

      document_symbol.name = get_visible_symbol_name(symbol);
      
      if (symbol.source_reference != null)
      {
        document_symbol.range = source_reference_to_range(symbol.source_reference);
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
        document_symbol.kind = SymbolKind.Method;
        Vala.Method method = (Vala.Method)symbol;
        if (method.body != null)
        {
          extend_ranges(document_symbol.range, source_reference_to_range(method.body.source_reference));
        }
      }
      else if (symbol is Vala.Destructor)
      {
        document_symbol.name = "~" + symbol.parent_symbol.name;
        document_symbol.kind = SymbolKind.Method;
        Vala.Destructor destructor = (Vala.Destructor)symbol;
        if (destructor.body != null)
        {
          extend_ranges(document_symbol.range, source_reference_to_range(destructor.body.source_reference));
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
        if (logdebug) debug(@"Symbol not returned: '$(code_node_to_string(symbol))'");
        return null;
      }

      if (document_symbol.selectionRange == null)
      {
        document_symbol.selectionRange = document_symbol.range;
        
        if (symbol.name != null)
        {
          Location? location = get_symbol_location(symbol, symbol, false);
          if (location != null)
          {
            document_symbol.selectionRange = location.range;
          }
        }
      }

      document_symbol.detail = get_symbol_definition_code(symbol);
      document_symbol.children = new JsonArrayList<DocumentSymbol>();

      return document_symbol;
    }

    public static Gee.Set<Vala.Symbol> find_symbols_in_file(SourceFile source_file)
    {
      var finder = new FindSymbolsInFile(source_file.vala_file);
      finder.find();
      return finder.symbols;
    }
  }
}
