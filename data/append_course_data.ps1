$ErrorActionPreference = 'Stop'

$dataDirectory = Split-Path -Parent $MyInvocation.MyCommand.Path
$csvPath = Join-Path $dataDirectory 'course_data_import.csv'
$jsonPath = Join-Path $dataDirectory 'course_data.json'
$tempPath = Join-Path $dataDirectory 'course_data.json.tmp'

if (-not (Test-Path -LiteralPath $csvPath)) {
    throw "Import file not found: $csvPath"
}
if (-not (Test-Path -LiteralPath $jsonPath)) {
    throw "Course data file not found: $jsonPath"
}

$csvText = [System.IO.File]::ReadAllText($csvPath, [System.Text.Encoding]::UTF8)
if ($csvText.Length -gt 0 -and $csvText[0] -eq [char]0xFEFF) {
    $csvText = $csvText.Substring(1)
}

$importRows = @($csvText | ConvertFrom-Csv)
if ($importRows.Count -eq 0) {
    throw 'The import CSV contains no course rows.'
}

$requiredColumns = @('programme', 'code', 'title', 'description_brief', 'description', 'qr', 'website', 'artwork')
foreach ($column in $requiredColumns) {
    if ($importRows[0].PSObject.Properties.Name -notcontains $column) {
        throw "Required CSV column missing: $column"
    }
}

$jsonText = [System.IO.File]::ReadAllText($jsonPath, [System.Text.Encoding]::UTF8)
Add-Type -AssemblyName System.Web.Extensions
$serializer = New-Object System.Web.Script.Serialization.JavaScriptSerializer
$serializer.MaxJsonLength = [int]::MaxValue
$serializer.RecursionLimit = 100
$data = $serializer.DeserializeObject($jsonText)
if ($null -eq $data -or $data.Count -ne 1 -or $null -eq $data[0]) {
    throw 'Expected course_data.json to contain one outer array with a course array inside.'
}

$existingCourses = @($data[0])
$knownCodes = @{}
foreach ($course in $existingCourses) {
    if ($course.code) {
        $knownCodes[[string]$course.code] = $true
    }
}

$newCourses = New-Object 'System.Collections.Generic.List[object]'
foreach ($row in $importRows) {
    if ([string]::IsNullOrWhiteSpace($row.code)) {
        throw 'An imported course has an empty code.'
    }
    if ($knownCodes.ContainsKey([string]$row.code)) {
        continue
    }

    $newCourses.Add([ordered]@{
        programme = $row.programme
        code = $row.code
        title = $row.title
        description_brief = $row.description_brief
        description = $row.description
        qr = $row.qr
        website = $row.website
        keyword = @()
        artwork = $row.artwork
    })
    $knownCodes[[string]$row.code] = $true
}

$combinedCourses = @($existingCourses) + @($newCourses.ToArray())
$updatedData = [System.Array]::CreateInstance([object], 1)
$updatedData[0] = $combinedCourses
$jsonOutput = ConvertTo-Json -InputObject $updatedData -Depth 100

[System.IO.File]::WriteAllText($tempPath, $jsonOutput, [System.Text.UTF8Encoding]::new($false))
$verifiedJson = [System.IO.File]::ReadAllText($tempPath, [System.Text.Encoding]::UTF8)
$verifiedData = $serializer.DeserializeObject($verifiedJson)
if ($verifiedData.Count -ne 1 -or @($verifiedData[0]).Count -ne $combinedCourses.Count) {
    Remove-Item -LiteralPath $tempPath -Force
    throw 'Generated JSON did not pass validation; the original file was left unchanged.'
}

Move-Item -LiteralPath $tempPath -Destination $jsonPath -Force
Write-Host ("Added {0} course(s); skipped {1} existing code(s)." -f $newCourses.Count, ($importRows.Count - $newCourses.Count))