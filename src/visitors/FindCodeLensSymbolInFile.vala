namespace Vls
{
  public class FindCodeLensSymbolInFile : FindNodeInFile
  {
    private uint line;
    private uint column;

    public Vala.Symbol? found_symbol = null;

    public FindCodeLensSymbolInFile(Vala.SourceFile file, uint line, uint column)
    {
      base(file);
      this.line = line;
      this.column = column;
    }

    protected override void check_node_in_file(Vala.CodeNode node)
    {
      if (found_symbol != null)
      {
        return;
      }

      if (node.source_reference.begin.line != line || node.source_reference.begin.column != column)
      {
        return;
      }

      if (!(node is Vala.Method) && !(node is Vala.Property))
      {
        return;
      }

      found_symbol = (Vala.Symbol)node;
    }
  }
}
