﻿# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT license. See LICENSE file in the project root for full license information.


Param (
    [parameter(Mandatory=$true , Position=0)]
    [ValidateSet("Is-Owner",
                 "Get-ServiceAsWmiObject")]
    [string]
    $Command,
    
    [parameter()]
    [string]
    $Path,
    
    [parameter()]
    [System.ServiceProcess.ServiceController]
    $Service,
    
    [parameter()]
    [string]
    $Name
)

function IsOwner($_service, $_path) {
    if ($_service -eq $null) {
        throw "Service required."
    }
    if ([string]::IsNullOrEmpty($_path)) {
        throw "Path required."
    }
    
    $ownsSvc = $false

    $reg = Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Services\$($_service.Name)"
    $imagePath = $reg.ImagePath.Substring(0, $reg.ImagePath.IndexOf(".exe") + ".exe".Length)
    $rootIndex = $imagePath.IndexOf("\host\x64")

    if ($rootIndex -ne -1) {
        $imageRoot = $imagePath.Substring(0, $rootIndex)
        $ownsSvc = [System.IO.Path]::GetFullPath($_path) -eq [System.IO.Path]::GetFullPath($imageRoot)
    }

    return $ownsSvc
}

function Get-ServiceAsWmiObject($_name) {
    if ([string]::IsNullOrEmpty($_name)) {
        throw "Name required."
    }

    $query = New-Object "System.Management.WqlObjectQuery" -ArgumentList "Select * from Win32_Service where Name = '$_name'"
    $searcher = New-Object "System.Management.ManagementObjectSearcher" -ArgumentList $query
    $collection = $searcher.Get()

    if ($collection.Count -gt 0) {
        return $collection[0]
    }
    return $null
}

switch ($Command)
{
    "Is-Owner"
    {
        return IsOwner $Service $Path
    }
    "Get-ServiceAsWmiObject"
    {
        return Get-ServiceAsWmiObject $Name
    }
    default
    {
        throw "Unknown command"
    }
}