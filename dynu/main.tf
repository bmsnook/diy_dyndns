data "http" "myip" {
  url = "http://api.ipify.org"
}

data "aws_secretsmanager_secret_version" "dynu" {
  secret_id = "prod/dns/dynu"
}

data "http" "dynu_extant_records" {
  url             = "https://api.dynu.com/v2/dns/${local.dynu_account_id}/record"
  method          = "GET"
  request_headers = local.dynu_request_headers
}

data "http" "dynu_add_record" {
  count           = length(local.dnsRecordIdList) > 0 ? 0 : 1
  url             = "https://api.dynu.com/v2/dns/${local.dynu_account_id}/record"
  method          = "POST"
  request_headers = local.dynu_request_headers
  request_body    = local.dynu_request_body
}

data "http" "dynu_update_record" {
  count           = length(local.dnsRecordIdList) > 0 ? 1 : 0
  url             = "https://api.dynu.com/v2/dns/${local.dynu_account_id}/record/${local.dnsRecordId}"
  method          = "POST"
  request_headers = local.dynu_request_headers
  request_body    = local.dynu_request_body
}

locals {
  this_host_ip    = data.http.myip.response_body
  dynu_account_id = jsondecode(data.aws_secretsmanager_secret_version.dynu.secret_string)["dns_account_id"]
  dynu_api_key    = jsondecode(data.aws_secretsmanager_secret_version.dynu.secret_string)["api_key"]

  dynu_request_headers = {
    Accept       = "application/json"
    Content-Type = "application/json"
    API-Key      = "${local.dynu_api_key}"
  }
  dynu_request_body = jsonencode({
    nodeName    = "${var.dns_name}"
    recordType  = "A"
    ttl         = 300
    state       = true
    group       = ""
    ipv4Address = "${local.this_host_ip}"
  })
  dynu_extant_records_decoded = jsondecode(data.http.dynu_extant_records.response_body)
  dnsRecordIdList             = [for input in local.dynu_extant_records_decoded.dnsRecords[*] : input.id if length(regexall(var.dns_name, input.nodeName)) == 1]
  dnsRecordId                 = length(local.dnsRecordIdList) > 0 ? local.dnsRecordIdList[0] : null
}
