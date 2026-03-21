resource "terraform_data" "data_directories" {
  triggers_replace = [local.host_data_directory]

  provisioner "local-exec" {
    command = <<EOT
      mkdir -p '${local.host_data_directory}'
      chown ${var.app_uid}:${var.app_gid} '${local.host_data_directory}'
    EOT
  }
}
