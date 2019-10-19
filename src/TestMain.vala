namespace Vls
{
  void main(string[] args)
  {
    Test.init(ref args);

    _test_extract_completion_expression();

    Test.run ();
  }
}
