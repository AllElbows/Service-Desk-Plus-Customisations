Param(
    [STRING]$HTML_DATA_JSON_FILE 
)
#Get content from HTML form and convert from JSON
$JSONobject = Get-Content $HTML_DATA_JSON_FILE | ConvertFrom-Json
#Get individual vars
$samAccountName = $JSONobject.request.ACCOUNT_NAME
$WORKORDERID = $JSONobject.request.WORKORDERID
$radioResult = $JSONobject.request.radioResult.selector
$domainName  = $JSONobject.request.domainName

#Creds to run AD queries against (hardcoded for now)
$User = "Domain\UserName"
$password = ConvertTo-SecureString -String "PlainTextPassword" -AsPlainText -Force
$Cred = [PSCredential]::new($User, $password)

#SDP Key for SDP Sandbox
$URI = "https://servicedeskplus.domain.com/sdpapi/request/$($WORKORDERID)/notes"
$apikey = '#'

switch ($radioResult) {
    "Add" { 
        $MemberCount = (Get-ADGroupMember -Identity 'Application Access - Zoom Addon - Webinar 500' -Credential $cred).count

        if ($MemberCount -lt 50) {
            try {
                Add-ADGroupMember -Identity 'Application Access - Zoom Addon - Webinar 500' -Members $samAccountName -Credential $cred
                $Note = "Success: User has been added to group."
            }
            catch {
                $Note = "FAILED: Unable to add user to group. <br/><br/> $($Error[0])"
            }
        }
        else {
            $Note = "FAILED: Application Access - Zoom Addon - Webinar 500 has reached its maximum of 50 users."
        }
    }
    "Remove" {
        try {
            Remove-ADGroupMember -Identity 'Application Access - Zoom Addon - Webinar 500' -Confirm:$false -Credential $cred
            $Note = "Success: User has been removed from group."
        }
        catch {
            $Note = "FAILED: Unable to remove user from group. <br/><br/> $($Error[0])"
        }
    }
}

$inputData = @"
<API version='1.0' >
    <Operation>
        <Details>
            <Notes>
                <Note>
                    <isPublic>false</isPublic>
                    <notesText>$Note</notesText>
                </Note>
            </Notes>
        </Details>
    </Operation>
</API>
"@

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$postparams = @{OPERATION_NAME = 'ADD_NOTE'; TECHNICIAN_KEY = $apikey; INPUT_DATA = $inputData; FORMAT = 'XML' }
Invoke-WebRequest -Uri $URI -Method POST -Body $postparams -UseBasicParsing | Out-Null
