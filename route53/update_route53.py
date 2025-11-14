import boto3

def update_a_record(zone_id, record_name, ip_address, ttl=300):
  client = boto3.client('route53')
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

# Example usage:
# zone_id = 'Z1234567890ABC'
# record_name = 'example.yourdomain.com.'
# ip_address = '1.2.3.4'
# update_a_record(zone_id, record_name, ip_address)