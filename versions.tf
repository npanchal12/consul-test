terraform {
  cloud {
    organization = "Nimesh-Org"
    workspaces {
      # Fixed name
      name = "hcp-consul-dev"
    }
  }
}
