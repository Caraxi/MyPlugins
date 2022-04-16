$ErrorActionPreference = 'SilentlyContinue'

$output = New-Object Collections.Generic.List[object]
$notInclude = "SimpleTweaksPlugin";

$counts = Get-Content "downloadcounts.json" | ConvertFrom-Json
$categoryFallbacksMap = Get-Content "categoryfallbacks.json" | ConvertFrom-Json

$dlTemplateInstall = "https://raw.githubusercontent.com/Caraxi/MyPlugins/main/{1}/{0}/latest.zip"

$apiLevel = 4

$thisPath = Get-Location

$table = ""

Get-ChildItem -Path plugins -File -Recurse -Include *.json |
Foreach-Object {
    $content = Get-Content $_.FullName | ConvertFrom-Json

    if ($notInclude.Contains($content.InternalName)) { 
    	$content | add-member -Force -Name "IsHide" -value "True" -MemberType NoteProperty
    }
    else
    {
    	$content | add-member -Force -Name "IsHide" -value "False" -MemberType NoteProperty
        
        $newDesc = $content.Description -replace "\n", "<br>"
        $newDesc = $newDesc -replace "\|", "I"
        
        if ($content.DalamudApiLevel -eq $apiLevel) {
            if ($content.RepoUrl) {
                $table = $table + "| " + $content.Author + " | [" + $content.Name + "](" + $content.RepoUrl + ") | " + $newDesc + " |`n"
            }
            else {
                $table = $table + "| " + $content.Author + " | " + $content.Name + " | " + $newDesc + " |`n"
            }
        }
    }

    $testingPath = Join-Path $thisPath -ChildPath "testing" | Join-Path -ChildPath $content.InternalName | Join-Path -ChildPath $_.Name
    if ($testingPath | Test-Path)
    {
        $testingContent = Get-Content $testingPath | ConvertFrom-Json
        $content | add-member -Name "TestingAssemblyVersion" -value $testingContent.AssemblyVersion -MemberType NoteProperty
    }
    $content | add-member -Force -Name "IsTestingExclusive" -value "False" -MemberType NoteProperty

    $dlCount = $counts | Select-Object -ExpandProperty $content.InternalName | Select-Object -ExpandProperty "count" 
    if ($dlCount -eq $null){
        $dlCount = 0;
    }
    $content | add-member -Force -Name "DownloadCount" $dlCount -MemberType NoteProperty

    if ($content.CategoryTags -eq $null) {
    	$content | Select-Object -Property * -ExcludeProperty CategoryTags
    
        $fallbackCategoryTags = $categoryFallbacksMap | Select-Object -ExpandProperty $content.InternalName
        if ($fallbackCategoryTags -ne $null) {
			$content | add-member -Force -Name "CategoryTags" -value @() -MemberType NoteProperty
			$content.CategoryTags += $fallbackCategoryTags
        }
    }

    $internalName = $content.InternalName
    
    $updateDate = git log -1 --pretty="format:%ct" plugins/$internalName/latest.zip
    if ($updateDate -eq $null){
        $updateDate = 0;
    }
    $content | add-member -Force -Name "LastUpdate" $updateDate -MemberType NoteProperty

    $installLink = $dlTemplateInstall -f $internalName, "plugins"
    $content | add-member -Force -Name "DownloadLinkInstall" $installLink -MemberType NoteProperty
    
    $installLink = $dlTemplateInstall -f $internalName, "plugins"
    $content | add-member -Force -Name "DownloadLinkTesting" $installLink -MemberType NoteProperty
    
    $updateLink =  $dlTemplateInstall -f $internalName, "plugins"
    $content | add-member -Force -Name "DownloadLinkUpdate" $updateLink -MemberType NoteProperty

    $output.Add($content)
}

$outputStr = $output | ConvertTo-Json

if (!$outputStr.StartsWith("[")) {
    $outputStr = "[$outputStr]"
}

Out-File -FilePath .\pluginmaster.json -InputObject $outputStr