let { harness, .. } = import "minimal.ncl" in
harness {
  name = "pulumi-go",

  build_packages = ["go", "binutils", "linux_headers"],
  runtime_packages = ["pulumi"],

  build_env_vars = {
    CGO_ENABLED = "0",
  },

  build_cmds_cmd = [
    "/bin/bash",
    "-c",
    m%"
    # Install Pulumi Go SDK if not vendored
    if [ ! -d vendor ] && grep -q 'github.com/pulumi/pulumi' go.mod 2>/dev/null; then
      go mod download
    fi
    go build -trimpath -ldflags="-buildid=" ./...
  "%
  ],

  matches_project_if_any = [
    {
      file_regexes = {
        "go.mod" = "github\\.com/pulumi/pulumi",
        "Pulumi.yaml" = "(?s)runtime:.*?go",
      },
    }
  ],
  matches_project_priority = 15, # Higher than plain go harness
}
