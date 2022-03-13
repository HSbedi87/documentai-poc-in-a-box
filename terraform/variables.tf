variable "project" {
  type        = string
  default = "rand-automl-project"
  description = "Google Cloud Platform Project ID"
}

variable "region" {
  default = "us-west2"
  type    = string
}

variable "docai-processor-id" {
#  default = "d50b35f50802accd"
  default = "242fdaa80184bbca"
  type    = string
}

variable "docai-processor-region" {
  default = "us"
  type    = string
}

variable "docai-skip-hitl" {
  default = "False"
  type = string
}

variable "docai-processor-extract-collection" {
  default = "invoice_extractions"
  type = string
}

variable "docai-hitl-output-collection" {
  default = "compiled_invoice_results"
  type = string
}