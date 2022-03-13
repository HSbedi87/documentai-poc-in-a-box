# A dedicated Cloud Storage bucket to store input files
resource "google_storage_bucket" "input_bucket" {
  name = "${var.project}${local.input_bucket_postfix}"

  uniform_bucket_level_access = true
}

resource "google_storage_bucket" "processed_bucket" {
  name = "${var.project}${local.processed_bucket_postfix}"

  uniform_bucket_level_access = true
}

resource "google_storage_bucket" "error_bucket" {
  name = "${var.project}${local.error_bucket_postfix}"

  uniform_bucket_level_access = true
}
resource "google_storage_bucket" "input_bucket_async" {
  name = "${var.project}${local.input_bucket_postfix_async}"

  uniform_bucket_level_access = true
}

# A dedicated Cloud Storage bucket to store HITL output JSON
resource "google_storage_bucket" "hitl_bucket" {
  name = "${var.project}${local.HITL_output_bucket_postfix}"

  uniform_bucket_level_access = true
}

# A dedicated Cloud Storage bucket to store processor output
resource "google_storage_bucket" "processor_output_bucket" {
  name = "${var.project}${local.processor_output_bucket_postfix}"

  uniform_bucket_level_access = true
}

# A dedicated Cloud Storage bucket to store the zip source
resource "google_storage_bucket" "source" {
name = "${var.project}${local.source_code_bucket_postfix}"

uniform_bucket_level_access = true
}

# Use firestore
resource google_app_engine_application "app" {
  location_id   = "us-west2"
  database_type = "CLOUD_FIRESTORE"
  project = var.project
}

# DocAI sync GCS to Firestore Cloud Function
resource "google_cloudfunctions_function" "docai_sync_function" {
  name        = local.sync_function_name
  description = "processing"
  runtime     = "python38"
  region      = var.region
  ingress_settings = "ALLOW_INTERNAL_AND_GCLB"

  available_memory_mb   = 256
  source_archive_bucket = google_storage_bucket.source.name
  source_archive_object = google_storage_bucket_object.archive.name

  entry_point           = "main_func"
  max_instances = 10

  event_trigger {
  event_type = "google.storage.object.finalize"
  resource = google_storage_bucket.input_bucket.name
  }

  # Environment variables

  environment_variables = {
  PROJECT_ID= var.project,
  LOCATION= var.docai-processor-region,
#  PDAI_SPLITTER_ID=$PDAI_SPLITTER_ID,
#  SPLIT_INVOICE_BUCKET=$GCS_DAI_SPLIT_DOCS,
#  SPLITTER_RESPONSE_BUCKET=$GCS_DAI_RAW_SPLITTER_RESPONSE,
  PROJECT_NUM = data.google_project.project.number,
  SKIP_HITL = var.docai-skip-hitl,
  HITL_BUCKET = google_storage_bucket.hitl_bucket.name,
  DAI_PROCESSOR_ID = var.docai-processor-id,
  GCS_RAW_EXTRACT_BUCKET = google_storage_bucket.processor_output_bucket.name,
  GCS_PROCESSED_BUCKET = google_storage_bucket.processed_bucket.name,
  GCS_ERROR_BUCKET = google_storage_bucket.error_bucket.name
  PROCESSOR_EXTRACT_FIRESTORE_COLLECTION = var.docai-processor-extract-collection

  }

  service_account_email = google_service_account.dai_cf_sync_service_account.email

  depends_on = [google_project_service.cloudfunctions,google_storage_bucket.input_bucket]
}

# Create a fresh archive of the current function folder
data "archive_file" "docai_sync_function" {
  type        = "zip"
  output_path = "temp/function_code_${timestamp()}.zip"
  source_dir  = local.sync_function_folder
}

