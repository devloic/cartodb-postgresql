--------------------------------------------------------------------------------
-- Private functions
--------------------------------------------------------------------------------

--
-- Get the version of a remote PG server
--
CREATE OR REPLACE FUNCTION @extschema@.__CDB_FS_Foreign_Server_Version_PG(server_internal name)
RETURNS text
AS $$
DECLARE
    -- Import pg_settings from pg_catalog
    remote_schema name := 'pg_catalog';
    remote_table name := 'pg_settings';
    local_schema name := @extschema@.__CDB_FS_Create_Schema(server_internal, remote_schema);
    role_name name := @extschema@.__CDB_FS_Generate_Server_Role_Name(server_internal);
    remote_server_version text;
BEGIN
    -- Import the foreign pg_settings table
    IF NOT EXISTS (
        SELECT * FROM pg_class
        WHERE relnamespace = (SELECT oid FROM pg_namespace WHERE nspname = local_schema)
        AND relname = remote_table
    ) THEN
        EXECUTE format('IMPORT FOREIGN SCHEMA %I LIMIT TO (%I) FROM SERVER %I INTO %I',
                    remote_schema, remote_table, server_internal, local_schema);
    END IF;

    BEGIN
        EXECUTE format('
            SELECT setting FROM %I.%I WHERE name = ''server_version'';
        ', local_schema, remote_table) INTO remote_server_version;
    EXCEPTION WHEN OTHERS THEN
        RAISE EXCEPTION 'Not enough permissions to access the server "%"',
                        @extschema@.__CDB_FS_Extract_Server_Name(server_internal);
    END;

    RETURN remote_server_version;
END
$$
LANGUAGE PLPGSQL VOLATILE PARALLEL UNSAFE;


--
-- Get the PostGIS extension version of a remote PG server
--
CREATE OR REPLACE FUNCTION @extschema@.__CDB_FS_Foreign_PostGIS_Version_PG(server_internal name)
RETURNS text
AS $$
DECLARE
    -- Import pg_settings from pg_catalog
    remote_schema name := 'pg_catalog';
    remote_table name := 'pg_extension';
    local_schema name := @extschema@.__CDB_FS_Create_Schema(server_internal, remote_schema);
    role_name name := @extschema@.__CDB_FS_Generate_Server_Role_Name(server_internal);
    remote_postgis_version text;
BEGIN
    -- Import the foreign pg_extension table
    IF NOT EXISTS (
        SELECT * FROM pg_class
        WHERE relnamespace = (SELECT oid FROM pg_namespace WHERE nspname = local_schema)
        AND relname = remote_table
    ) THEN
        EXECUTE format('IMPORT FOREIGN SCHEMA %I LIMIT TO (%I) FROM SERVER %I INTO %I',
                    remote_schema, remote_table, server_internal, local_schema);
    END IF;

    BEGIN
        EXECUTE format('
            SELECT extversion FROM %I.%I WHERE extname = ''postgis'';
        ', local_schema, remote_table) INTO remote_postgis_version;
    EXCEPTION WHEN OTHERS THEN
        RAISE EXCEPTION 'Not enough permissions to access the server "%"',
                        @extschema@.__CDB_FS_Extract_Server_Name(server_internal);
    END;

    RETURN remote_postgis_version;
END
$$
LANGUAGE PLPGSQL VOLATILE PARALLEL UNSAFE;


--
-- Collect and return diagnostics info from a remote PG into a jsonb
--
CREATE OR REPLACE FUNCTION @extschema@.__CDB_FS_Server_Diagnostics_PG(server_internal name)
RETURNS jsonb
AS $$
DECLARE
    remote_server_version  text := @extschema@.__CDB_FS_Foreign_Server_Version_PG(server_internal);
    remote_postgis_version text := @extschema@.__CDB_FS_Foreign_PostGIS_Version_PG(server_internal);
BEGIN
    RETURN jsonb_build_object(
        'server_version', remote_server_version,
        'postgis_version', remote_postgis_version
    );
END
$$
LANGUAGE PLPGSQL VOLATILE PARALLEL UNSAFE;



--------------------------------------------------------------------------------
-- Public functions
--------------------------------------------------------------------------------

--
-- Collect and return diagnostics info from a remote PG into a jsonb
--
CREATE OR REPLACE FUNCTION @extschema@.CDB_Federated_Server_Diagnostics(server TEXT)
RETURNS jsonb
AS $$
DECLARE
    server_internal name := @extschema@.__CDB_FS_Generate_Server_Name(input_name => server, check_existence => true);
    server_type name := @extschema@.__CDB_FS_server_type(server_internal);
BEGIN
    CASE server_type
    WHEN 'postgres_fdw' THEN
        RETURN @extschema@.__CDB_FS_Server_Diagnostics_PG(server_internal);
    ELSE
        RAISE EXCEPTION 'Not implemented server type % for remote server %', server_type, server;
    END CASE;
END
$$
LANGUAGE PLPGSQL VOLATILE PARALLEL UNSAFE;
