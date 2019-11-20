namespace Vls
{
  public class FindCodeLensSymbolsInFile : FindNodeInFile
  {
    public Gee.HashSet<Vala.Symbol> symbols = new Gee.HashSet<Vala.Symbol>();

    public FindCodeLensSymbolsInFile(Vala.SourceFile file)
    {
      base(file);
    }

    protected override void check_node_in_file(Vala.CodeNode node)
    {
      if (!(node is Vala.Method) && !(node is Vala.Property))
      {
        return;
      }

      Vala.Symbol symbol = (Vala.Symbol)node;

      if (symbol.source_reference == null || is_hidden_symbol(symbol) || symbol.name.has_prefix("_lambda"))
      {
        if (logdebug) debug(@"Symbol ignored: '$(code_node_to_string(symbol))'");
        return;
      }
      
      if (logdebug) debug(@"Found code lens symbol: '$(code_node_to_string(symbol))'");
      symbols.add(symbol);
    }
  }
}
