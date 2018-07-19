script "libSQLYogaSchema"


command dbschema_load pSchemaFile
  # code...
end dbschema_load


/**
Summary: Dispatches `RunMigration` to a stack file.

Parameters:
pMigrationVersion:
pStackFilename:
pConnectionA:
pDBKey:

Description:

*/
command dbschema_processMigrationFile pMigrationVersion, pStackFilename, pConnectionA, pDBKey
  local tError

  _beginProcessMigration pMigrationVersion, pConnectionA, pDBKey
  put the result into tError

  try
    if tError is empty then
      dispatch "RunMigration" to stack pStackFilename with pConnectionA
      put the result into tError
    end if

    if tError is empty then
      dbschema_createTriggers pConnectionA
      put the result into tError
    end if

    if tError is empty then
      _endProcessMigration pMigrationVersion, pConnectionA
    end if

    if tError is empty then
      dbsynch_schemaWithDatabase pConnectionA, pDBKey
      put the result into tError
    end if
  catch tError

  finally
    if there is a stack pStackFilename then
      delete stack pStackFilename
    end if
  end try

  if tError is empty then
    dbconn_commitTransaction empty, pConnectionA
  else
    dbconn_rollbackTransaction empty, pConnectionA
  end if

  return tError for error
end dbschema_processMigrationFile


/**
Summary:

*/
command dbschema_processMigrationArray pMigrationVersion, pMigrationA, pConnectionA, pDBKey
  local tError, tTableA, tIndexA, tFieldA, tFieldsA

  _beginProcessMigration pMigrationVersion, pConnectionA, pDBKey
  put the result into tError

  try
    if tError is empty then
      repeat for each element tTableA in pMigrationA["migration"]["create tables"]

        # Get fields into format that API expects
        if tTableA["field order"] is empty then
          repeat for each element tFieldA in tTableA["fields"]
            put tFieldA["name"] & "," after tTableA["field order"]
            put tFieldA into tFieldsA[tFieldA["name"]]
          end repeat
          delete the last char of tTableA["field order"]
        end if
        put tFieldsA into tTableA["fields"]

        dbschema_createTable tTableA["name"], tTableA, pConnectionA, pDBKey
        put the result into tError

        if tError is not empty then exit repeat
      end repeat
    end if

    if tError is empty then
      repeat for each element tTableA in pMigrationA["migration"]["create fields"]
        dbschema_createFields tTableA["table"], tTableA["fields"], pConnectionA, pDBKey
        put the result into tError

        if tError is not empty then exit repeat
      end repeat
    end if

    if tError is empty then
      repeat for each element tIndexA in pMigrationA["migration"]["create indexes"]
        dbschema_createIndex tIndexA["name"], tIndexA, pConnectionA, pDBKey
        put the result into tError

        if tError is not empty then exit repeat
      end repeat
    end if

    if tError is empty then
      dbschema_createTriggers pConnectionA
      put the result into tError
    end if

    if tError is empty then
      _endProcessMigration pMigrationVersion, pConnectionA
    end if

    if tError is empty then
      dbsynch_schemaWithDatabase pConnectionA, pDBKey
      put the result into tError
    end if

    if tError is empty then
      local tRecA, tField

      repeat for each element tTableA in pMigrationA["migration"]["create records"]
        repeat for each element tRecordA in tTableA["records"]
          put sqlrecord_createObject(tTableA["table"], pConnectionA, pDBKey) into tRecA
          repeat for each key tField in tRecordA
            sqlrecord_set tRecA, tField, tRecordA[tField]
          end repeat
          sqlrecord_create tRecA
          put the result into tError

          if tError is not empty then exit repeat
        end repeat

        if tError is not empty then exit repeat
      end repeat
    end if
  catch tError

  end try

  if tError is empty then
    dbconn_commitTransaction empty, pConnectionA
  else
    dbconn_rollbackTransaction empty, pConnectionA
  end if

  return tError for error
end dbschema_processMigrationArray


private command _beginProcessMigration pMigrationVersion, @rConnectionA, pDBKey
  local tError

  put dbobject_createConnectionArray(rConnectionA, pDBKey) into rConnectionA

  dbconn_connect rConnectionA
  put the result into tError

  if tError is empty then
    dbconn_beginTransaction empty, rConnectionA
    put the result into tError
  end if

  if tError is empty then
    _createSchemaMigrationsTable rConnectionA
    put the result into tError
  end if

  if tError is empty then
    _checkSchemaMigrationShouldRun pMigrationVersion, rConnectionA
    put the result into tError
  end if

  return tError
end _beginProcessMigration


private command _endProcessMigration pMigrationVersion, pConnectionA
  local tError

  if tError is empty then
    _insertSchemaMigration pMigrationVersion, pConnectionA
    put the result into tError
  end if

  return tError
end _endProcessMigration


private command _checkSchemaMigrationShouldRun pMigrationVersion, pConnectionA
  local tError

  if tError is empty then
    local tSQL, tVersion

    put _getCurrentSchemaVersion(pConnectionA) into tVersion
    put the result into tError
  end if

  if tError is empty then
    if tVersion >= pMigrationVersion then
      put "migration has already been applied" into tError
    end if
  end if

  return tError for error
end _checkSchemaMigrationShouldRun


private command _insertSchemaMigration pMigrationVersion, pConnectionA
  local tError
  local tSQL, tBindingsA, tRecords

  if tError is empty then
    local theAffectedRows

    put pMigrationVersion + 0 into tBindingsA[1]

    put "UPDATE schema SET version = :1" into tSQL
    dbconn_executeWBindings tSQL, tBindingsA, pConnectionA
    put it into theAffectedRows
    put _ErrorMsg("unable to update schema version info", the result) into tError

    if theAffectedRows is 0 then
      put "INSERT INTO schema (version) VALUES (:1)" into tSQL
      dbconn_executeWBindings tSQL, tBindingsA, pConnectionA
      put _ErrorMsg("unable to update schema version info", the result) into tError
    end if
  end if

  return tError for error
end _insertSchemaMigration


private function _listTables pConnectionA
  local tConnID, tTables, tError

  put dbconn_get("connection id", pConnectionA) into tConnID

  if dbconn_get("type", pConnectionA) is "valentina" then
    local tTableCount, tTableRef

    put VDatabase_TableCount( tConnID ) into tTableCount
    repeat with i = 1 to tTableCount
      put VDatabase_Table( tConnID, i) into tTableRef
      put VTable_Name( tTableRef) & cr after tTables
    end repeat
    delete the last char of tTables
    put _valentinaErrorSchema(tConnID) into tError
  else
    if dbconn_get("type", pConnectionA) is "mysql" then
      put revDataFromQuery(tab, cr, tConnID, "SHOW TABLES") into tTables
    else
      put revDatabaseTableNames(tConnID) into tTables
    end if
    if item 1 of tTables is "revdberr" then
      put _ErrorMsg("retrieving database tables", item 2 to -1 of tTables) into tError
    end if
  end if

  if tError is empty then
    return tTables for value
  else
    return tError for error
  end if
end _listTables


/**
Summary: Returns the current version number of the database.

Parameters:
pConnectionA: A connection array.

Description:
This function returns 0 if the `version` table does not exist.

Returns: Version or error in result.
*/
private function _getCurrentSchemaVersion pConnectionA
  local tError, tSQL, tBindingsA
  local tVersion = "0"

  if "schema" is among the lines of _listTables(pConnectionA) then
    put "SELECT version FROM schema" into tSQL
    dbconn_retrieveQueryAsData tSQL, tBindingsA, tVersion, empty, empty, pConnectionA
    put the result into tError
  end if

  if tError is empty then
    return tVersion for value
  else
    return tError for error
  end if
end _getCurrentSchemaVersion


private command _createSchemaMigrationsTable pConnectionA
  local tError, tDBTables, tSQL

  put revDatabaseTableNames(dbconn_get("connection id", pConnectionA)) into tDBTables
  if "schema" is not among the lines of tDBTables then
    put "CREATE TABLE schema (version varchar(255) NOT NULL UNIQUE)" into tSQL
    dbconn_executeSQL tSQL, pConnectionA
    put _ErrorMsg("unable to create schema table", the result) into tError
  end if

  return tError for error
end _createSchemaMigrationsTable


/**
Summary: Updates the physical database schema to the schema version specified.

Parameters:
pVersion: The version to upgrade the database schema to.

Description:
DEPRECATED

Returns: Error messages
*/
command dbschema_migrateToVersion pVersion, pConnectionA, pDBKey
  local theError, theContainer, theVersions, theSQL

  put dbobject_createConnectionArray(pConnectionA, pDBKey) into pConnectionA
  put dbobject_get("schema migrations", pConnectionA["database"]) into theContainer

  repeat with i = 1 to the number of controls of theContainer
    put the short name of button i of theContainer & cr after theVersions
  end repeat
  delete the last char of theVersions
  sort lines of theVersions numeric by word 2 to -1 of each

  if theError is empty then
    dbconn_beginTransaction empty, pConnectionA
    put the result into theError
  end if

  if theError is empty then
    local theConnId, theQuotesA

    put dbconn_get("connection id", pConnectionA) into theConnID
    put dbconn_get("quotes") into theQuotesA

    set the wholeMatches to true
    if "schema" is not among the lines of revDatabaseTableNames(theConnID) then
      put "CREATE TABLE " & theQuotesA["left"] & "schema" & theQuotesA["right"] & " (version integer NOT NULL)" into theSQL
      dbconn_executeSQL theSQL, pConnectionA
      put the result into theError

      if theError is empty then
        put format("INSERT INTO %sschema%s (version) VALUES(0)", theQuotesA["left"], theQuotesA["right"]) into theSQL
        dbconn_executeSQL theSQL, pConnectionA
        put the result into theError
      end if
    end if
  end if

  if theError is empty then
    local theBindingsA, theInstalledVersion

    put format("SELECT version FROM %sschema%s", theQuotesA["left"], theQuotesA["right"]) into theSQL
    put empty into theBindingsA
    dbconn_retrieveQueryAsData theSQL, theBindingsA, theInstalledVersion, tab, cr, pConnectionA
    put the result into theError
  end if

  if theError is empty then
    local theControlName, theVersion, theLastInstalledVersion

    repeat for each line theControlName in theVersions
      put word 2 of theControlName into theVersion
      if theVersion > pVersion then exit repeat

      if theVersion > theInstalledVersion then
        try
          dispatch "InstallSchemaVersion" to button ("Version" && theVersion) of theContainer with pConnectionA
        catch theError
        end try
      end if

      if theError is empty then
        put theVersion into theLastInstalledVersion
      end if

      if theError is not empty then exit repeat
    end repeat
  end if

  if theError is empty then
    ## Don't update if last installed version < installed version. May be running old version
    ## of software and trying to upgrade to latest vesion caused error because
    ## table/fields already existed.
    if theLastInstalledVersion > theInstalledVersion then
      put format("UPDATE %sschema%s SET version = " & theLastInstalledVersion, theQuotesA["left"], theQuotesA["right"]) into theSQL
      dbconn_executeSQL theSQL, pConnectionA
      put the result into theError
    end if
  end if

  if theError is empty then
    dbconn_commitTransaction empty, pConnectionA
    put the result into theError
  else
    dbconn_rollbackTransaction empty, pConnectionA
  end if

  if theError is empty then
    local theType, theDo

    ## Let db clean up
    put dbconn_get("type", pConnectionA) into theType

    replace space with empty in theType
    put "_" & theType & "_afterMigration pConnectionA" into theDo
    do theDo
    put the result into theError
  end if

  return theError
end dbschema_migrateToVersion


## Creates a table in the database
command dbschema_createTable pName, pTableA, pConnectionA, pDBKey
  local theError, theType, theEncoding

  -- pTableA["primary key"]
  -- pTableA["fields"]
  -- pTableA["foreign keys"]
  -- pTableA["indexes"]
  put dbobject_createConnectionArray(pConnectionA, pDBKey) into pConnectionA
  put dbconn_get("type", pConnectionA) into theType

  ## Get effective encoding
  put pTableA["encoding"] into theEncoding
  if theEncoding is empty then put dbobject_get("encoding", pConnectionA["database"]) into theEncoding
  put theEncoding into pTableA["encoding"]

  if theError is empty then
    ## fill in encoding and check for primary key field
    repeat for each key theKey in pTableA["fields"]
      if pTableA["fields"][theKey]["encoding"] is empty then
        put theEncoding into pTableA["fields"][theKey]["encoding"]
      end if

      if pTableA["primary key"] is empty and pTableA["fields"][theKey]["name"] is "id" then
        put "id" into pTableA["primary key"]
      end if
    end repeat
  end if

  if theError is empty then
    local theDo

    replace space with empty in theType
    put "_" & theType & "_dbCreateTable pName, pTableA, pConnectionA" into theDo
     do theDo
     put _ErrorMsg("unable to create table '" & pName & "'", the result) into theError
  end if

  if theError is empty then
    local theIndexA

    repeat with i = 1 to the number of elements of pTableA["indexes"]
      put pTableA["indexes"][i] into theIndexA
      if theIndexA["table"] is empty then
        put pName into theIndexA["table"]
      end if

      dbschema_createIndex theIndexA["name"], theIndexA, pConnectionA
      put the result into theError

      if theError is not empty then exit repeat
    end repeat
  end if

  return theError
end dbschema_createTable


command dbschema_deleteTable pName

end dbschema_deleteTable


command dbschema_createFields pTable, pFieldsA, pConnection, pDBKey
  local theError, theConnectionA
  local theType, theEncoding

  -- name
  -- type
  -- length
  -- accepts null
  -- default value
  put dbobject_createConnectionArray(pConnection, pDBKey) into theConnectionA
  put dbconn_get("type", theConnectionA) into theType

  ## Get effective encoding
  put dbobject_get("encoding", theConnectionA["database"]) into theEncoding

  if theError is empty then
    ## fill in encoding for fields
    repeat for each key theKey in pFieldsA
      if pFieldsA[theKey]["encoding"] is empty then
        put theEncoding into pFieldsA[theKey]["encoding"]
      end if
    end repeat
  end if

  if theError is empty then
    local theDo

    replace space with empty in theType
    put "_" & theType & "_dbCreateFields pTable, pFieldsA, theConnectionA" into theDo
    do theDo
    put _ErrorMsg("unable to add fields", the result) into theError
  end if

  # sync schema with table changes
  if theError is empty then
    dbschema_tableSet pTable, empty, empty, theConnectionA["database"]
    dbsynch_schemaImportTable theConnectionA, pTable
    put the result into theError
  end if

  return theError
end dbschema_createFields


command dbschema_deleteFields pTable, pFields, pConnection, pDBKey
  local theError, theConnectionA, theType, theDo

  put dbobject_createConnectionArray(pConnection, pDBKey) into theConnectionA
  put dbconn_get("type", theConnectionA) into theType

  replace space with empty in theType
  put "_" & theType & "_dbDeleteFields pTable, pFields, theConnectionA" into theDo
  do theDo
  put the result into theError

  # Sync schema with table changes
  if theError is empty then
    dbschema_tableSet pTable, empty, empty, theConnectionA["database"]
    dbsynch_schemaImportTable theConnectionA, pTable
    put the result into theError
  end if

  return theError
end dbschema_deleteFields


command dbschema_createIndex pName, pIndexA, pConnection, pDBKey
  local theError, theConnectionA, theType, theDo

  -- table
  -- type (unique, simple, fulltext, spatial)
  -- length
  -- fields[1].."name", "length", "sort order", "collation"
  -- indexing method (btree, hash, rtree)

  put dbobject_createConnectionArray(pConnection, pDBKey) into theConnectionA
  put dbconn_get("type", theConnectionA) into theType

  replace space with empty in theType
  put "_" & theType & "_dbCreateTableIndexes pName, pIndexA, theConnectionA" into theDo
  do theDo
  put the result into theError

  return theError
end dbschema_createIndex


command dbschema_deleteIndex pIndexName, pTableName, pConnection, pDBKey
  local theError, theConnectionA, theType, theDo

  put dbobject_createConnectionArray(pConnection, pDBKey) into theConnectionA
  put dbconn_get("type", theConnectionA) into theType

  replace space with empty in theType
  put "_" & theType & "_dbDeleteIndex pIndexName, pTableName, pConnectionA" into theDo
  do theDo
  put the result into theError

  return theError
