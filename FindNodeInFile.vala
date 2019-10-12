namespace VLS
{
  abstract class FindNodeInFile : FindNode
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
  }
}
