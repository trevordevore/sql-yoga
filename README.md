sql-yoga
========

SQL Yoga database library for LiveCode

This repository hosts the source code for the SQL Yoga library for LiveCode. While the library can be used independently of any framework, SQL Yoga is distributed as a Helper for the [Levure framework](https://www.github.com/trevordevore/levure).

# Adding SQL Yoga to a Levure application

## Add as a helper
The simplest way is to download the SQL Yoga repository, rename the folder to "sql yoga" and place it in your applications "helpers" folder. The next time you open your application in the IDE SQL Yoga will be loaded.

## Configure app.yml

In the `app.yml` file you tell SQL Yoga where to find your database configuration files. Add the following to the `app.yml` file.

**app.yml**

```
sql yoga:
  configuration:
    - filename: ./database
```

## Create the database folder

Since you told SQL Yoga that configuration files are stored in a `database` folder you now need to create the folder. Create the `database` folder in the `app` folder (alongside the `ui`, `behaviors`, etc. folders).

# Configuring SQL Yoga

## Create the connections.yml file

In the `./app/database` folder create a file named `connections.yml`. Configure a connection that points to the database file. Here is a SQLite example that points to a .sqlite file in the `./app/database` folder:

```
default connection: local
connections:
  local:
    adaptor: sqlite
    file: ./database/to-do.sqlite
```

# Import an existing database schema

1. Open your Levure application in the LiveCode IDE.
2. In the message box call `dbconn_connect`.
3. In the message box call `sqlyogadev_saveSchemaToYAML;put the result`.

You will now find a `schema.yml` file in your `./app/database` folder. It contains a YAML represenation of the database. If any errors occurred they will be reported in the message box due to the addition of `;put the result`.

## Updating the database schema if it is modified

If you modify the database schema in a 3rd party application you will need to update the `schema.yml` file. 

1. Open your Levure application in the LiveCode IDE.
2. In the message box call `dbconn_connect`.
3. In the message box call `dbsynch_schemaWithDatabase`.
4. In the message box call `sqlyogadev_saveSchemaToYAML;put the result`.

The `./app/database/schema.yml` file will now be updated to match your database schema.

# Create a database

SQL Yoga allows you to create a database from scratch using a YAML file as well. 

1. Create a `migrate` folder in your `./app/database` folder.
2. Create a file named `001_create_tables.yml` in the `./app/database/migrate` folder.
3. Add the following YAML to the file:
```
migration:
  create tables:
```
4. For each table you want to create add the following:
```
    - name: TABLE_NAME
      fields:
        - { name: FIELD_NAME, type: FIELD_TYPE }
```
5. Open your Levure application open in the Livecode IDE.
6. In the message box call `sqlyogadev_runMigrations;put the result`.

Your database will now have the tables and fields you specified and the `./app/database/schema.yml` file will contain the new schema. If any errors occurred they will be reported in the message box due to the addition of `;put the result`.

You can also create new records in the migration file.

```
migration:
  create tables:
    ...
  create records:
    - table: TABLE_NAME
      records:
        - { FIELD_NAME: FIELD_VALUE, FIELD_NAME: FIELD_VALUE }
```