end dbschema_deleteIndex


command dbschema_createTriggers pConnection, pDBKey
  local theError, theConnectionA, theType, theDo

  put dbobject_createConnectionArray(pConnection, pDBKey) into theConnectionA
  put dbconn_get("type", theConnectionA) into theType

  replace space with empty in theType
  put "_" & theType & "_dbCreateForeignKeyConstraints theConnectionA" into theDo
  do theDo
  put the result into theError

  return theError
end dbschema_createTriggers


--> sql databases

# Makes any changes necessary to database to put it in synch with the current schema.
# No data will be lost.
command dbsynch_databaseWithSchema pConnectionA, pDBKey
  local i, theDBKey
  local theConnectionID
  local theDatabaseTables
  local theDBType
  local theSQL
  local theError
  local theTable, theTables
  local theVersion
  local theRecords

  put dbobject_createConnectionArray(pConnectionA, pDBKey) into pConnectionA

  set the wholeMatches to true
  dbconn_connect pConnectionA
  put _ErrorMsg("unable to connect to database", the result) into theError
  put it into theConnectionID

  if theError is empty then
    dbconn_beginTransaction empty, pConnectionA
    put the result into theError
  end if

  if theError is empty then
    put dbconn_get("type", pConnectionA) into theDBType
    put dbconn_get("database", pConnectionA) into theDBKey

    replace space with empty in theDBType

    put revDatabaseTableNames(theConnectionID) into theDatabaseTables
    if item 1 of theDatabaseTables is "revdberr" then
      put _ErrorMsg("failed to retrieve database table names", item 2 to -1 of theDatabaseTables) into theError
    end if
  end if

  ## CREATE OR ALTER TABLES THAT EXIST IN SCHEMA
  if theError is empty then
    put dbschema_get("tables", theDBKey) into theTables

    repeat for each line theTable in theTables
      if theTable is among the lines of theDatabaseTables then
        dbsynch_dbAlterTable theTable, pConnectionA
        put the result into theError
        if theError is not empty then
          exit repeat
        end if
      else
        dbsynch_dbCreateTable theTable, pConnectionA
        put the result into theError
        if theError is not empty then
          exit repeat
        end if
      end if
    end repeat
  end if

  ## ANY REMAINING FOREIGN KEY OPERATIONS (ACTUAL FOREIGN KEYS THROUGH ALTERTABLE, CREATE TRIGGERS, ETC.)
  if theError is empty then
    local theDo

    put "_" & theDBType & "_dbCreateForeignKeyConstraints pConnectionA" into theDo
    do theDo
    put the result into theError
  end if

  ## Update schema table
  if theError is empty then
    _createSchemaMigrationsTable pConnectionA
    put the result into theError
  end if

  if theError is empty then
    put dbschema_get("version", theDBKey) into theVersion

    _insertSchemaMigration theVersion, pConnectionA
    put the result into theError
  end if

  if theError is empty then
    dbconn_commitTransaction empty, pConnectionA
  else
    dbconn_rollbackTransaction empty, pConnectionA
  end if

  return theError
end dbsynch_databaseWithSchema


# Puts active schema in synch with database
command dbsynch_schemaWithDatabase pConnectionA, pDBKey
  -----
  local theConnectionID
  local theError
  local theSchemaTables
  local theTable, theTableA
  local theTables
  -----
  put dbobject_createConnectionArray(pConnectionA, pDBKey) into pConnectionA

  set the wholeMatches to true

  put dbconn_get("connection id", pConnectionA) into theConnectionID

  if theConnectionID < 1 then
    -- dbconn_connect pConnectionA
    put "you must connect to the database before importing the schema" into theError
  end if

  if theError is empty then
    put _listTables(pConnectionA) into theTables
  end if

  if theError is empty then
    dbschema_reset pConnectionA["database"]

    ## Import tables
    repeat for each line theTable in theTables
      dbsynch_schemaImportTable pConnectionA, theTable
    end repeat

    # Set version
    dbschema_set "version", _getCurrentSchemaVersion(pConnectionA), pConnectionA["database"]
  end if

  return theError
end dbsynch_schemaWithDatabase


on dbsynch_dbDropTable pConnectionA, pTable
  local theDBType
  local theError
  local theSQL

  put dbconn_get("type", pConnectionA) into theDBType
  set the wholeMatches to true

  put format("DROP TABLE IF EXISTS '%s'", pTable) into theSQL
  dbconn_executeSQL theSQL, pConnectionA
  put _ErrorMsg("unable to drop table '" & pTable & "'", the result) into theError

  return theError
end dbsynch_dbDropTable


command dbsynch_dbCreateTable pTableName, pConnectionA
  local theDBType
  local theSQL
  local theError
  local theTableA

  ## NO FIELDS, NO CREATE
  if dbschema_tableGet(pTableName, "fields", pConnectionA["database"]) is empty then return empty

  -- put dbconn_get("type", pConnectionA) into theDBType
  -- replace space with empty in theDBType

  ## CREATE TABLE
  put dbsynch_createTableSQL(pTableName, pConnectionA) into theSQL

  if theSQL is not empty then
    dbconn_executeSQL theSQL, pConnectionA
    put _ErrorMsg("unable to create table '" & pTableName & "'", the result) into theError
  else
    put format("error getting CREATE TABLE sql for table \"%s\"",  pTableName) into theError
  end if

  -- ## INDEXES
  -- if theError is empty then
  --   local theDo

  --   put "_" & theDBType & "_dbCreateTableIndexes pConnectionA, pTableA" into theDo
  --   do theDo
  --   put the result into theError
  -- end if

  return theError
end dbsynch_dbCreateTable


function dbsynch_createTableSQL pTableName, pConnectionA
  local theDBType, theDo
  local theTableA, theSQL, theHandler

  if dbschema_tableGet(pTableName, "fields", pConnectionA["database"]) is empty then return empty

  put dbschema_tableGet(pTableName,, pConnectionA["database"]) into theTableA

  put dbconn_get("type", pConnectionA) into theDBType
  replace space with empty in theDBType
  put "_" & theDBType & "_dbCreateTableSQL" into theHandler
  put "put" && theHandler && "(pTableName, theTableA, pConnectionA) into theSQL" into theDo
  do theDo

  return theSQL
end dbsynch_createTableSQL


command dbsynch_dbAlterTable pTableName, pConnectionA
  local theDBType, theDo, theHandler
  local theTableA, theError

  if dbschema_tableGet(pTableName, "fields", pConnectionA["database"]) is empty then return empty

  put dbschema_tableGet(pTableName,, pConnectionA["database"]) into theTableA

  put dbconn_get("type", pConnectionA) into theDBType
  replace space with empty in theDBType
  put "_" & theDBType & "_dbAlterTable" into theHandler
  put theHandler && "pTableName, theTableA, pConnectionA" into theDo
  do theDo
  put the result into theError

  return theError
end dbsynch_dbAlterTable


command dbsynch_schemaImportTable pConnectionA, pTable
  -----
  local i
  local theDBType, theSystemTables, theDo
  local theError
  local theField, theFieldA, theFields, theFieldsA, theIndexFields
  local theIndex, theIndexA, theIndexName
  local theIndexesA
  local theOldFieldsA, theOldIndexesA
  local theRelationshipsA
  local theTableA
  -----
  put dbconn_get("type", pConnectionA) into theDBType
  replace space with empty in theDBType

  ## FILTER OUT DB CREATED TABLES
  set the wholeMatches to true

  put "put _" & theDBType & "_systemTables() into theSystemTables" into theDo
  do theDo
  put the result into theSystemTables

  if pTable is among the lines of theSystemTables then
    return empty
  end if

  --> theArrayA["fields"]
  --> theArrayA["fields"][index]["length"] (string, text, binary, integer)
  --> theArrayA["fields"][index]["precision"] (decimal)
  --> theArrayA["fields"][index]["scale"] (decimal)
  --> theArrayA["fields"][index]["signed"]
  --> theArrayA["fields"][index]["primary key"]
  --> theArrayA["fields"][index]["fixed width"] (for string, specifies varchar or char)
  --> theArrayA["fields"][index]["default value"]
  --> theArrayA["fields"][index]["unique"]
  --> theArrayA["fields"][index]["accepts null"]
  if theError is empty then
    put "_" & theDBType & "_dbTableFields pConnectionA, pTable" into theDo
    do theDo
    put the result into theError
    put it into theTableA
  end if

  if theError is empty then
    put "_" & theDBType & "_dbTableIndexes pConnectionA, pTable, theFieldsA " into theDo
    do theDo
    put it into theIndexesA
  end if

  set the wholeMatches to true

  ## Assign meta type to fields
  repeat for each key theField in theTableA["fields"]
    put _NormalizeFieldType(theTableA["fields"][theField]["type"]) into theTableA["fields"][theField]["meta type"]
  end REPEAT

  ## Update list of primary key fields if need be. Multiple primary keys
  ## are stored as an index.
  repeat for each key theIndexName in theIndexesA["indexes"]
    if theIndexesA["indexes"][theIndexName]["primary key"] then
      put theIndexesA["indexes"][theIndexName]["fields"] into theFields
      split theFields by column
      replace cr with comma in theFields[1]
      put theFields[1] into theTableA["primary key"]
      exit repeat
    end if
  end repeat

  dbschema_addTableDefinition pTable, theTableA, pConnectionA["database"]
  put _ErrorMsg("adding table to schema", the result) into theError

  return theError
end dbsynch_schemaImportTable


-- splits a field type into type and length
-- values come out in parameters
command dbsynch_splitFieldType pFieldType, @rType, @rLength, @rSigned
  local theOffset

  put empty into rType
  put empty into rLength
  put empty into rSigned

  put offset("(", pFieldType) into theOffset
  if theOffset > 0 then
    put char 1 to theOffset - 1 of pFieldType into rType
    put char theOffset + 1 to offset(")", pFieldType) - 1 of pFieldType into rLength
  else
    put word 1 of pFieldType into rType
  end if
  put word 2 of pFieldType is "signed" into rSigned

  return empty
end dbsynch_splitFieldType


command dbsynch_dbTableCreateSQL pConnectionA, pTable
  -----
  local theColumn
  local theConnectionID
  local theCreateTableSQL
  local theCursor
  local theError
  local theQs,theSQL
  local theType
  -----
  put dbconn_get("connection id", pConnectionA) into theConnectionID
  put dbconn_get("type", pConnectionA) into theType
  put dbconn_get("quotes", pConnectionA) into theQs

  put theQs["left"] & pTable & theQs["right"] into pTable

  switch theType
    case "mysql"
      put "show create table" && pTable into theSQL
      put "Create Table" into theColumn
      break
    case "sqlite"
      put "SELECT sql FROM sqlite_master WHERE name =" && pTable & " AND type = 'table'" into theSQL
      put "sql" into theColumn
      break
    case "valentina"

      break
    case "postgresql"

      break
    case "sql server"

      break
  end SWITCH

  put revQueryDatabase(theConnectionID, theSQL) into theCursor
  if theCursor is an integer then
    put revDatabaseColumnNamed(theCursor, theColumn) into theCreateTableSQL
    revCloseCursor theCursor
  else
    put _ErrorMsg("unable to retrieve create table SQL from database", theCursor) into theError
  end if

  if theError is empty then
    return theCreateTableSQL for value
  else
    return theError for error
  end if
end dbsynch_dbTableCreateSQL


--> Driver: SQLite


private command _sqlite_dbTableFields pConnectionA, pTable
  -----
  local leftQ,rightQ,theA
  local theConnectionID
  local theCursor
  local theError
  local theField
  local thePrimaryKeys
  local theQuotesA
  local theSQL
  -----
  put dbconn_get("connection id", pConnectionA) into theConnectionID
  put dbconn_get("quotes", pConnectionA) into theQuotesA
  put theQuotesA["left"] into leftQ
  put theQuotesA["right"] into rightQ

  put "PRAGMA table_info(" & leftQ & pTable & rightQ & ")" into theSQL
  put revQueryDatabase(theConnectionID, theSQL) into theCursor
  if theCursor is not an integer then
    put _ErrorMsg("retrieving table fields", theCursor) into theError
  end if

  if theError is empty then
    if revQueryIsAtEnd(theCursor) then
      revCloseCursor theCursor
      put "no fields were returned for table '" & pTable & "'" into theError
    end if
  end if

  if theError is empty then
    -- Returns cid, name, type, notnull, dflt_value, pk
    repeat forever
      put revDatabaseColumnNamed(theCursor, "name") into theField

      put theField & comma after theA["field order"]

      put theField into theA["fields"][theField]["name"]
      put empty into theA["fields"][theField]["encoding"]
      put revDatabaseColumnNamed(theCursor, "dflt_value") into theA["fields"][theField]["default value"]
      ## An empty string would have a ''. Default to NULL
      if theA["fields"][theField]["default value"] is empty then put "NULL" into theA["fields"][theField]["default value"]
      put revDatabaseColumnNamed(theCursor, "notnull") is "0" into theA["fields"][theField]["accepts null"]  # value is 99 for null
      put revDatabaseColumnNamed(theCursor, "pk") > 0 into theA["fields"][theField]["primary key"]    # value is 0 for not primary
      put false into theA["fields"][theField]["unique"]
      if theA["fields"][theField]["primary key"] then
        put theField & comma after thePrimaryKeys
      end if

      ## Note: default value is wrapped in '' if a string. Or it could be something like CURRENT_DATE if it is a sqlite function.
      local theType, theLength, isSigned

      dbsynch_splitFieldType revDatabaseColumnNamed(theCursor, "Type"), theType, theLength, isSigned

      put theType into theA["fields"][theField]["type"]
      put theLength into theA["fields"][theField]["length"]
      put isSigned into theA["fields"][theField]["signed"]

      revMoveToNextRecord theCursor
      if the result is not true then exit REPEAT
    end repeat

    delete the last char of thePrimaryKeys
    put thePrimaryKeys into theA["primary key"]
    delete the last char of theA["field order"]

    ## INTEGER PRIMARY KEY IS AN AUTOINCREMENT IN SQLITE
    ## ALTHOUGH IT WILL REUSE NUMBERS
    ## AUTOINCREMENT KEYWORD MEANS THE TABLE WILL MAX OUT
    if the number of items of thePrimaryKeys is 1 then
      if theA["fields"][thePrimaryKeys]["type"] is "integer" then
        put "sequence" into theA["fields"][thePrimaryKeys]["type"]
        put empty into theA["fields"][thePrimaryKeys]["length"]
        put false into theA["fields"][thePrimaryKeys]["signed"]
        put true into theA["fields"][thePrimaryKeys]["unique"]    # primary has to be unique
      end if
    end if

    revCloseCursor theCursor
  end if

  if theError is empty then
    return theA for value
  else
    return theError for error
  end if
end _sqlite_dbTableFields


private command _sqlite_dbTableRelationships pConnectionA, pTable
  local theError, theConnectionID, theQuotesA, leftQ, rightQ
  local theSQL, theCursor

  put dbconn_get("connection id", pConnectionA) into theConnectionID
  put dbconn_get("quotes", pConnectionA) into theQuotesA
  put theQuotesA["left"] into leftQ
  put theQuotesA["right"] into rightQ

  -- create array of relationships the table has with other tables
  put "PRAGMA foreign_key_list(" & leftQ & pTable & rightQ & ")" into theSQL
  put revQueryDatabase(theConnectionID, theSQL) into theCursor
  if theCursor is not an integer then
    put _ErrorMsg("retrieving foreign key list", theCursor) into theError
  end if

  if theError is empty then
    if not revQueryIsAtEnd(theCursor) then
      local theIndex, theReferencedTable, theSourceColumns, theReferencedColumns, theA

      repeat forever
        add 1 to theIndex

        put revDatabaseColumnNamed(theCursor, "table") into theReferencedTable
        put revDatabaseColumnNamed(theCursor, "from") into theSourceColumns
        put revDatabaseColumnNamed(theCursor, "to") into theReferencedColumns

        put theSourceColumns into theA[theIndex]["from key"]
        put theReferencedTable into theA[theIndex]["to table"]
        put theReferencedColumns into theA[theIndex]["to key"]

        revMoveToNextRecord theCursor
        if the result is not true then exit repeat
      end repeat
    end if
    revCloseCursor theCursor
  end if

  if theError is empty then
    return theA for value
  else
    return theError for error
  end if
