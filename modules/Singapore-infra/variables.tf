#키페어 변수#
variable "keypair_name" {}
#######port variables#########
variable "server_http_port" {
  description = "The port the server will use for HTTP requests"
  type        = number
  default     = 80
}
variable "server_ssh_port" {
  description = "The port the server will use for SSH requests"
  type        = number
  default     = 22
}
variable "server_https_port" {
  description = "The port the server will use for HTTP requests"
  type        = number
  default     = 443
}

