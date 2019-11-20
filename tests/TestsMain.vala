namespace Vls
{
  public static void main(string[] args)
  {
    Test.init(ref args);

    CompletionHelpers.test_extract_completion_expression();

    Test.run ();
  }
}