end _sqlite_dbTableRelationships


private command _sqlite_dbTableIndexes pConnectionA, pTable, pFieldsA
  -----
  local leftQ,rightQ
  local theA,theSQL
  local theConnectionID
  local theCursor, theCursor2
  local theError
  local theFieldName
  local theIndexName
  local theQuotesA
  local thisIsPrimaryKeyIndex
  -----
  put dbconn_get("connection id", pConnectionA) into theConnectionID
  put dbconn_get("quotes", pConnectionA) into theQuotesA
  put theQuotesA["left"] into leftQ
  put theQuotesA["right"] into rightQ

  put "PRAGMA index_list(" & leftQ & pTable & rightQ & ")" into theSQL
  put revQueryDatabase(theConnectionID, theSQL) into theCursor
  if theCursor is empty then put "no indexes for table" && pTable into theCursor
  if theCursor is not an integer then
    put _ErrorMsg("retrieving index list", theCursor) into theError
  end if

  if theError is empty then
    if not revQueryIsAtEnd(theCursor) then
      repeat forever
        put revDatabaseColumnNamed(theCursor, "name") into theIndexName
        put revDatabaseColumnNamed(theCursor, "unique") is 1 into theA["indexes"][theIndexName]["unique"]
        put true into thisIsPrimaryKeyIndex

        put "PRAGMA index_info(" & theIndexName & ")" into theSQL
        put revQueryDatabase( theConnectionID, theSQL) into theCursor2
        if not revQueryIsAtEnd(theCursor2) then
          repeat forever
            put revDatabaseColumnNamed(theCursor2, "name") into theFieldName
            put theFieldName into line (the number of lines of theA["indexes"][theIndexName]["fields"] + 1) \
                  of theA["indexes"][theIndexName]["fields"]

            if not pFieldsA["fields"][theFieldName]["primary key"] then put false into thisIsPrimaryKeyIndex

            revMoveToNextRecord theCursor2
            if the result is not true then exit repeat
          end repeat
        end if

        revCloseCursor theCursor2

        ## TODO: ADD CHECK FOR FULL TEXT
        if theA["indexes"][theIndexName]["unique"] then
          put "unique" into theA["indexes"][theIndexName]["style"]
        else
          put "simple" into theA["indexes"][theIndexName]["style"]
        end if

        put thisIsPrimaryKeyIndex into theA["indexes"][theIndexName]["primary key"]
        revMoveToNextRecord theCursor
        if the result is not true then exit REPEAT
      end repeat
    end if

    revCloseCursor theCursor
  end if

  if theError is empty then
    return theA for value
  else
    return theError for error
  end if
end _sqlite_dbTableIndexes


private function _sqlite_getFieldSQLType pFieldA
  local theType, theLimit, thePrecision, theScale, theSQLType

  put _effectiveFieldtype(pFieldA) into theType
  put pFieldA["length"] into theLimit
  put pFieldA["precision"] into thePrecision
  put pFieldA["scale"] into theScale

  put toupper(theType) into theSQLType

  switch theType
    case "text"
      if pFieldA["fixed width"] then
        put "CHAR" into theSQLType
        if theLimit is not an integer then
          put 255 into theLimit
        end if
      end if

      if theLimit is an integer then
        if theLimit <= 255 then
          if theSQLType is "text" then
            put "VARCHAR" into theSQLType
          end if
        end if

        put theSQLType & "(" & theLimit & ")" into theSQLType
      end if
      break

    case "float"
      put "REAL" into theSQLType
      break

    case "double precision"
      put "DOUBLE PRECISION" into theSQLType
      break

    case "decimal"
      if thePrecision is not an integer then
        put "10" into thePrecision
      end if
      if theScale is not an integer then
        put "2" into theScale
      end if
      put "DECIMAL (" & thePrecision & comma & theScale & ")" into theSQLType
      break

    case "date time"
      put "DATETIME" into theSQLType
      break

    case "binary"
      put "BLOB" into theSQLType
      break
  end switch

  return theSQLType
end _sqlite_getFieldSQLType


private function _sqlite_getFieldCollateType pFieldA
  local tCollation

  if pFieldA["charset"] is not empty then
    if pFieldA["charset"] is "binary" then
      put "BINARY" into tCollation
    else
      put "NOCASE" into tCollation
    end if
  else
    if pFieldA["type"] is "text" then
      put "NOCASE" into tCollation
    end if
  end if

  return tCollation
end _sqlite_getFieldCollateType


private command _sqlite_dbCreateTable pName, pTableA, pConnectionA
  local theError, theSQL

  put _sqlite_dbCreateTableSQL(pName, pTableA, pConnectionA) into theSQL
  dbconn_executeSQL theSQL, pConnectionA
  put the result into theError

  return theError
end _sqlite_dbCreateTable


private function _sqlite_dbCreateTableSQL pName, pTableA, pConnectionA
  local theQsA, theSQL, theField

  put dbconn_get("quotes", pConnectionA) into theQsA

  put "CREATE TABLE" && theQsA["left"] & pName & theQsA["right"] into theSQL
  put false into pTableA["@primary key is taken care of"]

  ## Fields
  put " (" after theSQL
  repeat for each item theField in pTableA["field order"]
    put _sqlite_getColumnDefSQL(pTableA, pTableA["fields"][theField]) after theSQL
    put comma & space after theSQL
  end repeat

  ## Primary key
  if pTableA["primary key"] is not empty and not pTableA["@primary key is taken care of"] then
    put " PRIMARY KEY(" & pTableA["primary key"] & "), " after theSQL
  end if

  ## Foreign keys
  if the keys of pTableA["foreign keys"] is not empty then
    put _sqlite_ForeignKeySQL(pTableA["foreign keys"], pConnectionA) after theSQL
    put ")" after theSQL
  else
    put ")" into char -2 to -1 of theSQL
  end if

  return theSQL
end _sqlite_dbCreateTableSQL


-- pTableA["@primary key is taken care of"] can be modified
function _sqlite_getColumnDefSQL @pTableA, pFieldA
  local theQsA, theSQLType, theCollation, theSQL

  put quote into theQsA["left"]
  put quote into theQsA["right"]
  put _sqlite_getFieldSQLType(pFieldA) into theSQLType
  put _sqlite_getFieldCollateType(pFieldA) into theCollation

  ## Name
  put theQsA["left"] & pFieldA["name"] & theQsA["right"] & space into theSQL

  if pFieldA["type"] is "sequence" \
        and (pTableA["primary key"] is pFieldA["name"] or pTableA["primary key"] is empty) then
    put "INTEGER PRIMARY KEY AUTOINCREMENT " after theSQL
    put pFieldA["name"] into pTableA["primary key"]
    put true into pTableA["@primary key is taken care of"]
  else
    put theSQLType & space after theSQL

    if "default" is among the keys of pFieldA then
      switch pFieldA["type"]
        case "boolean"
          if pFieldA["default"] is among the items of "0,false" then put "0" into pFieldA["default"]
          else if pFieldA["default"] is among the items of "1,true" then put "1" into pFieldA["default"]
          break
      end switch
      put "DEFAULT " & pFieldA["default"] & " " after theSQL
    end if

    if theCollation is not empty then
      put "COLLATE" && theCollation & " " after theSQL
    end if

    if pFieldA["accepts null"] is false then
      put "NOT NULL " after theSQL
    end if
  end if
  delete the last char of theSQL
  return theSQL
end _sqlite_getColumnDefSQL


private function _sqlite_ForeignKeySQL pForeignKeysA, pConnectionA
  local theError
  local theSQL, theQsA

  put dbconn_get("quotes", pConnectionA) into theQsA

  -- sqlyoga_addToArray theTableA["foreign keys"], "key:step_id", "references:steps", "on fields:id", "on delete:cascade", "on update:cascade"
  repeat with i = 1 to the number of elements of pForeignKeysA
    if pForeignKeysA[i]["name"] is not empty then
      put "CONSTRAINT " & pForeignKeysA[i]["name"] & " " after theSQL
    end if

    put "FOREIGN KEY (" & pForeignKeysA[i]["key"] & ") " & \
          "REFERENCES " & pForeignKeysA[i]["references"] & "(" & pForeignKeysA[i]["on fields"] & ")" after theSQL

    repeat for each item theItem in "on delete,on update"
      if pForeignKeysA[i][theItem] is not empty then
        put " " & toUpper(theItem) && pForeignKeysA[i][theItem] after theSQL
      end if
    end repeat

    put ", " after theSQL
  end repeat
  delete char -2 to -1 of theSQL

  return theSQL
end _sqlite_ForeignKeySQL


private command _sqlite_dbCreateFields pTable, pFieldsA, pConnectionA
  local theError, theQsA, theTableA, theBaseSQL, theSQL

  put dbconn_get("quotes", pConnectionA) into theQsA

  put empty into theTableA["primary key"]
  put true into theTableA["@primary key is taken care of"]

  put "ALTER TABLE " & theQsA["left"] & pTable & theQsA["right"] & " " into theBaseSQL

  repeat with i = 1 to the number of elements of pFieldsA
    put theBaseSQL & "ADD COLUMN " & _sqlite_getColumnDefSQL(theTableA, pFieldsA[i]) into theSQL
    dbconn_executeSQL theSQL, pConnectionA
    put the result into theError

    if theError is not empty then exit repeat
  end repeat

  return theError
end _sqlite_dbCreateFields


private command _sqlite_afterMigration pConnectionA
  local theError

  dbconn_executeSQL "VACUUM", pConnectionA
  put _ErrorMsg("creating new table", the result) into theError

  return theError
end _sqlite_afterMigration


private command _sqlite_dbDeleteFields pTable, pFields, pConnectionA
  local theError, theQsA
  local theOldCreateSQL, theTempTable
  local theTriggersA, theIndexesA, theOldFields, theNewFields, theItemNo
  local theSQL, theBindingsA, theCreateTableSQL

  -- CREATE TABLE
  -- INSERT INTO new table (select from old table)
  -- DROP ORIGINAL TABLE
  -- ALTER NAME OF NEW TABLE

  put dbconn_get("quotes", pConnectionA) into theQsA
  put "_tmp_" & pTable & "_tmp_" into theTempTable

  ## Preflight) Get current and new field names
  if theError is empty then
    put revDatabaseColumnNames( dbconn_get("connection id", pConnectionA), pTable) into theOldFields
    put theOldFields into theNewFields

    set the wholeMatches to true
    repeat for each item theField in pFields
      put itemOffset(theField, theNewFields) into theItemNo
      if theItemNo > 0 then
        delete item theItemNo of theNewFields
      end if
    end repeat
  end if

  ## 1) Grab triggers, indexes from existing table
  if theError is empty then
    put format("SELECT sql FROM sqlite_master WHERE type = 'trigger' AND tbl_name = '%s'", pTable) into theSQL
    dbconn_retrieveQueryAsArray theSQL,, theBindingsA, theTriggersA, pConnectionA
    put _ErrorMsg("retrieving table triggers", the result) into theError
  end if

  if theError is empty then
    put format("SELECT sql FROM sqlite_master WHERE type = 'index' AND tbl_name = '%s'", pTable) into theSQL
    dbconn_retrieveQueryAsArray theSQL,, theBindingsA, theIndexesA, pConnectionA
    put _ErrorMsg("retrieving table indexes", the result) into theError
  end if

  ## 2) Get Create table SQL
  if theError is empty then
    put "SELECT sql FROM sqlite_master WHERE type = 'table' AND tbl_name=" & theQsA["left"] & pTable & theQsA["right"] into theSQL
    dbconn_retrieveQueryAsData theSQL,, theCreateTableSQL,,, pConnectionA
    put the result into theError
  end if

  ## 2) Rename existing table.
  if theError is empty then
    put format("ALTER TABLE %s%s%s RENAME TO %s%s%s", theQsA["left"], pTable, theQsA["right"], \
          theQsA["left"], theTempTable, theQsA["right"]) into theSQL
    dbconn_executeSQL theSQL, pConnectionA
    put _ErrorMsg("renaming table", the result) into theError
  end if

  ## 3) Create new table
  if theError is empty then
    local theDefsA

    _getAllDefinitionsFromCreateSQL theCreateTableSQL
    put the result into theError
  end if

  if theError is empty then
    put it into theDefsA

    local theColumnName, theCharNo, theCharNo2

    repeat with i = the number of elements of theDefsA down to 1
      put empty into theColumnName

      ## Get rid of foreign key refs
      if word 1 to 2 of theDefsA[i]["definition"] is "FOREIGN KEY" then
        put offset("(", theDefsA[i]["definition"]) into theCharNo
        if theCharNo > 0 then
          put offset(")", theDefsA[i]["definition"]) into theCharNo2
          if theCharNo2 > 0 then
            put char theCharNo + 1 to theCharNo2 - 1 of theDefsA[i]["definition"] into theColumnName
          end if
        end if
      else if 1 is 0 then
        ## todo: check for indexes on column
      else
        ## Regular column
        put word 1 of theDefsA[i]["definition"] into theColumnName
      end if

      replace "'" with empty in theColumnName
      replace quote with empty in theColumnName
      replace "`" with empty in theColumnName

      if theColumnName is among the items of pFields then
        delete char theDefsA[i]["definition start char"] to theDefsA[i]["last char"] of theCreateTableSQL
      end if

      if theError is not empty then exit repeat
    end repeat
  end if


  if theError is empty then
    dbconn_executeSQL theCreateTableSQL, pConnectionA
    put _ErrorMsg("creating new table", the result) into theError
  end if

  ## 4) Copy data over to new table
  if theError is empty then
    -- INSERT INTO t1 SELECT a,b FROM t1_backup
    put format("INSERT INTO %s%s%s (rowid,%s) SELECT rowid,%s FROM %s%s%s", theQsA["left"], pTable, theQsA["right"], \
          theNewFields, theNewFields, \
          theQsA["left"], theTempTable, theQsA["right"]) into theSQL
    dbconn_executeSQL theSQL, pConnectionA
    put _ErrorMsg("removing temporary table", the result) into theError
  end if

  ## 5) Delete tmp table
  if theError is empty then
    put format("DROP TABLE %s%s%s", theQsA["left"], theTempTable, theQsA["right"]) into theSQL
    dbconn_executeSQL theSQL, pConnectionA
    put _ErrorMsg("removing temporary table", the result) into theError
  end if

  ## 6) Assign indexes and triggers
  if theError is empty then
    repeat with i = 1 to the number of elements of theIndexesA
      if theIndexesA[i]["sql"] is not empty then
        try
          dbconn_executeSQL theIndexesA[i]["sql"], pConnectionA
          put _ErrorMsg("adding indexes", the result) into theError
          if theError is not empty then exit repeat
        catch e
          ## in case column no longer exists
        end try
      end if
    end repeat
  end if

  if theError is empty then
    repeat with i = 1 to the number of elements of theTriggersA
      if theTriggersA[i]["sql"] is not empty then
        try
          dbconn_executeSQL theTriggersA[i]["sql"], pConnectionA
          put _ErrorMsg("adding triggers", the result) into theError
        catch e
          ## in case column no longer exists
        end try
        if theError is not empty then exit repeat
      end if
    end repeat
  end if

  return theError
end _sqlite_dbDeleteFields


