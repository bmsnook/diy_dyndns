#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import boto3
import argparse
import json
import requests

hosted_zones = []
hosted_zones_ids = {}

DEBUG = False

def init_boto3_route53_client():
    """Initialize and return a boto3 Route 53 client."""
    route53_client = boto3.client('route53')
    try:
        if DEBUG: print("Initializing boto3 Route 53 client.")
    except Exception as e:
        print(f"An error occurred during boto3 client initialization: {e}")
    return route53_client

def get_hosted_zones():
    """
    Retrieves and prints the IDs and names of all Route 53 hosted zones
    in the AWS account.
    """
    try:
        # Initialize the Route 53 client
        # client = boto3.client('route53')
        # hosted_zones = []
        next_marker = None
        # Handle pagination to retrieve all hosted zones
        while True:
            if next_marker:
                response = client.list_hosted_zones(Marker=next_marker)
            else:
                response = client.list_hosted_zones()
            hosted_zones.extend(response['HostedZones'])
            if response.get('IsTruncated'):
                next_marker = response['NextMarker']
            else:
                break # No more hosted zones to fetch
        # Build a dictionary of hosted zone names to IDs
        if hosted_zones:
            if DEBUG: print("AWS Route 53 Hosted Zones:")
            for zone in hosted_zones:
                if DEBUG: print(f"Raw zone data: {zone}")
                zone_id = zone['Id'].split('/')[-1] # Extract the actual ID
                zone_name = zone['Name'].rstrip('.') # Remove trailing dot
                hosted_zones_ids[zone_name] = zone_id
                if DEBUG: print(f"  ID: {zone_id}, Name: {zone_name}")
        else:
            print("No hosted zones found in this AWS account.")
    # Report any exceptions encountered during the process
    except Exception as e:
        print(f"An error occurred: {e}")

def get_hosted_zone_for_domain(domain_name):
    """
    Given a domain name, find and return the corresponding hosted zone ID.
    If no matching hosted zone is found, return None.
    """
    for zone_name, zone_id in hosted_zones_ids.items():
        if domain_name.endswith(zone_name):
            return zone_id
    return None

def get_connection_ip():
    """Retrieve the current connection's public IP address."""
    try:
        response = requests.get('https://api.ipify.org?format=text')
        response.raise_for_status()
        return response.text
    except requests.RequestException as e:
        print(f"Error retrieving public IP: {e}")
        return None

def get_route53_record_ip(zone_id, record_name):
    """Retrieve the current IP address of a specific A record in Route53."""
    try:
        # client = boto3.client('route53')
        response = client.list_resource_record_sets(
            HostedZoneId=zone_id,
            StartRecordName=record_name,
            StartRecordType='A',
            MaxItems='1'
        )
        record_sets = response['ResourceRecordSets']
        if record_sets and record_sets[0]['Name'].rstrip('.') == record_name and record_sets[0]['Type'] == 'A':
            return record_sets[0]['ResourceRecords'][0]['Value']
        else:
            print(f"No A record found for {record_name} in zone {zone_id}.")
            return None
    except Exception as e:
        print(f"An error occurred while retrieving the A record: {e}")
        return None

def print_hosted_zones():
    """Print the list of hosted zones."""
    for zone_name, zone_id in hosted_zones_ids.items():
        print(f"Hosted Zone ID: {zone_id}, Name: {zone_name}")

def update_a_record(zone_id, record_name, ip_address, ttl=300):
    # client = boto3.client('route53')
    response = client.change_resource_record_sets(
        HostedZoneId=zone_id,
        ChangeBatch={
            'Comment': 'Add or update A record',
            'Changes': [
                {
                    'Action': 'UPSERT',
                    'ResourceRecordSet': {
                        'Name': record_name,
                        'Type': 'A',
                        'TTL': ttl,
                        'ResourceRecords': [{'Value': ip_address}]
                    }
                }
            ]
        }
    )
    return response

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='Manipulate Route53 records')
    parser.add_argument('-l', '--list-zones', action='store_true', help='List all hosted zones')
    parser.add_argument('-n', '--name-record', metavar='DOMAIN', help='Get hosted zone ID for a domain name')
    parser.add_argument('-s', '--sync-ip', action='store_true', help='Sync the A record IP with the current connection IP for the specified domain')
    parser.add_argument('-d', '--debug', action='store_true', help='Enable debug output')
    # parser.add_argument('zone_id', help='The ID of the hosted zone')
    # parser.add_argument('record_name', help='The name of the A record to update')
    # parser.add_argument('ip_address', help='The IP address to set for the A record')
    # parser.add_argument('--ttl', type=int, default=300, help='The TTL for the A record (default: 300)')
    args = parser.parse_args()

    if args.debug:
        DEBUG = True

# # Example change batch template for reference
# change_template = """
# '{
#       "Changes": [
#           {
#               "Action": "UPSERT",
#               "ResourceRecordSet": {
#                   "Name": "example.com",
#                   "Type": "A",
#                   "TTL": 300,
#                   "ResourceRecords": [
#                       {
#                           "Value": "192.0.2.44"
#                       }
#                   ]
#               }
#           }
#       ]
# }'
# """

if __name__ == "__main__":
    client = init_boto3_route53_client()
    get_hosted_zones()
    if args.list_zones:
        print_hosted_zones()
    if args.name_record:
        zone_id = get_hosted_zone_for_domain(args.name_record)
        if zone_id:
            print(f"Hosted Zone ID for domain '{args.name_record}': {zone_id}")
            dns_ip = get_route53_record_ip(zone_id, args.name_record)
            if dns_ip:
                print(f"Current A record IP for '{args.name_record}': {dns_ip}")
                current_ip = get_connection_ip()
                if current_ip:
                    print(f"Current connection IP: {current_ip}")
                    if dns_ip != current_ip:
                        print(f"IP mismatch detected. Update the A record for '{args.name_record}' to {current_ip}.")
        else:
            print(f"No hosted zone found for domain '{args.name_record}'")
    if args.sync_ip:
        domain_name = args.name_record
        if not domain_name:
            print("Please provide a domain name using --name_record to sync its A record.")
        else:
            zone_id = get_hosted_zone_for_domain(domain_name)
            if zone_id:
                dns_ip = get_route53_record_ip(zone_id, domain_name)
                current_ip = get_connection_ip()
                if current_ip and dns_ip != current_ip:
                    print(f"Updating A record for '{domain_name}' from {dns_ip} to {current_ip}.")
                    response = update_a_record(zone_id, domain_name, current_ip)
                    # print("Update response:", json.dumps(response, indent=4))
                    print(f"Response: {response}")
                else:
                    print(f"No update needed for '{domain_name}'. Current IP matches DNS record.")
            else:
                print(f"No hosted zone found for domain '{domain_name}'")
    