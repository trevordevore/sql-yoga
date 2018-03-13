script "SQL Yoga Development Tools"
command sqlyogadev_reloadConfigFiles
  levureReloadRegisteredKey "sql yoga|configuration"

  return empty
end sqlyogadev_reloadConfigFiles


command sqlyogadev_createTriggers
  local theError

  dbconn_connect
  if theError is empty then
    dbconn_beginTransaction
    put the result into theError
  end if
  dbschema_createTriggers # default connection
  put the result into theError
  if theError is empty then
    dbconn_commitTransaction
  else
    dbconn_rollbackTransaction
  end if

  return theError
end sqlyogadev_createTriggers


command sqlyogadev_enableLogging pBoolean, pConnectionName, pDBKey
  if pBoolean then
    dbconn_set "log callback", "sqlyogadev_loggingCallback", pConnectionName, pDBKey
  else
    dbconn_set "log callback", "", pConnectionName, pDBKey
  end if
end sqlyogadev_enableLogging


command sqlyogadev_loggingCallback pSQL, pConnectionName, pDBKey
  loggerLogMsg "sqlYoga:" && pSQL
end sqlyogadev_loggingCallback


/**
Summary:

*/
command sqlyogadev_createSchemaMigration pName, pDBKey
  local tError, tMigrateFolder, tStamp

  put _migrateFolder(pDBKey) into tMigrateFolder
  put _GetGMTTimeStampForMigrationId() into tStamp

  put textEncode("migration:" & cr & "  ", "utf8") \
        into URL ("binfile:" & tMigrateFolder & "/" & tStamp & "_" & pName & ".yml")
  put the result into tError

  return tError for error
end sqlyogadev_createSchemaMigration


command sqlyogadev_runMigrations pDBKey
  local tError, tConfigA, i, tMigrateFolder

  put _migrateFolder(pDBKey) into tMigrateFolder

  if there is a folder tMigrateFolder then
    _runMigrations tMigrateFolder, empty, pDBKey
    put the result into tError
  else
    put "migrate folder not found:" && tMigrateFolder into tError
  end if

  dbsynch_schemaWithDatabase empty, pDBKey

  return tError
end sqlyogadev_runMigrations


command _runMigrations pMigrationFolder, pConnectionA, pDBKey
  local tError, tFiles, tFile, tMigrateA

  put files(pMigrationFolder) into tFiles
  filter tFiles without ".*"
  filter tFiles with "*.yml"

  sort lines of tFiles numeric by each

  repeat for each line tFile in tFiles
    put yamlFileToArray(pMigrationFolder & "/" & tFile) into tMigrateA
    put the result into tError

    if tError is empty then
      dbmigrate_processMigrationArray tMigrateA, pConnectionA, pDBKey
      put the result into tError
    end if

    if tError is not empty then exit repeat
  end repeat

  return tError
end _runMigrations


private function _migrateFolder pDBKey
  local tConfigA, i

  put levureAppGet("sql yoga") into tConfigA

  repeat with i = 1 to the number of elements of tConfigA["configuration"]
    if tConfigA["configuration"][i]["database key"] is pDBKey \
          or (pDBKey is empty and tConfigA["configuration"][i]["database key"] is "default") then
      return tConfigA["configuration"][i]["filename"] & "/migrate"
    end if
  end repeat

  return empty
end _migrateFolder


private function _GetGMTTimeStampForMigrationId
  local tInternetTime, tGMTOffset

  put the internet date into tInternetTime
  put _InternetTimeStampGMTOffset(tInternetTime) into tGMTOffset

  convert tInternetTime from internet date to dateItems
  if tGMTOffset is a number then
    subtract tGMTOffset from item 4 of tInternetTime
  end if
  convert tInternetTime to dateItems
  replace comma with empty in tInternetTime
  return tInternetTime
end _GetGMTTimeStampForMigrationId


private function _InternetTimeStampGMTOffset pInternetTime
  local tGMTOffset

  put the last word of pInternetTime into tGMTOffset
  delete the char -2 to -1 of tGMTOffset
  if char 2 of tGMTOffset is 0 then delete char 2 of tGMTOffset
  if char 1 of tGMTOffset is "+" then delete char 1 of tGMTOffset
  return tGMTOffset
end _InternetTimeStampGMTOffset
