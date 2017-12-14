script "SQLYoga Levure Callbacks"
command loadRegisteredKeyFile @xFileA
  local tDBObjectA, tError

  dbobject_createFromFile xFileA["filename"], xFileA["database key"]

  if the result is not empty then
    put "unable to read schema yaml file" && xFileA["filename"] && ":" && the result into tError
  end if

  if tError is empty then
    return empty for value
  else
    return tError for error
  end if
end loadRegisteredKeyFile
