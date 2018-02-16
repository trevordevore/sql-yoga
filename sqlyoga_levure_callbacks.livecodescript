script "SQLYoga Levure Callbacks"
command loadRegisteredKeyFile @xFileA
  local tDBObjectA, i, tData, tError

  if there is a folder xFileA["filename"] then
    repeat for each line tFile in files(xFileA["filename"])
      if not (tFile ends with ".yml") then next repeat

      put url("binfile:" & xFileA["filename"] & "/" & tFile) & cr after tData
      if the result is not empty then
        put "unable to read schema yaml file" && xFileA["filename"] & "/" & tFile && ":" && the result into tError
        exit repeat
      end if
    end repeat
  else
    put url("binfile:" & xFileA["filename"]) into tData
  end if

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
