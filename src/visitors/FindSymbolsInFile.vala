namespace Vls
{
  class FindSymbolsInFile : FindNodeInFile
  {
    public Gee.HashSet<Vala.Symbol> symbols = new Gee.HashSet<Vala.Symbol>();

    public FindSymbolsInFile(Vala.SourceFile file)
    {
      base(file);
    }

    protected override void check_node(Vala.CodeNode node)
    {
      if (node.source_reference == null || node.source_reference.file != this.file)
      {
        return;
      }

      Vala.Symbol? symbol = node as Vala.Symbol;
      
      if (symbol == null || is_hidden_symbol(symbol))
      {
        return;
      }

      if (logdebug) debug(@"Found symbol ($(code_node_to_string(symbol)))");
      symbols.add(symbol);
    }
  }
}
