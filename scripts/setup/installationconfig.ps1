﻿# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT license. See LICENSE file in the project root for full license information.


Param (
    [parameter(Mandatory=$true , Position=0)]
    [ValidateSet("Get",
                 "Exists",
                 "Get-UserFileMap",
                 "Write-Config",
                 "Write-AppHost")]
    [string]
    $Command,
    
    [parameter()]
    [string]
    $Path,
    
    [parameter()]
    [object]
    $ConfigObject,
    
    [parameter()]
    [string]
    $AppHostPath,
    
    [parameter()]
    [string]
    $ApplicationPath,
    
    [parameter()]
    [int]
    $Port
)

# Name of file we place installation data in
$INSTALL_FILE = "setup.config"

function Get-UserFileMap {
    return @{
        "applicationHost.config" = "host/applicationHost.config"
        "web.config" = "Microsoft.IIS.administration/web.config"
        "modules.json" = "Microsoft.IIS.administration/config/modules.json"
        "config.json" = "Microsoft.IIS.administration/config/appsettings.json"
        "api-keys.json" = "Microsoft.IIS.administration/config/api-keys.json"
    }
}

function Exists($_path) {

    if ([string]::IsNullOrEmpty($_path)) {
        throw "Path required."
    }

    return Test-Path (Join-Path $_path $INSTALL_FILE)
}

function Get($_path) {

    if ([string]::IsNullOrEmpty($_path)) {
        throw "Path required."
    }
    
	if (-not(Exists $_path)) {
		return $null
	}

    [xml]$configXml = Get-Content (Join-Path $_path $INSTALL_FILE)
    $config = $configXml.Configuration

    $userFiles = Get-UserFileMap

    $installConfig = @{
        InstallPath = $config.InstallPath
        Port = $config.Port
        ServiceName = $config.ServiceName
        Version = $config.Version
        UserFiles = $userFiles
        Installer = $config.Installer
        Date = $config.Date
		CertificateThumbprint = $config.CertificateThumbprint
    }

    return $installConfig
}

function Write-Config($obj, $_path) {

    if ([string]::IsNullOrEmpty($_path)) {
        throw "Path required."
    }

    $xml = [xml]""
    $xConfig = $xml.CreateElement("Configuration")

    foreach ($key in $obj.keys) {     
           
        $xElem = $xml.CreateElement($key)
        $xElem.InnerText = $obj[$key]
        $xConfig.AppendChild($xElem) | Out-Null
    }     
    $xml.AppendChild($xConfig) | Out-Null

    $sw = New-Object System.IO.StreamWriter -ArgumentList (Join-Path $_path $INSTALL_FILE)
    $xml.Save($sw) | Out-Null
    $sw.Dispose()
}

function Write-AppHost($_appHostPath, $_applicationPath, $_port) {

    if ([string]::IsNullOrEmpty($_appHostPath)) {
        throw "AppHostPath required."
    }
    if ([string]::IsNullOrEmpty($_applicationPath)) {
        throw "ApplicationPath required."
    }
    if ($_port -eq 0) {
        throw "Port required."
    }

    $IISAdminSiteName = "IISAdmin"

    [xml]$xml = Get-Content -Path "$_appHostPath"
    $sites = $xml.GetElementsByTagName("site")

    $site = $null;
    foreach ($s in $sites) {
    if ($s.name -eq $IISAdminSiteName) { 
            $site = $s;
        } 
    }

    if ($site -eq $null) {
        throw "Installation applicationHost.config does not contain IISAdmin site"
    }

    $site.application.virtualDirectory.SetAttribute("physicalPath", "$_applicationPath")
    $site.bindings.binding.SetAttribute("bindingInformation", "*:$($_port):")
    $sw = New-Object System.IO.StreamWriter -ArgumentList $_appHostPath
    $xml.Save($sw)
    $sw.Dispose()
}

switch ($Command)
{
    "Get"
    {
        return Get $Path
    }
    "Exists"
    {
        return Exists $Path
    }
    "Get-UserFileMap"
    {
        return Get-UserFileMap
    }
    "Write-Config"
    {
        Write-Config $ConfigObject $Path
    }
    "Write-AppHost"
    {
        Write-AppHost $AppHostPath $ApplicationPath $Port
    }
    default
    {
        throw "Unknown command"
    }
}