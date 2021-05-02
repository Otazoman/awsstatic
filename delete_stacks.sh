#!/bin/bash
R53_STACK_NAME="route53set"
ACM_STACK_NAME="acmbuild"
STATIC_STACK_NAME="staticsitebuild"
BREAK_WORD="CREATE_COMPLETE"
SLEEP_TIME=30

if [ $# != 1 ]; then
    echo 'Empty Domain! Please [./deletestack.sh yourdomain]'
    exit 1
fi
domain=$1
BUCKET_NAME=prd-${domain}-logs

echo '*** Delete S3 object ***'
objectdel=$(aws s3 rm s3://${BUCKET_NAME} --recursive)
aws cloudformation delete-stack --stack-name ${STATIC_STACK_NAME}

echo '*** Checked DNS Records ***'
route53result=$(aws route53 list-hosted-zones-by-name --dns-name ${domain})
hosted=$(echo ${route53result} | jq -r ".HostedZones[0].Id")
hz=$(echo ${hosted} | sed -e "s!/hostedzone/!!g")

while true
do
  route53records=$(aws route53 list-resource-record-sets --hosted-zone-id /hostedzone/${hz})
  array=$(echo ${route53records} | jq -r ".ResourceRecordSets[].Type")
  if [[ $(printf '%s\n' "${array[@]}" | grep -qx "A"; echo -n ${?} ) -eq 0 ]]; then
    sleep ${SLEEP_TIME}
  else
    break
  fi
done

echo '*** Delete ACM ***'
aws cloudformation delete-stack --region us-east-1 --stack-name ${ACM_STACK_NAME}

echo '*** Delete Route53 ***'
route53records=$(aws route53 list-resource-record-sets --hosted-zone-id /hostedzone/${hz})
RESOURCE_VALUE=$(echo ${route53records} | jq -c -r '.ResourceRecordSets[]| if .Type == "CNAME" then .ResourceRecords[].Value else empty end')
DNS_NAME=$(echo ${route53records} | jq -c -r '.ResourceRecordSets[] | if .Type == "CNAME" then .Name else empty end')
RECORD_TYPE="CNAME"
TTL=$(echo ${route53records} | jq -c -r '.ResourceRecordSets[]| if .Type == "CNAME" then .TTL else empty end')
JSON_FILE=`mktemp`

(
cat <<EOF
{
    "Comment": "Delete single record set",
    "Changes": [
        {
            "Action": "DELETE",
            "ResourceRecordSet": {
                "Name": "$DNS_NAME",
                "Type": "$RECORD_TYPE",
                "TTL": $TTL,
                "ResourceRecords": [
                    {
                        "Value": "${RESOURCE_VALUE}"
                    }
                ]                
            }
        }
    ]
}
EOF
) > $JSON_FILE

echo "Deleting DNS Record set"
aws route53 change-resource-record-sets --hosted-zone-id ${hz} --change-batch file://$JSON_FILE
aws cloudformation delete-stack --stack-name ${R53_STACK_NAME}

echo 'Delete Complete!'
