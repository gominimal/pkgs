let { Attrs, BuildSpec, Local, Needs, OutputData, Test, .. } = import "minimal.ncl" in
let binutils-arm-none-eabi = import "../binutils-arm-none-eabi/build.ncl" in
let base = import "../base/build.ncl" in
let rust = import "../rust/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let version = "1.93.1" in
{
  name = "rust-arm-embedded",
  build_deps = [
    { file = "build.sh" } | Local,
    base,
    rust,
    toolchain,
  ],
  runtime_deps = [rust],

  needs =
    {
      dns = {},
      internet = {},
    } | Needs,

  cmd = "./build.sh",

  outputs = {
    thumbv6m = { glob = "usr/lib/rustlib/thumbv6m-none-eabi/lib/*" } | OutputData,
    thumbv7em = { glob = "usr/lib/rustlib/thumbv7em-none-eabi/lib/*" } | OutputData,
    thumbv7em_hf = { glob = "usr/lib/rustlib/thumbv7em-none-eabihf/lib/*" } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
      source_provenance = {
        category = 'GithubRepo,
        owner = "rust-lang",
        repo = "rust",
      },
    } | Attrs,

  tests = {
    gpio_blink =
      {
        class = 'Standalone,
        test_deps = [base, binutils-arm-none-eabi, toolchain],
        cmds = [
          # Write a minimal no_std embedded program that toggles a GPIO register
          ["/bin/bash", "-c", "cat > gpio.rs << 'RUSTEOF'\n#![no_std]\n#![no_main]\n\nuse core::panic::PanicInfo;\nuse core::ptr;\n\n// STM32F4 GPIOA Output Data Register\nconst GPIOA_ODR: *mut u32 = 0x4002_0014 as *mut u32;\n\n#[no_mangle]\npub unsafe extern \"C\" fn _start() -> ! {\n    // Toggle pin 5 (LED on many STM32F4 boards)\n    ptr::write_volatile(GPIOA_ODR, 1 << 5);\n\n    // Spin for a few cycles\n    for _ in 0..100u32 {\n        core::hint::spin_loop();\n    }\n\n    // Toggle off\n    ptr::write_volatile(GPIOA_ODR, 0);\n\n    loop { core::hint::spin_loop(); }\n}\n\n#[panic_handler]\nfn panic(_: &PanicInfo) -> ! { loop {} }\nRUSTEOF"],
          # Compile to object file for Cortex-M4F (hard float)
          ["/bin/bash", "-c", "rustc --target thumbv7em-none-eabihf --edition 2021 --emit=obj -C opt-level=2 gpio.rs -o gpio.o"],
          # Verify it's an ARM ELF object
          ["/bin/bash", "-c", "readelf -h gpio.o | grep -q 'Machine:.*ARM'"],
          # Verify it contains Thumb instructions (disassemble and look for ARM ops)
          ["/bin/bash", "-c", "arm-none-eabi-objdump -d gpio.o | grep -qE 'str|mov|bl?x?\\s'"],
        ],
      } | Test,
  },
} | BuildSpec
