﻿<#
.SYNOPSIS
Creates inbound and outbound network security rule configs from the text export of a fortigate routing table.
#>


[CmdletBinding(SupportsShouldProcess)]

param(
    [Parameter(Mandatory=$true,ValueFromPipeline=$true)]$NetworkSecurityGroup,
    [Parameter(Mandatory=$true)][string]$routingTablePath,
    [switch]$IncludePrivateRFC1918Subnets,
    [int]$StartingPriority=1000,
    [int]$PriorityInterval=10
)

process {
$rawRoutingTable = get-content $routingtablePath

#Match a CIDR Notation Subnet (111.222.333.0/24, etc.)
$regexCIDR = '\d{0,3}\.\d{0,3}\.\d{0,3}\.\d{0,3}/\d{0,2}'

#Convert the table into a list of subnets
$subnets = $rawRoutingTable | select-string -Pattern $regexCIDR | foreach {$PSItem.Matches.Value}

if (!($IncludePrivateRFC1918Subnets)) {
#Remove known internal networks (RFC1918). This is done poorly and matches 172.10-15.x.x and 172.33-39.x.x which are not technically RFC1918.
$subnets = $subnets -notmatch '^10\.'
$subnets = $subnets -notmatch '^172\.[1-3][0-9]\.'
$subnets = $subnets -notmatch '^192\.168\.'
}

$Priority = $StartingPriority
if ($PSCmdlet.ShouldProcess($NetworkSecurityGroup.Name,"Add Inbound Rules generated from $routingTablePath")) {
    foreach ($subnet in $subnets) {
        write-verbose "Creating Allow-$($subnet -replace "/","n")-Inbound Rule"
        Add-AzureRmNetworkSecurityRuleConfig `
            -Name "Allow-$($subnet -replace "/","n")-Inbound" `
            -access Allow  `
            -Direction Inbound `
            -DestinationAddressPrefix * `
            -SourceAddressPrefix $subnet `
            -priority $Priority `
            -Description "Generated by Script on $($env:computername) at $(get-date -format u)" `
            -SourcePortRange "*" `
            -DestinationPortRange "*" `
            -Protocol "*" `
            -NetworkSecurityGroup $NetworkSecurityGroup `
            | out-null
            
        $Priority += $PriorityInterval
    }
    
}

if ($PSCmdlet.ShouldProcess($NetworkSecurityGroup.Name,"Commit New Configuration")) {
    Set-AzureRmNetworkSecurityGroup -NetworkSecurityGroup $NetworkSecurityGroup
}

}#Process

