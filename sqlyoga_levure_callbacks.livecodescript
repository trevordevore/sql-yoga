script "SQLYoga Levure Callbacks"
command loadRegisteredKeyFile @xFileA
  local tDBObjectA, i, tData, tError

  repeat with i = 1 to the number of elements of xFileA["configuration files"]
    put url("binfile:" & xFileA["configuration files"][i]["filename"]) & cr after tData
    if the result is not empty then
      put "unable to read schema yaml file" && xFileA["filename"] && ":" && the result into tError
      exit repeat
    end if
  end repeat

  if tError is empty then
    dbobject_createFromYAML tData, levureAppFolder(), xFileA["database key"]
    put the result into tError
  end if

  if tError is empty then
    return empty for value
  else
    return tError for error
  end if
end loadRegisteredKeyFile
