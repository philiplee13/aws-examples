variable "test_key" {
  default = {
    key   = "test-key"
    value = "test-value"
  }

  type = map(string)
}

resource "aws_secretsmanager_secret" "test_secret" {
  name                    = "test_secret_2"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "test_secret_version" {
  secret_id     = aws_secretsmanager_secret.test_secret.id
  secret_string = jsonencode(var.test_key)
}
