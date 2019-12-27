namespace Vls
{
  public abstract class FindNodeAtPosition : FindNodeInFile
  {
    protected uint line;
    protected uint column;

    protected FindNodeAtPosition(Vala.SourceFile file, uint line, uint column)
    {
      base(file);
      this.line = line;
      this.column = column;
    }

    protected override void check_node_in_file(Vala.CodeNode node)
    {
      unowned Vala.SourceReference? source_reference = node.source_reference;
      if (source_reference == null)
      {
        return;
      }

      unowned Vala.SourceLocation begin = source_reference.begin;
      unowned Vala.SourceLocation end = source_reference.end;

      if (begin.line > end.line)
      {
        if (logwarn) warning(@"Source reference '$(source_reference)' begins after it ends");
        return;
      }

      if (line < begin.line || line > end.line)
      {
        return;
      }
      if (line == begin.line && column < begin.column)
      {
        return;
      }
      if (line == end.line && column > end.column + 1)
      {
        return;
      }

      if (logdebug) debug(@"Found node: '$(code_node_to_string(node))', source: '$(get_code_node_source(node))'");
      on_node_found(node);
    }

    protected abstract void on_node_found(Vala.CodeNode node);
  }
}
