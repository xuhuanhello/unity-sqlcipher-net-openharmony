#!/usr/bin/env sed -i '' -f
# Idempotent sed script to add cr_ prefix to SQLite functions
# Safe to run multiple times - will not create double prefixes
# Usage: sed -i '' -f add_cr_prefix_fixed.sed Plugins/sqlite-amalgamation/sqlite3.h
#        sed -i '' -f add_cr_prefix_fixed.sed Plugins/sqlite-amalgamation/sqlite3.c

# Fix any existing double prefixes first
s/cr_cr_sqlite3_/cr_sqlite3_/g

# Core idempotent replacement: only replace sqlite3_ when NOT preceded by cr_
# This single rule handles most cases
s/\([^c][^r][^_]\)sqlite3_/\1cr_sqlite3_/g
s/^sqlite3_/cr_sqlite3_/g
s/\([[:space:]]\)sqlite3_/\1cr_sqlite3_/g
s/\([,;=()]\)sqlite3_/\1cr_sqlite3_/g

# Additional specific patterns to catch edge cases
s/\(==\)sqlite3_/\1cr_sqlite3_/g
s/\(#define[[:space:]]\+[A-Za-z_][A-Za-z0-9_]*[[:space:]]\+\)sqlite3_/\1cr_sqlite3_/g
