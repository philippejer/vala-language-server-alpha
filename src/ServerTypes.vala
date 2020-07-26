namespace Vls
{
  public errordomain VlsError
  {
    FAILED
  }

  public enum LogLevel
  {
    OFF = 0,
    WARN,
    INFO,
    DEBUG,
    SILLY;

    public string to_string()
    {
      GLib.EnumValue? value = ((GLib.EnumClass) typeof(LogLevel).class_ref()).get_value(this);
      return value == null ? "???" : value.value_name.replace("VLS_LOG_LEVEL_", "");
    }

    public string to_json()
    {
      switch (this)
      {
      case LogLevel.OFF: return "off";
      case LogLevel.WARN: return "warn";
      case LogLevel.INFO: return "info";
      case LogLevel.DEBUG: return "debug";
      case LogLevel.SILLY: return "silly";
      default: return "???";
      }
    }

    public static LogLevel? from_json(string? value)
    {
      if (value == null)
      {
        return null;
      }

      switch (value)
      {
      case "off": return LogLevel.OFF;
      case "warn": return LogLevel.WARN;
      case "info": return LogLevel.INFO;
      case "debug": return LogLevel.DEBUG;
      case "silly": return LogLevel.SILLY;
      case "true": return LogLevel.INFO;
      default: return LogLevel.INFO;
      }
    }
  }

  public enum MethodCompletionMode
  {
    OFF = 0,
    SPACE,
    NOSPACE;

    public string to_string()
    {
      GLib.EnumValue? value = ((GLib.EnumClass) typeof(MethodCompletionMode).class_ref()).get_value(this);
      return value == null ? "???" : value.value_name.replace("VLS_METHOD_COMPLETION_MODE_", "");
    }

    public string to_json()
    {
      switch (this)
      {
      case MethodCompletionMode.OFF: return "off";
      case MethodCompletionMode.SPACE: return "space";
      case MethodCompletionMode.NOSPACE: return "nospace";
      default: return "???";
      }
    }

    public static MethodCompletionMode? from_json(string? value)
    {
      if (value == null)
      {
        return null;
      }

      switch ((string)value)
      {
      case "off": return MethodCompletionMode.OFF;
      case "space": return MethodCompletionMode.SPACE;
      case "nospace": return MethodCompletionMode.NOSPACE;
      default: return MethodCompletionMode.OFF;
      }
    }
  }

  public class ServerConfig : AbstractJsonSerializableObject
  {
    public LogLevel logLevel { get; set; default = LogLevel.WARN; }
    public MethodCompletionMode methodCompletionMode { get; set; default = MethodCompletionMode.OFF; }
    public bool referencesCodeLensEnabled { get; set; default = false; }
    public bool minimalCodeCheckEnabled { get; set; default = false; }

    public override bool deserialize_property(string property_name, out Value value, ParamSpec pspec, Json.Node property_node)
    {
      if (pspec.value_type.is_a(typeof(LogLevel)))
      {
        value = Value(pspec.value_type);
        value.set_enum(LogLevel.from_json(property_node.get_string()) ?? LogLevel.WARN);
        return true;
      }
      else if (pspec.value_type.is_a(typeof(MethodCompletionMode)))
      {
        value = Value(pspec.value_type);
        value.set_enum(MethodCompletionMode.from_json(property_node.get_string()) ?? MethodCompletionMode.OFF);
        return true;
      }
      return base.deserialize_property(property_name, out value, pspec, property_node);
    }
  }

  public class BuildConfig : AbstractJsonSerializableObject
  {
    public JsonSerializableCollection<string>? sources { get; set; }

    public string? parameters { get; set; }

    protected override JsonSerializableCollection? create_collection(string property_name)
    {
      switch (property_name)
      {
      case "sources":
        return new JsonArrayList<string>();
      }
      return base.create_collection(property_name);
    }
  }

  public class MesonTarget : AbstractJsonSerializableObject, Json.Serializable
  {
    public string name { get; set; }

    public string target_type { get; set; } // "type" is not allowed (even with an '@')

    public JsonSerializableCollection<MesonTargetSource>? target_sources { get; set; }

    public override unowned ParamSpec? find_property(string name)
    {
      return base.find_property(name == "type" ? "target_type" : name);
    }

    protected override JsonSerializableCollection? create_collection(string property_name)
    {
      switch (property_name)
      {
      case "target-sources":
        return new JsonArrayList<MesonTargetSource>();
      }
      return base.create_collection(property_name);
    }
  }

  public class MesonTargetSource : AbstractJsonSerializableObject
  {
    public string? language { get; set; }

    public JsonSerializableCollection<string>? parameters { get; set; }

    public JsonSerializableCollection<string>? sources { get; set; }

    protected override JsonSerializableCollection? create_collection(string property_name)
    {
      switch (property_name)
      {
      case "parameters":
      case "sources":
        return new JsonArrayList<string>();
      }
      return base.create_collection(property_name);
    }
  }

  public enum LintSeverity
  {
    IGNORE = 0,
    ACTION,
    HINT,
    INFO,
    WARN,
    ERROR;

    public string to_string()
    {
      GLib.EnumValue? value = ((GLib.EnumClass) typeof(LintSeverity).class_ref()).get_value(this);
      return value == null ? "???" : ((GLib.EnumValue)value).value_name.replace("LINT_SEVERITY_", "");
    }

    public string to_json()
    {
      switch (this)
      {
      case LintSeverity.IGNORE: return "ignore";
      case LintSeverity.ACTION: return "action";
      case LintSeverity.HINT: return "hint";
      case LintSeverity.INFO: return "info";
      case LintSeverity.WARN: return "warn";
      case LintSeverity.ERROR: return "error";
      default: return "???";
      }
    }

    public static LintSeverity? from_json(string? value)
    {
      if (value == null)
      {
        return null;
      }

      switch ((string)value)
      {
      case "ignore": return LintSeverity.IGNORE;
      case "action": return LintSeverity.ACTION;
      case "hint": return LintSeverity.HINT;
      case "info": return LintSeverity.INFO;
      case "warn": return LintSeverity.WARN;
      case "error": return LintSeverity.ERROR;
      default: return LintSeverity.IGNORE;
      }
    }
  }

  public class LintConfig : AbstractJsonSerializableObject
  {
    public LintSeverity no_implicit_this_access { get; set; default = LintSeverity.IGNORE; }
    public LintSeverity no_unqualified_static_access { get; set; default = LintSeverity.IGNORE; }
    public LintSeverity no_implicit_non_null_cast { get; set; default = LintSeverity.IGNORE; }
    public LintSeverity no_type_inference { get; set; default = LintSeverity.IGNORE; }
    public LintSeverity no_type_inference_unless_evident { get; set; default = LintSeverity.IGNORE; }

    public override Json.Node serialize_property(string property_name, Value value, ParamSpec pspec)
    {
      error("Not supported");
    }

    public override bool deserialize_property(string property_name, out Value value, ParamSpec pspec, Json.Node property_node)
    {
      if (pspec.value_type.is_a(typeof(LintSeverity)))
      {
        value = Value(pspec.value_type);
        value.set_enum(LintSeverity.from_json(property_node.get_string()) ?? LintSeverity.IGNORE);
        return true;
      }
      return base.deserialize_property(property_name, out value, pspec, property_node);
    }
  }
}
