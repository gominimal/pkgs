let { harness, .. } = import "minimal.ncl" in
harness {
  name = "pulumi-nodejs",

  runtime_packages = ["pnpm", "pulumi"],
  build_packages = ["base", "bash"],

  build_cmds_cmd = [
    "/bin/bash",
    "-c",
    m%"
    # Install pulumi SDK if not present
    [ -z "$(pnpm list @pulumi/pulumi 2>/dev/null | grep @pulumi/pulumi)" ] && echo "pnpm install @pulumi/pulumi" || echo "echo Pulumi installation ready."
  "%
  ],

  matches_project_if_any = [
    {
      file_regexes = {
        "pnpm-lock.yaml" = "*",
        "Pulumi.yaml" = "(?s)runtime:.*?nodejs.*?pnpm",
      },
    }
  ],
  matches_project_priority = 15, # Higher than pnpm
}
