variable "profile" {
     description = "Enter your user profile"
     type        = string
}
variable "region" {
     description = "Enter Region name"
     type = string
}
variable "vpcName" {
     description = "Enter VPC Name"
     type = string
}
variable "dnsSup" {
     type = string
     default = true
}
variable "hosts" {
     type = string
     default = true
}
variable "cidrBlockVPC" {
     description = "Enter VPC Cidr Block"
     type = string
     default = "10.0.0.0/16"
}
variable "cidrBlockSubnet" {
     description = "Enter Subnet Cidr Block"
     type = list
     default = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}
variable "cidrBlockDestination" {
    default = "0.0.0.0/0"
}
variable "cidrBlockIngress" {
    type = list
    default = [ "0.0.0.0/0" ]
}
variable "cidrBlockEgress" {
    type = list
    default = [ "0.0.0.0/0" ]
}
variable "S3BucketName" {
      type = string
      default = "webapp.ankita.tiwari"
}
variable "DBInstanceIdentifier"{
     type = string
     default = "csye6225-f20"
}
variable "rdsDatabaseName"{
     type = string
     default = "csye6225"
}
variable "masterUsername"{
     type = string
     default = "csye6225fall2020"
}
variable "masterPassword"{
     description = "Enter RDS Password"
     type = string
}
variable "dynamoDatabaseName"{
     type = string
     default = "csye6225"
}
variable "ssh_key"{
     description = "SSH Key Name"
     type = string
}
variable "AppPort"{
     type = string
     default = "8080"
}
variable "accountId"{
     description = "Enter Dev Account ID"
     type = string
}

variable "env"{
     description = "Enter Environment"
     type = string
}

variable "domainName"{
     description = "Enter domainName"
     type = string
}

variable "fromAddress" {
  type = string
  default = "no-reply"
}