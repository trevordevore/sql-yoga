script "SQLYoga Levure Callbacks"
command loadRegisteredKeyFile @xFileA
  local tDBObjectA, tDataA, tError

  _concatYAMLFiles xFileA["filename"]
  put the result into tError
  put it into tDataA

  if tError is empty then
    dbobject_initialize tDataA, levureAppFolder(), xFileA["database key"]
    put the result into tError
  end if

  if tError is empty then
    return empty for value
  else
    return tError for error
  end if
end loadRegisteredKeyFile


private command _concatYAMLFiles pFilename
  local tError, tFile, tData, tDataA

  if there is a folder pFilename then
    repeat for each line tFile in files(pFilename)
      if not (tFile ends with ".yml" or tFile ends with ".yaml") then next repeat

      put url("binfile:" & pFilename & "/" & tFile) & cr after tData
      if the result is not empty then
        put "unable to read schema yaml file" && pFilename & "/" & tFile && ":" && the result into tError
        exit repeat
      end if
    end repeat
  else
    put url("binfile:" & pFilename) into tData
  end if

  if tError is empty then
    YAMLToArray textDecode(tData, "utf8")
    put the result into tError
    put it into tDataA
  end if

  if tError is empty then
    return tDataA for value
  else
    return tError for error
  end if
end _concatYAMLFiles


/**
Summary: Concat all of the files and store in a custom property in sqlyoga_loader.livecodescript

Description:
This helper doesn't distribute the files in the sql yoga > configuration key. In
development the designated folder holds multiple files. Concat the files and make available
through a custom property.
*/
command processPackagedFileAsset pBuildProfile, pPlatform, @xFileAssetA, pOutputFolder
  local tError, tDataA, tFilename
  local msgsAreLocked

  if xFileAssetA["database key"] is empty then put "default" into xFileAssetA["database key"]

  _concatYAMLFiles xFileAssetA["filename"]
  put the result into tError
  put it into tDataA

  if tError is empty then
    # Store the database object in the sqlyoga library stack
    put pOutputFolder & "/helpers/sql-yoga/sqlyoga_loader.livecodescript" into tFilename
    put the lockMessages into msgsAreLocked
    lock messages
    set the uDbObjects[ xFileAssetA["database key"] ] of stack tFilename to tDataA
    set the scriptonly of stack tFilename to false
    save stack tFilename
    delete stack tFilename
    unlock messages
  end if

  if tError is not empty then
    answer error "SQL Yoga Helper:" && param(0) & ":" && tError
  end if

  return empty
end processPackagedFileAsset
