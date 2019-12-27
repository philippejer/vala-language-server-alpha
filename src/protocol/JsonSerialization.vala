namespace Vls
{
  public class AbstractJsonSerializableObject : GLib.Object, JsonSerializableObject
  {
    protected virtual bool serialize_nulls()
    {
      return false;
    }

    public virtual Json.Node? serialize_property(string property_name, Value value, ParamSpec pspec)
    {
      // Serialize primitive types explicitly otherwise zero values are ignored for some reason...
      if (pspec.value_type.is_a(typeof(int)))
      {
        int val = value.get_int();
        Json.Node node = new Json.Node(Json.NodeType.VALUE);
        node.set_int(val);
        return node;
      }
      else if (pspec.value_type.is_a(typeof(double)))
      {
        double val = value.get_double();
        Json.Node node = new Json.Node(Json.NodeType.VALUE);
        node.set_double(val);
        return node;
      }
      else if (pspec.value_type.is_a(typeof(bool)))
      {
        bool val = value.get_boolean();
        Json.Node node = new Json.Node(Json.NodeType.VALUE);
        node.set_boolean(val);
        return node;
      }
      else if (pspec.value_type.is_a(typeof(JsonSerializableValue)))
      {
        unowned JsonSerializableValue? val = value as JsonSerializableValue;
        if (val == null)
        {
          if (serialize_nulls())
          {
            Json.Node node = new Json.Node(Json.NodeType.NULL);
            return node;
          }
          else
          {
            return null;
          }
        }
        else
        {
          return val.serialize();
        }
      }

      return default_serialize_property(property_name, value, pspec);
    }

    public virtual bool deserialize_property(string property_name, ref Value value, ParamSpec pspec, Json.Node property_node)
    {
      if (pspec.value_type.is_a(typeof(JsonSerializableValue)))
      {
        JsonSerializableValue? json_value = create_value(pspec.value_type, property_name);
        if (json_value == null)
        {
          return false;
        }
        if (json_value.deserialize(property_node))
        {
          value = Value(pspec.value_type);
          value.set_object(json_value);
        }
        return true;
      }

      return default_deserialize_property(property_name, ref value, pspec, property_node);
    }

    private JsonSerializableValue? create_value(Type value_type, string property_name)
    {
      if (value_type.is_a(typeof(JsonSerializableCollection)))
      {
        return create_collection(property_name);
      }
      else if (value_type.is_a(typeof(JsonSerializableMap)))
      {
        return create_map(property_name);
      }
      else
      {
        return (JsonSerializableValue)Object.new(value_type);
      }
    }

    protected virtual JsonSerializableCollection? create_collection(string property_name)
    {
      return null;
    }

    protected virtual JsonSerializableMap? create_map(string property_name)
    {
      return null;
    }
  }

  public interface JsonSerializableValue : Object
  {
    public abstract Json.Node serialize();
    public abstract bool deserialize(Json.Node node);
  }

  [GenericAccessors]
  public interface JsonSerializableCollection<T> : Gee.Collection<T>, JsonSerializableValue
  {
    public Type get_element_type()
    {
      return typeof(T);
    }

    public static Json.Node serialize_collection(JsonSerializableCollection<T> list)
    {
      Json.Array array = new Json.Array.sized(list.size);

      Type element_type = list.get_element_type();
      if (element_type.is_a(typeof(int)))
      {
        foreach (int value in (JsonSerializableCollection<int>)list)
        {
          array.add_int_element(value);
        }
      }
      else if (element_type.is_a(typeof(double)))
      {
        foreach (double? value in (JsonSerializableCollection<double?>)list)
        {
          if (value != null)
          {
            array.add_double_element(value);
          }
        }
      }
      else if (element_type.is_a(typeof(bool)))
      {
        foreach (bool value in (JsonSerializableCollection<bool>)list)
        {
          array.add_boolean_element(value);
        }
      }
      else if (element_type.is_a(typeof(string)))
      {
        foreach (string str in (JsonSerializableCollection<string>)list)
        {
          array.add_string_element(str);
        }
      }
      else if (element_type.is_a(typeof(JsonSerializableValue)))
      {
        foreach (JsonSerializableValue value in (JsonSerializableCollection<JsonSerializableValue>)list)
        {
          array.add_element(value.serialize());
        }
      }
      else if (element_type.is_a(typeof(Object)))
      {
        foreach (Object object in (JsonSerializableCollection<Object>)list)
        {
          array.add_element(Json.gobject_serialize(object));
        }
      }

      Json.Node node = new Json.Node(Json.NodeType.ARRAY);
      node.set_array(array);

      return node;
    }

    public static bool deserialize_collection(JsonSerializableCollection<T> list, Json.Node property_node)
    {
      Json.Array? array = (Json.Array)property_node.get_array();
      if (array == null)
      {
        return false;
      }

      Type element_type = list.get_element_type();
      array.foreach_element((array, index, node) =>
      {
        if (element_type.is_a(typeof(int)))
        {
          ((JsonSerializableCollection<int>)list).add((int)node.get_int());
        }
        else if (element_type.is_a(typeof(double)))
        {
          ((JsonSerializableCollection<double?>)list).add(node.get_double());
        }
        else if (element_type.is_a(typeof(bool)))
        {
          ((JsonSerializableCollection<bool>)list).add(node.get_boolean());
        }
        else if (element_type.is_a(typeof(string)))
        {
          string? elem = node.get_string();
          if (elem != null)
          {
            ((JsonSerializableCollection<string>)list).add(elem);
          }
        }
        else if (element_type.is_a(typeof(JsonSerializableValue)))
        {
          JsonSerializableValue elem = (JsonSerializableValue)Object.new(element_type);
          if (elem.deserialize(node))
          {
            ((JsonSerializableCollection<JsonSerializableValue>)list).add(elem);
          }
        }
        else if (element_type.is_a(typeof(Object)))
        {
          Object elem = Json.gobject_deserialize(element_type, node);
          ((JsonSerializableCollection<Object>)list).add(elem);
        }
      });

      return true;
    }
  }

  public class JsonArrayList<T> : Gee.ArrayList<T>, JsonSerializableValue, JsonSerializableCollection<T>
  {
    public JsonArrayList(owned Gee.EqualDataFunc<T>? equal_func = null)
    {
      base((owned)equal_func);
    }

    public JsonArrayList.wrap(owned T[] items, owned Gee.EqualDataFunc<T>? equal_func = null)
    {
      base.wrap((owned)items, (owned)equal_func);
    }

    public JsonArrayList.wrap_one(T item, owned Gee.EqualDataFunc<T>? equal_func = null)
    {
      base((owned)equal_func);
      add(item);
    }

    public Json.Node serialize()
    {
      return JsonSerializableCollection<T>.serialize_collection(this);
    }

    public bool deserialize(Json.Node node)
    {
      return JsonSerializableCollection<T>.deserialize_collection(this, node);
    }
  }

  [GenericAccessors]
  public interface JsonSerializableMap<T> : Gee.Map<string, T>, JsonSerializableValue
  {
    public T? first()
    {
      Gee.Iterator<Gee.Map.Entry<string, T>> iterator = iterator();
      if (!iterator.next())
      {
        return null;
      }
      return iterator.get().value;
    }

    public Type get_value_type()
    {
      return typeof(T);
    }

    public static Json.Node serialize(JsonSerializableMap<T> map)
    {
      Json.Object object = new Json.Object();
      Type value_type = map.get_value_type();
      if (value_type.is_a(typeof(int)))
      {
        foreach (Gee.Map.Entry<string, int> entry in ((JsonSerializableMap<int>)map).entries)
        {
          Json.Node node = new Json.Node.alloc().init_int(entry.value);
          object.set_member(entry.key, node);
        }
      }
      else if (value_type.is_a(typeof(double)))
      {
        foreach (Gee.Map.Entry<string, double?> entry in ((JsonSerializableMap<double?>)map).entries)
        {
          double? value = entry.value;
          if (value != null)
          {
            Json.Node node = new Json.Node.alloc().init_double(value);
            object.set_member(entry.key, node);
          }
        }
      }
      else if (value_type.is_a(typeof(bool)))
      {
        foreach (Gee.Map.Entry<string, bool> entry in ((JsonSerializableMap<bool>)map).entries)
        {
          Json.Node node = new Json.Node.alloc().init_boolean(entry.value);
          object.set_member(entry.key, node);
        }
      }
      else if (value_type.is_a(typeof(string)))
      {
        foreach (Gee.Map.Entry<string, string> entry in ((JsonSerializableMap<string>)map).entries)
        {
          Json.Node node = new Json.Node.alloc().init_string(entry.value);
          object.set_member(entry.key, node);
        }
      }
      else if (value_type.is_a(typeof(JsonSerializableValue)))
      {
        foreach (Gee.Map.Entry<string, JsonSerializableValue> entry in ((JsonSerializableMap<JsonSerializableValue>)map).entries)
        {
          object.set_member(entry.key, entry.value.serialize());
        }
      }
      else if (value_type.is_a(typeof(Object)))
      {
        foreach (Gee.Map.Entry<string, Object> entry in ((JsonSerializableMap<Object>)map).entries)
        {
          object.set_member(entry.key, Json.gobject_serialize(entry.value));
        }
      }

      Json.Node node = new Json.Node(Json.NodeType.OBJECT);
      node.set_object(object);

      return node;
    }

    public static bool deserialize(JsonSerializableMap<T> map, Json.Node property_node)
    {
      Json.Object? property_object = property_node.get_object();
      if (property_object == null)
      {
        return false;
      }

      Type value_type = map.get_value_type();
      property_object.foreach_member((object, name, node) =>
      {
        if (value_type.is_a(typeof(int)))
        {
          ((JsonSerializableMap<int>)map).set(name, (int)node.get_int());
        }
        else if (value_type.is_a(typeof(double)))
        {
          ((JsonSerializableMap<double?>)map).set(name, node.get_double());
        }
        else if (value_type.is_a(typeof(bool)))
        {
          ((JsonSerializableMap<bool>)map).set(name, node.get_boolean());
        }
        else if (value_type.is_a(typeof(string)))
        {
          if (!node.is_null())
          {
            string? value = node.get_string();
            if (value != null)
            {
              ((JsonSerializableMap<string>)map).set(name, value);
            }
          }
        }
        else if (value_type.is_a(typeof(JsonSerializableValue)))
        {
          JsonSerializableValue value = (JsonSerializableValue)Object.new(value_type);
          if (value.deserialize(node))
          {
            ((JsonSerializableMap<JsonSerializableValue>)map).set(name, value);
          }
        }
        else if (value_type.is_a(typeof(Object)))
        {
          Object value = Json.gobject_deserialize(value_type, node);
          ((JsonSerializableMap<Object>)map).set(name, value);
        }
      });

      return true;
    }
  }

  public class JsonHashMap<T> : Gee.HashMap<string, T>, JsonSerializableValue, JsonSerializableMap<T>
  {
    public JsonHashMap(owned Gee.HashDataFunc<string>? key_hash_func = null, owned Gee.EqualDataFunc<string>? key_equal_func = null, owned Gee.EqualDataFunc<string>? value_equal_func = null)
    {
      base((owned)key_hash_func, (owned)key_equal_func, (owned)value_equal_func);
    }

    public Json.Node serialize()
    {
      return JsonSerializableMap<T>.serialize(this);
    }

    public bool deserialize(Json.Node node)
    {
      return JsonSerializableMap<T>.deserialize(this, node);
    }
  }

  public class JsonDouble : Object, JsonSerializableValue
  {
    public double value;

    public JsonDouble(double value)
    {
      this.value = value;
    }

    public Json.Node serialize()
    {
      Json.Node node = new Json.Node(Json.NodeType.VALUE);
      node.set_double(value);
      return node;
    }

    public bool deserialize(Json.Node node)
    {
      if (node.get_node_type() != Json.NodeType.VALUE)
      {
        return false;
      }

      value = node.get_double();
      return true;
    }
  }

  public class JsonInt : Object, JsonSerializableValue
  {
    public int value;

    public JsonInt(int value)
    {
      this.value = value;
    }

    public Json.Node serialize()
    {
      Json.Node node = new Json.Node(Json.NodeType.VALUE);
      node.set_int(value);
      return node;
    }

    public bool deserialize(Json.Node node)
    {
      if (node.get_node_type() != Json.NodeType.VALUE)
      {
        return false;
      }

      value = (int)node.get_int();
      return true;
    }
  }

  public class JsonBool : Object, JsonSerializableValue
  {
    public bool value;

    public JsonBool(bool value)
    {
      this.value = value;
    }

    public Json.Node serialize()
    {
      Json.Node node = new Json.Node(Json.NodeType.VALUE);
      node.set_boolean(value);
      return node;
    }

    public bool deserialize(Json.Node node)
    {
      if (node.get_node_type() != Json.NodeType.VALUE)
      {
        return false;
      }

      value = node.get_boolean();
      return true;
    }
  }
}
