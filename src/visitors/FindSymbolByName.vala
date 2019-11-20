namespace Vls
{
  public class FindSymbolByName : FindNodeInFile
  {
    protected string name;

    public Gee.HashSet<Vala.Symbol> symbols = new Gee.HashSet<Vala.Symbol>();

    public FindSymbolByName(Vala.SourceFile file, string name)
    {
      base(file);
      this.name = name;
    }

    protected override void check_node_in_file(Vala.CodeNode node)
    {
      var symbol = node as Vala.Symbol;

      if (symbol == null || symbol.name != name)
      {
        return;
      }

      if (loginfo) info(@"Found symbol: '$(code_node_to_string(symbol))', source: '$(get_code_node_source(symbol))'");
      symbols.add(symbol);
    }
  }
}
