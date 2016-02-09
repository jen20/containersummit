#!/usr/bin/env bash

set -e

function getInstanceAddresses() {
    local metadata_base_url="http://169.254.169.254/latest/meta-data"
    local this_instance_id
    local this_instance_az
    local this_instance_region
    local this_asg_name
    local instances_in_asg

    this_instance_id=$(curl --silent --location ${metadata_base_url}/instance-id)
    this_instance_az=$(curl --silent --location ${metadata_base_url}/placement/availability-zone)
    #shellcheck disable=SC2001
    this_instance_region=$( echo "${this_instance_az}" | sed 's/.$//')

    this_asg_name=$(aws ec2 describe-tags \
        --region "${this_instance_region}" \
        --filters "Name=resource-type,Values=instance" \
        "Name=resource-id,Values=${this_instance_id}" \
        "Name=key,Values=aws:autoscaling:groupName" \
        --query "Tags[0].Value" \
        --output=text)

    instances_in_asg=$(aws autoscaling describe-auto-scaling-groups \
        --region "${this_instance_region}" \
        --auto-scaling-group-names="${this_asg_name}" \
        --query "AutoScalingGroups[0].Instances[*].{InstanceId:InstanceId}" \
        --output=text)

    #shellcheck disable=SC2086
    aws ec2 describe-instances \
        --region "${this_instance_region}" \
        --instance-ids ${instances_in_asg} \
        --query "Reservations[*].Instances[*].{LaunchTime:LaunchTime,PrivateIpAddress:PrivateIpAddress}" \
        --output=text | sort -s -n -k 1,1 | cut -f 2 -s
}

getInstanceAddresses
