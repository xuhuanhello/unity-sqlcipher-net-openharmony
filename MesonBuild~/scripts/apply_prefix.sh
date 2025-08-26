#!/bin/bash
# Simple script to apply cr_ prefix to SQLite functions
# Usage: ./apply_prefix.sh (from project root)

cd "$(dirname "$0")/../.."

echo "Applying cr_ prefix to sqlite3.c..."
sed -i '' -f MesonBuild~/scripts/add_cr_prefix_fixed.sed Plugins/sqlite-amalgamation/sqlite3.c

echo "Applying cr_ prefix to sqlite3.h..."
sed -i '' -f MesonBuild~/scripts/add_cr_prefix_fixed.sed Plugins/sqlite-amalgamation/sqlite3.h

echo "Applying cr_ prefix to C# DllImport in Runtime files..."
find Runtime -name "*.cs" -exec sed -i '' -f MesonBuild~/scripts/add_cr_prefix_csharp.sed {} \;

echo "Done!"
