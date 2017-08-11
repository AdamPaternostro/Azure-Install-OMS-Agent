# Set to true to actually install the agent (False will just show you what will be done)
$doInstall = $false

# OMS ids
$workspaceId = "<<REMOVED>> e.g. 00000000-0000-0000-0000-000000000000"
$workspaceKey = "<<REMOVED>>"

# do you want to run this on all your subscriptions (that could be a lot!)
$runOnAllSubscriptions = $false

 # only needed if $runOnAllSubscriptions == false
$singleSubscriptionId = "<<REMOVED>> e.g. 00000000-0000-0000-0000-000000000000" 


# Uncomment this out to login
Login-AzureRmAccount

$subscriptionList = Get-AzureRmSubscription

foreach ($s in $subscriptionList)
{
    # Note: we can write this to loop through all subscriptions
    if ($runOnAllSubscriptions)
    {
       Select-AzureRmSubscription -SubscriptionId $s.SubscriptionId
    }
    else
    {
       Select-AzureRmSubscription -SubscriptionId $singleSubscriptionId
    }


    # Gets all Azure resources
    $Resources = Get-AzureRmResource

    foreach ($r in $Resources)
    {
       $item = New-Object -TypeName PSObject -Property @{
                    Name = $r.Name
                    ResourceType = $r.ResourceType
                    ResourceGroupName = $r.ResourceGroupName
                    Location = $r.Location
                    } | Select-Object Name,  ResourceType, ResourceGroupName, Location

 
       if ($item.ResourceType -eq "Microsoft.Compute/virtualMachines")
       {
            $output = "Name: " + $item.Name + " ResourceType: " + $item.ResourceType + " ResourceGroupName: " + $item.ResourceGroupName
            Write-Output $output

            # Check to see if the machine is running
            $running = $false
            $VMDetail = Get-AzureRmVM -ResourceGroupName $item.ResourceGroupName -Name $item.Name -Status 
            foreach ($VMStatus in $VMDetail.Statuses)
            { 
               if($VMStatus.Code.CompareTo("PowerState/running") -eq 0)
                  {
                   $running = $true
                  }
            }

            if ($running)
            {
                $found = $false
                $extensions = (Get-AzureRmVM -ResourceGroupName $item.ResourceGroupName -VMName $item.Name).Extensions
                foreach ($extension in  $extensions)
                {
                   if ($extension.VirtualMachineExtensionType -eq "OmsAgentForLinux")
                   {
                     $found = $true
                   }
                   if ($extension.VirtualMachineExtensionType -eq "MicrosoftMonitoringAgent")
                   {
                     $found = $true
                   }
                }

                $osProfile = (Get-AzureRmVM -ResourceGroupName $item.ResourceGroupName -VMName  $item.Name).OsProfile


                if (!$found)
                {
                    $PublicSettings = @{"workspaceId" = $workspaceId }
                    $ProtectedSettings = @{"workspaceKey" = $workspaceKey }
                
                    if ($doInstall)
                    {
                       if ($osProfile.WindowsConfiguration)
                       {
                            $output =  "Windows Agent (MicrosoftMonitoringAgent Not Found) Installing on: " + $item.Name
                            Write-Output $output

                            Set-AzureRmVMExtension -ExtensionName "Microsoft.EnterpriseCloud.Monitoring" `
                                -ResourceGroupName $item.ResourceGroupName `
                                -VMName $item.Name `
                                -Publisher "Microsoft.EnterpriseCloud.Monitoring" `
                                -ExtensionType "MicrosoftMonitoringAgent" `
                                -TypeHandlerVersion 1.0 `
                                -Settings $PublicSettings `
                                -ProtectedSettings $ProtectedSettings `
                                -Location $item.Location 
                       }
                       else
                       {
                            $output =  "Linux Agent (MicrosoftMonitoringAgent Not Found) Installing on: " + $item.Name
                            Write-Output $output

                            Set-AzureRmVMExtension -ExtensionName "Microsoft.EnterpriseCloud.Monitoring" `
                                -ResourceGroupName $item.ResourceGroupName `
                                -VMName $item.Name `
                                -Publisher "Microsoft.EnterpriseCloud.Monitoring" `
                                -ExtensionType "OmsAgentForLinux" `
                                -TypeHandlerVersion 1.0 `
                                -Settings $PublicSettings `
                                -ProtectedSettings $ProtectedSettings `
                                -Location $item.Location 
                       } # windows or linux

                    } # doInstall

                } # notfound

             } # running

       } # Microsoft.Compute/virtualMachines

        # Classic VMs (not implemented)

    } # ($r in $Resources)

    Write-Output ""

   if (!$runOnAllSubscriptions)
   {
      break;
   }

} #foreach ($s in $subscriptionList)
