namespace Vls
{
  public void test_equal_strings(string expected, string actual)
  {
    if (expected != actual)
    {
      error(@"\"$(actual)\" should be \"$(expected)\"");
    }
  }
}
