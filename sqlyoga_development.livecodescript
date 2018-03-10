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


command sqlyogadev_runMigrations pDBKey
  local tError, tConfigA, i, tMigrateFolder

  put levureAppGet("sql yoga") into tConfigA

  repeat with i = 1 to the number of elements of tConfigA["configuration"]
    if tConfigA["configuration"][i]["database key"] is pDBKey \
          or (pDBKey is empty and tConfigA["configuration"][i]["database key"] is "default") then
      put tConfigA["configuration"][i]["filename"] & "/migrate" into tMigrateFolder

      if there is a folder tMigrateFolder then
        _runMigrations tMigrateFolder, empty, pDBKey
        put the result into tError
      else
        put "migrate folder not found:" && tMigrateFolder into tError
      end if

      exit repeat
    end if
  end repeat

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
