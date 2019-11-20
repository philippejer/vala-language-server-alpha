namespace Vls
{
  public abstract class FindNodeInFile : FindNode
  {
    protected Vala.SourceFile file;

    protected FindNodeInFile(Vala.SourceFile file)
    {
      this.file = file;
    }

    public void find()
    {
      this.visit_source_file(file);
    }

    protected override bool check_node(Vala.CodeNode node)
    {
      var source_reference = node.source_reference;
      if (source_reference == null)
      {
        return true;
      }
      if (source_reference.file != file)
      {
        return false;
      }

      check_node_in_file(node);

      return true;
    }

    protected abstract void check_node_in_file(Vala.CodeNode node);
  }
}
