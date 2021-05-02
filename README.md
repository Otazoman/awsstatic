# awsstaticsite  
AWS StaticHostingPattern Building Stack  

# Description  
This is a set of files for configuring static website hosting with AWS CloudFormation, using ACM + CloudFront + S3.  

# Operating environment 
Ubuntu 20.04.2 LTS  
Python 3.7.7  
aws-cli/1.18.39

# Usage  
$ create_stack.sh youredomain  

### Caution
It is necessary to set the AWS token in the environment variable beforehand.  
https://docs.aws.amazon.com/ja_jp/cli/latest/userguide/cli-configure-envvars.html

