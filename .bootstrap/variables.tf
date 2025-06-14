variable "name" {
  type = string
}

variable "labels" {
  type = map(string)
}

variable "project_id" {
  type = string
}

variable "impersonators" {
  type    = list(string)
  default = []
}

variable "collaborators" {
  type    = set(string)
  default = []
}

variable "github_options" {
  type = object({
    private_repo = bool
    name         = string
    description  = string
    template     = string
  })
  nullable = false
  default = {
    private_repo = false
    name         = "f5-google-aigw-archetype"
    description  = "A set of archetypes for deploying F5 AI Gateway on Google Cloud"
    template     = ""
  }
}
