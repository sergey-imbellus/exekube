# ------------------------------------------------------------------------------
# STORAGE BUCKET FOR PROJECT SECRETS
# ------------------------------------------------------------------------------

resource "google_storage_bucket" "secret_store" {
  count = "${length(var.crypto_keys)}"

  project       = "${google_project.project.project_id}"
  name          = "${google_project.project.project_id}-${element(keys(var.crypto_keys), count.index)}-secrets"
  force_destroy = true
  storage_class = "REGIONAL"
  location      = "${var.secret_store_location}"
}

# ------------------------------------------------------------------------------
# KEY RING AND CRYPTOGRAPHIC KEYS
# ------------------------------------------------------------------------------

resource "google_kms_key_ring" "key_ring" {
  project  = "${google_project.project.project_id}"
  name     = "${var.product_env}"
  location = "global"
}

resource "google_kms_crypto_key" "crypto_keys" {
  count = "${length(var.crypto_keys)}"

  name     = "${element(keys(var.crypto_keys), count.index)}"
  key_ring = "${google_kms_key_ring.key_ring.id}"
}

# ------------------------------------------------------------------------------
# PERMISSIONS FOR KEYRING
# ------------------------------------------------------------------------------

resource "google_kms_key_ring_iam_binding" "keyring_admins" {
  count = "${length(var.keyring_admins) > 0 ? 1 : 0}"

  key_ring_id = "${google_kms_key_ring.key_ring.id}"
  role        = "roles/cloudkms.admin"

  members = "${var.keyring_admins}"
}

resource "google_kms_key_ring_iam_binding" "keyring_users" {
  count = "${length(var.keyring_users) > 0 ? 1 : 0}"

  key_ring_id = "${google_kms_key_ring.key_ring.id}"
  role        = "roles/cloudkms.cryptoKeyEncrypterDecrypter"

  members = "${var.keyring_users}"
}

# ------------------------------------------------------------------------------
# PERMISSIONS FOR CRYPTOKEYS
# ------------------------------------------------------------------------------

resource "google_kms_crypto_key_iam_binding" "cryptokey_users" {
  count = "${length(var.crypto_keys)}"

  crypto_key_id = "${element(google_kms_crypto_key.crypto_keys.*.id, count.index)}"
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"

  members = "${split(",", lookup(var.crypto_keys, element(keys(var.crypto_keys), count.index)))}"
}

# ------------------------------------------------------------------------------
# PERMISSIONS FOR STORAGE BUCKET
# ------------------------------------------------------------------------------

resource "google_project_iam_custom_role" "storage_viewer_creator" {
  project     = "${google_project.project.project_id}"
  role_id     = "storageViewerCreator"
  title       = "Storage Object View and Creator"
  description = "Allows to view and create storage bucket objects"

  permissions = [
    "storage.objects.get",
    "storage.objects.list",
    "storage.objects.create",
  ]
}

resource "google_storage_bucket_iam_binding" "bucket_admins" {
  count = "${length(var.keyring_admins) == 0 ? 0 : length(var.crypto_keys)}"

  bucket = "${element(google_storage_bucket.secret_store.*.name, count.index)}"

  role = "roles/storage.objectAdmin"

  members = "${var.keyring_admins}"
}

resource "google_storage_bucket_iam_binding" "bucket_users" {
  count      = "${length(var.keyring_users) == 0 ? 0 : length(var.crypto_keys)}"
  depends_on = ["google_project_iam_custom_role.storage_viewer_creator"]

  bucket = "${element(google_storage_bucket.secret_store.*.name, count.index)}"

  role = "projects/${google_project.project.project_id}/roles/storageViewerCreator"

  members = "${var.keyring_users}"
}
