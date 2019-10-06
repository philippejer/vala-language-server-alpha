class FindSymbolReferences : FindNode
{
  protected Vala.CodeContext context;
  protected Vala.Symbol target_symbol;
  protected bool include_target_symbol;

  protected Gee.HashSet<Vala.CodeNode> found_nodes = new Gee.HashSet<Vala.CodeNode>();
  public Gee.ArrayList<Vala.CodeNode> references = new Gee.ArrayList<Vala.CodeNode>();

  public FindSymbolReferences(Vala.CodeContext context, Vala.Symbol target_symbol, bool include_target_symbol)
  {
    this.context = context;
    this.target_symbol = target_symbol;
    this.include_target_symbol = include_target_symbol;
  }

  public void find()
  {
    context.accept(this);
  }

  protected override void check_node(Vala.CodeNode node)
  {
    var source_reference = node.source_reference;
    if (source_reference == null)
    {
      return;
    }

    if (found_nodes.contains(node))
    {
      return;
    }
    found_nodes.add(node);

    Vala.Symbol? symbol = get_symbol_reference(node);

    if ((include_target_symbol || (node != target_symbol)) && symbol == target_symbol)
    {
      if (loginfo) info(@"Found reference ($(code_node_to_string (node)))");
      references.add(node);
    }
  }
}
