#!/bin/bash

# Script to replace all .help() modifiers with .customTooltip() for working tooltips
# Run this from the Production Runner directory

echo "🔧 Fixing tooltips across Production Runner app..."
echo ""

# Find all Swift files and replace .help( with .customTooltip(
find "Production Runner" -name "*.swift" -type f -exec sed -i '' 's/\.help(/\.customTooltip(/g' {} +

echo "✅ Complete! All .help() calls have been replaced with .customTooltip()"
echo ""
echo "Summary:"
echo "- Created: CustomTooltip.swift (working tooltip implementation)"
echo "- Updated: ProductionRunnerApp.swift (added .enableTooltips())"
echo "- Replaced: All .help() → .customTooltip() in all Swift files"
echo ""
echo "Next steps:"
echo "1. Build and run your app in Xcode"
echo "2. Test tooltips by hovering over any button"
echo "3. Tooltips should now appear with a slight delay"