command _sqlite_createSQLFromDB pTable, pCreateAs, pExcludeFields, pConnectionA
  local theSQL, theError
  local theTrailer, theQsA, theCreateSQL, theCreateTableSQL
  local theForeignKeysA, theTableA

  if pCreateAs is empty then put pTable into pCreateAs
  put dbconn_get("quotes", pConnectionA) into theQsA

  if theError is empty then
    put "SELECT sql FROM sqlite_master WHERE type = 'table' AND tbl_name=" & theQsA["left"] & pTable & theQsA["right"] into theSQL
    dbconn_retrieveQueryAsData theCreateSQL,, theCreateTableSQL,, pConnectionA
    put the result into theError
  end if

  set the wholeMatches to true

  ## Table columns
  if theError is empty then
    put "PRAGMA table_info(" & theQsA["left"] & pTable & theQsA["right"] & ")" into theSQL
    dbconn_retrieveQueryAsArray theSQL,,, theTableA, pConnectionA
    put the result into theError
  end if

  ## Foreign keys
  if theError is empty then
    ## Need to dig into the create SQL for this
    put "PRAGMA foreign_key_list(" & theQsA["left"] & theQsA["right"] & quote & ")" into theSQL
    dbconn_retrieveQueryAsArray theSQL,,, theForeignKeysA, pConnectionA
    put the result into theError
  end if

  if theError is empty then
    put "CREATE TABLE "  & theQsA["left"] & pCreateAs & theQsA["right"] & " (" into theSQL

    ## Column Definitions
    repeat with i = 1 to the number of elements of theTableA
      if theTableA[i]["name"] is among the items of pExcludeFields then next repeat

      put theTrailer after theSQL

      put quote & theTableA[i]["name"] & quote && theTableA[i]["type"] after theSQL
      if theTableA[i]["pk"] is "1" then
        ## is it autoincrementing?
        ## check create sql to see if AUTOINCREMENT appears.
        ## Note: you might be tempted to check the sqlite_sequence table for an entry but
        ## there will be no entry if no records have been added yet.
        put "SELECT sql FROM sqlite_master WHERE type = 'table' AND tbl_name = " & theQsA["left"] & pTable & theQsA["right"] into theCreateSQL
        dbconn_retrieveQueryAsData theCreateSQL,, theCreateTableSQL,, pConnectionA
        if theCreateTableSQL contains "autoincrement" then
          put " PRIMARY KEY AUTOINCREMENT" after theSQL
        else
          put " PRIMARY KEY" after theSQL
          if theTableA[i]["notnull"] > 0 then
            put " NOT NULL" after theSQL
          end if
          if theTableA[i]["dflt_value"] is not empty then
            put " DEFAULT " & theTableA[i]["dflt_value"] after theSQL
          end if
        end if

      else ## not primary key
        if theTableA[i]["notnull"] > 0 then
          put " NOT NULL" after theSQL
        end if
        if theTableA[i]["dflt_value"] is not empty then
          put " DEFAULT " & theTableA[i]["dflt_value"] after theSQL
        end if
      end if

      put ", " into theTrailer
    end repeat

    put ")" after theSQL
  end if

  if theError is empty then
    return theSQL for value
  else
    return theError for error
  end if
end _sqlite_createSQLFromDB


private command _getAllDefinitionsFromCreateSQL pSQL
  local theError, theDefsA, theDefinition, theDefStartCharNo, theDefEndCharNo, theLastCharNo
  local i = 0

  repeat forever
    add 1 to i
    put empty into theDefinition

    _extractDefinitionFromCreateSQL pSQL, i, theDefinition, theDefStartCharNo, theDefEndCharNo, theLastCharNo
    put the result into theError

    if theDefinition is empty then exit repeat

    if theError is empty then
      put theDefinition into theDefsA[i]["definition"]
      put theDefStartCharNo into theDefsA[i]["definition start char"]
      put theDefEndCharNo into theDefsA[i]["definition end char"]
      put theLastCharNo into theDefsA[i]["last char"]
    end if

    if theError is not empty then exit repeat
  end repeat

  if theError is empty then
    return theDefsA for value
  else
    return theError for error
  end if
end _getAllDefinitionsFromCreateSQL


private command _extractDefinitionFromCreateSQL pSQL, pDefNum, @rCreateDef, @rStartDefCharNo, @rEndDefCharNo, @rClosingCharNo
  local theError, theRootSearchCharNo, theCreateDef

  put offset("(", pSQL) into theRootSearchCharNo
  if theRootSearchCharNo is 0 then put "invalid sql statement: missing " & quote & "(" & quote into theError

  if theError is empty then
    add 1 to theRootSearchCharNo
    repeat pDefNum times
      ## root char no will be updated each time
      put _findNextCreateDef(pSQL, theRootSearchCharNo, rStartDefCharNo, rEndDefCharNo) into rCreateDef
      put theRootSearchCharNo into rClosingCharNo
      add 1 to theRootSearchCharNo
    end repeat
  end if

  return theError
end _extractDefinitionFromCreateSQL


private function _findNextCreateDef pSQL, @xRootSearchCharNo, @rStartCharNo, @rEndCharNo
  local theCreateDef, theChar, inQuotedSeq, theSeqQuote
  local theLastMatchedParenCharNo

  put 0 into rStartCharNo
  put 0 into rEndCharNo

  ## find actual starting char
  repeat with i = xRootSearchCharNo to the number of chars of pSQL
    if word 1 to -1 of (char i of pSQL) is not empty then
      put i into rStartCharNo
      put i into xRootSearchCharNo
      exit repeat
    end if
  end repeat

  repeat with i = xRootSearchCharNo to the number of chars of pSQL
    put char i of pSQL into theChar

    if not inQuotedSeq then
      if theChar is "," or theChar is ")" then
        ## all done
        put i into xRootSearchCharNo
        subtract 1 from i
        exit repeat
      else
        --            put theChar after theCreateDef
        put theChar is among the items of quote & ",',`,(" into inQuotedSeq
        if inQuotedSeq then
          put theChar into theSeqQuote
        end if
      end if
    else
      --         put theChar after theCreateDef

      ## in quoted sequence
      if theSeqQuote is "(" and theChar is ")" then
        put false into inQuotedSeq
        put i into theLastMatchedParenCharNo
      else if theChar is theSeqQuote then
        if char (i+1) of pSQL is theSeqQuote then
          add 1 to i
          put char i of pSQL after theCreateDef
        else
          put false into inQuotedSeq
        end if
      end if
    end if
  end repeat

  if rStartCharNo > 0 then
    repeat with i = i down to 1
      if char i of pSQL is not empty then
        put i into rEndCharNo
        exit repeat
      end if
    end repeat

    put char rStartCharNo to rEndCharNo of pSQL into theCreateDef
  end if

  return theCreateDef
end _findNextCreateDef


private command _sqlite_dbAlterTable pTable, pTableA, pConnectionA
  local theSQL
  local theConnID
  local theError
  local theField
  local theFieldsThatLiveAnotherDay
  local theNewCreateSQL, theNewFields
  local theOldFields, theOldCreateSQL
  local theBindingsA
  local theTempName

  put dbconn_get("connection id", pConnectionA) into theConnID

  put format("SELECT sql FROM sqlite_master WHERE name = '%s'", pTable) into theSQL
  dbconn_retrieveQueryAsData theSQL, theBindingsA, theOldCreateSQL, empty, empty, pConnectionA
  put _ErrorMsg("retrieving create sql for table alteration", the result) into theError

  if theError is empty then
    ## Get current and new field names
    put revDatabaseColumnNames(theConnID, pTable) into theOldFields
    put dbschema_tableGet(pTable, "fields", pConnectionA["database"]) into theNewFields

    ## Determine which fields will exist after the update. These are fields we can insert into.
    set the wholeMatches to true
    repeat for each line theField in theNewFields
      if theField is among the items of theOldFields then
        put theField & comma after theFieldsThatLiveAnotherDay
      end if
    end repeat
    delete the last char of theFieldsThatLiveAnotherDay

    ## Extra data from table we are altering
    put "_tmp_" & pTable & "_tmp_" into theTempName
    put "CREATE TEMPORARY table" && quote & theTempName & quote into word 1 to 3 of theOldCreateSQL
    put _sqlite_dbCreateTableSQL(pTable, pTableA, pConnectionA) into theNewCreateSQL

    put theOldCreateSQL & ";" & cr into theSQL
    put format("INSERT INTO %s (rowid,%s) SELECT rowid,%s FROM \"%s\";\n", \
          theTempName, theOldFields, theOldFields, pTable) after theSQL
    put "DROP TABLE" && quote & pTable & quote & ";" & cr after theSQL
    put theNewCreateSQL & ";" & cr after theSQL
    put format("INSERT INTO \"%s\" (rowid,%s) select rowid,%s from \"%s\";\n", \
          pTable, theFieldsThatLiveAnotherDay, theFieldsThatLiveAnotherDay, theTempName) after theSQL
    put "DROP TABLE" && quote & theTempName & quote & ";" after theSQL

    dbconn_executeSQL theSQL, pConnectionA
    put _ErrorMsg("alter table '" & pTable & "'", the result) into theError
  end if

  if theError is empty then
    ## INDEXES
    -- _sqlite_dbCreateTableIndexes pConnectionA, pTableA
    -- put the result into theError
  end if

  return theError
end _sqlite_dbAlterTable


private command _sqlite_dbCreateTableIndexes pName, pIndexA, pConnectionA
  local theQsA, theSQL, theError

  put dbconn_get("quotes", pConnectionA) into theQsA

  if pIndexA["type"] is "unique" then
    put "CREATE UNIQUE INDEX " into theSQL
  else
    put "CREATE INDEX " into theSQL
  end if

  -- NAME on "TABLE"
  put theQsA["left"] & pName & theQsA["right"] && "ON" && theQsA["left"] & pIndexA["table"] & theQsA["right"] after theSQL

  put " (" after theSQL
  repeat with i = 1 to the number of elements of pIndexA["fields"]
    if pIndexA["fields"][i]["sort order"] is "descending" then put "DESC" into pIndexA["fields"][i]["sort order"]
    else put "ASC" into pIndexA["fields"][i]["sort order"]

    put theQsA["left"] & pIndexA["fields"][i]["name"] & theQsA["right"] && pIndexA["fields"][i]["sort order"] & ", " after theSQL
  end repeat
  put ")" into char -2 to -1 of theSQL

  dbconn_executeSQL theSQL, pConnectionA
  put _ErrorMsg("unable to create index on table '" & pIndexA["table"] & "'", the result) into theError

  return theError
end _sqlite_dbCreateTableIndexes


private command _sqlite_dbDeleteIndex pIndexName, pTableName, pConnectionA
  local theError, theQsA, theSQL

  put dbconn_get("quotes", pConnectionA) into theQsA

  put "DROP INDEX " into theSQL
  put theQsA["left"] & pIndexName & theQsA["right"] after theSQL

  dbconn_executeSQL theSQL, pConnectionA
  put _ErrorMsg("unable to drop index '" & pTableName & "'", the result) into theError

  return theError
end _sqlite_dbDeleteIndex


private function _sqlite_systemTables
  return "sqlite_sequence"
end _sqlite_systemTables


## Creates comparison between each matching item in pLeftFields and pRightFields.
## Uses OLD for sqlite trigger
private function _sqlite_TriggerWhereConditionFromMultipleFields pLeftFields, pRightFields, pTriggerKeyWord
  -----
  local i,theSQL
  -----
  if pTriggerKeyWord is empty then put "OLD" into pTriggerKeyWord

  repeat with i = 1 to the number of items of pLeftFields
    put quote & item i of pLeftFields & quote && "= " & pTriggerKeyWord & "." & quote & item i of pRightFields & quote && "AND " after theSQL
  end repeat
  delete the last word of theSQL

  ## example: "left_1" = OLD."right_1" AND "left_2" = OLD."right_2"

  return theSQL
end _sqlite_TriggerWhereConditionFromMultipleFields


private command _sqlite_dbCreateForeignKeyConstraints pConnectionA
  local theError
  local theSQL, theQsA, theTablesA, theTableName, theDeleteStatements
  local theRelationsA, theR, theType, theUpdateAction, theDeleteAction
  local theLeftTable, theRightTable, theCrossRefTable
  local theTableKeyFields, theCrossRefKeyFields, theWhereCondition
  local theRightKeyFields, theLeftKeyFields

  #########
  ## STEP 1: CREATE delete_ TRIGGERS FOR many-to-many, one-to-one and one-to-many
  ## TO DO: one-to-one
  put dbconn_get("quotes", pConnectionA) into theQsA
  put tableobjects_get("tables", pConnectionA["database"]) into theTablesA

  repeat with i = 1 to the number of elements of theTablesA
    ## Skip aliases
    if tableobj_get(theTablesA[i], "type") is "alias" then next repeat
    put tableobj_get(theTablesA[i], "name") into theTableName
    put empty into theDeleteStatements

    put tableobj_get(theTablesA[i], "relationship indexes") into theRelationsA

    repeat with j = 1 to the number of elements of theRelationsA
      put theRelationsA[j] into theR

      put tblrelation_get(theR, "type") into theType
      put tblrelation_get(theR, "update action") into theUpdateAction
      put tblrelation_get(theR, "delete action") into theDeleteAction
      put tblrelation_get(theR, "left table") into theLeftTable
      put tblrelation_get(theR, "right table") into theRightTable
      -- put tblrelation_get(theR, "owner") into theOwner -- left, none or right (one-to-one)
      put tblrelation_get(theR, "cross-reference table") into theCrossRefTable

      ## Todo: Figure out what to do with update actions

      switch theType
        case "many-to-many"
          switch theDeleteAction
            case "restrict"
              ## Todo: Don't allow deletion of left/right until cross-ref has been deleted.
              break
            case "cascade"
              ## Todo: (Verify?) Delete record records from opposite table
              if theTableName is theLeftTable then
                put tblrelation_get(theR, "left table key") into theTableKeyFields
                put tblrelation_get(theR, "cross-reference table key for left table") into theCrossRefKeyFields
                put _sqlite_TriggerWhereConditionFromMultipleFields(theCrossRefKeyFields, theTableKeyFields, "OLD") into theWhereCondition
                put format("    DELETE FROM %s WHERE %s;\n", theCrossRefTable, theWhereCondition ) after theDeleteStatements

              else if theTableName is theRightTable then
                put tblrelation_get(theR, "right table key") into theTableKeyFields
                put tblrelation_get(theR, "cross-reference table key for right table") into theCrossRefKeyFields
                put _sqlite_TriggerWhereConditionFromMultipleFields(theCrossRefKeyFields, theTableKeyFields, "OLD") into theWhereCondition
                put format("    DELETE FROM %s WHERE %s;\n", theCrossRefTable, theWhereCondition) after theDeleteStatements
              end if
              break
            case "set null"
              ## todo: Set link in cross-ref table to NULL
              break
          end switch
          break

        case "one-to-many"
          switch theDeleteAction
            case "restrict"
              ## todo: Must delete right table records before deleting left table record
              break
            case "cascade"
              ## Delete right table records when deleting left table record
              if theTableName is theLeftTable then
                put tblrelation_get(theR, "right table key") into theRightKeyFields
                put tblrelation_get(theR, "left table key") into theLeftKeyFields
                put _sqlite_TriggerWhereConditionFromMultipleFields(theRightKeyFields, theLeftKeyFields, "OLD") into theWhereCondition
                put format("    DELETE FROM %s WHERE %s;\n", theRightTable, theWhereCondition ) after theDeleteStatements
              end if
              break
            case "set null"
              ## Set right table key to NULL when deleting left table record
              if theTableName is theLeftTable then
                put tblrelation_get(theR, "right table key") into theRightKeyFields
                put tblrelation_get(theR, "left table key") into theLeftKeyFields
                put _sqlite_TriggerWhereConditionFromMultipleFields(theRightKeyFields, theLeftKeyFields, "OLD") into theWhereCondition
                put format("    UPDATE %s SET %s = NULL WHERE %s;\n", \
                      theRightTable, theRightKeyFields, theWhereCondition ) after theDeleteStatements
              end if
              break
          end switch
          break

        case "one-to-one"
          switch theDeleteAction
            case "restrict"
              ## todo: Don't allow owner to be deleted until ownee is deleted
              break
            case "cascade"
              ## todo: When the owner is deleted then delete ownee
              -- if theTableName is theTable1Name then
              -- put format("    DELETE FROM %s WHERE %s = OLD.%s;\n", \
                  -- theTable2Name, relationobject_getProp(theObject, "right table key"), \
                  -- relationobject_getProp(theObject, "left table key") ) after theDeleteStatements
              -- end if
              break
            case "set null"
              ## todo: Set ownee to NULL when owner is deleted
              break
          end switch
          break
      end switch

    end repeat ## relationships

    if theDeleteStatements is not empty then
      put tableobj_get(theTablesA[i], "name") into theTableName

      ## DELETE ANY EXISTING TRIGGER
      put "DROP TRIGGER IF EXISTS delete_" & theTableName into theSQL
      dbconn_executeSQL theSQL, pConnectionA
      put the result into theError

      if theError is empty then
        ## CREATE TRIGGER
        put format("CREATE TRIGGER delete_%s AFTER DELETE ON %s\n", theTableName, theQsA["left"] & theTableName & theQsA["right"]) into theSQL
        put "FOR EACH ROW BEGIN" & cr after theSQL
        put theDeleteStatements after theSQL
        put "END" after theSQL

        dbconn_executeSQL theSQL, pConnectionA
        put the result into theError
      end if
    end if
    ## END STEP 1
    ##############

    if theError is not empty then exit repeat
  end repeat ## tables

  return theError
