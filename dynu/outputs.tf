output "dynu_account_id" {
  value     = local.dynu_account_id
  sensitive = true
}
output "dynu_request_headers" {
  value     = local.dynu_request_headers
  sensitive = true
}
output "dynu_request_body" {
  value = local.dynu_request_body
}
output "dynu_domain_dump" {
  value = data.http.dynu_extant_records.response_body
}
output "dynu_domain_dump_decoded" {
  value = jsondecode(data.http.dynu_extant_records.response_body)
}
output "dynu_extant_records_decoded" {
  value = local.dynu_extant_records_decoded
}
output "decoded_nodeNames" {
  value = local.dynu_extant_records_decoded.dnsRecords[*].nodeName
}
output "non_empty_nodeNames" {
  value = local.dynu_extant_records_decoded.dnsRecords[*].nodeName != "" ? "YES" : "NO"
}
output "dnsRecordIdList" {
  value = local.dnsRecordIdList
}
output "debug" {
  value = { for input in local.dynu_extant_records_decoded.dnsRecords[*] : input.nodeName => input.id if input.nodeName == var.dns_name }
}
