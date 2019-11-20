namespace Vls
{
  public class FindSymbolReferenceAtPosition : FindNodeAtPosition
  {
    private bool prefer_override;

    public Gee.HashSet<Vala.Symbol> symbols = new Gee.HashSet<Vala.Symbol>();
    public Vala.CodeNode? best_node = null;
    public Vala.Symbol? best_symbol = null;

    public FindSymbolReferenceAtPosition(Vala.SourceFile file, uint line, uint character, bool prefer_override)
    {
      base(file, line, character);
      this.prefer_override = prefer_override;
    }

    protected override void on_node_found(Vala.CodeNode node)
    {
      Vala.Symbol? symbol = get_symbol_reference(node, prefer_override);
      if (symbol == null)
      {
        return;
      }
      symbols.add(symbol);

      if (best_node == null)
      {
        if (loginfo) info(@"Found first symbol: '$(code_node_to_string(symbol))'");
        best_node = node;
        best_symbol = symbol;
      }
      else
      {
        bool is_inside = code_node_is_inside(node, best_node);
        if (is_inside)
        {
          if (code_node_matches(node, best_node))
          {
            if (best_node is Vala.Symbol && !(node is Vala.Symbol))
            {
              if (loginfo) info(@"Found worse symbol (best node is a symbol, not current node): '$(code_node_to_string(symbol))'");
            }
            else
            {
              if (loginfo) info(@"Found better symbol (matching symbols): '$(code_node_to_string(symbol))'");
              best_node = node;
              best_symbol = symbol;
            }
          }
          else
          {
            if (best_symbol.parent_symbol == symbol)
            {
              if (loginfo) info(@"Found worse symbol (more focused but parent of current best symbol): '$(code_node_to_string(symbol))'");
            }
            else
            {
              if (loginfo) info(@"Found better symbol (more focused): '$(code_node_to_string(symbol))'");
              best_node = node;
              best_symbol = symbol;
            }
          }
        }
        else
        {
          if (loginfo) info(@"Found worse symbol (less focused): '$(code_node_to_string(symbol))'");
        }
      }
    }
  }
}