end _sqlite_dbCreateForeignKeyConstraints


--> Driver: MySQL


private command _mysql_dbTableFields pConnectionA, pTable
  local theError, theArrayA, theConnectionID, theCursor, theField
  local thePrimaryKeys, theSQL, theQs, theA

  put dbconn_get("connection id", pConnectionA) into theConnectionID
  put dbconn_get("quotes", pConnectionA) into theQs

  put "SHOW FULL COLUMNS FROM" && theQs["left"] & pTable & theQs["right"] into theSQL
  put revQueryDatabase(theConnectionID, theSQL) into theCursor
  if theCursor is not an integer then
    put _ErrorMsg("retrieving mysql table fields", theCursor) into theError
  end if

  if theError is empty then
    if revQueryIsAtEnd(theCursor) then
      revCloseCursor theCursor
      put "no fields were returned for table '" & pTable & "'" into theError
    end if
  end if

  if theError is empty then
    repeat forever
      put revDatabaseColumnNamed(theCursor, "Field") into theField

      put theField & comma after theA["field order"]

      -- if pTable is "steps" then
      -- -- put revDataFromQuery(tab, cr, theConnectionID, theSQL)
      -- answer revDatabaseColumnNamed(theCursor, "NULL")
      -- end if

      -- ODBC cuts off last char for Null and Key.
      -- Taking into account for testing
      put theField into theA["fields"][theField]["name"]
      put revDatabaseColumnNamed(theCursor, "Default") into theA["fields"][theField]["default value"]
      put revDatabaseColumnNamed(theCursor, "Collation") into theA["fields"][theField]["encoding"]
      if theA["fields"][theField]["encoding"] begins with "utf8" then put "utf8" into theA["fields"][theField]["encoding"]

      if theA["fields"][theField]["default value"] is empty then
        put "NULL" into theA["fields"][theField]["default value"]
      else if theA["fields"][theField]["default value"] is not "NULL" \
            and theA["fields"][theField]["default value"] is not a number \
            and theA["fields"][theField]["default value"] is not "CURRENT_TIMESTAMP"  then
        ## add quotes so we can pass directly to the database
        put "'" & theA["fields"][theField]["default value"] & "'" into theA["fields"][theField]["default value"]
      end if
      put revDatabaseColumnNamed(theCursor, "NULL") begins with "YE" into theA["fields"][theField]["accepts null"]
      put revDatabaseColumnNamed(theCursor, "Key") begins with "PR" into theA["fields"][theField]["primary key"]
      put revDatabaseColumnNamed(theCursor, "Key") begins with "UN" into theA["fields"][theField]["unique"]
      if theA["fields"][theField]["primary key"] then
        put theField & comma after thePrimaryKeys
      end if

      if revDatabaseColumnNamed(theCursor, "Extra") is "auto_increment" then
        put "sequence" into theA["fields"][theField]["type"]
        put empty into theA["fields"][theField]["length"]
        put false into theA["fields"][theField]["signed"]
      else
        local theType, theLength, isSigned

        dbsynch_splitFieldType revDatabaseColumnNamed(theCursor, "Type"), theType, theLength, isSigned
        put theType into theA["fields"][theField]["type"]
        put theLength into theA["fields"][theField]["length"]
        put isSigned into theA["fields"][theField]["signed"]
      end if

      revMoveToNextRecord theCursor
      if the result is not true then exit REPEAT
    end REPEAT

    delete the last char of thePrimaryKeys
    put thePrimaryKeys into theA["primary key"]
    delete the last char of theA["field order"]

    revCloseCursor theCursor
  end if

  if theError is empty then
    return theA for value
  else
    return theError for error
  end if
end _mysql_dbTableFields


private command _mysql_dbTableRelationships pConnectionA, pTable
  -----
  local theConnectionID
  local theQs
  local theError, theA
  -----
  put dbconn_get("connection id", pConnectionA) into theConnectionID
  put dbconn_get("quotes", pConnectionA) into theQs

  -- create array of relationships the table has with other tables
  -- put "PRAGMA foreign_key_list(" & leftQ & pTable & rightQ & ")" into theSQL
  -- put revQueryDatabase(theConnectionID, theSQL) into theCursor
  -- if theCursor is not an integer then
  -- put _ErrorMsg("retrieving foreign key list", theCursor) into theError
  -- end if

  -- if theError is empty then
  -- if not revQueryIsAtEnd(theCursor) then
  -- repeat forever
  -- add 1 to theIndex

  -- put revDatabaseColumnNamed(theCursor, "table") into theReferencedTable
  -- put revDatabaseColumnNamed(theCursor, "from") into theSourceColumns
  -- put revDatabaseColumnNamed(theCursor, "to") into theReferencedColumns

  -- put theSourceColumns into theA[theIndex]["from key"]
  -- put theReferencedTable into theA[theIndex]["to table"]
  -- put theReferencedColumns into theA[theIndex]["to key"]

  -- revMoveToNextRecord theCursor
  -- if the result is not true then exit repeat
  -- end repeat
  -- end if
  -- revCloseCursor theCursor
  -- end if

  if theError is empty then
    return theA for value
  else
    return theError for error
  end if
end _mysql_dbTableRelationships


private command _mysql_dbTableIndexes pConnectionA, pTable, pFieldsA
  local theError, theArrayA, theCollation, theConnectionID
  local theCursor, theIndexName, theSQL, theQs, theA

  put dbconn_get("connection id", pConnectionA) into theConnectionID
  put dbconn_get("quotes", pConnectionA) into theQs

  -- http://dev.mysql.com/doc/refman/5.0/en/show-index.html
  put "SHOW INDEX FROM" && pTable into theSQL
  put revQueryDatabase( theConnectionID, theSQL) into theCursor
  if theCursor is not an integer then
    put _ErrorMsg("retrieving mysql index list", theCursor) into theError
  end if

  if theError is empty then
    if not revdb_iseof(theCursor) then
      repeat forever
        put revDatabaseColumnNamed(theCursor, "Key_name") into theIndexName
        put revDatabaseColumnNamed(theCursor, "Non_unique") is 0 into theA["indexes"][theIndexName]["unique"]
        put revDatabaseColumnNamed(theCursor, "Column_name") into \
              line (the number of lines of theA["indexes"][theIndexName]["fields"] + 1) of theA["indexes"][theIndexName]["fields"]
        put revDatabaseColumnNamed(theCursor, "Collation") into theCollation
        put revDatabaseColumnNamed(theCursor, "Index_type") into theA["indexes"][theIndexName]["type"]

        ## TODO: ADD CHECK FOR FULL TEXT
        if theA["indexes"][theIndexName]["unique"] then
          put "unique" into theA["indexes"][theIndexName]["style"]
        else
          put "simple" into theA["indexes"][theIndexName]["style"]
        end if

        put theIndexName is "PRIMARY" into theA["indexes"][theIndexName]["primary key"]
        if theCollation is "A" then put "ascending" into theA["indexes"][theIndexName]["sort direction"]
        else put "descending" into theA["indexes"][theIndexName]["sort direction"]

        revMoveToNextRecord theCursor
        if the result is not true then exit REPEAT
      end repeat
    end if

    revCloseCursor theCursor
  end if

  if theError is empty then
    return theA for value
  else
    return theError for error
  end if
end _mysql_dbTableIndexes


private function _mysql_getFieldSQLType pFieldA
  local theType, theLimit, thePrecision, theScale, theSQLType

  -- boolean, decimal, float, double precision, integer, timestamp, date, date time, binary, sequence, list, text
  put _effectiveFieldtype(pFieldA) into theType
  put pFieldA["length"] into theLimit
  put pFieldA["precision"] into thePrecision
  put pFieldA["scale"] into theScale

  put theType into theSQLType

  switch theType
    case "text"
      if pFieldA["fixed width"] then
        put "CHAR" into theSQLType
        if theLimit is not an integer then
          put 255 into theLimit
        end if
      end if

      if theLimit is an integer then
        if theLimit <= 1024 then
          if theSQLType is "text" then
            put "VARCHAR" into theSQLType
          end if
        end if

        put theSQLType & "(" & theLimit & ")" into theSQLType
      end if
      break

    case "float"
      put "FLOAT" into theSQLType
      break

    case "double precision"
      put "DOUBLE PRECISION" into theSQLType
      break

    case "decimal"
      if thePrecision is not an integer then
        put "10" into thePrecision
      end if
      if theScale is not an integer then
        put "2" into theScale
      end if
      put theSQLType & "(" & thePrecision & comma & theScale & ")" into theSQLType
      break

    case "integer"
      if theLimit is not empty then
        put " (" & theLimit & ")" after theSQLType
      end if
      if not pFieldA["signed"] then
        put " UNSIGNED" after theSQLType
      end if
      break

    case "list"
      put "ENUM" into theSQLType
      break

    case "date time"
      put "DATETIME" into theSQLType
      break

    case "binary"
      put "blob" into theSQLType
      break
  end switch

  return theSQLType
end _mysql_getFieldSQLType


private function _mysql_systemTables
  return empty
end _mysql_systemTables


private command _mysql_dbCreateTable pName, pTableA, pConnectionA
  local theError, theQsA, theSQL

  put dbconn_get("quotes", pConnectionA) into theQsA

  put "CREATE TABLE" && theQsA["left"] & pName & theQsA["right"] into theSQL
  put false into pTableA["@primary key is taken care of"]

  ## Fields
  put " (" after theSQL
  repeat with i = 1 to the number of elements of pTableA["fields"]
    put _mysql_getColumnDefSQL(pTableA, pTableA["fields"][i]) after theSQL
    put comma & space after theSQL
  end repeat

  ## Primary key
  if pTableA["primary key"] is not empty and not pTableA["@primary key is taken care of"] then
    put " PRIMARY KEY(" & pTableA["primary key"] & "), " after theSQL
  end if

  ## Foreign keys
  if the keys of pTableA["foreign keys"] is not empty then
    put _mysql_ForeignKeySQL(pTableA["foreign keys"], pConnectionA) after theSQL
    put ")" after theSQL
  else
    put ")" into char -2 to -1 of theSQL
  end if

  ## Database type
  if pTableA["vendor"]["mysql"]["type"] is not empty then
    put " ENGINE = " & pTableA["vendor"]["mysql"]["type"] after theSQL
  else if the keys of pTableA["foreign keys"] is not empty then
    ## NOTE: InnoDB DOES NOT SUPPORT FULLTEXT INDEXES. WE MAY NEED TO TAKE THIS INTO ACCOUNT
    ## IN THE FUTURE
    put " ENGINE = InnoDB" after theSQL
  else
    put " ENGINE = MyISAM" after theSQL
  end if

  if theError is empty then
    dbconn_executeSQL theSQL, pConnectionA
    put the result into theError
  end if

  return theError
end _mysql_dbCreateTable


-- pTableA["@primary key is taken care of"] can be modified
function _mysql_getColumnDefSQL @pTableA, pFieldA
  local theQsA, theSQLType, theSQL

  put "`" into theQsA["left"]
  put "`" into theQsA["right"]
  put _mysql_getFieldSQLType(pFieldA) into theSQLType

  ## Name
  put theQsA["left"] & pFieldA["name"] & theQsA["right"] & space into theSQL

  if pFieldA["type"] is "sequence" \
        and (pTableA["primary key"] is pFieldA["name"] or pTableA["primary key"] is empty) then
    put "INT(11) UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY " after theSQL
    put pFieldA["name"] into pTableA["primary key"]
    put true into pTableA["@primary key is taken care of"]
  else
    put theSQLType & space after theSQL

    if "default" is among the keys of pFieldA then
      switch pFieldA["type"]
        case "boolean"
          if pFieldA["default"] is among the items of "0,false" then put "0" into pFieldA["default"]
          else if pFieldA["default"] is among the items of "1,true" then put "1" into pFieldA["default"]
          break
      end switch
      put "DEFAULT " & pFieldA["default"] & " " after theSQL
    end if

    if pFieldA["accepts null"] is false then
      put "NOT NULL " after theSQL
    end if
  end if
  delete the last char of theSQL
  return theSQL
end _mysql_getColumnDefSQL


private function _mysql_ForeignKeySQL pForeignKeysA, pConnectionA
  local theError
  local theSQL, theQsA

  put dbconn_get("quotes", pConnectionA) into theQsA

  -- sqlyoga_addToArray theTableA["foreign keys"], "key:step_id", "references:steps", "on fields:id", "on delete:cascade", "on update:cascade"
  repeat with i = 1 to the number of elements of pForeignKeysA
    if pForeignKeysA[i]["name"] is not empty then
      put "CONSTRAINT " & pForeignKeysA[i]["name"] & " " after theSQL
    end if

    put "FOREIGN KEY (" & pForeignKeysA[i]["key"] & ") " & \
          "REFERENCES " & pForeignKeysA[i]["references"] & "(" & pForeignKeysA[i]["on fields"] & ")" after theSQL
    --      if pForeignKeysA[i]["name"] is not empty then put " " after pForeignKeysA[i]["name"]

    --      put "FOREIGN KEY " & pForeignKeysA[i]["name"] & "(" & pForeignKeysA[i]["key"] & ") " & \
          --             "REFERENCES " & pForeignKeysA[i]["references"] & "(" & pForeignKeysA[i]["on fields"] & ")" after theSQL

    repeat for each item theItem in "on delete,on update"
      if pForeignKeysA[i][theItem] is not empty then
        put " " & toUpper(theItem) && pForeignKeysA[i][theItem] after theSQL
      end if
    end repeat

    put ", " after theSQL
  end repeat
  delete char -2 to -1 of theSQL

  return theSQL
end _mysql_ForeignKeySQL


private command _mysql_afterMigration pConnectionA
  return empty
end _mysql_afterMigration


private command _mysql_dbCreateFields pTable, pFieldsA, pConnectionA
  local theError, theQsA, theTableA
  local theBaseSQL, theSQL

  put dbconn_get("quotes", pConnectionA) into theQsA

  put empty into theTableA["primary key"]
  put true into theTableA["@primary key is taken care of"]

  put "ALTER TABLE " & theQsA["left"] & pTable & theQsA["right"] & " " into theBaseSQL

  repeat with i = 1 to the number of elements of pFieldsA
    put theBaseSQL & "ADD COLUMN " & _mysql_getColumnDefSQL(theTableA, pFieldsA[i]) into theSQL
    dbconn_executeSQL theSQL, pConnectionA
    put the result into theError

    if theError is not empty then exit repeat
  end repeat

  return theError
end _mysql_dbCreateFields


private command _mysql_dbDeleteFields pTable, pFields, pConnectionA
  local theError, theQsA, theBaseSQL, theSQL

  put dbconn_get("quotes", pConnectionA) into theQsA

  put "ALTER TABLE " & theQsA["left"] & pTable & theQsA["right"] & " " into theBaseSQL

  ## Mysql supports multiple drop statements in a single query
  ## could change later if desired.
  repeat for each item theField in pFields
    put theBaseSQL & "DROP COLUMN " & theQsA["left"] & theField & theQsA["right"] into theSQL
    dbconn_executeSQL theSQL, pConnectionA
    put the result into theError

    if theError is not empty then exit repeat
  end repeat

  return theError
end _mysql_dbDeleteFields


private command _mysql_dbAlterTable pConnectionA, pTableA

end _mysql_dbAlterTable


