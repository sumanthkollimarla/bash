#!bin/bash
COMPONENT=$1
ZONE_ID="Z05153301U7YF8KV1K7QB"

if [ -z "$1" ]; then
    echo -e "\e[31m component name is required \n example usage is: \n\t bash create-server.sh componentname \e[0m"
    exit 1
fi

AMI_ID="$(aws ec2 describe-images --region us-east-1  --filters "Name=name,Values=DevOps-LabImage-CentOS7" | jq '.Images[].ImageId' | sed -e 's/"//g')"
SGID="$(aws ec2 describe-security-groups --filters Name=group-name,Values=ds-73-add | jq '.SecurityGroups[].GroupId' | sed -e 's/"//g')"

echo "AMI ID used to launch instance : $AMI_ID"
echo "SG ID used to launch instance : $SGID"

echo $COMPONENT
create-server() {
PRIVATE_IP=$(aws ec2 run-instances --image-id $AMI_ID --instance-type t2.micro --security-group-ids $SGID --instance-market-options "MarketType=spot, SpotOptions={SpotInstanceType=Persistent,InstanceInterruptionBehavior=stop}" --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=${COMPONENT}}]" | jq '.Instances[].PrivateIpAddress' | sed -e 's/"//g')

sed -e "s/IPADDRESS/${PRIVATE_IP}/" -e "s/COMPONENT/$COMPONENT/" route53.json > /tmp/dns.json

echo -n "Creating the DNS Record ********"
aws route53 change-resource-record-sets --hosted-zone-id $ZONE_ID --change-batch file:///tmp/dns.json | jq
}

if [ "$1" == "all" ]; then
    for component in frontend mongodb catalogue cart user redis; do
        COMPONENT=$component
        create-server
    done
else
        create-server
fi