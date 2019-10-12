namespace VLS
{
  [CCode(cname = "JsonSerializable", cprefix = "json_serializable_", cheader_filename = "json-glib/json-glib.h", type_id = "json_serializable_get_type()")]
  public interface JsonSerializableObject : GLib.Object
  {
    public virtual unowned GLib.ParamSpec? find_property(string name);
    public virtual GLib.Value get_property(GLib.ParamSpec pspec);
    public virtual void set_property(GLib.ParamSpec pspec, GLib.Value value);
    [CCode(array_length_pos = 0.1, array_length_type = "guint")]
    public (unowned GLib.ParamSpec)[] list_properties();
    public Json.Node default_serialize_property(string property_name, GLib.Value value, GLib.ParamSpec pspec);
    public virtual Json.Node serialize_property(string property_name, GLib.Value value, GLib.ParamSpec pspec);
    public bool default_deserialize_property(string property_name, ref GLib.Value value, GLib.ParamSpec pspec, Json.Node property_node);
    public virtual bool deserialize_property(string property_name, ref GLib.Value value, GLib.ParamSpec pspec, Json.Node property_node);
  }
}