private command _mysql_dbCreateTableIndexes pName, pIndexA, pConnectionA
  local theError, theQsA, theSQL, theLimit

  put dbconn_get("quotes", pConnectionA) into theQsA

  switch pIndexA["type"]
    case "unique"
      put "CREATE UNIQUE INDEX " into theSQL
      break
    case "fulltext"
      put "CREATE FULLTEXT INDEX " into theSQL
      break
    case "spatial"
      put "CREATE SPATIAL INDEX " into theSQL
      break
    default
      put "CREATE INDEX " into theSQL
  end switch

  -- NAME on "TABLE"
  put theQsA["left"] & pName & theQsA["right"] && "ON" && theQsA["left"] & pIndexA["table"] & theQsA["right"] after theSQL

  put " (" after theSQL
  repeat with i = 1 to the number of elements of pIndexA["fields"]
    if pIndexA["fields"][i]["sort order"] is "descending" then put "DESC" into pIndexA["fields"][i]["sort order"]
    else put "ASC" into pIndexA["fields"][i]["sort order"]

    ## INDEXING TEXT OR BLOG COLUMNS REQUIRE SOME SORT OF INDEX VALUE.
    ## WE USE 20 IF THE SCHEMA DOESN'T SPECIFY ONE (RANDOM NUMBER I CHOSE)
    if pIndexA["fields"][i]["length"] > 0 then
      put " (" & pIndexA["fields"][i]["length"] & ")" into theLimit
    else if pIndexA["fields"][i]["type"] is among the items of "text,binary" then
      put " (" & 20 & ")" into theLimit
    end if

    ## TODO: COLLATION SUPPORT. WE DON'T HAVE METATYPES FOR COLLATIONS THOUGH
    put theQsA["left"] & pIndexA["fields"][i]["name"] & theQsA["right"] & theLimit \
          && pIndexA["fields"][i]["sort order"] & ", " after theSQL
  end repeat
  put ")" into char -2 to -1 of theSQL

  dbconn_executeSQL theSQL, pConnectionA
  put _ErrorMsg("unable to create index on table '" & pIndexA["table"] & "'", the result) into theError

  return theError
end _mysql_dbCreateTableIndexes


private command _mysql_dbDeleteIndex pIndexName, pTableName, pConnectionA
  local theError, theQsA, theSQL

  put dbconn_get("quotes", pConnectionA) into theQsA

  put "DROP INDEX " into theSQL
  put theQsA["left"] & pIndexName & theQsA["right"] && "ON" && theQsA["left"] & pTableName & theQsA["right"] after theSQL

  dbconn_executeSQL theSQL, pConnectionA
  put _ErrorMsg("unable to drop index '" & pTableName & "'", the result) into theError

  return theError
end _mysql_dbDeleteIndex


private command _mysql_dbCreateForeignKeyConstraints pConnectionA

end _mysql_dbCreateForeignKeyConstraints


--> Driver: PostGreSQL


private function _postgresql_getFieldSQLType pFieldA
  local theType, theLimit, thePrecision, theScale, theSQLType

  put _effectiveFieldtype(pFieldA) into theType
  put pFieldA["length"] into theLimit
  put pFieldA["precision"] into thePrecision
  put pFieldA["scale"] into theScale

  put theType into theSQLType

  switch theType
    case "text"
      if pFieldA["fixed width"] then
        put "character" into theSQLType
        if theLimit is not an integer then
          put 255 into theLimit
        end if
      else if theLimit > 0 then
        put "character varying" into theSQLType
      end if

      if theLimit > 0 then
        put "(" & theLimit & ")" after theSQLType
      end if
      break

    case "float"
      put "real" into theSQLType
      break

    case "double precision"
      put "double precision" into theSQLType
      break

    case "decimal"
      if thePrecision is not an integer then
        put "10" into thePrecision
      end if
      if theScale is not an integer then
        put "2" into theScale
      end if
      put theSQLType & "(" & thePrecision & comma & theScale & ")" into theSQLType
      break

    case "list"
      put "ENUM" into theSQLType
      break

    case "date time"
      put "timestamp" into theSQLType
      break

    case "binary"
      put "bytea" into theSQLType
      break
  end switch

  return theSQLType
end _postgresql_getFieldSQLType


private function _postgresql_systemTables
  return empty
end _postgresql_systemTables


private command _postgresql_dbCreateTable pName, pTableA, pConnectionA
  local theError, theQsA, theSQL

  put dbconn_get("quotes", pConnectionA) into theQsA

  put "CREATE TABLE" && theQsA["left"] & pName & theQsA["right"] into theSQL
  put false into pTableA["@primary key is taken care of"]

  ## Fields
  put " (" after theSQL
  repeat with i = 1 to the number of elements of pTableA["fields"]
    put _postgresql_getColumnDefSQL(pTableA, pTableA["fields"][i]) after theSQL
    put comma & space after theSQL
  end repeat

  ## Primary key
  if pTableA["primary key"] is not empty and not pTableA["@primary key is taken care of"] then
    put " PRIMARY KEY(" & pTableA["primary key"] & "), " after theSQL
  end if

  ## Foreign keys
  if the keys of pTableA["foreign keys"] is not empty then
    put _postgresql_ForeignKeySQL(pTableA["foreign keys"], pConnectionA) after theSQL
    put ")" after theSQL
  else
    put ")" into char -2 to -1 of theSQL
  end if

  if theError is empty then
    dbconn_executeSQL theSQL, pConnectionA
    put the result into theError
  end if

  return theError
end _postgresql_dbCreateTable


-- pTableA["@primary key is taken care of"] can be modified
function _postgresql_getColumnDefSQL @pTableA, pFieldA
  local theQsA, theSQL, theSQLType

  put quote into theQsA["left"]
  put quote into theQsA["right"]
  put _postgresql_getFieldSQLType(pFieldA) into theSQLType

  ## Name
  put theQsA["left"] & pFieldA["name"] & theQsA["right"] & space into theSQL

  if pFieldA["type"] is "sequence" \
        and (pTableA["primary key"] is pFieldA["name"] or pTableA["primary key"] is empty) then
    put "SERIAL PRIMARY KEY " after theSQL
    put pFieldA["name"] into pTableA["primary key"]
    put true into pTableA["@primary key is taken care of"]
  else
    put theSQLType & space after theSQL

    if "default" is among the keys of pFieldA then
      switch pFieldA["type"]
        case "boolean"
          if pFieldA["default"] is among the items of "0,false" then put "FALSE" into pFieldA["default"]
          else if pFieldA["default"] is among the items of "1,true" then put "TRUE" into pFieldA["default"]
          break
      end switch
      put "DEFAULT " & pFieldA["default"] & " " after theSQL
    end if

    if pFieldA["accepts null"] is false then
      put "NOT NULL " after theSQL
    end if
  end if
  delete the last char of theSQL
  return theSQL
end _postgresql_getColumnDefSQL


private function _postgresql_ForeignKeySQL pForeignKeysA, pConnectionA
  local theError
  local theSQL, theQsA

  put dbconn_get("quotes", pConnectionA) into theQsA

  -- sqlyoga_addToArray theTableA["foreign keys"], "key:step_id", "references:steps", "on fields:id", "on delete:cascade", "on update:cascade"
  repeat with i = 1 to the number of elements of pForeignKeysA
    if pForeignKeysA[i]["name"] is not empty then
      put "CONSTRAINT " & pForeignKeysA[i]["name"] & " " after theSQL
    end if

    put "FOREIGN KEY (" & pForeignKeysA[i]["key"] & ") " & \
          "REFERENCES " & pForeignKeysA[i]["references"] & "(" & pForeignKeysA[i]["on fields"] & ")" after theSQL

    repeat for each item theItem in "on delete,on update"
      if pForeignKeysA[i][theItem] is not empty then
        put " " & toUpper(theItem) && pForeignKeysA[i][theItem] after theSQL
      end if
    end repeat

    put ", " after theSQL
  end repeat
  delete char -2 to -1 of theSQL

  return theSQL
end _postgresql_ForeignKeySQL


private command _postgresql_afterMigration pConnectionA
  return empty
end _postgresql_afterMigration


private command _postgresql_dbCreateFields pTable, pFieldsA, pConnectionA
  local theError, theQsA, theTableA, theBaseSQL, theSQL

  put dbconn_get("quotes", pConnectionA) into theQsA

  put empty into theTableA["primary key"]
  put true into theTableA["@primary key is taken care of"]

  put "ALTER TABLE " & theQsA["left"] & pTable & theQsA["right"] & " " into theBaseSQL

  repeat with i = 1 to the number of elements of pFieldsA
    put theBaseSQL & "ADD COLUMN " & _postgresql_getColumnDefSQL(theTableA, pFieldsA[i]) into theSQL
    dbconn_executeSQL theSQL, pConnectionA
    put the result into theError

    if theError is not empty then exit repeat
  end repeat

  return theError
end _postgresql_dbCreateFields


private command _postgresql_dbDeleteFields pTable, pFields, pConnectionA
  local theError, theQsA, theBaseSQL, theSQL

  put dbconn_get("quotes", pConnectionA) into theQsA

  put "ALTER TABLE " & theQsA["left"] & pTable & theQsA["right"] & " " into theBaseSQL

  repeat for each item theField in pFields
    put theBaseSQL & "DROP COLUMN " & theQsA["left"] & theField & theQsA["right"] into theSQL
    dbconn_executeSQL theSQL, pConnectionA
    put the result into theError

    if theError is not empty then exit repeat
  end repeat

  return theError
end _postgresql_dbDeleteFields


private command _postgresql_dbAlterTable pConnectionA, pTableA

end _postgresql_dbAlterTable


private command _postgresql_dbCreateTableIndexes pName, pIndexA, pConnectionA
  local theError, theQsA, theSQL, theLimit

  put dbconn_get("quotes", pConnectionA) into theQsA

  switch pIndexA["type"]
    case "unique"
      put "CREATE UNIQUE INDEX " into theSQL
      break
    default
      put "CREATE INDEX " into theSQL
  end switch

  -- NAME on "TABLE"
  put theQsA["left"] & pName & theQsA["right"] && "ON" && theQsA["left"] & pIndexA["table"] & theQsA["right"] after theSQL

  put " (" after theSQL
  repeat with i = 1 to the number of elements of pIndexA["fields"]
    if pIndexA["fields"][i]["sort order"] is "descending" then put "DESC" into pIndexA["fields"][i]["sort order"]
    else put "ASC" into pIndexA["fields"][i]["sort order"]

    if pIndexA["fields"][i]["length"] > 0 then
      put " (" & pIndexA["fields"][i]["length"] & ")" into theLimit
    end if

    ## TODO: COLLATION SUPPORT. WE DON'T HAVE METATYPES FOR COLLATIONS THOUGH
    put theQsA["left"] & pIndexA["fields"][i]["name"] & theQsA["right"] & theLimit \
          && pIndexA["fields"][i]["sort order"] & ", " after theSQL
  end repeat
  put ")" into char -2 to -1 of theSQL

  dbconn_executeSQL theSQL, pConnectionA
  put _ErrorMsg("unable to create index on table '" & pIndexA["table"] & "'", the result) into theError

  return theError
end _postgresql_dbCreateTableIndexes


private command _postgresql_dbDeleteIndex pIndexName, pTableName, pConnectionA
  local theError, theQsA, theSQL

  put dbconn_get("quotes", pConnectionA) into theQsA

  put "DROP INDEX " into theSQL
  put theQsA["left"] & pIndexName & theQsA["right"] after theSQL

  dbconn_executeSQL theSQL, pConnectionA
  put _ErrorMsg("unable to drop index '" & pTableName & "'", the result) into theError

  return theError
end _postgresql_dbDeleteIndex


private command _postgresql_dbCreateForeignKeyConstraints pConnectionA

end _postgresql_dbCreateForeignKeyConstraints


private function _postgresql_ForeignKeySQL pForeignKeysA, pConnectionA
  local theError
  local theSQL, theQsA

  put dbconn_get("quotes", pConnectionA) into theQsA

  -- sqlyoga_addToArray theTableA["foreign keys"], "key:step_id", "references:steps", "on fields:id", "on delete:cascade", "on update:cascade"
  repeat with i = 1 to the number of elements of pForeignKeysA
    put "FOREIGN KEY (" & pForeignKeysA[i]["key"] & ") " & \
          "REFERENCES " & pForeignKeysA[i]["references"] & "(" & pForeignKeysA[i]["on fields"] & ")" after theSQL

    repeat for each item theItem in "on delete,on update"
      if pForeignKeysA[i][theItem] is not empty then
        put " " & toUpper(theItem) && pForeignKeysA[i][theItem] after theSQL
      end if
    end repeat

    put ", " after theSQL
  end repeat
  delete char -2 to -1 of theSQL

  return theSQL
end _postgresql_ForeignKeySQL


private command _postgresql_dbTableFields pConnectionA, pTable
  local theArrayA, theConnectionID, theCursor, theField
  local thePrimaryKeys, theQuotes, theSQL, theEncoding
  local theError, theQs

  set the wholeMatches to true

  put dbconn_get("connection id", pConnectionA) into theConnectionID
  put dbconn_get("quotes", pConnectionA) into theQs
  put false into pConnectionA["import schema"] ## no recursion, thank you

  ## primary key
  if theError is empty then
    ## PRIMARY KEY
    put "SELECT c.COLUMN_NAME FROM information_schema.table_constraints pk, " & \
          "information_schema.key_column_usage c " & \
          "WHERE pk.table_name = '" & pTable & "' " & \
          "AND CONSTRAINT_TYPE = 'PRIMARY KEY' " & \
          "AND c.TABLE_NAME = pk.TABLE_NAME " & \
          "AND c.CONSTRAINT_NAME = pk.CONSTRAINT_NAME" into theSQL
    put false into pConnectionA["import schema"] ## no recursion, thank you
    dbconn_retrieveQueryAsData theSQL, empty, thePrimaryKeys, empty, comma, pConnectionA
    put the result into theError
  end if

  if theError is empty then
    ## Get DB encoding to assign to fields
    put "SHOW SERVER_ENCODING" into theSQL
    dbconn_retrieveQueryAsData theSQL, empty, theEncoding, empty, comma, pConnectionA
    put the result into theError

    if theError is empty then
      put tolower(theEncoding) into theEncoding
    end if
  end if

  if theError is empty then
    put "SELECT * FROM information_schema.columns " & \
          "WHERE table_schema != 'information_schema' AND table_name = '" & pTable & "' " & \
          "ORDER BY ordinal_position" into theSQL
    put revQueryDatabase(theConnectionID, theSQL) into theCursor
    if theCursor is not an integer then
      put _ErrorMsg("retrieving postgresql table fields", theCursor) into theError
    end if
  end if

  if theError is empty then
    if revQueryIsAtEnd(theCursor) then
      revCloseCursor theCursor
      put "no fields were returned for table '" & pTable & "'" into theError
    end if
  end if

  if theError is empty then
    local theA, theChar

    repeat forever
      put revDatabaseColumnNamed(theCursor, "column_name") into theField

      put theField & comma after theA["field order"]

      put theField into theA["fields"][theField]["name"]
      put theEncoding into theA["fields"][theField]["encoding"]

      put revDatabaseColumnNamed(theCursor, "column_default") into theA["fields"][theField]["default value"]
      if theA["fields"][theField]["default value"] is empty then put "NULL" into theA["fields"][theField]["default value"]
      put revDatabaseColumnNamed(theCursor, "is_nullable") is "YES" into theA["fields"][theField]["accepts null"]
      put theField is among the items of thePrimaryKeys into theA["fields"][theField]["primary key"]

      ## Cleanse ::character...
      repeat with i = the number of chars of theA["fields"][theField]["default value"] down to 1
        put char i of theA["fields"][theField]["default value"] into theChar
        if theChar is "'" then exit repeat
        if theChar is ":" and (char i-1 of theA["fields"][theField]["default value"] is ":") then
          delete char i-1 to -1 of theA["fields"][theField]["default value"]
          exit repeat
        end if
      end repeat
      -- put revDatabaseColumnNamed(theCursor, "Key") is "UNI" into theA["fields"][theField]["unique"]

      put revDatabaseColumnNamed(theCursor, "data_type") into theA["fields"][theField]["type"]

      if theA["fields"][theField]["default value"] begins with "nextval("  \
            and theA["fields"][theField]["type"] is "integer" then
        put "sequence" into theA["fields"][theField]["type"]
        put empty into theA["fields"][theField]["length"]
        put false into theA["fields"][theField]["signed"]
        put empty into theA["fields"][theField]["default value"]
      else
        put revDatabaseColumnNamed(theCursor, "numeric_precision") into theA["fields"][theField]["length"]
        if theA["fields"][theField]["length"] is empty then
          put revDatabaseColumnNamed(theCursor, "character_maximum_length") into theA["fields"][theField]["length"]
        end if

        ## How to find this out?
        put false into theA["fields"][theField]["signed"]
      end if

      revMoveToNextRecord theCursor
      if the result is not true then exit REPEAT
    end REPEAT

    put thePrimaryKeys into theA["primary key"]
    delete the last char of theA["field order"]

    revCloseCursor theCursor
  end if

  if theError is empty then
    return theA for value
  else
    return theError for error
  end if
