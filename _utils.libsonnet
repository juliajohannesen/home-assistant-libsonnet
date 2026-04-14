{
  toArray(value): if std.isArray(value) then value else [value],
  
  provideRoot(root, value): std.get({
    "array": [$.provideRoot(root, item) for item in value],
    "function": value(root),
  }, std.type(value), value),
}