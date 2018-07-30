script "libSQLYoga"
constant kVersion = "2.0.0"
constant kBuildNumber = "2"
constant kBuildProfile = "development"
constant kExpirationDate = ""

--> Defines (old)

constant kErrInvalidArray = 422
constant kErrInvalidBoolean = 452
constant kErrInvalidNumber = 453
constant kErrPropDoesntExist = 456
constant kErrInvalidInteger = 354
constant kErrInvalidPoint = 355
constant kErrInvalidRect = 356
constant kErrReadOnlyProp = 449
constant kErrInvalidProperty = 348
constant kErrCantFindObject = 619
constant kErrRenameErrorInDestination = 487
constant kErrObjectNameTaken = 132 ##create: error in name expression
constant kErrInvalidGroupObject = 238
constant kErrErrorInFunction = 219

local sFieldGetProps = "notes,database,database schema,table,type,limit,scale,precision,fixed width,accepts null,signed,has default value,default value,meta type"
local sFieldSetProps = "notes,name,type,limit,scale,precision,fixed width,accepts null,unique,signed,has default value,default value"

local sTableGetProps = "notes,database,database schema,relationships,fields,field names,indexes,index names,data,primary key fields,primary key field,primary key,sql queries"
local sTableSetProps = "notes,primary key,name"

local sRelationGetProps = "notes,database,database schema,type,table 1,table 1 name,table 1 key,table 2,table 2 name,table 2 key,link table,link table name,link table to table 1 key,link table to table 2 key,table 1 update action,table 1 delete action,table 2 update action,table 2 delete action,update action,delete action"
local sRelationSetProps = "notes,type,table 1,table 1 key,table 2,table 2 key,link table,link table to table 1 key,link table to table 2 key,table 1 update action,table 1 delete action,table 2 update action,table 2 delete action,update action,delete action"

local sDatabaseProps = "notes"
local sConnectionProps = "notes"

local sIndexGetProps = "notes,database,database schema,table,fields,field names,style,type"
local sIndexSetProps = "notes,fields,style,type"

local sValidationProps = ""


--> Defines (New)

constant kSupportedDatabase = "sqlite,mysql,valentina,postgresql"

constant kFieldReference = "field reference"
constant kTableReference = "table reference"
constant kConnectionReference = "connection reference"
constant kQueryTemplateReference = "query template reference"
constant kQueryReference = "query reference"
constant kRelationshipReference = "table relationship reference"
constant kIndexReference = "table index reference"
constant kSchemaMigrationReference = "schema migration reference"
constant kScopeReference = "scope reference"

constant kJoinTypes = "inner,left,left outer,right outer,full outer,self,cross" # left is a synonym for left outer
constant kDefaultJoinType = "inner"

constant kDatabaseKeyNotFound = "database key %s%s%s was not found"
constant kInvalidType = "invalid array type for"
constant kInvalidCursor = "invalid database cursor"

local sDbsA
local sConnectionsA

local sSQLQuerySetProps = "database,connection,table,table as,select,select clause,distinct,find,full column names,column names length,column names,joins,related table joins,conditions,condition bindings,sort by,order by,report null,column delimiter,row delimiter,limit,offset,group by,having"
local sSQLQueryGetProps = "tables,database type,number of records,query is at end,query is at start,joins including scopes,related table joins including scopes,from clause,join clause,where clause,query"

constant kBoolTrueValues = "true,1,y,yes,t"
constant kBoolFalseValues = "false,0,n,no,f"

constant kDontQuoteTypes = "decimal,integer,sequence"

constant kTempConnProps = "username,password,log file,log field,log callback,last executed sql,version,database name,host,port"

local sDefaultDBKey = "default"

--> Version

/**
Summary: Returns the version of the SQLite library.

Description:
Returns a string in a format similar to "1.0.0 build 1".

Returns: String
*/
function sqlyoga_version
  return kVersion && "build" && kBuildNumber
end sqlyoga_version


--> Messages (Engine)

on libraryStack
  if the target is not me then pass libraryStack

end libraryStack


on releaseStack
  if the target is not me then pass releaseStack

end releaseStack


--> Database Utilities


/**
Summary: Converts any number of key:value pairs into an array that is added to as a new element to another array.

Params:
xArrayA: The array to add an element to. A new key equal to the number of elements of xArrayA + 1 will be added.
pKey: Key of xArrayA to store key/values in.
pKeyValue: Key/Value pairs in the format key:value. Each key value passed in will be added to the new key of pArray.

Description:
Helper command for populating arrays.

Example:
put empty into tFieldsA
sqlyoga_addToArray tFieldsA, "name:id", "type:sequence"

Returns: empty
*/
command sqlyoga_addToArray @xArrayA, pKey, pKeyValue
  local theIndex, theKey

  if pKey is not an array and pKey is empty then
    put the number of elements of xArrayA + 1 into theIndex
    set the itemDelimiter to ":"
    repeat with i = 3 to the paramCount
      put item 1 of param(i) into theKey
      put item 2 to -1 of param(i) into xArrayA[theIndex][theKey]
    end repeat
  else
    put the number of elements of xArrayA[pKey] + 1 into theIndex
    set the itemDelimiter to ":"
    repeat with i = 3 to the paramCount
      put item 1 of param(i) into theKey
      put item 2 to -1 of param(i) into xArrayA[pKey][theIndex][theKey]
    end repeat
  end if
  return empty
end sqlyoga_addToArray


/**
Summary: Converts the parameters to an array.

Description:
Each parameter is a key:value pair.

Example:
put sqlyoga_array("id:1", "label:My Record") into tDataA

Returns: Array
*/
function sqlyoga_array
  local tKey, tArray

  set the itemDelimiter to ":"
  repeat with i = 1 to the paramCount
    put item 1 of param(i) into tKey
    put item 2 to -1 of param(i) into tArray[tKey]
  end repeat

  return tArray
end sqlyoga_array


/**
Summary: Adds a new element onto the end of an array.

Params:
xArrayA: The array to add an element to. A new key equal to the number of elements of xArrayA + 1 will be added.
pValue: Variable to add to array.

Description:
Helper command for populating arrays.

Example:
put "a value" into theFieldsA[1]
sqlyoga_arrayPush theFieldsA, "another value" -- added to theFieldsA[2]

Returns: empty
*/
command sqlyoga_arrayPush @xArrayA, pValue
  local theIndex

  put the number of elements of xArrayA + 1 into theIndex
  put pValue into xArrayA[theIndex]
  return empty
end sqlyoga_arrayPush


/**
Summary: Returns a return delimited list of all Database object names.

Returns: Line delimited list of database keys
*/
function sqlyoga_getDatabases
  local theDatabases

  put the keys of sDbsA into theDatabases
  sort theDatabases
  return theDatabases
end sqlyoga_getDatabases


/**
Summary: Sets the default Database object to use with the SQL Yoga API calls.

Params:
pDBKey: The name of the Database object to set as the default.

Description:
By default the SQL Yoga API calls assume you are acting on the Database object named "default".
You can use this command to specify a different Database object name to use as the default.

Returns: empty
*/
command sqlyoga_setDefaultDatabase pDBKey
  if pDBKey is not "default" then
    _ValidateDBKeyExistence pDBKey
  end if
  put pDBKey into sDefaultDBKey
  return empty
end sqlyoga_setDefaultDatabase


/**
Summary: Returns the name of the Database object used by default in SQL Yoga API calls.

Returns: Name of default database key.
*/
function sqlyoga_getDefaultDatabase
  return sDefaultDBKey
end sqlyoga_getDefaultDatabase


/**
Summary: Parses a search string and converts it into an array of it's component parts.

Params:
pString: A string representing the terms a user wants to search for.
pDefaultOperator: Default boolean operator to use between words that do not explicity state one. Valid values are `AND` or `OR`. Default value is `AND`.

Description:
Search interfaces often allow a user to enter a search string for querying the database.
A string entered by the user as`tacos pizza` might look like this in a `WHERE` clause:

```
field = 'tacos' AND field='pizza'
```

or

```
field='tacos' OR field='pizza'
```

A search string such as `"cheese pizza" tacos` might look like this in a `WHERE` clause:

```
field = 'cheese pizza' OR field='tacos'
```

This function splits up the string into it's component parts and stores them in a numerically
indexed array. This array can be used to generate conditions for a SQL Query object.
For example, it can be passed as a parameter to `sqlquery_addScope`.

The string `"cheese pizza" tacos` would be parsed and converted to an array that looks
like this (assuming `OR` was the default operator):

```
[1]["string"] = cheese pizza
[1]["operator"] = OR
[2]["string"] = tacos
[2]["operator"] = OR
```

Returns: Numerically indexed array. Each index has two keys: `operator` and `string`.
*/
function sqlyoga_splitUserSearchString pString, pDefaultOperator
  return _ParseUserSearchString(pString, pDefaultOperator)
end sqlyoga_splitUserSearchString


/**
Summary: Escapses a string using the appropriate characters for the specified database type.

Params:
pDbType: The type of database to escape for (mysql, postgresql, sqlite, valentina, sql server)
pString: The string to escape.

Returns: Escape string
*/
function sqlyoga_escapeString pDbType, pString
  _EscapeDbStringByRef pDbType, pString
  return pString
end sqlyoga_escapeString


/**
Summary: Returns the query used to retrieve the id of the last record that was inserted into the database.

Returns: SQL query
*/
function sqlyoga_lastInsertIDQuery pDbType, pConnectionA
  local theDo, theSQL

  replace space with empty in pDbType
  put "put _" & pDbType & "_lastInsertIDSQL(pConnectionA) into theSQL" into theDo
  do theDO
  return theSQL
end sqlyoga_lastInsertIDQuery


--> String Parsers (Private)

private function _StripDBObjectQuotes pString
  local theCharsToStrip

  put quote & "'" & "[" & "]" into theCharsToStrip
  repeat until char 1 of pString is not in theCharsToStrip
    delete char 1 of pString
  end repeat

  repeat until the last char of pString is not in theCharsToStrip
    delete the last char of pString
  end repeat
  return pString
end _StripDBObjectQuotes

## break into array with value, as
private function _ParseSelectClause pString
  -----
  local ignoringInput
  local theAsOffset
  local theChar, theCharNo
  local theStartEscapeChars, theEndEscapeChars
  local theCharsFollowingOperators
  local theCharsPrecedingOperators
  local theEscapeChars
  local theFieldsA
  local theProcessedCharCount
  local theString
  -----
  put false into ignoringInput
  put 0 into theProcessedCharCount
  put 0 into theAsOffset
  put empty into theString
  put empty into theFieldsA

  ## todo: customize for individual databases
  put "'(" & quote into theStartEscapeChars
  put "')" & quote into theEndEscapeChars
  put " ')" & quote into theCharsPrecedingOperators
  put " '(" & quote into theCharsFollowingOperators

  repeat with theCharNo = 1 to the number of chars of pString
    put char theCharNo of pString into theChar

    ## Look for escape chars
    if ignoringInput then
      if theChar is "\" then
        ## Add to string and then skip next char
        add 1 to theCharNo
        put theChar & char theCharNo of pString after theString
        next repeat
      end if
    end if

    if ignoringInput then
      ## Should we stop ignoring?
      if theChar is in theEndEscapeChars then
        put false into ignoringInput
        put theChar after theString
        next repeat
      end if
    else
      ## Should we start ignoring?
      if theChar is in theStartEscapeChars then
        put true into ignoringInput
        put theChar after theString
        next repeat
      end if
    end if

    ## Process char
    if not ignoringInput then

      ## Find AS
      if char theCharNo to (theCharNo + 3) of pString is " AS " then
        put theCharNo - theProcessedCharCount into theAsOffset
      end if

      switch theChar
        case comma
          ## Process chunk
          _ProcessSelectClauseChunk theFieldsA, theString, theAsOffset
          put empty into theString
          put 0 into theAsOffset
          put theCharNo into theProcessedCharCount
          break

        default
          put theChar after theString
      end switch

    else
      put theChar after theString
    end if

  end repeat

  if theString is not empty then _ProcessSelectClauseChunk theFieldsA, theString, theAsOffset

  return theFieldsA
end _ParseSelectClause


private command _ProcessSelectClauseChunk @xFieldA, pString, pAsOffset
  local theAs, theValue, theNextIndex

  ## Process chunk
  if pAsOffset > 0 then
    put char (pAsOffset + 4) to -1 of pString into theAs
    put char 1 to (pAsOffset - 1) of pString into theValue
  else
    put pString into theValue
  end if

  put the number of elements of xFieldA + 1 into theNextIndex
  put word 1 to -1 of theValue into xFieldA[theNextIndex]["value"]
  put word 1 to -1 of theAs into xFieldA[theNextIndex]["as"]

  return empty
end _ProcessSelectClauseChunk


private function _ConvertSelectClauseToSelectClauseFieldIndex pKey, pSelectClause, pTables
  -----
  local i
  local theTable, theTables, theFieldName, theFieldNames
  local theFieldsA
  local theNextIndex
  local theSelectClauseA
  local theTableIndex, theTableIndexes
  -----
  put _ParseSelectClause(pSelectClause) into theSelectClauseA

  repeat with i = 1 to the number of elements of theSelectClauseA
    put empty into theTableIndex

    put _StripDBObjectQuotes(theSelectClauseA[i]["value"]) into theSelectClauseA[i]["value"]

    set the itemDelimiter to "."
    if the number of items of theSelectClauseA[i]["value"] > 1 then
      put item 1 of theSelectClauseA[i]["value"] into theTable
      put item 2 of theSelectClauseA[i]["value"] into theFieldName
    else
      put theSelectClauseA[i]["value"] into theFieldName
    end if
    set the itemDelimiter to comma

    ## Now lookup table index if need be
    if theTable is empty then
      put pTables into theTables
      replace comma with cr in theTables
    else
      put theTable into theTables
    end if

    if theFieldName is "*" then
      repeat for each line theTable in theTables
        put the keys of sDbsA[ pKey ]["schema"]["tables"][ theTable ]["field order"] into theFieldNames
        repeat for each line theFieldName in theFieldNames
          put the number of elements of theFieldsA[theTableIndex] + 1 into theNextIndex
          put theFieldName into theFieldsA[theTable][theNextIndex]["field name"]
          put empty into theFieldsA[theTable][theNextIndex]["as"]
        end repeat
      end repeat
    else
      put _FindFirstInstanceOfFieldInTables(pKey, theTables, theFieldName) into theTable
      if theTable is not empty then
        put the number of elements of theFieldsA[theTableIndex] + 1 into theNextIndex
        put theFieldName into theFieldsA[theTable][theNextIndex]["field name"]
        put theSelectClauseA[i]["as"] into theFieldsA[theTableIndex][theNextIndex]["as"]
      else
        _ThrowError kErrPropDoesntExist, "field '" & theFieldName & "' was not found in any tables in the query template"
      end if
    end if
  end repeat

  return theFieldsA
end _ConvertSelectClauseToSelectClauseFieldIndex


private function _ParseUserSearchString pString, pDefaultOperator
  -----
  local foundABooleanOperator
  local i
  local ignoringInput
  local lookingForMatch
  local theChar, theCharCount
  local theCharNoOfLastQuote
  local theCharsFollowingOperators
  local theCharsPrecedingOperators
  local theEscapeChars
  local theNextOperator
  local theSearchA
  local theWord
  -----
  if pDefaultOperator is not "OR" then put "AND" into pDefaultOperator
  ## Step 1: Balance quotes
  put false into lookingForMatch
  put empty into theSearchA

  repeat for each char theChar in pString
    add 1 to i

    if theChar is quote then
      put i into theCharNoOfLastQuote
      put not lookingForMatch into lookingForMatch
    end if
  end repeat

  if lookingForMatch then put space into char theCharNoOfLastQuote of pString

  ## Step 2: Break up into WORDS
  put false into ignoringInput
  put quote into theEscapeChars
  put " " & quote into theCharsPrecedingOperators
  put " " & quote into theCharsFollowingOperators
  put the number of chars of pString into theCharCount
  put pDefaultOperator into theNextOperator

  repeat with i = 1 to theCharCount
    put char i of pString into theChar

    ## Deal with quotes
    if ignoringInput then
      ## Should we stop ignoring?
      if theChar is in theEscapeChars then
        put false into ignoringInput

        ## Done with quoted "word"
        _ProcessWordInUserSearchString theWord, theSearchA, theNextOperator, pDefaultOperator
        next repeat
      end if
    else
      ## Should we start ignoring?
      if theChar is in theEscapeChars then
        put true into ignoringInput
        next repeat
      end if
    end if

    ## Look for and/or
    if not ignoringInput then
      put (theCharsPrecedingOperators contains char (i-1) of pString or i is 1) and \
            ( (char i to (i+2) of pString is "AND" and ( ((i+3) > theCharCount) or theCharsFollowingOperators contains char (i+3) of pString) ) or \
            (char i to (i+1) of pString is "OR" and ( ((i+2) > theCharCount) or theCharsFollowingOperators contains char (i+2) of pString) ) ) \
            into foundABooleanOperator
      if foundABooleanOperator then
        if char i to (i+2) of pString is "AND" then
          put "AND" into theNextOperator
          add 2 to i
        else
          put "OR" into theNextOperator
          add 1 to i
        end if
        next repeat
      end if
    end if

    ## Process char
    if not ignoringInput then
      if theChar is space then
        ## process word
        _ProcessWordInUserSearchString theWord, theSearchA, theNextOperator, pDefaultOperator
      else
        put theChar after theWord
      end if
    else
      put theChar after theWord
    end if
  end repeat

  ## process word
  _ProcessWordInUserSearchString theWord, theSearchA, theNextOperator, pDefaultOperator

  return theSearchA
end _ParseUserSearchString


private command _ProcessWordInUserSearchString @xWord, @xSearchA, @xNextOperator, pDefaultOperator
  if xWord is not empty then
    local theSearchIndex

    put the number of elements of xSearchA + 1 into theSearchIndex

    put xWord into xSearchA[theSearchIndex]["string"]
    put xNextOperator into xSearchA[theSearchIndex]["operator"]
    put pDefaultOperator into xNextOperator
    put empty into xWord
  end if
end _ProcessWordInUserSearchString


private function _FindFirstInstanceOfFieldInTables pKey, pTables, pFieldName
  -----
  local theIndex
  local theTableIndex
  -----
  repeat for each line theTable in pTables
    if theTable is among the keys of sDbsA[ pKey ]["schema"]["tables"] then
      if pFieldName is among the keys of sDbsA[ pKey ]["schema"]["tables"][ theTable ]["fields"] then
        return theTable
      end if
    else
      ## maybe an alias?
      if tableobjects_tableExists(theTable, pKey) then
        local theTableA, theRealTable

        put tableobjects_getTable(theTable, pKey) into theTableA
        if tableobj_get(theTableA, "type") is "alias" then
          put tableobj_get(theTableA, "alias for table") into theRealTable
          if theRealTable is among the keys of sDbsA[ pKey ]["schema"]["tables"] then
            if pFieldName is among the keys of sDbsA[ pKey ]["schema"]["tables"][ theRealTable ]["fields"] then
              return theTable
            end if
          end if
        end if
      end if
    end if
  end repeat
  return empty
end _FindFirstInstanceOfFieldInTables


private function _TranslateConditions pString
  -----
  local earlyMatch, lateMatch
  local ignoringInput
  local theChar, theCharNo
  local theCharsFollowingOperators, theCharsPrecedingOperators, theOperatorA
  local theClause
  local theEnglishExprs
  local theEscapeChars
  local theExpr, theExpression
  local theLongestExpr
  local theProcessedCharCount
  local theStartTime
  local theString
  local theSubstr
  -----
  put empty into theClause
  put false into ignoringInput
  put 0 into theProcessedCharCount
  put 0 into theCharNo

  ## todo: customize for individual databases
  ## todo: Hard coded for sqlite right now
  put "IS,IS NOT,IS GREATER THAN,IS GREATER THAN OR EQUAL TO,IS LESS THAN,IS LESS THAN OR EQUAL TO,IS IN," & \
        "IS NOT IN,IS BETWEEN,CONTAINS,DOES NOT CONTAIN,BEGINS WITH,ENDS WITH,DOES NOT BEGIN WITH,DOES NOT END WITH" into theEnglishExprs
  sort items of theEnglishExprs numeric descending by _SortByLength(each)
  put the number of chars of item 1 of theEnglishExprs into theLongestExpr

  put "'" & quote into theEscapeChars
  put " ')" & quote into theCharsPrecedingOperators
  put " '(" & quote into theCharsFollowingOperators

  repeat with theCharNo = 1 to the number of chars of pString
    put char theCharNo of pString into theChar

    ## Look for escape chars
    if ignoringInput then
      if theChar is "\" then
        ## Add to string and then skip next char
        add 1 to theCharNo
        put theChar & char theCharNo of pString after theString
        next repeat
      end if
    end if

    if ignoringInput then
      ## Should we stop ignoring?
      if theChar is in theEscapeChars then
        put false into ignoringInput
        put theChar after theString
        next repeat
      end if
    else
      ## Should we start ignoring?
      if theChar is in theEscapeChars then
        put true into ignoringInput
        put theChar after theString
        next repeat
      end if
    end if

    ## Process char
    if not ignoringInput then
      local thePrecedingChar, theCharFollowingExpr

      ## Look for english expressions.
      ## Only start looking if previous char is space
      put char theCharNo to (theCharNo + (theLongestExpr - 1)) of pString into theSubstr
      put char (theCharNo - 1) of pString into thePrecedingChar
      if theOperatorA["start"] is empty and char (theCharNo - 1) of pString is space then
        repeat for each item theExpr in theEnglishExprs ## items go from longest expression to shortest
          if theSubstr begins with theExpr then
            ## Check that a valid termination character comes after expression: space ' ( :
            put char ( theCharNo + length(theExpr) ) of pString into theCharFollowingExpr

            if (theCharsFollowingOperators & ":") contains theCharFollowingExpr then
              put theCharNo - theProcessedCharCount into theOperatorA["start"]
              put theExpr into theExpression

              ## Update string and charNo/char with found expression
              put char theCharNo to (theCharNo + (length(theExpression) - 2)) of pString after theString
              put theCharNo + (length(theExpression) - 1) into theCharNo
              put char theCharNo of pString into theChar

              exit repeat
            end if
          end if
        end repeat
      end if

      put theChar after theString

      local terminationMatch

      ## Look for match in string with (...)AND/(...)OR
      ## Make sure AND/OR falls outside range of theExpression though
      put theCharsPrecedingOperators contains theChar and \
            ( (char 2 to 4 of theSubstr is "AND" and theCharsFollowingOperators contains char 5 of theSubstr) or \
            (char 2 to 3 of theSubstr is "OR" and theCharsFollowingOperators contains char 4 of theSubstr ) ) into terminationMatch

      ## Process string
      if terminationMatch then
        put theOperatorA["start"] + length(theExpression) - 1 into theOperatorA["end"]
        _ProcessEnglishOperatorChunk theClause, theString, theOperatorA

        put empty into theString
        put theCharNo into theProcessedCharCount
        put empty into theOperatorA
        put empty into theExpression
      end if

    else
      put theChar after theString
    end if
  end repeat

  ## Final cleanup
  if theOperatorA["start"] > 0 or theOperatorA["start"] is empty then
    put theOperatorA["start"] + length(theExpression) - 1 into theOperatorA["end"]
    _ProcessEnglishOperatorChunk theClause, theString, theOperatorA
  end if

  return theClause
end _TranslateConditions


private command _ProcessEnglishOperatorChunk @xClause, pString, pOperatorA
  local theValueA, theCharsToSkip

  ## Get portion of string appearing after expression
  put pOperatorA["end"] + 1 into theValueA["start"]
  put the number of chars of pString into theValueA["end"]

  put " )" into theCharsToSkip

  ## Find last char of value
  repeat with i = theValueA["end"] down to 1
    if not (theCharsToSkip contains char i of pString) then
      put i into theValueA["end"]
      exit repeat
    end if
  end repeat

  ## Now we have first char of expression and last char of value. Process.
  put _ConvertEnglishOperatorToSQLExpressionInString(pString, pOperatorA, theValueA) after xClause

  return empty
end _ProcessEnglishOperatorChunk


private function _SortByLength pStr
  return length(pStr)
end _SortByLength


private function _ConvertEnglishOperatorToSQLExpressionInString pString, pOperatorA, pValueA
  -----
  local theEnglishOperator
  local theValue
  -----
  put char pOperatorA["start"] to pOperatorA["end"] of pString into theEnglishOperator
  put char pValueA["start"] to pValueA["end"] of pString into theValue

  -- answer "in:" && quote & pString & quote & cr & theEnglishOperator

  switch theEnglishOperator
    case "IS"
      if word 1 to -1 of theValue is "NULL" then
        -- NOTHING, ALREADY IN CORRECT SYNTAX
      else if word 1 to -1 of theValue is "empty" then
        put "= ''" into char pOperatorA["start"] to pValueA["end"] of pString
      else
        put "=" into char pOperatorA["start"] to pOperatorA["end"] of pString
      end if
      break
    case "IS NOT"
      if word 1 to -1 of theValue is "NULL" then
        -- NOTHING, ALREADY IN CORRECT SYNTAX
      else
        put "!=" into char pOperatorA["start"] to pOperatorA["end"] of pString
      end if
      break
    case "IS GREATER THAN"
      put ">" into char pOperatorA["start"] to pOperatorA["end"] of pString
      break
    case "IS GREATER THAN OR EQUAL TO"
      put ">=" into char pOperatorA["start"] to pOperatorA["end"] of pString
      break
    case "IS LESS THAN"
      put "<" into char pOperatorA["start"] to pOperatorA["end"] of pString
      break
    case "IS LESS THAN OR EQUAL TO"
      put "<=" into char pOperatorA["start"] to pOperatorA["end"] of pString
      break
    case "IS IN"
    case "IS NOT IN"
      if char 1 of word 1 of theValue is "'" then
        delete char 1 of word 1 of theValue
      end if
      if char -1 of word -1 of theValue is "'" then
        delete char -1 of word -1 of theValue
      end if

      if char 1 of word 1 of theValue is not "(" then
        put "(" before word 1 of theValue
      end if
      if the last char of the last word of theValue is not ")" then
        put ")" after the last word of theValue
      end if
      put theValue into char pValueA["start"] to pValueA["end"] of pString

      if theEnglishOperator is "IS IN" then
        put "IN" into char pOperatorA["start"] to pOperatorA["end"] of pString
      else
        put "NOT IN" into char pOperatorA["start"] to pOperatorA["end"] of pString
      end if
      break
    case "IS BETWEEN"
      put "BETWEEN" into char pOperatorA["start"] to pOperatorA["end"] of pString
      break
    case "CONTAINS"
    case "DOES NOT CONTAIN"
      ## Support the use of functions: CONTAINS UPPER(':1')
      ## New behavior
      put _AddWildcardToSearchString(theValue, true, true) into theValue
      put theValue into char pValueA["start"] to pValueA["end"] of pString

      if theEnglishOperator is "CONTAINS" then
        put "LIKE" into char pOperatorA["start"] to pOperatorA["end"] of pString
      else
        put "NOT LIKE" into char pOperatorA["start"] to pOperatorA["end"] of pString
      end if
      break
    case "BEGINS WITH"
    case "DOES NOT BEGIN WITH"
      put _AddWildcardToSearchString(theValue, false, true) into theValue
      put theValue into char pValueA["start"] to pValueA["end"] of pString

      if theEnglishOperator is "BEGINS WITH" then
        put "LIKE" into char pOperatorA["start"] to pOperatorA["end"] of pString
      else
        put "NOT LIKE" into char pOperatorA["start"] to pOperatorA["end"] of pString
      end if
      break
    case "ENDS WITH"
    case "DOES NOT END WITH"
      put _AddWildcardToSearchString(theValue, true, false) into theValue
      put theValue into char pValueA["start"] to pValueA["end"] of pString

      if theEnglishOperator is "ENDS WITH" then
        put "LIKE" into char pOperatorA["start"] to pOperatorA["end"] of pString
      else
        put "NOT LIKE" into char pOperatorA["start"] to pOperatorA["end"] of pString
      end if
      break
  end SWITCH

  -- answer "out:" && quote & pString & quote

  return pString
end _ConvertEnglishOperatorToSQLExpressionInString


private function _AddWildcardToSearchString pValue, pAddPrefix, pAddSuffix
  local theStartCharNo, theEndCharNo

  put offset("'", pValue) into theStartCharNo
  if theStartCharNo > 0 then
    put offset("'", pValue, theStartCharNo) into theEndCharNo
    if theEndCharNo is 0 then
      put the number of chars of pValue into theEndCharNo
    else
      add theStartCharNo to theEndCharNo
    end if
  else
    put 0 into theStartCharNo
    put the number of chars of pValue into theEndCharNo
  end if

  if pAddSuffix is not false then put "%" before char theEndCharNo of pValue
  if pAddPrefix is not false then put "%" after char theStartCharNo of pValue

  return pValue
end _AddWildcardToSearchString


--> Array Hierarchy Parsers (Private)


/**
Summary: Converts the current row of a cursor to an array keyed by each column name.
* Assumes the cursor is not at the end.
*/
private command _CursorRowToArray pQueryA, pFields, @xArray, pDynamicKeyA
  local theValue, theNextKeyIndex, i
  local theFldRef

  -- pFields should be the fields as returned by revDatabaseColumnNames. The names
  -- need to match up with the revDB index since we access by index below.
  put the number of elements of pDynamicKeyA + 1 into theNextKeyIndex

  switch sDbsA[ pQueryA["database"] ]["connections"][ pQueryA["connection"] ]["type"]
    case "valentina"
      if pFields is empty then put  _ValentinaFieldsFromCursor( pQueryA["cursor id"] ) into pFields
      replace comma with cr in pFields

      repeat for each line theField in pFields
        add 1 to i
        put VCursor_Field(pQueryA["cursor id"], i) into theFldRef
        put theField into pDynamicKeyA[theNextKeyIndex]
        if pQueryA["report null"] and VField_IsNull(theFldRef) then
          put "NULL" into xArray[ pDynamicKeyA ]
        else
          switch VField_Type(theFldRef)
            case "kTypePicture"
            case "kTypeBLOB"
              get VBLOB_ReadData(theFldRef, "theValue")
              put theValue into xArray[ pDynamicKeyA ]
              break
            case "kTypeText"
            case "kTypeFixedBinary"
            case "kTypeVarBinary"
            default
              put VField_Value(theFldRef) into xArray[ pDynamicKeyA ]
          end switch
        end if
      end REPEAT
      break

    default
      if pFields is empty then put _CursorFieldNames(pQueryA["cursor id"]) into pFields
      replace comma with cr in pFields

      repeat for each line theField in pFields
        add 1 to i
        put theField into pDynamicKeyA[theNextKeyIndex]
        if pQueryA["report null"] and revDatabaseColumnIsNull(pQueryA["cursor id"], i) is true then
          put "NULL" into xArray[ pDynamicKeyA ]
        else
          ## We could probably set the array key directly if we didn't have to pass in dynamic key
          ## dynamic key is required because we can't pass array by ref
          ## We use "theValue" so we can get binary data
          get revDatabaseColumnNumbered(pQueryA["cursor id"], i, "theValue")
          put theValue into xArray[ pDynamicKeyA ]
        end if
      end REPEAT
      break
  end SWITCH

  --> todo: Apply encodings

  return empty
end _CursorRowToArray


private function _QueryTableHierarchyStructure @xQueryA, pCursorFields
  -----
  local i
  local theField
  local theHierarchyA
  local theItemNo
  local theRootTable
  local theTable, theTableA
  local theTablesInSelectClauseA
  -----
  if pCursorFields is empty then
    put revDatabaseColumnNames(xQueryA["cursor id"]) into pCursorFields
    replace comma with cr in pCursorFields
  end if

  set the wholeMatches to true

  ## Create hierarchy structure. We create a flattened structure indexed by table names in the query.
  ## This will be used for converting our flat rows into a hierarchal structure.
  -- "unique fields"
  -- "parent"
  -- "relationship to parent"
  -- "children"
  -- "fields"
  -- "current unique key"
  put sqlquery_get(xQueryA, "table") into theRootTable
  if tableobjects_tableExists(theRootTable, xQueryA["database"]) then
    put tableobjects_getTable(theRootTable, xQueryA["database"]) into theTableA
  end if

  ## Fill in root table
  if theTableA is an array then
    local theJoinsA

    put tableobj_get(theTableA, "primary key") into theHierarchyA[theRootTable]["unique fields"]

    ## Now fill in joins tables in hierarchal structure
    put sqlquery_get(xQueryA, "related table joins including scopes") into theJoinsA

    _ConvertQueryJoinToFlatHierarchy theHierarchyA, xQueryA["database"], theJoinsA, theRootTable
  else
    put sDbsA[ xQueryA["database"] ]["schema"]["tables"][ theRootTable ]["primary key"] into theHierarchyA[theRootTable]["unique fields"]
  end if
  put empty into theHierarchyA[theRootTable]["parent"]
  put empty into theHierarchyA[theRootTable]["relationship to parent"]

  ## We need to know which fields Fields may or may not have table name prefixed.
  ## Put fields into each table entry in hierarchy array. Then build rest of array.
  ## This allows us to properly store the 'unique fields' since we know if the table field
  ## prefixes the reference or not.
  local theTables

  put sqlquery_get(xQueryA, "tables") into theTables
  set the itemDelimiter to "."

  repeat for each line theField in pCursorFields
    if the number of items of theField > 1 then
      put item 1 of theField into theTable
    else
      put _FindFirstInstanceOfFieldInTables(xQueryA["database"], theTables, theField) into theTable
      if theTable is empty then
        ## Probably a virtual column. Attach to root table
        put theRootTable into theTable
      end if
    end if

    put theField into line (the number of lines of theHierarchyA[theTable]["fields"] + 1) of theHierarchyA[theTable]["fields"]

    ## Keep a list of tables that are actually in the results
    put 1 into theTablesInSelectClauseA[theTable]
  end repeat

  set the itemDelimiter to ","

  ## Now make sure that 'unique fields' listed use proper name as appears in the cursor fields
  ## This will also alert us if unique field is not in query
  repeat for each key theTable in theHierarchyA
    repeat with i = 1 to the number of items of theHierarchyA[theTable]["unique fields"]
      put lineOffset(item i of theHierarchyA[theTable]["unique fields"], theHierarchyA[theTable]["fields"]) into theItemNo

      if theItemNo is 0 then
        ## Check for table prefix
        put lineOffset(theTable & "." & item i of theHierarchyA[theTable]["unique fields"], theHierarchyA[theTable]["fields"]) into theItemNo
        if theItemNo > 0 then
          put theTable & "." & item i of theHierarchyA[theTable]["unique fields"] into item i of theHierarchyA[theTable]["unique fields"]
        else if theHierarchyA[theTable]["fields"] is not empty then ## if fields are in select clause we need unique fields
          ## -- The IF check above misses checking the linking table which is bad. Better to enforce all keys
          ## -- if the user wants to convert to records.
          ## -- If table is in select clause and unique field isn't present then throw error
          _ThrowError kErrCantFindObject, "unique field '" & item i of theHierarchyA[theTable]["unique fields"] & "' for table '" & theTable & "' is not present in the cursor"
        end if
      end if
    end repeat
  end repeat

  return theHierarchyA
end _QueryTableHierarchyStructure


/**
Summary: Converts a db cursor to a hierarchal array of Record objects based on relationships between tables.

xQueryA: The SQL Query object that created the cursor.
xOutArray: The resulting array of Record objects.

Returns: Error
*/
private command _HierarchalCursorToArray @xQueryA, @xOutArray
  local theCursorFields, theType, theRowA
  local theError
  local theHierarchyA
  local theRootTable, theConnectionA
  local theIndex

  set the wholeMatches to true
  put dbconn_get("type", xQueryA["connection"]) into theType

  ## Initialize
  if theError is empty then
    if theType is "valentina" then
      put _ValentinaFieldsFromCursor(xQueryA["cursor id"]) into theCursorFields
    else
      put revDatabaseColumnNames(xQueryA["cursor id"]) into theCursorFields
    end if
    replace comma with cr in theCursorFields
    put _QueryTableHierarchyStructure(xQueryA, theCursorFields) into theHierarchyA
  end if

  # We are converting a SQL cursor to a hierarchal data structure.  Each row represents multiple dimensions of
  # an array.  SQL results will include duplicates result sets of parent table data for each child table data
  # returned.  We store a list of unique keys that identify table records in each dimension.  This enables us
  # filter out duplicate entries.
  if theError is empty then
    put sqlquery_get(xQueryA, "table") into theRootTable
    put sqlquery_get(xQueryA, "connection") into theConnectionA

    if theType is "valentina" then
      ##
      ## VALENTINA
      ##
      if VCursor_FirstRecord(xQueryA["cursor id"]) then
        repeat forever
          add 1 to theIndex
          _CursorRowToArray xQueryA, theCursorFields, theRowA, empty

          ## move over any db/connection info
          put xQueryA["database"] into theRowA["@database"]
          put xQueryA["connection"] into theRowA["@connection"]

          ## Convert to hierarchy
          _ConvertRowTableFieldsToArray theConnectionA, theRowA, theRootTable, xOutArray, theHierarchyA, empty

          get VCursor_NextRecord( xQueryA["cursor id"])
          if not it then exit repeat
        end repeat
      end if

    else
      ##
      ## OTHER
      ##
      if not revQueryIsAtEnd(xQueryA["cursor id"]) then
        repeat forever
          add 1 to theIndex
          _CursorRowToArray xQueryA, theCursorFields, theRowA, empty

          ## move over any db/connection info
          put xQueryA["database"] into theRowA["@database"]
          put xQueryA["connection"] into theRowA["@connection"]

          ## Convert to hierarchy
          _ConvertRowTableFieldsToArray theConnectionA, theRowA, theRootTable, xOutArray, theHierarchyA, empty

          revMoveToNextRecord xQueryA["cursor id"]
          if not the result then exit repeat
        end repeat
      end if
    end if
  end if

  return theError
end _HierarchalCursorToArray


private command _ConvertRowTableFieldsToArray pConnectionA, pRowA, pTable, @xOutArray, @xTableHierarchyA, pDynamicKeyA
  -----
  local usingAnArray, theColumn
  local theCurrentParentUniqueKey
  local theField
  local theIndex
  local theNextIndex
  local theRowTableUniqueKey
  local theTable, theTableUniqueKey
  -----

  put pDynamicKeyA is an array into usingAnArray
  set the wholeMatches to true

  ## Check unique keys for table. If NULL or empty we are done with this table
  repeat for each item theField in xTableHierarchyA[pTable]["unique fields"]
    if pRowA[theField] is "NULL" or pRowA[theField] is empty then
      ## No need to process children tables. Just get out.
      return empty
    else
      ## Table unique key is table.field.value
      put pRowA[theField] & comma after theTableUniqueKey
    end if
  end REPEAT

  ## WHAT WE WATCH OUT FOR
  ## if you have a root table with:
  ## * at least two children
  ## * both children have more than 1 record
  ## * 1 child has more records than the other child

  ## Lookup the index for this row. If used before then no need to reinsert the data
  put xTableHierarchyA[ xTableHierarchyA[pTable]["parent"] ]["current unique key"] into theCurrentParentUniqueKey
  put theCurrentParentUniqueKey & theTableUniqueKey into theRowTableUniqueKey

  ## Store this unique key as the current unique key being used for table pTable
  put theRowTableUniqueKey into xTableHierarchyA[pTable]["current unique key"]
  put xTableHierarchyA[pTable][theRowTableUniqueKey] into theIndex

  ## Create index entry in dynamic key =  table[INDEX][column]
  if theIndex is empty then
    ## Determine next index
    ## The child in a many-to-many used table["column"] rather than table[INDEX][column]

    ## many-to-many and one-to-one (note that cross-ref table is 'many-to-many cross reference') can
    ## only have one record so we don't store results in a indexed list [1], [2], etc. We store the result
    ## directly in the table key i.e. [steps][col1], [steps][col2], etc.
    if xTableHierarchyA[pTable]["relationship to parent"] is among the items of "n-n,1-1" then
      put -1 into theIndex
    else
      if usingAnArray then
        put the number of elements of xOutArray[pDynamicKeyA] into theIndex
      else
        put the number of elements of xOutArray into theIndex
      end if

      add 1 to theIndex
      put theIndex into pDynamicKeyA[max(1, the number of elements of pDynamicKeyA + 1)]
    end if

    ## Identify as record
    put pTable into xOutArray[pDynamicKeyA]["@table"]
    put pRowA["@database"] into xOutArray[pDynamicKeyA]["@database"]
    put pRowA["@connection"] into xOutArray[pDynamicKeyA]["@connection"]

    ## Fill in values for columns
    set the itemDelimiter to "."
    repeat for each line theColumn in xTableHierarchyA[pTable]["fields"]
      ## Use -1 so that we only use field name rather than table.field
      put item -1 of theColumn into theField
      put pRowA[theColumn] into xOutArray[pDynamicKeyA][theField]

      ## BOOLEAN CONVERSION
      if sDbsA[ pConnectionA["database"] ]["schema"]["tables"][ pTable ]["fields"][ theField ]["meta type"] is "boolean" then
        set the itemDelimiter to ","
        put xOutArray[pDynamicKeyA][theField] is among the items of kBoolTrueValues into xOutArray[pDynamicKeyA][theField]
        set the itemDelimiter to "."
      end if
    end repeat
    set the itemDelimiter to ","

    ## Store index for this key which marks it as having been used
    put theIndex into xTableHierarchyA[pTable][theRowTableUniqueKey]
  else
    ## Already used, just insert the index into the array index (if >0) before processing child tables
    ## The highest index in array index right now is parent table name.
    if theIndex > 0 then
      put theIndex into pDynamicKeyA[max(1, the number of elements of pDynamicKeyA + 1)]
    end if
  end if

  ## todo: Hmm, what about having a table,sibling table hierarchy entry? Then we could merge one-to-one
  ## into a single array entry...

  ## Store children tables in their child array
  put the number of elements of pDynamicKeyA + 1 into theNextIndex
  repeat for each line theTable in xTableHierarchyA[pTable]["children"]
    put theTable into pDynamicKeyA[theNextIndex]

    -- if the shiftkey is down then -- pTable is "tlk_tagged" then
    -- answer pTable & cr && theTable & cr &  printKeys(pDynamicKeyA)
    -- end if

    _ConvertRowTableFieldsToArray pConnectionA, pRowA, theTable, xOutArray, xTableHierarchyA, pDynamicKeyA
  end repeat

  return empty
end _ConvertRowTableFieldsToArray


private command _ConvertQueryJoinToFlatHierarchy @xHierarchyA, pKey, pJoinA, pParentTable
  -----
  local i
  local theCount
  local theIndex, theTableIndex
  local theNextIndex
  local theRelationA
  local theRelationRefA
  local theTable, theTableA
  local usingAnArray
  -----
  put the number of elements of pJoinA into theCount

  repeat with i = 1 to theCount
    put pJoinA[ i ]["table"]["name"] into theTable
    put kTableReference into theTableA["type"]
    put pKey into theTableA["database"]
    put theTable into theTableA["name"]

    ## Get relationship and relationship ref
    put sDbsA[pKey]["table objects"]["relationships"][ pJoinA[ i ]["relationship index"] ] into theRelationA
    put kRelationshipReference into theRelationRefA["type"]
    put pKey into theRelationRefA["database"]
    put pJoinA[ i ]["relationship index"] into theRelationRefA["index"]

    ## Figure out unique fields
    if theTable is theRelationA["left table"] or theTable is theRelationA["right table"] then
      put tableobj_get(theTableA, "primary key") into xHierarchyA[theTable]["unique fields"]

    else if theTable is theRelationA["cross-reference table"] then
      put tblrelation_get(theRelationRefA, "cross-reference table key for left table without values") & comma & \
            tblrelation_get(theRelationRefA, "cross-reference table key for right table without values") into xHierarchyA[theTable]["unique fields"]
    else
      ## no match
      _ThrowError kErrInvalidProperty, "relationship is not valid in " & param(0)
    end if

    ## put in parent
    put pParentTable into xHierarchyA[theTable]["parent"]

    ## put in relationship to parent and normalize
    put theRelationA["type"] into xHierarchyA[theTable]["relationship to parent"]
    switch theRelationA["type"]
      case "many-to-many"
      case "n-n"
        if theTable is theRelationA["cross-reference table"] then
          put "n-n cross reference" into xHierarchyA[theTable]["relationship to parent"]
        else
          put "n-n" into xHierarchyA[theTable]["relationship to parent"]
        end if
        break
      case "one-to-many"
      case "1-n"
        if theTable is theRelationA["right table"] then
          put "n-1" into xHierarchyA[theTable]["relationship to parent"]
        else
          put "1-n" into xHierarchyA[theTable]["relationship to parent"]
        end if
        break
      case "one-to-one"
      case "1-1"
        put "1-1" into xHierarchyA[theTable]["relationship to parent"]
        break
    end switch

    ## Add to parent's children
    put theTable into line (the number of lines of xHierarchyA[pParentTable]["children"] + 1) of xHierarchyA[pParentTable]["children"]

    ## Now make a recursive call in order to handle the "related table joins" of this entry.
    _ConvertQueryJoinToFlatHierarchy xHierarchyA, pKey, pJoinA[i]["related table joins"], theTable
  end repeat

  return empty
end _ConvertQueryJoinToFlatHierarchy


--> Relationship Handlers (Private)


## Returns the dynamic key array of table in a joins array. Empty if not found
private function _FindTableInQueryJoins pJoinsA, pTable, pDynamicKeyA
  local theTargetIndex, theCount, theFoundKeyA
  local theNextIndex

  if pDynamicKeyA is not an array then
    put 1 into theTargetIndex
    put the number of elements of pJoinsA into theCount
  else
    put the number of elements of pDynamicKeyA + 1 into theTargetIndex
    put the number of elements of pJoinsA[pDynamicKeyA] into theCount
  end if

  repeat with i = 1 to theCount
    put i into pDynamicKeyA[theTargetIndex]
    if pTable is pJoinsA[ pDynamicKeyA ]["table name"] then
      put pDynamicKeyA into theFoundKeyA
      exit repeat
    else if pJoinsA[pDynamicKeyA]["related table joins"] is an array then
      put the number of elements of pDynamicKeyA into theNextIndex
      add 1 to theNextIndex
      put "related table joins" into pDynamicKeyA[theNextIndex]
      put _FindTableInQueryJoins(pJoinsA, pTable, pDynamicKeyA) into theFoundKeyA
      if theFoundKeyA is an array then
        exit repeat
      else
        ## restore dynamic key array for next iteration
        delete local pDynamicKeyA[theNextIndex]
      end if
    end if
  end repeat

  return theFoundKeyA
end _FindTableInQueryJoins


private command _TablesInQueryJoin @xTablesA, pJoinsA, pDynamicKeyA
  -----
  local i
  local theCount
  local theNextIndex
  local theTargetIndex, theArrayIndex
  -----
  if pDynamicKeyA is not an array then
    put 1 into theTargetIndex
    put the number of elements of pJoinsA into theCount
  else
    put the number of elements of pDynamicKeyA + 1 into theTargetIndex
    put the number of elements of pJoinsA[pDynamicKeyA] into theCount
  end if

  put the number of elements of xTablesA into theArrayIndex

  repeat with i = 1 to theCount
    add 1 to theArrayIndex
    put i into pDynamicKeyA[theTargetIndex]

    put pJoinsA[ pDynamicKeyA ]["table"]["name"] into xTablesA[theArrayIndex]["name"]
    put pJoinsA[ pDynamicKeyA ]["table"]["as"] into xTablesA[theArrayIndex]["as"]

    if pJoinsA[pDynamicKeyA]["related table joins"] is an array then
      put the number of elements of pDynamicKeyA into theNextIndex
      add 1 to theNextIndex
      put "related table joins" into pDynamicKeyA[theNextIndex]

      _TablesInQueryJoin xTablesA, pJoinsA, pDynamicKeyA

      ## restore dynamic key array for next iteration
      delete local pDynamicKeyA[theNextIndex]
      put the number of elements of xTablesA into theArrayIndex // update array index
    end if
  end repeat

  return empty
end _TablesInQueryJoin


private command _JoinClauseFromQueryJoin @xClause, @xRelationshipOrderBy, pKeyOrConnection, pLeftTable, pLeftTableAs, pJoinsA
  ## Join it baby!
  __JoinClauseFromQueryJoin xClause, xRelationshipOrderBy, pKeyOrConnection, pLeftTable, pLeftTableAs, pJoinsA
  delete the last char of xClause
end _JoinClauseFromQueryJoin


private command __JoinClauseFromQueryJoin @xClause, @xRelationshipOrderBy, pKeyOrConnection, pLeftTable, pLeftTableAs, pJoinsA, pDynamicKeyA
  -----
  local theDbKey, i
  local theCount
  local theTable, theTableName, theLeftTable, theLeftTableAs, theLeftTableIndex, theOrderBy
  local theNextIndex
  local theRelationA
  local theTableIndex
  local theTargetIndex
  local theQsA
  -----
  if pKeyOrConnection is an array then
    put pKeyOrConnection["database"] into theDbKey
    put dbconn_get("effective quotes", pKeyOrConnection) into theQsA
  end if

  if pDynamicKeyA is not an array then
    put 1 into theTargetIndex
    put the number of elements of pJoinsA into theCount
  else
    put the number of elements of pDynamicKeyA + 1 into theTargetIndex
    put the number of elements of pJoinsA[pDynamicKeyA] into theCount
  end if

  repeat with i = 1 to theCount
    put i into pDynamicKeyA[theTargetIndex]

    put pJoinsA[ pDynamicKeyA ]["table"]["name"] into theTable

    if pJoinsA[ pDynamicKeyA ]["relationship index"] > 0 then
      ## Assume we have a relationship index for now
      put tableobjects_getRelationship(pJoinsA[ pDynamicKeyA ]["relationship index"], theDbKey) into theRelationA

      ## Build up ORDER by for relationships
      put tblrelation_get(theRelationA, "order by") into theOrderBy
      if theOrderBy is not empty then
        put theOrderBy & cr after xRelationshipOrderBy
      end if
    else
      put empty into theRelationA
    end if

    ## Start JOIN clause

    ## Look for aliases
    if sDbsA[ theDbKey ]["table objects"]["tables"][ theTable ]["type"] is "alias" then
      if pJoinsA[ pDynamicKeyA ]["table"]["as"] is empty then
        put theTable into pJoinsA[ pDynamicKeyA ]["table"]["as"]
      end if
      put sDbsA[ theDbKey ]["table objects"]["tables"][ theTable ]["alias for table"] into theTableName
    else
      put theTable into theTableName
    end if

    put toUpper(pJoinsA[ pDynamicKeyA ]["join type"]) && "JOIN" after xClause
    put space & theQsA["left"] & theTableName & theQsA["right"] after xClause
    if pJoinsA[ pDynamicKeyA ]["table"]["as"] is not empty then
      put " AS " & theQsA["left"] & pJoinsA[ pDynamicKeyA ]["table"]["as"] & theQsA["right"] after xClause
    end if
    put " ON " after xClause

    if pJoinsA[ pDynamicKeyA ]["on clause"] is not empty then
      put pJoinsA[ pDynamicKeyA ]["on clause"] & space after xClause
    else
      ## Add on key in clause
      if pKeyOrConnection is an array then
        put pKeyOrConnection["name"] into theRelationA["connection"]
      end if

      put _ForeignKeyClauseFromRelationship(theRelationA, \
            pLeftTable, pLeftTableAs, \
            pJoinsA[ pDynamicKeyA ]["table"]["name"], pJoinsA[ pDynamicKeyA ]["table"]["as"]) & space after xClause

      ## Recursive call
      if pJoinsA[pDynamicKeyA]["related table joins"] is an array then
        put pJoinsA[ pDynamicKeyA ]["table"]["name"] into theLeftTable
        put pJoinsA[ pDynamicKeyA ]["table"]["as"] into theLeftTableAs

        put the number of elements of pDynamicKeyA into theNextIndex
        add 1 to theNextIndex
        put "related table joins" into pDynamicKeyA[theNextIndex]

        __JoinClauseFromQueryJoin xClause, xRelationshipOrderBy, pKeyOrConnection, theLeftTable, theLeftTableAs, pJoinsA, pDynamicKeyA

        ## restore dynamic key array for next iteration
        delete local pDynamicKeyA[theNextIndex]
      end if
    end if
  end repeat

  return empty
end __JoinClauseFromQueryJoin


private command _RemoveDuplicateJoins pJoinsA, @xFilteredJoinsA, pDynamicKeyA, @xProcessedIDsA
  ## table.as, table.index, relationships index uniquely identify a join
  ## Perform lookup in pKeyArraysForTablesA - if we find it then append any "related table joins" to
  ## existing array. Otherwise just create it and store the key
  local theNextDynamicIndex, theNextFilterIndex, theId

  put the number of elements of pDynamicKeyA + 1 into theNextDynamicIndex
  put the number of elements of xFilteredJoinsA[ pDynamicKeyA ] into theNextFilterIndex

  repeat for each line i in _SortNumericKeys( the keys of pJoinsA)
    ## Get unique id
    put pJoinsA[i]["table"]["index"] & comma & pJoinsA[i]["table"]["as"] & comma & pJoinsA[i]["relationship index"] into theID

    ## Add if doesn't exist
    if theID is not among the keys of xProcessedIDsA then
      add 1 to theNextFilterIndex
      put theNextFilterIndex into pDynamicKeyA[theNextDynamicIndex]
      put pJoinsA[i] into xFilteredJoinsA[ pDynamicKeyA ]

      ## Log as used
      put theNextFilterIndex into xProcessedIDsA[theID]
    else
      ## It exists, get the index it is stored under from xProcessedIDsA
      put xProcessedIDsA[theID] into pDynamicKeyA[theNextDynamicIndex]

      ## Recursion
      put "related table joins" into pDynamicKeyA[theNextDynamicIndex + 1]
      _RemoveDuplicateJoins pJoinsA[i]["related table joins"], xFilteredJoinsA, pDynamicKeyA, xProcessedIDsA

      delete local pDynamicKeyA[theNextDynamicIndex + 1]
    end if
  end repeat
end _RemoveDuplicateJoins



private function _SelectClauseFromTables pConnectionA, pTablesA, pPrependTableName, pSelectColumnNamesAs
  -----
  local theEQsA, theQsA
  local theTableA, theClause
  local theField, theFields
  local theTable
  -----

  ## All fields of all tables
  put dbconn_get("effective quotes", pConnectionA) into theEQsA
  put dbconn_get("quotes", pConnectionA) into theQsA

  repeat with i = 1 to the number of elements of pTablesA
    ## If an alias then we need to resolve to actual table
    if not dbschema_tableExists(pTablesA[i]["name"], pConnectionA["database"]) then
      put tableobjects_getTable(pTablesA[i]["name"], pConnectionA["database"]) into theTableA
      if tableobj_get(theTableA, "type") is "alias" then
        put pTablesA[i]["name"] into pTablesA[i]["as"]
        put tableobj_get(theTableA, "alias for table") into pTablesA[i]["name"]
      end if
    end if

    put dbschema_tableGet(pTablesA[i]["name"], "fields", pConnectionA["database"]) into theFields
    if pPrependTableName then
      put pTablesA[i]["name"] into theTable
    end if

    ## override table name with as
    if pTablesA[i]["as"] is not empty then
      put pTablesA[i]["as"] into theTable
    end if

    repeat for each line theField in theFields
      if pPrependTableName then
        put theEQsA["left"] & theTable & theEQsA["right"] & "." & theEQsA["left"] & theField & theEQsA["right"] after theClause
      else
        put theEQsA["left"] & theField & theEQsA["right"] after theClause
      end if

      ## Only append AS if including table name
      if pSelectColumnNamesAs is "long" and pPrependTableName then
        put " AS " & theQsA["left"] & theTable & "." & theField & theQsA["right"] after theClause
      else if pSelectColumnNamesAs is "short" then
        put " AS " & theQsA["left"] & theField & theQsA["right"] after theClause
      end if

      put ", " after theClause
    end repeat

    ##
    ## Note: If table objects ever get the ability to define
    ## 'fields' that are SQL functions then we would tack them on
    ## here by checking if there is a table object for theTable
    ## put tableobjects_getTable(theTable, pConnectionA["database"]) into theTableA
    ## if theTableA is an array then ...
    ##
  end repeat
  delete char -2 to -1 of theClause

  return theClause
end _SelectClauseFromTables


private function _ForeignKeyClauseFromRelationship pRelationA, pLeftTable, pLeftTableName, pRightTable, pRightTableName
  -----
  local i
  local theClause
  local theConnectionA
  local theDbType
  local theLeftField, theLeftFields
  local theRelationA
  local theRightField, theRightFields
  local theQsA
  -----
  put sDbsA[ pRelationA["database"] ]["table objects"]["relationships"][ pRelationA["index"] ] into theRelationA
  ## pRightTableIndex is only passed when pLeftTableIndex is the cross-refernece table in a many-to-many relationship
  ## It is ignored otherwise.

  if pRelationA["connection"] is not empty then
    put tblrelation_get(pRelationA, "connection") into theConnectionA
    put dbconn_get("type", theConnectionA) into theDbType
    put dbconn_get("effective quotes", theConnectionA) into theQsA
  end if

  ## is pLeftTable left or right in relationship?
  if pLeftTable is theRelationA["left table"] then
    put tblrelation_get(pRelationA, "left table key") into theLeftFields
    -- put theRelationA["left table"]["key field indexes"] into theLeftFieldIndexes

    ## taint check
    if (theRelationA["type"] is among the items of "n-n,many-to-many" and pRightTable is not theRelationA["cross-reference table"]) and \
          (theRelationA["type"] is not among the items of "n-n,many-to-many" and pRightTable is not theRelationA["right table"])  then
      _ThrowError kErrInvalidProperty, "invalid right table '" & pRightTable & "' in relationship '" & pRelationA["index"] & "' for " & param(0)
    end if

    ## Get fields
    switch theRelationA["type"]
      case "many-to-many"
      case "n-n"
        -- put theRelationA["cross-reference table"]["keys"]["right table field indexes"] into theRightFieldIndexes
        put tblrelation_get(pRelationA, "cross-reference table key for left table") into theRightFields
        break
      case "one-to-one"
      case "1-1"
        ## Enforce ownership rules for one-to-one
        if theRelationA["owner"] is "right" then _ThrowError kErrInvalidProperty, "cannot generate key clause from a 1-1 relationship with owner='right'"
        put tblrelation_get(pRelationA, "right table key") into theRightFields
        break
      default
        put tblrelation_get(pRelationA, "right table key") into theRightFields
        -- put theRelationA["right table"]["keys"]["key field indexes"] into theRightFieldIndexes
    end switch

  else if pLeftTable is theRelationA["right table"] then
    put tblrelation_get(pRelationA, "right table key") into theLeftFields
    -- put theRelationA["right table"]["key field indexes"] into theLeftFieldIndexes

    ## taint check
    if (theRelationA["type"] is among the items of "n-n,many-to-many" and pRightTable is not theRelationA["cross-reference table"]) or \
          (theRelationA["type"] is not among the items of "n-n,many-to-many" and pRightTable is not theRelationA["left table"])  then
      _ThrowError kErrInvalidProperty, "invalid right table '" & pRightTable & "' for " & param(0)
    end if

    ## Get fields
    switch theRelationA["type"]
      case "many-to-many"
      case "n-n"
        -- put theRelationA["cross-reference table"]["keys"]["left table field indexes"] into theRightFieldIndexes
        put tblrelation_get(pRelationA, "cross-reference table key for right table") into theRightFields
        break
      case "one-to-one"
      case "1-1"
        ## Enforce ownership rules for one-to-one
        if theRelationA["owner"] is "left" then _ThrowError kErrInvalidProperty, "cannot generate key clause from a 1-1 relationship with owner='left'"
        put tblrelation_get(pRelationA, "left table key") into theRightFields
        break
      default
        put tblrelation_get(pRelationA, "left table key") into theRightFields
        -- put theRelationA["left table"]["keys"]["key field indexes"] into theRightFieldIndexes
    end switch

  else if pLeftTable is theRelationA["cross-reference table"] then
    ## taint check
    if pRightTable is not theRelationA["left table"] and \
          pRightTable is not theRelationA["right table"]  then
      _ThrowError kErrInvalidProperty, "invalid right table '" & pRightTable & "' in relationship '" & pRelationA["index"] & "' for " & param(0)
    end if

    if pRightTable is theRelationA["left table"] then
      put tblrelation_get(pRelationA, "cross-reference table key for left table") into theLeftFields
      put tblrelation_get(pRelationA, "left table key") into theRightFields
      -- put theRelationA["cross-reference table"]["keys"]["left table field indexes"] into theLeftFieldIndexes
      -- put theRelationA["left table"]["keys"]["key field indexes"] into theRightFieldIndexes
    else if pRightTable is theRelationA["right table"] then
      put tblrelation_get(pRelationA, "cross-reference table key for right table") into theLeftFields
      put tblrelation_get(pRelationA, "right table key") into theRightFields
      -- put theRelationA["cross-reference table"]["keys"]["right table field indexes"] into theLeftFieldIndexes
      -- put theRelationA["right table"]["keys"]["key field indexes"] into theRightFieldIndexes
    else
      _ThrowError kErrInvalidProperty, "invalid right table '" & pRightTable & "' in relationship '" & pRelationA["index"] & "' for " & param(0)
    end if
  end if

  if pLeftTableName is empty then put pLeftTable into pLeftTableName
  if pRightTableName is empty then put pRightTable into pRightTableName

  ## Now we have left/right tables and left/right fields. Build the clause.
  ## righttable.rightFields = lefttable.leftFields
  put empty into theClause
  ## Note: adding an extra comma on won't add any items but it will count last item in theLeftFields it is empty
  repeat with i = 1 to max(the number of items of theLeftFields, the number of items of theRightFields)
    put item i of theLeftFields into theLeftField
    put item i of theRightFields into theRightField
    split theLeftField by "=" ## account for field=value
    split theRightField by "="

    if the number of elements of theLeftField > 1 then
      put theQsA["left"] & pLeftTableName & theQsA["right"] & "." & \
            theQsA["left"] & theLeftField[1] & theQsA["right"] && "=" && "'" & _EscapeDbString(theDbType, theLeftField[2]) & "' AND " after theClause
    else if the number of elements of theRightField > 1 then
      put theQsA["left"] & pRightTableName & theQsA["right"] & "." & \
            theQsA["left"] & theRightField[1] & theQsA["right"] && "=" && "'" & _EscapeDbString(theDbType, theRightField[2]) & "' AND " after theClause
    else
      ## straight up fields
      put theQsA["left"] & pRightTableName & theQsA["right"] & "." & \
            theQsA["left"] & theRightField[1] & theQsA["right"] && "=" && \
            theQsA["left"] & pLeftTableName & theQsA["right"] & "." & \
            theQsA["left"] & theLeftField[1] & theQsA["right"] & " AND " after theClause
    end if
  end repeat
  delete the last word of theClause
  return theClause
end _ForeignKeyClauseFromRelationship


private function _StringToJoins pRootTableA, pString
  -----
  local i,theAs
  local theEntry
  local theIndex, theTableIndex
  local theJoin, theJoinType
  local theJoinsA
  local theRelationsA, theJoinDynamicKeyA, theRelDynamicKeyA
  local theTable, theToTableA
  local theWordNo, theCharNo, theOnClause
  -----

  set the wholematches to true

  ## LEFT OUTER JOIN steps, tlk_lessons_servers
  repeat for each item theEntry in pString
    add 1 to theIndex
    put word 1 to -1 of theEntry into theJoin
    put empty into theOnClause

    put offset(" ON ", theJoin) into theCharNo
    if theCharNo > 0 then
      put char (theCharNo + 4) to -1 of theJoin into theOnClause
      delete char theCharNo to -1 of theJoin
    end if

    put wordOffset("JOIN", theJoin) into theWordNo
    if theWordNo > 0 then
      put word theWordNo + 1 to -1 of theJoin into theTable
      put toLower(word 1 to theWordNo - 1 of theJoin) into theJoinType
    else
      put kDefaultJoinType into theJoinType
      put theJoin into theTable
    end if

    put wordOffset("AS", theTable) into theWordNo
    if theWordNo > 0 then
      put word theWordNo + 1 to -1 of theTable into theAs
      put word 1 to theWordNo - 1 of theTable into theTable
    else
      put empty into theAs
    end if

    if pRootTableA is not an array then
      ## No root table provided. Don't do any lookup of relationships.
      ## Developer MUST explicitly define ON relationships.
      if theOnClause is not empty then
        put the number of elements of theJoinsA + 1 into theIndex
        put theOnClause into theJoinsA[ theIndex ]["on clause"]
        put theTable into theJoinsA[ theIndex ]["table"]["name"]
        put theAs into theJoinsA[ theIndex ]["table"]["as"]
        put theJoinType into theJoinsA[ theIndex ]["join type"]
        put 0 into theJoinsA[ theIndex ]["relationship index"]
      else
        _ThrowError kErrInvalidProperty, "no ON clause was provided in the JOIN statement: " & theJoin
      end if
    else
      ## Passing in a root table then look up relationships
      if theTable is not among the keys of sDbsA[ pRootTableA["database"] ]["table objects"]["tables"] then
        _ThrowError kErrCantFindObject, "table '" & theTable & "' was not found in database '" & pRootTableA["database"] & "'"
      end if

      put tableobjects_getTable(theTable, pRootTableA["database"]) into theToTableA

      ## Lookup relationship between our friends
      put _FindRelationshipBetweenTables(pRootTableA, theToTableA) into theRelationsA

      ## Add to join
      local theRelationshipType, theCrossRefTable, theToTable

      put empty into theJoinDynamicKeyA
      repeat with i = 1 to the number of elements of theRelationsA
        ## is relationship already in JOIN?
        put tblrelation_get(theRelationsA[i], "type") into theRelationshipType
        put tblrelation_get(theRelationsA[i], "cross-reference table") into theCrossRefTable
        put tblrelation_get(theRelationsA[i], theRelationsA[i]["to table key"]) into theToTable
        put _DynamicKeyForRelationshipInJoin(theJoinsA, theRelationsA[i]["index"], theToTable) into theRelDynamicKeyA

        if theRelDynamicKeyA is an array then
          ## already exists, nothing to do
          put theRelDynamicKeyA into theJoinDynamicKeyA
        else
          ## If theJoinDynamicKeyA is an array then the last index will have an integer.
          ## We append "related table joins" to that and then determine the next index of that array.
          ## If theJoinDynamicKeyA is NOT an array then we get the next highest index
          ## of theJoinsA
          if theJoinDynamicKeyA is an array then
            put the number of elements of theJoinDynamicKeyA + 1 into theIndex
            put "related table joins" into theJoinDynamicKeyA[ theIndex ]
            put the number of elements of theJoinsA[ theJoinDynamicKeyA ] + 1 into theJoinDynamicKeyA[ theIndex + 1 ]
          else
            put the number of elements of theJoinsA + 1 into theJoinDynamicKeyA[1]
          end if

          ## If this is a many-to-many and the to table IS NOT the cross-reference table then add in the cross-ref table
          if theRelationshipType is among the items of "n-n,many-to-many" and theToTable is not theCrossRefTable then
            put theCrossRefTable into theJoinsA[ theJoinDynamicKeyA ]["table"]["name"]
            put theRelationsA[i]["index"] into theJoinsA[ theJoinDynamicKeyA ]["relationship index"]

            ## Update dynamic key for TO table
            put the number of elements of theJoinDynamicKeyA into theIndex
            put "related table joins" into theJoinDynamicKeyA[ theIndex + 1]
            put the number of elements of theJoinsA[ theJoinDynamicKeyA ] + 1 into theJoinDynamicKeyA[ theIndex + 2 ]
          end if

          ## Add entry for "to table key"
          ## ["to table key"]
          put theToTable into theJoinsA[ theJoinDynamicKeyA ]["table"]["name"]
          put theRelationsA[i]["index"] into theJoinsA[ theJoinDynamicKeyA ]["relationship index"]
        end if

        ## no on clause as relationships are used to generate it
        put empty into theJoinsA[ theJoinDynamicKeyA ]["on clause"]

        ## If this is the last relationship then we are at the table for this entry.
        ## go ahead and update the as and join type.
        ## Otherwise there is nothing to do.
        if i is the number of elements of theRelationsA then
          local theTempDynamicKeyA

          put theAs into theJoinsA[ theJoinDynamicKeyA ]["table"]["as"]
          put theJoinType into theJoinsA[ theJoinDynamicKeyA ]["join type"]

          ## The join type of the table we found the relationship for is inherited by all else if empty.
          put theJoinDynamicKeyA into theTempDynamicKeyA
          repeat until the number of lines of the keys of theTempDynamicKeyA <= 1
            delete local theTempDynamicKeyA[ the number of elements of theTempDynamicKeyA ] ## index
            delete local theTempDynamicKeyA[ the number of elements of theTempDynamicKeyA ] ## related table joins

            if "join type" is not among the keys of theJoinsA[ theTempDynamicKeyA ] or theJoinsA[ theTempDynamicKeyA ]["join type"] is empty then
              put theJoinType into theJoinsA[ theTempDynamicKeyA ]["join type"]
            end if
          end repeat
        end if
      end repeat
    end if

  end repeat

  return theJoinsA
end _StringToJoins


private function _DynamicKeyForTableInJoin pJoinsA, pTable, pTableAs, pDynamicKeyA
  -----
  local theKey
  local theNextIndex
  -----
  put the number of elements of pDynamicKeyA + 1 into theNextIndex
  repeat for each line theKey in _SortNumericKeys(pJoinsA)
    put theKey into pDynamicKeyA[theNextIndex]

    if pJoinsA[ pDynamicKeyA ]["table"]["as"] is pTableAs and pJoinsA[ pDynamicKeyA ]["table"]["name"] is pTable then
      return pDynamicKeyA
    else
      put "related table joins" into pDynamicKeyA[theNextIndex + 1]
      put _DynamicKeyForTableInJoin(pJoinsA, pTable, pTableAs, pDynamicKeyA) into pDynamicKeyA

      if pDynamicKeyA is an array then
        return pDynamicKeyA
      end if
    end if
  end repeat

  return empty
end _DynamicKeyForTableInJoin


## We need both the relationship index and to table to verify as
## many-to-many relationship index will show up twice
private function _DynamicKeyForRelationshipInJoin pJoinsA, pRelationshipIndex, pToTable, pDynamicKeyA
  -----
  local theKey
  local theNextIndex
  -----
  put the number of elements of pDynamicKeyA + 1 into theNextIndex
  repeat for each line theKey in _SortNumericKeys(pJoinsA)
    put theKey into pDynamicKeyA[theNextIndex]

    if pJoinsA[ pDynamicKeyA ]["relationship index"] is pRelationshipIndex and pJoinsA[ pDynamicKeyA ]["table"]["name"] is pToTable then
      return pDynamicKeyA
    else
      put "related table joins" into pDynamicKeyA[theNextIndex + 1]
      put _DynamicKeyForRelationshipInJoin(pJoinsA, pRelationshipIndex, pToTable, pDynamicKeyA) into pDynamicKeyA

      if pDynamicKeyA is an array then
        return pDynamicKeyA
      end if
    end if
  end repeat

  return empty
end _DynamicKeyForRelationshipInJoin


private command _VerifyTableJoins pParentTableA, @xJoinsA, pDynamicKeyA
  -----
  local i, theCharNo, theAs
  local theChildTableA
  local theCount
  local theError
  local theNextIndex
  local theRelationA
  local theTargetIndex
  -----
  if pDynamicKeyA is not an array then
    put 1 into theTargetIndex
    put the number of elements of xJoinsA into theCount
  else
    put the number of elements of pDynamicKeyA + 1 into theTargetIndex
    put the number of elements of xJoinsA[pDynamicKeyA] into theCount
  end if

  repeat with i = 1 to theCount
    put i into pDynamicKeyA[theTargetIndex]

    ## Store table index.
    if "table" is among the keys of xJoinsA[pDynamicKeyA] and xJoinsA[pDynamicKeyA]["table"] is not an array then
      ## 'table' key has to be present or array is invalid

      ## Note: the value of 'table' may be an alias

      ## Note: First look for "as" in the string

      put offset(" as ", xJoinsA[pDynamicKeyA]["table"]) into theCharNo
      if theCharNo > 0 then
        put char (theCharNo + 4) to -1 of xJoinsA[pDynamicKeyA]["table"] into theAs
        put char 1 to (theCharNo - 1) of xJoinsA[pDynamicKeyA]["table"] into xJoinsA[pDynamicKeyA]["table"]["name"]
        put theAs into xJoinsA[pDynamicKeyA]["table"]["as"]
      else
        put xJoinsA[pDynamicKeyA]["table"] into xJoinsA[pDynamicKeyA]["table"]["name"]
      end if

      put tableobjects_getTable(xJoinsA[pDynamicKeyA]["table"]["name"], pParentTableA["database"]) into theChildTableA

      put theChildTableA["name"] into xJoinsA[pDynamicKeyA]["table"]["name"]
    else
      -- get xJoinsA[pDynamicKeyA]
      -- answer printKeys(it) & cr & printKeys(pDynamicKeyA) & cr & "theTargetIndex:" && theTargetIndex
      put tableobjects_getTable(xJoinsA[pDynamicKeyA]["table"]["name"], pParentTableA["database"]) into theChildTableA
    end if

    ## Cache relationship
    if xJoinsA[pDynamicKeyA]["relationship index"] is empty then
      local theDudA

      put empty into theDudA ## since we are in repeat loop we need to reset relationships searched each time
      put _FindImmediateRelationBetweenTables(pParentTableA, theChildTableA, theDudA) into theRelationA

      if theRelationA is an array then
        put theRelationA[1]["index"] into xJoinsA[pDynamicKeyA]["relationship index"]
      else
        _ThrowError kErrInvalidProperty, "table '" & tableobj_get(theChildTableA, "name") & "' is not related to table '" & tableobj_get(pParentTableA, "name")  & "'"
      end if
    end if

    ## Join type
    if xJoinsA[pDynamicKeyA]["join type"] is not among the items of kJoinTypes then
      put kDefaultJoinType into xJoinsA[pDynamicKeyA]["join type"]
    end if

    ## as
    if "as" is not among the keys of xJoinsA[pDynamicKeyA]["table"] then
      put empty into xJoinsA[pDynamicKeyA]["table"]["as"]
    end if

    if xJoinsA[pDynamicKeyA]["related table joins"] is an array then
      put the number of elements of pDynamicKeyA into theNextIndex
      add 1 to theNextIndex
      put "related table joins" into pDynamicKeyA[theNextIndex]
      _VerifyTableJoins theChildTableA, xJoinsA, pDynamicKeyA
      put the result into theError

      ## Restore dynamica key for next iteration
      delete local pDynamicKeyA[theNextIndex]
    else
      put empty into xJoinsA[pDynamicKeyA]["related table joins"]
    end if

    if theError is not empty then exit repeat
  end repeat

  return theError
end _VerifyTableJoins


## Searches as far and wide as possible to get a link from pFromTableA and pToTableA
private function _FindRelationshipBetweenTables pFromTableA, pToTableA
  -----
  local i,theKey
  local theDudA
  local theFirstKey
  local theFoundRelationsA
  local theIndex
  local theKeys
  local theRelationsA
  -----
  put _FindAnyRelationBetweenTables(pFromTableA, pToTableA, theDudA, 0) into theRelationsA

  ## Now filter out the junk.
  ## What happens is that if we have lots of table relationships and aliases then
  ## the path taken to find the relationship can be a little crazy. We will delete any
  ## relationship, except the last one, that doesn't match from/to tables.
  ## Lastly, we inject a relationship between pFromTable and pToTableA if it isn't present.
  if theRelationsA is an array then
    repeat with i = 1 to (the number of elements of theRelationsA - 1)
      if (pFromTableA["name"] is theRelationsA[i]["from table"] and \
            pToTableA["name"] is theRelationsA[i]["to table"]) or \
            (pToTableA["name"] is theRelationsA[i]["from table"] and \
            pFromTableA["name"] is theRelationsA[i]["to table"]) then
        exit repeat
      else
        delete local theRelationsA[i]
      end if
    end repeat

    ###
    ## Now that we've cleansed we need to rebuild.
    ###
    put the keys of theRelationsA into theKeys
    sort lines of theKeys numeric

    ## Make sure that the found relationships array links all the way
    ## back to the from table.
    put line 1 of theKeys into theFirstKey
    if pFromTableA["name"] is not theRelationsA[theFirstKey]["from table"] and \
          pFromTableA["name"] is not theRelationsA[theFirstKey]["to table"] then
      ## Logic: if from table is not in the first relationship then we need to link the table that isn't the
      ## 'to' table to the from.
      if pToTableA["name"] is not theRelationsA[theFirstKey]["from table"] then
        put theRelationsA[theFirstKey]["from table"] into pToTableA["name"]
      else
        put theRelationsA[theFirstKey]["to table"] into pToTableA["name"]
      end if

      ##
      ## Alright, get the relationship of origin.
      ##
      put empty into theDudA
      put _FindImmediateRelationBetweenTables(pFromTableA, pToTableA, theDudA) into theFoundRelationsA
      if theFoundRelationsA[1] is not an array then
        return empty
      end if
    end if

    ##
    ## Now let's compact everything into a nice tidy array for returning
    ##
    put the number of elements of theFoundRelationsA + 1 into theIndex
    repeat for each line theKey in theKeys
      put theRelationsA[theKey] into theFoundRelationsA[theIndex]
    end repeat

    -- put "theFoundRelationsA:" && printKeys(theFoundRelationsA) & cr & "---" & cr after msg
  end if

  return theFoundRelationsA
end _FindRelationshipBetweenTables


private function _FillInRelationshipTableIdentifiers pFromTableA, pToTableA, pRelationA
  -----
  local theRelationKeyA
  local theTable
  -----
  put _KeyArrayForRelationship(pRelationA) into theRelationKeyA
  repeat for each item theTable in "left table,right table,cross-reference table"
    if sDbsA[ theRelationKeyA ][ theTable ] is pFromTableA["name"] then
      put theTable into pRelationA["from table key"]

      ## this is a quick lookup for _FindRelationshipBetweenTables
      put pFromTableA["name"] into pRelationA["from table"]

      ## for debugging
      -- put tableobj_get(pFromTableA, "name") into pRelationA["from table name"]
      exit repeat
    end if
  end repeat

  repeat for each item theTable in "left table,right table,cross-reference table"
    if sDbsA[ theRelationKeyA ][ theTable ] is pToTableA["name"] then
      put theTable into pRelationA["to table key"]

      ## this is a quick lookup for _FindRelationshipBetweenTables
      put pToTableA["name"] into pRelationA["to table"]

      ## for debugging
      -- put tableobj_get(pToTableA, "name") into pRelationA["to table name"]
      exit repeat
    end if
  end repeat

  ## For debugging
  -- put param(0) && cr & printKeys(pRelationA) & cr & "---" & cr & the executioncontexts & cr & "******" after msg

  return pRelationA
end _FillInRelationshipTableIdentifiers


private function _FindImmediateRelationBetweenTables pFromTableA, pToTableA, @xRelationshipsAlreadySearchedA, pFromTableRelationsA
  -----
  local i
  local theKeyA
  local theRelationsA
  -----
  if pFromTableRelationsA is not an array then put tableobj_get(pFromTableA, "relationship indexes") into pFromTableRelationsA

  repeat with i = 1 to the number of elements of pFromTableRelationsA
    ## don't search a relationship twice
    if pFromTableRelationsA[i]["index"] is among the keys of xRelationshipsAlreadySearchedA["first pass"] then next repeat
    put 1 into xRelationshipsAlreadySearchedA["first pass"][ pFromTableRelationsA[i]["index"] ]

    put _KeyedArray(pFromTableRelationsA[i]["database"], "table objects", "relationships", pFromTableRelationsA[i]["index"]) into theKeyA

    if sDbsA[ theKeyA ]["left table"] is pToTableA["name"] or \
          sDbsA[ theKeyA ]["right table"] is pToTableA["name"] or \
          sDbsA[ theKeyA ]["cross-reference table"] is pToTableA["name"] then
      put _FillInRelationshipTableIdentifiers(pFromTableA, pToTableA, pFromTableRelationsA[i]) into theRelationsA[1]
      return theRelationsA
    end if
  end repeat

  return empty
end _FindImmediateRelationBetweenTables


private function _FindAnyRelationBetweenTables pFromTableA, pToTableA, @xRelationshipsAlreadySearchedA, pIndent
  -----
  local i
  local theFoundRelationsA, theFromRelationshipsA
  local theIndex
  local theKeyA
  local theRelationsA
  local theTable, theTable3A
  -----
  -- if pIndent is not an integer then put 0 into pIndent
  -- ## For debugging
  -- put printCharXTimes(space, pIndent * 2) & \
        -- "looking for relationships between:" && tableobj_get(pFromTableA, "name") && "and" && tableobj_get(pToTableA, "name") & cr after msg

  put 0 into theIndex
  put tableobj_get(pFromTableA, "relationship indexes") into theFromRelationshipsA

  ## We perform two separate passes when looking for relationships.
  ## The first pass looks for direct relationships. If none are found then
  ## the second pass looks for relationships beyond one level deep.

  ## Look for immediate relationship
  put _FindImmediateRelationBetweenTables(pFromTableA, pToTableA, \
        xRelationshipsAlreadySearchedA, theFromRelationshipsA) into theRelationsA

  ## Possible exit
  if theRelationsA is an array then return theRelationsA

  ## Now look for a relationship far and wide
  repeat with i = 1 to the number of elements of theFromRelationshipsA

    ## don't search a relationship twice
    if theFromRelationshipsA[i]["index"] is among the keys of xRelationshipsAlreadySearchedA["second pass"] then next repeat
    put 1 into xRelationshipsAlreadySearchedA["second pass"][ theFromRelationshipsA[i]["index"] ]

    put _KeyedArray(theFromRelationshipsA[i]["database"], "table objects", "relationships", theFromRelationshipsA[i]["index"]) into theKeyA

    ## pToTableA isn't directly linked to pFromTableA.
    ## Try to find links to pToTable through pFromTable relationships.
    put pToTableA into theTable3A

    repeat for each item theTable in "left table,right table,cross-reference table"
      put sDbsA[ theKeyA ][ theTable ] into theTable3A["name"]

      if theTable3A["name"] is not empty and theTable3A["name"] is not pFromTableA["name"] then
        put _FindAnyRelationBetweenTables(theTable3A, pToTableA, xRelationshipsAlreadySearchedA, pIndent +1) into theFoundRelationsA
        if theFoundRelationsA is an array then
          add 1 to theIndex
          put _FillInRelationshipTableIdentifiers(pFromTableA, theTable3A, theFromRelationshipsA[i]) into theRelationsA[theIndex]

          repeat with i = 1 to the number of elements of theFoundRelationsA
            add 1 to theIndex
            put theFoundRelationsA[i] into theRelationsA[theIndex]
          end repeat
          return theRelationsA
        end if
      end if
    end repeat
  end repeat

  return empty
end _FindAnyRelationBetweenTables


--> Errors (Private)


private command _ThrowError pErrNum, pMsg
  local theContexts, theContextsA, theCount, theError

  ## error number, line number, col number, message
  if pErrNum is empty then put 567 into pErrNum ## external error

  ## Build error to throw using executionContexts
  put the executionContexts into theContexts

  ## don't want reference to self
  delete the last line of theContexts

  put _ParseExecutionContexts(theContexts) into theContextsA

  put the number of elements of theContextsA into theCount
  put format("%s,%u,%u,%s\n", pErrNum, theContextsA[theCount]["line number"], 0, pMsg) after theError
  repeat with i = theCount down to 1
    if theContextsA[i]["error number"] is empty then put pErrNum into theContextsA[i]["error number"]

    put format("%s,%u,%u,%s\n", pErrNum, theContextsA[i]["line number"], 0, theContextsA[i]["handler"]) after theError
    put format("%s,%u,%u,%s\n", theContextsA[i]["error number"], theContextsA[i]["line number"], 0, theContextsA[i]["object"]) after theError
  end repeat
  delete the last char of theError
  throw theError
end _ThrowError


private function _ParseExecutionContexts pContexts
  -----
  local theIndex, theContext
  local theContextsA
  local theItem, theItemNo, theStack
  local theErrorObject
  -----
  ## Each line has object-long-id,handler-name,line-number,[parent script object][,]
  ## Beware of quotes and commas in stack path name. They will get you.
  ## How to properly parse?

  ## How many entries?
  repeat for each line theContext in pContexts
    add 1 to theIndex
    put 0 into theItemNo
    repeat for each item theItem in theContext
      add 1 to theItemNo
      if theItem is an integer then
        ## found the line number
        put theItem into theContextsA[theIndex]["line number"]
        put item (theItemNo - 1) of theContext into theContextsA[theIndex]["handler"]
        put item 1 to (theItemNo - 2) of theContext into theContextsA[theIndex]["object"]

        put item (theItemNo + 1) to -1 of theContext into theContextsA[theIndex]["parents"]

        ##
        ## Strip line number from SQL yoga scripts. Error reporting windows should
        ## point to the object that called the SQL yoga function.
        if theContextsA[theIndex]["object"] is not empty and there is a theContextsA[theIndex]["object"] then
          put _StackOf(theContextsA[theIndex]["object"]) into theStack
          if the short name of theStack is the short name of me then
            ## strip line number and add to error description.
            put " (" & theContextsA[theIndex]["line number"] & ")" after theContextsA[theIndex]["handler"]
            put 0 into theContextsA[theIndex]["line number"]
          else
            ##
            ## Mark object that generated error with '353'
            if theErrorObject is empty then
              put "353" into theContextsA[theIndex]["error number"]
              put theContextsA[theIndex]["object"] into theErrorObject
            end if
          end if

        end if

      end if
    end repeat
  end repeat

  return theContextsA
end _ParseExecutionContexts


--> Private


-- returns actual table name if table happens to be alias
private function _ResolvedTableName pDatabase, pTable
  if sDbsA[ pDatabase ]["table objects"]["tables"][ pTable ]["type"] is "alias" then
    return sDbsA[ pDatabase ]["table objects"]["tables"][ pTable ]["alias for table"]
  else
    return pTable
  end if
end _ResolvedTableName


private function _internalTransactionName
  set the randomSeed to the milliseconds
  return "sqlyoga_" & random(10000)
end _internalTransactionName


-- Returns index of found relationship. 0 otherwise.
private function _getRelationshipIndexFromName pDBKey, pName
  local theFoundIndex=0

  repeat for each key theIndex in sDbsA[ pDBKey ]["table objects"]["relationships"]
    if sDbsA[ pDBKey ]["table objects"]["relationships"][ theIndex ]["name"] is pName then
      put theIndex into theFoundIndex
      exit repeat
    end if
  end repeat
  return theFoundIndex
end _getRelationshipIndexFromName


private function _CustomControlReference pControl
  -----
  local theFirstCharToDelete
  local theLastCharToDelete
  local theStackOffset=0,theSecondStackOffset
  local theStack
  -----
  put the long ID of pControl into pControl
  ## Get id without hierarchy

  ## Strip any nested refs
  if pControl contains "of group id" then
    put length(word 1 to 4 of pControl) + 1 into theFirstCharToDelete
    put offset(" card id", pControl) - 1 into theLastCharToDelete
    delete char theFirstCharToDelete to theLastCharToDelete of pControl
  end if

  if word 1 of pControl is not "stack" then
    put offset(" of stack ", pControl) into theStackOffset
  end if
  put offset(" of stack ", pControl, theStackOffset) into theSecondStackOffset
  if theSecondStackOffset > 0 then
    ## Strip mainstack ref if substack.
    ## We want user to move stacks around.
    add theSecondStackOffset to theStackOffset
    delete char theStackOffset to -1 of pControl
  else if theStackOffset > 0 then
    ## Shorten stack name
    put char (theStackOffset + 4) to -1 of pControl into theStack
    put the short name of theStack into theStack    # get stack short name
    put quote & theStack & quote into char (theStackOffset + 10) to -1 of pControl
  else
    ## stack "something "reference
    put the short name of pControl into theStack    # get stack short name
    put quote & theStack & quote into char 7 to -1 of pControl
  end if

  ## Strip card ref
  ## Taken out so that one can locate the card of a stack that a reference is on
  ## without looping through every card on the stack.
  -- put offset(" of card ", pControl) into theFirstCharToDelete
  -- put offset(" of stack ", pControl) into theLastCharToDelete
  -- delete char theFirstCharToDelete + 1 to theLastCharToDelete of pControl

  return pControl
end _CustomControlReference


private function _SortNumericKeys pKeys
  sort lines of pKeys ascending numeric
  return pKeys
end _SortNumericKeys


private function _KeyedArray
  -----
  local i
  local theKeyA
  -----
  repeat with i = 1 to the paramCount
    put param(i) into theKeyA[i]
  end repeat
  return theKeyA
end _KeyedArray


private function _IsListOfIntegers pList
  replace comma with empty in pList
  return pList is an integer
end _IsListOfIntegers


private function _IsPositiveInteger pValue
  return pValue is an integer and pValue > 0
end _IsPositiveInteger


## We fill in holes rather than incrementing each time.
private function _FirstEmptyIntegerInList pList
  -----
  local theInt, theCounter
  local theNextIndex
  -----
  replace comma with cr in pList
  repeat for each line theInt in pList
    add 1 to theCounter
    if theCounter is not theInt then
      put theCounter into theNextIndex
      exit repeat
    end if
  end repeat

  if theNextIndex is empty then
    put the last line of pList + 1 into theNextIndex
  end if

  return theNextIndex
end _FirstEmptyIntegerInList


private function _ArrayOfDBSubKeys pKey, pSubKey, pType
  local theKeys, theIndex, theA

  put the keys of sDbsA[pKey][pSubKey] into theKeys
  sort lines of theKeys ascending numeric

  repeat for each line theKey in theKeys
    add 1 to theIndex

    put pType into theA[theIndex]["type"]
    put pKey into theA[theIndex]["database"]
    put theKey into theA[theIndex]["name"]
  end repeat

  return theA
end _ArrayOfDBSubKeys


private function _NextIndexForDBSubKey pKey, pSubKey
  local theIndexes

  put the keys of sDbsA[pKey][pSubKey] into theIndexes
  sort lines of theIndexes ascending numeric

  return _FirstEmptyIntegerInList(theIndexes)
end _NextIndexForDBSubKey


private function _EscapeDbString pDbType, pString
  _EscapeDbStringByRef pDbType, pString
  return pString
end _EscapeDbString


private command _EscapeDbStringByRef pDbType, @xString
  switch word 1 of pDbType
    case "valentina"
      --put Valentina_EscapeString(xString, true) into xString   # regex example
      replace numToChar(92) with numToChar(92) & numToChar(92) in xString --> \ to \\ -
      replace numToChar(39) with numToChar(39) & numToChar(39) in xString --> ' to ''
      break

    case "mysql"
      replace numToChar(92) with numToChar(92) & numToChar(92) in xString --> \ to \\ -
      replace numToChar(39) with numToChar(92) & numToChar(39) in xString --> ' to \'
      replace numToChar(34) with numToChar(92) & numToChar(34) in xString --> " to \"
      replace numToChar(0) with numToChar(92) & numToChar(48) in xString --> NULL to \0
      replace numToChar(26) with numToChar(92) & numToChar(90) in xString --> Control-Z to \Z
      replace numToChar(10) with numToChar(92) & numToChar(110) in xString --> newline to \n
      replace numToChar(13) with numToChar(92) & numToChar(114) in xString --> carriage return to \r
      replace numToChar(9) with numToChar(92) & numToChar(116) in xString --> tab to \t
      replace numToChar(8) with numToChar(92) & numToChar(98) in xString --> backspace to \b
      break
    case "postgresql"
      // As of version 8.1 you need E'...' in order to avoid warnings for C escape
      // Just escape the single quote.
      --            replace numToChar(92) with numToChar(92) & numToChar(92) in xString --> \ to \\ -
      replace numToChar(39) with numToChar(39) & numToChar(39) in xString --> ' to ''
      --         replace numToChar(12) with numToChar(92) & numToChar(102) in xString --> formfeed to \f
      --         replace numToChar(10) with numToChar(92) & numToChar(110) in xString --> newline to \n
      --         replace numToChar(13) with numToChar(92) & numToChar(114) in xString --> carriage return to \r
      --         replace numToChar(9) with numToChar(92) & numToChar(116) in xString --> tab to \t
      --         replace numToChar(8) with numToChar(92) & numToChar(98) in xString --> backspace to \b
      break
    case "sqlite"
    default
      replace numToChar(39) with numToChar(39) & numToChar(39) in xString --> ' to ''
      break
  end SWITCH
end _EscapeDbStringByRef


private function _NextIndexForSchemaSubKey pKey, pSubKey
  -----
  local theIndexes
  -----
  put the keys of sDbsA[pKey]["schema"][pSubKey] into theIndexes
  sort lines of theIndexes ascending numeric

  return _FirstEmptyIntegerInList(theIndexes)
end _NextIndexForSchemaSubKey


private function _NextIndexForTableObjectsSubKey pKey, pSubKey
  -----
  local theIndexes
  -----
  put the keys of sDbsA[pKey]["table objects"][pSubKey] into theIndexes
  sort lines of theIndexes ascending numeric

  return _FirstEmptyIntegerInList(theIndexes)
end _NextIndexForTableObjectsSubKey


private function _NextIndexForTableSubKey pKey, pTableIndex, pSubKey
  -----
  local theIndexes
  -----
  put the keys of sDbsA[pKey]["schema"]["tables"][pTableIndex][pSubKey] into theIndexes
  sort lines of theIndexes ascending numeric

  return _FirstEmptyIntegerInList(theIndexes)
end _NextIndexForTableSubKey


private function _NextIndexForQuerySubKey pQueryA, pSubKey
  -----
  local theIndexes
  -----
  put the keys of pQueryA[pSubKey] into theIndexes
  sort lines of theIndexes ascending numeric

  return _FirstEmptyIntegerInList(theIndexes)
end _NextIndexForQuerySubKey


private command _ValidateDatabaseArray pArray
  ## todo: Validate array structure
  return empty
end _ValidateDatabaseArray


private command _ValidateKey @xKey
  if xKey is empty then put sDefaultDBKey into xKey
  return empty
end _ValidateKey


private command _ValidateDBKeyExistence pKey
  if pKey is not among the keys of sDbsA then _ThrowError kErrCantFindObject, format(kDatabaseKeyNotFound, quote, pKey, quote)
  return empty
end _ValidateDBKeyExistence


private command _ValidateConnectionExistence pKey, pConnectionName
  if pKey is not among the keys of sDbsA then _ThrowError kErrCantFindObject,  format(kDatabaseKeyNotFound, quote, pKey, quote)

  if pConnectionName is not among the keys of sDbsA[pKey]["connections"] then \
        _ThrowError kErrCantFindObject, "database connection '" & pConnectionName & "' not found in database '" & pKey & "'"

  return empty
end _ValidateConnectionExistence

-- Helper for libSQLYogaSchema
function dbobject_createConnectionArray pConnection, pDBKey
  return _CreateConnectionArray(pConnection, pDBKey)
end dbobject_createConnectionArray


private function _CreateConnectionArray pConnection, pDBKey
  if pConnection is an array then
    ## nothing
  else
    _ValidateKey pDBKey

    if pConnection is empty then
      put dbobject_get("default connection", pDBKey) into pConnection
    end if
    put dbobject_getConnection(pConnection, pDBKey) into pConnection
  end if

  _ValidateConnectionArray pConnection

  return pConnection
end _CreateConnectionArray


private command _ValidateConnectionArray pConnectionA
  if pConnectionA["type"] is not kConnectionReference then _ThrowError kErrInvalidProperty, kInvalidType && "connection"-- & cr & the executioncontexts
  _ValidateConnectionExistence pConnectionA["database"], pConnectionA["name"]
  return empty
end _ValidateConnectionArray


private command _ValidateRelationshipArray pRelationA
  if pRelationA["type"] is not kRelationshipReference then _ThrowError kErrInvalidProperty, kInvalidType && "relationship" --& cr & the executioncontexts
  _ValidateRelationshipExistence pRelationA["database"], pRelationA["index"]
end _ValidateRelationshipArray


private command _ValidateRelationshipExistence pKey, pIndex
  if pKey is not among the keys of sDbsA then _ThrowError kErrCantFindObject, format(kDatabaseKeyNotFound, quote, pKey, quote)
  if pIndex is not among the keys of sDbsA[pKey]["table objects"]["relationships"] then \
        _ThrowError kErrCantFindObject, "relationship index '" & pIndex & "' not found in database '" & pKey & "'"
  return empty
end _ValidateRelationshipExistence


private command _ValidateTableExistence pKey, pTableName
  if pKey is not among the keys of sDbsA then _ThrowError kErrCantFindObject, format(kDatabaseKeyNotFound, quote, pKey, quote)

  if pTableName is not among the keys of sDbsA[pKey]["table objects"]["tables"] then \
        _ThrowError kErrCantFindObject, "table '" & pTableName & "' not found in database '" & pKey & "'" --& cr & the executioncontexts
  return empty
end _ValidateTableExistence


private function _CreateTableArray pTable, pDBKey
  if pTable is an array then
    ## nothing
  else
    _ValidateKey pDBKey
    put tableobjects_getTable(pTable, pDBKey) into pTable
  end if

  _ValidateTableArray pTable

  return pTable
end _CreateTableArray


private function _CreateQueryTemplateArray pTemplate, pDBKey
  if pTemplate is an array then
    ## nothing
  else
    _ValidateKey pDBKey
    put dbobject_getQueryTemplate(pTemplate, pDBKey) into pTemplate
  end if

  _ValidateQueryTemplateArray pTemplate

  return pTemplate
end _CreateQueryTemplateArray


private function _CreateRelationshipArray pRelation, pDBKey
  if pRelation is an array then
    ## nothing
  else
    _ValidateKey pDBKey
    put tableobjects_getRelationship(pRelation, pDBKey) into pRelation
  end if

  _ValidateRelationshipArray pRelation

  return pRelation
end _CreateRelationshipArray


private command _ValidateTableArray pTableA
  ## If a string then go ahead and fetch for default connection.
  if pTableA["type"] is not kTableReference then _ThrowError kErrInvalidProperty, kInvalidType && "table" --& cr & the executioncontexts
  _ValidateTableExistence pTableA["database"], pTableA["name"]
  return empty
end _ValidateTableArray


private command _ValidateIndexExistence pKey, pTableNameOrIndex, pIndexNameOrIndex
  if pTableNameOrIndex is not an integer then
    put sDbsA[pKey]["schema"]["tables lookup"][pTableNameOrIndex] into pTableNameOrIndex
  end if
  if pIndexNameOrIndex is not an integer then
    repeat for each key theKey in sDbsA[pKey]["schema"]["tables"][pTableNameOrIndex]["indexes"]
      if pIndexNameOrIndex is sDbsA[pKey]["schema"]["tables"][pTableNameOrIndex]["indexes"][theKey]["name"] then
        put theKey into pIndexNameOrIndex
        exit repeat
      end if
    end repeat
  end if

  _ValidateTableExistence pKey, pTableNameOrIndex
  if pIndexNameOrIndex is not among the keys of sDbsA[pKey]["schema"]["tables"][pTableNameOrIndex]["indexes"] then \
        _ThrowError kErrCantFindObject, "index '" & pIndexNameOrIndex & "' not found in table index '" & pTableNameOrIndex & "' of database '" & pKey & "'"
  return empty
end _ValidateIndexExistence


private command _ValidateIndexArray pIndexA
  if pIndexA["type"] is not kIndexReference then _ThrowError kErrInvalidProperty, kInvalidType && "index"
  _ValidateIndexExistence pIndexA["database"], pIndexA["table"], pIndexA["index"]
  return empty
end _ValidateIndexArray


private command _ValidateScopeExistence pKey, pTableName, pScopeName
  _ValidateTableExistence pKey, pTableName
  if pScopeName is not among the keys of sDbsA[pKey]["table objects"]["tables"][pTableName]["scopes"] then
    _ThrowError kErrCantFindObject, "scope '" & pScopeName & "' not found in table '" & pTableName & "' of database '" & pKey & "'"
  end if
  return empty
end _ValidateScopeExistence


private command _ValidateScopeArray pScopeA
  if pScopeA["type"] is not kScopeReference then _ThrowError kErrInvalidProperty, kInvalidType && "scope" -- & cr & the executioncontexts

  _ValidateScopeExistence pScopeA["database"], pScopeA["table"], pScopeA["name"]
  return empty
end _ValidateScopeArray


private command _ValidateQueryArray pQueryA
  if pQueryA["type"] is not kQueryReference then _ThrowError kErrInvalidProperty, kInvalidType && "query" --& cr & the executioncontexts
  if pQueryA["database"] is not among the keys of sDbsA then _ThrowError kErrCantFindObject, format(kDatabaseKeyNotFound, quote, pQueryA["database"], quote)
  return empty
end _ValidateQueryArray


private command _ValidateQueryTemplateArray pTemplateA
  if pTemplateA["type"] is not kQueryTemplateReference then _ThrowError kErrInvalidProperty, kInvalidType && "query template"
  _ValidateQueryTemplateExistence pTemplateA["database"], pTemplateA["name"]
  return empty
end _ValidateQueryTemplateArray


private command _ValidateQueryTemplateExistence pKey, pTemplateName
  if pKey is not among the keys of sDbsA then _ThrowError kErrCantFindObject, format(kDatabaseKeyNotFound, quote, pKey, quote)

  if pTemplateName is not among the keys of sDbsA[pKey]["query templates"] then \
        _ThrowError kErrCantFindObject, "query template '" & pTemplateName & "' not found in database '" & pKey & "'"
  return empty
end _ValidateQueryTemplateExistence


private command _ValidateDatabaseObject pButtonRef
  if there is not a pButtonRef then
    _ThrowError kErrCantFindObject, "database object does not exist"
  end if

  return empty
end _ValidateDatabaseObject


private function _StackOf pControl
  local theCharNo

  put the long ID of pControl into pControl ## force the long id

  if word 1 of pControl is not "stack" then
    put offset(" of stack ", pControl) into theCharNo
    if theCharNo > 0 then
      delete char 1 to (theCharNo + 3) of pControl
    else
      put empty into pControl
    end if
  end if
  return pControl
end _StackOf


--> Object: Database


/**
Summary: Initializes a database object using a configuration array.

pDbA: The configuration array.
pRootFolder: Folder used to resolve relative filenames in pDbA.
pDBKey: Key to assign to the new database object.

Description:

`dbobject_initialize` allows a developer to create a new database object with schema, connections,
migrations, query templates, table objects, scopes, and relationships defined in an array
format. This handler will parse that format and make the necessary API calls to create objects.
This array format allows a database object to be defined in a markup such as YAML.

pDBA array keys:

```
conections:
  default connection:
  connections:
    CONNECTION_NAME:
      adaptor:
      type:
      file:
      quote identifiers:
relationships:
  - name:
    type:
    order by:
    left table:
    left table key:
    cross-reference table:
    cross-reference table key for left table:
    cross-reference table key for right table:
    right table:
    right table key:
scopes:
  TABLE_NAME:
    - name:
      related table joins:
      conditions:
schema:
  tables:
    TABLE_NAME:
      primary key:
      field order:
      fields:
        FIELD_NAME:
          accepts null:
          default value:
            primary key:
            limit:
            unique:
            signed:
            meta type:
            type:
```

Returns: Error message
*/
command dbobject_initialize pDbA, pRootFolder, pDBKey
  local theError, tConnectionsA, tRelationshipsA, tScopesA, tTablesA
  local tKey, tTable, tField, tProp, tVendor, i

  if theError is empty then
    put pDbA["connections"] into tConnectionsA
    put pDbA["relationships"] into tRelationshipsA
    put pDbA["scopes"] into tScopesA
    put pDbA["tables"] into tTablesA

    delete local pDbA["connections"]
    delete local pDbA["relationships"]
    delete local pDbA["scopes"]
    delete local pDbA["tables"]

    # Fill in "name" field for each field. SQL Yoga expects it, YAML shouldn't need to set it twice.
    repeat for each key tTable in pDbA["schema"]["tables"]
      repeat for each key tField in pDbA["schema"]["tables"][tTable]["fields"]
        put tField into pDbA["schema"]["tables"][tTable]["fields"][tField]["name"]
      end repeat
    end repeat

    dbobject_createFromArray pDbA, pDBKey
    put the result into theError
  end if

  # Set up connections
  if theError is empty then
    repeat for each key tKey in tConnectionsA
      dbconn_createObject tKey, tConnectionsA[tKey]["adaptor"], tConnectionsA[tKey]["type"], pDBKey

      if tConnectionsA[tKey]["file"] is not empty then
        put resolveFilenameReference(tConnectionsA[tKey]["file"], pRootFolder) into tConnectionsA[tKey]["file"]
        dbconn_set "file", tConnectionsA[tKey]["file"], tKey, pDBKey
      else if tConnectionsA[tKey]["database name"] is not empty then
        dbconn_set "database name", tConnectionsA[tKey]["database name"], tKey, pDBKey
      end if

      repeat for each item tProp in "host,port,username,password,use ssl,dsn,quote identifiers"
        if tConnectionsA[tKey][tProp] is empty then next repeat

        dbconn_set tProp, tConnectionsA[tKey][tProp], tKey, pDBKey
      end repeat

      repeat for each key tVendor in tConnectionsA[tKey]["vendor"]
        repeat for each key tProp in tConnectionsA[tKey]["vendor"][tVendor]
          dbconn_setVendor tVendor, tProp, tConnectionsA[tKey]["vendor"][tVendor][tProp], tKey, pDBKey
        end repeat
      end repeat
    end repeat
  end if

  # Set up tables, scopes, and relationships
  if theError is empty then
    repeat with i = 1 to the number of elements of tTablesA
      if not tableobjects_tableExists(tTablesA[i]["name"], pDBKey) then
        tableobj_createObject tTablesA[i]["name"], "table", pDBKey
      end if

      repeat for each item tKey in "type,name,alias for table,conditions,primary key"
        if tKey is among the keys of tTablesA[i] then
          tableobj_set tTablesA[i]["name"], tKey, tTablesA[i][tKey], pDBKey
        end if
      end repeat
    end repeat

    repeat with i = 1 to the number of elements of tRelationshipsA
      tblrelation_createObject tRelationshipsA[i]["name"], pDBKey

      repeat for each item tKey in "left table,right table,cross-reference table"
        if tRelationshipsA[i][tKey] is not empty \
              and not tableobjects_tableExists(tRelationshipsA[i][tKey], pDBKey) then
          tableobj_createObject tRelationshipsA[i][tKey], "table", pDBKey
        end if
      end repeat

      repeat for each item tKey in "type,left table,left table key," & \
            "right table,right table key,order by,delete action,update action"
        tblrelation_set tRelationshipsA[i]["name"], tKey, tRelationshipsA[i][tKey]
      end repeat

      if tRelationshipsA[i]["type"] is among the items of "n-n,many-to-many" then
        repeat for each item tKey in "cross-reference table,cross-reference table key for left table," & \
              "cross-reference table key for right table"
          tblrelation_set tRelationshipsA[i]["name"], tKey, tRelationshipsA[i][tKey]
        end repeat
      end if
    end repeat

    local tScopeA

    repeat for each key tTable in tScopesA
      if not tableobjects_tableExists(tTable, pDBKey) then
        tableobj_createObject tTable, "table", pDBKey
      end if

      repeat with i = 1 to the number of elements of tScopesA[tTable]
        tblscope_createObject tTable, tScopesA[tTable][i]["name"], pDBKey
        put it into tScopeA

        if "joins" is among the keys of tScopesA[tTable][i] then
          put tScopesA[tTable][i]["joins"] into tScopesA[tTable][i]["related table joins"]
        end if

        repeat for each item tKey in "related table joins,conditions"
          tblscope_set tScopeA, tKey, tScopesA[tTable][i][tKey]
        end repeat
      end repeat
    end repeat
  end if

  return theError
end dbobject_initialize


/**
Summary: Creates a Database Object from an object that you have previously stored a Database Object in using dbobject_save.

Params:
pObjectID: The id of the LiveCode object that the Database Object was stored in.
pDBKey: Database Object to store created Database Object in. Default is name returned by `sqlyoga_getDefaultDatabase()`.

Description:
If you are using SQL Yoga with Levure you will not use this command. Levure uses the YAML configuration files.

Returns: Error message
*/
command dbobject_createFromObject pObjectID, pDBKey
  local theDatabaseArray, theError

  _ValidateKey pDBKey
  _ValidateDatabaseObject pObjectID

  put the uSQLDatabaseObject of pObjectID into theDatabaseArray
  if theDatabaseArray is an array then
    dbobject_createFromArray theDatabaseArray, pDBKey
    put the result into theError
  end if

  if theError is empty then
    dbobject_set "storage object", pObjectID, pDBKey
  end if

  return theError
end dbobject_createFromObject


/**
Summary: Creates a Database Object from a file where you have previously stored a Database Object using `dbobject_save`.

Params:
pFile: The path to the file the Database Object is stored in.
pDBKey: Database Object to store created Database Object in. Default is name returned by `sqlyoga_getDefaultDatabase()`.

Description:
If you are using SQL Yoga with Levure you will not use this command. Levure uses the YAML configuration files.

Returns: Error message
*/
command dbobject_createFromFile pFile, pDBKey
  local theError

  _ValidateKey pDBKey

  open file pFile for binary read
  put the result into theError

  if theError is empty then
    read from file pFile until end
    put the result into theError

    if theError is empty and it is not empty then
      dbobject_createFromArray arrayDecode(it), pDBKey
      put the result into theError
    end if

    close file pFile
  end if

  if theError is empty then
    dbobject_set "storage file", pFile, pDBKey
  end if

  return theError
end dbobject_createFromFile


/**
Summary: Creates a Database Object from database object array that you retrieved using `dbobject_getArray()`.

Params:
pArray: The array containing the Database Object.
pDBKey: Database Object to store created Database Object in. Default is name returned by `sqlyoga_getDefaultDatabase()`.

Description:
If you are using SQL Yoga with Levure you will not use this command. Levure uses the YAML configuration files.

Returns: Error message
*/
command dbobject_createFromArray pArray, pDBKey
  local theError

  _ValidateKey pDBKey
  _ValidateDatabaseArray pArray

  if pArray is not an array then
    _ThrowError kErrInvalidArray, "invalid array"
  end if

  _ResetDatabaseKey pDBKey

  put pArray into sDbsA[pDBKey]

  return theError
end dbobject_createFromArray


private command _ResetDatabaseKey pDBKey
  local theKey

  ## If db key already exists then disconnect
  ## todo: Move over deprecated tables behavior property
  if dbobject_exists(pDBKey) then
    repeat for each line theKey in dbobject_get("connections", pDBKey)
      if dbconn_get("connection id", theKey, pDBKey) > 0 then
        dbconn_disconnect theKey, pDBKey
      end if
    end repeat
  end if
end _ResetDatabaseKey


/**
Summary: Saves a Database Object to a LiveCode object or a file depending on what you have configured.

Parameters:
pDBKey: Database Object to store created Database Object in. Default is name returned by `sqlyoga_getDefaultDatabase()`.


Description:
If you have set the "storage object" property of a Database Object it will be saved to the LiveCode
object and the stack the object is a part of will be saved. If you have set the "storage file" property
then it will be saved to the file.

If you are using SQL Yoga with Levure you will not use this command. Levure uses the YAML configuration files.

Returns: Error message
*/
command dbobject_save pDBKey
  local theObject, theStack, theError
  local theFile

  _ValidateKey pDBKey
  _ValidateDBKeyExistence pDBKey

  switch sDbsA[pDBKey]["storage"]["type"]
    case "object"
      put sDbsA[pDBKey]["storage"]["resource"] into theObject
      _ValidateDatabaseObject theObject
      set the uSQLDatabaseObject of theObject to sDbsA[pDBKey]
      put _StackOf(theObject) into theStack
      compact stack theStack
      save stack theStack
      put the result into theError
      break

    case "file"
      put sDbsA[pDBKey]["storage"]["resource"] into theFile
      open file theFile for binary write
      put the result into theError

      if theError is empty then
        if sDbsA[pDBKey] is an array then
          write arrayEncode(sDbsA[pDBKey]) to file theFile
        else
          write empty to file theFile
        end if
        put the result into theError

        close file theFile
      end if

      break
  end switch

  return theError
end dbobject_save


/**
Summary: Imports the database schema into the Database object using the default connection for the Database object.

Parameters:
pDBKey: The Database object to target. Default is name returned by `sqlyoga_getDefaultDatabase()`.

Description:
Call this handler when you change your database schema and need to tell SQL Yoga about the change.
You should call dbobject_save after calling this handler so that the updated schema is saved.

Returns: Error message
*/
command dbobject_reloadSchema pDBKey
  local theError, theConnection

  _ValidateKey pDBKey
  _ValidateDBKeyExistence pDBKey

  put dbobject_get("default connection", pDBKey) into theConnection

  ## Reset then call connect which reloads the schema
  if theConnection is not empty then
    dbschema_reset pDBKey
    dbconn_connect theConnection, pDBKey
    put the result into theError
  else
    put "no default connection defined for database object" into theError
  end if

  return theError
end dbobject_reloadSchema


/**
Summary: Returns the internal array used to represent a Database Object.

Parameters:
pDBKey: Database Object to store created Database Object in. Default is name returned by `sqlyoga_getDefaultDatabase()`.

Returns: Array
*/
function dbobject_getArray pDBKey
  _ValidateKey pDBKey
  _ValidateDBKeyExistence pDBKey

  return sDbsA[pDBKey]
end dbobject_getArray


/**
Summary: Returns the internal array that contains all registered database objects.

Returns: Array
*/
function dbobject_getArrays
  return sDbsA
end dbobject_getArrays


/**
Summary: Retrieves a Database Object property.

Parameters:
pProperty: Property to get.
pDBKey: Database Object to store created Database Object in. Default is name returned by `sqlyoga_getDefaultDatabase()`.

Description:
| Property | Description |
| -------- |:----------- |
| `connections` | A return delimited list of connections in the Database object. |
| `default connection` | The name of the Connection object that is used by default in all SQL Yoga API calls using the Database object. |
| `storage file` | The path to the file where dbobject_save will store the Database object. (Not used in conjuction with Levure.) |
| `storage object` | A reference to the LiveCode control where dbobject_save will store the Database object. (Not used in conjuction with Levure.) |
| `storage type` | `object` or `file` depending on whether the Database object will be stored in a LiveCode object or a file. (Not used in conjuction with Levure.) |

Returns: Value
*/
function dbobject_get pProperty, pDBKey
  -----
  local theA,theKey
  local theArray
  local theIndex
  local theKeys
  -----
  _ValidateKey pDBKey
  _ValidateDBKeyExistence pDBKey

  -- put empty into sDbsA
  switch pProperty
    case "connection indexes"
      ## Return an array of references
      return _ArrayOfDBSubKeys(pDBKey, "connections", kConnectionReference)
      break

    case "connections"
      local theConnections

      put the keys of sDbsA[ pDBKey ]["connections"] into theConnections
      sort theConnections
      return theConnections
      break

    case "query templates"
      ## todo: return lines of query template names
      ## Return an array of references
      return _ArrayOfDBSubKeys(pDBKey, "query templates", kQueryTemplateReference)
      break

    case "default connection"
      return sDbsA[pDBKey][pProperty]
      break

    case "storage type"
      return sDbsA[pDBKey]["storage"]["type"]
      break

    case "storage object"
      if sDbsA[pDBKey]["storage"]["type"] is "object" then
        return sDbsA[pDBKey]["storage"]["resource"]
      else
        return empty
      end if
      break
    case "storage file"
      if sDbsA[pDBKey]["storage"]["type"] is "file" then
        return sDbsA[pDBKey]["storage"]["resource"]
      else
        return empty
      end if
      break

    case "schema migrations"
    case "encoding" ## undocumented
      return sDbsA[ pDBKey ][pProperty]
      break

    default
      if pProperty is among the keys of sDbsA[ pDBKey ] then
        return sDbsA[ pDBKey ][pProperty]  ## update prop we are targeting
      else
        _ThrowError kErrInvalidProperty, "invalid database property '" & pProperty & "'"
      end if
  end switch
end dbobject_get


/**
Summary: Sets a Database Object property.

Parameters:
pProperty: Property to get.
pValue: Value to set property to.
pDBKey: Database Object to store created Database Object in. Default is name returned by `sqlyoga_getDefaultDatabase()`.

Description:
| Property | Description |
| -------- |:----------- |
| `default connection` | The name of the connection that the database object should use for querying the database. |
| `storage file` | The path to the file to store your database object in. This allows the object to persist across sessions by using `dbobject_createFromFile`. (Not used in conjuction with Levure.) |
| `storage object` | The long id of the LiveCode control that you would like to save your database object in (as a custom property). This allows the object to persist across sessions by using `dbobject_createFromObject`. (Not used in conjuction with Levure.) |

Returns: Error message

References: dbobject_createFromObject (command), dbobject_createFromFile (command)
*/
command dbobject_set pProperty, pValue, pDBKey
  local theError

  _ValidateKey pDBKey
  _ValidateDBKeyExistence pDBKey

  ## Set
  switch pProperty
    case "default connection"
      put _CreateConnectionArray(pValue, pDBKey) into pValue
      put pValue["name"] into sDbsA[pDBKey][pProperty]
      break

    case "storage object"
      ## Reduce to bare essentials of referencing an object in Rev
      if pValue is not empty then put _CustomControlReference(pValue) into pValue
      put pValue into sDbsA[pDBKey]["storage"]["resource"]
      put "object" into sDbsA[pDBKey]["storage"]["type"]
      break

    case "storage file"
      put pValue into sDbsA[pDBKey]["storage"]["resource"]
      put "file" into sDbsA[pDBKey]["storage"]["type"]
      break

    case "schema migrations"
      if pValue is not empty then
        if word 1 of pValue is not "group" then
          _ThrowError kErrInvalidGroupObject, "value must be a reference to a group"
        end if
        put _CustomControlReference(pValue) into pValue
      end if
      put pValue into sDbsA[ pDBKey ][pProperty]
      break

    case "encoding"
      put pValue into sDbsA[ pDBKey ][pProperty]
      break

    default
      if pProperty is among the keys of sDbsA[ pDBKey ] then
        put pValue into sDbsA[ pDBKey ][pProperty]  ## update prop we are targeting
      else
        _ThrowError kErrInvalidProperty, "invalid database property '" & pProperty & "'"
      end if
  end switch

  return theError
end dbobject_set


/**
Summary: Deletes a Connection Object from a Database Object.

Parameters:
pConnectionA: The name of the Connection Object or a Connection Object reference array.
pDBKey: Database Object connection is associated with. Default is name returned by `sqlyoga_getDefaultDatabase()`. Only applies if pConnectionA is a name and not a reference array.

Returns: empty
*/
command dbobject_deleteConnection pConnectionA
  put _CreateConnectionArray(pConnectionA, param(3)) into pConnectionA
  delete local sDbsA[ pConnectionA["database"] ]["connections"][ pConnectionA["name"] ]
  return empty
end dbobject_deleteConnection


/**
Summary: Returns a Connection Object reference array for a given connection name.

Parameters:
pConnectionName: The name of the Connection Object.
pDBKey: Database Object connection is associated with. Default is name returned by `sqlyoga_getDefaultDatabase()`.

Returns: Connection Object reference array or empty if one doesn't exist.
*/
function dbobject_getConnection pConnectionName, pDBKey
  -----
  local theA
  -----
  _ValidateKey pDBKey

  _ValidateConnectionExistence pDBKey, pConnectionName

  put kConnectionReference into theA["type"]
  put pDBKey into theA["database"]
  put pConnectionName into theA["name"]

  return theA
end dbobject_getConnection


/**
Summary: Deletes a SQL Query Template Object from a Database Object.

Parameters:
pTemplateA: The name of the SQL Query Template Object or a SQL Query Template Object reference array.
pDBKey: Database Object connection is associated with. Default is name returned by `sqlyoga_getDefaultDatabase()`. Only applies if pTemplateA is a name and not a reference array.

Returns: empty
*/
command dbobject_deleteQueryTemplate pTemplateA, pDBKey
  put _CreateQueryTemplateArray(pTemplateA, pDBKey) into pTemplateA
  delete local sDbsA[pDBKey]["query templates"][ pTemplateA["name"] ]
  return empty
end dbobject_deleteQueryTemplate


/**
Summary: Returns a SQL Query Template Object reference array for a given template name.

Parameters:
pTemplateName: The name of the SQL Query Template Object.

Returns: SQL Query Template Object refernece array or empty if one doesn't exist.
*/
function dbobject_getQueryTemplate pTemplateName, pDBKey
  -----
  local theA
  -----
  _ValidateKey pDBKey

  try
    _ValidateQueryTemplateExistence pDBKey, pTemplateName

    put kQueryTemplateReference into theA["type"]
    put pDBKey into theA["database"]
    put pTemplateName into theA["name"]
  catch e
    ## connection doesn't exist
  end try

  return theA
end dbobject_getQueryTemplate


/**
Summary: Creates a new Database Object.

Parameters:
pDBKey: Database Object to create. Default is name returned by `sqlyoga_getDefaultDatabase()`.

Description:
Calling this command will create a new Database Object.

Returns: Error messsage
*/
command dbobject_createObject pDBKey
  -----
  local theA
  local theError
  local theMigrationStamp
  -----
  _ValidateKey pDBKey

  if pDBKey is among the keys of sDbsA then
    _ThrowError kErrObjectNameTaken, "database '" & pDBKey & "' already exists"
  end if

  if theError is empty then
    ## Create root keys
    put empty into theA["default connection"]

    put empty into theA["connections"]
    put empty into theA["query templates"]
    put empty into theA["schema"]
    put empty into theA["schema migrations"]

    ## Create table objects
    put empty into theA["table objects"] --["tables"] / ["relationships"]

    put theA into sDbsA[pDBKey]
  end if

  return theError
end dbobject_createObject


/**
Summary: Deletes a Database Object.

Parameters:
pDBKey: Database Object to delete. Default is name returned by `sqlyoga_getDefaultDatabase()`.

Returns: empty
*/
command dbobject_deleteObject pDBKey
  local theConnsA

  _ValidateKey pDBKey
  _ValidateDBKeyExistence pDBKey

  ## Disconnect
  put dbobject_get("connection indexes", pDBKey) into theConnsA

  repeat with i = 1 to the number of elements of theConnsA
    dbconn_deleteObject theConnsA[i]
  end repeat

  delete local sDbsA[pDBKey]
  return empty
end dbobject_deleteObject


/**
Summary: Checks as to whether or not a Database Object exists.

Parameters:
pDBKey: Database Object to create. Default is name returned by `sqlyoga_getDefaultDatabase()`.

Returns: empty
*/
function dbobject_exists pDBKey
  _ValidateKey pDBKey
  try
    _ValidateDBKeyExistence pDBKey
  catch e
    return false
  end try
  return true
end dbobject_exists


--> Object: Connection


private function _KeyArrayForConnection pConnectionA
  local theKeyA

  put pConnectionA["database"] into theKeyA[1]
  put "connections" into theKeyA[2]
  put pConnectionA["name"] into theKeyA[3]
  return theKeyA
end _KeyArrayForConnection


private function _KeyArrayForTempConnection pConnectionA
  local theKeyA

  put pConnectionA["database"] into theKeyA[1]
  put pConnectionA["name"] into theKeyA[2]
  return theKeyA
end _KeyArrayForTempConnection


/**
Summary: Checks as to whether or not a Connection Object exists.

Parameters:
pConnName: The name of a Connection.
pDBKey: Database Object connection is associated with. Default is name returned by `sqlyoga_getDefaultDatabase()`.

Returns: empty
*/
function dbconn_exists pConnName, pDBKey
  _ValidateKey pDBKey
  try
    _ValidateConnectionExistence pDBKey, pConnName
  catch e
    return false
  end try
  return true
end dbconn_exists


/**
Summary: Returns an array of all currently configured connections.

Returns: Array
*/
function dbconn_getArrays
  return sConnectionsA
end dbconn_getArrays


/**
Summary: Creates a Database Connection for a Database.

Parameters:
pName: The Database Connection name. You will use this name whenever you refer to the connection in the API.
pAdaptor: The adaptor to use to connect to the database that the connection is associated with: `mysql`, `odbc`, `postgresql`, `sqlite`, `valentina`.
pType: The type of database you are connecting to. Only required for ODBC.
pDBKey: Database Object to associate connection with. Default is name returned by `sqlyoga_getDefaultDatabase()`.

Description:
SQL Yoga allows you to have multiple database connections.
You can define one database connection for your development environment and anotherf
for distribution. Changing which connection SQL Yoga uses for a Database Object is
as simple as:

```
dbobject_setprop "default connection", "development"
```

Returns: Error message
*/
command dbconn_createObject pName, pAdaptor, pType, pDBKey
  -----
  local theA
  local theConnectionA
  local theError
  local theNextIndex
  local theProp
  -----
  _ValidateKey pDBKey
  _ValidateDBKeyExistence pDBKey
  if word 1 to -1 of pName is empty then  _ThrowError kErrObjectNameTaken, "connection name cannot be empty"
  if pName is among the keys of sDbsA[pDBKey]["connections"] then  _ThrowError kErrObjectNameTaken, "connection '" & pName & "' already exists"

  if pAdaptor is not among the items of "sqlite,mysql,valentina,postgresql,odbc" then _ThrowError kErrInvalidProperty, "invalid connection adaptor"
  if pAdaptor is "odbc" then
    if pType is not among the items of "sqlite,mysql,postgresql,sql server,filemaker" then
      _ThrowError kErrInvalidProperty, "invalid connection type"
    end if
  else if pType is empty then
    put pAdaptor into pType
  end if

  if theError is empty then
    local theTempKeyA

    put toLower(pAdaptor) into theA["adaptor"]
    put toLower(pType) into theA["type"]
    put pDBKey into theTempKeyA[1]
    put pName into theTempKeyA[2]

    -- repeat for each item theProp in "version,host,database name,username,password,port"
    -- put empty into theA[theProp]
    -- end repeat

    put false into theA["quote identifiers"]

    ## store it
    put theA into sDbsA[pDBKey]["connections"][pName]
  end if

  ## Set as default if empty
  if sDbsA[pDBKey]["default connection"] is empty then
    dbobject_set "default connection", pName, pDBKey
  end if

  return theError
end dbconn_createObject


private command _SetConnectionDefaults pConnectionA
  local theKeyA

  put _KeyArrayForTempConnection(pConnectionA) into theKeyA
  put "vendor" into theKeyA[ the number of elements of theKeyA + 1]

  switch dbconn_get("adaptor", pConnectionA)
    case "odbc"
      if sConnectionsA[ theKeyA ]["odbc"]["cursor type"] is empty then
        put "forward only" into sConnectionsA[ theKeyA ]["odbc"]["cursor type"]
      end if
      break
    case "sqlite"

      break
    case "mysql"

      break
    case "valentina"
      put "valentina" into theKeyA[ the number of elements of theKeyA + 1]

      -- put empty into sConnectionsA[ theKeyA ]["mac serial number"]
      -- put empty into sConnectionsA[ theKeyA ]["win serial number"]
      -- put empty into sConnectionsA[ theKeyA ]["unix serial number"]
      -- put empty into sConnectionsA[ theKeyA ]["encryption key"]
      if not _IsPositiveInteger( sConnectionsA[ theKeyA ]["cache size"] ) then
        put 3 * 1024 * 1024 into sConnectionsA[ theKeyA ]["cache size"]
      end if
      if sConnectionsA[ theKeyA ]["debug level"] is empty then
        put "kLogParams" into sConnectionsA[ theKeyA ]["debug level"]
      end if
      if sConnectionsA[ theKeyA ]["encryption type"] is empty then
        put "kStructureOnly" into sConnectionsA[ theKeyA ]["encryption type"]
      end if
      put sConnectionsA[ theKeyA ]["flush each log"] is true into sConnectionsA[ theKeyA ]["flush each log"] -- default to false
      if sConnectionsA[ theKeyA ]["mode"] is empty then
        put "kDscDatBlbInd" into sConnectionsA[ theKeyA ]["mode"] ## default to 1 file on disk
      end if
      if not _IsPositiveInteger( sConnectionsA[ theKeyA ]["timeout"] ) then
        put 5 into sConnectionsA[ theKeyA ]["timeout"]
      end if
      if not _IsPositiveInteger( sConnectionsA[ theKeyA ]["segment size"] ) then
        put 32 * 1024 into sConnectionsA[ theKeyA ]["segment size"]
      end if
      if sConnectionsA[ theKeyA ]["os encoding"] is empty then
        put "kOSDefault" into sConnectionsA[ theKeyA ]["os encoding"]
      end if
      if sConnectionsA[ theKeyA ]["storage type"] is empty then
        put "kDisk" into sConnectionsA[ theKeyA ]["storage type"]
      end if
      break
  end switch
end _SetConnectionDefaults


/**
Summary: Deletes a Database Connection from a Database.

Parameters:
pConnName: The name of a Connection.
pDBKey: Database Object connection is associated with. Default is name returned by `sqlyoga_getDefaultDatabase()`.

Description:
If the connection you are deleting is the default connection then SQL Yoga will assign
one of your other connections as the default connection if one exists.

Returns: empty
*/
command dbconn_deleteObject pConnName, pDBKey
  local theKeyA, theConnectionA

  _ValidateKey pDBKey

  put _CreateConnectionArray(pConnName, pDBKey) into theConnectionA

  dbconn_disconnect theConnectionA

  put _KeyArrayForConnection(theConnectionA) into theKeyA

  if theConnectionA["name"] is sDbsA[pDBKey]["default connection"] then
    ## remove if default connection
    put empty into sDbsA[pDBKey]["default connection"]

    ## set first connection to default
    if the keys of sDbsA[pDBKey]["connections"] is not empty then
      local theKeys
      put the keys of sDbsA[pDBKey]["connections"] into theKeys
      sort lines of theKeys ascending numeric
      put line 1 of theKeys into sDbsA[pDBKey]["default connection"]
    end if
  end if

  delete local sDbsA[ theKeyA ]
  return empty
end dbconn_deleteObject


/**
Summary: Retrieves properties of a Database Connection Object.

Parameters:
pProp: The property to get.
pConnName: The name of a Database Connection. The default is the `default connection` for the Database Object.
pDBKey: Database Object connection is associated with. Default is name returned by `sqlyoga_getDefaultDatabase()`.

Description:
| Property | Description |
| -------- |:----------- |
| `adaptor` | The adaptor to use to connect to the database: `mysql`, `odbc`, `postgresql`, `sqlite`, `valentina`. |
| `connection id` | The current RevDB connection id (or V4REV database reference if using Valentina). If you need to call any RevDB or native Valentina calls directly then you will need this value. |
| `database` | The name of the Database Object that the connection is associated with. |
| `database name` | The name of the database on the server. For sqlite this and the 'file' property are synonymous. |
| `dsn` | The DSN you would like to connect to. Used with ODBC and maps to the "host" property. |
| `file` | For SQLite databases this is the path to the database file on disk. Synonymous with 'database name'. |
| `host` | The host for your database. |
| `last error` | The last error reported for this database connection. An error can occur when connection to, disconnecting from or querying the database. |
| `last executed sql` | The last SQL statement that was executed using this database connection. |
| `last insert[ed] id` | When working with database tables that have auto incrementing primary key fields this will return the value used when creating the last record. |
| `log field` | The field where all SQL statements that are executed are logged. |
| `log file` | The file where all SQL statements that are executed are logged. |
| `open transactions` | The number of transactions that have been opened using `dbconn_beginTransaction` but not yet closed using `dbconn_commitTransaction` or `dbconn_rollbackTransaction`. |
| `port` | Port to connect to the database over. Default values for each platform are implied. |
| `quote identifiers` | If true then SQL Yoga adds quotes around every table/field name in queries. Default is false. |
| `quotes` | The left and right strings used to quote table and field names for the database associated with a connection. An array is returned with two keys - `left` and `right`. |
| `type` | The type of database that this connection is associated with. For most database types this is the same as the adaptor property. For ODBC it is the type of database that is being connected to through ODBC. |
| `use ssl` | Whether or not the connection uses SSL to connect to the database. |
| `valentina client connection id` | The id representing the connection with the server when running in client/server mode. |
| `version` | The version of the database engine connected to. |

Returns: value
*/
function dbconn_get pProp, pConnName, pDBKey
  local theKeyA, theTempKeyA, theConnectionA

  put _CreateConnectionArray(pConnName, pDBKey) into theConnectionA

  put _KeyArrayForConnection(theConnectionA) into theKeyA
  put _KeyArrayForTempConnection(theConnectionA) into theTempKeyA

  ## Update any virtual props
  switch pProp
    case "file" ## for sqlite
      put "database name" into pProp
      break
    case "dsn"
      put "host" into pProp
      break
  end switch

  switch pProp
    case "database"
      return theConnectionA["database"]
      break
    case "last error"
      return sConnectionsA[ theTempKeyA ]["last error"]
      break
    case "connection id"
    case "valentina client connection id"
      return max(0, sConnectionsA[ theTempKeyA ][pProp])
      break
    case "last insert id"
    case "last inserted id"
      dbconn_lastInsertedID theConnectionA
      return it ## error has to be accessed using "last error" since this is a getProp
      break
    case "effective quotes"
      ## Only returns quotes if "quote identifiers" is true. Used internally.
      if not dbconn_get("quote identifiers", theConnectionA) then return empty
    case "quotes"
      local theA

      put empty into theA

      switch sDbsA[ theKeyA ]["type"]
        case "mysql"
          put numToChar(96) into theA["left"]
          put numToChar(96) into theA["right"]
          break
        case "sqlite"
        case "postgresql"
        case "valentina"
        case "sql server"
        case "filemaker"
          put quote into theA["left"]
          put quote into theA["right"]
          break
        case "oracle"   # is this right?  I've never used Oracle.
          put "[" into theA["left"]
          put "]" into theA["right"]
          break
      end switch
      return theA
      break
    case "quote identifiers"
      return sDbsA[ theKeyA ][pProp] is true
      break
    case "schema version" ## undocumented
      local theQuotesA, theSQL, theBindingsA, theInstalledVersion

      put dbconn_get("quotes", theConnectionA) into theQuotesA
      put format("SELECT version FROM %sschema%s", theQuotesA["left"], theQuotesA["right"]) into theSQL
      put empty into theBindingsA
      try
        dbconn_retrieveQueryAsData theSQL, theBindingsA, theInstalledVersion, tab, cr, theConnectionA
        if the result is empty then
          return theInstalledVersion
        else
          return empty
        end if
      catch e
        return empty ## Table doesn't exist
      end try
      break
    case "open transactions"
      return max(0, sConnectionsA[ theTempKeyA ]["open transactions"])
      break
      --      case "effective type"
      --         if sConnectionsA[ theTempKeyA ]["type"] is empty then
      --            return sDbsA[ theKeyA ]["adaptor"]
      --         else
      --            return sDbsA[ theKeyA ]["type"]
      --         end if
      --         break
    default
      set the itemDelimiter to "."
      if item 1 of pProp is "vendor" then
        ## accessing vendor properties vendor.mysql.use ssl
        return sConnectionsA[ theTempKeyA ]["vendor"][item 2 of pProp][item 3 of pProp]
      else
        set the itemDelimiter to comma
        if pProp is among the items of kTempConnProps then
          return sConnectionsA[ theTempKeyA ][pProp]
        else if pProp is among the keys of sDbsA[ theKeyA ] then
          return sDbsA[ theKeyA ][pProp]  ## update prop we are targeting
        else
          _ThrowError kErrInvalidProperty, "invalid connection property '" & pProp & "'" -- & cr & the executioncontexts
        end if
      end if
      break
  end switch
end dbconn_get


/**
Summary: Sets properties for a Database Connection Object.

Parameters:
pProp: The property of the Connection to set.
pValue: The value to set the property to.
pConnName: The name of a Database Connection. The default is the `default connection` for the Database Object.
pDBKey: Database Object connection is associated with. Default is name returned by `sqlyoga_getDefaultDatabase()`.

Description:

| Property | Description |
| -------- |:----------- |
| `adaptor` | The adaptor to use to connect to the database: `mysql`, `odbc`, `postgresql`, `sqlite`, `valentina`. |
| `dsn` | The DSN you would like to connect to. Used with ODBC and maps to the "host" property. |
| `database name` | The name of the database on the server. For sqlite this and the 'file' property are synonymous. |
| `file` | For SQLite databases this is the path to the database file on disk. Synonymous with 'database name'. |
| `host` | The host for your database. |
| `last executed sql` | The last SQL statement that was executed using this database connection. |
| `log field` | A reference to a field where all SQL statements that are executed will be logged. For debugging purposes. |
| `log file` | A file path where all SQL statements that are executed will be logged. For debugging purposes. |
| `password` | Password required to connect to the database. |
| `port` | Port to connect to the database over. Default values for each platform are implied. |
| `quote identifiers` | Set to true to have SQL Yoga add quotes around every table/field name in queries. Default is false. |
| `type` | The type of database that this connection is associated with. Only applies if the adaptor is set to "odbc": sql server, mysql, postgresql. |
| `username` | Username used to connect to the database. |
| `use ssl` | Set to true to connect to the database using SSL. Currently supported with MySQL and Valentina client. |

Description:
Different vendor types have different options.

Example:
## SQLite Example
dbconn_set "file", thePathToDatabaseFile
dbconn_setVendor "sqlite", "options", "binary,extensions"

Example:
## MySQL Example
dbconn_set "host", "localhost"
dbconn_set "username", "root"
dbconn_set "password", empty
dbconn_set "database name", "sql_yoga_test"

Example:
## ODBC Example
-- Note: When calling dbconn_createObject you pass in 3 parameters
--                The 2nd is "odbc" and the 3rd is the type of database you are
--                connection too
-- dbconn_createObject "development", "odbc", "sql server"
dbconn_set "dsn", "sqlserver_odbc"
dbconn_set "username", "odbc_user"
dbconn_set "password", empty

Example:
## Local Valentina Example
dbconn_set "file", theDatabase
dbconn_setVendor "valentina", "mac serial number", MyValMacSerialNumber
dbconn_setVendor "valentina", "win serial number", MyValWinSerialNumber
dbconn_setVendor "valentina", "unix serial number", MyValUnixSerialNumber
dbconn_setVendor "valentina", "encryption key", MyEncryptionKey

Example:
## Valentina Client Example
dbconn_set "host", "localhost"
dbconn_set "username", "sa"
dbconn_set "password", "sa"
dbconn_set "use ssl", true
dbconn_set "database name", "my database.vdb"

Returns: empty
*/
command dbconn_set pProp, pValue, pConnName, pDBKey
  local theConnectionA, theKeyA, theTempKeyA

  set the wholeMatches to true

  put _CreateConnectionArray(pConnName, pDBKey) into theConnectionA
  put _KeyArrayForConnection(theConnectionA) into theKeyA
  put _KeyArrayForTempConnection(theConnectionA) into theTempKeyA

  ## Update any virtual props
  switch pProp
    case "file" ## for sqlite
      put "database name" into pProp
      break
    case "dsn"
      put "host" into pProp
      break
    case "log field"
      if pValue is not empty then
        put _CustomControlReference(pValue) into pValue
      end if
      break
  end switch

  ## Look for props that require disconnecting
  switch pProp
    case "adaptor"
    case "host"
    case "database name"
    case "username"
    case "password"
    case "type"
    case "port"
      dbconn_disconnect theConnectionA
      break
      -- sDbsA[ theKeyA ]["vendor"][ sDbsA[ theKeyA ]["type"] ]["use ssl"]
  end switch

  switch pProp
    case "adaptor"
      put toLower(pValue) into pValue
      if pValue is not among the items of ",sqlite,mysql,valentina,postgresql,odbc" then _ThrowError kErrInvalidProperty, "invalid connection adaptor"
      break
    case "type"
      put toLower(pValue) into pValue
      if pValue is not among the items of ",sqlite,mysql,postgresql,sql server,filemaker" then
        _ThrowError kErrInvalidProperty, "invalid connection type"
      end if
      break
  end switch

  ## Store
  if pProp is among the items of kTempConnProps then
    put pValue into sConnectionsA[ theTempKeyA ][pProp]
  else
    put pValue into sDbsA[ theKeyA ][pProp]
  end if

  if pProp is "adaptor" then
    ## no empty types and no conflicting types if not odbc
    if sDbsA[ theKeyA ]["type"] is empty OR sDbsA[ theKeyA ]["adaptor"] is not "odbc" then
      put sDbsA[ theKeyA ][pProp] into sDbsA[ theKeyA ]["type"]
    end if
  end if

  ## Logging
  if pProp is "last executed sql" then
    if there is a sConnectionsA[ theTempKeyA ]["log field"] \
          and word 1 of sConnectionsA[ theTempKeyA ]["log field"] is "field" then
      local theField, theID

      put sConnectionsA[ theTempKeyA ]["log field"] into theField
      put the short ID of theField into theID
      delete word 1 to 3 of theField
      put sConnectionsA[ theTempKeyA ]["last executed sql"] & \
            cr & "----------" & cr after field ID theID of theField
    end if

    if sConnectionsA[ theTempKeyA ]["log file"] is not empty then
      open file sConnectionsA[ theTempKeyA ]["log file"] for append
      if the result is empty then
        write sConnectionsA[ theTempKeyA ]["last executed sql"] & \
              cr & "----------" & \
              cr to file sConnectionsA[ theTempKeyA ]["log file"]
        close file sConnectionsA[ theTempKeyA ]["log file"]
      end if
    end if

    if sConnectionsA[ theTempKeyA ]["log callback"] is not empty then
      dispatch sConnectionsA[ theTempKeyA ]["log callback"] \
            with sConnectionsA[ theTempKeyA ]["last executed sql"], \
            theConnectionA["name"], \
            theConnectionA["database"]
    end if
  end if

  return empty
end dbconn_set


/**
Summary: Sets vendor specific connection settings.

Parameters:
pVendor: Name of vendor to set property for: `mysql`, `odbc`, `postgresql`, `sqlite`, `valentina`.
pProp: Property to set.
pValue: Value to set property to.
pConnName: The name of a Database Connection. The default is the `default connection` for the Database Object.
pDBKey: Database Object connection is associated with. Default is name returned by `sqlyoga_getDefaultDatabase()`.

Description:

| Vendor    | Property | Description |
| --------- | -------- |:----------- |
| SQLite    |          | See revOpenDatabase documentation for a description of each of these properties. |
|           | `options` |            |
| Valentina |          | See Valentina documentation for a description of each of these properties. Appropriate defaults are used. |
|           | `cache size` |         |
|           | `debug level` |        |
|           | `encryption key` |     |
|           | `encryption type` |    |
|           | `flush each log` |     |
|           | `mac serial number` |  |
|           | `mode` |               |
|           | `os encoding` |        |
|           | `port` |               |
|           | `timeout` |            |
|           | `segment size` |       |
|           | `storage type` |       |
|           | `unix serial number` | |
|           | `win serial number` |  |

Returns: empty
*/
command dbconn_setVendor pVendor, pProp, pValue, pConnName, pDBKey
  local pKey, theConnectionA, theKeyA

  _ValidateKey pKey

  put _CreateConnectionArray(pConnName, pDBKey) into theConnectionA
  put _KeyArrayForTempConnection(theConnectionA) into theKeyA

  switch pVendor
    case "valentina"
      switch pProp
        case "flush each log"
          put pValue is true into pValue

          if dbconn_get("connection id", theConnectionA) > 0 then
            get Valentina_FlushEachLog( pValue )
          end if
          break
      end switch
      break
  end switch

  put pValue into sConnectionsA[ theKeyA ]["vendor"][ pVendor ][pProp]

  return empty
end dbconn_setVendor


/**
Summary: Gets vendor specific connection settings.

Parameters:
pVendor: Name of vendor to get property for: `mysql`, `odbc`, `postgresql`, `sqlite`, `valentina`.
pProp: Property to get.
pConnName: The name of a Database Connection. The default is the `default connection` for the Database Object.
pDBKey: Database Object connection is associated with. Default is name returned by `sqlyoga_getDefaultDatabase()`.

Description:
See dbconn_setVendor for list of properties.

Returns: Mixed

References: dbconn_setVendor
*/
function dbconn_getVendor pVendor, pProp, pConnName, pDBKey
  local theKeyA, theConnectionA

  _ValidateKey pDBKey

  put _CreateConnectionArray(pConnName, pDBKey) into theConnectionA
  put _KeyArrayForTempConnection(theConnectionA) into theKeyA

  return sConnectionsA[ theKeyA ]["vendor"][ pVendor ][pProp]
end dbconn_getVendor


/**
Summary: Escapses a string using the appropriate characters for the type of the database connection.

Parameters:
pString: The string to escape.

Returns: Escaped string
*/
function dbconn_escapeString pString, pConnName, pDBKey
  local theConnectionA, theDbType

  _ValidateKey pDBKey

  put _CreateConnectionArray(pConnName, pDBKey) into theConnectionA
  put dbconn_get("type", theConnectionA) into theDbType

  _EscapeDbStringByRef theDbType, pString
  return pString
end dbconn_escapeString


/**
Summary: Returns the last inserted record id for a database.

Parameters:
pConnName: The name of a Database Connection. The default is the `default connection` for the Database Object.
pDBKey: Database Object connection is associated with. Default is name returned by `sqlyoga_getDefaultDatabase()`.

Returns: integer
*/
command dbconn_lastInsertedID pConnName, pDBKey
  local theConnectionA, theConnectionID
  local theDo, theID
  local theError
  local theKeyA

  _ValidateKey pDBKey
  put _CreateConnectionArray(pConnName, pDBKey) into theConnectionA

  put _KeyArrayForConnection(theConnectionA) into theKeyA
  put sConnectionsA[ theConnectionA["database"] ][ theConnectionA["name"] ]["connection id"] into theConnectionID

  if theConnectionID <= 0 then
    put "invalid connection id" into theError
  end if

  if sDbsA[ theKeyA ]["type"] is "valentina" then
    put VDatabase_LastInsertedRecID(theConnectionID) into theID
    put _valentinaError(theConnectionID) into theError
  else
    local theSQL

    ## Generate adaptor specific SQL
    if theError is empty then
      local theType

       try
        put sDbsA[ theKeyA ]["type"] into theType
        replace space with empty in theType
        put "put _" & theType & "_lastInsertIDSQL(pConnectionA) into theSQL" into theDo
        do theDO
      catch e
        _ThrowError kErrErrorInFunction, param(0) && "has not been defined for database type '" & sDbsA[ theKeyA ]["type"] & "'"
      end try
    end if

    if theError is empty then
      dbconn_set "last executed sql", theSQL, theConnectionA

      repeat with queryAttempts = 1 to 2
        put revDataFromQuery(,, theConnectionID, theSQL) into theID
        if theID begins with "revdberr," then
          put theID into theError
          delete char 1 to length("revdberr,") of theError
        end if

        if theError is not empty then
          if queryAttempts is 1 then ## Try reconnecting 1 time
            local theNewConnectionID

            put _TryConnectingAgainBasedOnError(theConnectionA, theError) into theNewConnectionID
            if theNewConnectionID > 0 then
              ## try query again with new connection id
              put theNewConnectionID into theConnectionID
              put empty into theError
            else
              exit repeat
            end if
          end if
        else
          exit repeat
        end if
      end repeat
    end if
  end if

  _dbconnSetLastError theConnectionA, theError

  if theError is empty then
    return theID for value
  else
    return theError for error
  end if
end dbconn_lastInsertedID


/**
Summary: Returns the representation of true/false for the database associated with the database connection.

Parameters:
pBoolean: `true` or `false`
pConnName: The name of a Database Connection. The default is the `default connection` for the Database Object.
pDBKey: Database Object connection is associated with. Default is name returned by `sqlyoga_getDefaultDatabase()`.

Returns: string
*/
function dbconn_getBooleanValue pBoolean, pConnName, pDBKey
  local i, theDo, theError, theBoolean
  local theConnectionA, theKeyA, theType

  _ValidateKey pDBKey
  put _CreateConnectionArray(pConnName, pDBKey) into theConnectionA
  put _KeyArrayForConnection(theConnectionA) into theKeyA

  ## Generate adaptor specific SQL
  try
    put sDbsA[ theKeyA ]["type"] into theType
    replace space with empty in theType
    put pBoolean is among the items of kBoolTrueValues into pBoolean
    put "put _" & theType & "_getBooleanValue(pBoolean, pConnectionA, pParamsA) into theBoolean" into theDo
    do theDO
  catch e
    _ThrowError kErrErrorInFunction, param(0) && "has not been defined for database type '" & sDbsA[ theKeyA ]["type"] & "'"
  end try

  return theBoolean
end dbconn_getBooleanValue


private command _dbconnSetLastError pConnectionA, pError
  put pError into sConnectionsA[ pConnectionA["database"] ][ pConnectionA["name"] ]["last error"]
end _dbconnSetLastError


function _sqlite_lastInsertIDSQL pConnectionA
  return "SELECT last_insert_rowid()"
end _sqlite_lastInsertIDSQL


function _valentina_lastInsertIDSQL pConnectionA
  return "SELECT Last_RecID()"
end _valentina_lastInsertIDSQL


function _mysql_lastInsertIDSQL pConnectionA
  --To get the NEXT insert id use the mysql query SHOW TABLE STATUS LIKE 'tablename' and get the field auto_increment...
  return "SELECT LAST_INSERT_ID()"
end _mysql_lastInsertIDSQL


function _postgresql_lastInsertIDSQL pConnectionA
  ## Postgresql supports "returning" from an insert statement. We could look at that as well.
  return "SELECT lastval()"
end _postgresql_lastInsertIDSQL


function _sqlserver_lastInsertIDSQL pConnectionA
  return "SELECT @@identity"
end _sqlserver_lastInsertIDSQL


/**
Summary: Connects to a database using the Connection Objects connection settings.

Parameters:
pConnName: The name of a Database Connection. The default is the `default connection` for the Database Object.
pDBKey: Database Object connection is associated with. Default is name returned by `sqlyoga_getDefaultDatabase()`.

Description:
SQL Yoga will connect to a database if necessary whenever it tries to execute a query. This handler can be used
if you need to connect before using a SQL Yoga API call that automatically connects.

Returns: Returns empty. Connection id in `it`. Any errors will be thrown: `sqlyoga_connection_err,ERROR`
*/
command dbconn_connect pConnName, pDBKey
  -----
  local theConnectionID, theConnectionA
  local theKeyA, theTempKeyA, theDatabasePath
  local theError
  -----

  _ValidateKey pDBKey
  put _CreateConnectionArray(pConnName, pDBKey) into theConnectionA

  put _KeyArrayForConnection(theConnectionA) into theKeyA
  put _KeyArrayForTempConnection(theConnectionA) into theTempKeyA

  put sConnectionsA[ theTempKeyA ]["connection id"] into theConnectionID

  set the wholeMatches to true
  ## todo: add valentina check. I don't see a call to verify that a connection is a valid ref to a valentina db though
  if theConnectionID <= 0 \
        or (sDbsA[ theKeyA ]["adaptor"] is not "valentina" and theConnectionID is not among the items of revOpenDatabases() ) \
        then

    ## Cleanup!
    ## Move any props that are no temp over to temporary area.
    ## Delete variables that are now temporary.
    repeat for each item theProp in kTempConnProps
      if theProp is among the keys of sDbsA[ theKeyA ] then
        if theProp is not among the keys of sConnectionsA[ theTempKeyA ] then
          put sDbsA[ theKeyA ][theProp] into sConnectionsA[ theTempKeyA ][theProp]
        end if
        delete local sDbsA[ theKeyA ][theProp]
      end if
    end repeat
    ## End cleanup

    put false into sConnectionsA[ theTempKeyA ]["transaction in process"]

    ## Load any defaults
    _SetConnectionDefaults theConnectionA

    if sDbsA[ theKeyA ]["type"] is empty then
      put sDbsA[ theKeyA ]["adaptor"] into sDbsA[ theKeyA ]["type"]
    end if

    local theClientConnID, theCacheSize, thePort
    local theHost, theType

    switch sDbsA[ theKeyA ]["adaptor"]
      case "valentina"
        put 0 into theClientConnID
        put sConnectionsA[ theTempKeyA ]["database name"] into theDatabasePath

        if sConnectionsA[ theTempKeyA ]["host"] is empty then
          ## Local
          put sConnectionsA[ theTempKeyA ]["vendor"]["valentina"]["cache size"] into theCacheSize
          if not _IsPositiveInteger(theCacheSize) then put 3 * 1024 * 1024 into theCacheSize
          get Valentina_Init(theCacheSize, \
                sConnectionsA[ theTempKeyA ]["vendor"]["valentina"]["mac serial number"], \
                sConnectionsA[ theTempKeyA ]["vendor"]["valentina"]["win serial number"], \
                sConnectionsA[ theTempKeyA ]["vendor"]["valentina"]["unix serial number"])
          get Valentina_DebugLevel(sConnectionsA[ theTempKeyA ]["vendor"]["valentina"]["debug level"])
          get Valentina_FlushEachLog( sConnectionsA[ theTempKeyA ]["vendor"]["valentina"]["flush each log"] )

          put VDatabase_Constructor(sConnectionsA[ theTempKeyA ]["vendor"]["valentina"]["storage type"]) into theConnectionID

          if sConnectionsA[ theTempKeyA ]["vendor"]["valentina"]["encryption key"] is not empty then
            get VDatabase_UseEncryptionKey(theConnectionID, sConnectionsA[ theTempKeyA ]["vendor"]["valentina"]["encryption key"])
          end if

          if there is not a file theDatabasePath then  # create database if it doesn't exist
            get VDatabase_Create(theConnectionID, theDatabasePath, \
                  sConnectionsA[ theTempKeyA ]["vendor"]["valentina"]["mode"], \
                  sConnectionsA[ theTempKeyA ]["vendor"]["valentina"]["segment size"], \
                  sConnectionsA[ theTempKeyA ]["vendor"]["valentina"]["os encoding"])
          else
            get VDatabase_Open(theConnectionID, theDatabasePath)
          end if

        else    # client
          ##
          ## client/server
          ##
          get Valentina_InitClient()
          get Valentina_DebugLevel(sConnectionsA[ theTempKeyA ]["vendor"]["valentina"]["debug level"])
          get Valentina_FlushEachLog( sConnectionsA[ theTempKeyA ]["vendor"]["valentina"]["flush each log"] )

          ## Determine port
          put sConnectionsA[ theTempKeyA ]["port"] into thePort
          if thePort is empty then
            if sDbsA[ theKeyA ]["use ssl"] then put 15434 into thePort
            else put 15432 into thePort
          end if

          put VConnection_Constructor( sConnectionsA[ theTempKeyA ]["host"], \
                sConnectionsA[ theTempKeyA ]["username"], \
                sConnectionsA[ theTempKeyA ]["password"], \
                thePort, \
                sConnectionsA[ theTempKeyA ]["vendor"]["valentina"]["timeout"]) into theClientConnID

          if VConnection_Open( theClientConnID ) contains "error" then
            put Valentina_ErrString() into theError
            get Valentina_ShutDownClient()
          end if

          ## Yes, you can open a connection without opening a database
          if theError is empty and theDatabasePath is not empty then
            put VDatabase_Constructor( theClientConnID ) into theConnectionID
            get VDatabase_Open(theConnectionID, theDatabasePath)
          end if
        end if

        put _valentinaError(theConnectionID) into theError

        if theError is not empty then
          if theConnectionID > 0 and VDatabase_IsOpen(theConnectionID) then
            get VDatabase_Close( theConnectionID )
          end if
          get VDatabase_Destructor( theConnectionID )
        end if

        if theError is empty then
          if theClientConnID is an integer and theClientConnID > 0 then
            put theClientConnID into sConnectionsA[ theTempKeyA ]["valentina client connection id"]
          end if
          -- if theConnectionID is an integer and theConnectionID > 0 then
          -- put theConnectionID into sConnectionsA[ theTempKeyA ]["valentina connection id"]
          -- put revOpenDatabase("Valentina2","",theConnectionID,"","") into theConnectionID
          -- end if
        else
          ## RevDB returns errors in theConnectionID. Mimic
          put theError into theConnectionID
        end if

        break
      case "sqlite"
        -- case "sqlite3"
        if sConnectionsA[ theTempKeyA ]["vendor"]["sqlite"]["options"] is not empty then
          put revOpenDatabase(sDbsA[ theKeyA ]["adaptor"], \
                sConnectionsA[ theTempKeyA ]["database name"], \
                sConnectionsA[ theTempKeyA ]["vendor"]["sqlite"]["options"]) into theConnectionID
        else
          put revOpenDatabase(sDbsA[ theKeyA ]["adaptor"], \
                sConnectionsA[ theTempKeyA ]["database name"],,,) into theConnectionID
        end if
        break
      case "mysql"
        put sConnectionsA[ theTempKeyA ]["host"] into theHost
        if sConnectionsA[ theTempKeyA ]["port"] is not empty then \
              put ":" & sConnectionsA[ theTempKeyA ]["port"] after theHost
        put revOpenDatabase(sDbsA[ theKeyA ]["adaptor"], \
              theHost, \
              sConnectionsA[ theTempKeyA ]["database name"], \
              sConnectionsA[ theTempKeyA ]["username"], \
              sConnectionsA[ theTempKeyA ]["password"], \
              sDbsA[ theKeyA ]["use ssl"],,,) into theConnectionID
        break
      case "odbc"
        put sConnectionsA[ theTempKeyA ]["host"] into theHost
        if sConnectionsA[ theTempKeyA ]["port"] is not empty then \
              put ":" & sConnectionsA[ theTempKeyA ]["port"] after theHost
        ## cursor type is "static", "emulated static", or "forward only"
        put revOpenDatabase(sDbsA[ theKeyA ]["adaptor"], \
              theHost, \
              sConnectionsA[ theTempKeyA ]["database name"], \
              sConnectionsA[ theTempKeyA ]["username"], \
              sConnectionsA[ theTempKeyA ]["password"], \
              sConnectionsA[ theTempKeyA ]["vendor"][ "odbc" ]["cursor type"],,,) into theConnectionID
        break
      default
        put sConnectionsA[ theTempKeyA ]["host"] into theHost
        if sConnectionsA[ theTempKeyA ]["port"] is not empty then \
              put ":" & sConnectionsA[ theTempKeyA ]["port"] after theHost
        put revOpenDatabase(sDbsA[ theKeyA ]["adaptor"], \
              theHost, \
              sConnectionsA[ theTempKeyA ]["database name"], \
              sConnectionsA[ theTempKeyA ]["username"], \
              sConnectionsA[ theTempKeyA ]["password"], \
              ,,,) into theConnectionID
        break
    end SWITCH

    if theConnectionID is not an integer or theConnectionID < 1 then
      if theConnectionID begins with "revdberr," then
        delete char 1 to length("revdberr,") of theConnectionID
      end if
      put theConnectionID into theError
      put 0 into theConnectionID
    end if

    put theConnectionID into sConnectionsA[ theTempKeyA ]["connection id"]
    put 0 into sConnectionsA[ theTempKeyA ]["open transactions"]

    ## Get DB engine version
    if theError is empty then
      local theVersion, theDo

      put dbconn_get("type", theConnectionA) into theType
      replace space with empty in theType
      put "put _" & theType & "_version(" & theConnectionID & ") into theVersion" into theDo
      do theDo
      put the result into theVersion
      dbconn_set "version", theVersion, theConnectionA
    end if
  end if

  if theError is not empty then
    _ThrowError "sqlyoga_connection_err", theError
  end if

  ## Read in schema if we don't have it
  if _IsPositiveInteger(theConnectionID) and sDbsA[ theConnectionA["database"] ]["schema"]["tables"] is not an array \
        and theConnectionA["import schema"] is not false then
    dbsynch_schemaWithDatabase theConnectionA
    put the result into theError

    if theError is not empty then
      _ThrowError "sqlyoga_connection_err", theError
    end if
  end if

  return theConnectionID for value
end dbconn_connect


/**
Summary: Disconnects from a database connection.

Parameters:
pConnName: The name of a Database Connection. The default is the `default connection` for the Database Object.
pDBKey: Database Object connection is associated with. Default is name returned by `sqlyoga_getDefaultDatabase()`.

Returns: Error message
*/
command dbconn_disconnect pConnName, pDBKey
  -----
  local theConnectionA, theConnectionID
  local theCursor, theCursors
  local theError
  local theKeyA, theTempKeyA
  -----
  _ValidateKey pDBKey
  -- try
  put _CreateConnectionArray(pConnName, pDBKey) into theConnectionA
  -- catch e
  -- ## in case no connection exists
  -- end try

  -- if pConnectionA is an array then
  put _KeyArrayForConnection(theConnectionA) into theKeyA
  put _KeyArrayForTempConnection(theConnectionA) into theTempKeyA
  put sConnectionsA[ theTempKeyA ]["connection id"] into theConnectionID
  -- end if

  if theConnectionID > 0 then
    set the wholeMatches to true

    if sDbsA[ theKeyA ]["type"] is "valentina" then
      if sConnectionsA[ theTempKeyA ]["connection id"] > 0 then
        if VDatabase_IsOpen( sConnectionsA[ theTempKeyA ]["connection id"] ) then
          get VDatabase_Flush ( sConnectionsA[ theTempKeyA ]["connection id"] )
          get VDatabase_Close( sConnectionsA[ theTempKeyA ]["connection id"] )
        end if
        get VDatabase_Destructor( sConnectionsA[ theTempKeyA ]["connection id"] )
      end if

      ## close connection for client/server connection
      if sConnectionsA[ theTempKeyA ]["valentina client connection id"] > 0 then
        get VConnection_Close( sConnectionsA[ theTempKeyA ]["valentina client connection id"] )
        get Valentina_ShutdownClient()
      else
        get Valentina_Shutdown()
      end if

      put 0 into sConnectionsA[ theTempKeyA ]["valentina client connection id"]

    else if theConnectionID is among the items of revOpenDatabases() then
      put revDatabaseCursors(theConnectionID) into theCursors
      repeat for each item theCursor in theCursors
        revCloseCursor theCursor
      end repeat

      ## Safety net
      ## Note: need to think about this before uncommenting
      -- if sConnectionsA[ theTempKeyA ]["transaction in process"] then
      -- dbconn_commitTransaction empty, pConnectionA -- note that we don't pass in any params here
      -- end if

      revCloseDatabase theConnectionID
      put the result into theError
    end if

    put 0 into sConnectionsA[ theTempKeyA ]["connection id"]
    put 0 into sConnectionsA[ theTempKeyA ]["open transactions"]
  end if

  if theError begins with "revdberr," then
    delete char 1 to length("revdberr,") of theError
  end if

  _dbconnSetLastError theConnectionA, theError
  return theError
end dbconn_disconnect



/**
Summary: Executes a query and opens a database cursor that you can use to interact with the database.

Parameters:
 pSQL: SQL to execute.
 pBindingsA: Array of bindings to use with sql.
 pVendorParamsA: Array of parameters to use for executing the query. Valentina: location, lock type, direction.
pConnName: The name of a Database Connection. The default is the `default connection` for the Database Object.
pDBKey: Database Object connection is associated with. Default is name returned by `sqlyoga_getDefaultDatabase()`.

Description:
This command will try to reconnect to the database 1 time when certain error messages are returned from the RevDB driver.
For MySQL this occurs when the error is 'MySQL server has gone away'. For SQLite this occurs
when the driver returns an error with 'the database file is locked' or 'some kind of disk i/o error occurred'.

Returns: Returns empty. Cursor id in `it`. Any errors will be thrown: `sqlyoga_executesql_err,ERROR`
*/
command dbconn_openCursor pSQL, pBindingsA, pVendorParamsA, pConnName, pDBKey
  -----
  local theConnectionA, theConnectionID
  local theCursor
  local theError
  local theKeyA, theTempKeyA
  -----
  _ValidateKey pDBKey

  put _CreateConnectionArray(pConnName, pDBKey) into theConnectionA

  dbconn_connect theConnectionA
  put the result into theError

  if theError is empty then
    put it into theConnectionID
    put _KeyArrayForConnection(theConnectionA) into theKeyA
    put _KeyArrayForTempConnection(theConnectionA) into theTempKeyA
  end if

  if theError is empty then
    dbconn_set "last executed sql", pSQL, theConnectionA

    switch sDbsA[ theKeyA ]["type"]
      case "valentina"
        --> TRANSLATE VALUES TO VALENTINA CONSTANTS
        if pVendorParamsA["location"] is empty then
          if sConnectionsA[ theTempKeyA ]["valentina client connection id"] > 0 then
            put "server" into pVendorParamsA["location"]
          else
            put "client" into pVendorParamsA["location"]
          end if
        end if

        switch pVendorParamsA["location"]
          case "client"
            put "kClientSide" into pVendorParamsA["location"]
            break
          case "bulk server"
            put "kServerSideBulk" into pVendorParamsA["location"]
            break
          default
            put "kServerSide" into pVendorParamsA["location"]
        end switch

        if pVendorParamsA["lock type"] is "read" then put "kReadOnly" into pVendorParamsA["lock type"]
        else if pVendorParamsA["lock type"] is "readwrite" then put "kReadWrite" into pVendorParamsA["lock type"]
        else put "kNoLocks" into pVendorParamsA["lock type"]
        if pVendorParamsA["direction"] is "forward" then put "kForwardOnly" into pVendorParamsA["direction"]
        else put "kRandom" into pVendorParamsA["direction"]

        if the keys of pBindingsA is not empty then
          put VDatabase_SqlSelect( theConnectionID, \
                pSQL, pVendorParamsA["location"], pVendorParamsA["lock type"], \
                pVendorParamsA["direction"], \
                "pBindingsA") into theCursor
        else
          put VDatabase_SqlSelect( theConnectionID, \
                pSQL, pVendorParamsA["location"], pVendorParamsA["lock type"], \
                pVendorParamsA["direction"]) into theCursor
        end if

        ## Error checking
        if VDatabase_ErrNumber(theConnectionID) is not 0 then
          if VDatabase_ErrNumber(theConnectionID) < 0 then
            put "OS error ("& VDatabase_ErrNumber(theConnectionID) &")" into theError
          else
            put VDatabase_ErrString(theConnectionID) into theError
          end if
        else if theCursor is not an integer or theCursor < 1 then
          put "unknown valentina query error:" && theCursor into theError
        end if
        break

      default
        ## Repeat tries to connect if server/network drive goes away
        repeat with queryAttempts = 1 to 2
          if the keys of pBindingsA is not empty then
            put revQueryDatabaseBLOB(theConnectionID, pSQL, "pBindingsA") into theCursor
          else
            put revQueryDatabaseBLOB(theConnectionID, pSQL) into theCursor
          end if

          if theCursor is not an integer then ## Error occurred
            put theCursor into theError
            if queryAttempts is 1 then ## Try reconnecting 1 time
              local theNewConnectionID

              put _TryConnectingAgainBasedOnError(theConnectionA, theError) into theNewConnectionID
              if theNewConnectionID > 0 then
                ## Execute query again with new connection id
                put theNewConnectionID into theConnectionID
                put empty into theError
              else
                exit repeat
              end if
            end if
          else
            exit repeat
          end if
        end repeat
        break
    end SWITCH
  end if

  if theError is not empty then
    _ThrowError "sqlyoga_executesql_err", theError && "(" & pSQL & ")"
  end if

  return theCursor for value
end dbconn_openCursor


private function _TryConnectingAgainBasedOnError pConnectionA, pError
  local theNewConnectionID = 0
  local tryConnectingAgain = false
  local theKeyA

  put _KeyArrayForConnection(pConnectionA) into theKeyA

  switch sDbsA[ theKeyA ]["type"]
    case "mysql"
      put pError is "MySQL server has gone away" or pError begins with "Lost connection to MySQL" into tryConnectingAgain
      break
    case "sqlite"
      ## this is error if network drive db is on disappears
      put pError contains "the database file is locked" or \
            pError contains "some kind of disk i/o error occurred" into tryConnectingAgain
      break
  end switch

  if tryConnectingAgain then
    dbconn_disconnect pConnectionA
    if the result is empty then
      dbconn_connect pConnectionA
      ## try again with new connection
      put it into theNewConnectionID
    end if
  end if

  return theNewConnectionID
end _TryConnectingAgainBasedOnError


/**
Summary: Closes a cursor associated with a connection.

Parameters:
pCursor: Cursor id.
pConnName: The name of a Database Connection. The default is the `default connection` for the Database Object.
pDBKey: Database Object connection is associated with. Default is name returned by `sqlyoga_getDefaultDatabase()`.

Returns: Error message
*/
command dbconn_closeCursor pCursor, pConnName, pDBKey
  -----
  local theError, theConnectionA, theKeyA
  -----
  put _CreateConnectionArray(pConnName, pDBKey) into theConnectionA

  put _KeyArrayForConnection(theConnectionA) into theKeyA

  switch sDbsA[ theKeyA ]["type"]
    case "valentina"
      get VCursor_Destructor(pCursor)
      ## todo: check for error
      break

    default
      try
        revCloseCursor pCursor
      catch e
        put e into theError
        ## we don't care if it wasn't a valid cursor
      end try
      break
  end SWITCH

  _dbconnSetLastError theConnectionA, theError

  return theError
end dbconn_closeCursor pCursor


--> Object: Connection: Utilities


/**
Summary: Executes a SQL query against a database connection. Only execute queries that do not return record sets.

Parameters:
pSQL: SQL query to execute.
pConnName: The name of a Database Connection. The default is the `default connection` for the Database Object.
pDBKey: Database Object connection is associated with. Default is name returned by `sqlyoga_getDefaultDatabase()`.

Returns:
it: The affected rows
the result: Error message
*/
command dbconn_executeSQL pSQL, pConnName, pDBKey
  local theDataA

  dbconn_executeWBindings pSQL, theDataA, pConnName, pDBKey
  if the result is empty then
    return it for value
  else
    return the result for error
  end if
end dbconn_executeSQL


/**
Summary: Begins a transaction in the database connection.

Parameters:
pParamsA: Not implemented. Included for possible future use.
pConnName: The name of a Database Connection. The default is the `default connection` for the Database Object.
pDBKey: Database Object connection is associated with. Default is name returned by `sqlyoga_getDefaultDatabase()`.

Description:
After calling this command no changes you make to the database will be saved until you call `dbconn_commitTransaction`. You can
cancel any changes you made to the database by calling `dbconn_rollbackTransaction` rather than `dbconn_commitTransaction`.

Example:
## Start a transaction in the database.
dbconn_beginTransaction

# Modify database, checking for errors along the way.

## If nothing went wrong then commit the changes you made.
if tError is empty then
  dbconn_commitTransaction
else
  ## Something went wrong, rollback to state database was in before calling dbconn_beginTransaction.
  dbconn_rollbackTransaction
end if

Returns: Error message

References: dbconn_commitTransaction (command), dbconn_rollbackTransaction (command)
*/
command dbconn_beginTransaction pParamsA, pConnName, pDBKey
  -----
  local i, theConnectionA
  local theKeyA, theType, theError
  -----
  put _CreateConnectionArray(pConnName, pDBKey) into theConnectionA
  put _KeyArrayForConnection(theConnectionA) into theKeyA

  ## Only execute transaction code if no transaction open
  ## When we add NAMES then this code will change
  if sConnectionsA[ theConnectionA["database"] ][ theConnectionA["name"] ]["open transactions"] < 1 then
    if sDbsA[ theKeyA ]["type"] is "valentina" then

    else if sDbsA[ theKeyA ]["adaptor"] is "odbc" then

    else
      local theSQL, theDO

      ## Generate adaptor specific SQL
      try
        put sDbsA[ theKeyA ]["type"] into theType
        replace space with empty in theType
        put "put _" & theType & "_beginTransactionSQL(pConnectionA, pParamsA) into theSQL" into theDo
        do theDO
      catch e
        put param(0) && "has not been defined for database type '" & sDbsA[ theKeyA ]["type"] & "'" into theError
      end try

      if theError is empty then
        try
          dbconn_executeSQL theSQL, theConnectionA
          put the result into theError
        catch e
          put e into theError
        end try
      end if
    end if
  end if

  if theError is empty then
    add 1 to sConnectionsA[ theConnectionA["database"] ][ theConnectionA["name"] ]["open transactions"]
  end if

  return theError
end dbconn_beginTransaction


/**
Summary: Commits a transaction in the database connection.

Parameters:
pParamsA: Not implemented. Included for possible future use.
pConnName: The name of a Database Connection. The default is the `default connection` for the Database Object.
pDBKey: Database Object connection is associated with. Default is name returned by `sqlyoga_getDefaultDatabase()`.

Returns: Error message

References: dbconn_beginTransaction (command)
*/
command dbconn_commitTransaction pParamsA, pConnName, pDBKey
  -----
  local i,theDo,theError,theConnectionA
  local theKeyA
  -----
  put _CreateConnectionArray(pConnName, pDBKey) into theConnectionA
  put _KeyArrayForConnection(theConnectionA) into theKeyA

  ## Only execute transaction code if no transaction open
  ## When we add NAMES then this code will change
  if sConnectionsA[ theConnectionA["database"] ][ theConnectionA["name"] ]["open transactions"] is 1 then
    if sDbsA[ theKeyA ]["type"] is "valentina" then
      get VDatabase_Flush( sConnectionsA[ theConnectionA["database"] ][ theConnectionA["name"] ]["connection id"] )
      put _valentinaError( sConnectionsA[ theConnectionA["database"] ][ theConnectionA["name"] ]["connection id"] ) into theError
    else if sDbsA[ theKeyA ]["adaptor"] is "odbc" then

    else
      ## Generate adaptor specific SQL
      local theType, theSQL

      try
        put sDbsA[ theKeyA ]["type"] into theType
        replace space with empty in theType
        put "put _" & theType & "_commitTransactionSQL(pConnectionA, pParamsA) into theSQL" into theDo
        do theDO
      catch e
        put param(0) && "has not been defined for database type '" & sDbsA[ theKeyA ]["type"] & "'" into theError
      end try

      if theError is empty then
        try
          dbconn_executeSQL theSQL, theConnectionA
          put the result into theError
        catch e
          put e into theError
        end try
      end if
    end if
  end if

  if theError is empty then
    ## Decrement counter
    put max(0, sConnectionsA[ theConnectionA["database"] ][ theConnectionA["name"] ]["open transactions"] - 1) \
          into sConnectionsA[ theConnectionA["database"] ][ theConnectionA["name"] ]["open transactions"]
  end if

  return theError
end dbconn_commitTransaction


/**
Summary: Rolls back a transaction in the database connection.

Parameters:
pParamsA: Not implemented. Included for possible future use.
pConnName: The name of a Database Connection. The default is the `default connection` for the Database Object.
pDBKey: Database Object connection is associated with. Default is name returned by `sqlyoga_getDefaultDatabase()`.

Returns: Error message

References: dbconn_beginTransaction (command)
*/
command dbconn_rollbackTransaction pParamsA, pConnName, pDBKey
  local i, theDo, theError, theConnectionA
  local theKeyA

  put _CreateConnectionArray(pConnName, pDBKey) into theConnectionA
  put _KeyArrayForConnection(theConnectionA) into theKeyA

  if sDbsA[ theKeyA ]["type"] is "valentina" then

  else if sDbsA[ theKeyA ]["adaptor"] is "odbc" then

  else
    ## Generate adaptor specific SQL
    local theType, theSQL

    try
      put sDbsA[ theKeyA ]["type"] into theType
      replace space with empty in theType
      put "put _" & theType & "_rollbackTransactionSQL(pConnectionA, pParamsA) into theSQL" into theDo
      do theDO
    catch e
      put param(0) && "has not been defined for database type '" & sDbsA[ theKeyA ]["type"] & "'" into theError
    end try

    if theError is empty then
      try
        dbconn_executeSQL theSQL, theConnectionA
        put the result into theError
      catch e
        put e into theError
      end try
    end if
  end if

  ## Reset transactions.
  ## Once support for NAMES is added this code will change
  put 0 into sConnectionsA[ theConnectionA["database"] ][ theConnectionA["name"] ]["open transactions"]

  return theError
end dbconn_rollbackTransaction


private function _getBooleanValue pValue, pConnName, pDBKey
  local i, theDo, theError, theConnectionA, theKeyA

  put _CreateConnectionArray(pConnName, pDBKey) into theConnectionA
  put _KeyArrayForConnection(theConnectionA) into theKeyA

  ## Generate adaptor specific SQL
  local theType

  if char 1 of pValue is "'" then delete char 1 of pValue
  if char -1 of pValue is "'" then delete char -1 of pValue

  try
    put sDbsA[ theKeyA ]["type"] into theType
    replace space with empty in theType
    put "put _" & theType & "_getBooleanValue(pValue) into pValue" into theDo
    do theDO
  catch e
    throw param(0) && "has not been defined for database type '" & sDbsA[ theKeyA ]["type"] & "'" into theError
  end try

  return pValue
end _getBooleanValue


private function _sqlite_version pConnectionID
  local theSQL

  put "SELECT sqlite_version()" into theSQL
  return revDataFromQuery(tab, cr, pConnectionID, theSQL)
end _sqlite_version

private function _sqlite_beginTransactionSQL pConnectionA, pParamsA
  local theSQL

  put "BEGIN" into theSQL

  if pParamsA["behavior"] is among the items of "deferred,immediate,exclusive" then
    put space & toUpper(pParamsA["behavior"]) after theSQL
  end if

  put " TRANSACTION" after theSQL
  return theSQL
end _sqlite_beginTransactionSQL

private function _sqlite_commitTransactionSQL pConnectionA, pParamsA
  return "COMMIT TRANSACTION"
end _sqlite_commitTransactionSQL

private function _sqlite_rollbackTransactionSQL pConnectionA, pParamsA
  return "ROLLBACK TRANSACTION"
end _sqlite_rollbackTransactionSQL

private function _sqlite_getBooleanValue pValue
  if pValue is among the items of kBoolTrueValues then return 1
  else return 0
end _sqlite_getBooleanValue


private function _filemaker_version pConnectionID
  return 0
end _filemaker_version

private function _filemaker_beginTransactionSQL pConnectionA, pParamsA
  local theSQL

  put "BEGIN" into theSQL

  if pParamsA["behavior"] is among the items of "deferred,immediate,exclusive" then
    put space & toUpper(pParamsA["behavior"]) after theSQL
  end if

  put " TRANSACTION" after theSQL
  return theSQL
end _filemaker_beginTransactionSQL

private function _filemaker_commitTransactionSQL pConnectionA, pParamsA
  return "COMMIT TRANSACTION"
end _filemaker_commitTransactionSQL

private function _filemaker_rollbackTransactionSQL pConnectionA, pParamsA
  return "ROLLBACK TRANSACTION"
end _filemaker_rollbackTransactionSQL

private function _filemaker_getBooleanValue pValue
  if pValue is among the items of kBoolTrueValues then return 1
  else return 0
end _filemaker_getBooleanValue


private function _valentinaError pConnID
  local theError, theErrNum

  put VDatabase_ErrNumber( pConnID ) into theErrNum
  if theErrNum > 0 then
    put VDatabase_ErrString( pConnID ) into theError
  else if theErrNum < 0 then
    put "OS error ("& theErrNum &")" into theError
  end if
  return theError
end _valentinaError


private function _valentina_version pConnectionID
  return Valentina_Version(pConnectionID)
end _valentina_version

private function _valentina_beginTransactionSQL pConnectionA, pParamsA
  return empty

  local theSQL

  put "BEGIN" into theSQL

  if pParamsA["behavior"] is among the items of "deferred,immediate,exclusive" then
    put space & toUpper(pParamsA["behavior"]) after theSQL
  end if

  put " TRANSACTION" after theSQL
  return theSQL
end _valentina_beginTransactionSQL

private function _valentina_commitTransactionSQL pConnectionA, pParamsA
  return empty

  return "COMMIT TRANSACTION"
end _valentina_commitTransactionSQL

private function _valentina_rollbackTransactionSQL pConnectionA, pParamsA
  return empty

  return "ROLLBACK TRANSACTION"
end _valentina_rollbackTransactionSQL

private function _valentina_getBooleanValue pValue
  if pValue is among the items of kBoolTrueValues then return 1
  else return 0
end _valentina_getBooleanValue


private function _sqlserver_version pConnectionID
  local theSQL, theVersion

  -- http://support.microsoft.com/kb/321185
  put "SELECT @@VERSION" into theSQL
  -- Microsoft SQL Server 2008 (RTM) - 10.0.1600.22 (Intel X86)   Jul  9 2008 14:43:34   Copyright (c) 1988-2008 Microsoft Corporation  Express Edition with Advanced Services on Windows NT 5.1 <X86> (Build 2600: Service Pack 3) (VM)
  put revDataFromQuery(tab, cr, pConnectionID, theSQL) into theVersion
  if not (theVersion contains "SQL Server 7") then
    ## Assume SQL Server 2000 or SQL Server 8
    -- http://support.microsoft.com/kb/321185
    ## Have to case as query returns a SQL Server variant data type
    ## which ODBC driver doesn't seem to support.
    put "SELECT CAST(SERVERPROPERTY('productversion') AS varchar(255))" into theSQL
    get revDataFromQuery(tab, cr, pConnectionID, theSQL)
    if it is not empty then return it
    else return theVersion
  else
    return theVersion
  end if
end _sqlserver_version

private function _sqlserver_beginTransactionSQL pConnectionA, pParamsA
  local theSQL

  put "BEGIN" into theSQL

  if pParamsA["behavior"] is among the items of "deferred,immediate,exclusive" then
    put space & toUpper(pParamsA["behavior"]) after theSQL
  end if

  put " TRANSACTION" after theSQL
  return theSQL
end _sqlserver_beginTransactionSQL

private function _sqlserver_commitTransactionSQL pConnectionA, pParamsA
  return "COMMIT TRANSACTION"
end _sqlserver_commitTransactionSQL

private function _sqlserver_rollbackTransactionSQL pConnectionA, pParamsA
  return "ROLLBACK TRANSACTION"
end _sqlserver_rollbackTransactionSQL

private function _sqlserver_getBooleanValue pValue
  if pValue is among the items of kBoolTrueValues then return "1"
  else return "0"
end _sqlserver_getBooleanValue


## todo: http://dev.mysql.com/doc/refman/5.0/en/commit.html
private function _mysql_version pConnectionID
  local theSQL

  put "SELECT version()" into theSQL
  return revDataFromQuery(tab, cr, pConnectionID, theSQL)
end _mysql_version


private function _mysql_beginTransactionSQL pConnectionA, pParamsA
  local theSQL

  put "START TRANSACTION" into theSQL
  return theSQL
end _mysql_beginTransactionSQL


private function _mysql_commitTransactionSQL pConnectionA, pParamsA
  return "COMMIT"
end _mysql_commitTransactionSQL


private function _mysql_rollbackTransactionSQL pConnectionA, pParamsA
  return "ROLLBACK"
end _mysql_rollbackTransactionSQL

private function _mysql_getBooleanValue pValue
  if pValue is among the items of kBoolTrueValues then return 1
  else return 0
end _mysql_getBooleanValue


## http://www.postgresql.org/docs/8.3/static/tutorial-transactions.html
## TODO: implement savepoints
private function _postgresql_version pConnectionID
  local theSQL, theVersion

  put "SELECT version()" into theSQL
  put revDataFromQuery(tab, cr, pConnectionID, theSQL) into theVersion
  -- e.g. "PostgreSQL 8.4.0 on i386-apple-darwin, compiled by GCC i686-apple-darwin8-gcc-4.0.1 (GCC) 4.0.1 (Apple Computer, Inc. build 5370), 32-bit"
  put word 2 of theVersion into theVersion
  if the last char of theVersion is among the items of ",;" then delete the last char of theVersion
  return theVersion
end _postgresql_version


private function _postgresql_beginTransactionSQL pConnectionA, pParamsA
  local theSQL

  put "BEGIN" into theSQL
  return theSQL
end _postgresql_beginTransactionSQL


private function _postgresql_commitTransactionSQL pConnectionA, pParamsA
  return "COMMIT"
end _postgresql_commitTransactionSQL


private function _postgresql_rollbackTransactionSQL pConnectionA, pParamsA
  return "ROLLBACK"
end _postgresql_rollbackTransactionSQL

private function _postgresql_getBooleanValue pValue
  if pValue is among the items of kBoolTrueValues then return "TRUE"
  else return "FALSE"
end _postgresql_getBooleanValue


/**
Summary: Executes a SQL query using pValuesA as the binding array.

Parameters:
pSQL: SQL to execute.  Use placeholders (`:1`, `:2`) for binding.
pBindingsA: Array of values to bind.  Keyed using integers.
pConnName: The name of a Database Connection. The default is the `default connection` for the Database Object.
pDBKey: Database Object connection is associated with. Default is name returned by `sqlyoga_getDefaultDatabase()`.

Returns: Returns empty. Affected rows in `it`. Any errors will be thrown: `sqlyoga_executesql_err,ERROR`
*/
command dbconn_executeWBindings pSQL, pBindingsA, pConnName, pDBKey
  local theError, theConnectionA, theKeyA, theConnectionID

  # This might be a good place to add replication.
  # A connection object could have a list of other connection objects that should be replicated to.
  # What are the rules of replication?
  put _CreateConnectionArray(pConnName, pDBKey) into theConnectionA
  put _KeyArrayForConnection(theConnectionA) into theKeyA

  dbconn_connect theConnectionA
  put the result into theError

  if theError is empty then
    put it into theConnectionID
  end if

  ## Log last SQL statement
  dbconn_set "last executed sql", pSQL, theConnectionA

  local theAffectedRows

  if sDbsA[ theKeyA ]["type"] is "valentina" then
    if the keys of pBindingsA is not empty then
      put VDatabase_SqlExecute( theConnectionID, pSQL, "pBindingsA" ) into theAffectedRows
    else
      put VDatabase_SqlExecute( theConnectionID, pSQL) into theAffectedRows
    end if
    put _valentinaError(theConnectionID) into theError
  else
    ##
    ## try reconnecting once
    repeat with queryAttempts = 1 to 2
      if the keys of pBindingsA is not empty then
        revExecuteSQL theConnectionID, pSQL, "pBindingsA"
        put the result into theAffectedRows
      else
        revExecuteSQL theConnectionID, pSQL
        put the result into theAffectedRows
      end if

      ##
      ## Try reconnecting
      if theAffectedRows is not an integer then
        if queryAttempts is 1 then ## only try reconnecting 1 time
          local theNewConnectionID

          put _TryConnectingAgainBasedOnError(theConnectionA, theAffectedRows) into theNewConnectionID
          if theNewConnectionID > 0 then
            ## Try query again using new connection id
            put theNewConnectionID into theConnectionID
            put empty into theAffectedRows
          else
            exit repeat
          end if
        end if
      else
        exit repeat
      end if
      ##
    end repeat
  end if

  --> CHECK FOR ERRORS
  if theAffectedRows is not an integer then
    _ThrowError "sqlyoga_executesql_err", theAffectedRows && "(" & pSQL & ")"
  end if

  return theAffectedRows for value
end dbconn_executeWBindings


/**
Summary: Executes a SQL query against a database connection and returns the result as data from the selected columns (no cursor).

Parameters:
pSQL: SQL query to execute.
pBindingsA: Array of values to bind to pSQL.  Key `1` will replace `:1` in the query, etc. You can pass empty.
xOutData: Upon completion the data returned will be in this parameter.
pColDel: Character to delimit columns in the returned text. Default is the default value for `revDataFromQuery` (tab character).
pRowDel: Character to delimit rows in the returned text. Default is the default value for `revDataFromQuery` (return character).
pConnName: The name of a Database Connection. The default is the `default connection` for the Database Object.
pDBKey: Database Object connection is associated with. Default is name returned by `sqlyoga_getDefaultDatabase()`.

Returns: Empty. Any errors will be thrown: `sqlyoga_executesql_err,ERROR`
*/
command dbconn_retrieveQueryAsData pSQL, pBindingsA, @xOutData, pColDel, pRowDel, pConnName, pDBKey
  -----
  local theConnectionA, theConnectionID, theKeyA
  local theError
  local theExtraError
  -----
  put _CreateConnectionArray(pConnName, pDBKey) into theConnectionA
  put _KeyArrayForConnection(theConnectionA) into theKeyA

  dbconn_connect theConnectionA
  put the result into theError

  if theError is empty then
    put it into theConnectionID
  end if

  if theError is empty then
    local theLocation

    dbconn_set "last executed sql", pSQL, theConnectionA

    if sDbsA[ theKeyA ]["type"] is "valentina" then
      --   put VDatabase_SqlSelectRecords( mDatabase, "SELECT a1 FROM T1 WHERE a1 = 1 or a1 = 2", \
          -- "kServerSide", "kReadWrite",, 1, 3, " ", " ", "<td>", "</td>" , "<tr>", "</tr>") into res
      if sConnectionsA[ theConnectionA["database"] ][ theConnectionA["name"] ]["valentina client connection id"] > 0 then
        put "kServerSide" into theLocation
      else
        put "kClientSide" into theLocation
      end if
      if the keys of pBindingsA is not empty then
        put VDatabase_SQLSelectRecords( theConnectionID, pSQL, theLocation, "kReadOnly", "pBindingsA", 1, -1, \
              pColDel, pRowDel, "", "", "", "") into xOutData
      else
        put VDatabase_SQLSelectRecords( theConnectionID, pSQL, theLocation, "kReadOnly", "", 1, -1, \
              pColDel, pRowDel, "", "", "", "") into xOutData
      end if
      put _valentinaError(theConnectionID) into theError
    else
      repeat with queryAttempts = 1 to 2
        if the keys of pBindingsA is not empty then
          put revDataFromQuery(pColDel, pRowDel, theConnectionID, pSQL, pBindingsA) into xOutData
        else
          put revDataFromQuery(pColDel, pRowDel, theConnectionID, pSQL) into xOutData
        end if
        if char 1 to 9 of xOutData is "revdberr," then
          delete char 1 to 9 of xOutData
          put xOutData into theError
          put empty into xOutData

          set the itemDelimiter to ":"
          if item 1 of theError is "Database Error" then
            delete item 1 of theError
            put word 1 to -1 of theError into theError
            -- put line 2 to -1 of theError into theExtraError
            -- put line 1 of theError into theError
            -- if the environment is "development" then
            -- if theExtraError is not empty then
            -- put "Extra error information for" && param(0) && ":" && theExtraError
            -- end if
            -- end if
          end if
        end if

        if theError is not empty then
          if queryAttempts is 1 then ## Try reconnecting once
            local theNewConnectionID

            put _TryConnectingAgainBasedOnError(theConnectionA, theError) into theNewConnectionID
            if theNewConnectionID > 0 then
              ## Try query again using new connection id
              put theNewConnectionID into theConnectionID
              put empty into theError
            else
              exit repeat
            end if
          end if
        else
          exit repeat
        end if

      end repeat

    end if

    if theError is not empty then
      ## New throw behavior
      _ThrowError "sqlyoga_executesql_err", theError && "(" & pSQL & ")"
      -- throw "sqlyoga_executesql_err," & theError && "(" & pSQL & ")"
    end if
  end if

  return empty
end dbconn_retrieveQueryAsData


/**
Summary: Executes a SQL query against a database connection and returns the results in a numerically indexed array.

Parameters:
pSQL: SQL query to execute.
pVendorParamsA: Array of parameters to use for executing the query. All: report null. Valentina: location, lock type, direction.
pBindingsA: Array of values to bind to pSQL.  Key `1` will replace `:1` in the query, etc. You can pass empty.
xOutArray: Results will be put into this array. If the array already contains numeric keys then the results will be appended.
pConnName: The name of a Database Connection. The default is the `default connection` for the Database Object.
pDBKey: Database Object connection is associated with. Default is name returned by `sqlyoga_getDefaultDatabase()`.

Description:
This handler will query a database and convert any returned records into a multi-dimensional array.
Each row in the database cursor will be represented by a number in the first dimension. Each column
in each row will be contained in the second dimension for that number.

Example:
# A cursor with 2 columns (name and email) and 2 rows:

theDataA[1]["name"]
theDataA[1]["email"]
theDataA[2]["name"]
theDataA[2]["email"]

Returns: Error message
*/
command dbconn_retrieveQueryAsArray pSQL, pVendorParamsA, pBindingsA, @xOutArray, pConnName, pDBKey
  -----
  local theConnectionA, theConnectionID
  local theDynamicKeyA
  local theError
  local theFields
  local theIndex
  local theQueryA
  -----
  put _CreateConnectionArray(pConnName, pDBKey) into theConnectionA

  put the number of elements of xOutArray into theIndex
  if theIndex is not an integer then put 0 into theIndex

  dbconn_connect theConnectionA
  put the result into theError

  if theError is empty then
    put it into theConnectionID
  end if

  if theError is empty then
    dbconn_openCursor pSQL, pBindingsA, pVendorParamsA, theConnectionA
    put the result into theError
    put it into theQueryA["cursor id"]
  end if

  if theError is empty then
    put theConnectionA["database"] into theQueryA["database"]
    put theConnectionA["name"] into theQueryA["connection"]
    put pVendorParamsA["report null"] into theQueryA["report null"]

    if dbconn_get("type", theConnectionA) is "valentina" then
      put _ValentinaFieldsFromCursor(theQueryA["cursor id"]) into theFields

      if VCursor_FirstRecord(theQueryA["cursor id"]) then
        repeat forever
          add 1 to theIndex
          put theIndex into theDynamicKeyA[1]
          _CursorRowToArray theQueryA, theFields, xOutArray, theDynamicKeyA
          get VCursor_NextRecord( theQueryA["cursor id"] )
          if not it then exit repeat
        end repeat
      end if

    else
      if not revQueryIsAtEnd(theQueryA["cursor id"]) then
        put revDatabaseColumnNames(theQueryA["cursor id"]) into theFields

        repeat forever
          add 1 to theIndex
          put theIndex into theDynamicKeyA[1]
          _CursorRowToArray theQueryA, theFields, xOutArray, theDynamicKeyA
          revMoveToNextRecord theQueryA["cursor id"]
          if not the result then exit repeat
        end repeat
      end if
    end if
  end if

  if theQueryA["cursor id"] > 0 then
    dbconn_closeCursor theQueryA["cursor id"], theConnectionA
  end if

  return theError
end dbconn_retrieveQueryAsArray


--> Object: Scope


private function _KeyArrayForScope pScopeA
  local theKeyA

  put pScopeA["database"] into theKeyA[1]
  put "table objects" into theKeyA[2]
  put "tables" into theKeyA[3]
  put pScopeA["table"] into theKeyA[4]
  put "scopes" into theKeyA[5]
  put pScopeA["name"] into theKeyA[6]
  return theKeyA
end _KeyArrayForScope


/**
Summary: Creates a Scope Object and attaches it to a Table Object.

Parameters:
pTableA: The name of the table to attach the scope to.
pName: The name of the scope.
pDBKey: Database Object connection is associated with. Default is name returned by `sqlyoga_getDefaultDatabase()`.

Description:
Create a Scope Object to help you generate searches dynamically.

Returns:
it: Scope reference array
the result: Error message
*/
command tblscope_createObject pTableA, pName, pDBKey
  -----
  local theA
  local theKeyA
  local theNextIndex
  -----
  put _CreateTableArray(pTableA, pDBKey) into pTableA
  put _KeyArrayForTable(pTableA) into theKeyA

  if pName is empty then _ThrowError kErrObjectNameTaken, "scope name cannot be empty"

  if pName is among the keys of sDbsA[ theKeyA ]["scopes"] then
    _ThrowError kErrObjectNameTaken, "scope '" & pName & "' already exists for table '" & tableobj_get(pTableA, "name") & "'"
  else
    put pName into theA["name"]
    put empty into theA["related table joins"]
    put empty into theA["conditions"]

    ## Store it
    put theA into sDbsA[theKeyA]["scopes"][pName]

    ## Return reference
    put empty into theA
    put kScopeReference into theA["type"]
    put pTableA["database"] into theA["database"]
    put pTableA["name"] into theA["table"]
    put pName into theA["name"]
    return theA for value
  end if
end tblscope_createObject


/**
Summary: Deletes a Scope Object from a Table Object.

Parameters:
pScopeA: Scope reference array. See `tableobj_getScope()`.

Returns: Error message.

References: tableobj_getScope (function)
*/
command tblscope_deleteObject pScopeA
  local theKeyA

  _ValidateScopeArray pScopeA

  put _KeyArrayForScope(pScopeA) into theKeyA

  ## Delete scope
  delete local sDbsA[ theKeyA ]

  return empty
end tblscope_deleteObject


/**
Summary: Retrieves properties of a Scope Object.

Parameters:
pScopeA: Scope reference array. See tableobj_getScope().
pProp: The property to get.

Description:
| Property | Description |
| -------- |:----------- |
| `conditions` | Search conditions for the Scope (as set using `tableobj_set`). |
| `database` | Database that Scope is associated with. |
| `order by` | `ORDER BY` fields. |
| `sql conditions` | The conditions as they will appear in the SQL statement. Any english operators used when setting the `conditions` will have been translated into SQL. |
| `table` | Table that Scope is associated with. |
| `[related table] joins` | If you haven't defined relationships between tables then this is the string you set the joins to. If you have defined relationships then you will get the internal array that represents the join. |

Returns: value

References: tableobj_getScope (function)
*/
function tblscope_get pScopeA, pProp
  local theKeyA

  _ValidateScopeArray pScopeA
  put _KeyArrayForScope(pScopeA) into theKeyA

  switch pProp
    case "database"
      return pScopeA["database"]
      break
    case "table"
      return tableobjects_getTable(pScopeA["table"], pScopeA["database"])
      break
    case "conditions"
      return sDbsA[theKeyA]["conditions"]["human"]
      break
    case "sql conditions"
      return sDbsA[theKeyA]["conditions"]["sql"]
      break
    default
      ## todo: Move to defined list in case we add props later
      if pProp is among the keys of sDbsA[theKeyA] then
        return sDbsA[theKeyA][pProp]
      else
        _ThrowError kErrInvalidProperty, "invalid scope property '" & pProp & "'"
      end if
  end switch
end tblscope_get


/**
Summary: Sets properties of a Scope Object.

Parameters:
pScopeA: Scope reference array. See `tableobj_getScope()`.
pProp: The property to get.
pValue: Value to set property to.

Description:
| Property | Description |
| -------- |:----------- |
| `conditions` | Search conditions for the Scope. Use binding variables in order to set the value when adding the scope to a SQL Query Object. |
| `[related table] joins` | The related tables to that the scope requries in addition to the scopes table. You can simply pass in a string like `LEFT JOIN related_table_name`. The string will be parsed and the ON portion of the JOIN will be included. |
| `order by` | ORDER BY fields. |

Returns: empty

References: tableobj_getScope (function)
*/
command tblscope_set pScopeA, pProp, pValue
  -----
  local theCurrentName
  local theKeyA
  local theTableA, theTableKeyA
  -----
  _ValidateScopeArray pScopeA
  put _KeyArrayForScope(pScopeA) into theKeyA

  put tblscope_get(pScopeA, "table") into theTableA
  put _KeyArrayForTable(theTableA) into theTableKeyA

  ## todo: Move to defined list in case we add props later
  if pProp is among the keys of sDbsA[theKeyA] then
    switch pProp
      case "related table joins"
      case "joins"
        ## Can pass in a string i.e. LEFT OUTER JOIN steps, tlk_lessons_servers
        ## In this case we parse string, lookup relationship and create JOINS array
        if pValue is not an array then put _StringToJoins(theTableA, pValue) into pValue
        _VerifyTableJoins theTableA, pValue
        put pValue into sDbsA[ theKeyA ][pProp]
        break

      case "conditions"

        ## Translate any english into SQL
        put _TranslateConditions(pValue) into sDbsA[ theKeyA ]["conditions"]["sql"]

        ## Cache original user setting
        put pValue into sDbsA[ theKeyA ]["conditions"]["human"]
        break

    end switch
  else
    _ThrowError kErrInvalidProperty, "invalid scope property '" & pProp & "'"
  end if

  return empty
end tblscope_set


--> Object: Tables


/**
Summary: Retrieves properties of the Table Objects in a Database Object

Parameters:
pProp: The property to get.
pDBKey: Database Object to target. Default is name returned by `sqlyoga_getDefaultDatabase()`.

Description:
| Property | Description |
| -------- |:----------- |
| `tables` | An array of Table Object reference arrays. |
| `relationships` | An array of Relationship Object reference arrays. |

Returns: value
*/
function tableobjects_get pProp
  -----
  local pKey,theA,theKey
  local theIndex
  local theKeys
  local theReference
  -----
  put param(2) into pKey
  _ValidateKey pKey

  switch pProp
    case "tables"
      put the keys of sDbsA[pKey]["table objects"]["tables"] into theKeys
      sort lines of theKeys
      repeat for each line theKey in theKeys
        add 1 to theIndex
        put _CreateTableArray(theKey, pKey) into theA[theIndex]
      end repeat
      return theA
      break

    case "relationships"
      repeat with i = 1 to the number of elements of sDbsA[pKey]["table objects"]["relationships"]
        add 1 to theIndex
        put kRelationshipReference into theA[theIndex]["type"]
        put pKey into theA[theIndex]["database"]
        put i into theA[theIndex]["index"]
      end repeat
      return theA
      break

    default
      ## Todo: need actual list to compare against in case we add valid props later on
      if pProp is not among the keys of sDbsA[pKey]["schema"]["tables"] then
        _ThrowError kErrInvalidProperty, "invalid property passed to " & param(0)
      else
        return sDbsA[pKey]["schema"]["tables"][pProp]
      end if
  end switch
end tableobjects_get


/**
Summary: Determines whether a table object exists.

Parameters:
pTableName: Name of the table to get the reference array for.
pDBKey: Database Object to target. Default is name returned by `sqlyoga_getDefaultDatabase()`.

Returns: Boolean
*/
function tableobjects_tableExists pTableName, pDBKey
  _ValidateKey pDBKey

  try
    _ValidateTableExistence pDBKey, pTableName
    return true
  catch e
  end try

  return false
end tableobjects_tableExists



/**
Summary: Returns a Table Object reference array.

Parameters:
pTableName: Name of the table to get the reference array for.
pDBKey: Database Object to target. Default is name returned by `sqlyoga_getDefaultDatabase()`.

Returns: Table reference array. Empty if no Table Object exists.
*/
function tableobjects_getTable pTableName, pDBKey
  -----
  local theA
  -----
  _ValidateKey pDBKey

  -- try
  _ValidateTableExistence pDBKey, pTableName

  put kTableReference into theA["type"]
  put pDBKey into theA["database"]
  put pTableName into theA["name"]

  -- catch e
  -- ## table doesn't exist
  -- end try

  return theA
end tableobjects_getTable


/**
Summary: Returns a Relationship object reference array.

Parameters:
pIndexOrName: The index of the relationship to retrieve. Alternatively you can pass in a name if you specified a name when creating the relationship.
pDBKey: Database Object to target. Default is name returned by `sqlyoga_getDefaultDatabase()`.

Returns: Relationship reference array.
*/
function tableobjects_getRelationship pIndexOrName, pDBKey
  -----
  local theA
  -----
  _ValidateKey pDBKey

  ## Lookup name
  if pIndexOrName is not an integer then
    put _getRelationshipIndexFromName(pDBKey, pIndexOrName) into pIndexOrName
  end if

  _ValidateRelationshipExistence pDBKey, pIndexOrName

  put kRelationshipReference into theA["type"]
  put pDBKey into theA["database"]
  put pIndexOrName into theA["index"]

  return theA
end tableobjects_getRelationship


--> Object: Table


private function _KeyArrayForTable pTableA
  local theKeyA

  put pTableA["database"] into theKeyA[1]
  put "table objects" into theKeyA[2]
  put "tables" into theKeyA[3]
  put pTableA["name"] into theKeyA[4]
  return theKeyA
end _KeyArrayForTable


## pass in a table object array to get a key array for the table objects table in the schema
private function _KeyArrayForSchemaTable pTableA
  local theKeyA

  put pTableA["database"] into theKeyA[1]
  put "schema" into theKeyA[2]
  put "tables" into theKeyA[3]
  put pTableA["name"] into theKeyA[4]
  return theKeyA
end _KeyArrayForSchemaTable


/**
Summary: Creates a Table Object.

Parameters:
pName: The name of the Table Object to create.
pType: "table" or "alias". Default is "table".
pDBKey: Database Object table is associated with. Default is name returned by `sqlyoga_getDefaultDatabase()`.

Description:
Creating a Table Object allows you to take advantage of a number of SQL Yoga features.
SQL Yoga already knows about the tables and fields in your database and can generate
queries for those tables. But when you define Table Objects you can take advantage of:

- Defining Relationships between tables, allowing SQL Yoga to generate hierachel query results.
- Defining Scopes, or predefined searches, which make dynamic searches a snap.
- Defining additional table properties i.e. a property that returns a condensed version of a field with lots of text.
- Defining callbacks when records are created, deleted, retrieved or updated.

In addition, a Table Object can be an "alias" to another table. An alias is a table object  that points to a real
table but has certain conditions that filter the content returned. For example, you may have an
`attributes` table for foods. While `attributes` is a single table you may have a field called `type`
that categorizes the various attributes. If you wanted to treat different types of `attributes`  as
their own tables you could creat ean alias to the `attributes` table. For example, you could create a
an alias called `region`. The table would be the `attributes` table but the `conditions` would be:

```
type = "region"
```

Whenever you referenced the `region` table in a SQL Query Object or join SQL Yoga would know to target
the `attributes` table and to add `type="region"` to the WHERE condition.

Returns:
it: Table Object reference array
the result: Error message
*/
command tableobj_createObject pName, pType, pDBKey
  -----
  local theA
  local theError
  local theProp
  -----
  _ValidateKey pDBKey

  if pType is empty then put "table" into pType

  if pName is empty then _ThrowError kErrObjectNameTaken, "table name cannot be empty"
  if pName is among the keys of sDbsA[pDBKey]["table objects"]["tables"] then
    _ThrowError kErrObjectNameTaken, "table '" & pName & "' already exists"
  end if

  ## NOTE: taken out. Don't allow definition of relationships before table
  ## is created
  ##--------
  ## Suck up any properties that might already exist.
  ## Defining relationships before creating the table object
  ## might populate some of the table object props ahead of
  ## time.
  -- put sDbsA[pKey]["table objects"]["tables"][pName] into theA
  -----------

  _SetDefaultTableProperties pType, theA
  put pName into theA["name"]

  ## Store it
  put theA into sDbsA[pDBKey]["table objects"]["tables"][pName]

  ## Return reference
  put empty into theA
  put kTableReference into theA["type"]
  put pDBKey into theA["database"]
  put pName into theA["name"]

  if theError is not empty then
    return theError for error
  else
    return theA for value
  end if
end tableobj_createObject


private command _SetDefaultTableProperties pType, @xArrayA
  local theProps

  put toLower(pType) into xArrayA["type"]

  if "name" is not among the keys of xArrayA then
    put empty into xArrayA["name"]
  end if

  if xArrayA["type"] is "alias" then
    put "alias for table,conditions" into theProps
  else
    put "scopes,scopes lookup,relationships lookup" into theProps
  end if

  repeat for each item theProp in theProps
    if theProp is not among the keys of xArrayA then
      put empty into xArrayA[theProp]
    end if
  end repeat

  return empty
end _SetDefaultTableProperties


/**
Summary: Deletes a Table Object.

Parameters:
pName: The name of the Table Object to delete.
pDBKey: Database Object table is associated with. Default is name returned by `sqlyoga_getDefaultDatabase()`.

Returns: Error message
*/
command tableobj_deleteObject pTableA, pDBKey
  local theKeyA, theRelationA, theRelationIndex, theRelationProp
  local theTable

  put _CreateTableArray(pTableA, pDBKey) into pTableA

  put _KeyArrayForTable(pTableA) into theKeyA

  ## Reset any relationships props pointing to this table
  ## Note that this will erase any references to fields in this table as well.
  repeat for each key theRelationIndex in sDbsA[ theKeyA ]["relationships lookup"]
    put tableobjects_getRelationship(theRelationIndex, pTableA["database"]) into theRelationA

    put sDbsA[ theKeyA ]["relationships lookup"][theRelationIndex] into theRelationProp
    _ResetRelationProperty theRelationA, theRelationProp
  end repeat

  ## Delete any aliases
  repeat for each key theTable in sDbsA[ pTableA["database"] ]["table objects"]["tables"]
    if sDbsA[ pTableA["database"] ]["table objects"]["tables"][theTable]["type"] is "alias" then
      if pTableA["name"] is sDbsA[ pTableA["database"] ]["table objects"]["tables"][theTable]["alias for table"] then
        tableobj_deleteObject theTable
      end if
    end if
  end repeat

  ## Delete table
  delete local sDbsA[ pTableA["database"] ]["table objects"]["tables"][ pTableA["name"] ]

  ## Delete any links in query templates
  _DeleteTableReferencesInQueryTemplates pTableA["database"], pTableA["name"]

  return empty
end tableobj_deleteObject pTableA


/**
Summary: Retrieves properties of a Table Object.

Parameters:
pTableA: Name of the table to get a property for.
pProp: The property to get.
pDBKey: Database Object table is associated with. Default is name returned by `sqlyoga_getDefaultDatabase()`.

Description:
| Property | Description |
| -------- |:----------- |
| `conditions` | If a Table object is an alias to another table then this property returns any conditions that have been set. The conditions are used to filter the table content that the alias represents. The format is `FIELD=VALUE,FIELD2=VALUE2,...` |
| `database` | The name of the Database object the Table object is associated with. |
| `fields` | A return delimited list of the fields in the table. |
| `fields array` | The array containing all field information for the table. The keys are the names of the fields. Each field key has properties such as `name`, `type`, `meta type`, etc. |
| `name` | The name of the Table object. |
| `primary key` | A comma delimited list of field names that make up the primary key for the table. |
| `relationships` | A return delimited list of the names of relationships associated with the table. |
| `scopes` | A return delimited list of the names of the Table object's Scope objects. |
| `table aliases` | A return delimited list of names of Table objects that are aliases to the Table object. |
| `type` | The type of the Table object - `table` or `alias`. |


Returns: value
*/
function tableobj_get pTableA, pProp, pDBKey
  -----
  local theA
  local theOriginalKeyA
  local theAliasA
  local theAliasKeyA, theKey, theKeyA, theKeys
  local theFieldIndex, theFields
  local theIndex
  local theNames
  -----
  put _CreateTableArray(pTableA, pDBKey) into pTableA
  put _KeyArrayForTable(pTableA) into theKeyA

  ## Resolve alias
  put theKeyA into theOriginalKeyA
  if sDbsA[ theKeyA ]["type"] is "alias" then
    put theKeyA into theAliasKeyA
    put sDbsA[ theKeyA ]["alias for table"] into pTableA["name"]
    put _KeyArrayForTable(pTableA) into theKeyA
  end if

  switch pProp
    ## shared props
    case "type"
    case "name"
      if theAliasKeyA is an array then
        return sDbsA[ theAliasKeyA ][pProp]
      else
        return sDbsA[ theKeyA ][pProp]
      end if
      break
      ## end shared props

    case "database"
      return pTableA["database"]
      break

    case "table aliases"
      local theTables

      if sDbsA[ theOriginalKeyA ]["type"] is not "alias" then
        repeat for each key theTable in sDbsA[ pTableA["database"] ]["table objects"]["tables"]
          if theTable is pTableA["name"] then next repeat

          if sDbsA[ pTableA["database"] ]["table objects"]["tables"][theTable]["type"] is "alias" then
            if sDbsA[ pTableA["database"] ]["table objects"]["tables"][theTable]["alias for table"] is pTableA["name"] then
              put theTable & cr after theTables
            end if
          end if
        end repeat
        delete the last char of theTables
      end if
      return theTables
      break

    case "primary key"
      if "primary key" is among the keys of sDbsA[ theKeyA ] then
        return sDbsA[ theKeyA ]["primary key"]
      else
        local theSchemaTableKeyA

        ## Get schema table primary keys
        put _KeyArrayForSchemaTable(pTableA) into theSchemaTableKeyA
        return sDbsA[ theSchemaTableKeyA ]["primary key"]
      end if
      break

    case "fields"
      put _KeyArrayForSchemaTable(pTableA) into theSchemaTableKeyA
      put sDbsA[ theSchemaTableKeyA ]["field order"] into theFields
      replace comma with cr in theFields
      return theFields
      break

    case "fields array"
      put _KeyArrayForSchemaTable(pTableA) into theSchemaTableKeyA
      return sDbsA[ theSchemaTableKeyA ]["fields"]
      break

    case "relationship indexes"
      if theAliasKeyA is an array then
        put the keys of sDbsA[ theAliasKeyA ]["relationships lookup"] into theKeys
      else
        put the keys of sDbsA[ theKeyA ]["relationships lookup"] into theKeys
      end if

      ## Return an array of relationship references
      put empty into theA
      sort lines of theKeys ascending numeric

      put 0 into theIndex
      repeat for each line theKey in theKeys
        add 1 to theIndex

        put kRelationshipReference into theA[theIndex]["type"]
        put pTableA["database"] into theA[theIndex]["database"]
        put theKey into theA[theIndex]["index"]
      end repeat

      return theA
      break

    case "relationships"
      local theRelationships, theIndexes

      if theAliasKeyA is an array then
        put the keys of sDbsA[ theAliasKeyA ]["relationships lookup"] into theIndexes
      else
        put the keys of sDbsA[ theKeyA ]["relationships lookup"] into theIndexes
      end if

      ## Return list of names
      sort lines of theIndexes ascending numeric

      repeat for each line theIndex in theIndexes
        put sDbsA[ pTableA["database"] ]["table objects"]["relationships"][theIndex]["name"] & cr after theRelationships
      end repeat
      delete the last char of theRelationships
      return theRelationships
      break

    case "scopes"
      put the keys of sDbsA[ theOriginalKeyA ]["scopes"] into theKeys
      sort lines of theKeys
      return theKeys
      break

      ## Alias properties
    case "alias for table"
      if theAliasKeyA is an array then
        return sDbsA[ theAliasKeyA ]["alias for table"]
      else
        _ThrowError kErrCantFindObject, "invalid target for table alias property '" & pProp & "'"
      end if
      break

    case "conditions"
      local theConditions

      if theAliasKeyA is an array then
        put empty into theConditions
        repeat with i = 1 to the number of elements of sDbsA[ theAliasKeyA ]["conditions"]
          put sDbsA[ theAliasKeyA ]["conditions"][i]["field"] & "=" & \
                sDbsA[theAliasKeyA]["conditions"][i]["value"] & comma after theConditions
        end repeat
        delete the last char of theConditions
        return theConditions
      else
        _ThrowError kErrCantFindObject, "invalid target for table alias property '" & pProp & "'"
      end if
      break

    case "table"
      if theAliasKeyA is an array then
        return pTableA
      else
        _ThrowError kErrCantFindObject, "invalid target for table alias property '" & pProp & "'"
      end if
      break

      ## end alias properties

    default
      if pProp is among the keys of sDbsA[ theKeyA ] then
        ## todo: update to set list so we can add props in the future
        return sDbsA[ theKeyA ][pProp]
      else
        _ThrowError kErrInvalidProperty, "invalid table property '" & pProp & "'"
      end if
  end switch
end tableobj_get


/**
Summary: Retrieves properties of a Table Object.

Parameters:
pTableA: Name of the table to get a property for.
pProp: The property to get.
pValue: The value.
pDBKey: Database Object table is associated with. Default is name returned by `sqlyoga_getDefaultDatabase()`.

Description:
| Property | Description |
| -------- |:----------- |
| `conditions` | |
| `primary key` | |
| `type` | |

Returns: value
*/
command tableobj_set pTableA, pProp, pValue, pDBKey
  local theKeyA, theOriginalKeyA, theAliasKeyA, theAliasTableA
  local theA

  put _CreateTableArray(pTableA, pDBKey) into pTableA

  put _KeyArrayForTable(pTableA) into theKeyA

  ## Resolve alias
  put theKeyA into theOriginalKeyA

  if sDbsA[ theKeyA ]["type"] is "alias" then
    put theKeyA into theAliasKeyA
    put pTableA into theAliasTableA
    put sDbsA[ theKeyA ]["table index"] into pTableA["index"]
    put _KeyArrayForTable(pTableA) into theKeyA
  end if

  set the wholeMatches to true

  switch pProp
    case "type"
      if pValue is not among the items of "alias,table" then _ThrowError kErrInvalidProperty, "invalid value '" & pValue & "' for property '" & pProp & "'"
      put sDbsA[ theOriginalKeyA ]["name"] into theA["name"]
      _SetDefaultTableProperties pValue, theA
      put theA into sDbsA[ theOriginalKeyA ]
      break

    default
      ## Branch based on type
      if sDbsA[ theOriginalKeyA ]["type"] is "alias" then
        switch pProp
          case "name"
            if "." is in pValue then _ThrowError kErrRenameErrorInDestination, "table name can not contain '.'"
            if "," is in pValue then _ThrowError kErrRenameErrorInDestination, "table name can not contain ','"
            if " " is in pValue then _ThrowError kErrRenameErrorInDestination, "table name can not contain a space"

            if pValue is not sDbsA[ theAliasKeyA ]["name"] then
              if pValue is among the keys of sDbsA[ theAliasTableA["database"] ]["schema"]["tables lookup"] then \
                    _ThrowError kErrRenameErrorInDestination, "a table named '" & pValue & "' already exists"

              ## update index
              delete local sDbsA[ theAliasTableA["database"] ]["schema"]["tables lookup"][ sDbsA[ theAliasKeyA]["name"] ]
              put theAliasTableA["index"] into sDbsA[ theAliasTableA["database"] ]["schema"]["tables lookup"][pValue]
            end if

            break
          case "alias for table"
            put pValue into sDbsA[ theAliasKeyA ][pProp]
            break
          case "conditions"
            local theConditionsA, i, theField

            put empty into theConditionsA
            put 0 into i

            repeat for each item theEntry in pValue
              add 1 to i
              put theEntry into theField
              split theField by "="
              put theField[1] into theConditionsA[i]["field"]
              if theConditionsA[i]["field"] is not empty then
                put theField[2] into theConditionsA[i]["value"]
              else
                _ThrowError kErrCantFindObject, "invalid field '" & theField[1] & "' in condition"
              end if
            end repeat
            put theConditionsA into sDbsA[ theAliasKeyA ][pProp]
            break
          default
            _ThrowError kErrInvalidProperty, "invalid table alias property '" & pProp & "'"
        end switch
      else

        ## Set
        switch pProp
          case "name"
            if "." is in pValue then _ThrowError kErrRenameErrorInDestination, "table name can not contain '.'"
            if "," is in pValue then _ThrowError kErrRenameErrorInDestination, "table name can not contain ','"
            if " " is in pValue then _ThrowError kErrRenameErrorInDestination, "table name can not contain a space"

            if pValue is not sDbsA[ theKeyA ]["name"] then
              if pValue is among the keys of sDbsA[ theKeyA["database"] ]["schema"]["tables lookup"] then \
                    _ThrowError kErrRenameErrorInDestination, "a table named '" & pValue & "' already exists"

              ## update index
              delete local sDbsA[ pTableA["database"] ]["schema"]["tables lookup"][ sDbsA[ theKeyA]["name"] ]
              put pTableA["index"] into sDbsA[ pTableA["database"] ]["schema"]["tables lookup"][pValue]
            end if

            break

          case "primary key"
            ## if primary key is set on object then it overrides schema
            if pValue is empty then
              ## inherit
              delete local sDbsA[ theKeyA ][pProp]
            else
              put pValue into sDbsA[ theKeyA ][pProp]
            end if
            break

          default
            if pProp is among the keys of sDbsA[ theKeyA ] then
              put pValue into sDbsA[ theKeyA ][pProp]
            else
              _ThrowError kErrInvalidProperty, "invalid table property '" & pProp & "'"
            end if
        end switch

      end if    ## processing 'table' rather than 'alias'
  end switch

  return empty
end tableobj_set


/**
Summary: Returns a Scope reference array.

Parameters:
pTableA: Table name or Table Reference array.
pScopeName: Name of scope.
pDBKey: Database Object table is associated with. Default is name returned by `sqlyoga_getDefaultDatabase()`. Only applies if pTableA is a name and not a reference array.

Returns: Scope Reference array
*/
function tableobj_getScope pTableA, pScopeName
  -----
  local theA
  local theKeyA
  -----
  put _CreateTableArray(pTableA, param(3)) into pTableA
  put _KeyArrayForTable(pTableA) into theKeyA

  ## Note: Do NOT resolve alias. Scopes are attached to aliases or table so developer
  ## can organize them.

  try
    _ValidateScopeExistence pTableA["database"], pTableA["name"], pScopeName

    put kScopeReference into theA["type"]
    put pTableA["database"] into theA["database"]
    put pTableA["name"] into theA["table"]
    put pScopeName into theA["name"]
  catch e
    ## scope doesn't exist
  end try

  return theA
end tableobj_getScope


--> Object: Relationship


private function _KeyArrayForRelationship pRelationA
  local theKeyA

  put pRelationA["database"] into theKeyA[1]
  put "table objects" into theKeyA[2]
  put "relationships" into theKeyA[3]
  put pRelationA["index"] into theKeyA[4]
  return theKeyA
end _KeyArrayForRelationship


private command _ResetRelationProperty pRelationA, pProperty
  local theKeyA

  put _KeyArrayForRelationship(pRelationA) into theKeyA

  ## If replacing value then we need to reset some props
  if sDbsA[theKeyA][pProperty] is not empty then
    put empty into sDBsA[theKeyA]["owner"]
    put empty into sDBsA[theKeyA]["joins"]
  end if

  switch pProperty
    case "left table"
    case "right table"
      put empty into sDbsA[theKeyA][pProperty]
      break
    case "cross-reference table"
      put empty into sDbsA[theKeyA][pProperty]
      break
  end switch
end _ResetRelationProperty


/**
Summary: Creates a Relationship Object.

Parameters:
pName: A name for the relationship.
pDBKey: Database Object to associate relationship with.

Description:
Internally relationships are stored used numerical indexes but if you would like to
provide a name for lookup purposes you may. If you specify a name it is up to you to ensure that names
are unique.


Returns:
it: Relationship Reference array
the result: Error message
*/
command tblrelation_createObject pName, pDBKey
  -----
  local theA, theExistingIndex, theNextIndex
  local theError
  local theProp
  -----
  _ValidateKey pDBKey

  if pName is empty then _ThrowError kErrObjectNameTaken, "relationship name cannot be empty"
  put _getRelationshipIndexFromName(pDBKey, pName) into theExistingIndex
  if theExistingIndex > 0 then
    _ThrowError kErrObjectNameTaken, "relationship '" & pName & "' already exists"
  end if

  put pName into theA["name"]
  put "1-n" into theA["type"] ## default value
  repeat for each item theProp in "owner,left table,right table,cross-reference table,joins,order by"
    put empty into theA[theProp]
  end repeat

  ## Find next index.
  put _NextIndexForTableObjectsSubKey(pDBKey, "relationships") into theNextIndex

  ## Store it
  put theA into sDbsA[pDBKey]["table objects"]["relationships"][theNextIndex]

  ## Return reference
  put empty into theA
  put kRelationshipReference into theA["type"]
  put pDBKey into theA["database"]
  put theNextIndex into theA["index"]

  if theError is not empty then
    return theError for error
  else
    return theA for value
  end if
end tblrelation_createObject


/**
Summary: Deletes a relationship object.

Parameters:
pRelationA: Relationship Reference array or relationship name.
pDBKey: Database Object relationship is associated with. Default is name returned by `sqlyoga_getDefaultDatabase()`. Only applicable if pRelationA is not a reference array.

Returns: empty
*/
command tblrelation_deleteObject pRelationA
  local theProp, theTable

  put _CreateRelationshipArray(pRelationA, param(2)) into pRelationA

  ## Delete lookups in associated tables
  repeat for each item theProp in "left table,right table,cross-reference table"
    put sDbsA[ pRelationA["database"] ]["table objects"]["relationships"][ pRelationA["index"] ][theProp] into theTable
    delete local sDbsA[ pRelationA["database"] ]["table objects"]["tables"][theTable]["relationships lookup"][ pRelationA["index"] ]
  end repeat

  ## Delete relationship
  delete local sDbsA[ pRelationA["database"] ]["table objects"]["relationships"][ pRelationA["index"] ]

  return empty
end tblrelation_deleteObject


/**
Summary: Retrieves a property of a Relationship Object.

Parameters:
pRelationA: Relationship name.
pProp: Property to retrieve.
pDBKey: Database Object relationship is associated with. Default is name returned by `sqlyoga_getDefaultDatabase()`. Only applicable if pRelationA is not a reference array.

Description:
| Property | Description |
| -------- |:----------- |
| `connection` | |
| `cross-reference table` | The name of the table that connects the left and right tables in a `n-n` (`many-to-many`) relationship. |
| `cross-reference table key for left table` | A comma delimited list of field(s) used as the key that connects the cross-reference table to the left table. You can pass in a hard coded value using the format `COL=VALUE`, escaping and quoting VALUES as needed. |
| `cross-reference table key for left table without values` | Returns the keys used for to link the cross-reference table to the left table with any hard coded column values stripped. |
| `cross-reference table key for right table` | A comma delimited list of field(s) used as the key that connects the cross-reference table to the right table. You can pass in a hard coded value using the format `COL=VALUE`, escaping and quoting VALUES as needed. |
| `cross-reference table key for right table without values` | Returns the keys used for to link the cross-reference table to the right table with any hard coded column values stripped. |
| `database` | The name of the database the Relationship object is associated with. |
| `left table key` | A comma delimited list of field(s) used as the key in the left table. |
| `left table key` | A comma delimited list of field(s) used as the key in the left table. |
| `left table key without values` | Returns the keys used for the left table with any hard coded column values stripped. |
| `right table key without values` | Returns the keys used for the right table with any hard coded column values stripped. |
| `name` | The name of the Relationship object. |
| `order by` | The column to sort the records in the relationship by when they are retrieved from the database. |
| `owner` | |
| `right table` | The name of the right table in the relationship. This can also be thought of as the child table. |
| `right table key` | A comma delimited list of field(s) used as the key in the right table. |
| `type` | Type of relationship. `n-n` (`many-to-many`), `1-n` (`one-to-many`) or `1-1` (`one-to-one`). |

Returns: value
*/
function tblrelation_get pRelationA, pProp, pDBKey
  local theKeyA

  put _CreateRelationshipArray(pRelationA, pDBKey) into pRelationA
  put _KeyArrayForRelationship(pRelationA) into theKeyA

  switch pProp
    case "database"
      return pRelationA["database"]
      break

    case "connection"
      local theConnA

      put empty into theConnA
      if pRelationA["connection"] is not empty then
        _ValidateConnectionExistence pRelationA["database"], pRelationA["connection"]
        put kConnectionReference into theConnA["type"]
        put pRelationA["database"] into theConnA["database"]
        put pRelationA["connection"] into theConnA["name"]
      end if
      return theConnA
      break

    case "left table"
    case "right table"
    case "cross-reference table"
    case "update action"
    case "delete action"
      return sDbsA[ theKeyA ][pProp]
      break

    case "left table key"
    case "right table key"
    case "cross-reference table key for left table"
    case "cross-reference table key for right table"
      --
    case "left table key without values"
    case "right table key without values"
    case "cross-reference table key for left table without values"
    case "cross-reference table key for right table without values"
      local theTable, includeTheValues, theTableOffset
      local theJoinType, theJoinKey, theJoinsA, theJoinIndex
      local theTableA

      put sDbsA[ theKeyA ][word 1 to 2 of pProp] into theTable
      put word -2 to -1 of pProp is not "without values" into includeTheValues
      if includeTheValues then
        put 2 into theTableOffset
      else
        put 4 into theTableOffset
      end if

      ## field|field=value,...
      if sDbsA[ theKeyA ]["type"] is among the items of "n-n,many-to-many" then
        if word 1 of pProp is "left" then
          put "left to cross-reference" into theJoinType
          put "left" into theJoinKey
        else if word 1 of pProp is "right" then
          put "right to cross-reference" into theJoinType
          put "right" into theJoinKey
        else
          if word -theTableOffset of pProp is "left" then
            put "left to cross-reference" into theJoinType
            put "cross-reference" into theJoinKey
          else
            put "right to cross-reference" into theJoinType
            put "cross-reference" into theJoinKey
          end if
        end if
      else
        if word 1 of pProp is "cross-reference" then _ThrowError kErrInvalidProperty, "invalid property '" & pProp & "' for relationship type '" & sDbsA[ theKeyA ]["type"] & "'"
        put "left to right" into theJoinType
        put word 1 of pProp into theJoinKey
      end if

      put sDbsA[ theKeyA ]["joins"][theJoinType] into theJoinsA

      ## For alias tables we first add the field=value join before processing
      if tableobjects_tableExists(theTable, pRelationA["database"]) then
        put tableobjects_getTable( theTable , pRelationA["database"]) into theTableA

        if tableobj_get(theTableA, "type") is "alias" then
          local theRealTableA, theSchemaTableKeyA, theConditions, theField

          put the number of elements of theJoinsA into theJoinIndex
          put tableobj_get(theTableA, "alias for table") into theTable
          put pRelationA["database"] into theRealTableA["database"]
          put theTable into theRealTableA["name"]
          put _KeyArrayForSchemaTable(theRealTableA) into theSchemaTableKeyA
          put tableobj_get(theTableA, "conditions") into theConditions
          repeat for each line theEntry in theConditions
            add 1 to theJoinIndex
            put theEntry into theField
            split theField by "="

            ## we could have empty entries that are opposite entries of a field=value key
            if theField[1] is not among the keys of sDbsA[ theSchemaTableKeyA ]["fields"] then
              _ThrowError kErrCantFindObject, "field '" & theField[1] & "' was not found in table '" & theTable & "'" -- & cr & the executioncontexts
            end if

            put theField[1] into theJoinsA[theJoinIndex][theJoinKey]["field"]
            put theField[2] into theJoinsA[theJoinIndex][theJoinKey]["value"]
          end repeat
        end if
      end if

      ## Now loop through joins and do the dirty work
      local theFieldName, theFields

      repeat with i = 1 to the number of elements of theJoinsA
        put theJoinsA[i][theJoinKey]["field"] into theFieldName
        if theFieldName is not empty then
          ## todo: maybe throw an error if index isn't found?
          put theFieldName after theFields

          if includeTheValues and theJoinsA[i][theJoinKey]["value"] is not empty then
            put "=" & theJoinsA[i][theJoinKey]["value"] after theFields
          end if
        end if
        put comma after theFields
      end repeat

      delete the last char of theFields
      return theFields
      break

    default
      if pProp is among the keys of sDbsA[ theKeyA ] then
        ## todo: update to fixed list so we can add properties in the future
        return sDbsA[ theKeyA ][pProp]
      else
        _ThrowError kErrInvalidProperty, "invalid relation property '" & pProp & "' for " & param(0)
      end if
      break
  end switch
end tblrelation_get


/**
Summary: Sets a property of a Relationship Object.

Parameters:
pRelationA: Relationship Reference array or relationship name.
pProp: Property to retrieve.
pValue: Value to set property to.
pDBKey: Database Object relationship is associated with. Default is name returned by `sqlyoga_getDefaultDatabase()`. Only applicable if pRelationA is not a reference array.

Description:
| Property | Description |
| -------- |:----------- |
| `cross-reference table` | The name of the table that connects the left and right tables in a `n-n` (`many-to-many`) relationship. |
| `cross-reference table key for left table` | A comma delimited list of field(s) used as the key that connects the cross-reference table to the left table. You can pass in a hard coded value using the format `COL=VALUE`, escaping and quoting `VALUES` as needed. |
| `cross-reference table key for right table` | A comma delimited list of field(s) used as the key that connects the cross-reference table to the right table. You can pass in a hard coded value using the format `COL=VALUE`, escaping and quoting `VALUES` as needed. |
| `left table` | The name of the left table in the relationship. This can also be thought of as the parent table. |
| `left table key` | A comma delimited list of field(s) used as the key in the left table. |
| `name` | The name of the Relationship object. |
| `order by` | The column to sort the records in the relationship by when they are retrieved from the database. |
| `owner` | |
| `right table` | The name of the right table in the relationship. This can also be thought of as the child table. |
| `right table key` | A comma delimited list of field(s) used as the key in the right table. |
| `type` | Type of relationship. `1-n` (`one-to-many`), `1-1` (`one-to-one`) or `n-n` (`many-to-many`). |

Returns: empty
*/
command tblrelation_set pRelationA, pProp, pValue, pDBKey
  local theKeyA

  put _CreateRelationshipArray(pRelationA, pDBKey) into pRelationA
  put _KeyArrayForRelationship(pRelationA) into theKeyA

  ## Set
  switch pProp
    case "type"
      if pValue is not among the items of "one-to-many,1-n,one-to-one,1-1,many-to-many,n-n" then \
            _ThrowError kErrInvalidProperty, "invalid relationship type '" & pValue & "'"

      ## Reset joins if no longer valid
      if sDbsA[ theKeyA ]["type"] is not empty and \
            ( (sDbsA[ theKeyA ]["type"] is among the items of "n-n,many-to-many" and pValue is not among the items of "n-n,many-to-many") or \
            (pValue is among the items of "n-n,many-to-many" and sDbsA[ theKeyA ]["type"] is not among the items of "n-n,many-to-many") ) then
        put empty into sDbsA[ theKeyA ]["joins"]
      end if

      put pValue into sDbsA[ theKeyA ]["type"]

      ## Enforce ownership rules
      switch pValue
        case "one-to-many"
        case "1-n"
          put "left" into sDbsA[ theKeyA ]["owner"]
          break
        case "many-to-many"
        case "n-n"
          put "none" into sDbsA[ theKeyA ]["owner"]
          break
      end switch
      break

    case "owner"
      if pValue is not among the items of "left,none,right" then _ThrowError kErrInvalidProperty, "invalid owner type '" & pValue & "'"
      if (pValue is not "left" and sDbsA[ theKeyA ]["type"] is among the items of "1-n,one-to-many") \
            or (pValue is not "none" and sDbsA[ theKeyA ]["type"] is among the items of "n-n,many-to-many") then
        _ThrowError kErrInvalidProperty, "invalid owner '" & pValue & "' for relationship type '" & sDbsA[ theKeyA ]["type"] & "'"
      end if
      put pValue into sDbsA[ theKeyA ]["owner"]
      break

    case "left table"
    case "right table"
    case "cross-reference table"
      local theRelationProp

      ## is table already linked to other property?
      put sDbsA[ pRelationA["database"] ]["table objects"]["tables"][pValue]["relationships lookup"][ pRelationA["index"] ] into theRelationProp
      if theRelationProp is pProp then
        ## nothing to do, already linked
      else
        _ResetRelationProperty pRelationA, pProp

        if theRelationProp is not empty then
          ## linked to other property. Remove old property.
          _ResetRelationProperty pRelationA, theRelationProp
        end if

        ## Store in relationship
        put pValue into sDbsA[ theKeyA ][pProp]

        ## Store table index
        put pProp into sDbsA[ pRelationA["database"] ]["table objects"]["tables"][pValue]["relationships lookup"][ pRelationA["index"] ]
      end if
      break

    case "left table key"
    case "right table key"
    case "cross-reference table key for left table"
    case "cross-reference table key for right table"
      if sDbsA[ theKeyA ]["type"] is not among the items of "n-n,many-to-many" and \
            word 1 of pProp is "cross-reference" then _ThrowError kErrInvalidProperty, "invalid property '" & pProp & "' for relationship type '" & sDbsA[ theKeyA ]["type"] & "'"

      local theTable, theFieldNames, theIndex, theFieldIndex, theFieldName

      put sDbsA[ theKeyA ][word 1 to 2 of pProp] into theTable
      if theTable is empty then _ThrowError kErrInvalidProperty, "cannot set key field names before setting the table"

      ## Resolve table aliases
      if sDbsA[ pRelationA["database"] ]["table objects"]["tables"][theTable]["type"] is "alias" then
        put sDbsA[ pRelationA["database"] ]["table objects"]["tables"][theTable]["alias for table"] into theTable
      end if

      ## Lookup field indexes
      put pValue into theFieldNames
      put empty into pValue
      put 0 into theIndex
      repeat for each item theFieldEntry in theFieldNames
        add 1 to theIndex
        put empty into theFieldIndex
        put theFieldEntry into theFieldName
        split theFieldName by "=" ## [1] is field name, [2] is field value

        ## Note: we could have empty entries that are opposite entries of a field=value key

        put theFieldName[1] into pValue[theIndex]["field"]
        put theFieldName[2] into pValue[theIndex]["value"] ## this is only used for things like single table inheritance
      end repeat

      ## Insert into proper join property
      repeat with i = 1 to theIndex
        if word 1 of pProp is "cross-reference" then
          if word -2 of pProp is "left" then
            put pValue[i] into sDBsA[ theKeyA ]["joins"]["left to cross-reference"][i]["cross-reference"]
          else
            put pValue[i] into sDBsA[ theKeyA ]["joins"]["right to cross-reference"][i]["cross-reference"]
          end if
        else
          if sDbsA[ theKeyA ]["type"] is among the items of "n-n,many-to-many" then
            if word 1 of pProp is "left" then
              put pValue[i] into sDBsA[ theKeyA ]["joins"]["left to cross-reference"][i]["left"]
            else
              put pValue[i] into sDBsA[ theKeyA ]["joins"]["right to cross-reference"][i]["right"]
            end if
          else
            put pValue[i] into sDBsA[ theKeyA ]["joins"]["left to right"][i][word 1 of pProp]
          end if
        end if
      end repeat
      break

    case "delete action"
    case "update action"
      put pValue into sDbsA[ theKeyA ][pProp]
      break

    default
      ## Note: You set "fields" as an array already prepped. Indexed 1 to N
      if pProp is among the keys of sDbsA[ theKeyA ] then
        ## todo: update to fixed list so we can add properties in the future
        put pValue into sDbsA[ theKeyA ][pProp]
      else
        _ThrowError kErrInvalidProperty, "invalid relationship property '" & pProp & "' for " & param(0)
      end if
      break
  end switch

  return empty
end tblrelation_set


--> Object: Schema


command dbschema_set pPropPathA, pValue, pDBKey
  _ValidateKey pDBKey

  if pPropPathA is an array then
    put pValue into sDbsA[pDBKey]["schema"][pPropPathA]
  else
    if pPropPathA is empty then
      put pValue into sDbsA[pDBKey]["schema"]
    else
      put pValue into sDbsA[pDBKey]["schema"][pPropPathA]
    end if
  end if
  return empty
end dbschema_set


/**
Summary: Returns info on a Database Objects internal database schema represenation.

pProp: Property to retrieve.
pDBKey: Database Object schema is associated with. Default is name returned by `sqlyoga_getDefaultDatabase()`.

Description:

| Property | Description |
| -------- |:----------- |
| `tables` | Returns a return delimited list of tables in SQL Yoga's internal representation of the database schema. |
| `tables array` | Returns the array used to SQL Yoga's internal representation of the database schema. |

Returns: array
*/
function dbschema_get pProp, pDBKey
  local theA, theKey, theIndex
  local theKeys, theReference

  _ValidateKey pDBKey

  switch pProp
    case ""
      return sDbsA[pDBKey]["schema"]
    case "tables" -- "table names"
      put the keys of sDbsA[pDBKey]["schema"]["tables"] into theKeys
      sort lines of theKeys ascending
      return theKeys
      break

    case "tables array"
      return sDbsA[pDBKey]["schema"]["tables"]
      break

    case "yaml"
      return _outputKeyAsYAML(sDbsA[pDBKey], "schema", 1)
      break

    case "version"
      return sDbsA[pDBKey]["schema"]["version"]

    default
      ## Todo: need actual list to compare against in case we add valid props later on
      if pProp is not among the keys of sDbsA[pDBKey]["schema"] then
        _ThrowError kErrInvalidProperty, "invalid property passed to " & param(0) && ":" && pProp
      else
        return sDbsA[pDBKey]["schema"][pProp]
      end if
  end switch
end dbschema_get


/**
Summary: Clears the internal database schema representation for a Database Object.

Parameters:
pDBKey: Database Object schema is associated with. Default is name returned by `sqlyoga_getDefaultDatabase()`.

Description:
When SQL Yoga connects to a database it checks to see if the internal database
schema represenation has been created. If it hasn't then it is. You can reset the
schema in order to have SQL Yoga regenerate it the next time a connection is made.

Returns: empty
*/
command dbschema_reset pDBKey
  _ValidateKey pDBKey

  put empty into sDbsA[pDBKey]["schema"]["tables"]
  return empty
end dbschema_reset


## undocumented. Used by schema sync.
command dbschema_addTableDefinition pName, pTableA, pDBKey
  local theError

  _ValidateKey pDBKey

  if pName is among the keys of sDbsA[pDBKey]["schema"]["tables"] \
        and the keys of sDbsA[pDBKey]["schema"]["tables"][pName] is not empty then
    put "table '" & pName & "' already exists in database object '" & pDBKey & "'" into theError
  else
    put pTableA into sDbsA[pDBKey]["schema"]["tables"][pName]
  end if

  return theError
end dbschema_addTableDefinition


## undocumented. Used when creating tables.
command dbschema_storeForeignKeys pTableName, pForeignKeysA, pDBKey

end dbschema_storeForeignKeys


/**
Summary: Retreives the array that represents a table in the internal database schema .

Parameters:
pTable: The name of the table
pDBKey: Database Object schema is associated with. Default is name returned by `sqlyoga_getDefaultDatabase()`.

Returns: Array
*/
function dbschema_tableGet pTable, pProperty, pDBKey
  _ValidateKey pDBKey

  if pTable is not among the keys of sDbsA[pDBKey]["schema"]["tables"] then
    _ThrowError kErrCantFindObject, "table '" & pTable & "' is not in the schema '" & pDBKey & "'"
  else
    switch pProperty
      case ""
        return sDbsA[pDBKey]["schema"]["tables"][pTable]
      case "fields"
        local tFields
        put sDbsA[pDBKey]["schema"]["tables"][pTable]["field order"] into tFields
        replace comma with cr in tFields
        return tFields
    end switch
  end if
end dbschema_tableGet


command dbschema_tableSet pTable, pProperty, pValue, pDBKey
  _ValidateKey pDBKey

  if pTable is not among the keys of sDbsA[pDBKey]["schema"]["tables"] then
    _ThrowError kErrCantFindObject, "table '" & pTable & "' is not in the schema '" & pDBKey & "'"
  else
    switch pProperty
      case ""
        put pValue into sDbsA[pDBKey]["schema"]["tables"][pTable]
        break
      default
        put pValue into sDbsA[pDBKey]["schema"]["tables"][pTable][pProperty]
        break
    end switch
  end if
end dbschema_tableSet


/**
Summary: Returns true if the table exists in the internal database schema.

Parameters:
pTable: The name of the table
pDBKey: Database Object schema is associated with. Default is name returned by `sqlyoga_getDefaultDatabase()`.

Returns: List (CR delimited)
*/
function dbschema_tableExists pTable, pDBKey
  _ValidateKey pDBKey

  return pTable is among the keys of sDbsA[pDBKey]["schema"]["tables"]
end dbschema_tableExists


--> Object: Table Index


private function _KeyArrayForIndex pIndexA
  local theKeyA

  put pIndexA["database"] into theKeyA[1]
  put "schema" into theKeyA[2]
  put "tables" into theKeyA[3]
  put pIndexA["table"] into theKeyA[4]
  put "indexes" into theKeyA[5]
  put pIndexA["index"] into theKeyA[6]
  return theKeyA
end _KeyArrayForIndex


command dbindex_create pTableA, pName
  -----
  local theA, theNextIndex
  local theError
  local theProp
  -----
  put _CreateTableArray(pTableA, param(3)) into pTableA

  put pName into theA["name"]
  repeat for each item theProp in "fields"
    put empty into theA[theProp]
  end repeat

  put "simple" into theA["style"]["meta"]
  put empty into theA["type"]["meta"]

  ## Find next array index.
  put _NextIndexForTableSubKey(pTableA["database"], pTableA["index"], "indexes") into theNextIndex

  ## Store index
  put theA into sDbsA[ pTableA["database"] ]["schema"]["tables"][ pTableA["index"] ]["indexes"][theNextIndex]

  ## Return reference
  put empty into theA
  put kIndexReference into theA["type"]
  put pTableA["database"] into theA["database"]
  put pTableA["index"] into theA["table"]
  put theNextIndex into theA["index"]

  if theError is not empty then
    return theError for error
  else
    return theA for value
  end if
end dbindex_create


command dbindex_delete pIndexA
  local theKeyA

  _ValidateIndexArray pIndexA

  put _KeyArrayForIndex(pIndexA) into theKeyA

  ## Delete index
  delete local sDbsA[ theKeyA ]

  return empty
end dbindex_delete


function dbindex_get pIndexA, pProp
  local theKeyA

  _ValidateIndexArray pIndexA

  put _KeyArrayForIndex(pIndexA) into theKeyA

  if the number of words of pProp is 2 and the last word of pProp is among the items of "style,type" then
    ## sqlite style, mysql type, etc.
    return sDbsA[ theKeyA ][ word 2 of pProp ][ word 1 of pProp ]
  else
    switch pProp
      case "database"
        return pIndexA["database"]
        break
      case "type"
      case "style"
        return sDbsA[ theKeyA ][pProp]["meta"]
        break

      case "fields"
        return sDbsA[ theKeyA ]["fields"]
        break

      default
        if pProp is among the keys of sDbsA[ theKeyA ] then
          ## todo: update to fixed list so we can add properties in the future
          return sDbsA[ theKeyA ][pProp]
        else
          _ThrowError kErrInvalidProperty, "invalid index property '" & pProp & "' for " & param(0)
        end if
        break
    end switch
  end if
end dbindex_get


command dbindex_set pIndexA, pProp, pValue
  -----
  local theKeyA
  -----
  _ValidateIndexArray pIndexA
  put _KeyArrayForIndex(pIndexA) into theKeyA

  ## Set
  if the number of words of pProp is 2 and the last word of pProp is among the items of "style,type" then
    ## sqlite style, mysql type, etc.
    put pValue into sDbsA[ theKeyA ][ word 2 of pProp ][ word 1 of pProp ]
  else
    switch pProp
      case "type"
        put pValue into sDbsA[ theKeyA ][pProp]["meta"]
        break
      case "style"
        if pValue is not among the items of "unique,simple,fulltext,spatial" then _ThrowError kErrInvalidProperty, "invalid value '" & pValue & "' for style"
        put pValue into sDbsA[ theKeyA ][pProp]["meta"]
        break

      default
        ## Note: You set "fields" as an array already prepped. Indexed 1 to N
        if pProp is among the keys of sDbsA[ theKeyA ] then
          ## todo: update to fixed list so we can add properties in the future
          put pValue into sDbsA[ theKeyA ][pProp]
        else
          _ThrowError kErrInvalidProperty, "invalid index property '" & pProp & "' for " & param(0)
        end if
        break
    end switch
  end if
end dbindex_set


--> Object: Query Templates


private function _KeyArrayForTemplate pTemplateA
  local theKeyA

  put pTemplateA["database"] into theKeyA[1]
  put "query templates" into theKeyA[2]
  put pTemplateA["name"] into theKeyA[3]
  return theKeyA
end _KeyArrayForTemplate


## Resets any query templates with this table assigned.
## Erases entire table join if table is part of the 'related table joins'.
private command _DeleteTableReferencesInQueryTemplates pKey, pTable
  -----
  local theKey
  local theFoundKey
  -----
  repeat for each key theKey in sDbsA[pKey]["query templates"]
    if pTable is sDbsA[pKey]["query templates"][theKey]["table"]["name"] then
      ## get rid of the whole thing
      sqlquerytmpl_delete theKey
    else
      ## See if we should at least delete join
      put _FindTableInQueryJoins(sDbsA[pKey]["query templates"][theKey]["related table joins"], pTable) into theFoundKey
      if theFoundKey is an array then
        put empty into sDbsA[pKey]["query templates"][theKey]["related table joins"]
      end if
    end if
  end repeat

  return empty
end _DeleteTableReferencesInQueryTemplates


/**
Summary: Creates a SQL Query Template.

Parameters:
pName: The name of the SQL Query Template.
pDBKey: Database Object SQL Query Template is associated with. Default is name returned by `sqlyoga_getDefaultDatabase()`.

Description:
A SQL Query Template allows you to preconfigure settings that can be used to create new SQL Query Objects.


Returns:
it: SQL Query Template reference array
the result: Error message
*/
command sqlquerytmpl_createObject pName, pDBKey
  -----
  local theA
  local theError
  local theProp
  -----
  _ValidateKey pDBKey

  if pName is among the keys of sDbsA[pDBKey]["query templates"] then
    put "query template '" & pName & "' already exists in database object '" & pDBKey & "'" into theError
  else
    repeat for each item theProp in sSQLQuerySetProps
      put empty into theA[theProp]
    end repeat
    put pName into theA["name"]
    put false into theA["report null"]

    ## Store it
    put theA into sDbsA[pDBKey]["query templates"][pName]

    ## Return reference
    put empty into theA
    put kQueryTemplateReference into theA["type"]
    put pDBKey into theA["database"]
    put pName into theA["name"]
  end if

  if theError is not empty then
    return theError for error
  else
    return theA for value
  end if
end sqlquerytmpl_createObject


/**
Summary: Deletes a SQL Query Template.

Parameters:
pName: The name of the SQL Query Template or a SQL Query Template reference array.
pDBKey: Database Object SQL Query Template is associated with. Default is name returned by `sqlyoga_getDefaultDatabase()`.

Returns: empty
*/
command sqlquerytmpl_deleteObject pTemplateA, pDBKey
  local theKeyA

  put _CreateQueryTemplateArray(pTemplateA, pDBKey) into pTemplateA
  put _KeyArrayForTemplate(pTemplateA) into theKeyA

  ## Delete template
  delete local sDbsA[ pTemplateA["database"] ]["query templates"][ pTemplateA["name"] ]

  return empty
end sqlquerytmpl_deleteObject


/**
Summary: Retrieves a property for a SQL Query Template.

Parameters:
TemplateA: Name of SQL Query Template or SQL Query Template reference array.
pProp: Property to get value for.
pDBKey:

Description:
| Property | Description |
| -------- |:----------- |
| `column delimiter` | |
| `conditions` | |
| `database` | |
| `distinct` | |
| `from clause` | |
| `full column names` | |
| `group by` | |
| `join clause` | |
| `order by` | |
| `query` | |
| `[related table] joins` | |
| `report null` | |
| `row delimiter` | |
| `select clause` | |
| `table` | |
| `table as` | |
| `where clause` | |

*Note:* You must create a Connection in your Database object before calling this function.

Returns: value
*/
function sqlquerytmpl_get pTemplateA, pProp, pDBKey
  -----
  local theConnName, theQueryA
  local theKeyA
  -----
  ## Create from
  put _CreateQueryTemplateArray(pTemplateA, pDBKey) into pTemplateA
  put _KeyArrayForTemplate(pTemplateA) into theKeyA
  put dbobject_get("default connection", pTemplateA["database"]) into theConnName

  put sDbsA[ theKeyA ] into theQueryA
  put kQueryReference into theQueryA["type"]
  put pTemplateA["database"] into theQueryA["database"]
  put theConnName into theQueryA["connection"]
  put 0 into theQueryA["cursor id"]

  return sqlquery_get(theQueryA, pProp)
end sqlquerytmpl_get


/**
Summary: Sets a SQL Query Template property.

Parameters:
TemplateA: Name of SQL Query Template or SQL Query Template reference array.
pProp: Property to get value for.

Description:
| Property | Description |
| -------- |:----------- |
| `column delimiter` | |
| `conditions` | |
| `distinct` | |
| `full column names` | |
| `group by` | |
| `order by` | |
| `[related table] joins` | |
| `report null` | |
| `row delimiter` | |
| `select clause` | |
| `table` | |
| `table as` | |

Returns: value
*/
command sqlquerytmpl_set pTemplateA, pProp, pValue
  -----
  local theAs
  local theFieldsA
  local theKeyA
  local theOrigValue
  local theRootTableA
  local theTemplateTableIndexes
  -----
  put _CreateQueryTemplateArray(pTemplateA, param(4)) into pTemplateA
  put _KeyArrayForTemplate(pTemplateA) into theKeyA

  ## Prep
  switch pProp
    case "sort by"
      put "order by" into pProp ## alias since Rev uses 'sort'
      break
  end switch

  ## Set
  switch pProp
    case "select clause"
      ## Used to parse and segment out fields.
      ## Why though? Hierarchal converters determine table fields
      ## on the fly for us.
      put pValue into sDbsA[ theKeyA ][pProp]
      break

    case "related table joins"
    case "joins"
      put empty into sDbsA[ theKeyA ]["related tables order by"] ## private property built when we create join clause. Uses relationships 'order by'

      ## If " ON " is in statement then don't perform automatic lookups
      if not (pValue contains " ON ") then
        ## If the user has defined table object for root table then
        ## separate into joins. Otherwise just use the raw string.
        if tableobjects_tableExists(sDbsA[ theKeyA ]["table"]["name"], pTemplateA["database"]) then
          put tableobjects_getTable(sDbsA[ theKeyA ]["table"]["name"], pTemplateA["database"]) into theRootTableA
          if sDbsA[ theKeyA ]["table"]["name"] is empty then _ThrowError kErrInvalidProperty, "you must set the table property before you can set related table joins in " & param(0)

          ## Can pass in a string i.e. LEFT OUTER JOIN steps, tlk_lessons_servers
          ## In this case we parse string, lookup relationship and create JOINS array
          if pValue is not an array then put _StringToJoins(theRootTableA, pValue) into pValue
          _VerifyTableJoins theRootTableA, pValue
        end if
      end if
      put pValue into sDbsA[ theKeyA ][pProp]
      break

    case "table"
      local theCharNo

      put offset(" as ", pValue) into theCharNo
      if theCharNo > 0 then
        put char (theCharNo + 4) to -1 of pValue into theAs
        put char 1 to (theCharNo - 1) of pValue into pValue
      end if

      ## We just reset everything if changing
      if pValue is not sDbsA[ theKeyA ]["table"]["name"] then
        put empty into sDbsA[ theKeyA ]["select clause"]
        put empty into sDbsA[ theKeyA ]["related table joins"]
        put empty into sDbsA[ theKeyA ]["group by"]
        put empty into sDbsA[ theKeyA ]["having"]
        put empty into sDbsA[ theKeyA ]["conditions"]
      end if

      if theAs is not empty then put theAs into sDbsA[ theKeyA ]["table"]["as"]
      put pValue into sDbsA[ theKeyA ]["table"]["name"]

      break

    case "table as"
      put pValue into sDbsA[ theKeyA ]["table"]["as"]
      break

    case "conditions"
      ## Translate any english into SQL
      put _TranslateConditions(pValue) into sDbsA[ theKeyA ]["conditions"]["sql"]

      ## Cache original user setting
      put pValue into sDbsA[ theKeyA ]["conditions"]["human"]
      break

    case "distinct"
      put pValue is true into sDbsA[ theKeyA ][pProp]
      break

    case "full column names" # deprecated - see `column names length`
      ## 1.0.1 change.
      if pValue is true then put "long" into sDbsA[ theKeyA ]["column names length"]
      else put "default" into sDbsA[ theKeyA ]["column names length"]
      break

    case "column names length"
      if pValue is "full" then put "long" into pValue
      if pValue is among the items of "long,short,default" then
        put pValue into sDbsA[ theKeyA ][pProp]
      else
        _ThrowError kErrInvalidProperty, "column names length must be long, short or default in " & param(0)
      end if
      break

    default
      if pProp is among the keys of sDbsA[ theKeyA ] then
        put pValue into sDbsA[ theKeyA ][pProp]  ## update prop we are targeting
      else
        _ThrowError kErrInvalidProperty, "invalid query property '" & pProp & "'"
      end if
  end switch

  return empty
end sqlquerytmpl_set


--> Object: SQL Queries


/**
Summary: Creates a SQL Query Object from a SQL Query Template or a table.

Parameters:
pTemplateOrTableName: The name of a SQL Query Template or table in your database.
pConnName: Name of the connection to attach the SQL Record to. Default is the default connection for the database object.
pDBKey: The name of the database object to attach the SQL Record object to. Default is name returned by `sqlyoga_getDefaultDatabase()`.

Description:
The returned array represents the SQL query. You should not modify this array yourself but rather use
the SQL Query Object API to get and set properties.

Returns: SQL Query Object array
*/
function sqlquery_createObject pTemplateOrTableName, pConnName, pDBKey
  -----
  local theKey, theConnectionA
  local theProp
  local theQueryA
  -----
  put _CreateConnectionArray(pConnName, pDBKey) into theConnectionA

  put theConnectionA["database"] into theKey
  if pTemplateOrTableName is among the keys of sDbsA[theKey]["query templates"] then
    put sDbsA[theKey]["query templates"][pTemplateOrTableName] into theQueryA

    put kQueryReference into theQueryA["type"]
    put theConnectionA["database"] into theQueryA["database"]
    put theConnectionA["name"] into theQueryA["connection"]
    put 0 into theQueryA["cursor id"]

    return theQueryA
  else if pTemplateOrTableName is among the keys of sDbsA[theKey]["table objects"]["tables"] or \
        pTemplateOrTableName is among the keys of sDbsA[theKey]["schema"]["tables"] then
    return _CreateSQLQueryFromTable(theConnectionA, pTemplateOrTableName)
  else
    _ThrowError kErrCantFindObject, "no table or sql query template exists with that name:" && pTemplateOrTableName
  end if
end sqlquery_createObject


private function _CreateSQLQueryFromTable pConnectionA, pTable
  -----
  local theProp, theA
  local theQueryA
  -----
  if pTable is not among the keys of sDbsA[ pConnectionA["database"] ]["schema"]["tables"] then
    _ValidateTableExistence pConnectionA["database"], pTable
  end if

  repeat for each item theProp in sSQLQuerySetProps
    put empty into theQueryA[theProp]
  end repeat
  put pTable into theQueryA["table"]["name"]
  put false into theA["report null"]
  put "default" into theQueryA["column names length"]

  put kQueryReference into theQueryA["type"]
  put pConnectionA["database"] into theQueryA["database"]
  put pConnectionA["name"] into theQueryA["connection"]
  put 0 into theQueryA["cursor id"]

  return theQueryA
end _CreateSQLQueryFromTable


/**
Summary: Sets properties on a SQL Query Object array.

xQueryA: A SQL Query Object array as created using `sqlquery_createObject()`.
pProp: The property to set.
pValue: The value to set the property to.

Description:
| Property | Description |
| -------- |:----------- |
| `column delimiter` | When retrieving a query as data or converting a query cursor to data the column delimiter is used. Default is TAB. |
| `column names length` | Allows you to explicitly select just column name (`short`), the table and column name (`long`) or the default behavior. The setting only applies to columns that SQL Yoga generates the SQL for. If you manually set the "select clause" property of the query object this setting will only affect any entries entered as `TABLE_NAME.*`. |
| `conditions` | A string representing the search conditions for the SQL query. You can use english or SQL operators. You can also use binding variables with the one caveat being that you need to put single quotes around the binding variables if you are using a string. This is necessary as some conditions in SQL WHERE statements can break if wrapped in single quotes. A condition using english operators would look something like this: <br /><br /> `lesson.name contains ':1' AND lesson.description contains ':2' AND lesson.id is in :3` <br /><br /> If you are using binding then pass in the binding values as parameters 4 - n, where n = the number of binding variables you use in your conditions string. Support english operators are:<br /><br />`IS`, `IS NOT`, `IS GREATER THAN`, `IS GREATER THAN OR EQUAL TO`, `IS LESS THAN`, `IS LESS THAN OR EQUAL TO`, `IS IN`, `IS NOT IN`, `IS BETWEEN`, `CONTAINS`, `DOES NOT CONTAIN`, `BEGINS WITH`, `ENDS WITH`, `DOES NOT BEGIN WITH`, `DOES NOT END WITH` |
| `condition bindings` | A numerically indexed array. The value of `[1]` will be used to replace `:1` in the conditions, `[2]` for `:2`, and so on. |
| `connection` | Name of connection to use when querying database. Default is the default connection for the Database Object. |
| `distinct` | Set to `true`/`false` to affect whether a SQL query returns `DISTINCT` results. |
| `find` | Set to `first` to only return the first record in the result. |
| `group by` | Determines how returned rows are grouped. |
| `having` | Used to filter the rows returned using group by. |
| `limit` | The number of rows to limit the result to. Useful for large record sets of which you only want a certain number. Default is empty. |
| `offset` | The number of rows to skip when returning the results. Setting this to 21 would skip records 1 to 20. Default is empty. |
| `order by` | Fields to sort records by. |
| `[related table] joins` | The related tables to include in the results. If you have defined Table Objects and Relationship Objects then you can simply pass in a string like `LEFT JOIN related_table_name`. The string will be parsed and the `ON` portion of the `JOIN` will be included. If you have not defined Relationship Objects for your Table Objects then you must pass in the full join string, i.e. `JOIN related_table_name ON field = field`. |
| `report null` | Set to true to return "NULL" as the column value if a column is NULL. Default is 'false' in which case empty is returned for the column value. |
| `row delimiter` | When retrieving a query as data or converting a query cursor to data the row delimiter is used. Default is `CR`. |
| `select clause` | Fields to retrieve from the database. The default is empty which means all fields for all tables in the query. Use the syntax `TABLE.*` to include all fields for a table. |
| `sort by` | alias for `order by`. |
| `table` | The name of the primary table for the SQL Query Object. You can pass in `TABLE as ALIAS_NAME` to specify an alias for the table in the query. When setting the `table` property the `select clause`, `related table joins`, `group by`, `having` and `conditions` properties are reset. |
| `table as` | The alias to use for the table in the query. |

Returns: empty
*/
command sqlquery_set @xQueryA, pProp, pValue
  _ValidateQueryArray xQueryA

  ## Prep
  put _TranslateSQLQueryProp(pProp) into pProp

  ## Set
  switch pProp
    ## QUERY specific props. Not shared by template
    case "connection"
      put _CreateConnectionArray(pValue, xQueryA["database"]) into pValue
      put pValue["name"] into xQueryA[pProp]
      break

      ## end query specific props

    case "select clause"
      ## Used to parse and segment out fields.
      ## Why though? Hierarchal converters determine table fields
      ## on the fly for us.
      put pValue into xQueryA[pProp]
      break

    case "related table joins"
      put empty into xQueryA["related tables order by"] ## private property built when we create join clause. Uses relationships 'order by'

      ## If " ON " is in statement then don't perform automatic lookups
      if not (pValue contains " ON ") then
        if tableobjects_tableExists(xQueryA["table"]["name"], xQueryA["database"]) then
          local theRootTableA

          put tableobjects_getTable(xQueryA["table"]["name"], xQueryA["database"]) into theRootTableA

          ## If the user has defined table object for root table then
          ## separate into joins.
          if xQueryA["table"]["name"] is empty then _ThrowError kErrInvalidProperty, "you must set the table property before you can set related table joins in " & param(0)

          ## Can pass in a string i.e. LEFT OUTER JOIN steps, tlk_lessons_servers
          ## In this case we parse string, lookup relationship and create JOINS array
          if pValue is not an array then put _StringToJoins(theRootTableA, pValue) into pValue
          _VerifyTableJoins theRootTableA, pValue
        end if
      else
        ## Developer hard coded relationship. No looksup, just do a basic parse.
        put _StringToJoins(empty, pValue) into pValue
      end if
      put pValue into xQueryA[pProp]
      break

      -- case "virtual select clause fields"
      -- put _ParseSelectClause(pValue) into theFieldsA
      -- put theFieldsA into xQueryA["virtual select clause fields"]
      -- break

    case "table"
      local theCharNo, theAs

      put offset(" as ", pValue) into theCharNo
      if theCharNo > 0 then
        put char (theCharNo + 4) to -1 of pValue into theAs
        put char 1 to (theCharNo - 1) of pValue into pValue
      end if

      ## We just reset everything if changing
      if pValue is not xQueryA["table"]["name"] then
        put empty into xQueryA["select clause"]
        put empty into xQueryA["related table joins"]
        put empty into xQueryA["group by"]
        put empty into xQueryA["having"]
        put empty into xQueryA["conditions"]
      end if

      if theAs is not empty then put theAs into xQueryA["table"]["as"]
      put pValue into xQueryA["table"]["name"]

      break

    case "conditions"
      ## Translate any english into SQL
      put _TranslateConditions(pValue) into xQueryA["conditions"]["sql"]

      ## Cache original user setting
      put pValue into xQueryA["conditions"]["human"]

      ## Store any bindings that may have been passed in
      if the paramCount >= 4 then
        local theBindingsA

        if param(4) is not an array then
          repeat with i = 4 to the paramCount
            put param(i) into theBindingsA[i-3]
          end repeat
        else
          put param(4) into theBindingsA
        end if
        put theBindingsA into xQueryA["condition bindings"]
      end if
      break

    case "distinct"
      put pValue is true into xQueryA[pProp]
      break

    case "full column names"
      ## 1.0.1 change.
      if pValue is true then put "long" into xQueryA["column names length"]
      else put "default" into xQueryA["column names length"]
      break

    case "column names length"
      if pValue is "full" then put "long" into pValue
      if pValue is among the items of "long,short,default," then
        put pValue into xQueryA[pProp]
      else
        _ThrowError kErrInvalidProperty, "column names length must be long, short or default in " & param(0)
      end if
      break

    case "limit"
    case "offset"
      if pValue is 0 then put empty into pValue
      if pValue is not empty then
        if not _IsPositiveInteger(pValue)  then
          _ThrowError kErrInvalidInteger, pProp && "must be an integer > 0 or empty"
        end if
      end if
      put pValue into xQueryA[pProp]
      break
    default
      if pProp is among the items of sSQLQuerySetProps then
        put pValue into xQueryA[pProp]  ## update prop we are targeting
      else
        _ThrowError kErrInvalidProperty, "invalid SQL Query object property '" & pProp & "'"
      end if
  end switch

  return empty
end sqlquery_set


private function _TranslateSQLQueryProp pProp
  switch pProp
    case "sort by"
    case "order"
      put "order by" into pProp ## alias since Rev uses 'sort'
      break
    case "joins"
      put "related table joins" into pProp
      break
    case "select"
      put "select clause" into pProp
      break
    case "db type"
      put "database type" into pProp
      break
    case "joins including scopes"
      put "related table joins including scopes" into pProp
      break
    case "group"
      put "group by" into pProp
      break
  end switch

  return pProp
end _TranslateSQLQueryProp


/**
Summary: Retrieves properties of a SQL Query Object array.

xQueryA: A SQL Query Object array as created using `sqlquery_createObject()`.
pProp: The property to get.

Description:
| Property | Description |
| -------- |:----------- |
| `column delimiter` | When retrieving a query as data or converting a query cursor to data the column delimiter is used. Default is TAB. |
| `column names length` | Allows you to explicitly select just column name (`short`), the table and column name (`full`) or the default behavior. |
| `conditions` | A string representing the search conditions for the SQL query. You can use english or SQL operators. You can also use binding. A condition using english operators would look something like this: <br /><br />  `lesson.name contains :1 AND lesson.description contains :2`<br /> <br />If you are using binding then pass in the binding values as parameters 4 - n, where n = the number of binding variables you use in your conditions string. The following english operators are supported: <br /> <br /> `IS`, `IS NOT`, `IS GREATER THAN`, `IS GREATER THAN OR EQUAL TO`, `IS LESS THAN`, `IS LESS THAN OR EQUAL TO`, `IS IN`, `IS NOT IN`, `CONTAINS`, `DOES NOT CONTAIN`, `BEGINS WITH`, `ENDS WITH`, `DOES NOT BEGIN WITH`, `DOES NOT END WITH` |
| `condition bindings` | A numerically indexed array. The value of `[1]` will be used to replace `:1` in the conditions, `[2]` for `:2`, and so on. |
| `connection` | Name of connection to use when querying database. |
| `cursor id` | The id of the RevDB cursor associated with the SQL Query object. This only returns a positive value if you use `sqlquery_retrieve`. |
| `database type` | The type of database that the object's connection points to. |
| `distinct` | Returns `true`/`false`. True means SQL query returns `DISTINCT` results. |
| `find` | Can be set to `first` to only return the first record found. |
| `from clause` | The `FROM` clause of the query. |
| `group by` | Determines how returned rows are grouped. |
| `having` | Used to filter the rows returned using group by. |
| `join clause` | The `JOIN` clause of the query. |
| `number of records` | The number of records in the object's cursor. A cursor is opened using `sqlquery_retrieve`. |
| `limit` | The number of rows to limit the result to. Useful for large record sets of which you only want a certain number. Default is empty. |
| `offset` | The number of rows to skip when returning the results. Setting this to 21 would skip records 1 to 20. Default is empty. |
| `order by` | Fields to sort records by. |
| `query` | The full `SELECT` query for the object. This query is used when opening a cursor or retrieving data. |
| `query is at end` | Returns true if the object's cursor is at the end of available records. A cursor is opened using `sqlquery_retrieve`. |
| `query is at start` | Returns `true` if the object's cursor is at the beginning of available records. A cursor is opened using `sqlquery_retrieve`. |
| `[related table] joins` | The related tables to include in the results. If you have defined Table Objects and Relationship Objects then you can simply pass in a string like `LEFT JOIN related_table_name`. The string will be parsed and the `ON` portion of the `JOIN` will be included. If you have not defined Relationship Objects for your Table Objects then you must pass in the full join string, i.e. `JOIN related_table_name ON field = field`. |
| `row delimiter` | When retrieving a query as data or converting a query cursor to data the row delimiter is used. Default is `CR`. |
| `select clause` | Returns the fields to retrieve from the database. |
| `sort by` | alias for `order by`. |
| `table` | The name of the primary table for the SQL Query Object. |
| `table as` | The alias to use for the table in the query. |
| `tables` | A line delimited list of all tables in the query. |
| `where clause` | The `WHERE` clause of the query. |

Returns: value
*/
function sqlquery_get @xQueryA, pProp
  _ValidateQueryArray xQueryA

  ## Prep
  put _TranslateSQLQueryProp(pProp) into pProp

  ## Work
  switch pProp
    ## START QUERY specific props. Not shared by template
    case "connection"
      return dbobject_getConnection(xQueryA["connection"], xQueryA["database"])
      break

    case "database type"
      local theConnectionA
      put dbobject_getConnection(xQueryA["connection"], xQueryA["database"]) into theConnectionA
      return dbconn_get("type", theConnectionA)
      break

    case "cursor id"
      return max(0, xQueryA["cursor id"])
      break

    case "number of records"
      return revNumberOfRecords(xQueryA["cursor id"])
      break

    case "query is at end"
      return revQueryIsAtEnd(xQueryA["cursor id"])
      break

    case "query is at start"
      return revQueryIsAtStart(xQueryA["cursor id"])
      break

    case "column delimiter"
      if xQueryA["column delimiter"] is empty then return tab
      else return xQueryA["column delimiter"]
      break

    case "row delimiter"
      if xQueryA["row delimiter"] is empty then return cr
      else return xQueryA["row delimiter"]
      break
      ## END QUERY specific props

    case "database"
      return xQueryA["database"]
      break

    case "table"
      return xQueryA["table"]["name"]
      break

    case "table as"
      return xQueryA["table"]["as"]
      break

    case "tables"
      local theJoinsA, theTables, theTablesA

      put sqlquery_get(xQueryA, "related table joins including scopes") into theJoinsA

      ## All tables in query
      put xQueryA["table"]["name"] into theTablesA[1]["name"]
      put xQueryA["table"]["as"] into theTablesA[1]["as"]
      _TablesInQueryJoin theTablesA, theJoinsA

      ## todo: Should we return "AS ..." with this?
      put empty into theTables
      repeat with i = 1 to the number of elements of theTablesA
        put theTablesA[i]["name"] & cr after theTables
      end repeat
      delete the last char of theTables
      return theTables
      break

    case "related table joins including scopes"
    case "joins including scopes"
      local theFilterJoinsA, theProcessedIdsA

      put xQueryA["related table joins"] into theJoinsA

      ## Add in joins for scope
      repeat for each line i in _SortNumericKeys(the keys of xQueryA["scopes"])
        repeat for each line j in _SortNumericKeys(the keys of xQueryA["scopes"][i]["related table joins"])
          put xQueryA["scopes"][i]["related table joins"][j] into theJoinsA[the number of elements of theJoinsA + 1]
        end repeat
      end repeat

      _RemoveDuplicateJoins theJoinsA, theFilterJoinsA, empty, theProcessedIdsA
      return theFilterJoinsA
      break

    case "select clause"
      local appendTheTableName, theConnA, theClause

      ## Get Clause
      put true into appendTheTableName
      put _CreateConnectionArray(xQueryA["connection"], xQueryA["database"]) into theConnA

      if xQueryA["select clause"] is empty then
        put sqlquery_get(xQueryA, "related table joins including scopes") into theJoinsA

        ## Get order of tables to include
        put xQueryA["table"]["name"] into theTablesA[1]["name"]
        put xQueryA["table"]["as"] into theTablesA[1]["as"]
        _TablesInQueryJoin theTablesA, theJoinsA

        put _SelectClauseFromTables(theConnA, theTablesA, appendTheTableName, \
              sqlquery_get(xQueryA, "column names length") ) into theClause
      else
        local theItem, theTable

        ## Look for any tables to expand (table.*)...
        put xQueryA["select clause"] into theClause
        repeat with i = the number of items of theClause down to 1
          put word 1 to -1 of item i of theClause into theItem
          if the last char of theItem is "*" then
            set the itemDelimiter to "."
            if the number of items of theItem > 1 then
              put item 1 of theItem into theTable
              set the itemDelimiter to ","
              if dbschema_tableExists(theTable, xQueryA["database"]) then
                put theTable into theTablesA[1]["name"]
                put _SelectClauseFromTables(theConnA, theTablesA, appendTheTableName, \
                      sqlquery_get(xQueryA, "column names length") ) into item i of theClause
              end if
            else
              set the itemDelimiter to ","
            end if
          end if
        end repeat
      end if
      return theClause
      break

    case "from clause"
      local theQsA, theTableA, theAs

      put empty into theTable
      put dbconn_get("effective quotes", xQueryA["connection"], xQueryA["database"]) into theQsA

      ## Handle alias
      if tableobjects_tableExists(xQueryA["table"]["name"], xQueryA["database"]) then
        put tableobjects_getTable(xQueryA["table"]["name"], xQueryA["database"]) into theTableA
        if tableobj_get(theTableA, "type") is "alias" then
          put tableobj_get(theTableA, "alias for table") into theTable
          put xQueryA["table"]["name"] into theAs
        end if
      end if

      if theTable is empty then
        put xQueryA["table"]["name"] into theTable
        put xQueryA["table"]["as"] into theAs
      end if

      put theQsA["left"] & theTable & theQsA["right"] into theClause
      if theAs is not empty then
        put " AS " & theQsA["left"] & theAs & theQsA["right"] after theClause
      end if
      return theClause
      break

    case "join clause"
      local theRelationshipOrderBy

      put empty into theClause
      -- _JoinClauseFromQueryJoin pClause, pKey, pLeftTableIndex, pLeftTableAs, pJoinsA, theKeyA
      put _CreateConnectionArray(xQueryA["connection"], xQueryA["database"]) into theConnA

      ## Get query joins
      put sqlquery_get(xQueryA, "related table joins including scopes") into theJoinsA

      ## Now create clause. This handler will filter out duplicates.
      put empty into theRelationshipOrderBy
      _JoinClauseFromQueryJoin theClause, theRelationshipOrderBy, theConnA, \
            xQueryA["table"]["name"], xQueryA["table"]["as"], theJoinsA

      put char 1 to -2 of theRelationshipOrderBy into xQueryA["related tables order by"]
      return theClause
      break

    case "conditions"
      return xQueryA["conditions"]["human"]
      break

    case "where clause"
      local theAliasWhere, theScopeWhere, theWhere, theTableName, theDbType
      local theKeys, theConditions, theOrigConditions, theSQLA

      put _CreateConnectionArray(xQueryA["connection"], xQueryA["database"]) into theConnectionA

      put empty into theAliasWhere
      put empty into theScopeWhere
      put empty into theWhere
      put xQueryA["table"]["name"] into theTable
      put xQueryA["table"]["as"] into theTableName
      if theTableName is empty then put theTable into theTableName
      put dbconn_get("effective quotes", theConnectionA) into theQsA
      put dbconn_get("type", theConnectionA) into theDbType

      ## Account for conditions in an alias
      if not xQueryA["ignore alias conditions"] and tableobjects_tableExists(theTable, xQueryA["database"]) then
        put tableobjects_getTable(theTable, xQueryA["database"]) into theTableA
        if tableobj_get(theTableA, "type") is "alias" then
          if xQueryA["use long form for alias conditions"] is empty then put true into xQueryA["use long form for alias conditions"] ## used internally
          put _TableAliasWhereClause(theConnectionA, theTable, xQueryA["use long form for alias conditions"]) into theAliasWhere
        end if
      end if

      ## Add in conditions for scope
      put _SortNumericKeys(the keys of xQueryA["scopes"]) into theKeys
      repeat for each line i in theKeys
        put xQueryA["scopes"][i]["conditions"]["sql"] & " AND " after theScopeWhere
      end repeat
      delete the last word of theScopeWhere
      if theScopeWhere is not empty then
        if the number of lines of theKeys > 1 then
          put "(" & theScopeWhere & ")" into theScopeWhere
        else
          put theScopeWhere into theScopeWhere
        end if
      end if

      put theAliasWhere into theWhere
      if theAliasWhere is not empty then put " AND " after theWhere
      put theScopeWhere after theWhere
      if theScopeWhere is not empty then put " AND " after theWhere

      ## Add in bindings. Take into account bindings that are arrays
      put xQueryA["conditions"]["sql"] into theConditions
      put theConditions into theOrigConditions
      put empty into theSQLA
      if theConditions is not empty then
        repeat with i = 1 to the number of elements of xQueryA["condition bindings"]
          if xQueryA["condition bindings"][i] is an array then
            ## You can pass multiple arrays in but all MUST have the same number of keys
            ## Only the operator of the first array is honored
            if theSQLA is not an array then
              repeat with j = 1 to the number of elements of xQueryA["condition bindings"][i]
                put xQueryA["condition bindings"][i][j]["operator"] into theSQLA[j]["operator"]
                put "(" & theOrigConditions & ")" into theSQLA[j]["sql"]
              end repeat
            end if

            ## Now replace each string in array with binding
            repeat with j = 1 to the number of elements of theSQLA
              replace (":" & i) with _EscapeDbString(theDbType, xQueryA["condition bindings"][i][j]["string"]) in theSQLA[j]["sql"]
            end repeat
          else
            ## QUESTION: Can we do offset(":"), check if integer follows, check if wrapped in '' then check if preceding condition is "IN"?
            ## We could then automatically add the '' if need be.
            ## Is "IN" the only one that wouldn't be escaped?
            replace (":" & i) with _EscapeDbString(theDbType, xQueryA["condition bindings"][i]) in theConditions
          end if
        end repeat
      end if

      if theSQLA is an array then
        repeat with i = 1 to the number of elements of theSQLA
          put space & theSQLA[i]["operator"] && theSQLA[i]["sql"] after theWhere
        end repeat
        delete char 1 of theWhere
        delete word 1 of theWhere
      else
        put theConditions after theWhere
      end if
      ## end bindings
      if the last word of theWhere is "AND" then delete the last word of theWhere

      return theWhere
      break

    case "query"
      local theQuery, theFrom, theQuerySuffix, theOrderBy, theLimit, theOffset
      local theJoin

      ## the full query this baby produces
      put "SELECT " into theQuery
      put empty into theFrom
      put empty into theQuerySuffix
      put empty into theOrderBy

      ## Account for find
      put xQueryA["limit"] into theLimit
      put xQueryA["offset"] into theOffset

      if xQueryA["find"] is not empty then
        put 1 into theLimit
        put 0 into theOffset
      end if

      if xQueryA["find"] is "last" then
        ## how to handle?
        ## If no "order by" then set to primary key field DESC
        ## If order by then swap DESC with ASC
        ## If no DESC/ASC then add DESC to each order by entry
      end if

      ## Add TOP for sql server
      switch sqlquery_get(xQueryA, "database type")
        case "sql server"
          if theLimit > 0 and theOffset < 1 then
            put "TOP" && theLimit & space after theQuery
          end if
          break
      end switch

      if sqlquery_get(xQueryA, "distinct") then
        put "DISTINCT " after theQuery
      end if

      put sqlquery_get(xQueryA, "select clause") after theQuery
      put " FROM " into theFrom

      put sqlquery_get(xQueryA, "from clause") after theFrom
      put sqlquery_get(xQueryA, "join clause") into theJoin
      if theJoin is not empty then
        put space & theJoin after theFrom
      end if

      put empty into theQuerySuffix
      put sqlquery_get(xQueryA, "where clause") into theWhere
      if theWhere is not empty then
        put " WHERE " & theWhere after theQuerySuffix
      end if
      if xQueryA["group by"] is not empty then
        put space & "GROUP BY" && xQueryA["group by"] after theQuerySuffix
      end if
      if xQueryA["having"] is not empty then
        put space & "HAVING" && xQueryA["having"] after theQuerySuffix
      end if

      ##
      ## Order by needs to include related tables as well
      ##
      local theString, theItemWO, theUsedA

      put xQueryA["order by"] into theString
      if xQueryA["related tables order by"] is not empty then
        if theString is not empty then put "," after theString
        put xQueryA["related tables order by"] after theString
        replace cr with "," in theString
      end if

      if theString is not empty then
        put empty into theOrderBy

        ## remove duplicates
        repeat for each item theItem in theString
          put word 1 to -1 of theItem into theItemWO
          if theUsedA[theItemWO] is 1 then next repeat

          put theItemWO & ", " after theOrderBy
          put 1 into theUsedA[theItemWO]
        end repeat
        delete char -2 to -1 of theOrderBy

        put space & "ORDER BY" && theOrderBy into theOrderBy
      end if

      ##
      ## limit/offset
      ##
      switch sqlquery_get(xQueryA, "database type")
        case "sql server"
          ## http://msdn.microsoft.com/en-us/library/ms186734.aspx
          ## Seriously people? You can't add offset?
          if theOffset > 0 then
            ## Must provide ORDER BY
            if theOrderBy is empty then
              _ThrowError kErrInvalidProperty, "you must specify an 'order by' value to use ROW_NUMBER with SQL Server"
            end if
            if theLimit < 1 then
              _ThrowError kErrInvalidProperty, "you must specify a limit when using 'offset' with SQL Server"
            end if

            ## Wrap select in WITH ... AS so we can use ROW_NUMBER
            ## This is funky.
            put "WITH SqlYogaSub AS (" && \
                  theQuery & ", ROW_NUMBER() OVER (" & char 2 to -1 of theOrderBy & ") AS 'RowNumber'" & \
                  theFrom & theQuerySuffix & \
                  ") " & \
                  "SELECT * FROM SqlYogaSub WHERE RowNumber BETWEEN" &&  \
                  theOffset && "AND" && theOffset + (theLimit - 1) into theQuery
            put empty into theFrom
            put empty into theQuerySuffix
            put empty into theOrderBy

          else
            put theOrderBy after theQuerySuffix
          end if
          break

        case "valentina"
        case "mysql"
        case "postgresql"
        case "sqlite"
        default
          put theOrderBy after theQuerySuffix

          if theLimit > 0 then
            put space & "LIMIT" && theLimit after theQuerySuffix
          end if

          if theOffset > 0 then
            if theLimit < 1 then
              ## Use a really big number as limit MUST have a value.
              ## This is as high as SQLite would go through RevDB.
              put space & "LIMIT 1000000000000000000" after theQuerySuffix
            end if
            put space & "OFFSET" && theOffset - 1 after theQuerySuffix
          end if
      end switch

      return theQuery & theFrom & theQuerySuffix
      break

    case "distinct" ## until we create list of all props
    case "full column names" # deprecated - see `column names length`
    case "column names length"
      return xQueryA[pProp]
      break

    default
      if pProp is among the items of sSQLQuerySetProps & comma & sSQLQueryGetProps then
        return xQueryA[pProp]
      else
        _ThrowError kErrInvalidProperty, "invalid SQL Query objec property '" & pProp & "'"
      end if
  end switch
end sqlquery_get


private function _TableAliasWhereClause pConnectionA, pTable, pUseLongForm
  local theQsA, theAliasWhere, theDbType

  put dbconn_get("type", pConnectionA) into theDbType
  put dbconn_get("effective quotes", pConnectionA["name"], pConnectionA["database"]) into theQsA

  if the number of elements of sDbsA[ pConnectionA["database"] ]["table objects"]["tables"][ pTable ]["conditions"] > 1 then
    put "(" into theAliasWhere
  end if

  repeat with i = 1 to the number of elements of sDbsA[ pConnectionA["database"] ]["table objects"]["tables"][ pTable ]["conditions"]
    if pUseLongForm then
      put theQsA["left"] &  pTable  & theQsA["right"] & "." after theAliasWhere
    end if
    put theQsA["left"] & sDbsA[ pConnectionA["database"] ]["table objects"]["tables"][ pTable ]["conditions"][i]["field"] & theQsA["right"] && "=" && \
          "'" & _EscapeDbString(theDbType, \
          sDbsA[ pConnectionA["database"] ]["table objects"]["tables"][ pTable ]["conditions"][i]["value"]) & "'" after theAliasWhere
    put " AND " after theAliasWhere
  end repeat
  delete the last word of theAliasWhere

  if the number of elements of sDbsA[ pConnectionA["database"] ]["table objects"]["tables"][ pTable ]["conditions"] > 1 then
    put ")" after theAliasWhere
  end if

  return theAliasWhere
end _TableAliasWhereClause


/**
Summary: Creates a record in a table.

Parameters:
pTable: The name of the table to create the record. If you need to pass in a Database or Connection object that isn't the default then pass in SQL Query object.
pParamsA: An array of key value pairs used to create the record.

Description:
This command will perform a `CREATE` based on the parameters you pass in.

Example:
## Create lesson
put 0 into theValuesA["draft"]
sqlquery_create "lessons", theValuesA
put the result into theError

Returns:
it: Number of affected rows
the result: Error string
*/
command sqlquery_create pTable, pParamsA, pConnName, pDBKey
  local theAffectedRows
  local theQueryA
  local theError

  ## Get query object
  if pTable is not an array then
    put sqlquery_createObject(pTable, pConnName, pDBKey) into theQueryA
  else
    put pTable into theQueryA
    _ValidateQueryArray theQueryA
  end if

  ##
  ## Create Record object
  local theRecordA

  put theQueryA["connection"] into theRecordA["@connection"]
  put theQueryA["database"] into theRecordA["@database"]
  put theQueryA["table"]["name"] into theRecordA["@table"]

  ##
  ## Get primary key and fill in table
  if tableobjects_tableExists(theQueryA["table"]["name"], theQueryA["database"]) then
    local theTableA, thePrimaryKey

    put tableobjects_getTable(theQueryA["table"]["name"], theQueryA["database"]) into theTableA
    put tableobj_get(theTableA, "primary key") into thePrimaryKey

    if tableobj_get(theTableA, "type") is "alias" then
      put tableobj_get(theTableA, "alias for table") into theRecordA["@table"]

      ## Automatically set alias properties
      repeat with i = 1 to the number of elements of sDbsA[ theQueryA["database"] ]["table objects"]["tables"][ theQueryA["table"]["name"] ]["conditions"]
        put sDbsA[ theQueryA["database"] ]["table objects"]["tables"][ theQueryA["table"]["name"] ]["conditions"][i]["value"] \
              into pParamsA[ sDbsA[ theQueryA["database"] ]["table objects"]["tables"][ theQueryA["table"]["name"] ]["conditions"][i]["field"] ]
      end repeat
    end if
  else
    put sDbsA[ theQueryA["database"] ]["schema"]["tables"][ theQueryA["table"]["name"] ]["primary key"] into thePrimaryKey
  end if

  repeat for each key theKey in pParamsA
    put pParamsA[theKey] into theRecordA[theKey]
  end repeat

  ##
  ## Create the table lookup array
  local theConnectionA, theQs, theTablesA

  put _CreateConnectionArray(theQueryA["connection"], theQueryA["database"]) into theConnectionA
  put dbconn_get("effective quotes", theConnectionA) into theQs
  put thePrimaryKey into theTablesA[ theRecordA["@table"] ]["primary key"]
  repeat for each key theField in pParamsA
    put theField & "," after theTablesA[ theRecordA["@table"] ]["fields"]
  end repeat
  delete the last char of theTablesA[ theRecordA["@table"] ]["fields"]

  put 0 into theAffectedRows

  if theError is empty then
    local updateRecordAfterCreate

    ## Perform the update
    put false into updateRecordAfterCreate
    _InsertRecordIntoTable theConnectionA, theQs, theTablesA, theRecordA, updateRecordAfterCreate, false
    put the result into theError
    put it into theAffectedRows
  end if

  if theError is not empty then
    return theError for error
  else
    return theAffectedRows for value
  end if
end sqlquery_create


/**
Summary: Updates a record in a table.

Parameters:
pTable": The name of the table to update. If you need to pass in a Database or Connection object that isn't the default then pass in SQL Query object.
pConditions: The search conditions. This can be an array of search parameters, a primary key value or an exact string to assign to the `WHERE` clause. You can pass in an empty value for `pConditions` if there is no primary key for the table.
pParamsA: An array of key value pairs used to perform the update.

Description:

This command will perform an UPDATE based on the parameters you pass in.

Example:
## Update lesson with id of 2
put 0 into theValuesA["draft"]
sqlquery_update "lessons", 2, theValuesA
put the result into theError

## Update lesson with id of 2
sqlquery_update "lessons", "id = 2", theValuesA
put the result into theError

## Update lessons with an id of 12 and 15
put "id is in :1" into theConditionsA["conditions"]
put "12,15" into theConditionsA["condition bindings"][1]
sqlquery_update "lessons", theConditionsA, theValuesA
put the result into theError

Returns:
it: Number of affected rows
the result: Error string\
*/
command sqlquery_update pTable, pConditions, pParamsA, pConnName, pDBKey
  local theResolvedTable, theTableA, theAffectedRows
  local thePrimaryKey, theQueryA, theAliasWhere
  local theError

  ## Get query object
  if pTable is not an array then
    put sqlquery_createObject(pTable, pConnName, pDBKey) into theQueryA
  else
    put pTable into theQueryA
    _ValidateQueryArray theQueryA
  end if

  ##
  ## Get primary key
  put theQueryA["table"]["name"] into theResolvedTable
  if tableobjects_tableExists(theQueryA["table"]["name"], theQueryA["database"]) then
    put tableobjects_getTable(theQueryA["table"]["name"], theQueryA["database"]) into theTableA
    put tableobj_get(theTableA, "primary key") into thePrimaryKey

    if tableobj_get(theTableA, "type") is "alias" then
      put tableobj_get(theTableA, "alias for table") into theResolvedTable

      put false into theQueryA["use long form for alias conditions"]
    end if
  else
    put sDbsA[ theQueryA["database"] ]["schema"]["tables"][ theQueryA["table"]["name"] ]["primary key"] into thePrimaryKey
  end if

  ##
  ## pConditions is a string or array.
  ## Integer searches on primary key field.
  ## Otherwise we parse conditions.
  if pConditions is not an array then
    if pConditions is empty then
      if thePrimaryKey is not empty then
        _ThrowError kErrInvalidProperty, "you must provide a search condition for the primary key field (" & thePrimaryKey & ")"
      end if
    else if the number of words of pConditions > 1 then ## passed in full search condition as string.
      sqlquery_set theQueryA, "conditions", pConditions
    else
      if thePrimaryKey is empty or the number of items of thePrimaryKey > 1 then
        _ThrowError kErrInvalidProperty, "primary key is empty or has more than one field (" & thePrimaryKey & ")"
      end if
      if sDbsA[ theQueryA["database"] ]["schema"]["tables"][ theQueryA["table"]["name"] ]["fields"][ thePrimaryKey ]["meta type"] \
            is not among the items of kDontQuoteTypes then
        sqlquery_set theQueryA, "conditions", thePrimaryKey && "= ':1'", pConditions
      else
        sqlquery_set theQueryA, "conditions", thePrimaryKey && "= :1", pConditions
      end if
    end if
  else
    repeat for each key theProp in pConditions
      if _TranslateSQLQueryProp(theProp) is among the items of sSQLQuerySetProps then
        sqlquery_set theQueryA, theProp, pConditions[theProp]
      end if
    end repeat
  end if

  ##
  ## Create Record object
  local theRecordA

  put pParamsA into theRecordA
  put theResolvedTable into theRecordA["@table"]
  put theQueryA["connection"] into theRecordA["@connection"]
  put theQueryA["database"] into theRecordA["@database"]
  put sqlquery_get(theQueryA, "where clause") into theRecordA["@where"]

  ##
  ## Create the table lookup array
  ## Note: We allow updating of primary key fields so don't fill in
  ## "primary key" or _UpdateRecordInTable will strip any primary key fields out.
  ## We don't need to include primary keys anyway because we include the where statement
  ## and we don't update record after update.
  ##
  local theConnectionA, theQs, theTablesA

  put _CreateConnectionArray(theQueryA["connection"], theQueryA["database"]) into theConnectionA
  put dbconn_get("effective quotes", theConnectionA) into theQs
  --    put thePrimaryKey into theTablesA[ theRecordA["@table"] ]["primary key"]
  repeat for each key theField in pParamsA
    put theField & "," after theTablesA[ theRecordA["@table"] ]["fields"]
  end repeat
  delete the last char of theTablesA[ theRecordA["@table"] ]["fields"]

  put 0 into theAffectedRows

  if theError is empty then
    ## Perform the update
    local updateRecordAfterUpdate

    put false into updateRecordAfterUpdate
    _UpdateRecordInTable theConnectionA, theQs, theTablesA, theRecordA, updateRecordAfterUpdate, false
    put the result into theError
    put it into theAffectedRows
  end if

  if theError is not empty then
    return theError for error
  else
    return theAffectedRows for value
  end if
end sqlquery_update


/**
Summary: Opens a database cursor for a SQL Query object.

Parameters:
xQueryA: A SQL Query Object array as created using `sqlquery_createObject()`.

Description:
Use this command to open a database cursor after setting the appropriate properties of
a SQL Query Object. After opening a cursor you can interact with the cursor using the sqlquery handlers listed below.

Returns:
it: Cursor id
the result: Error string

References: sqlquery_close (command), sqlquery_convertToArray (command), sqlquery_convertToArray (command), sqlquery_currentRowToArray (command), sqlquery_moveToFirstRecord (command), sqlquery_moveToLastRecord (command), sqlquery_moveToNextRecord (command), sqlquery_moveToPreviousRecord (command)
*/
command sqlquery_retrieve @xQueryA
  -----
  local theBindingsA
  local theConnectionA
  local theError
  local theQuery
  -----
  put sqlquery_get(xQueryA, "connection") into theConnectionA
  _ValidateConnectionArray theConnectionA

  put sqlquery_get(xQueryA, "query") into theQuery
  put sqlquery_get(xQueryA, "condition bindings") into theBindingsA
  dbconn_openCursor theQuery, theBindingsA, xQueryA["database parameters"], theConnectionA
  put the result into theError

  if theError is empty then
    put it into xQueryA["cursor id"]
    return it for value
  else
    put 0 into xQueryA["cursor id"]
    return theError for error
  end if
end sqlquery_retrieve


/**
Summary: Executes a SQL Query Object query and returns the result as an array.

Parameters:
pQueryA: A SQL Query Object array as created using sqlquery_createObject().
xOutArray: Upon completion holds a numerically indexed array. The keys are column names and values are column values. If `xOutArray` already contains numerical indexes then this command will add the returned records to the end.

Description:
This handler will execute the query property of a SQL Query OBject and convert any returned
records into a multi-dimensional array. Each row in the database cursor will be represented
by a number in the first dimension. Each column in each row will be contained in the second
dimension for that number.

Example:
# A cursor with 2 columns (name and email) and 2 rows:

theDataA[1]["name"]
theDataA[1]["email"]
theDataA[2]["name"]
theDataA[2]["email"]

Returns: Error message
*/
command sqlquery_retrieveAsArray pQueryA, @xOutArray
  local tError

  sqlquery_retrieve pQueryA
  put the result into tError

  if tError is empty then
    sqlquery_convertToArray pQueryA, xOutArray
    put the result into tError

    sqlquery_close pQueryA
    if tError is empty then
      put the result into tError
    end if
  end if

  return tError
end sqlquery_retrieveAsArray


/**
Summary: Executes a SQL Query Object query and returns the result as data from the selected columns (no cursor).

Parameters:
pQueryA: A SQL Query Object array as created using `sqlquery_createObject()`.
xOutData: Upon completion the data returned will be in this parameter.

Description:
The 'column delimter' and 'row delimiter' properties of the SQL Query Object will be used to delimit columns and rows.

Returns: Error message
*/
command sqlquery_retrieveAsData pQueryA, @xOutData
  local theQuery, theBindingsA, theError
  local theConnectionA

  put empty into xOutData

  put sqlquery_get(pQueryA, "connection") into theConnectionA
  _ValidateConnectionArray theConnectionA

  put sqlquery_get(pQueryA, "query") into theQuery
  put sqlquery_get(pQueryA, "condition bindings") into theBindingsA
  dbconn_retrieveQueryAsData theQuery, theBindingsA, xOutData, \
        sqlquery_get(pQueryA, "column delimiter"), sqlquery_get(pQueryA, "row delimiter"), \
        theConnectionA
  put the result into theError
  _dbconnSetLastError theConnectionA, theError
  return theError
end sqlquery_retrieveAsData


/**
Summary: Executes a SQL Query Object query and returns the result as a Records array.

Parameters:
pQueryA: A SQL Query Object array as created using `sqlquery_createObject()`.
xOutRecordsA: Upon completion holds a numerically indexed array. If you pass in an array that already has numerical indexes then the array will be added to.

Description:
When retreiving query results as records any relationships that have been defined using
Table and Relationship  objects will be used to transform the flat SQL results into
a hierarchy representing defined relationships. Each record will have a `@table` key
in the array that contains the name of the table the record represents.

Example:
# A Records array that has a lesson table with step table children:

theRecordsA[1]["@table"] = "lesson"
theRecordsA[1]["id"] = "12"
theRecordsA[1]["title"] = "my lesson title"
theRecordsA[1]["steps"][1]["@table"] = "steps"
theRecordsA[1]["steps"][1]["id"] = "36"
theRecordsA[1]["steps"][1]["title"] = "My step title"
theRecordsA[1]["steps"][2]["@table"] = "steps"
theRecordsA[1]["steps"][2]["id"] = "58"
theRecordsA[1]["steps"][2]["title"] = "Another step title"

Returns: Error message
*/
command sqlquery_retrieveAsRecords pQueryA, @xOutRecordsA
  local tError

  sqlquery_set pQueryA, "column names length", "long"

  sqlquery_retrieve pQueryA
  put the result into tError

  if tError is empty then
    sqlquery_convertToRecords pQueryA, xOutRecordsA
    put the result into tError

    sqlquery_close pQueryA
    if tError is empty then
      put the result into tError
    end if
  end if

  return tError
end sqlquery_retrieveAsRecords


/**
Summary: Closes an open database cursor associated with a SQL Query Object.

Parameters:
xQueryA: A SQL Query Object array as created using `sqlquery_createObject()`.

Returns: Error message
*/
command sqlquery_close @xQueryA
  -----
  local theError
  -----
  _ValidateQueryArray xQueryA
  dbconn_closeCursor xQueryA["cursor id"], xQueryA["connection"], xQueryA["database"]
  put the result into theError

  if theError is empty then
    put 0 into xQueryA["cursor id"]
  end if

  return theError
end sqlquery_close


/**
Summary: Executes a `DELETE` query using the `where clause` of the SQL Query Object.

Parameters:
pQueryA: A SQL Query Object array as created using `sqlquery_createObject()`.

Returns:
it: Number of affected rows
the result: Error message
*/
command sqlquery_delete pQueryA
  -----
  local theAffectedRows
  local theConnectionA, theTransA
  local theError
  local theQs,theSQL
  local theWhere
  local rethrowTheError
  -----
  put sqlquery_get(pQueryA, "connection") into theConnectionA
  _ValidateConnectionArray theConnectionA

  put dbconn_get("effective quotes", theConnectionA) into theQs

  put _internalTransactionName() into theTransA["name"]
  dbconn_beginTransaction theTransA, theConnectionA
  put the result into theError

  try
    if theError is empty then
      local theQueryA

      put pQueryA into theQueryA
      put false into theQueryA["use long form for alias conditions"]
      put sqlquery_get(theQueryA, "where clause") into theWhere
      put "DELETE FROM %s%s%s WHERE %s" into theSQL
      put format(theSQL, theQs["left"], _ResolvedTableName(theQueryA["database"], theQueryA["table"]["name"]), theQs["right"], theWhere) into theSQL

      dbconn_executeSQL theSQL, theConnectionA
      put the result into theError
      put it into theAffectedRows
    end if
  catch e
    put e into theError
    put true into rethrowTheError
  end try

  if theError is empty then
    dbconn_commitTransaction theTransA, theConnectionA
    return theAffectedRows for value
  else
    dbconn_rollbackTransaction theTransA, theConnectionA
    if rethrowTheError then throw theError
    else return theError for error
  end if
end sqlquery_delete


/**
Summary: Navigates to the next record in a SQL Query Object's database cursor.

Parameters:
pQueryA: A SQL Query Object array as created using `sqlquery_createObject()`.

Returns: Boolean

References: sqlquery_retrieve (command)
*/
command sqlquery_moveToNextRecord pQueryA
  local theResult

  _ValidateQueryArray pQueryA
  if sDbsA[ pQueryA["database"] ]["connections"][ pQueryA["connection"] ]["type"] is "valentina" then
    put VCursor_NextRecord( pQueryA["cursor id"]) into theResult
  else
    revMoveToNextRecord pQueryA["cursor id"]
    put the result into theResult
  end if
  return theResult
end sqlquery_moveToNextRecord


/**
Summary: Navigates to the previous record in a SQL Query Object's database cursor.

Parameters:
pQueryA: A SQL Query Object array as created using `sqlquery_createObject()`.

Returns: Boolean

References: sqlquery_retrieve (command)
*/
command sqlquery_moveToPreviousRecord pQueryA
  local theResult

  _ValidateQueryArray pQueryA
  if sDbsA[ pQueryA["database"] ]["connections"][ pQueryA["connection"] ]["type"] is "valentina" then
    put VCursor_PrevRecord( pQueryA["cursor id"]) into theResult
  else
    revMoveToPreviousRecord pQueryA["cursor id"]
    put the result into theResult
  end if
  return theResult
end sqlquery_moveToPreviousRecord


/**
Summary: Navigates to the first record in a SQL Query Object's database cursor.

Parameters:
pQueryA: A SQL Query Object array as created using `sqlquery_createObject()`.

Returns: Boolean

References: sqlquery_retrieve (command)
*/
command sqlquery_moveToFirstRecord pQueryA
  local theResult

  _ValidateQueryArray pQueryA
  if sDbsA[ pQueryA["database"] ]["connections"][ pQueryA["connection"] ]["type"] is "valentina" then
    put VCursor_FirstRecord( pQueryA["cursor id"]) into theResult
  else
    revMoveToFirstRecord pQueryA["cursor id"]
    put the result into theResult
  end if
  return theResult
end sqlquery_moveToFirstRecord


/**
Summary: Navigates to the last record in a SQL Query Object's database cursor.

Parameters:
pQueryA: A SQL Query Object array as created using `sqlquery_createObject()`.

Returns: Boolean

References: sqlquery_retrieve (command)
*/
command sqlquery_moveToLastRecord pQueryA
  local theResult

  _ValidateQueryArray pQueryA
  if sDbsA[ pQueryA["database"] ]["connections"][ pQueryA["connection"] ]["type"] is "valentina" then
    put VCursor_LastRecord( pQueryA["cursor id"]) into theResult
  else
    revMoveToLastRecord pQueryA["cursor id"]
    put the result into theResult
  end if
  return theResult
end sqlquery_moveToLastRecord


/**
Summary: Navigates to the specified record in a SQL Query Object's database cursor.

Parameters:
pQueryA: A SQL Query Object array as created using `sqlquery_createObject()`.
pRecNum: The number of the record to navigate to, starting from 1.

Returns: Boolean

References: sqlquery_retrieve (command)
*/
command sqlquery_moveToRecord pQueryA, pRecNum
  local theResult

  _ValidateQueryArray pQueryA
  if sDbsA[ pQueryA["database"] ]["connections"][ pQueryA["connection"] ]["type"] is "valentina" then
    put VCursor_Position( pQueryA["cursor id"], pRecNum) into theResult
  else
    revMoveToRecord pQueryA["cursor id"], max(0, pRecNum - 1)
    put the result into theResult
  end if
  return theResult
end sqlquery_moveToRecord


/**
Summary: Converts a search string into the condition property of a SQL Query Object.

Parameters:
xQueryA: A SQL Query Object array.
pString: A string representing the terms a user wants to search for.
pConditions: A string representing the SQL WHERE clause. :1 appears where you want to insert search terms. You do no need to wrap :1 in single quotes as this function always assumes you are searching for a string and wraps the strings in single quotes for you.
pDefaultOperator: Default boolean operator to use between words that do not explicity state one. Options are `AND` (default) or `OR`.

Description:
Search interfaces often allow a user to enter a search string for querying the database.
A string entered by the user as

```
tacos pizza
```

might look like this in a WHERE clause:

```
field = 'tacos' AND field='pizza'
```

or

```
field='tacos' OR field='pizza'
```

A search string such as

```
"cheese pizza" tacos
```

might look like this in a WHERE clause:

```
field = 'cheese pizza' OR field='tacos'
```

This command takes a search string and combines it with the conditions of a WHERE clause and applies
them to a SQL Query Object.

For example, if you passed in the string

```
"cheese pizza" taco
```

with a default operator of "OR" and the conditions were "food.name contains :1" then the following
WHERE clause would be generated for the query:

```
WHERE (food.name LIKE  '%cheese pizza%' OR food.name LIKE '%tacos%')
```

You can see that the WHERE clause searches the name field of the food table for both terms.

Returns: Error message.

References: sqlyoga_splitUserSearchString (function)
*/
command sqlquery_setConditionsFromUserSearchString @xQueryA, pString, pConditions, pDefaultOperator
  -----
  local i
  local theConditions
  local theConnectionA
  local theDbType
  local theError
  local theFindCriteria
  local theSearchA
  -----
  put empty into theError
  put sqlquery_get(xQueryA, "connection") into theConnectionA

  put dbconn_get("type", theConnectionA) into theDbType
  put _ParseUserSearchString(pString, pDefaultOperator) into theSearchA

  repeat with i = 1 to the number of elements of theSearchA
    put theSearchA[i]["operator"] & space after theFindCriteria

    ## for each entry we will do an OR search on all provided fields to search on
    put "(" after theFindCriteria

    put pConditions into theConditions
    replace ":1" with "'" & _EscapeDbString(theDbType, theSearchA[i]["string"]) & "'" in theConditions

    put theConditions after theFindCriteria
    put ")" after theFindCriteria

    put space after theFindCriteria
  end repeat
  delete word 1 of theFindCriteria
  delete the last char of theFindCriteria

  sqlquery_set xQueryA, "conditions", theFindCriteria

  return theError
end sqlquery_setConditionsFromUserSearchString


/**
Summary: Adds a condition to a query by creating a scope and assigning the condition to it.

pQueryA: A SQL Query Object array.
pCondition: The search condition. No bindings are allowed.

Description:
This handler can be useful if you are dynamically building search conditions and
need to add a hard coded search condition.

Returns: empty
*/
command sqlquery_addCondition pQueryA, pCondition
  local theScopeA, theNextIndex

  put "condition" && the milliseconds into theScopeA["name"]
  put pCondition into theScopeA["conditions"]["sql"]
  put _NextIndexForQuerySubKey(pQueryA, "scopes") into theNextIndex
  put theScopeA into pQueryA["scopes"][theNextIndex]
  return empty
end sqlquery_addCondition


/**
Summary: Adds an existing Scope object to a SQL Query Object.

xQueryA: A SQL Query Object array.
pScope: The name of the Scope object to add to the query.
pParamsDotDotDot: Pass in additional parameters for use with any binding entries in the scopes conditions. You can pass in strings or a numerically indexed array.

Description:
This handler enables you to dynamically build search criteria for a SQL Query Object.
This makes generating queries from complex search UIs much easier.

The array for parameter 3 is numerically indexed and each numeric key has
a **string** and **operater** key.

If you are passing in multiple arrays for use in replacing the bindings used in
the scope condition then each array MUST have the same number of numeric entries.
The **string** key will only be used from the first array passed in however.

Example:
put sqlquery_createObject("lessons") into theQueryA
sqlquery_addScope theQueryA, "lessons linked to manuals"
sqlquery_retrieveAsArray theQueryA, theDataA

Returns: empty
*/
command sqlquery_addScope @xQueryA, pScope, pParamsDotDotDot
  -----
  local i,j,theSQLA
  local theCharNo
  local theConnectionA
  local theDbType
  local theKeyA
  local theLeftParen
  local theNextIndex
  local theOrigConditions
  local theParam
  local theRightParen
  local theScopeA
  local theTable, theTableA
  -----
  ## pScope needs to be associated with 'table' of xQueryA
  put sqlquery_get(xQueryA, "table") into theTable
  put tableobjects_getTable(theTable, xQueryA["database"]) into theTableA
  put tableobj_getScope(theTableA, pScope) into theScopeA

  if the keys of theScopeA is not empty then
    put _KeyArrayForScope(theScopeA) into theKeyA
    put sDbsA[ theKeyA ] into theScopeA

    put sqlquery_get(xQueryA, "connection") into theConnectionA
    put dbconn_get("type", theConnectionA) into theDbType

    ## Store original scope
    ## Only wrap in parens if there is more than one condition
    put theScopeA["conditions"]["sql"] into theOrigConditions
    put offset(":1", theOrigConditions) into theCharNo
    if theCharNo > 0 then
      put offset(":1", theOrigConditions, theCharNo) into theCharNo
      if theCharNo > 0 then
        put "(" into theLeftParen
        put ")" into theRightParen
      end if
    end if

    ## count backwards in case of double digit replacements
    repeat with i = the paramCount down to 3
      put param(i) into theParam
      if theParam is an array then
        -- theParam[1]["operator"]
        -- theParam[1]["string"]

        ## You can pass multiple arrays in but all MUST have the same number of keys
        ## Only the operator of the first array is honored
        if theSQLA is not an array then
          repeat with j = 1 to the number of elements of theParam
            put theParam[j]["operator"] into theSQLA[j]["operator"]
            put theLeftParen & theOrigConditions & theRightParen into theSQLA[j]["sql"]
          end repeat
        end if

        repeat with j = 1 to the number of elements of theSQLA
          replace (":" & i-2) with _EscapeDbString(theDbType, theParam[j]["string"]) in theSQLA[j]["sql"]
        end repeat
      else
        replace (":" & i-2) with _EscapeDbString(theDbType, param(i)) in theScopeA["conditions"]["sql"]
      end if
    end repeat

    if theSQLA is an array then
      put empty into theScopeA["conditions"]["sql"]
      repeat with i = 1 to the number of elements of theSQLA
        put space & theSQLA[i]["operator"] && theSQLA[i]["sql"] after theScopeA["conditions"]["sql"]
      end repeat
      delete char 1 of theScopeA["conditions"]["sql"]
      delete word 1 of theScopeA["conditions"]["sql"]

      ## Wrap multiple conditions in parentheses so they are grouped
      if the number of elements of theSQLA > 1 then
        put "(" before theScopeA["conditions"]["sql"]
        put ")" after theScopeA["conditions"]["sql"]
      end if
    end if

    put _NextIndexForQuerySubKey(xQueryA, "scopes") into theNextIndex
    put theScopeA into xQueryA["scopes"][theNextIndex]
    return empty
  else
    _ThrowError kErrCantFindObject, "scope " & quote & pScope & quote & " not found"
  end if
end sqlquery_addScope


/**
Summary: Converts the current row of the SQL Query Object cursor to an array.

Parameters:
pQueryA: A SQL Query Object array.
xOutArrayA: Upon completion this will hold row values. The keys are column names and values are column values.

Returns: empty
*/
command sqlquery_currentRowToArray pQueryA, @xOutArrayA
  -----
  local theFields
  -----
  ## Let function figure out field names
  _CursorRowToArray pQueryA, theFields, xOutArrayA, empty
  return empty
end sqlquery_currentRowToArray


private function _ValentinaFieldsFromCursor pCursorID
  local theFieldCount, theFieldRef, theFields, theCursorFields
  local theField, theUsedFieldsA

  ## No duplicate field names
  put VCursor_FieldCount( pCursorID ) into theFieldCount
  repeat with i = 1 to theFieldCount
    put VCursor_Field( pCursorID, i ) into theFieldRef
    put VField_Name( theFieldRef ) into theField
    add 1 to theUsedFieldsA[theField]

    if theUsedFieldsA[theField] is 1 then
      put theField & comma after theFields
    else
      put theField & theUsedFieldsA[theField] & comma after theFields
    end if
  end repeat
  delete the last char of theFields

  return theFields
end _ValentinaFieldsFromCursor


private function _CursorFieldNames pCursorID
  local theFields, theCursorFields
  local theField, theUsedFieldsA

  ## No duplicate field names
  put revDatabaseColumnNames(pCursorID) into theCursorFields
  repeat for each item theField in theCursorFields
    add 1 to theUsedFieldsA[theField]
    if theUsedFieldsA[theField] is 1 then
      put theField & comma after theFields
    else
      put theField & theUsedFieldsA[theField] & comma after theFields
    end if
  end repeat
  delete the last char of theFields

  return theFields
end _CursorFieldNames


/**
Summary: Converts a SQL Object's open database cursor into an array.

Parameters:
pQueryA: A SQL Query Object array.
xOutArray: Upon completion holds a numerically indexed array. The keys are column names and values are column values. If xOutArray already contains numerical indexes then this command will add the returned records to the end.

Returns: Error message.
*/
command sqlquery_convertToArray pQueryA, @xOutArray
  -----
  local theIndex, theDynamicKeyA
  local theError
  local theFields
  -----
  put the number of elements of xOutArray into theIndex
  if theIndex is not an integer then put 0 into theIndex

  _ValidateQueryArray pQueryA
  if pQueryA["cursor id"] < 1 then put kInvalidCursor into theError

  if theError is empty then
    switch sDbsA[ pQueryA["database"] ]["connections"][ pQueryA["connection"] ]["type"]
      case "valentina"
        if VCursor_FirstRecord(pQueryA["cursor id"]) then
          put _ValentinaFieldsFromCursor( pQueryA["cursor id"] ) into theFields

          repeat forever
            add 1 to theIndex
            put theIndex into theDynamicKeyA[1]
            _CursorRowToArray pQueryA, theFields, xOutArray, theDynamicKeyA
            get VCursor_NextRecord( pQueryA["cursor id"] )
            if not it then exit repeat
          end repeat
        end if
        break

      default
        if not revQueryIsAtEnd(pQueryA["cursor id"]) then
          put _CursorFieldNames(pQueryA["cursor id"]) into theFields

          repeat forever
            add 1 to theIndex
            put theIndex into theDynamicKeyA[1]
            _CursorRowToArray pQueryA, theFields, xOutArray, theDynamicKeyA
            revMoveToNextRecord pQueryA["cursor id"]
            if not the result then exit repeat
          end repeat
        end if
    end switch
  end if

  ## Using find only returns a single record
  if pQueryA["find"] is not empty then
    put xOutArray[1] into xOutArray
  end if

  return theError
end sqlquery_convertToArray


/**
Summary: Converts a SQL Object's open database cursor into records.

Parameters:
xQueryA: A SQL Query Object array.
xOutRecordsA" Upon completion holds a numerically indexed array. If you pass in an array that already has numerical indexes then the array will be added to.

Description:
When converting a cursor to records any relationships that have been defined will be used to transform the flat
SQL results into a hierarchy representing defined relationships. Each record will have a `@table` key in the array
that contains the name of the table the record represents.

Example:
# A Records array that has a lesson table with step table children:

theRecordsA[1]["@table"] = "lesson"
theRecordsA[1]["id"] = "12"
theRecordsA[1]["title"] = "my lesson title"
theRecordsA[1]["steps"][1]["@table"] = "steps"
theRecordsA[1]["steps"][1]["id"] = "36"
theRecordsA[1]["steps"][1]["title"] = "My step title"
theRecordsA[1]["steps"][2]["@table"] = "steps"
theRecordsA[1]["steps"][2]["id"] = "58"
theRecordsA[1]["steps"][2]["title"] = "Another step title"

Returns: Error message.
*/
command sqlquery_convertToRecords @xQueryA, @xOutRecordsA
  -----
  local theError
  -----
  _ValidateQueryArray xQueryA
  if xQueryA["cursor id"] < 1 then put kInvalidCursor into theError

  if theError is empty then
    _HierarchalCursorToArray xQueryA, xOutRecordsA
    put the result into theError
  end if

  ## return single instance
  if xQueryA["find"] is not empty then
    put xOutRecordsA[1] into xOutRecordsA
  end if

  return theError
end sqlquery_convertToRecords


--> Object: SQL Records


/**
Summary: Creates a SQL Record object (represented as an array) for a table with all columns initialized to their default values.

Parameters:
pTable: Name of the table to create the Record array for.
pConnName: Name of the connection to attach the SQL Record to. Default is the default connection for the database object.
pDBKey: The name of the database object to attach the SQL Record object to. Default is name returned by `sqlyoga_getDefaultDatabase()`.

Description:
A SQL Record object represents a table record. An array is used to hold the object values. You should always use `sqlrecord_set` to
update values in this array as there are special keys in the array that get updated when setting values. In addition,
`sqlrecord_get`/`sqlrecord_set` will throw errors if you try to set the value of a column not in the table which can help catch bugs early on.

Returns: Record array

References: sqlrecord_get (function), sqlrecord_set (command)
*/
function sqlrecord_createObject pTable, pConnName, pDBKey
  local theA, theConnectionA

  put pTable into theA["@table"]

  put _CreateConnectionArray(pConnName, pDBKey) into theConnectionA
  put theConnectionA["database"] into theA["@database"]
  put theConnectionA["name"] into theA["@connection"]

  ## first check for table object, then go after table
  if tableobjects_tableExists(pTable, pDBKey) then
    local theTableA

    put tableobjects_getTable(pTable, pDBKey) into theTableA
    if tableobj_get(theTableA, "type") is "alias" then
      put tableobj_get(theTableA, "table") into theTableA
      put theTableA["name"] into pTable
    end if
  end if

  put dbschema_tableGet(pTable, pDBKey) into theTableA

  repeat for each key theField in theTableA["fields"]
    put theTableA["fields"][theField]["default value"] into theA[theField]

    ## Note: Not setting NULL to actual LiveCode NULL value since that
    ## messes up displaying of strings. Since we have passthru turned
    ## on then it doesn't matter

    put theField & comma after theA["@passthru"]
  end repeat
  delete the last char of theA["@passthru"]

  ## primary key should have NULL value
  ## Some dbs will use expressions as DEFAULT
  if the number of items of theTableA["primary key"] is 1 then
    put "NULL" into theA[ theTableA["primary key"] ]
  end if

  return theA
end sqlrecord_createObject


function sqlrecord_initWithTable pTable, pDBKey
  return sqlrecord_createObject(pTable, pDBKey)
end sqlrecord_initWithTable


/**
Summary: Finds records in the database and returns as SQL Record objects.

pRecordA: Can be the name of a table or a SQL Record object. Pass in an object if you want to specify the connection and/or database to use. Otherwise default database and default database connection are assumed.
pParamsA: Pass a string to search on the primary key field for the table.
xRecordsA: [out] Contains the found record(s).

Description:
`pParamsA` has a number of options.

- Pass in the primary key value.
- If the primary key for the table is composed of more than one field then pass in `name:value,name:value` pairs.
- Pass in an array whose keys are properties of a SQL Query object for more control over results. In this case an array of SQL Record objects is returned.

Example:
## Find lesson with id of 2 and store it in theRecordA
sqlrecord_find "lessons", 2, theRecordA
put the result into theError
-- theRecordA contains a single SQL Record object

Example:
## Find record using primary key composed of two fields (id_1 and id_2)
sqlrecord_find "object", "id_1:53,id_2:25", theRecordA
put the result into theError
-- theRecordA contains a single SQL Record object

Example:
## Find lessons with ids of 12 or 15 and order by id
## Store result in theRecordsA
put "id is in :1" into theParamsA["conditions"]
put "12,15" into theParamsA["condition bindings"][1]
put "id ASC" into theParamsA["order by"]
sqlrecord_find "lessons", theParamsA, theRecordsA
put the result into theError
-- theRecordsA contains an array of SQL Records objects (numerically indexed)

Returns: Error message
*/
command sqlrecord_find pRecordA, pParamsA, @xRecordsA
  local theQueryA, theFields, theField
  local theError

  put empty into xRecordsA

  ## pRecordA is a SQL Record object or name of a table.
  if pRecordA is an array then
    if "@table" is not among the keys of pRecordA then
      _ThrowError kErrCantFindObject, "you must assign a valid table to a record"
    end if
  else
    put pRecordA into pRecordA["@table"]
  end if

  ## Create a SQL Query
  put sqlquery_createObject(pRecordA["@table"], pRecordA["@connection"], pRecordA["@database"]) into theQueryA

  ## pParamsA is a string or array.
  ## Integer searches on primary key field.
  ## Otherwise we parse params.
  if pParamsA is not an array then
    local theParam, theConditions, theBindingsA, i

    sqlquery_set theQueryA, "find", "first" ## return single instance

    # Just get table record based on primary key
    if tableobjects_tableExists(pRecordA["@table"], theQueryA["database"]) then
      local theTableA

      put tableobjects_getTable(pRecordA["@table"], theQueryA["database"]) into theTableA
      put tableobj_get(theTableA, "primary key") into theFields
    else
      put sDbsA[ theQueryA["database"] ]["schema"]["tables"][ pRecordA["@table"] ]["primary key"] into theFields
    end if
    if theFields is empty or (the number of items of theFields > 1 and the number of items of pParamsA is not the number of items of theFields) then
      _ThrowError kErrInvalidProperty, "primary key is empty or has more than one field and not enough items in pParams (" & theFields & ")"
    end if

    if pParamsA contains ":" and pParamsA contains "," then
      split pParamsA by "," and ":"
    end if

    repeat with i = 1 to the number of items of theFields
      put item i of theFields into theField
      if pParamsA is an array then
        put pParamsA[theField] into theParam
      else
        put pParamsA into theParam
      end if
      if i > 1 then put " AND " after theConditions

      if sDbsA[ theQueryA["database"] ]["schema"]["tables"][ pRecordA["@table"] ]["fields"][ theField ]["meta type"] \
            is not among the items of kDontQuoteTypes then
        put theParam into theBindingsA[i]
        put theField && "= ':" & i & "'" after theConditions
      else
        put theParam into theBindingsA[i]
        put theField && "= :" & i after theConditions
      end if
    end repeat

    sqlquery_set theQueryA, "conditions", theConditions
    sqlquery_set theQueryA, "condition bindings", theBindingsA
  else
    repeat for each key theProp in pParamsA
      if _TranslateSQLQueryProp(theProp) is among the items of sSQLQuerySetProps then
        sqlquery_set theQueryA, theProp, pParamsA[theProp]
      end if
    end repeat
  end if

  ## Retrieve as records
  sqlquery_retrieveAsRecords theQueryA, xRecordsA
  put the result into theError

  return theError
end sqlrecord_find


/**
Summary: Returns a property of a SQL Record object.

Parameters:
pRecordA: SQL Record object that you want to get the property for.
pProp: The property to get.

Description:
`pProp` can be a built-in property, a column in the SQL Record's table
or a custom property. The built-in properties are:

| Property | Description |
| -------- |:----------- |
| `@table` | The name of the table to associate the SQL Record with. |
| `@database` | The name of the database object the SQL record is associated with. |
| `@connection` | The connection object the SQL Record should use. |

If `pProp` is not a built-in property or a column then it is assumed that it is a
custom property that you have defined in the table behavior stack script (`TABLE_NAME table behavior`)
for the SQL Record's table. The function that will be called will be `TABLE_NAME_getPROP`.
For example, a custom property named `short description` for the `lessons` table would be defined as follows:

```
function lessons_getShortDescription pRecordA
  return char 1 to 35 of pRecordA["description"]
end lessons_getShortDescription
```

Returns: value
*/
function sqlrecord_get pRecordA, pProp
  local i
  local theError
  local theKeyA
  local theDudA
  local thePropIsARelatedTable = false

  if "@table" is not among the keys of pRecordA then
    _ThrowError kErrCantFindObject, "you must assign a valid table to a record"
  end if

  if char 1 of pProp is "@" then
    switch pProp
      case "@table"
      case "@passthru"
        return pRecordA[pProp]
      case "@connection"
        return _CreateConnectionArray(pRecordA["@connection"], pRecordA["@database"])
        break
      case "@database"
        local theKey

        put pRecordA[pProp] into theKey
        _ValidateKey theKey
        return pRecordA[pProp]theKey
        break
      default
        _ThrowError kErrInvalidProperty, pProp && "is not a valid SQL Record property"
    end switch

  else
    if pProp is among the keys of pRecordA then
      return pRecordA[pProp]
    else
      ## user defined property
      local theSanitizedProp, theCommand, theBehaviorStack

      put pProp into theSanitizedProp
      replace space with empty in theSanitizedProp
      put pRecordA["@table"] & "_get" & theSanitizedProp into theCommand
      put _tableBehaviorStackName(pRecordA["@table"]) into theBehaviorStack

      dispatch function theCommand to stack theBehaviorStack with pRecordA
      if it is "handled" then
        return the result
      end if

      ## prop doesn't exist
      _ThrowError kErrInvalidProperty, "'" & pProp & "' is not a valid property of the '" & pRecordA["@table"] & "' table object"
    end if
  end if
end sqlrecord_get


/**
Summary: Returns a boolean value specifying whether or not a column value passes through to the db when being inserted.

pRecordA: A SQL Record object.
pColumn: The name of the column to check.

Description:
When setting the value of a SQL Record column you can specify that the value should
be passed through to the database without quoting or escaping the value. This returns the setting for
a particular column.

Returns: Boolean
*/
function sqlrecord_columnPassesThru pRecordA, pColumn
  set the wholeMatches to true
  return pColumn is among the items of pRecordA["passthru"]
end sqlrecord_columnPassesThru


/**
Summary: Retrieves records from a table related to the Record object's table.

Parameters:
xRecordsA: Record array that you want to get the property for.
pTable: The table whose related records should be retrieved.

Description:
All records in pTable related to the record stored in xRecordsA will be retrieved
from the database and stored in `xRecordsA[TABLE_NAME]`.
Note that `xRecordsA` can be a numerically indexed array of Record arrays if you want
to retrieve related records for many records at once.

Returns: Error message
*/
command sqlrecord_getRelated @xRecordsA, pTable
  -----
  local theConnectionA, i
  local theError
  local theDudA
  -----

  if "@table" is among the keys of xRecordsA then
    put _CreateConnectionArray(xRecordsA["@connection"], xRecordsA["@database"]) into theConnectionA
  else if "@table" is among the keys of xRecordsA[1] then
    put _CreateConnectionArray(xRecordsA[1]["@connection"], xRecordsA[1]["@database"]) into theConnectionA
  else
    _ThrowError kErrCantFindObject, "you must assign a valid table to a record object"
  end if

  if "@table" is among the keys of xRecordsA then
    ## single record
    ## Get related table records
    _RetrieveRecordsRelatedtoRecord theConnectionA, xRecordsA, pTable
    put the result into theError
  else
    ## multiple records
    ## todo: Optimize with a single query that then puts results into the array
    repeat with i = 1 to the number of elements of xRecordsA
      if "@table" is not among the keys of xRecordsA[i] then
        _ThrowError kErrCantFindObject, "you must assign a valid table to a record object"
        -- put kInvalidType && "record" into theError
      else
        _RetrieveRecordsRelatedtoRecord theConnectionA, xRecordsA[i], pTable
        put the result into theError
      end if

      if theError is not empty then exit repeat
    end repeat
  end if

  return theError
end sqlrecord_getRelated


/**
Summary: Sets a property of a SQL Record object.

xRecordA: SQL Record object that you want to set the property for.
pProp: The property to set.
pValue: The value to set the property to.
pPassThru: Set to true if SQL Yoga should not quote and escape the value you set. This is useful when setting the value of an expression or a value like CURRENT_TIMESTAMP. Default is false.

Description:
`pProp` can be either a built-in property, a column in the SQL Record's table or a custom property
that you have defined in the Table Object for the SQL Record's table.

The built-in properties are:

| Property | Description |
| -------- |:----------- |
| `@table` | The name of the table to associate the SQL Record with. |
| `@database` | The name of the database object the SQL record is associated with. |
| `@connection` | The name of the database connection the SQL Record should use. |
| `@passthru` | A comma delimited list of fields that will not be escaped or quoted, but rather passed directly to the database as is. |

If pProp is not a built-in property or a column then it is assumed that it is a
custom property that you have defined in the table behavior stack script (`TABLE_NAME table behavior`)
for the SQL Record's table. The function that will be called will be `TABLE_NAME_setPROP`.
For example, a custom property named `search terms` for the `lessons` table would be defined as follows:

```
function lessons_setSearchTerms pRecordA, pValue
  ...
end lessons_setSearchTerms
```

Returns: Error message
*/
command sqlrecord_set @xRecordA, pProp, pValue, pPassThru
  local theConnectionA, theError
  local theValue

  put _CreateConnectionArray(xRecordA["@connection"], xRecordA["@database"]) into theConnectionA

  if char 1 of pProp is "@" then
    switch pProp
      case "@table"
      case "@passthru"
        put pValue into xRecordA[pProp]
        break
      case "@connection"
        put _CreateConnectionArray(pValue, xRecordA["@database"]) into xRecordA[pProp]
        break
      case "@database"
        _ValidateKey pValue
        _ValidateDBKeyExistence pValue
        put pValue into xRecordA[pProp]
        break
      default
        _ThrowError kErrInvalidProperty, pProp && "is not a valid SQL Record property"
    end switch

    return empty
  else
    if "@table" is not among the keys of xRecordA then
      _ThrowError kErrCantFindObject, "you must assign a valid table to a record"
    end if

    ## If pProp is a column in array then set normally
    if pProp is among the keys of xRecordA then
      local theItemNo

      put pValue into xRecordA[pProp]

      ## Update list of passthru fields
      set the wholeMatches to true
      put itemOffset(pProp, xRecordA["@passthru"]) into theItemNo
      if pPassThru then
        if theItemNo is 0 then
          put pProp into item (the number of items of xRecordA["@passthru"]) + 1 of xRecordA["@passthru"]
        end if
      else
        if theItemNo > 0 then
          delete item theItemNo of xRecordA["@passthru"]
        end if
      end if
    else
      local theSanitizedProp, theCommand, theBehaviorStack

      put pProp into theSanitizedProp
      replace space with empty in theSanitizedProp
      put xRecordA["@table"] & "_set" & theSanitizedProp into theCommand
      put _tableBehaviorStackName(xRecordA["@table"]) into theBehaviorStack

      dispatch command theCommand to stack theBehaviorStack with xRecordA, pValue
      if it is "handled" then
        return the result
      end if

      ## prop doesn't exist
      _ThrowError kErrInvalidProperty, "'" & pProp & "' is not a valid property of the '" & xRecordA["@table"] & "' table object"
    end if
  end if
end sqlrecord_set


private command _FillInTableRecordFromDatabase pConnectionA, @xRecordsA, pUsePrimaryKeysOnly, pDynamicKeyA
  -----
  local i
  local isValidField
  local theError
  local theFieldIndex, theFieldName
  local theNextIndex
  local theQueryA
  local theTableA
  local theTableKeyA
  local theWhere
  local usingArray
  local theBindingsA
  -----
  put pDynamicKeyA is an array into usingArray
  put the number of elements of pDynamicKeyA + 1 into theNextIndex

  if pUsePrimaryKeysOnly then
    local thePrimaryKey

    put "@table" into pDynamicKeyA[theNextIndex]

    # Just get table record based on primary key
    if tableobjects_tableExists(xRecordsA[pDynamicKeyA], pConnectionA["database"]) then
      put tableobjects_getTable(xRecordsA[pDynamicKeyA], pConnectionA["database"]) into theTableA
      put _KeyArrayForTable(theTableA) into theTableKeyA
      put tableobj_get(theTableA, "primary key") into thePrimaryKey
    else
      put sDbsA[ pConnectionA["database"] ]["schema"]["tables"][ xRecordsA[pDynamicKeyA] ]["primary key"] into thePrimaryKey
    end if
    delete local pDynamicKeyA[theNextIndex]

    repeat for each item theFieldName in thePrimaryKey
      if not usingArray then put theFieldName is among the keys of xRecordsA into isValidField
      else put theFieldName is among the keys of xRecordsA[pDynamicKeyA] into isValidField

      if not isValidField then
        _ThrowError kErrCantFindObject, "primary key field '" & theFieldName & "' is not in table '" & xRecordsA[pDynamicKeyA] & "' record" --& cr & the executioncontexts
      end if

      put theFieldName into pDynamicKeyA[theNextIndex]
      put theFieldName && "=" && xRecordsA[pDynamicKeyA] & " AND " after theWhere
    end repeat
    delete the last word of theWhere

  else
    ## Use all columns provided
    if usingArray then
      repeat for each key theColumn in xRecordsA[pDynamicKeyA]
        if char 1 of theColumn is "@" then next repeat
        add 1 to i
        put theColumn && "=" && ":" & i & " AND " after theWhere
        put xRecordsA[pDynamicKeyA][theColumn] into theBindingsA[i]
      end repeat
    else
      repeat for each key theColumn in xRecordsA
        if char 1 of theColumn is "@" then next repeat
        add 1 to i
        put theColumn && "=" && ":" & i & " AND " after theWhere
        put xRecordsA[theColumn] into theBindingsA[i]
      end repeat
    end if
    delete the last word of theWhere
  end if

  put "@table" into pDynamicKeyA[theNextIndex]
  put _CreateSQLQueryFromTable(pConnectionA, xRecordsA[pDynamicKeyA]) into theQueryA
  if theBindingsA is an array then
    sqlquery_set theQueryA, "conditions", theWhere, theBindingsA
  else
    sqlquery_set theQueryA, "conditions", theWhere
  end if

  if theError is empty then
    sqlquery_retrieve theQueryA
    put the result into theError
  end if

  if theError is empty then
    local theRecordA

    sqlquery_convertToRecords theQueryA, theRecordA
    put the result into theError

    sqlquery_close theQueryA

    if theRecordA is not an array then
      put "no matching record found" into theError
    end if
  end if

  if theError is empty then
    put theRecordA[1] into theRecordA
    if the keys of theRecordA is not empty then
      put xRecordsA[pDynamicKeyA] into theRecordA["@table"]
    end if

    if usingArray then
      delete local pDynamicKeyA[theNextIndex]
      put theRecordA into xRecordsA[pDynamicKeyA]
    else
      put theRecordA into xRecordsA
    end if
  end if

  return theError
end _FillInTableRecordFromDatabase


private command _RetrieveRecordsRelatedtoRecord pConnectionA, @xRecordA, pRelatedTable
  -----
  local theArrayTableKey, theCrossRefPropKeys, theCrossRefRecordKeys, theDBKey, thePropKeyFields, theRecordKeyFields
  local theCrossRefTable
  local theDataA
  local theDbType
  local theError
  local theField, theFieldEntry
  local theJoinA
  local theQueryA
  local theRecordTable
  local theRelationA
  local theTable1A, theTable2A
  local theWhere, theFind, theOrderBy
  -----
  put xRecordA["@table"] into theRecordTable
  put pConnectionA["database"] into theDBKey

  if theError is empty then
    put dbconn_get("type", pConnectionA) into theDbType
  end if

  ## Find relationship
  if theError is empty then
    put kTableReference into theTable1A["type"]
    put pConnectionA["database"] into theTable1A["database"]
    put theRecordTable into theTable1A["name"]
    put kTableReference into theTable2A["type"]
    put pConnectionA["database"] into theTable2A["database"]
    put pRelatedTable into theTable2A["name"]
    put _FindRelationshipBetweenTables(theTable1A, theTable2A) into theRelationA

    ## Filter could return empty if the record didn't contain a matching field
    if theRelationA is not an array or the number of elements of theRelationA > 1 then ## we don't support relationships more than 1 away
      put "'" & pRelatedTable & "' is not directly related to '" & theRecordTable & "'" into theError
    else
      put theRelationA[1] into theRelationA
    end if
  end if

  ## Build WHERE
  if theError is empty then
    put pConnectionA["name"] into theRelationA["connection"] ## in order to get db quotes for field=value keys
    put tblrelation_get(theRelationA, "order by") into theOrderBy

    if tblrelation_get(theRelationA, "type") is among the items of "n-n,many-to-many" then
      put tblrelation_get(theRelationA, "cross-reference table") into theCrossRefTable

      if pRelatedTable is tblrelation_get(theRelationA, "left table") then
        ## extract right table key from xRecordA and assign to left table key in search
        put tblrelation_get(theRelationA, "right table key") into theRecordKeyFields
        put tblrelation_get(theRelationA, "left table key") into thePropKeyFields
        if theRecordTable is not theCrossRefTable then
          put tblrelation_get(theRelationA, "cross-reference table key for left table") into theCrossRefPropKeys
          put tblrelation_get(theRelationA, "cross-reference table key for right table") into theCrossRefRecordKeys
        else
          # If the record table is the cross-ref table then skip the join and flatten the result
          put tblrelation_get(theRelationA, "cross-reference table key for left table") into theRecordKeyFields
          put empty into theOrderBy
          put "first" into theFind
        end if

      else if pRelatedTable is tblrelation_get(theRelationA, "right table") then
        ## extract right table key from xRecordA and assign to left table key in search
        put tblrelation_get(theRelationA, "left table key") into theRecordKeyFields
        put tblrelation_get(theRelationA, "right table key") into thePropKeyFields
        if theRecordTable is not theCrossRefTable then
          put tblrelation_get(theRelationA, "cross-reference table key for right table") into theCrossRefPropKeys
          put tblrelation_get(theRelationA, "cross-reference table key for left table") into theCrossRefRecordKeys
        else
          # If the record table is the cross-ref table then skip the join and flatten the result
          put tblrelation_get(theRelationA, "cross-reference table key for right table") into theRecordKeyFields
          put empty into theOrderBy
          put "first" into theFind
        end if

      else
        ## the cross-ref table
        if theRecordTable is tblrelation_get(theRelationA, "left table") then
          put tblrelation_get(theRelationA, "left table key") into theRecordKeyFields
          put tblrelation_get(theRelationA, "cross-reference table key for left table") into thePropKeyFields
        else
          put tblrelation_get(theRelationA, "right table key") into theRecordKeyFields
          put tblrelation_get(theRelationA, "cross-reference table key for right table") into thePropKeyFields
        end if
      end if

    else
      if pRelatedTable is tblrelation_get(theRelationA, "left table") then
        ## extract right table key from xRecordA and assign to left table key in search
        put tblrelation_get(theRelationA, "right table key") into theRecordKeyFields
        put tblrelation_get(theRelationA, "left table key") into thePropKeyFields

      else -- if pRelatedTable is tblrelation_get(theRelationA, "right table") then
        ## extract right table key from xRecordA and assign to left table key in search
        put tblrelation_get(theRelationA, "left table key") into theRecordKeyFields
        put tblrelation_get(theRelationA, "right table key") into thePropKeyFields
      end if

    end if
  end if

  if theError is empty then
    local tField

    if theCrossRefRecordKeys is not empty then
      local theResolvedCrossRefTable, i

      ## Requires a JOIN
      put _ResolvedTableName( pConnectionA["database"], theCrossRefTable) into theResolvedCrossRefTable

      repeat for each item theFieldEntry in theCrossRefRecordKeys
        add 1 to i
        put theFieldEntry into theField
        split theField by "=" ## in case of field=value key

        if the number of elements of theField is 2 then
          put theCrossRefTable & "." & theField[1] && "=" && "'" & _EscapeDbString(theDbType, theField[2]) & "'" & " AND " after theWhere
        else
          put item i of theRecordKeyFields into tField
          if xRecordA[tField] is empty then
            put "key field '" & tField &"' was not found in the record" into theError
          else
            if sDbsA[ pConnectionA["database"] ]["schema"]["tables"][ theResolvedCrossRefTable ]["fields"][ theField[1] ]["meta type"] \
                  is not among the items of kDontQuoteTypes then
              put theCrossRefTable & "." & theField[1] & " = " & "'" & _EscapeDbString(theDbType, xRecordA[tField]) & "'" & " AND " after theWhere
            else
              put theCrossRefTable & "." & theField[1] & " = " & xRecordA[tField] & " AND " after theWhere
            end if
          end if
        end if
        if theError is not empty then exit repeat
      end repeat
      delete the last word of theWhere

      put _CreateSQLQueryFromTable(pConnectionA, theCrossRefTable) into theQueryA
      put pRelatedTable into theJoinA[1]["table"]["name"]
      put theRelationA["index"] into theJoinA[1]["relationship index"]
      put "inner" into theJoinA[1]["join type"]
      sqlquery_set theQueryA, "related table joins", theJoinA

      put theCrossRefTable into theArrayTableKey

    else
      ## No JOIN
      local theResolvedRelatedTable

      put _ResolvedTableName( pConnectionA["database"], pRelatedTable) into theResolvedRelatedTable
      repeat for each item theFieldEntry in thePropKeyFields
        add 1 to i
        put theFieldEntry into theField
        split theField by "=" ## in case of field=value key

        if the number of elements of theField is 2 then
          put pRelatedTable & "." & theField[1] && "=" && "'" & _EscapeDbString(theDbType, theField[2]) & "'" & " AND " after theWhere
        else
          put item i of theRecordKeyFields into tField
          if xRecordA[tField] is empty then
            put "key field '" & item i of theRecordKeyFields &"' was not found in the record" into theError
          else
            if sDbsA[ pConnectionA["database"] ]["schema"]["tables"][ theResolvedRelatedTable ]["fields"][ theField[1] ]["meta type"] \
                  is not among the items of kDontQuoteTypes then
              put pRelatedTable & "." & theField[1] & " = " & "'" & _EscapeDbString(theDbType, xRecordA[tField]) & "'" & " AND " after theWhere
            else
              put pRelatedTable & "." & theField[1] & " = " & xRecordA[tField] & " AND " after theWhere
            end if
          end if
        end if
        if theError is not empty then exit repeat
      end repeat
      delete the last word of theWhere

      put _CreateSQLQueryFromTable(pConnectionA, pRelatedTable) into theQueryA
      put pRelatedTable into theArrayTableKey
    end if
  end if

  ## Execute
  if theError is empty then
    sqlquery_set theQueryA, "order by", theOrderBy
    sqlquery_set theQueryA, "conditions", theWhere
    sqlquery_set theQueryA, "find", theFind
    sqlquery_set theQueryA, "column names length", "long"
    put true into theQueryA["ignore alias conditions"] ## internal property as relationships already contain alias WHERE
    sqlquery_retrieve theQueryA
    put the result into theError
  end if

  if theError is empty then
    put empty into theDataA
    sqlquery_convertToRecords theQueryA, theDataA
    put the result into theError

    sqlquery_close theQueryA
  end if

  ## Store in table subkey
  if theError is empty then
    put theDataA into xRecordA[theArrayTableKey]
  end if

  return theError
end _RetrieveRecordsRelatedtoRecord


/**
Summary: Updates records in a database using a SQL Record object.

Parameters:
xRecordsA: SQL Record object/array of SQL Record objects (numerically indexed) that has the primary key column for each record filled in along with any columns whose values you want to set.
pRefreshRecords: Pass in true to refresh the record objects with new data.

Description:
This command updates records in the database based on the SQL Record objects you pass in. Note that the primary key
column will NOT be updated.

Update callbacks in your Table Object definitions will be called and
broadcasts will be sent to callbacks during this operation.

Example:
sqlrecord_find "lessons", theID, theRecordA
sqlrecord_set theRecordA, "title", "A new title"
sqlrecord_update theRecordA

Returns:
it: Number of affected rows
the result: Error message

References: sqlrecord_find (command)
*/
command sqlrecord_update @xRecordsA, pRefreshRecords
  -----
  local i,theQs, theTablesA
  local theConnectionA
  local theAffectedRows
  local theError
  local theTablesIndexA
  local rethrowTheError
  -----

  put pRefreshRecords is true into pRefreshRecords

  if "@table" is among the keys of xRecordsA then
    put _CreateConnectionArray(xRecordsA["@connection"], xRecordsA["@database"]) into theConnectionA
  else if "@table" is among the keys of xRecordsA[1] then
    put _CreateConnectionArray(xRecordsA[1]["@connection"], xRecordsA[1]["@database"]) into theConnectionA
  else
    _ThrowError kErrCantFindObject, "you must assign a valid table to a record object"
  end if

  put dbconn_get("effective quotes", theConnectionA) into theQs

  put empty into theTablesA
  _SplitRecordsIntoTablesIndex theConnectionA, xRecordsA, theTablesA, true
  put the result into theError

  ## We now have an array of:
  ## TABLE 'primary key'
  ## TABLE 'fields'
  ## TABLE 'records' INDEX FIELD1
  ## TABLE 'records' INDEX FIELD2
  local theTransA

  put _internalTransactionName() into theTransA["name"]
  dbconn_beginTransaction theTransA, theConnectionA
  put the result into theError
  put 0 into theAffectedRows

  ##
  ##
  ## NOTE:
  ## Currently we only support updating the root record. If you pass in nested
  ## records they are ignored.
  ## As an update we should find these records and process them, adding relationship field values
  ## as we go.
  ##
  ##
  try
    if theError is empty then
      if "@table" is among the keys of xRecordsA then
        ## single record
        _UpdateRecordInTable theConnectionA, theQs, theTablesA, xRecordsA, pRefreshRecords, true
        put the result into theError
        put it into theAffectedRows
      else
        ## multiple records
        repeat with i = 1 to the number of elements of xRecordsA
          if "@table" is not among the keys of xRecordsA[i] then
            put kInvalidType && "record" into theError
          else
            _UpdateRecordInTable theConnectionA, theQs, theTablesA, xRecordsA[i], pRefreshRecords, true
            put the result into theError

            if theError is empty then
              add it to theAffectedRows
            end if
          end if

          if theError is not empty then exit repeat
        end repeat
      end if
    end if
  catch e
    put e into theError
    put true into rethrowTheError
  end try

  if theError is empty then
    dbconn_commitTransaction theTransA, theConnectionA
    return theAffectedRows for value
  else
    dbconn_rollbackTransaction theTransA, theConnectionA
    if rethrowTheError then throw theError
    else return theError for error
  end if
end sqlrecord_update


private command _UpdateRecordInTable pConnectionA, pQuotesA, pTablesA, @xRecordA, pUpdateRecordAfterUpdate, pSendCallbacks
  -----
  local i,theSQL, theType, isBoolean
  local theAffectedRows
  local theBaseSQL
  local theBindingsA
  local theError
  local theField, theFields
  local theKeysWithChildRecords
  local theNextKeyIndex
  local thePrimaryKeys
  local theTable
  local theTableKey
  local theTablesIndexA
  local theUpdateClause
  local theWhere
  -----

  put pSendCallbacks is true into pSendCallbacks
  put xRecordA["@table"] into theTable

  ## VALIDATION CALLBACKS
  _dispatchValidationCheck xRecordA, "update"
  put the result into theError
  put the keys of xRecordA into theFields

  ## Validation error, prefix with something
  if theError is not empty then
    -- ... Should library prefix or just pass through the error message?
  end if

  if theError is empty then
    filter theFields without "@*"

    ## Error checking
    if the number of items of pTablesA[ theTable ]["primary key"] < 1 \
          and "@where" is not among the keys of xRecordA then
      _ThrowError kErrInvalidProperty, "cannot update table '" & theTable & "' as no primary key is defined"
      -- put "cannot update table '" & theTable & "' as no primary key is defined" into theError
    end if
  end if

  if theError is empty and pSendCallbacks then
    _dispatchTableObjectEventListener theTable, pConnectionA, "before update", xRecordA
    put the result into theError
  end if

  if theError is empty then
    ## Perform UPDATE
    put "UPDATE %s%s%s SET %s" into theBaseSQL

    ## WHERE clause
    put dbconn_get("type", pConnectionA) into theType
    repeat for each item theField in pTablesA[ theTable ]["primary key"]
      put sDbsA[ pConnectionA["database"] ]["schema"]["tables"][ theTable ]["fields"][ theField ]["meta type"] is "boolean" into isBoolean

      ## Strings like '01' are reported as integers so make sure and check defined type.
      if sDbsA[ pConnectionA["database"] ]["schema"]["tables"][ theTable ]["fields"][ theField ]["meta type"] is not among the items of kDontQuoteTypes then
        put pQuotesA["left"] & theField & pQuotesA["right"] & " = '" & _EscapeDbString(theType, xRecordA[theField]) & "' AND " after theWhere
      else
        if isBoolean then put pQuotesA["left"] & theField & pQuotesA["right"] & " = " & _getBooleanValue(xRecordA[theField], pConnectionA) & " AND " after theWhere
        else put pQuotesA["left"] & theField & pQuotesA["right"] & " = " & xRecordA[theField] & " AND " after theWhere
      end if

      put theField & comma after thePrimaryKeys
    end repeat
    delete the last word of theWhere
    delete the last char of thePrimaryKeys

    ## sqlquery_update passes in a WHERE clause as it can be more complex
    if "@where" is among the keys of xRecordA then
      put xRecordA["@where"] into theWhere
    end if

    local thePassThruFields, theMetaType, theConnType
    local theFieldIndex

    put xRecordA["@passthru"] into thePassThruFields
    set the wholeMatches to true

    ## UPDATE clause
    repeat for each line theField in theFields
      if theField is among the items of thePrimaryKeys then next repeat
      if theField is not among the items of pTablesA[ theTable ]["fields"] then
        if xRecordA[ theField ] is an array then
          ## This is a list of fields that are possible related record arrays.
          ## After we finish updating this record we need to find the
          ## relationship between the two, add the forign key field value
          ## and update the record. Just make recursive call.
          put theField & comma after theKeysWithChildRecords
        end if
        next repeat
      end if

      put sDbsA[ pConnectionA["database"] ]["schema"]["tables"][ theTable ]["fields"][ theField ]["meta type"] is "boolean" into isBoolean
      put sDbsA[ pConnectionA["database"] ]["schema"]["tables"][ theTable ]["fields"][ theField ]["meta type"] into theMetaType
      put dbconn_get("type", pConnectionA) into theConnType

      if xRecordA[theField] is NULL OR (theConnType is "sql server" AND theMetaType is among the items of "text,binary,decimal" AND xRecordA[theField] is empty) then
        ## ODBC (at least with SQL Server) will not take an empty string in columns that are character, decimal or binary
        put pQuotesA["left"] & theField & pQuotesA["right"] & " = NULL" & comma after theUpdateClause
      else if theField is among the items of thePassThruFields then
        ## some fields just pass through values to the db
        if isBoolean then put pQuotesA["left"] & theField & pQuotesA["right"] & " = " & _getBooleanValue(xRecordA[theField], pConnectionA) & "," after theUpdateClause
        else put pQuotesA["left"] & theField & pQuotesA["right"] & " = " & xRecordA[theField] & comma after theUpdateClause
      else
        add 1 to theFieldIndex
        put pQuotesA["left"] & theField & pQuotesA["right"] & " = " & ":" & theFieldIndex & comma after theUpdateClause

        if sDbsA[ pConnectionA["database"] ]["schema"]["tables"][ theTable ]["fields"][ theField ]["meta type"] is "binary" then
          put xRecordA[theField] into theBindingsA["*b" & theFieldIndex]
        else
          if isBoolean then put _getBooleanValue(xRecordA[theField], pConnectionA) into theBindingsA[theFieldIndex]
          else put xRecordA[theField] into theBindingsA[theFieldIndex]
        end if
      end if
    end repeat
    delete the last char of theUpdateClause
    delete the last char of theKeysWithChildRecords

    put format(theBaseSQL, pQuotesA["left"], theTable, pQuotesA["right"], theUpdateClause) into theSQL
    if theWhere is not empty then
      put " WHERE " & theWhere after theSQL
    end if
    dbconn_executeWBindings theSQL, theBindingsA, pConnectionA
    put the result into theError
    put it into theAffectedRows
  end if

  ## Fetch record from db and put back into array
  if theError is empty \
        and pUpdateRecordAfterUpdate \
        and pTablesA[ theTable ]["primary key"] is not empty then
    local theOutRecordA

    _RetrieveUpdatedRecordAfterDbMod theOutRecordA, pConnectionA, xRecordA, pTablesA[ theTable ]["primary key"]
    put the result into theError

    if theError is empty then
      delete local xRecordA["@passthru"]

      ## Update record one field at a time so we don't overwrite any related tables
      repeat for each key theField in theOutRecordA
        put theOutRecordA[theField] into xRecordA[theField]
      end repeat
    end if
  end if

  if theError is empty and pSendCallbacks then
    _dispatchTableObjectEventListener theTable, pConnectionA, "after update", xRecordA
    put the result into theError
  end if

  ## Recursively process any children records
  if theError is empty then
    local theTablesA

    repeat for each item theTableKey in theKeysWithChildRecords
      put empty into theTablesIndexA
      _SplitRecordsIntoTablesIndex pConnectionA, xRecordA[theTableKey], theTablesA, true, theTable
      put the result into theError

      if theError is empty then
        if line 1 of the keys of xRecordA[ theTableKey ] is an integer then
          ## array of records
          repeat with i = 1 to the number of elements of xRecordA[ theTableKey ]
            if "@table" is among the keys of xRecordA[ theTableKey ][i] then
              _UpdateRecordInTable pConnectionA, pQuotesA, theTablesA, xRecordA[ theTableKey ][i], pUpdateRecordAfterUpdate, pSendCallbacks
              put the result into theError
            end if
            if theError is not empty then exit repeat
          end repeat
        else
          ## just a record
          if "@table" is among the keys of xRecordA[ theTableKey ] then
            _UpdateRecordInTable pConnectionA, pQuotesA, theTablesA, xRecordA[ theTableKey ], pUpdateRecordAfterUpdate, pSendCallbacks
            put the result into theError
          end if
        end if
      end if

      if theError is not empty then exit repeat
    end repeat
  end if

  if theError is not empty then
    return theError for error
  else
    return theAffectedRows for value
  end if
end _UpdateRecordInTable


/**
Summary: Dispatches callback messages associated with a table.

Parameters:
pTable: Name of table.
pConnectionA: The active connection.
pCallbackKey: The callback key to use (e.g. `before delete`)
xRecordA: The record that is being acted on. Callback may modify the record.

Returns: Error message

*/
private command _dispatchTableObjectEventListener pTable, pConnectionA, pCallbackType, @xRecordA
  local tError, tBehaviorStack, tCallbackHandler

  put _tableBehaviorStackName(pTable) into tBehaviorStack

  if there is a stack tBehaviorStack then
    put _tableCallbackHandlerName(pTable, pCallbackType) into tCallbackHandler

    dispatch tCallbackHandler to stack tBehaviorStack with xRecordA, pConnectionA
    if it is "handled" then
      put the result into tError
    end if
  end if

  return tError
end _dispatchTableObjectEventListener


private command _dispatchValidationCheck @xRecordA, pEventType
  local tError, tBehaviorStack, tCallbackHandler

  put _tableBehaviorStackName(xRecordA["@table"]) into tBehaviorStack
  put _tableCallbackHandlerName(xRecordA["@table"], "validate") into tCallbackHandler

  if there is a stack tBehaviorStack then
    dispatch tCallbackHandler to stack tBehaviorStack with xRecordA, pEventType
    if it is "handled" then
      put the result into tError
    end if
  end if

  return tError
end _dispatchValidationCheck


private function _tableBehaviorStackName pTable
  return pTable && "table" && "behavior"
end _tableBehaviorStackName


private function _tableCallbackHandlerName pTable, pCallbackType
  replace space with empty in pCallbackType
  return pTable & "_" & pCallbackType
end _tableCallbackHandlerName


/**
Summary This handler takes a records arrays and splits it up based on tables.

pConnectionA:
xRecordsA:
@rTablesA:
pEnforceKeyPresence:
pParentTableKey:

Description:
When done `rTablesA` will have keys for each table represented in `xRecordsA`. Each
table in turn has an index, records, fields and primary key entry. The records
entry is an integer indexed array of the records to in the table with the
value of the primary key field(s).

Note: If table has no `primary key` field(s) defined then all included fields will be used as primary key.
this supports `through` tables that might not have primary key defined.

Example:
steps
  index: 7
  records
    1
      id: 1
      primary key
        1
          field index: 4
          value:
          field name: id
      fields: id,instructions,lesson_id,title

Returns: Error message
*/
private command _SplitRecordsIntoTablesIndex pConnectionA, @xRecordsA, @rTablesA, pEnforceKeyPresence, pParentTableKey
  -----
  local isAnArray, isSingleRecord, theNextIndex, i
  local theError
  local theTable, theField
  local thePrimaryKey, theIndex
  local theCount, theKeys
  local theTableA, theLookupKeyA, tLookupIndex
  -----
  put kTableReference into theTableA["type"]
  put "@table" is among the keys of xRecordsA into isSingleRecord

  # If dealing with nested records then build the array index key using the existing
  # parent table array index.
  if pParentTableKey is not empty then
    put rTablesA[pParentTableKey] into theLookupKeyA
    put pParentTableKey into theLookupKeyA[ the number of elements of theLookupKeyA + 1 ]
  end if
  put the number of elements of theLookupKeyA + 1 into tLookupIndex

  if isSingleRecord then
    ## single record
    put xRecordsA["@table"] into theTable

    put theTable into rTablesA[ theTable ]["name"]
    if tableobjects_tableExists(theTable, pConnectionA["database"]) then
      put tableobjects_getTable(theTable, pConnectionA["database"]) into theTableA
      put tableobj_get(theTableA, "primary key") into rTablesA[ theTable ]["primary key"]
      put tableobj_get(theTableA, "fields") into rTablesA[ theTable ]["fields"]
    else
      put sDbsA[ pConnectionA["database"] ]["schema"]["tables"][ theTable ]["primary key"] into rTablesA[ theTable ]["primary key"]
      put dbschema_tableGet(theTable, "fields", pConnectionA["database"]) into rTablesA[ theTable ]["fields"]
    end if
    replace cr with comma in rTablesA[ theTable ]["fields"]
    put 1 into theIndex

    ## So others can look up entry in xRecordsA
    put theLookupKeyA into rTablesA[ theTable ]["records"][theIndex]["index array"]

    ## No primary key defined for table?
    ## Use all included fields
    put rTablesA[ theTable ]["primary key"] into thePrimaryKey
    if thePrimaryKey is empty then
      repeat for each item theFieldName in rTablesA[ theTable ]["fields"]
        if theFieldName is among the keys of xRecordsA then
          put theFieldName & comma after thePrimaryKey
        end if
      end repeat
      delete the last char of thePrimaryKey
    end if

    repeat for each item theFieldName in thePrimaryKey
      if pEnforceKeyPresence and \
            theFieldName is not among the keys of xRecordsA then
        put "primary key field '" & theFieldName & "' was not found in the record array" into theError
      else
        put xRecordsA[theFieldName] into rTablesA[ theTable ]["records"][theIndex][theFieldName]
      end if
    end repeat

  else
    ## Multiple records
    put the number of elements of xRecordsA into theCount
    repeat with i = 1 to theCount

      put xRecordsA[i]["@table"] into theTable

      put i into theLookupKeyA[tLookupIndex]

      if theTable is empty then put kInvalidType && "record" into theError
      add 1 to theIndex

      if theError is empty then
        put theTable into rTablesA[ theTable ]["name"]
        if tableobjects_tableExists(theTable, pConnectionA["database"]) then
          put tableobjects_getTable(theTable, pConnectionA["database"]) into theTableA
          put tableobj_get(theTableA, "primary key") into rTablesA[ theTable ]["primary key"]
          put tableobj_get(theTableA, "fields") into rTablesA[ theTable ]["fields"]
        else
          put sDbsA[ pConnectionA["database"] ]["schema"]["tables"][ theTable ]["primary key"] into rTablesA[ theTable ]["primary key"]
          put dbschema_tableGet(theTable, "fields", pConnectionA["database"]) into rTablesA[ theTable ]["fields"]
        end if
        replace cr with comma in rTablesA[ theTable ]["fields"]

        ## So others can look up entry in xRecordsA
        put theLookupKeyA into rTablesA[ theTable ]["records"][theIndex]["index array"]

        ## No primary key defined for table?
        ## Use all included fields
        put rTablesA[ theTable ]["primary key"] into thePrimaryKey
        if thePrimaryKey is empty then
          repeat for each item theFieldName in rTablesA[ theTable ]["fields"]
            if theFieldName is among the keys of xRecordsA[i] then
              put theFieldName & comma after thePrimaryKey
            end if
          end repeat
          delete the last char of thePrimaryKey
        end if

        repeat for each item theFieldName in thePrimaryKey
          if pEnforceKeyPresence and theFieldName is not among the keys of xRecordsA[i] then
            put "primary key field '" & theFieldName & "' was not found in the record array" into theError
          else
            put xRecordsA[i][theFieldName] into rTablesA[ theTable ]["records"][theIndex][theFieldName]
          end if
        end repeat
      end if

      if theError is not empty then exit repeat
    end repeat
  end if

  return theError
end _SplitRecordsIntoTablesIndex


/**
Summary: Deletes records in a database using the Record array(s) passed in.

Parameters:
xRecordsA: Records array/array of Record arrays (numerically indexed) that has the primary key column for each record filled in.

Description:
This command deletes records from the database based on the Record array(s) passed in.

Delete callbacks in your Table Object definitions will be called and
broadcasts will be sent to callbacks during this operation.

After this handler completes xRecordsA will only contain SQL Record(s) with the`"@table` key.
Other keys will have been removed since the data no longer exists in the database.

Example:
## Find lesson record in db with id of 12 and store in theRecordA
sqlrecord_find "lessons", 12, theRecordA

sqlrecord_delete theRecordA
put the result into theError

Returns:
it: Number of affected rows
the result: Error message
*/
command sqlrecord_delete @xRecordsA
  -----
  local i,j,theIds, theConnectionA
  local theAffectedRows, theBaseSQL
  local theError
  local theFields
  local theFieldName
  local theQs,theSQL
  local theTable, theTableA, theTablesA
  local theWhere, theTransA
  local rethrowTheError
  -----

  if "@table" is among the keys of xRecordsA then
    put _CreateConnectionArray(xRecordsA["@connection"], xRecordsA["@database"]) into theConnectionA
  else if "@table" is among the keys of xRecordsA[1] then
    put _CreateConnectionArray(xRecordsA[1]["@connection"], xRecordsA[1]["@database"]) into theConnectionA
  else
    _ThrowError kErrCantFindObject, "you must assign a valid table to a record object"
  end if

  put dbconn_get("effective quotes", theConnectionA) into theQs

  _SplitRecordsIntoTablesIndex theConnectionA, xRecordsA, theTablesA, true
  put the result into theError

  ## We now have an array of:
  ## TABLE 'primary key'
  ## TABLE 'fields'
  ## TABLE 'records' INDEX FIELD1
  ## TABLE 'records' INDEX FIELD2
  put _internalTransactionName() into theTransA["name"]
  dbconn_beginTransaction theTransA, theConnectionA
  put the result into theError

  try
    local theType

    if theError is empty then
      repeat for each key theTable in theTablesA
        if tableobjects_tableExists(theTable, theConnectionA["database"]) then
          put tableobjects_getTable(theTable, theConnectionA["database"]) into theTableA
        end if

        put "DELETE FROM %s%s%s WHERE " into theBaseSQL
        put format(theBaseSQL, theQs["left"], theTable, theQs["right"]) into theBaseSQL

        ## One delete at a time until we can confirm if RevDB supports multiple statements at once
        repeat with i = 1 to the number of elements of theTablesA[theTable]["records"]
          ## Build where statement
          put empty into theWhere
          put dbconn_get("type", theConnectionA) into theType

          ## Take into account 'through' table for many-to-many that might not
          ## have primary key defined
          if theTablesA[theTable]["primary key"] is not empty then
            ## Verify that all primary key fields are included
            ## If not use all included fields
            repeat for each item theFieldName in theTablesA[theTable]["primary key"]
              if theFieldName is not among the items of theTablesA[theTable]["fields"] then
                put theTablesA[theTable]["fields"] into theFields
                exit repeat
              end if
            end repeat

            ## All primary keys are present. Use them.
            if theFields is empty then
              put theTablesA[theTable]["primary key"] into theFields
            end if
          else
            put theTablesA[theTable]["fields"] into theFields
          end if

          local isBoolean, theRecordIndexArray

          ## So we can look up record
          put theTablesA[theTable]["records"][i]["index array"] into theRecordIndexArray

          ## Loop through fields being used to uniquly identify record
          repeat for each item theFieldName in theFields
            ## Strings like '01' are reported as integers. Make sure and check defined type.
            if sDbsA[ theConnectionA["database"] ]["schema"]["tables"][ theTable ]["fields"][ theFieldName ]["meta type"] is not among the items of kDontQuoteTypes then
              -- if theTablesA[theTable]["records"][i][theFieldName] is not an integer then
              put theQs["left"] & theFieldName & theQs["right"] & \
                    " = '" & _EscapeDbString(theType, theTablesA[theTable]["records"][i][theFieldName]) & "' AND " after theWhere
            else
              put sDbsA[ theConnectionA["database"] ]["schema"]["tables"][ theTable ]["fields"][ theFieldName ]["meta type"] into isBoolean

              if isBoolean then put theQs["left"] & theFieldName & theQs["right"] & " = " & _getBooleanValue(xRecordsA[theRecordIndexArray], theConnectionA) & " AND " after theWhere
              put theQs["left"] & theFieldName & theQs["right"] & " = " & theTablesA[theTable]["records"][i][theFieldName] & " AND " after theWhere
            end if
          end repeat
          delete the last word of theWhere
          put theBaseSQL & theWhere into theSQL

          ##
          ## Before callbacks
          ##
          if theTableA is an array then
            if theRecordIndexArray is an array then
              _dispatchTableObjectEventListener theTable, theConnectionA, "before delete", xRecordsA[theRecordIndexArray]
            else
              _dispatchTableObjectEventListener theTable, theConnectionA, "before delete", xRecordsA
            end if
            put the result into theError
          end if

          if theError is empty then
            dbconn_executeSQL theSQL, theConnectionA
            put the result into theError
            add it to theAffectedRows

            if theError is empty then
              if theTableA is an array then
                if theRecordIndexArray is an array then
                  _dispatchTableObjectEventListener theTable, theConnectionA, "after delete", xRecordsA[theRecordIndexArray]
                else
                  _dispatchTableObjectEventListener theTable, theConnectionA, "after delete", xRecordsA
                end if
                put the result into theError
              end if
            end if

            ## Clear out SQL Record object
            if theError is empty then
              get theTablesA[theTable]["records"][i]["index array"]
              if it is an array then
                put empty into xRecordsA[it]
                put theTable into xRecordsA[it]["@table"]
              else
                put empty into xRecordsA
                put theTable into xRecordsA["@table"]
              end if
            end if
          end if

          if theError is not empty then exit repeat
        end repeat

        if theError is not empty then exit repeat
      end repeat
    end if
  catch e
    put e into theError
    put true into rethrowTheError
  end try

  if theError is empty then
    dbconn_commitTransaction theTransA, theConnectionA
    return theAffectedRows for value
  else
    dbconn_rollbackTransaction theTransA, theConnectionA
    if rethrowTheError then throw theError
    else return theError for error
  end if
end sqlrecord_delete


/**
Summary: Creates records in a database using a SQL Record object.

Parameters:
xRecordsA: SQL Records object/array of SQL Record objects (numerically indexed).
pRefreshRecords: Pass in `false` if you do not want to refresh the records with data from the database after you create them.

Description:
This command creates records in the database based on the SQL Record object you pass in.

If you pass in empty values for any of the fields in the primary key for the table then they \
will not be included in the `CREATE` statement.

Example:
put sqlrecord_createObject("lessons") into theRecordA
sqlrecord_set theRecordA, "title", "A new title"
sqlrecord_set theRecordA, "description", "It's a description."
sqlrecord_create theRecordA
put the result into theError

## theRecordA["id"] is now filled in with new id in database for this record

Returns:
it: Number of affected rows
the result: Error message
*/
command sqlrecord_create @xRecordsA, pRefreshRecords
  -----
  local i,theQs
  local theConnectionA, theTablesA
  local theAffectedRows
  local theError
  local rethrowTheError
  -----

  put pRefreshRecords is not false into pRefreshRecords

  if "@table" is among the keys of xRecordsA then
    put _CreateConnectionArray(xRecordsA["@connection"], xRecordsA["@database"]) into theConnectionA
  else if "@table" is among the keys of xRecordsA[1] then
    put _CreateConnectionArray(xRecordsA[1]["@connection"], xRecordsA[1]["@database"]) into theConnectionA
  else
    _ThrowError kErrCantFindObject, "you must assign a valid table to a record object"
  end if

  put dbconn_get("effective quotes", theConnectionA) into theQs

  put empty into theTablesA
  _SplitRecordsIntoTablesIndex theConnectionA, xRecordsA, theTablesA, false
  put the result into theError

  ## We now have an array of:
  ## TABLE 'primary key'
  ## TABLE 'fields'
  ## TABLE 'records' INDEX FIELD1
  ## TABLE 'records' INDEX FIELD2
  ## since you can only have one transaction at a time we
  ## don't automatically open transaction
  local theTransA
  local theRecordCount

  put _internalTransactionName() into theTransA["name"]
  dbconn_beginTransaction theTransA, theConnectionA
  put the result into theError

  put 0 into theAffectedRows

  try
    if theError is empty then
      if "@table" is among the keys of xRecordsA then
        ## single record
        _InsertRecordIntoTable theConnectionA, theQs, theTablesA, xRecordsA, pRefreshRecords, true
        put the result into theError
        put it into theAffectedRows
      else
        put the number of elements of xRecordsA into theRecordCount

        ## multiple records
        if theRecordCount > 0 then
          repeat with i = 1 to the number of elements of xRecordsA
            if "@table" is not among the keys of xRecordsA[i] then
              put kInvalidType && "record" into theError
            else
              _InsertRecordIntoTable theConnectionA, theQs, theTablesA, xRecordsA[i], pRefreshRecords, true
              put the result into theError

              if theError is empty then
                add it to theAffectedRows
              end if
            end if

            if theError is not empty then exit repeat
          end repeat
        else
          put kInvalidType && "record" into theError
        end if
      end if
    end if
  catch e
    put e into theError
    put true into rethrowTheError
  end try

  if theError is empty then
    dbconn_commitTransaction theTransA, theConnectionA
    return theAffectedRows for value
  else
    dbconn_rollbackTransaction theTransA, theConnectionA
    if rethrowTheError then throw theError
    else return theError for error
  end if
end sqlrecord_create


/**
Summary: Inserts a record into the database.

pConnectionA:
pQuotesA:
pTablesA:
xRecordA:
pUpdateRecordAfterCreate: Pass in true to update xRecordA with the db record contents after performing the insert.
pSendCallbacks: Set to true to send `before/after create callbacks`.

Description:

Returns:
it: Number of affected rows
the result: Error message
*/
private command _InsertRecordIntoTable pConnectionA, pQuotesA, pTablesA, @xRecordA, pUpdateRecordAfterCreate, pSendCallbacks
  -----
  local theAffectedRows
  local theBaseSQL
  local theBindingsA
  local theError
  local theField, theFields, theFieldsToInsert
  local theSQL
  local theTable
  local theValuesToInsert
  local insertingAPrimaryKeyValue = "false"
  -----

  put pSendCallbacks is true into pSendCallbacks

  ##
  ## VALIDATION CALLBACKS
  _dispatchValidationCheck xRecordA, "create"
  put the result into theError

  put the keys of xRecordA into theFields

  ## Validation error, prefix with something
  if theError is not empty then
    -- ... Should library prefix or just pass through the error message?
  end if

  ## Validation could have generated error
  if theError is empty then

    filter theFields without "@*"

    put xRecordA["@table"] into theTable

    if pSendCallbacks then
      _dispatchTableObjectEventListener theTable, pConnectionA, "before create", xRecordA
      put the result into theError
    end if
  end if

  if theError is empty then
    ##
    ## Perform INSERT
    ##
    local thePassThruFields, theConnType, isBoolean, theMetaType
    local theKeysWithChildRecords, theFieldIndex

    put "INSERT INTO %s%s%s" into theBaseSQL

    put xRecordA["@passthru"] into thePassThruFields
    set the wholeMatches to true

    put dbconn_get("type", pConnectionA) into theConnType

    ## VALUES
    repeat for each line theField in theFields
      put sDbsA[ pConnectionA["database"] ]["schema"]["tables"][ theTable ]["fields"][ theField ]["meta type"] is "boolean" into isBoolean
      put sDbsA[ pConnectionA["database"] ]["schema"]["tables"][ theTable ]["fields"][ theField ]["meta type"] into theMetaType

      if theField is not among the items of pTablesA[ theTable ]["fields"] then
        if xRecordA[theField] is an array then
          ## This is a list of fields that are possible related record arrays.
          ## After we finish updating this record we need to find the
          ## relationship between the two, add the forign key field value
          ## and update the record. Just make recursive call.
          ## Note: Currently not supported. Don't know that we ever will.
          put theField & comma after theKeysWithChildRecords
        end if
        next repeat
      else if theField is among the items of pTablesA[ theTable ]["primary key"] then
        if xRecordA[theField] is empty or xRecordA[theField] is NULL or xRecordA[theField] is "NULL" then
          ## fields that are primary key fields with no values get skipped
          next repeat
        else
          ## primary key has value. Flag so that dbs that need to specificly allow insertion of primary keys can do so.
          if insertingAPrimaryKeyValue is false and theMetaType is "sequence" then ## only set once
            put true into insertingAPrimaryKeyValue
          end if
        end if
      end if

      put pQuotesA["left"] & theField & pQuotesA["right"] & comma after theFieldsToInsert

      if xRecordA[theField] is NULL OR (theConnType is "sql server" AND theMetaType is among the items of "text,binary,decimal" AND xRecordA[theField] is empty) then
        ## ODBC (at least with SQL Server) will not take an empty string in columns that are character, decimal or binary
        put "NULL" & comma after theValuesToInsert
      else if theField is among the items of thePassThruFields then
        ## Some fields should just be passed directly to the database
        if isBoolean then put _getBooleanValue(xRecordA[theField], pConnectionA) & comma after theValuesToInsert
        else put xRecordA[theField] & comma after theValuesToInsert
      else
        add 1 to theFieldIndex
        put ":" & theFieldIndex & comma after theValuesToInsert

        ## Prepend "*b" to key name if binary
        --            if the shiftkey is down then answer sDbsA[ pConnectionA["database"] ]["schema"]["tables"][ theTable ]["fields"][ theField ]["encoding"]
        if sDbsA[ pConnectionA["database"] ]["schema"]["tables"][ theTable ]["fields"][ theField ]["meta type"] is "binary" then
          put xRecordA[theField] into theBindingsA["*b" & theFieldIndex]
        else
          if isBoolean then put _getBooleanValue(xRecordA[theField], pConnectionA) into theBindingsA[theFieldIndex]
          else
            put xRecordA[theField] into theBindingsA[theFieldIndex]
          end if
        end if
      end if
    end repeat
    delete the last char of theFieldsToInsert
    delete the last char of theValuesToInsert

    if insertingAPrimaryKeyValue then
      if theConnType is "sql server" then
        local thePrefixSQL, theSuffixSQL

        put format("SET IDENTITY_INSERT %s%s%s ON;", pQuotesA["left"], theTable, pQuotesA["right"]) into thePrefixSQL
        put format(";SET IDENTITY_INSERT %s%s%s OFF", pQuotesA["left"], theTable, pQuotesA["right"]) into theSuffixSQL
      end if
    end if

    put format(theBaseSQL, pQuotesA["left"], theTable, pQuotesA["right"]) into theBaseSQL
    put format("%s%s (%s) VALUES(%s)%s", thePrefixSQL, theBaseSQL, theFieldsToInsert, theValuesToInsert, theSuffixSQL) into theSQL
    dbconn_executeWBindings theSQL, theBindingsA, pConnectionA
    put the result into theError
    put it into theAffectedRows
  end if

  -- if the shiftkey is down and theError is not empty then answer theSQL & cr & theAffectedRows & cr & theError & cr & printKeys(theBindingsA)

  ## Fetch record from db and put back into array
  if theError is empty then
    local theValue, insertLastID, theLastID

    ## Just fill in primary key field if single and empty
    ## Some dbs may return id when inserting but I don't think revDB supports that
    if the number of items of pTablesA[ theTable ]["primary key"] is 1 then
      put xRecordA[ pTablesA[ theTable ]["primary key"] ] into theValue
      put theValue is empty or theValue is NULL or theValue is "NULL" into insertLastID

      if insertLastID then
        put dbconn_get("last inserted id", pConnectionA) into theLastID
        put theLastID into xRecordA[ pTablesA[ theTable ]["primary key"] ]
      end if
    end if

    if pUpdateRecordAfterCreate then
      local theOutRecordA

      _RetrieveUpdatedRecordAfterDbMod theOutRecordA, pConnectionA, xRecordA, pTablesA[ theTable ]["primary key"]
      put the result into theError

      if theError is empty then
        delete local xRecordA["@passthru"]

        ## Update record one field at a time so we don't overwrite any related tables
        repeat for each key theField in theOutRecordA
          put theOutRecordA[theField] into xRecordA[theField]
        end repeat
      end if
    end if
  end if

  if theError is empty and pSendCallbacks then
    _dispatchTableObjectEventListener theTable, pConnectionA, "after create", xRecordA
    put the result into theError
  end if

  if theError is not empty then
    return theError for error
  else
    return theAffectedRows for value
  end if
end _InsertRecordIntoTable


private command _RetrieveUpdatedRecordAfterDbMod @xOutRecordA, pConnectionA, pRecordA, pTablePrimaryKeys
  -----
  local theDbType, allPrimaryKeysIncluded
  local theError
  local theField
  local theLastID
  local theQueryA
  local theWhere
  -----
  put dbconn_get("type", pConnectionA) into theDbType

  ## Were all primary key included in the create?
  put true into allPrimaryKeysIncluded
  repeat for each item theFieldName in pTablePrimaryKeys
    put pRecordA[ theFieldName ] is not empty into allPrimaryKeysIncluded
    if not allPrimaryKeysIncluded then exit repeat
  end repeat

  ## Nope, try to get last inserted id if primary keys is 1
  ## Otherwise this was not a valid insert.
  put empty into theWhere
  if not allPrimaryKeysIncluded then
    if the number of items of pTablePrimaryKeys > 1 then
      put "insert did not include all of the necessary primary keys for table '" & pRecordA["@table"] & "'" into theError
    else
      ## one primary key, try to fetch
      put dbconn_get("last inserted id", pConnectionA) into theLastID
      put pTablePrimaryKeys & " = " & theLastID into theWhere
    end if
  else
    repeat for each item theFieldName in pTablePrimaryKeys
      if sDbsA[ pConnectionA["database"] ]["schema"]["tables"][ pRecordA["@table"] ]["fields"][ theFieldName ]["meta type"] \
            is not among the items of kDontQuoteTypes then
        put theFieldName & " = '" & pRecordA[ theFieldName ] & "' AND " after theWhere
      else
        put theFieldName & " = " & pRecordA[ theFieldName ] & " AND " after theWhere
      end if

    end repeat
    delete the last word of theWhere
  end if

  ## Now perform actual fetch
  if theError is empty then
    put _CreateSQLQueryFromTable(pConnectionA, pRecordA["@table"]) into theQueryA
    sqlquery_set theQueryA, "conditions", theWhere
    sqlquery_retrieve theQueryA
    put the result into theError

    if theError is empty then
      put empty into xOutRecordA
      sqlquery_convertToArray theQueryA, xOutRecordA
      put the result into theError

      if theError is empty then
        put xOutRecordA[1] into xOutRecordA
        put pRecordA["@table"] into xOutRecordA["@table"]
      end if

      sqlquery_close theQueryA
    end if
  end if

  return theError
end _RetrieveUpdatedRecordAfterDbMod


/**
Summary: Links two records represented by xRecord1A and xRecord2A together in the database.

Parameters:
xRecord1A: The primary Record array.
xRecord2A: The Record array that should be linked to xRecord1A.

Description:
This handler will link two records together if you have defined a relationship between
the two tables. You just need to fill in the column keys for each record that are
needed to uniquely identify them.

Example:
put sqlrecord_createObject("lessons") into theLessonA
sqlrecord_set theLessonA, "id", 2

put sqlrecord_createObject("steps") into theStepA
sqlrecord_set theStepA, "id", 15

sqlrecord_link theLessonA, theStepA

Returns: Error message
*/
command sqlrecord_link @xRecord1A, @xRecord2A
  -----
  local theConnectionA, theError
  -----

  if "@table" is among the keys of xRecord1A and "@table" is among the keys of xRecord2A then
    if "@connection" is among the keys of xRecord1A or "@database" is among the keys of xRecord1A then
      put _CreateConnectionArray(xRecord1A["@connection"], xRecord1A["@database"]) into theConnectionA
    else
      put _CreateConnectionArray(xRecord2A["@connection"], xRecord2A["@database"]) into theConnectionA
    end if

    ## single record
    _LinkUnlinkRecords "link", theConnectionA, xRecord1A, xRecord2A, empty
    put the result into theError
  else
    put "invalid record arrays passed to " & param(0) into theError
  end if

  return theError
end sqlrecord_link


/**
Summary: Unlinks the two records represented by xRecord1A and xRecord2A in the database.

Parameters:
xRecord1A: The primary Record array.
xRecord2A: The Record array that should be unlinked from xRecord1A.

Description:
This handler will unlink two records from each other if you have defined a relationship between
the two tables. You just need to fill in the column keys for each record that are
needed to uniquely identify them.

Example:
put sqlrecord_createObject("lessons") into theLessonA
sqlrecord_set theLessonA, "id", 2

put sqlrecord_createObject("steps") into theStepA
sqlrecord_set theStepA, "id", 15

sqlrecord_unlink theLessonA, theStepA

Returns: Error message
*/
command sqlrecord_unlink @xRecord1A, @xRecord2A
  -----
  local theConnectionA, theError
  -----

  if "@table" is among the keys of xRecord1A and "@table" is among the keys of xRecord2A then
    if "@connection" is among the keys of xRecord1A or "@database" is among the keys of xRecord1A then
      put _CreateConnectionArray(xRecord1A["@connection"], xRecord1A["@database"]) into theConnectionA
    else
      put _CreateConnectionArray(xRecord2A["@connection"], xRecord2A["@database"]) into theConnectionA
    end if

    ## single record
    _LinkUnlinkRecords "unlink", theConnectionA, xRecord1A, xRecord2A, empty
    put the result into theError
  else
    put "invalid record arrays passed to " & param(0) into theError
  end if

  return theError
end sqlrecord_unlink


private command _LinkUnlinkRecords pAction, pConnectionA, @xRecord1A, @xRecord2A
  -----
  local i
  local theError
  local theField
  local theLeftField, theLeftKey
  local theLeftRecordA, theRecordA
  local theLeftRefKey
  local thePrimaryKey
  local theQuotesA
  local theRelationA
  local theRightField, theRightKey, theRightRecordA, theRightRefKey
  local theRightTableA, theTable1A, theTable2A
  -----
  ## Find relation between the two
  if theError is empty then
    put dbconn_get("effective quotes", pConnectionA) into theQuotesA
    put tableobjects_getTable(xRecord1A["@table"], pConnectionA["database"]) into theTable1A
    put tableobjects_getTable(xRecord2A["@table"], pConnectionA["database"]) into theTable2A

    put _FindRelationshipBetweenTables(theTable1A, theTable2A) into theRelationA
    if theRelationA is not an array or the number of elements of theRelationA > 1 then ## we don't support relationships more than 1 away
      put "'" & xRecord1A["@table"] & "' is not directly related to '" & xRecord2A["@table"] & "'" into theError
    else
      put theRelationA[1] into theRelationA
    end if
  end if

  ## Determine keys
  if theError is empty then
    switch tblrelation_get(theRelationA, "type")
      case "many-to-many"
      case "n-n"
        ## todo: do many-to-many
        if tblrelation_get(theRelationA, "cross-reference table") is among the items of (theTable1A["name"] & comma & theTable2A["name"]) then
          ## todo: add support for this
          put "unable to link directly to the cross-reference table" into theError
        end if

        if theError is empty then
          if theTable1A["name"] is tblrelation_get(theRelationA, "left table") then
            put xRecord1A into theLeftRecordA
            put xRecord2A into theRightRecordA
          else
            put xRecord2A into theLeftRecordA
            put xRecord1A into theRightRecordA
          end if
        end if

        put tblrelation_get(theRelationA, "left table key") into theLeftKey
        put tblrelation_get(theRelationA, "right table key") into theRightKey

        ## Create record to use for insertion
        put tblrelation_get(theRelationA, "cross-reference table") into theRecordA["@table"]

        ## Insert fields linking to left table
        if theError is empty then
          put tblrelation_get(theRelationA, "cross-reference table key for left table") into theLeftRefKey
          repeat with i = 1 to max(the number of items of theLeftKey, the number of items of theLeftRefKey)
            put item i of theLeftKey into theLeftField
            put item i of theLeftRefKey into theRightField
            split theLeftField by "="
            split theRightField by "=" ## account for field=value in relationship (alias tables)

            if the number of elements of theLeftField > 1 then
              put theLeftField[2] into theRecordA[ theLeftField[1] ]
            else if the number of elements of theRightField > 1 then
              put theRightField[2] into theRecordA[ theRightField[1] ]
            else
              ## straight up fields
              if theLeftField[1] is among the keys of theLeftRecordA then
                put theLeftRecordA[ theLeftField[1] ] into theRecordA[ theRightField[1] ]
              else
                put "required field '" & theLeftField[1] & "' is not present in the record" into theError
                exit repeat
              end if
            end if
          end repeat
        end if

        ## Insert fields linking to right table
        if theError is empty then
          put tblrelation_get(theRelationA, "cross-reference table key for right table") into theRightRefKey
          repeat with i = 1 to max(the number of items of theRightKey, the number of items of theRightRefKey)
            put item i of theRightRefKey into theLeftField
            put item i of theRightKey into theRightField
            split theLeftField by "="
            split theRightField by "=" ## account for field=value in relationship (alias tables)

            if the number of elements of theLeftField > 1 then
              put theLeftField[2] into theRecordA[ theLeftField[1] ]
            else if the number of elements of theRightField > 1 then
              put theRightField[2] into theRecordA[ theRightField[1] ]
            else
              ## straight up fields
              if theRightField[1] is among the keys of theRightRecordA then
                put theRightRecordA[ theRightField[1] ] into theRecordA[ theLeftField[1] ]
              else
                put "required field '" & theRightField[1] & "' is not present in the record" into theError
                exit repeat
              end if
            end if
          end repeat
        end if

        if pAction is "link" then
          ## Create update structures
          if theError is empty then
            local theTablesA

            _SplitRecordsIntoTablesIndex pConnectionA, theRecordA, theTablesA, true
            put the result into theError
          end if

          ## Update
          if theError is empty then
            _InsertRecordIntoTable pConnectionA, theQuotesA, theTablesA, theRecordA, true, true
            put the result into theError
          end if

        else ## Unlink
          if theError is empty then
            sqlrecord_delete theRecordA, pConnectionA
            put the result into theError
          end if
        end if

        break

      case "one-to-one"
      case "1-1"
      case "one-to-many"
      case "1-n"
        ## Insert key value of left table record into key of right table record
        if theTable1A["name"] is tblrelation_get(theRelationA, "left table") then
          put xRecord1A into theLeftRecordA
          put xRecord2A into theRightRecordA
          put theTable2A into theRightTableA
        else
          put xRecord2A into theLeftRecordA
          put xRecord1A into theRightRecordA
          put theTable1A into theRightTableA
        end if

        put tblrelation_get(theRelationA, "left table key") into theLeftKey
        put tblrelation_get(theRelationA, "right table key") into theRightKey

        ## Start filling in record that we will use to update with
        put theRightRecordA["@table"] into theRecordA["@table"]

        ## get primary key values from theRightRecordA
        put tableobj_get(theRightTableA, "primary key") into thePrimaryKey
        repeat for each item theField in thePrimaryKey
          put theRightRecordA[theField] into theRecordA[theField]
        end repeat

        ## Insert link values into record
        repeat with i = 1 to max(the number of items of theLeftKey, the number of items of theRightKey)
          put item i of theLeftKey into theLeftField
          put item i of theRightKey into theRightField
          split theLeftField by "="
          split theRightField by "=" ## account for field=value in relationship (alias tables)

          if the number of elements of theLeftField > 1 then
            put theLeftField[2] into theRecordA[ theLeftField[1] ]
          else if the number of elements of theRightField > 1 then
            put theRightField[2] into theRecordA[ theRightField[1] ]
          else
            ## straight up fields
            if pAction is "link" then
              if theLeftField[1] is among the keys of theLeftRecordA then
                put theLeftRecordA[ theLeftField[1] ] into theRecordA[ theRightField[1] ]
              else
                put "required field '" & theLeftField[1] & "' is not present in the record" into theError
                exit repeat
              end if

            else ## unlink
              ## Set to Null, 0 or empty
              local theFieldA

              put sDbsA[ theRightTableA["database"] ]["schema"]["tables"][ theRightTableA["name"] ]["fields"][ theRightField[1] ] into theFieldA
              if theFieldA["accepts null"] then
                put NULL into theRecordA[ theRightField[1] ]
              else if theFieldA["type"] is among the items of kDontQuoteTypes then
                put 0 into theRecordA[ theRightField[1] ]
              else
                put empty into theRecordA[ theRightField[1] ]
              end if
            end if
          end if
        end repeat

        ## Create update structures
        if theError is empty then
          _SplitRecordsIntoTablesIndex pConnectionA, theRecordA, theTablesA, true
          put the result into theError
        end if

        ## Update
        if theError is empty then
          local updateRecordAfterUpdate = "false" ## in case we ever need some sort of refresh in the future
          _UpdateRecordInTable pConnectionA, theQuotesA, theTablesA, theRecordA, updateRecordAfterUpdate, true
          put the result into theError

          ## Update record passed in so it has new id
          if theTable1A["name"] is tblrelation_get(theRelationA, "left table") then
            ## update pRecordA2
            put theRecordA into xRecord2A
          else
            ## update pRecordA1
            put theRecordA into xRecord1A
          end if
        end if

        break
    end switch
  end if

  return theError
end _LinkUnlinkRecords


--> Test Helpers

function printKeys pArray, pDimension, pFullData
  local theKeys, theText, theTempArray

  if pDimension is empty then put 0 into pDimension

  put the keys of pArray into theKeys
  sort theKeys numeric

  repeat for each line theKey in theKeys
    if pArray[theKey] is an array then
      put printCharXTimes(space, pDimension * 5) & theKey & cr after theText
      put pArray[theKey] into theTempArray
      put printKeys(theTempArray, pDimension + 1, pFullData) after theText
    else
      if pFullData then
        put printCharXTimes(space, pDimension * 5) &  theKey & ":" && pArray[theKey] & cr after theText
      else
        put printCharXTimes(space, pDimension * 5) &  theKey & ":" && line 1 of pArray[theKey] & cr after theText
      end if
    end if
  end repeat

  return theText
end printKeys

function printCharXTimes pChar, pTimes
  local theStr

  repeat with i = 1 to pTimes
    put pChar after theStr
  end repeat
  return theStr
end printCharXTimes


private function resolveFilenameReference pFilename, pRootFolder
  repeat while the last char of pFilename is "/"
    delete the last char of pFilename
  end repeat

  if isFilenameRelative(pFilename) then
    put normalizeRelativeFilename(pFilename) into pFilename

    if pFilename begins with "../" then
      return resolveRelativeFilenameReference(pFilename, pRootFolder) for value
    else
      return pRootFolder & "/" & pFilename for value
    end if
  else
    return pFilename for value
  end if
end resolveFilenameReference


private function isFilenameRelative pFilename
  set the itemDelimiter to "/"
  -- [[ is for variables
  return not ((the platform is "win32" and item 1 of pFilename contains ":") or pFilename begins with "/" or pFilename begins with "[[")
end isFilenameRelative


private function normalizeRelativeFilename pFilename
  if char 1 of pFilename is "/" then
    delete char 1 of pFilename
  else if char 1 to 2 of pFilename is "./" then
    delete char 1 to 2 of pFilename
  end if
  return pFilename for value
end normalizeRelativeFilename


private function resolveRelativeFilenameReference pFilename, pRootFolder
  set the itemDelimiter to "/"

  repeat while pFilename begins with "../"
    if pRootFolder is empty then
      return "relative path is too deep for root folder" for error
    else
      delete the last item of pRootFolder
      delete char 1 to 3 of pFilename
    end if
  end repeat

  return pRootFolder & "/" & pFilename for value
end resolveRelativeFilenameReference


private function _outputKeyAsYAML pArrayA, pKey, pLevel
  local tKey, tStr, i

  repeat with i = 1 to pLevel-1
    put space & space after tStr
  end repeat
  put pKey & ": " after tStr

  if pArrayA[pKey] is an array then
    put cr after tStr
    repeat for each key tKey in pArrayA[pKey]
      put _outputKeyAsYAML(pArrayA[pKey], tKey, pLevel+1) & cr after tStr
    end repeat
  else
    if pArrayA[pKey] contains "'" then
      replace "'" with "''" in pArrayA[pKey]
      put "'" & pArrayA[pKey] & "'" & cr after tStr
    else
      put pArrayA[pKey] & cr after tStr
    end if
  end if
  delete the last char of tStr

  return tStr
end _outputKeyAsYAML