end _postgresql_dbTableFields


private command _postgresql_dbTableIndexes pConnectionA, pTable, @pFieldsA
  local theError, theArrayA, theCollation, theConnectionID, theQs
  local theCursor, theIndexName, theSQL

  put dbconn_get("connection id", pConnectionA) into theConnectionID
  put dbconn_get("quotes", pConnectionA) into theQs

  -- http://dev.mysql.com/doc/refman/5.0/en/show-index.html
  put "SHOW INDEX FROM" && pTable into theSQL
  put revQueryDatabase( theConnectionID, theSQL) into theCursor
  if theCursor is not an integer then
    put _ErrorMsg("retrieving mysql index list", theCursor) into theError
  end if

  if theError is empty then
    local theA

    if not revdb_iseof(theCursor) then
      repeat forever
        put revDatabaseColumnNamed(theCursor, "Key_name") into theIndexName
        put revDatabaseColumnNamed(theCursor, "Non_unique") is 0 into theA["indexes"][theIndexName]["unique"]
        put revDatabaseColumnNamed(theCursor, "Column_name") into \
              line (the number of lines of theA["indexes"][theIndexName]["fields"] + 1) of theA["indexes"][theIndexName]["fields"]
        put revDatabaseColumnNamed(theCursor, "Collation") into theCollation
        put revDatabaseColumnNamed(theCursor, "Index_type") into theA["indexes"][theIndexName]["type"]

        ## TODO: ADD CHECK FOR FULL TEXT
        if theA["indexes"][theIndexName]["unique"] then
          put "unique" into theA["indexes"][theIndexName]["style"]
        else
          put "simple" into theA["indexes"][theIndexName]["style"]
        end if

        put theIndexName is "PRIMARY" into theA["indexes"][theIndexName]["primary key"]
        if theCollation is "A" then put "ascending" into theA["indexes"][theIndexName]["sort direction"]
        else put "descending" into theA["indexes"][theIndexName]["sort direction"]

        revMoveToNextRecord theCursor
        if the result is not true then exit REPEAT
      end repeat
    end if

    revCloseCursor theCursor
  end if

  if theError is empty then
    return theA for value
  else
    return theError for error
  end if
end _postgresql_dbTableIndexes


private function _postgresql_systemTables
  get "sql_features,sql_implementation_info,sql_languages,sql_packages,sql_parts,sql_sizing,sql_sizing_profiles"
  replace comma with cr in it
  return it
end _postgresql_systemTables


--> Driver: Valentina


private function _valentina_getFieldSQLType pFieldA
  local theType, theLimit, thePrecision, theScale, theSQLType

  put _effectiveFieldtype(pFieldA) into theType
  put pFieldA["length"] into theLimit
  put pFieldA["precision"] into thePrecision
  put pFieldA["scale"] into theScale

  put theType into theSQLType

  switch theType
    case "text"
      if pFieldA["fixed width"] then
        put "CHAR" into theSQLType
        if theLimit is not an integer then
          put 255 into theLimit
        end if
      end if

      if theLimit is an integer then
        if theLimit <= 255 then
          if theSQLType is "text" then
            put "VARCHAR" into theSQLType
          end if
        end if

        put theSQLType & "(" & theLimit & ")" into theSQLType
      end if
      break

    case "float"
      put "FLOAT" into theSQLType
      break

    case "double precision"
      put "DOUBLE PRECISION" into theSQLType
      break

    case "decimal"
      if thePrecision is not an integer then
        put "10" into thePrecision
      end if
      if theScale is not an integer then
        put "2" into theScale
      end if
      put theSQLType & "(" & thePrecision & comma & theScale & ")" into theSQLType
      break

    case "list"
      put "ENUM" into theSQLType
      break
  end switch

  return theSQLType
end _valentina_getFieldSQLType


private command _valentina_dbTableFields pConnectionA, pTable
  local theError, theQs, theA, theConnectionID, theCursor, theField
  local thePrimaryKeys, theQuotes, theSQL, theRowsA

  put dbconn_get("connection id", pConnectionA) into theConnectionID
  put dbconn_get("quotes", pConnectionA) into theQs

  put "SHOW COLUMNS FROM " & theQs["left"] & pTable & theQs["right"] into theSQL
  put false into pConnectionA["import schema"] ## no recursion, thank you
  dbconn_retrieveQueryAsArray theSQL, empty, empty, theRowsA, pConnectionA
  put the result into theError

  if theError is empty then
    if the keys of theRowsA is empty then
      put "no fields were returned for table '" & pTable & "'" into theError
    end if
  end if

  if theError is empty then
    ## Every table has a rec id
    put "RecID" into theA["fields"]["RecID"]["name"]
    put "sequence" into theA["fields"]["RecID"]["type"]
    put NULL into theA["fields"]["RecID"]["default value"]
    put false into theA["fields"]["RecID"]["accepts null"]
    put empty into theA["fields"]["RecID"]["length"]
    put false into theA["fields"]["RecID"]["signed"]

    repeat with i = 1 to the number of elements of theRowsA
      put theRowsA[i]["fld_name"] into theField
      put theField & comma after theA["field order"]
      put theField into theA["fields"][theField]["name"]
      put empty into theA["fields"][theField]["encoding"]

      put theRowsA[i]["fld_default_value"] into theA["fields"][theField]["default value"]
      if theA["fields"][theField]["default value"] is empty \
            or theA["fields"][theField]["default value"] is null then
        put "NULL" into theA["fields"][theField]["default value"]
      else if theA["fields"][theField]["default value"] is not an integer then
        put "'" & theA["fields"][theField]["default value"] & "'" into theA["fields"][theField]["default value"]
      end if
      put theRowsA[i]["fld_nullable"] is true into theA["fields"][theField]["accepts null"]
      put theRowsA[i]["fld_identity"] is true into theA["fields"][theField]["primary key"]
      put theRowsA[i]["fld_type"] into theA["fields"][theField]["type"]

      put theRowsA[i]["fld_max_length"] into theA["fields"][theField]["length"]
      if theA["fields"][theField]["length"] is 0 then put empty into theA["fields"][theField]["length"]

      ## How to find this out?
      put false into theA["fields"][theField]["signed"]

      if theA["fields"][theField]["primary key"] then
        put theField & comma after thePrimaryKeys
      end if

      ## Assign primary key a sequence
      if theA["fields"][theField]["primary key"] then
        put "sequence" into theA["fields"][theField]["type"]
        put empty into theA["fields"][theField]["length"]
        put false into theA["fields"][theField]["signed"]
      end if
    end repeat

    delete the last char of thePrimaryKeys
    put thePrimaryKeys into theA["primary key"]
    delete the last char of theA["field order"]

    ## Default to Valentina special key
    if theA["primary key"] is empty then
      put "RecID" into theA["primary key"]
      put "RecID" into item (the number of items of theA["field order"] + 1) of theA["field order"]
    end if
  end if

  if theError is empty then
    return theA for value
  else
    return theError for error
  end if
end _valentina_dbTableFields


private command _valentina_dbTableIndexes pConnectionA, pTable, pFieldsA
  local theA, theError

  -- put dbconn_get("connection id", pConnectionA) into theConnectionID
  -- put dbconn_get("quotes", pConnectionA) into theQs

  -- --> http://dev.mysql.com/doc/refman/5.0/en/show-index.html
  -- put "SHOW INDEX FROM" && pTable into theSQL
  -- put revQueryDatabase( theConnectionID, theSQL) into theCursor
  -- if theCursor is not an integer then
  -- put _ErrorMsg("retrieving mysql index list", theCursor) into theError
  -- end if

  -- if theError is empty then
  -- if not revdb_iseof(theCursor) then
  -- repeat forever
  -- put revDatabaseColumnNamed(theCursor, "Key_name") into theIndexName
  -- put revDatabaseColumnNamed(theCursor, "Non_unique") is 0 into theA["indexes"][theIndexName]["unique"]
  -- put revDatabaseColumnNamed(theCursor, "Column_name") into \
        -- line (the number of lines of theA["indexes"][theIndexName]["fields"] + 1) of theA["indexes"][theIndexName]["fields"]
  -- put revDatabaseColumnNamed(theCursor, "Collation") into theCollation
  -- put revDatabaseColumnNamed(theCursor, "Index_type") into theA["indexes"][theIndexName]["type"]

  -- ## TODO: ADD CHECK FOR FULL TEXT
  -- if theA["indexes"][theIndexName]["unique"] then
  -- put "unique" into theA["indexes"][theIndexName]["style"]
  -- else
  -- put "simple" into theA["indexes"][theIndexName]["style"]
  -- end if

  -- put theIndexName is "PRIMARY" into theA["indexes"][theIndexName]["primary key"]
  -- if theCollation is "A" then put "ascending" into theA["indexes"][theIndexName]["sort direction"]
  -- else put "descending" into theA["indexes"][theIndexName]["sort direction"]

  -- revMoveToNextRecord theCursor
  -- if the result is not true then exit REPEAT
  -- end repeat
  -- end if

  -- revCloseCursor theCursor
  -- end if

  if theError is empty then
    return theA for value
  else
    return theError for error
  end if
end _valentina_dbTableIndexes


private function _valentina_systemTables
  return empty
end _valentina_systemTables


--> Driver: Filemaker


private function _filemaker_getFieldSQLType pFieldA

end _filemaker_getFieldSQLType


private command _filemaker_dbTableFields pConnectionA, pTable
  local theConnectionID, theQs, theSQL, theRowsA, theError
  local thePrimaryKeys, theField, theA

  set the wholeMatches to true

  put dbconn_get("connection id", pConnectionA) into theConnectionID
  put dbconn_get("quotes", pConnectionA) into theQs
  put false into pConnectionA["import schema"] ## no recursion, thank you

  -- SQLTables - catalog information is stored and reported as single part names (table name only).
  -- - SQLColumns
  -- - SQLColumnPrivileges
  -- - SQLDescribeCol
  -- - SQLGetTypeInfo

  put "SELECT SQLTables" into theSQL
  dbconn_retrieveQueryAsArray theSQL, empty, empty, theRowsA, pConnectionA
  put the result into theError

  if theError is empty then
    if the keys of theRowsA is empty then
      put "no fields were returned for table '" & pTable & "'" into theError
    end if
  end if

  if theError is empty then
    ## PRIMARY KEY
    put "SELECT c.COLUMN_NAME FROM information_schema.table_constraints pk, " & \
          "information_schema.key_column_usage c " & \
          "WHERE pk.table_name = '" & pTable & "' " & \
          "AND CONSTRAINT_TYPE = 'PRIMARY KEY' " & \
          "AND c.TABLE_NAME = pk.TABLE_NAME " & \
          "AND c.CONSTRAINT_NAME = pk.CONSTRAINT_NAME" into theSQL
    put false into pConnectionA["import schema"] ## no recursion, thank you
    dbconn_retrieveQueryAsData theSQL, empty, thePrimaryKeys, empty, comma, pConnectionA
    put the result into theError
  end if

  if theError is empty then
    repeat with i = 1 to the number of elements of theRowsA
      put theRowsA[i]["COLUMN_NAME"] into theField
      put theField & comma after theA["field order"]
      put theField into theA["fields"][theField]["name"]

      put theField is among the items of thePrimaryKeys into theA["fields"][theField]["primary key"]
      put theRowsA[i]["COLUMN_DEF"] into theA["fields"][theField]["default value"]
      if theA["fields"][theField]["default value"] is empty then
        put "NULL" into theA["fields"][theField]["default value"]
      end if
      put theRowsA[i]["IS_NULLABLE"] is "YES" into theA["fields"][theField]["accepts null"]
      put theRowsA[i]["TYPE_NAME"] into theA["fields"][theField]["type"]
      put theRowsA[i]["PRECISION"]  into theA["fields"][theField]["length"]

      if the last word of theA["fields"][theField]["type"] is "identity" then
        put "sequence" into theA["fields"][theField]["type"]
        put false into theA["fields"][theField]["signed"]
      else
        ## How to find this out?
        put false into theA["fields"][theField]["signed"]
      end if
    end REPEAT

    put thePrimaryKeys into theA["primary key"]
    delete the last char of theA["field order"]
  end if

  if theError is empty then
    return theA for value
  else
    return theError for error
  end if
end _filemaker_dbTableFields


private command _filemaker_dbTableIndexes pConnectionA, pTable, pFieldsA
  local theA, theError

  -- put dbconn_get("connection id", pConnectionA) into theConnectionID
  -- put dbconn_get("quotes", pConnectionA) into theQs

  -- --> http://dev.mysql.com/doc/refman/5.0/en/show-index.html
  -- put "SHOW INDEX FROM" && pTable into theSQL
  -- put revQueryDatabase( theConnectionID, theSQL) into theCursor
  -- if theCursor is not an integer then
  -- put _ErrorMsg("retrieving mysql index list", theCursor) into theError
  -- end if

  -- if theError is empty then
  -- if not revdb_iseof(theCursor) then
  -- repeat forever
  -- put revDatabaseColumnNamed(theCursor, "Key_name") into theIndexName
  -- put revDatabaseColumnNamed(theCursor, "Non_unique") is 0 into theA["indexes"][theIndexName]["unique"]
  -- put revDatabaseColumnNamed(theCursor, "Column_name") into \
        -- line (the number of lines of theA["indexes"][theIndexName]["fields"] + 1) of theA["indexes"][theIndexName]["fields"]
  -- put revDatabaseColumnNamed(theCursor, "Collation") into theCollation
  -- put revDatabaseColumnNamed(theCursor, "Index_type") into theA["indexes"][theIndexName]["type"]

  -- ## TODO: ADD CHECK FOR FULL TEXT
  -- if theA["indexes"][theIndexName]["unique"] then
  -- put "unique" into theA["indexes"][theIndexName]["style"]
  -- else
  -- put "simple" into theA["indexes"][theIndexName]["style"]
  -- end if

  -- put theIndexName is "PRIMARY" into theA["indexes"][theIndexName]["primary key"]
  -- if theCollation is "A" then put "ascending" into theA["indexes"][theIndexName]["sort direction"]
  -- else put "descending" into theA["indexes"][theIndexName]["sort direction"]

  -- revMoveToNextRecord theCursor
  -- if the result is not true then exit REPEAT
  -- end repeat
  -- end if

  -- revCloseCursor theCursor
  -- end if

  if theError is empty then
    return theA for value
  else
    return theError for error
  end if
end _filemaker_dbTableIndexes


private function _filemaker_systemTables
  -- get "sql_features,sql_implementation_info,sql_languages,sql_packages,sql_parts,sql_sizing,sql_sizing_profiles"
  -- replace comma with cr in it
  -- return it
  return empty
end _filemaker_systemTables


--> Driver: SQL Server


private function _sqlserver_getFieldSQLType pFieldA, pConnectionA
  local theType, theLimit, thePrecision, theScale, theEncoding, theSQLType

  put _effectiveFieldtype(pFieldA) into theType
  put pFieldA["length"] into theLimit
  put pFieldA["precision"] into thePrecision
  put pFieldA["scale"] into theScale
  put pFieldA["encoding"] into theEncoding

  put theType into theSQLType

  switch theType
    case "text"
      if pFieldA["fixed width"] then
        put "char" into theSQLType
        if theLimit is not an integer then
          put 255 into theLimit
        end if
      end if

      if theLimit is an integer then
        if theLimit <= 1024 then
          if theSQLType is "text" then
            put "varchar" into theSQLType
          end if
        end if

        put theSQLType & "(" & theLimit & ")" into theSQLType
      end if

      if theEncoding begins with "utf" or theEncoding begins with "unicode" then
        put "n" before theSQLType
      end if
      break

    case "float"
      put "DOUBLE" into theSQLType
      break

    case "double precision"
      put "DOUBLE PRECISION" into theSQLType
      break

    case "decimal"
      if thePrecision is not an integer then
        put "10" into thePrecision
      end if
      if theScale is not an integer then
        put "2" into theScale
      end if
      put theSQLType & "(" & thePrecision & comma & theScale & ")" into theSQLType
      break

    case "boolean"
      put "BIT" into theSQLType
      break

    case "list"
      put "ENUM" into theSQLType
      break

    case "date time"
      ## datetime2 is 2008 (10.x.xxxx.xx) and later.
      ## for 2005 (9.xx.xxxx.xx) we need datetime
      set the itemDelimiter to "."
      if item 1 of dbconn_get("version", pConnectionA) >= 10 then
        put "datetime2" into theSQLType
        if thePrecision is not an integer then
          put "7" into thePrecision
        end if
        put "(" & thePrecision & ")" after theSQLType
      else
        put "datetime" into theSQLType
      end if
      break

    case "binary"
      if theLimit is not an integer then
        put 8000 into theLimit
      end if

      if pFieldA["fixed width"] then
        put "binary" into theSQLType
        put min(8000, theLimit) into theLimit
      else
        put "varbinary" into theSQLType
        if theLimit > 8000 then
          put "max" into theLimit
        end if
      end if

      if theLimit is not empty then
        ## theLimit could be MAX
        put theSQLType & "(" & theLimit & ")" into theSQLType
      end if
      break
  end switch

  return theSQLType
