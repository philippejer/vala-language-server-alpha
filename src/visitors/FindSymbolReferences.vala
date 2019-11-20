namespace Vls
{
  public class FindSymbolReferences : FindNode
  {
    private Vala.CodeContext context;
    private Vala.Symbol target_symbol;
    private bool include_target_symbol;

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

    protected override bool check_node(Vala.CodeNode node)
    {
      if (is_package_code_node(node))
      {
        if (logsilly) debug(@"Ignoring non-source node: '$(code_node_to_string(node))'");
        return false;
      }

      Vala.Symbol? symbol_base = get_symbol_reference(node, false);

      if (symbol_base == target_symbol)
      {
        if (!include_target_symbol)
        {        
          if (node == target_symbol)
          {
            return true;
          }

          Vala.Symbol? symbol_override = get_symbol_reference(node, true);          
          if (node == symbol_override)
          {
            // Typically, this happens when the node references an override of the target method
            return true;
          }
        }
        
        if (loginfo) info(@"Found target symbol reference: '$(code_node_to_string(node))'");
        references.add(node);
      }

      return true;
    }
  }
}
