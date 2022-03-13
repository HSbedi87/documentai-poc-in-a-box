output "project_id" {
  value = data.google_client_config.current.project
}

output "project_number" {
  value = data.google_project.project.number
}