end _sqlserver_getFieldSQLType


private command _sqlserver_dbTableFields pConnectionA, pTable
  local theConnectionID, theQs, theSQL, theRowsA, theError
  local thePrimaryKeys, theField, theA

  set the wholeMatches to true

  put dbconn_get("connection id", pConnectionA) into theConnectionID
  put dbconn_get("quotes", pConnectionA) into theQs
  put false into pConnectionA["import schema"] ## no recursion, thank you

  -- put "SELECT * FROM information_schema.columns " & \
        -- "WHERE table_name = " & theQs["left"] & pTable & theQs["right"] & " " & \
        -- "ORDER BY ORDINAL_POSITION" into theSQL
  put "SP_COLUMNS N'" & pTable & "'" into theSQL
  dbconn_retrieveQueryAsArray theSQL, empty, empty, theRowsA, pConnectionA
  put the result into theError

  if theError is empty then
    if the keys of theRowsA is empty then
      put "no fields were returned for table '" & pTable & "'" into theError
    end if
  end if

  if theError is empty then
    ## PRIMARY KEY
    put "SELECT C.COLUMN_NAME FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS pk, " & \
          "INFORMATION_SCHEMA.KEY_COLUMN_USAGE c " & \
          "WHERE pk.TABLE_NAME = '" & pTable & "' " & \
          "AND CONSTRAINT_TYPE = 'PRIMARY KEY' " & \
          "AND c.TABLE_NAME = pk.TABLE_NAME " & \
          "AND c.CONSTRAINT_NAME = pk.CONSTRAINT_NAME" into theSQL
    put false into pConnectionA["import schema"] ## no recursion, thank you
    dbconn_retrieveQueryAsData theSQL, empty, thePrimaryKeys, empty, comma, pConnectionA
    put the result into theError
  end if

  if theError is empty then
    repeat with i = 1 to the number of elements of theRowsA
      put theRowsA[i]["COLUMN_NAME"] into theField
      put theField & comma after theA["field order"]
      put theField into theA["fields"][theField]["name"]

      if theRowsA[i]["TYPE_NAME"] is among the items of "nvarchar,ntext,nchar" then
        put "ucs2" into theA["fields"][theField]["encoding"]
      else
        put empty into theA["fields"][theField]["encoding"]
      end if

      put theField is among the items of thePrimaryKeys into theA["fields"][theField]["primary key"]
      put theRowsA[i]["COLUMN_DEF"] into theA["fields"][theField]["default value"]
      if theA["fields"][theField]["default value"] is empty then
        put "NULL" into theA["fields"][theField]["default value"]
      end if
      put theRowsA[i]["IS_NULLABLE"] is "YES" into theA["fields"][theField]["accepts null"]
      put theRowsA[i]["TYPE_NAME"] into theA["fields"][theField]["type"]
      put theRowsA[i]["PRECISION"]  into theA["fields"][theField]["length"]

      if the last word of theA["fields"][theField]["type"] is "identity" then
        put "sequence" into theA["fields"][theField]["type"]
        put false into theA["fields"][theField]["signed"]
      else
        ## How to find this out?
        put false into theA["fields"][theField]["signed"]
      end if
    end REPEAT

    put thePrimaryKeys into theA["primary key"]
    delete the last char of theA["field order"]
  end if

  if theError is empty then
    return theA for value
  else
    return theError for error
  end if
end _sqlserver_dbTableFields


private command _sqlserver_dbTableIndexes pConnectionA, pTable, pFieldsA
  local theA, theError

  -- put dbconn_get("connection id", pConnectionA) into theConnectionID
  -- put dbconn_get("quotes", pConnectionA) into theQs

  -- --> http://dev.mysql.com/doc/refman/5.0/en/show-index.html
  -- put "SHOW INDEX FROM" && pTable into theSQL
  -- put revQueryDatabase( theConnectionID, theSQL) into theCursor
  -- if theCursor is not an integer then
  -- put _ErrorMsg("retrieving mysql index list", theCursor) into theError
  -- end if

  -- if theError is empty then
  -- if not revdb_iseof(theCursor) then
  -- repeat forever
  -- put revDatabaseColumnNamed(theCursor, "Key_name") into theIndexName
  -- put revDatabaseColumnNamed(theCursor, "Non_unique") is 0 into theA["indexes"][theIndexName]["unique"]
  -- put revDatabaseColumnNamed(theCursor, "Column_name") into \
        -- line (the number of lines of theA["indexes"][theIndexName]["fields"] + 1) of theA["indexes"][theIndexName]["fields"]
  -- put revDatabaseColumnNamed(theCursor, "Collation") into theCollation
  -- put revDatabaseColumnNamed(theCursor, "Index_type") into theA["indexes"][theIndexName]["type"]

  -- ## TODO: ADD CHECK FOR FULL TEXT
  -- if theA["indexes"][theIndexName]["unique"] then
  -- put "unique" into theA["indexes"][theIndexName]["style"]
  -- else
  -- put "simple" into theA["indexes"][theIndexName]["style"]
  -- end if

  -- put theIndexName is "PRIMARY" into theA["indexes"][theIndexName]["primary key"]
  -- if theCollation is "A" then put "ascending" into theA["indexes"][theIndexName]["sort direction"]
  -- else put "descending" into theA["indexes"][theIndexName]["sort direction"]

  -- revMoveToNextRecord theCursor
  -- if the result is not true then exit REPEAT
  -- end repeat
  -- end if

  -- revCloseCursor theCursor
  -- end if

  if theError is empty then
    return theA for value
  else
    return theError for error
  end if
end _sqlserver_dbTableIndexes


private function _sqlserver_systemTables
  -- get "sql_features,sql_implementation_info,sql_languages,sql_packages,sql_parts,sql_sizing,sql_sizing_profiles"
  -- replace comma with cr in it
  -- return it
  return empty
end _sqlserver_systemTables


private command _sqlserver_dbCreateTable pName, pTableA, pConnectionA
  local theError, theQsA, theSQL

  put dbconn_get("quotes", pConnectionA) into theQsA

  put "CREATE TABLE" && theQsA["left"] & pName & theQsA["right"] into theSQL
  put false into pTableA["@primary key is taken care of"]

  ## Fields
  put " (" after theSQL
  repeat with i = 1 to the number of elements of pTableA["fields"]
    put _sqlserver_getColumnDefSQL(pTableA, pTableA["fields"][i], pConnectionA) after theSQL
    put comma & space after theSQL
  end repeat

  ## Primary key
  if pTableA["primary key"] is not empty and not pTableA["@primary key is taken care of"] then
    put " PRIMARY KEY(" & pTableA["primary key"] & "), " after theSQL
  end if

  ## Foreign keys
  if the keys of pTableA["foreign keys"] is not empty then
    put _sqlserver_ForeignKeySQL(pTableA["foreign keys"], pConnectionA) after theSQL
    put ")" after theSQL
  else
    put ")" into char -2 to -1 of theSQL
  end if

  if theError is empty then
    dbconn_executeSQL theSQL, pConnectionA
    put the result into theError
  end if

  return theError
end _sqlserver_dbCreateTable


-- pTableA["@primary key is taken care of"] can be modified
function _sqlserver_getColumnDefSQL @pTableA, pFieldA, pConnectionA
  local theQsA, theSQLType, theSQL

  put quote into theQsA["left"]
  put quote into theQsA["right"]
  put _sqlserver_getFieldSQLType(pFieldA, pConnectionA) into theSQLType

  ## Name
  put theQsA["left"] & pFieldA["name"] & theQsA["right"] & space into theSQL

  if pFieldA["type"] is "sequence" \
        and (pTableA["primary key"] is pFieldA["name"] or pTableA["primary key"] is empty) then
    put "INTEGER IDENTITY (1,1) PRIMARY KEY CLUSTERED " after theSQL
    put pFieldA["name"] into pTableA["primary key"]
    put true into pTableA["@primary key is taken care of"]
  else
    put theSQLType & space after theSQL

    if "default" is among the keys of pFieldA then
      switch pFieldA["type"]
        case "boolean"
          if pFieldA["default"] is among the items of "0,false" then put "0" into pFieldA["default"]
          else if pFieldA["default"] is among the items of "1,true" then put "1" into pFieldA["default"]
          break
      end switch
      put "DEFAULT " & pFieldA["default"] & " " after theSQL
    end if

    if pFieldA["accepts null"] is false then
      put "NOT NULL " after theSQL
    end if
  end if
  delete the last char of theSQL
  return theSQL
end _sqlserver_getColumnDefSQL


private function _sqlserver_ForeignKeySQL pForeignKeysA, pConnectionA
  local theError
  local theSQL, theQsA

  put dbconn_get("quotes", pConnectionA) into theQsA

  -- sqlyoga_addToArray theTableA["foreign keys"], "key:step_id", "references:steps", "on fields:id", "on delete:cascade", "on update:cascade"
  repeat with i = 1 to the number of elements of pForeignKeysA
    if pForeignKeysA[i]["name"] is not empty then
      put "CONSTRAINT " & pForeignKeysA[i]["name"] & " " after theSQL
    end if

    put "FOREIGN KEY (" & pForeignKeysA[i]["key"] & ") " & \
          "REFERENCES " & pForeignKeysA[i]["references"] & "(" & pForeignKeysA[i]["on fields"] & ")" after theSQL

    repeat for each item theItem in "on delete,on update"
      if pForeignKeysA[i][theItem] is not empty then
        put " " & toUpper(theItem) && pForeignKeysA[i][theItem] after theSQL
      end if
    end repeat

    put ", " after theSQL
  end repeat
  delete char -2 to -1 of theSQL

  return theSQL
end _sqlserver_ForeignKeySQL


private command _sqlserver_afterMigration pConnectionA
  return empty
end _sqlserver_afterMigration


private command _sqlserver_dbCreateFields pTable, pFieldsA, pConnectionA
  local theError, theQsA, theTableA, theBaseSQL, theSQL

  put dbconn_get("quotes", pConnectionA) into theQsA

  put empty into theTableA["primary key"]
  put true into theTableA["@primary key is taken care of"]

  put "ALTER TABLE " & theQsA["left"] & pTable & theQsA["right"] & " " into theBaseSQL

  repeat with i = 1 to the number of elements of pFieldsA
    put theBaseSQL & "ADD " & _sqlserver_getColumnDefSQL(theTableA, pFieldsA[i]) into theSQL
    dbconn_executeSQL theSQL, pConnectionA
    put the result into theError

    if theError is not empty then exit repeat
  end repeat

  return theError
end _sqlserver_dbCreateFields


private command _sqlserver_dbAlterTable pConnectionA, pTableA

end _sqlserver_dbAlterTable


private command _sqlserver_dbCreateTableIndexes pName, pIndexA, pConnectionA
  local theError, theQsA, theSQL, theLimit

  put dbconn_get("quotes", pConnectionA) into theQsA

  switch pIndexA["type"]
    case "unique"
      put "CREATE UNIQUE INDEX " into theSQL
      break
    default
      put "CREATE INDEX " into theSQL
  end switch

  -- NAME on "TABLE"
  put theQsA["left"] & pName & theQsA["right"] && "ON" && theQsA["left"] & pIndexA["table"] & theQsA["right"] after theSQL

  put " (" after theSQL
  repeat with i = 1 to the number of elements of pIndexA["fields"]
    if pIndexA["fields"][i]["sort order"] is "descending" then put "DESC" into pIndexA["fields"][i]["sort order"]
    else put "ASC" into pIndexA["fields"][i]["sort order"]

    if pIndexA["fields"][i]["length"] > 0 then
      put " (" & pIndexA["fields"][i]["length"] & ")" into theLimit
    end if

    ## TODO: COLLATION SUPPORT. WE DON'T HAVE METATYPES FOR COLLATIONS THOUGH
    put theQsA["left"] & pIndexA["fields"][i]["name"] & theQsA["right"] & theLimit \
          && pIndexA["fields"][i]["sort order"] & ", " after theSQL
  end repeat
  put ")" into char -2 to -1 of theSQL

  dbconn_executeSQL theSQL, pConnectionA
  put _ErrorMsg("unable to create index on table '" & pIndexA["table"] & "'", the result) into theError

  return theError
end _sqlserver_dbCreateTableIndexes


private command _sqlserver_dbDeleteIndex pIndexName, pTableName, pConnectionA
  local theError, theQsA, theSQL

  put dbconn_get("quotes", pConnectionA) into theQsA

  put "DROP INDEX " into theSQL
  put theQsA["left"] & pTableName & theQsA["right"] & "." & theQsA["left"] & pIndexName & theQsA["right"] after theSQL

  dbconn_executeSQL theSQL, pConnectionA
  put _ErrorMsg("unable to drop index '" & pTableName & "'", the result) into theError

  return theError
end _sqlserver_dbDeleteIndex


--> Private


## duplicate of function in libSQLYoga
private function _valentinaErrorSchema pConnID
  local theError, theErrNum
  put VDatabase_ErrNumber( pConnID ) into theErrNum
  if theErrNum > 0 then
    put VDatabase_ErrString( pConnID ) into theError
  else if theErrNum < 0 then
    put "OS error ("& theErrNum &")" into theError
  end if
  return theError
end _valentinaErrorSchema


private function _NormalizeFieldType pFromType
  local theType

  switch pFromType
    case "BIT"
    case "BOOLEAN"
      put "boolean" into theType
      break
    case "REAL"
    case "FLOAT"
    case "DOUBLE"
      put "float" into theType
    case "DOUBLE PRECISION"
      put "double precision" into theType
      break
    case "decimal"
    case "numeric"
      put "decimal" into theType
      break
    case "LONG"
    case "INTEGER"
    case "INT"
    case "SMALLINT"
    case "ULong"
    case "LLong"
    case "ULLong"
    case "Medium"
    case "MEDIUMINT"
    case "UMedium"
    case "short"
    case "ushort"
    case "Byte"
    case "ObjectPtr"
      put "integer" into theType
      break
    case "TIMESTAMP"
      put "timestamp" into theType
      break
    case "DATE"
      put "date" into theType
      break
    case "TIME"
    case "DATETIME"
    case "DATE TIME"
      put "date time" into theType
      break
    case "BLOB"
    case "TINYBLOB"
    case "MEDIUMBLOB"
    case "LONGBLOB"
    case "FixedBinary"
    case "VarBinary"
    case "LongVarBinary"
    case "BINARY"
    case "bytea" ## postgresql
      put "binary" into theType
      break
    case "sequence"
      put "sequence" into theType
      break
    case "ENUM"
    case "list"
      put "list" into theType
      break
    case "TEXT"
    case "CLOB"
    case "WORD"
    case "CHAR"
    case "STRING"
    case "WSTRING"
    case "VarChar"
    case "LongVarChar"
    case "nvarchar" -- sql server ucs-2
    case "nchar" -- sql server ucs-2
    case "ntext" -- sql server ucs-2
    case "character varying" ## postgresql
    case "citext" ## postgresql
    default
      put "text" into theType
      break
  end switch

  return theType
end _NormalizeFieldType


private function _effectiveFieldType pFieldA
  if pFieldA["meta type"] is not empty then
    return pFieldA["meta type"]
  else
    return pFieldA["type"]
  end if
end _effectiveFieldType

private function _ErrorMsg pMsg, pError
  if pError is not empty then
    return pMsg & ":" && pError
  else
    return empty
  end if
end _ErrorMsg
