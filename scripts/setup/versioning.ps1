﻿# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT license. See LICENSE file in the project root for full license information.


Param (
    [parameter(Mandatory=$true , Position=0)]
    [ValidateSet("Get-Latest",
                 "Remove-Subversion",
                 "Get-SubVersion",
                 "Compare-Version")]
    [string]
    $Command,
    
    [parameter()]
    [string]
    $Path,
    
    [parameter()]
    [string]
    $ServiceName,
    
    [parameter()]
    [string]
    $Version,
    
    [parameter()]
    [string]
    $Left,
    
    [parameter()]
    [string]
    $Right
)

function Normalize-Version($_version) {
    $v = $_version.Split('.')

    $newV = $v[0]
    for ($i = 1; $i -lt 3 -and $i -lt $v.Length; $i++) {
        $newV = $newV + "." + $v[$i]
    }

    $add = 3 - $v.Length
    for ($i = 0; $i -lt $add; $i++) {
        $newV = $newV + ".0"
    }

    return $newV
}

function Get-Latest($_path, $_serviceName) {
    if ([string]::IsNullOrEmpty($_path)) {
        throw "Path required."
    }
    if ([string]::IsNullOrEmpty($_serviceName)) {
        $_serviceName = .\constants.ps1 DEFAULT_SERVICE_NAME
        $serviceRequired = $true
    }

    $svc = Get-Service $_serviceName -ErrorAction SilentlyContinue

    if (-not(Test-Path $_path)) {
        return $null
    }

    $previousInstallations = Get-ChildItem -Directory $_path

    # Check if there are any previous versions at the specified path
    if ($previousInstallations.Length -eq 0) {
        return $null
    }

    # Check if any of the previous versions are the current owner of the target service
    if ($svc -ne $null) {
        foreach ($previousInstallation in $previousInstallations) {
            if (.\services.ps1 Is-Owner -Service $svc -Path $previousInstallation.FullName) {
                return $previousInstallation.FullName
            }
        }
    }

    if ($serviceRequired) {
        return $null
    }

    $vs = @()
    foreach ($pi in $previousInstallations) {
        $nv = Normalize-Version $pi.Name
        $v = $null
        if ([System.Version]::TryParse($nv, [ref] $v)) {
            $vs += $v
        }
    }

    # Default to the latest previous version that has a valid installation config specifying the target service
    for ($i = $vs.Length - 1; $i -ge 0; $i--) {
        $installConfig = .\installationconfig.ps1 Get -Path (Join-Path $_path $vs[$i].ToString())
        if ($installConfig -ne $null -and $installConfig.ServiceName -eq $_serviceName) {            
            return (Join-Path $_path $vs[$i].ToString())
        }
    }

    #No valid previous version found
    return $null
}

function Compare-Version($a, $b) {
    if ([string]::IsNullOrEmpty($a)) {
        throw "Left required."
    }
    if ([string]::IsNullOrEmpty($b)) {
        throw "Right required."
    }
    
    $aParts = $a.Split('.')
    $bParts = $b.Split('.')

    for ($i = 0; $i -lt $aParts.Length; $i++) {
        $val = $aParts[$i] - $bParts[$i]
        if ($val -ne 0) {
            return $val
        }
    }

    return 0
}

switch ($Command)
{
    "Get-Latest"
    {
        return Get-Latest $Path $ServiceName
    }
    "Compare-Version"
    {
        return Compare-Version $Left $Right
    }
    default
    {
        throw "Unknown command"
    }
}