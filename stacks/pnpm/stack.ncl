let { stack, .. } = import "minimal.ncl" in
stack {
  name = "pnpm",

  runtime_packages = ["node-lts"],
  build_packages = ["pnpm", "base"],

  # pnpm refuses `pnpm add -g` unless its global bin dir is on PATH, and the
  # session PATH is fixed (no `pnpm setup`). pnpm derives that dir as
  # $PNPM_HOME/bin, so pointing PNPM_HOME at ~/.local lands global bins in
  # /home/.local/bin — already on the session PATH. Stack vars fold into
  # sessions with session-declared vars winning, so this is overridable.
  # See gominimal/inbox#584.
  build_env_vars = {
    PNPM_HOME = "/home/.local",
  },

  build_cmds_cmd = [
    "/bin/bash",
    "-c",
    m%"
    [ -f pnpm-lock.yaml ] && echo '/bin/pnpm install --frozen-lockfile' || echo '/bin/pnpm install'
    echo '/bin/pnpm build'
  "%
  ],

  matches_project_if_any = [
    {
      file_regexes = {
        "pnpm-lock.yaml" = "*",
      },
    }
  ],
  matches_project_priority = 10, # Higher than npm
}