# The archive in Cloud Stoage uses the md5 of the zip file
# This ensures the Function is redeployed only when the source is changed.
resource "google_storage_bucket_object" "archive" {
  name = "${data.archive_file.docai_sync_function.output_md5}.zip" # will delete old items

  bucket = google_storage_bucket.source.name
  source = data.archive_file.docai_sync_function.output_path

  depends_on = [data.archive_file.docai_sync_function]
}


# Serivice account for docai_sync_function
resource "google_service_account" "dai_cf_sync_service_account" {
  account_id   = "dai-cf-sync"
  display_name = "DAI Sync Cloud Function Service Account"
}

resource "google_project_iam_custom_role" "dai_cf_sync_role" {
  role_id     = "dai_cf_sync_role"
  title       = "Role for dai cloud function"
  description = "Role for dai cloud function"
  permissions = ["documentai.processors.processOnline", "documentai.processorVersions.processOnline", "documentai.operations.getLegacy","documentai.humanReviewConfigs.review","storage.buckets.get", "storage.buckets.list",
  "storage.objects.create","storage.objects.delete","storage.objects.get","storage.objects.list","storage.objects.update","datastore.entities.create","datastore.entities.update","datastore.entities.list","datastore.entities.list",
  "datastore.indexes.create","datastore.indexes.get"]
}

resource "google_project_iam_binding" "dai_cf_sync_role" {
  role    = google_project_iam_custom_role.dai_cf_sync_role.id
  members = ["serviceAccount:${google_service_account.dai_cf_sync_service_account.email}",
  ]
}

# Process HITL output json Cloud Function
resource "google_cloudfunctions_function" "docai_hitl_process_function" {
  name        = local.hitl_function_name
  description = "HITL Process function"
  runtime     = "python38"
  region      = var.region
  ingress_settings = "ALLOW_INTERNAL_AND_GCLB"

  available_memory_mb   = 256
  source_archive_bucket = google_storage_bucket.source.name
  source_archive_object = google_storage_bucket_object.hitl_archive.name

  entry_point           = "main_func"
  max_instances = 5

  event_trigger {
  event_type = "google.storage.object.finalize"
  resource = google_storage_bucket.hitl_bucket.name
  }

  # Environment variables

  environment_variables = {
  PROCESSOR_EXTRACT_FIRESTORE_COLLECTION = var.docai-processor-extract-collection
  COMPILED_RESULTS_FIRESTORE_COLLECTION= var.docai-hitl-output-collection
  }

  service_account_email = google_service_account.dai_cf_hitl_service_account.email

  depends_on = [google_project_service.cloudfunctions,google_storage_bucket.hitl_bucket]
}

# Create a fresh archive of the current function folder
data "archive_file" "docai_hitl_process_function" {
  type        = "zip"
  output_path = "temp/hitl_function_code_${timestamp()}.zip"
  source_dir  = local.hitl_function_folder
}

# The archive in Cloud Stoage uses the md5 of the zip file
# This ensures the Function is redeployed only when the source is changed.
resource "google_storage_bucket_object" "hitl_archive" {
  name = "${data.archive_file.docai_hitl_process_function.output_md5}.zip" # will delete old items

  bucket = google_storage_bucket.source.name
  source = data.archive_file.docai_hitl_process_function.output_path

  depends_on = [data.archive_file.docai_hitl_process_function]
}

# Service account for HITL output process function
resource "google_service_account" "dai_cf_hitl_service_account" {
  account_id   = "dai-cf-hitl-process"
  display_name = "DAI HITL json process Cloud Function Service Account"
}

resource "google_project_iam_custom_role" "dai_cf_hitl_role" {
  role_id     = "dai_cf_hitl_role"
  title       = "Role for dai HITL process cloud function"
  description = "Role for dai HITL process cloud function"
  permissions = ["documentai.processors.processOnline", "documentai.processorVersions.processOnline", "documentai.operations.getLegacy","documentai.humanReviewConfigs.review","storage.buckets.get", "storage.buckets.list",
  "storage.objects.create","storage.objects.delete","storage.objects.get","storage.objects.list","storage.objects.update","datastore.entities.allocateIds","datastore.entities.create","datastore.entities.delete","datastore.entities.get",
  "datastore.entities.list","datastore.databases.get","appengine.applications.get","datastore.indexes.list"]
}

