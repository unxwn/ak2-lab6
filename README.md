# Kernel Module Lab 6 – BUG_ON and Simulated Failures

Lab 6: Extend the two-module design (`hello1`, `hello2`) from Lab 5 with BUG_ON and forced allocation error.

## Architecture

- **hello1.ko** – library module
  - Exports `int print_hello(void)`
  - Allocates list entries with:
    - `ktime_t time_before`, `ktime_t time_after`
  - On unload:
    - Prints elapsed time per entry (`time_after - time_before`)
    - Frees list

- **hello2.ko** – client module
  - Module parameter: `count` (0–10)
  - Validates `count`:
    - `BUG_ON(count > 10)` – triggers kernel oops/panic for invalid value
    - `pr_warn` for `count == 0` or `5 <= count <= 10`
  - Calls `print_hello()` `count` times
  - Handles error from `print_hello()` (simulated `kmalloc` failure)

## Special Behavior (Lab 6)

- In `hello1.c`:
  - Global `static int call_count;`
  - In `print_hello()`:
    - `call_count++;`
    - On specific call (e.g. 5th):
      - Print `pr_err("Simulated kmalloc() failure on call %d\n", call_count);`
      - Return `-ENOMEM` **without** allocating or adding to list

- In `hello2.c`:
  - If `print_hello()` returns error:
    - Print `pr_err("print_hello failed: %d\n", ret);`
    - Return this error from module init → `insmod` fails with “Cannot allocate memory” and module is not loaded

## Compilation

Set environment:

```

source setup_env.sh

```

Build modules:

```

make

```

You should get:

```

ls -l hello1.ko hello2.ko

```

If you follow appendix-style Makefile, you will also have `hello1.ko.unstripped` and `hello2.ko.unstripped` for analysis.

## Updating QEMU RootFS

Copy modules into BusyBox rootfs:

```

cp hello1.ko hello2.ko ~/repos/busybox/_install/

```

Rebuild initramfs:

```

cd ~/repos/busybox/_install
find . | cpio -H newc -o > ../../rootfs.cpio
cd ../..
gzip -f rootfs.cpio

```

## Boot QEMU

```

qemu-system-arm \
-kernel ~/repos/linux-stable/_install/boot/zImage \
-initrd ~/repos/rootfs.cpio.gz \
-machine virt -nographic -m 512 \
-append "root=/dev/ram0 rw console=ttyAMA0,115200 mem=512M"

```

## Test Scenarios

### 1. Normal load/unload (no errors)

```

insmod hello1.ko
insmod hello2.ko count=3
cat /sys/module/hello2/parameters/count
rmmod hello2
rmmod hello1
dmesg | tail -20

```

Expected:
- `hello1 module loaded`
- `hello2 module loaded`
- `Hello, world!` three times.
- On `rmmod hello1`: per-entry timing lines.

### 2. Simulated kmalloc failure

```

insmod hello1.ko
insmod hello2.ko count=7
dmesg | tail -30

```

Expected:
- 4× `Hello, world!`
- `Simulated kmalloc() failure on call 5`
- `print_hello failed: -12`
- `insmod: ... Cannot allocate memory`
- `hello2` **not** loaded, no `/sys/module/hello2`.

Then:

```

rmmod hello1
dmesg | tail -20

```

Expected:
- Timing output for successful calls only.

### 3. BUG_ON on invalid parameter

```

insmod hello1.ko
insmod hello2.ko count=15

# System should oops/panic; inspect dmesg after reboot

```

Expected:
- Kernel oops/panic
- `PC is at hello2_init+...` line in `dmesg`
- This is used to map crash location to `BUG_ON(count > 10)` via `objdump`/`gdb` on `hello2.ko.unstripped`.

## Module Dependencies

- `hello2` depends on `hello1`:
  - `hello2` calls `print_hello()` exported from `hello1`
  - `hello1` must be inserted before `hello2`
  - `hello1` can be removed only after `hello2` is removed (in successful-load scenarios)
