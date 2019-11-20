namespace Vls
{
  public class FindSymbolsInFile : FindNodeInFile
  {
    public Gee.HashSet<Vala.Symbol> symbols = new Gee.HashSet<Vala.Symbol>();

    public FindSymbolsInFile(Vala.SourceFile file)
    {
      base(file);
    }

    protected override void check_node_in_file(Vala.CodeNode node)
    {
      Vala.Symbol? symbol = node as Vala.Symbol;
      
      if (symbol == null || is_hidden_symbol(symbol))
      {
        return;
      }

      if (logdebug) debug(@"Found symbol: '$(code_node_to_string(symbol))'");
      symbols.add(symbol);
    }
  }
}
