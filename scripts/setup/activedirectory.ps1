# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT license. See LICENSE file in the project root for full license information.


Param(
    [parameter(Mandatory=$true , Position=0)]
    [ValidateSet("AddUserToGroup",
                 "CreateLocalGroup",
                 "CurrentAdUser",
                 "GetLocalGroup",
                 "GroupEquals",
                 "RemoveLocalGroup")]
    [string]
    $Command,
    
    [parameter()]
    [string]
    $Name,
    
    [parameter()]
    [string]
    $Description,
    
    [parameter()]
    [string]
    $AdPath,
    
    [parameter()]
    [System.Object]
    $Group
)

# Nano Server does not support ADSI provider
# Nano Server has localgroup and localuser commands which can be used instead of ADSI provider


# Function not available on Nano Server
function GetLocalAd {
    $server = "$env:COMPUTERNAME"
    return [ADSI]"WinNT://$server,computer"
}

function GroupCommandletsAvailable() {
    # For PS > 5.0
    $localGroupCommand = Get-Command "Get-LocalGroup"  -ErrorAction SilentlyContinue
    $newLocalGroupCommand = Get-Command "New-LocalGroup" -ErrorAction SilentlyContinue
    $removeLocalGroupCommand = Get-Command "Remove-LocalGroup" -ErrorAction SilentlyContinue
    $addLocalGroupMemberCommand = Get-Command "Add-LocalGroupMember" -ErrorAction SilentlyContinue

    return $($localGroupCommand -ne $null -and
                $newLocalGroupCommand -ne $null -and
                $removeLocalGroupCommand -ne $null -and
                $addLocalGroupMemberCommand -ne $null)
}

function GetLocalGroup($groupName) {
    $group = $null;

    if (-not($(GroupCommandletsAvailable))) {
	    if ([System.String]::IsNullOrEmpty($groupName)) {
		    throw "Name cannot be null"
	    }
    
        $localAd = GetLocalAd

        try {
            $group = $localAd.Children.Find($groupName, 'group')
        }
        catch {
            #COM Exception if group doesn't exit
        }
    }
    else {
        $group = Get-LocalGroup -Name $groupName -ErrorAction SilentlyContinue
    }

    return $group;
}

function GroupEquals($group, $_name, $desc) {
    
    $description = $null
    if (-not($(GroupCommandletsAvailable))) {
        # Using ADSI
        $description = $group.Properties["Description"].Value
    }
    else {
        # Using Local Group commands
        $description = $group.Description
    }

    return $group.Name -eq $_name -and $description -eq $desc
}

function CreateLocalGroup($_name, $desc) {

	if ([System.String]::IsNullOrEmpty($_name)) {
		throw "Name cannot be null"
	}

    $group = GetLocalGroup $_name;

    if($group -ne $null) {
        throw "Group $_name already exists"
    }

    if (-not($(GroupCommandletsAvailable))) {
        $localAd = GetLocalAd

        $group = $localAd.Children.Add($_name, 'group')
        $group.Properties["Description"].Value = $desc
    
        $group.CommitChanges()
    }
    else {
        $group = New-LocalGroup -Name $_name
        net localgroup $_name /comment:$desc | Out-Null
    }

    return $group
}

function RemoveLocalGroup($_name) {

	if ([System.String]::IsNullOrEmpty($_name)) {
		throw "Name cannot be null"
	}

    $g = GetLocalGroup $_name

    if($g -ne $null) {
        if (-not($(GroupCommandletsAvailable))) {
            $localAd = GetLocalAd
            $localAd.Children.Remove($g.Path)
        }
        else {
            Remove-LocalGroup -Name $_name
        }
    }
}

function CurrentAdUser {
    return [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
}

function AddUserToGroup($userPath, $_group) {

	if ([System.String]::IsNullOrEmpty($userPath)) {
		throw "User path cannot be null"
	}

	if ($_group -eq $null) {
		throw "Group cannot be null"
	}

    if (-not($(GroupCommandletsAvailable))) {
        $userPath = 'WinNT://' + $userPath.Replace("\", "/")

        try {
            $_group.Invoke('Add', @($userPath))
        }
        catch {
            # HRESULT -2147023518
            # The specified account name is already a member of the group.
            if($_.Exception.InnerException -eq $null -or $_.Exception.InnerException.HResult -ne -2147023518) {
                throw $_.Exception
            }
        }
    }
    else {
        $existingMember = Get-LocalGroupMember -Name $($_group.name) -Member $($userPath) -ErrorAction SilentlyContinue

        if ($existingMember -eq $null) {
            Add-LocalGroupMember -Name $($_group.name) -Member $($userPath)
        }
    }
}

switch($Command)
{
    "GetLocalGroup"
    {
        return GetLocalGroup $Name
    }
    "CreateLocalGroup"
    {
        return CreateLocalGroup $Name $Description
    }
    "RemoveLocalGroup"
    {
        return RemoveLocalGroup $Name
    }
    "CurrentAdUser"
    {
        return CurrentAdUser
    }
    "AddUserToGroup"
    {
        return AddUserToGroup $AdPath $Group
    }
    "GroupEquals"
    {
        return GroupEquals $Group $Name $Description
    }
    default
    {
        throw "Unknown command"
    }
}

