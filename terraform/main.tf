terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 3.90"
    }
  }
}

provider "google" {
  project = var.project
}

locals {

  input_bucket_postfix_async = "-dai-ingest-async"
  input_bucket_postfix = "-dai-ingest-2"
  HITL_output_bucket_postfix = "-dai-hitl-output"
  processor_output_bucket_postfix = "-dai-processor-output"
  source_code_bucket_postfix = "-dai-source"
  processed_bucket_postfix = "-dai-processed"
  error_bucket_postfix = "-dai-error"

  sync_function_name = "dai-sync-processor-firestore"
  sync_function_folder = "../scripts/cloud-functions/processor-sync"

  hitl_function_name = "dai-hitl-process"
  hitl_function_folder = "../scripts/cloud-functions/process-hitl-output"

  async_batch_prep_function_name = "dai-async-batch-prep"
  async_batch_prep_function_function_folder = "../scripts/cloud-functions/async-process-output-to-firestore"

}

data "google_client_config" "current" {}
data "google_project" "project" {}