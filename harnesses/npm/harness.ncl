let { harness, .. } = import "minimal.ncl" in
harness {
  name = "npm",

  runtime_packages = ["node-lts"],
  build_packages = ["base", "curl"],

  build_cmds_cmd = [
    "/bin/bash",
    "-c",
    m%"
    [ -f package-lock.json ] && echo '/bin/npm ci' || echo '/bin/npm install'
    echo '/bin/npm run build --if-present'
  "%
  ],

  matches_project_if_any = [
    {
      file_regexes = {
        "package-lock.json" = "*",
      },
    }
  ],
}
