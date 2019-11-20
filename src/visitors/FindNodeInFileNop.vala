namespace Vls
{
  public class FindNodeInFileNop : FindNodeInFile
  {
    private int num_nodes = 0;

    public FindNodeInFileNop(Vala.SourceFile file)
    {
      base(file);
    }

    ~FindNodeInFileNop()
    {
      if (loginfo) info(@"Visited nodes: $(num_nodes)");
    }

    protected override void check_node_in_file(Vala.CodeNode node)
    {
      num_nodes += 1;
    }
  }
}
