variable "domains" {
  type = map(list(object({
    name    = string
    type    = string
    ttl     = number
    records = list(string)
  })))

  default = {}
}