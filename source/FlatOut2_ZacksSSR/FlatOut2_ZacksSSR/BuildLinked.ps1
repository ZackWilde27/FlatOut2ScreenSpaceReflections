# Set Working Directory
Split-Path $MyInvocation.MyCommand.Path | Push-Location
[Environment]::CurrentDirectory = $PWD

Remove-Item "$env:RELOADEDIIMODS/FlatOut2_ZacksSSR/*" -Force -Recurse
dotnet publish "./FlatOut2_ZacksSSR.csproj" -c Release -o "$env:RELOADEDIIMODS/FlatOut2_ZacksSSR" /p:OutputPath="./bin/Release" /p:ReloadedILLink="true"

# Restore Working Directory
Pop-Location