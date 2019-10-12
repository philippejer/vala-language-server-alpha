namespace VLS
{
  abstract class FindNodeByPosition : FindNodeInFile
  {
    protected uint line;
    protected uint character;

    protected Gee.HashSet<Vala.CodeNode> found_nodes = new Gee.HashSet<Vala.CodeNode>();

    protected FindNodeByPosition(Vala.SourceFile file, uint line, uint character)
    {
      base(file);
      this.line = line;
      this.character = character;
    }

    protected override void check_node(Vala.CodeNode node)
    {
      var source_reference = node.source_reference;
      if (source_reference == null)
      {
        return;
      }

      if (source_reference.file != file)
      {
        return;
      }

      Vala.SourceLocation begin = source_reference.begin;
      Vala.SourceLocation end = source_reference.end;

      if (begin.line > end.line)
      {
        warning(@"Source reference begins after it ends ($(source_reference))");
        return;
      }

      if (line < begin.line || line > end.line)
      {
        return;
      }
      if (line == begin.line && character < begin.column)
      {
        return;
      }
      if (line == end.line && character > end.column + 1)
      {
        return;
      }

      if (found_nodes.contains(node))
      {
        return;
      }
      found_nodes.add(node);

      if (logdebug) debug(@"Found node ($(code_node_to_string (node))), source ($(get_code_node_source (node)))");
      if (loginfo) info(@"Found node ($(code_node_to_string (node)))");
      on_node_found(node);
    }

    protected abstract void on_node_found(Vala.CodeNode node);
  }
}
