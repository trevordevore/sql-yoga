script "SQL Yoga Database Object Loader"
/**
Summary: Used in deployment to load the database objects.

Description:
When put in use this library will load the databse objects stored in the uDbObjects
custom property set.

*/
on libraryStack
  if the target is not me then pass libraryStack

  if "uDbObjects" is among the lines of the customPropertySets of me then
    repeat for each line tDatabaseKey in the customKeys["uDbObjects"] of me
      dbobject_initialize the uDbObjects[tDatabaseKey] of me, levureAppFolder(), tDatabaseKey
    end repeat
  end if

  send "__removeSQLYogaLoaderFromMemory" to stack "libSQLYoga" in 0 seconds

  stop using me
end libraryStack


command __removeSQLYogaLoaderFromMemory
  delete me
end __removeSQLYogaLoaderFromMemory
