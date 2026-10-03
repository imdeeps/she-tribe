#!/usr/bin/env bash
# Runs the payment/membership tests on a throwaway local PostgreSQL (not your Supabase project).
# Needs a running Postgres you can create databases in:  PGUSER/PGHOST as usual.
set -euo pipefail
cd "$(dirname "$0")"
dropdb --if-exists she_tribe_test && createdb she_tribe_test
psql -q -v ON_ERROR_STOP=1 -d she_tribe_test -f mock_supabase_auth.sql
psql -q -v ON_ERROR_STOP=1 -d she_tribe_test -f ../schema.sql
psql -q -v ON_ERROR_STOP=1 -d she_tribe_test -c 'grant select,insert,update,delete on all tables in schema public to authenticated'
psql -q -v ON_ERROR_STOP=1 -d she_tribe_test -f payments_test.sql
