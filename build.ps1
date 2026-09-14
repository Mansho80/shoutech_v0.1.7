param(
    [string]$Configuration = "Debug"
)

Write-Host "Starting build script (Configuration=$Configuration)"

if (-not (Get-Command dotnet -ErrorAction SilentlyContinue)) {
    Write-Error "dotnet CLI not found. Install .NET SDK (7.0 or 9.0) and retry."
    exit 2
}

# Create solution if missing
$sln = Join-Path $PSScriptRoot "ShouTech.sln"
if (-not (Test-Path $sln)) {
    Write-Host "Creating solution ShouTech.sln"
    dotnet new sln -n ShouTech | Out-Null
}

# Add any csproj under repo to the solution
Get-ChildItem -Recurse -Filter "*.csproj" | ForEach-Object {
    $proj = $_.FullName
    Write-Host "Ensuring project added to solution: $proj"
    dotnet sln add "$proj" 2>$null
}

# Restore and build .NET projects
dotnet restore
dotnet build -c $Configuration

Write-Host ".NET build finished."

# Attempt to build C++ if Visual Studio/MSBuild present
if (Get-Command msbuild -ErrorAction SilentlyContinue) {
    Write-Host "Found msbuild; attempting to build vcxproj files"
    Get-ChildItem -Recurse -Filter "*.vcxproj" | ForEach-Object {
        Write-Host "Building VCXPROJ: $($_.FullName)"
        msbuild $_.FullName /p:Configuration=$Configuration
    }
} else {
    Write-Host "msbuild not found; skip C++ build. Build C++ projects in Visual Studio."
}

Write-Host "Build script completed."
