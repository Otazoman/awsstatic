#!/bin/bash
SLEEP_TIME=30
R53_YML_NAME="makehostedzone.yml"
R53_STACK_NAME="route53set"
ACM_YML_NAME="acmsetting.yml"
ACM_STACK_NAME="acmbuild"
STATIC_YML_NAME="static-site.yml"
STATIC_STACK_NAME="staticsitebuild"
BREAK_WORD="CREATE_COMPLETE"

if [ $# != 1 ]; then
    echo 'Empty Domain! Please [./create_stacks.sh yourdomain]'
    exit 1
fi
domain=$1

echo '*** Created route53 hostedzone ***'
aws cloudformation create-stack --stack-name ${R53_STACK_NAME} \
--template-body file://`pwd`/yml/${R53_YML_NAME} \
--parameters ParameterKey=DomainName,ParameterValue=${domain}
while true
do
  sleep ${SLEEP_TIME}
  cloudformationstatus=$(aws cloudformation describe-stacks --stack-name ${R53_STACK_NAME})
  stat=$(echo ${cloudformationstatus} | jq -r ".Stacks[0].StackStatus")
  if [ "$stat"=${BREAK_WORD} ]; then
    break
  fi
done

#Get hostedzoneId
route53result=$(aws route53 list-hosted-zones-by-name --dns-name ${domain})
hosted=$(echo ${route53result} | jq -r ".HostedZones[0].Id")
hz=$(echo ${hosted} | sed -e "s!/hostedzone/!!g")

echo '*** Create ACM ***'
if [ "$hz" = "" ]; then
    echo 'Fail get HostedZoneId'
    exit 1
fi
aws cloudformation create-stack \
--region us-east-1 \
--stack-name ${ACM_STACK_NAME} \
--template-body file://`pwd`/yml/${ACM_YML_NAME} \
--parameters ParameterKey=DomainName,ParameterValue=${domain} ParameterKey=HostedZone,ParameterValue=${hz}

echo '*** Please Setting Your Domain Nameserve ***'
route53records=$(aws route53 list-resource-record-sets --hosted-zone-id /hostedzone/${hz})
array=$(echo ${route53records} | jq -r ".ResourceRecordSets[0].ResourceRecords[].Value")
for i in ${array[@]}
do
  echo ${i}
done

#Check Certificate
while true
do
  sleep ${SLEEP_TIME}
  cloudformationstatus=$(aws cloudformation describe-stacks --region us-east-1 --stack-name ${ACM_STACK_NAME})
  stat=$(echo ${cloudformationstatus} | jq -r ".Stacks[0].StackStatus")
  if [ "$stat"=${BREAK_WORD} ]; then
    break
  fi
done
cloudformationstatus=$(aws cloudformation describe-stacks --region us-east-1 --stack-name ${ACM_STACK_NAME})
acmarn=$(echo ${cloudformationstatus} | jq -r ".Stacks[0].Outputs[].OutputValue")

echo '*** Create S3 and CloudFront ***'
aws cloudformation create-stack \
--stack-name ${STATIC_STACK_NAME} \
--template-body file://`pwd`/yml/${STATIC_YML_NAME} \
--parameters ParameterKey=SystemName,ParameterValue=prd ParameterKey=HostDomain,ParameterValue=${domain} ParameterKey=ACMCertificate,ParameterValue=${acmarn}
while true
do
  sleep ${SLEEP_TIME}
  cloudformationstatus=$(aws cloudformation describe-stacks --stack-name ${STATIC_STACK_NAME})
  stat=$(echo ${cloudformationstatus} | jq -r ".Stacks[0].StackStatus")
  if [ "$stat"=${BREAK_WORD} ]; then
    break
  fi
done

echo 'Static Site Build Completed!'