resource "google_project_iam_binding" "dai_cf_hitl_role" {
  role    = google_project_iam_custom_role.dai_cf_hitl_role.id
  members = ["serviceAccount:${google_service_account.dai_cf_hitl_service_account.email}",
  ]
}


# Async Batch Prep  Cloud Function
resource "google_cloudfunctions_function" "dai_async_batch_prep_function" {
  name        = local.async_batch_prep_function_name
  description = "Async Batch Prep Function function"
  runtime     = "python39"
  region      = var.region
  ingress_settings = "ALLOW_ALL"

  available_memory_mb   = 256
  source_archive_bucket = google_storage_bucket.source.name
  source_archive_object = google_storage_bucket_object.dai_async_batch_prep_archive.name

  entry_point           = "main_http"
  max_instances = 5

  trigger_http = true

  # Environment variables

  environment_variables = {
  PROJECT_ID= var.project,
  LOCATION= var.docai-processor-region,
  PROJECT_NUM = data.google_project.project.number,
  SKIP_HITL = var.docai-skip-hitl,
  HITL_BUCKET = google_storage_bucket.hitl_bucket.name,
  DAI_PROCESSOR_ID = var.docai-processor-id,
  GCS_RAW_EXTRACT_BUCKET = google_storage_bucket.processor_output_bucket.name,
  GCS_PROCESSED_BUCKET = google_storage_bucket.processed_bucket.name,
  GCS_ERROR_BUCKET = google_storage_bucket.error_bucket.name
  PROCESSOR_EXTRACT_FIRESTORE_COLLECTION = var.docai-processor-extract-collection
  GCS_ASYNC_PROCESS_INPUT_BUCKET = google_storage_bucket.input_bucket_async.name

  }

  service_account_email = google_service_account.dai_async_batch_prep_service_account.email

  depends_on = [google_project_service.cloudfunctions,google_storage_bucket.input_bucket_async]
}

# Create a fresh archive of the current function folder
data "archive_file" "dai_async_batch_prep_function" {
  type        = "zip"
  output_path = "temp/dai_async_batch_prep_function_code_${timestamp()}.zip"
  source_dir  = local.async_batch_prep_function_function_folder
}

# The archive in Cloud Stoage uses the md5 of the zip file
# This ensures the Function is redeployed only when the source is changed.
resource "google_storage_bucket_object" "dai_async_batch_prep_archive" {
  name = "${data.archive_file.dai_async_batch_prep_function.output_md5}.zip" # will delete old items

  bucket = google_storage_bucket.source.name
  source = data.archive_file.dai_async_batch_prep_function.output_path

  depends_on = [data.archive_file.dai_async_batch_prep_function]
}

# Service account for Async Batch Prep function
resource "google_service_account" "dai_async_batch_prep_service_account" {
  account_id   = "dai-async-batch-prep"
  display_name = "DAI  Async Batch Prep Coud Function Service Account"
}

resource "google_project_iam_custom_role" "dai_async_batch_prep_role" {
  role_id     = "dai_async_batch_prep_role"
  title       = "Role for DAI Async Batch Prep Coud Function"
  description = "Role for DAI Async Batch Prep Coud Function"
  permissions = ["sgcodatastore.indexes.list","documentai.processors.processOnline", "documentai.processorVersions.processOnline", "documentai.operations.getLegacy","documentai.humanReviewConfigs.review"]
}

resource "google_project_iam_binding" "dai_async_batch_prep_role" {
  role    = google_project_iam_custom_role.dai_async_batch_prep_role.id
  members = ["serviceAccount:${google_service_account.dai_async_batch_prep_service_account.email}",
  ]
}