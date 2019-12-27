namespace Vls
{
  public class FindSymbolReferences : FindNode
  {
    private Vala.CodeContext code_context;
    private Vala.Symbol target_symbol;
    private bool include_target_symbol;

    public Gee.ArrayList<Vala.CodeNode> references = new Gee.ArrayList<Vala.CodeNode>();

    public FindSymbolReferences(Vala.CodeContext code_context, Vala.Symbol target_symbol, bool include_target_symbol)
    {
      this.code_context = code_context;
      this.target_symbol = target_symbol;
      this.include_target_symbol = include_target_symbol;
    }

    public void find()
    {
      code_context.accept(this);
    }

    protected override bool check_node(Vala.CodeNode node)
    {
      if (is_package_code_node(node))
      {
        if (logsilly) debug(@"Ignoring non-source node: '$(code_node_to_string(node))'");
        return false;
      }

      // Get the base symbol to find every reference
      Vala.Symbol? base_symbol = get_symbol_reference(node, false);
      if (base_symbol == target_symbol)
      {
        if (!include_target_symbol)
        {
          if (node == target_symbol)
          {
            return true;
          }

          Vala.Symbol? derived_symbol = get_symbol_reference(node, true);
          if (derived_symbol != null && derived_symbol == node)
          {
            // Typically happens when the node references an override of the target method
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
