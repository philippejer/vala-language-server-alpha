namespace VLS
{
  class FindSymbolByPosition : FindNodeByPosition
  {
    public Gee.ArrayList<Vala.Symbol> symbols = new Gee.ArrayList<Vala.Symbol>();
    public Vala.CodeNode? best_node = null;
    public Vala.Symbol? best_symbol = null;

    public FindSymbolByPosition(Vala.SourceFile file, uint line, uint character)
    {
      base(file, line, character);
    }

    protected override void on_node_found(Vala.CodeNode node)
    {
      Vala.Symbol? symbol = get_symbol_reference(node);
      if (symbol == null)
      {
        return;
      }
      symbols.add(symbol);

      if (best_node == null)
      {
        if (loginfo) info(@"Found first symbol ($(code_node_to_string (symbol)))");
        best_node = node;
        best_symbol = symbol;
      }
      else
      {
        bool is_better_reference = code_node_is_inside(node, best_node);
        if (is_better_reference)
        {
          if (code_node_matches(node, best_node))
          {
            if (best_node is Vala.Symbol && !(node is Vala.Symbol))
            {
              if (loginfo) info(@"Found worse symbol (best node is a symbol, not current node) ($(code_node_to_string (symbol)))");
            }
            else
            {
              if (loginfo) info(@"Found better symbol (matching symbols) ($(code_node_to_string (symbol)))");
              best_node = node;
              best_symbol = symbol;
            }
          }
          else
          {
            if (loginfo) info(@"Found better symbol (more focused) ($(code_node_to_string (symbol)))");
            best_node = node;
            best_symbol = symbol;
          }
        }
        else
        {
          if (loginfo) info(@"Found worse symbol (less focused) ($(code_node_to_string (symbol)))");
        }
      }
    }
  }
}
