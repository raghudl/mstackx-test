#!/bin/bash
DEFAULT_REGION="ap-south-1"
AWS_REGION="${AWS_REGION:-${DEFAULT_REGION}}"

BUCKET="helm-gg7esslx"
NODE_ROLE_ARN="arn:aws:iam::828054316136:role/masters.vinga.cf"

export AWS_REGION

aws s3api put-bucket-policy --bucket ${BUCKET} --region $AWS_REGION --policy '{
   "Statement": [
      {
         "Effect": "Allow",
         "Principal": {
            "AWS": "'${NODE_ROLE_ARN}'"
          },
         "Action": [
          "s3:GetObject",
          "s3:PutObject"
          ],
         "Resource": "arn:aws:s3:::'${BUCKET}'/*"
      },
      {
         "Effect": "Allow",
         "Principal": {
            "AWS": "'${NODE_ROLE_ARN}'"
          },
         "Action": "s3:ListBucket",
         "Resource": "arn:aws:s3:::'${BUCKET}'"
      }
  ]
}'
