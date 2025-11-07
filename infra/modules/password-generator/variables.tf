variable "OPERATION" {
  type        = string
  description = "The passowrd operation"
  default     = "none"
  validation {
    condition     = contains(["none", "rotate", "swap"], var.OPERATION)
    error_message = "operation must be one of: none, rotate, swap."
  }
}

variable "NAMESPACE" {
  type        = string
  default     = "default"
  description = "Kubernetes namespace for the secret."
}

variable "SECRET_NAME" {
  type        = string
  default     = "example-secret"
  description = "Name of the Kubernetes secret."
}

variable "ANNOTATIONS" {
  type        = map(string)
  default     = {}
  description = "Additional annotations for the Kubernetes secret."
}

variable "PASSWORD_LENGTH" {
  type        = number
  default     = 16
  description = "Length of the generated passwords."
}

variable "PASSOWORD_OVERRIDE_SPECIAL" {
  type        = string
  default     = "!@#$%^&*()_+-=[]{}|"
  description = "Override the set of special characters used in password generation."
}