# 07-R Battery charge threshold mechanisms on Fedora and Ubuntu

**Status:** facts only

**For:**
[07 The battery threshold keybind and its missing script](../issues/07-battery-threshold-keybind.md)

**Date:** 2026-09-23

## Scope and method

This document records what the sources say. It decides nothing; the deciding
happens in ticket 07.

Three kinds of evidence appear below, and each claim says which one it rests on.

| Kind               | What it is                                                                                                                                                |
| ------------------ | --------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Measured here**  | A command run on the Fedora reference machine (ASUSTeK ZenBook UX363EA, Fedora 44, kernel `7.2.5-200.fc44.x86_64`). The command is given with the result. |
| **Source read**    | Kernel source and `Documentation/ABI`, TLP's documentation and its packaged source, asusctl's source, UPower's source, `man 7 udev`, `man 5 tmpfiles.d`.  |
| **Not measurable** | Anything about the HP EliteBook. That machine is not reachable from here. Section 3 says what would settle it and gives the commands to run by hand.      |

Kernel sources were fetched from `git.kernel.org` (cgit `plain/`), which serves
the torvalds tree; where a tag matters it is named (`?h=v7.2`).
`lore.kernel.org` is behind a proof-of-work gate and could not be fetched; the
mailing list threads in section 3 are read from
[Ratatoskr](https://ratatoskr.run/), a `platform-driver-x86` archive mirror, and
the message dates and authors are quoted as that archive shows them.

---

## 1. Where `charge_control_end_threshold` comes from

### The ABI

The attribute is defined in the kernel's own
[`Documentation/ABI/testing/sysfs-class-power`](https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/plain/Documentation/ABI/testing/sysfs-class-power),
verbatim:

```
What:		/sys/class/power_supply/<supply_name>/charge_control_end_threshold
Date:		April 2019
Contact:	linux-pm@vger.kernel.org
Description:
		Represents a battery percentage level, above which charging will
		stop. Not all hardware is capable of setting this to an arbitrary
		percentage. Drivers will round written values to the nearest
		supported value. Reading back the value will show the actual
		threshold set by the driver.

		Access: Read, Write

		Valid values: 0 - 100 (percent)
```

Its sibling, which the reference machine does not have:

```
What:		/sys/class/power_supply/<supply_name>/charge_control_start_threshold
Date:		April 2019
Contact:	linux-pm@vger.kernel.org
Description:
		Represents a battery percentage level, below which charging will
		begin.

		Access: Read, Write
		Valid values: 0 - 100 (percent)
```

Note that the file is `ABI/testing/`, not `ABI/stable/`.

Two neighbouring properties matter for the HP side in section 3.
`charge_behaviour` (Date: November 2021) is a mode selector, not a percentage:

```
		Valid values:
			===================== ========================================
			auto:                 Charge normally, respect thresholds
			inhibit-charge:       Do not charge while AC is attached
			inhibit-charge-awake: inhibit-charge only when device is awake
			force-discharge:      Force discharge while AC is attached
			===================== ========================================
```

`charge_types` (Date: December 2024) reports a list such as
`"Fast [Standard] Long_Life"`, where `Long Life` is described under
`charge_type` as "The charger reduces its charging rate in order to prolong the
battery health."

### What the ABI says about persistence

**Nothing.** The whole file contains no occurrence of the words `persist`,
`reboot`, `resume`, `suspend`, `boot`, `volatile` or `reset`:

```console
$ grep -niE "persist|reboot|resume|suspend|boot|volatile|reset" sysfs-class-power
$ echo $?
1
```

The ABI promises a read/write percentage with driver-side rounding, and says
nothing at all about lifetime. Persistence is therefore a per-driver and
per-firmware fact, not an ABI guarantee. Sections 2 and 3 give it per driver.

### Which drivers provide it on this kernel

Measured here, on kernel `7.2.5-200.fc44.x86_64`, by decompressing every module
in the tree and searching for the attribute name:

```console
$ cd /lib/modules/$(uname -r)/kernel
$ find . -name '*.ko.xz' -print0 | xargs -0 -P8 -I{} sh -c \
    'xz -dc "{}" 2>/dev/null | grep -qa "charge_control_.*_threshold" && echo "{}"' | sort
./drivers/platform/x86/asus-wmi.ko.xz
./drivers/platform/x86/dell/dell-laptop.ko.xz
./drivers/platform/x86/fujitsu-laptop.ko.xz
./drivers/platform/x86/huawei-wmi.ko.xz
./drivers/platform/x86/lenovo/thinkpad_acpi.ko.xz
./drivers/platform/x86/lg-laptop.ko.xz
./drivers/platform/x86/msi-ec.ko.xz
./drivers/platform/x86/samsung-galaxybook.ko.xz
./drivers/platform/x86/system76_acpi.ko.xz
./drivers/platform/x86/toshiba_acpi.ko.xz
./drivers/power/supply/cros_charge-control.ko.xz
```

Nothing is built in: `grep -c "charge_control" /boot/System.map-$(uname -r)`
returns `0`. **No HP driver appears in that list.**

The attribute's permissions are not a policy choice by udev or by the distro.
`asus-wmi` declares it with
`static DEVICE_ATTR_RW(charge_control_end_threshold);`, and
[`Documentation/filesystems/sysfs.rst`](https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/plain/Documentation/filesystems/sysfs.rst)
says of the `__ATTR_RW` family that it "assumes default name_show, name_store
and setting mode to 0644". That is exactly what is on disk (measured here):

```console
$ ls -l /sys/class/power_supply/BAT0/charge_control_end_threshold
-rw-r--r--. 1 root root 4096 Sep 23 13:17 /sys/class/power_supply/BAT0/charge_control_end_threshold
```

---

## 2. The ASUS side

### Which module registers it

`asus-wmi`, through the ACPI battery hook API. Measured here:

```console
$ grep -i "charge_control" /proc/kallsyms
0000000000000000 t charge_control_end_threshold_show	[asus_wmi]
0000000000000000 t charge_control_end_threshold_store	[asus_wmi]
0000000000000000 d dev_attr_charge_control_end_threshold	[asus_wmi]
```

In
[`drivers/platform/x86/asus-wmi.c`](https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/plain/drivers/platform/x86/asus-wmi.c)
the hook is registered only when the WMI device id is present:

```c
static struct acpi_battery_hook battery_hook = {
	.add_battery = asus_wmi_battery_add,
	.remove_battery = asus_wmi_battery_remove,
	.name = "ASUS Battery Extension",
};

static void asus_wmi_battery_init(struct asus_wmi *asus)
{
	asus->battery_rsoc_available = false;
	if (asus_wmi_dev_is_present(asus, ASUS_WMI_DEVID_RSOC)) {
		asus->battery_rsoc_available = true;
		battery_hook_register(&battery_hook);
	}
}
```

This explains the shape seen on the reference machine: BAT0 is a plain ACPI
battery (`PNP0C0A`), and `asus-wmi` bolts one extra attribute onto it. The
battery driver itself has nothing to do with charge control.

`asus-armoury`, which is also loaded, contributes nothing here. Its source
contains no occurrence of `charge_control`, `battery_hook` or
`ASUS_WMI_DEVID_RSOC`, and measured here its firmware-attributes directory has
exactly one entry:

```console
$ ls /sys/class/firmware-attributes/asus-armoury/attributes/
pending_reboot
```

### The value is not read back from hardware

The `show` function returns a module-global cached in software, because the
firmware offers no read path:

```c
	/* There isn't any method in the DSDT to read the threshold, so we
	 * save the threshold.
	 */
	charge_end_threshold = value;
```

So `cat charge_control_end_threshold` reports what Linux last wrote in this
boot, not what the embedded controller is actually enforcing.

### Does the kernel restore the value across a reboot? No: it overwrites it

On kernel 7.2 the hook's `add_battery` callback actively writes 100 to the
hardware every time it runs:

```c
	/* The charge threshold is only reset when the system is power cycled,
	 * and we can't read the current threshold, however the majority of
	 * platforms retains it.
	 *
	 * Setting a negative value would signal the threshold as unknown
	 * until user explicitly sets it to a new value, however to avoid
	 * regressing userspace, we initialize it to a value of 100.
	 */
	charge_end_threshold = 100;
	ret = asus_wmi_set_devstate(ASUS_WMI_DEVID_RSOC, charge_end_threshold, &rv);
```

`add_battery` runs whenever `asus-wmi` registers its hook and whenever a battery
is added to the ACPI battery list, per
[`drivers/acpi/battery.c`](https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/plain/drivers/acpi/battery.c):

```c
	 * Since we added a new battery to the list, we need to
	 * iterate over the hooks and call add_battery for each
	 * hook that was registered. This usually happens
	 * when a battery gets hotplugged or initialized
	 * during the battery module initialization.
```

So: **every boot, every `modprobe` of `asus-wmi`, and every battery
hotplug/re-add resets the hardware limit to 100 %.** The hardware would have
retained the old value ("the majority of platforms retains it"); the driver
deliberately does not let it.

Suspend/resume is different: `asus-wmi`'s PM callbacks (`asus_hotk_resume`,
`asus_hotk_restore`) touch only the WLAN rfkill state and the keyboard LED. They
do not re-add the battery and do not touch `ASUS_WMI_DEVID_RSOC`, so a plain
suspend/resume leaves the threshold alone as far as the driver is concerned.
TLP's documentation disagrees for some ASUS hardware; see section 4.

### This behaviour changed twice in 2026

Three consecutive kernel series behave differently. Checked by fetching
`asus-wmi.c` at each tag and reading `asus_wmi_battery_add`:

| Kernel      | `asus_wmi_battery_add` does                                      | What `cat` shows after boot |
| ----------- | ---------------------------------------------------------------- | --------------------------- |
| up to v7.0  | `asus_wmi_set_devstate(RSOC, 100)`; `charge_end_threshold = 100` | `100`                       |
| v7.1        | writes nothing to hardware; `charge_end_threshold = -1`          | `-ENODATA` (read error)     |
| v7.2 (here) | `asus_wmi_set_devstate(RSOC, 100)` with error handling           | `100`                       |

The v7.1 change is commit
[`186bf9031666`](https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/commit/?id=186bf9031666602d61b40832181b6b6fdc3ba4dc)
(Denis Benato, 2026-03-04), "platform/x86: asus-wmi: do not enforce a battery
charge threshold":

> Users are complaining for the battery limit being reset at 100% during the
> boot process while the general consensus appears to not apply unsolicited
> hardware changes, therefore stop resetting the battery charge limit at boot
> and return -ENODATA on charge_end_threshold to signal for an unknown limit.

It was undone for v7.2 by commit
[`78bf392ba77d`](https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/commit/?id=78bf392ba77dd8b2a25656e489449d2f91cfd1eb)
(Denis Benato, 2026-07-10), "platform/x86: asus-wmi: temporarily revert to
setting a charge limit":

> A userspace regression has been observed leaving the battery charging
> threshold unconfigured, so while the fix is being shipped revert the change
> keeping the infrastructure in place to return to the preferred behaviour as
> soon as it's appropriate to do.

That commit's `Link:` trailers point at a
[UPower work item](https://gitlab.freedesktop.org/upower/upower/-/work_items/347),
which ties the revert to the UPower route described in section 6. The wording
"temporarily" and "as soon as it's appropriate" is the upstream author's, so the
v7.2 behaviour is explicitly described as not the intended end state.

That the reset is live on the reference machine is measured here:

```console
$ xz -dc /lib/modules/$(uname -r)/kernel/drivers/platform/x86/asus-wmi.ko.xz \
    | strings | grep -i "battery charge threshold"
3asus_wmi: Failed to reset battery charge threshold
3asus_wmi: Error in battery charge threshold reset
```

### Since when

The attribute arrived for ASUS in
[`d507a54f5865`](https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/commit/?id=d507a54f5865d8dcbdd16c66a1a2da15640878ca)
"platform/x86: asus-wmi: Add support for charge threshold" (2019-08-05) and was
moved onto the battery hook API by
[`7973353e92ee`](https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/commit/?id=7973353e92ee1e7ca3b2eb361a4b7cb66c92abee)
"platform/x86: asus-wmi: Refactor charge threshold to use the battery hooking
API" (2019-09-09), which is the v5.4 merge window. TLP's own vendor page
independently gives the same floor: "asus_wmi - required, included in
distribution kernels (5.4 or newer)".

### A uevent caveat that matters for any udev-based approach

When `asus-wmi` registers its hook after the battery already exists,
`battery_hook_register()` calls `power_supply_changed(battery->bat)`, and
`power_supply_changed_work()` in
[`drivers/power/supply/power_supply_core.c`](https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/plain/drivers/power/supply/power_supply_core.c)
emits `kobject_uevent(&psy->dev.kobj, KOBJ_CHANGE)`. The attribute therefore
appears on a **`change`** event, not on the battery's original `add` event. A
udev rule keyed on `ACTION=="add"` alone can run before the attribute exists.
This is the same ordering problem TLP documents from the other end; see
section 4.

---

## 3. The HP side

### In-tree support: absent

`hp-wmi` does not expose either threshold. Read from
[`drivers/platform/x86/hp/hp-wmi.c`](https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/plain/drivers/platform/x86/hp/hp-wmi.c)
at torvalds/master on 2026-09-23:

- `grep -n "charge_control"` returns nothing.
- `grep -n "battery_hook"` returns nothing.
- The complete set of sysfs attributes it creates is `display`, `hddtemp`,
  `als`, `dock`, `tablet`, `postcode`, `gpu_mux_mode` (the `DEVICE_ATTR_*`
  declarations feeding `hp_wmi_attrs[]`).
- The only battery-adjacent identifiers are event codes,
  `HPWMI_CPU_BATTERY_THROTTLE = 0x06`, `HPWMI_BATTERY_CHARGE_PERIOD = 0x10`,
  `HPWMI_BATTERY_QUERY = 0x07`. They are notifications, not controls.

No other in-tree driver covers HP either: the eleven modules listed in section 1
are the complete set on kernel 7.2.5, and `drivers/platform/x86/hp/` builds only
`hp_accel`, `hp-wmi`, `tc1100-wmi` and `hp-bioscfg`.

So the answer to "since which kernel version" is: **there is no version in the
evidence gathered here.** It is not partial and not model-dependent; for
`charge_control_*_threshold` it is absent from the HP drivers outright in
current master and in the modules shipped for 7.2.5, which are the two states
examined. No history check was run over earlier releases, so "it never existed"
is not claimed.

### What is in flight

Two 2026 mailing-list threads exist, both from Navon John Lukose, read from the
Ratatoskr mirror of `platform-driver-x86`.

The RFC,
["HP laptop charge mode control via POWER_SUPPLY_PROP_CHARGE_BEHAVIOUR"](https://ratatoskr.run/platform-driver-x86/2026/04/3531527/t)
(2026-04-27), states the starting point on the author's HP machine:

> On this machine, Linux currently exposes no native battery charge thresholds:
>
> - no charge_control_start_threshold
> - no charge_control_end_threshold
>
> The existing HP kernel drivers also do not expose this feature here:
>
> - hp-wmi does not expose battery charge mode control
> - hp-bioscfg is present, but does not expose Battery Health Manager or related
>   battery threshold attributes on this machine

and its intended scope:

> My current thinking is:
>
> - expose only POWER_SUPPLY_PROP_CHARGE_BEHAVIOUR
> - support AUTO, INHIBIT_CHARGE, and FORCE_DISCHARGE
> - do not synthesize charge_control_\*\_threshold properties in the kernel
> - leave policies such as "resume below 75%, stop above 80%" to userspace

Hans de Goede's reply on the same day confirms the ABI choice and says plainly
that a percentage cap is not what this gives you:

> Yes, POWER_SUPPLY_PROP_CHARGE_BEHAVIOUR was initially added for basically the
> same settings on Lenovo ThinkPad laptops. Note these options are typically
> used to implement battery "fuel-gauge" calibration functionality.
>
> I guess inhibit charge could be used together with a userspace daemon
> monitoring charge to implement a charge to 80% threshold. But that would be a
> new way to use this API.

The implementation,
["[RFC PATCH] platform/x86: hp-wmi: Add charge behaviour support"](https://ratatoskr.run/platform-driver-x86/2026/05/3546141/t)
(first posted 2026-05-05, latest message in the thread 2026-09-08), is still RFC
and still gated to one board:

> Expose the mode control through the standard power_supply charge_behaviour
> property using a battery hook and power_supply extension. The initial quirk is
> limited to board 85C6 and still requires a successful charge mode read before
> registering the extension.

Even if it lands, it adds `charge_behaviour` with values `auto` /
`inhibit-charge` / `force-discharge`, not a percentage. The vendor firmware path
it drives is `\SBCC 0x0000` (auto), `\SBCO 0x0500` (inhibit charge),
`\SBCO 0x0200` (force discharge), reached through HP's BIOS WMI GUID
`5FB7F034-2C63-45E9-BE91-3D44E2C707E4`.

### The one other in-tree place an HP setting could surface

`hp-bioscfg` is a generic BIOS-attribute driver. It exposes whatever the
firmware offers under `/sys/class/firmware-attributes/*/attributes/*/`, per
[`Documentation/ABI/testing/sysfs-class-firmware-attributes`](https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/plain/Documentation/ABI/testing/sysfs-class-firmware-attributes)
(Date: February 2021, KernelVersion: 5.11). That ABI file itself never mentions
batteries or charging: it is a container, and whether an HP "Battery Health
Manager"-style setting shows up there is firmware-dependent per model. The RFC
author reports it did not on his machine. It is unknown for the EliteBook and is
the single most worthwhile thing to check by hand.

### Commands to settle it on the EliteBook

To be run by hand on the HP machine. Steps 0 to 5 are read-only and need no
root; step 6 needs `tlp` installed and root to run its probe; step 7 needs root
only to read an ACPI table.

```sh
# 0. Identify the machine, so the answer can be attached to a model.
cat /sys/class/dmi/id/sys_vendor /sys/class/dmi/id/product_name \
    /sys/class/dmi/id/product_family /sys/class/dmi/id/board_name \
    /sys/class/dmi/id/bios_version
uname -r

# 1. Does any charge control attribute exist at all?
ls -l /sys/class/power_supply/
for b in /sys/class/power_supply/BAT*; do
  echo "== ${b}"
  ls -l "${b}" | grep -E 'charge_control|charge_behaviour|charge_type'
done
cat /sys/class/power_supply/BAT*/charge_control_end_threshold 2>&1
cat /sys/class/power_supply/BAT*/charge_control_start_threshold 2>&1
cat /sys/class/power_supply/BAT*/charge_behaviour 2>&1
cat /sys/class/power_supply/BAT*/charge_types 2>&1

# 2. Which HP platform drivers are loaded?
lsmod | grep -E 'hp_wmi|hp_bioscfg|hp_accel|wmi'
ls /sys/bus/wmi/devices/

# 3. Does ANY module in this kernel carry the attribute? (handles .ko, .xz, .zst,
#    .gz, so it works on both Ubuntu and Fedora)
cd /lib/modules/"$(uname -r)"/kernel
find . -name '*.ko*' -print0 | xargs -0 -P4 -I{} sh -c '
  case "{}" in
    *.zst) zstdcat "{}" 2>/dev/null ;;
    *.xz)  xzcat   "{}" 2>/dev/null ;;
    *.gz)  zcat    "{}" 2>/dev/null ;;
    *)     cat     "{}" ;;
  esac | grep -qa "charge_control_.*_threshold" && echo "{}"' | sort
grep -c "charge_control" /boot/System.map-"$(uname -r)"

# 4. Does the BIOS expose a charge setting through hp-bioscfg?
ls /sys/class/firmware-attributes/
ls /sys/class/firmware-attributes/*/attributes/ | grep -iE 'batt|charg|health'
# for each hit <name>:
#   cat /sys/class/firmware-attributes/hp-bioscfg/attributes/<name>/type
#   cat /sys/class/firmware-attributes/hp-bioscfg/attributes/<name>/current_value
#   cat /sys/class/firmware-attributes/hp-bioscfg/attributes/<name>/possible_values

# 5. What does UPower see? (no root; see section 6)
upower -i /org/freedesktop/UPower/devices/battery_BAT0
gdbus introspect --system --dest org.freedesktop.UPower \
  --object-path /org/freedesktop/UPower/devices/battery_BAT0 | grep -i charge

# 6. What does TLP's own probe say? (needs tlp installed; see section 4)
sudo tlp-stat -b

# 7. Are the RFC's firmware methods even present? (root, read-only)
sudo cp /sys/firmware/acpi/tables/DSDT /tmp/DSDT.dat
iasl -d /tmp/DSDT.dat            # package: acpica-tools
grep -nE 'SBCC|SBCO|GBCC|GBCO|WHCM' /tmp/DSDT.dsl
```

What each outcome means:

- Step 1 shows `charge_control_end_threshold`: something out of the ordinary is
  in play (an out-of-tree or vendor module); step 3 names it.
- Step 1 shows only `charge_behaviour` or `charge_types`: the machine has mode
  control, not a percentage cap.
- Step 1 shows nothing and step 4 shows a battery attribute: the cap exists but
  lives in the firmware-attributes interface and is set there, likely needing a
  reboot (`pending_reboot`).
- Step 1 and step 4 both empty, step 6 prints `Plugin: generic` /
  `Supported features: none available`: the machine has no Linux charge control
  at all, and step 7 says whether the RFC's path could ever reach it.

---

## 4. TLP

Read from TLP's own documentation (version 1.10.2, "Last updated on Jul 06,
2026") and from the source shipped in Fedora's `tlp-1.10.1-1.fc44` RPM.

### Vendor support: ASUS yes, HP no

[Battery Care Vendor Specifics](https://linrunner.de/tlp/settings/bc-vendors.html)
opens with:

> **Important** Battery care is not supported for any hardware that is not
> specifically listed on this page.

The page lists: Apple Macbooks, ASUS, Chromebooks (and Framework), Dell, Huawei,
Lenovo ThinkPads, Lenovo/IBM legacy ThinkPads, Lenovo non-ThinkPad series, LG,
MSI laptops, Samsung, Sony, System76, Toshiba, Tuxedo Laptops, Wilco-EC. **HP
appears nowhere on the page**, and neither `hp`, `hp-wmi`, `hp_wmi`, `EliteBook`
nor `Hewlett` occurs anywhere in its text.

The packaged source agrees. TLP's battery plugins are one file per vendor, and
there is no HP one (measured here, from the Fedora RPM):

```console
$ rpm2cpio tlp-1.10.1-1.fc44.noarch.rpm | cpio -idm
$ ls usr/share/tlp/bat.d/
05-thinkpad  10-thinkpad-legacy  15-lenovo  16-lenovo-legacy  20-huawei
25-msi  30-samsung  35-lg  40-sony  45-system76  50-toshiba  55-cros-ec
60-macbook  65-dell  66-wilco-ec  70-tuxedo  89-asus  90-generic  TEMPLATE
```

The documentation describes exactly what an unsupported machine looks like:

> For any laptop vendor/brand/model without
>
> - hardware capabilities or
> - corresponding kernel driver
>
> the `tlp-stat -b` output would look like this:
>
> ```
> +++ Battery Care
> Plugin: generic
> Supported features: none available
> ...
> /sys/class/power_supply/BAT0/charge_control_start_threshold = (not available)
> /sys/class/power_supply/BAT0/charge_control_end_threshold   = (not available)
> ```
>
> Please do not submit TLP issues for this case.

There is a third case worth knowing for the EliteBook: if the kernel did expose
the attribute but no plugin matched, TLP reports `Plugin: generic` /
`Supported features: none available` while the sysfs files show real numbers,
and the docs say "In this case, you might submit an issue to request development
of a suitable plugin." TLP would then still not set it.

### What TLP says about ASUS

The ASUS section, quoted in full for the parts that bear on this ticket:

> **Kernel driver:** asus_wmi - required, included in distribution kernels (5.4
> or newer) **TLP version (min):** 1.4 **TLP plugin:** asus **Charge control
> options:** Stop charge threshold **Threshold configuration:** Batteries BAT0,
> BATC and BATT share the STOP_CHARGE_THRESH_BAT0 parameter. Battery BAT1 uses
> the STOP_CHARGE_THRESH_BAT1 parameter **Stop threshold values:** Range: 1
> .. 100. Special: 0 - threshold off, 100 - hardware default

and, under Specifics:

> Some ASUS laptops silently ignore stop threshold values other than 40, 60
> or 80. Please check if your configuration works as expected.
>
> When resuming from suspend TLP restores the threshold.
>
> When powering on, ASUS laptops reset the charge thresholds. TLP restores them
> on boot, but due to the hardware's behaviour, there is a short time window
> where the thresholds do not take effect.

The reference machine's current value of `60` is one of the three values that
paragraph names. Note also the disagreement with section 2: TLP attributes the
boot-time reset to the laptop ("When powering on, ASUS laptops reset the charge
thresholds"), while the kernel source attributes it to the driver deliberately
writing 100 at every `add_battery`, and the kernel comment says the hardware
itself "retains it" on "the majority of platforms". Both sources describe the
same observable outcome; they differ on the cause.

TLP also documents an ordering failure that matches the uevent caveat in section
2:

> **ASUS laptops: stop charge threshold isn't set at boot** Symptom: Battery
> stop charge threshold isn't set at boot. But manually running `tlp start` or
> `tlp setcharge` sets the threshold. Cause: kernel module asus_wmi is loaded
> too late in the boot sequence. Solution: add the module to the Initramfs.

### `tlp setcharge` requires root

Yes, hard-coded. From the packaged `usr/share/tlp/tlp-func-base`:

```sh
test_root () {
    # test root privilege -- rc: 0=root, 1=not root
    [ "$(id -u)" = "0" ]
}

check_root () {
    # show error message and quit when root privilege missing
    if ! test_root; then
        cecho "Error: missing root privilege." 1>&2
        do_exit 1
    fi
}
```

and `usr/bin/tlp`:

```sh
    setcharge) # set charge thresholds (temporarily)
        check_root
```

TLP ships no setuid binary, no polkit action and no D-Bus service for this. Its
[man page](https://linrunner.de/tlp/usage/tlp.html) writes every invocation as
`sudo tlp setcharge ...`. Nothing in TLP makes the threshold settable without
root; it moves the root requirement from your own script into a packaged one.

### Does TLP replace a hand-written unit plus state file? Yes

Three mechanisms, all in the package.

**Boot.** `tlp.service` is `Type=oneshot` with
`ExecStart=@TLP_SBIN@/tlp init start`, and the FAQ is explicit:

> YES, the service units are indispensable for correct operation - tlp.service
> applies power saving settings and charge thresholds as well as switching radio
> devices on system boot and shutdown.

**Resume.** `/usr/lib/systemd/system-sleep/tlp`:

```sh
case $1 in
    pre)  tlp suspend ;;
    post) tlp resume  ;;
esac
```

and in `usr/bin/tlp`, the `resume)` branch calls
`init_batteries_thresholds "asus huawei lg"` for exactly the hardware that
resets its EC across suspend.

**AC/battery transitions.** `/usr/lib/udev/rules.d/85-tlp.rules`:

```
ACTION=="change", SUBSYSTEM=="power_supply", KERNEL!="hidpp_battery*", RUN+="/usr/bin/tlp auto"
```

The state that survives a reboot is the config file, not a state file. From the
FAQ:

> It is not enough to set charge thresholds once with the `tlp setcharge`
> command. To make charge thresholds permanent, even if the hardware does not
> have the ability to keep them persistent, you have to enter them into the
> configuration file, for example `/etc/tlp.conf`.

and from the man page:

> `tlp setcharge` changes the charge thresholds only temporarily. To make the
> change permanent, you must activate or change the related settings in the
> config file.

One consequence of the config-as-state design: a keybind that toggles between
two values cannot use `tlp setcharge` alone, because `setcharge` is explicitly
temporary and the next boot restores whatever `/etc/tlp.conf` says. Making a
toggle durable means editing that root-owned file and running `tlp start`.

### Where the configuration lives, and whether there is a user route

From
[Settings: Introduction](https://linrunner.de/tlp/settings/introduction.html):

> Settings are read from the following files in the specified order:
>
> - Intrinsic defaults
> - `/etc/tlp.d/*.conf`: Drop-in customization snippets, read in lexical
>   (alphabetical) order
> - `/etc/tlp.conf`: User configuration

That is the complete list. Both paths are root-owned; the page's own quick
instructions begin `sudo nano /etc/tlp.conf`. **There is no `$HOME`, `XDG` or
per-user configuration route documented anywhere in TLP's settings
documentation**, and the intrinsic defaults live in
`/usr/share/tlp/defaults.conf` inside the package. For this repo that means
TLP's config cannot be a stowed dotfile; it is a manual, per-machine, root-owned
change of exactly the kind ticket 05 collects.

### Packaging

**Fedora 44.** Package `tlp`, plus `tlp-rdw` and `tlp-pd`, in Fedora's own
repositories. Measured here:

```console
$ dnf repoquery --qf '%{name}-%{evr} %{reponame}\n' tlp tlp-rdw tlp-pd
tlp-1.10.1-1.fc44 Fedora 44 - x86_64 - Updates
tlp-1.9.0-7.fc44 Fedora 44 - x86_64
tlp-pd-1.10.1-1.fc44 Fedora 44 - x86_64 - Updates
tlp-rdw-1.10.1-1.fc44 Fedora 44 - x86_64 - Updates
```

[mdapi](https://mdapi.fedoraproject.org/f44/pkg/tlp) reports `1.10.2-1.fc44` as
the newest build, in `updates-testing`; as in the ticket 02 survey, mdapi
answers for the newest build across `release`, `updates` and `updates-testing`,
and the `dnf` output above shows the package is in the base repositories either
way. Binaries: `/usr/bin/tlp`, `/usr/bin/tlp-stat`, `/usr/bin/tlpctl`, plus
`bluetooth`, `nfc`, `wifi`, `wwan`, `run-on-ac`, `run-on-bat`.

**Ubuntu: `main`, not universe.** Queried against Canonical's own Launchpad API
(`getPublishedSources`, `exact_match=true`, `status=Published`):

| Series           | Version        | Component | Launchpad series status |
| ---------------- | -------------- | --------- | ----------------------- |
| noble (24.04)    | 1.6.1-1ubuntu1 | main      | Supported               |
| plucky (25.04)   | 1.8.0-1ubuntu1 | main      | Obsolete                |
| questing (25.10) | 1.8.0-1ubuntu1 | main      | Obsolete                |
| resolute (26.04) | 1.8.0-1ubuntu2 | main      | Current Stable Release  |

Confirmed on the binary publication as well (`getPublishedBinaries` for
noble/amd64 → `tlp 1.6.1-1ubuntu1 main utils Release`). The status column is
Launchpad's own `/1.0/ubuntu/series` field; the ticket asked about 24.04 and
25.04, and 25.04 is marked `Obsolete` there, so the live pair of Ubuntu targets
today is 24.04 LTS and 26.04 LTS. Launchpad still lists published sources for
obsolete series.

Ubuntu puts the main binary at a different path: the noble file list gives
`/usr/sbin/tlp` and `/usr/bin/tlp-stat`, and resolute (1.8.0) still has
`/usr/sbin/tlp`. Fedora has `/usr/bin/tlp`. Config paths are the same on both:
`/etc/tlp.conf`, `/etc/tlp.d/`.

Ubuntu 24.04's 1.6.1 predates several things the TLP documentation above
describes for 1.10.x; the vendor page's "TLP version (min)" for ASUS is 1.4, so
ASUS stop thresholds are covered by every version in the table.

**Service enablement differs.** From TLP's installation FAQ:

> Debian, Ubuntu and derivatives enable the service by default as part of the
> package Installation, others such as Arch Linux, Fedora and openSUSE don't.

So on Fedora, installing the package is not enough;
`systemctl enable tlp.service` is a separate step.

### Side effects of installing TLP

TLP is a full power-management daemon. `apply_common_settings()` in
`usr/bin/tlp` runs, on every boot and every AC/battery transition:

```sh
    set_laptopmode          set_dirty_parms         set_platform_profile
    set_cpu_driver_opmode   set_cpu_scaling_governor
    set_cpu_scaling_min_max_freq                    set_intel_cpu_perf_pct
    set_cpu_boost_all       set_cpu_dyn_boost       set_cpu_perf_policy
    set_nmi_watchdog        set_mem_sleep           set_ahci_port_runtime_pm
    set_runtime_pm          set_ahci_disk_runtime_pm
    set_sata_link_power     set_disk_apm_level      set_disk_spindown_timeout
    set_disk_iosched        set_pcie_aspm           set_intel_gpu_power_profile
    set_intel_gpu_min_max_boost_freq                set_amdgpu_profile
    set_abm_level           set_wifi_power_mode     disable_wake_on_lan
    set_sound_power_mode
```

The intrinsic defaults in `usr/share/tlp/defaults.conf` are active from the
first boot, among them `TLP_ENABLE=1`, `USB_AUTOSUSPEND=1`,
`RUNTIME_PM_ON_BAT=auto`, `SATA_LINKPWR_ON_AC="med_power_with_dipm"`,
`WIFI_PWR_ON_BAT=on`, `SOUND_POWER_SAVE_ON_AC=1`, `DISK_IDLE_SECS_ON_BAT=2`,
`PLATFORM_PROFILE_ON_BAT=balanced`,
`CPU_ENERGY_PERF_POLICY_ON_BAT=balance_power`. It also ships
`/usr/lib/udev/tlp-usb-udev` and rules that act on every added USB and disk
device.

**Package-level conflicts differ between the two distributions.** Fedora's RPM
declares `Conflicts: laptop-mode-tools, tuned`. The reference machine has both
`tuned-2.28.0-1.fc44` and `tuned-ppd-2.28.0-1.fc44` installed (measured here
with `rpm -q`), so installing `tlp` on it means removing them. Ubuntu's deb
declares only `Conflicts: laptop-mode-tools` (read from the control file of
`tlp_1.6.1-1ubuntu1_all.deb`), but the functional conflict is the same and TLP
documents it:

> By default, many distributions install power-profiles-daemon as an optional
> component of the GNOME desktop environment. power-profiles-daemon competes and
> conflicts with TLP.

The same page also warns that the desktop's own charge-threshold UI fights TLP:

> In addition, the GNOME desktop can apply battery charge thresholds if
> configured. To disable the setting, go to Settings → Battery Charging and
> check Maximize Charge, then use the `tlp start` command to re-apply the
> thresholds already configured in TLP.

That GNOME setting is the UPower route in section 6.

---

## 5. asusctl

**Charge thresholds: yes, end threshold only.** The
[README](https://gitlab.com/asus-linux/asusctl/-/raw/main/README.md) lists "[x]
Set battery charge limit (with kernel supporting this)". The CLI subcommand,
from `asusctl/src/cli_opts.rs`:

```rust
#[argh(subcommand, name = "limit",
       description = "set battery charge limit <20-100>")]
pub struct BatteryLimitCommand {
    #[argh(positional, description = "charge limit percentage 20-100")]
    pub limit: u8,
}
```

so `asusctl battery limit <20-100>`, plus `battery oneshot` and `battery info`.
The backend writes the same kernel file: `rog-platform/src/power.rs` declares
`attr_num!("charge_control_end_threshold", battery, u8);`. asusctl is a client
of the same `asus-wmi` attribute, not a second mechanism.

**Daemon as root: yes.** `data/asusd.service` has no `User=`, so `asusd` runs as
root, `Type=dbus`, `BusName=xyz.ljones.Asusd`. It is started by device
activation, not socket activation: a udev rule (`data/asusd.rules`) matching
ASUS DMI vendor plus a family list including `*Zen*ook*` pulls the service unit
in. No `.socket` unit and no socket hand-off is involved.

**No sudo needed for the client**, but not via polkit. The repo carries no
polkit policy; access is granted by a D-Bus bus policy, `data/asusd.conf`:

```xml
    <policy group="adm">  <allow send_destination="xyz.ljones.Asusd"/> ... </policy>
    <policy group="sudo"> <allow send_destination="xyz.ljones.Asusd"/> ... </policy>
    <policy group="users"><allow send_destination="xyz.ljones.Asusd"/> ... </policy>
    <policy group="wheel"><allow send_destination="xyz.ljones.Asusd"/> ... </policy>
```

Any member of `adm`, `sudo`, `users` or `wheel` may call the daemon's methods.
There is no per-call authentication and no password prompt: group membership is
the whole check.

**Restores across reboot: yes, by itself.** `asusd` keeps its own configuration
under `/etc/asusd/` (`const CONFIG_PATH_BASE: &str = "/etc/asusd/";` in
`asusd/src/lib.rs`), storing `charge_control_end_threshold` and
`base_charge_control_end_threshold`. `CtrlPlatform`'s `Reloadable::reload()`
re-applies it at daemon start:

```rust
        if self.power.has_charge_control_end_threshold() {
            let limit = self.config.lock().await.charge_control_end_threshold;
            info!("reloading charge_control_end_threshold to {limit}");
            self.power.set_charge_control_end_threshold(limit)?;
```

**Packaging, Fedora: not in Fedora.** Measured here:

```console
$ dnf repoquery --repo=fedora --repo=updates --repo=updates-testing --qf '%{name} %{reponame}\n' asusctl
(no output)
$ dnf repoquery --qf '%{name}-%{evr} %{reponame}\n' asusctl asusctl-rog-gui
asusctl-1:6.5.0-1.fc44 Terra 44
asusctl-rog-gui-1:6.5.0-1.fc44 Terra 44
```

[packages.fedoraproject.org](https://packages.fedoraproject.org/search?query=asusctl)
answers "No results found!". The packages that were installed and removed on the
reference machine came from **Terra**, a third-party repository configured in
`/etc/yum.repos.d/terra.repo`
(`metalink=https://tetsudou.fyralabs.com/metalink?repo=terra$releasever&arch=$basearch`,
Fyra Labs).

**Packaging, Ubuntu: not in the archive at all.** Launchpad
`getPublishedSources` for `source_name=asusctl` returns zero entries for noble,
plucky, questing and resolute, and zero across all series.

**Caveats from upstream.** The README's own warnings:

> **WARNING:** Many features are developed in tandem with kernel patches. If you
> see a feature is missing you either need a patched kernel or latest release.
>
> Due to on-going driver work the minimum suggested kernel version is always
> **the latest**, as improvements and fixes are continuous.

and the project has moved:

> This project has been migrated to the OGC on GitHub and future development
> will happen there.

It is also ASUS-only by construction, so on the HP machine it is not an option
in any form.

---

## 6. Making the attribute writable without `sudo`

### udev `OWNER`, `GROUP`, `MODE` do not reach sysfs attributes

`man 7 udev` (systemd 259, installed here) defines them in one sentence:

```
       OWNER, GROUP, MODE
           The permissions for the device node. Every specified value overrides
           the compiled-in default value.
```

"The permissions for the device node" is the whole promise. A `power_supply`
class device has no device node. Measured here:

```console
$ udevadm info -p /sys/class/power_supply/BAT0 | grep -c DEVNAME
0
```

There is nothing for `MODE=` to act on, so the pattern
`SUBSYSTEM=="power_supply", KERNEL=="BAT0", MODE="0664", GROUP="wheel"` is not
"unsupported" so much as inapplicable: udev will accept the rule and it will
change nothing about `charge_control_end_threshold`. The same man page is silent
on sysfs attribute permissions throughout; the only sysfs write key it documents
is the value assignment:

```
       ATTR{key}
           The value that should be written to a sysfs attribute of the event
           device.
```

That is a documented way to set the **value**, not the **mode**:
`SUBSYSTEM=="power_supply", KERNEL=="BAT0", ATTR{charge_control_end_threshold}="60"`.

### `RUN+="/bin/chmod ..."` is documented as a mechanism, not as this pattern

`RUN{program}` is documented and would work, within limits the same man page
states:

```
           This can only be used for very short-running foreground tasks.
           Running an event process for a long period of time may block all
           further events for this or a dependent device.
...
           Starting daemons or other long-running processes is not allowed; the
           forked processes, detached or not, will be unconditionally killed
           after the event handling has finished.
```

A single `chmod` qualifies as a very short-running foreground task. But **no
systemd or kernel documentation presents chmod-ing a sysfs attribute from a udev
rule as a supported pattern**, and there is no precedent in what is installed
here: across every rule file shipped on the reference machine,

```console
$ grep -rn 'RUN+="/bin/chmod\|RUN+="/usr/bin/chmod\|RUN+=".*chown' \
    /usr/lib/udev/rules.d/ /etc/udev/rules.d/
$ echo $?
1
```

returns nothing. It is a local convention people use, not a documented
interface.

Two behavioural facts about such a rule:

- **The mode survives suspend/resume.** Nothing removes and recreates the sysfs
  file across a plain suspend cycle: `asus-wmi`'s PM callbacks do not re-add the
  battery (section 2), and the inode persists.
- **The mode is lost and must be re-applied whenever the attribute is
  recreated**, that is on every boot, on
  `modprobe -r asus_wmi; modprobe asus_wmi`, and on a battery remove/add. The
  file is created by
  `device_create_file(&battery->dev, &dev_attr_charge_control_end_threshold)`
  inside `asus_wmi_battery_add()`, with the driver's compiled-in `0644` from
  `DEVICE_ATTR_RW`. Any chmod applies to that instance only.
- **The rule must match `change`, not just `add`** (section 2): the attribute
  appears when `asus-wmi` registers its hook, which fires
  `power_supply_changed()` → `KOBJ_CHANGE`, after the battery's own `add` event.

### Writes go through the file mode and nothing else

`charge_control_end_threshold_store()` in `asus-wmi.c` contains no `capable()`,
no `CAP_SYS_ADMIN` check and no uid check. It parses the integer, range-checks
`0..100`, and calls the WMI method:

```c
	ret = kstrtouint(buf, 10, &value);
	if (ret)
		return ret;

	if (value < 0 || value > 100)
		return -EINVAL;

	ret = asus_wmi_set_devstate(ASUS_WMI_DEVID_RSOC, value, &rv);
```

The only gate is the ordinary VFS permission check against the inode mode that
sysfs derives from the attribute's declared `.mode`. There is no LSM hook
specific to this attribute; SELinux applies its generic `sysfs_t` file rules,
and on this machine the file carries the default context (the `.` in `ls -l`
output above).

This can be confirmed by hand on the reference machine with a command that
attempts the write as the normal user and is expected to be refused before the
kernel does anything:

```sh
# expected: "Permission denied"; writes nothing if it fails, and writes the
# value it already holds if the mode were permissive
echo 60 > /sys/class/power_supply/BAT0/charge_control_end_threshold
```

It was not run here, because it is a write against the live system rather than a
scratch directory.

### The polkit route: UPower, and it is already running here

There is one, and it comes from UPower rather than from the kernel or systemd.
Measured here on the reference machine (`upower-1.91.4-1.fc44`):

```console
$ gdbus introspect --system --dest org.freedesktop.UPower \
    --object-path /org/freedesktop/UPower/devices/battery_BAT0 | grep -i charge
      EnableChargeThreshold(in  b chargeThreshold);
      readonly i ChargeCycles = 1;
      readonly u ChargeStartThreshold = 75;
      readonly u ChargeEndThreshold = 80;
      readonly b ChargeThresholdEnabled = false;
      readonly b ChargeThresholdSupported = true;
      readonly u ChargeThresholdSettingsSupported = 2;
```

The method is gated by a polkit action.
`/usr/share/polkit-1/actions/org.freedesktop.upower.policy`, verbatim:

```xml
  <action id="org.freedesktop.UPower.enable-charging-limit">
    <description>Enable battery charging limit</description>
    <message>Authentication is required to set battery charging start and end limit.</message>
    <defaults>
      <allow_inactive>no</allow_inactive>
      <allow_active>yes</allow_active>
    </defaults>
  </action>
```

`<allow_active>yes</allow_active>` means an active local session is allowed
without any authentication. The gate is enforced in `src/up-device.c`:

```c
	if (!up_daemon_polkit_is_allowed (priv->daemon,
					  "org.freedesktop.UPower.enable-charging-limit",
					  invocation))
		return FALSE;
```

and the actual sysfs write happens inside the root daemon, in
`src/linux/up-device-supply-battery.c`, so the user never needs write permission
on the file:

```c
	if (end != G_MAXUINT) {
		g_string_printf (end_str, "%d", CLAMP (end, 0, 100));
		if (!g_file_set_contents_full (end_filename, end_str->str, end_str->len,
					  G_FILE_SET_CONTENTS_ONLY_EXISTING, 0644, NULL))
			err_count++;
	}
```

**The method is a boolean, not a percentage.** `EnableChargeThreshold(b)` is
documented in
[`dbus/org.freedesktop.UPower.Device.xml`](https://gitlab.freedesktop.org/upower/upower/-/raw/master/dbus/org.freedesktop.UPower.Device.xml):

> If it is true, the battery charge will be limited to ChargeEndThreshold and
> start to charge when the battery is lower than ChargeStartThreshold. [...] If
> it is false, the battery will always be fully charged.

`ChargeStartThreshold` and `ChargeEndThreshold` are `access="read"`. They are
not settable over D-Bus at all.

**Where 75 and 80 come from, and how to change them.** UPower reads a udev
property `CHARGE_LIMIT`, imported from a hwdb it ships.
`/usr/lib/udev/rules.d/60-upower-battery.rules`:

```
SUBSYSTEM=="power_supply", TEST=="charge_control_end_threshold", \
  IMPORT{builtin}="hwdb 'battery:$kernel:$attr{model_name}:$attr{[dmi/id]modalias}'", \
  GOTO="battery_end"
```

and `/usr/lib/udev/hwdb.d/60-upower-battery.hwdb` ends with a catch-all:

```
battery:*:*:dmi:*
 CHARGE_LIMIT=75,80
```

The same file documents the override route in its own header:

```
# CHARGE_LIMIT is in tuple format and each of the variables can be disabled by "_" character.
# For example:
# CHARGE_LIMIT=60,80 (charge_control_start_threshold is 60 and charge_control_end_threshold is 80.)
# CHARGE_LIMIT=_,80 (charge_control_start_threshold will be skipped and charge_control_end_threshold is 80.)
...
# To add local overrides, create a new file
# /etc/udev/hwdb.d/61-battery-local.hwdb
# and add your rules there. To load the new rules execute (as root):
# systemd-hwdb  update
# udevadm trigger -v -p /sys/class/power_supply/BAT
```

`ChargeThresholdSettingsSupported = 2` on this machine matches the driver: the
XML defines `1` as start threshold, `2` as end threshold, `4` as
firmware-controlled behaviours, so `2` means end threshold only.

**UPower restores it across reboot by itself.** It persists the on/off state in
a file and re-applies it when the device is coldplugged, in
`src/up-device-battery.c`:

```c
	state_filename = g_strdup_printf("charging-threshold-status");
	state_dir = up_device_battery_get_state_dir (self);
	filename = g_build_filename (state_dir, state_filename, NULL);
```

and

```c
	if (info->charge_control_supported == TRUE) {
		if (enabled == TRUE) {
			up_device_battery_set_charge_thresholds (self,
								 info->charge_control_start_threshold,
								 info->charge_control_end_threshold,
								 &error);
```

The state directory is `/var/lib/upower` on this machine. This is the userspace
counterpart that the kernel's July 2026 revert (section 2) points at.

GNOME surfaces this as Settings → Battery Charging → "Maximize Charge", per
TLP's conflicts page quoted in section 4. Whether other desktops expose the same
route was not checked and nothing here claims it.

### The systemd route for the value

`systemd-tmpfiles` is a documented mechanism that reaches sysfs.
`man 5 tmpfiles.d` (systemd 259) says in its description that it is used for

> the API file systems such as /sys/ or /proc/

and defines both a value write and a permission adjustment:

```
       w, w+
           Write the argument parameter to a file, if the file exists.
...
       z
           Adjust the access mode, user and group ownership, and restore the
           SELinux security context of a file or directory, if it exists.
```

with an example in the man page itself writing to `/proc/sys`
(`w- /proc/sys/vm/swappiness - - - - 10`). Two properties follow from how it
runs: `systemd-tmpfiles-setup.service` executes once during boot, so it does not
re-apply on a later module reload or battery re-add, and its config lives under
`/etc/tmpfiles.d/`, root-owned like every other route in this section.

### Summary of section 6

| Route                                          | Documented for this use | Needs root to configure | Re-applied automatically                      |
| ---------------------------------------------- | ----------------------- | ----------------------- | --------------------------------------------- |
| udev `OWNER`/`GROUP`/`MODE`                    | No: device nodes only   | root-owned rules dir    | n/a, has no effect here                       |
| udev `RUN+="chmod"`                            | `RUN` yes, this use no  | root-owned rules dir    | on each matching uevent, if keyed on `change` |
| udev `ATTR{charge_control_end_threshold}="60"` | Yes, for the value      | root-owned rules dir    | on each matching uevent                       |
| `systemd-tmpfiles` `w` (value) / `z` (mode)    | Yes                     | root-owned config dir   | once at boot only                             |
| UPower `EnableChargeThreshold` + polkit        | Yes                     | root for the hwdb value | yes, UPower's own state file                  |
| TLP `/etc/tlp.conf` + `tlp.service`            | Yes                     | root-owned config       | boot, resume, AC/battery change               |
| asusctl D-Bus (group `wheel`)                  | Yes                     | root-owned `/etc/asusd` | yes, daemon config                            |

Every route's configuration is root-owned. None of them has a `$HOME` or XDG
path. The difference between them is not whether root is involved at
configuration time, but whether root is involved at _toggle_ time: UPower's
polkit action and asusctl's D-Bus policy are the only two that let an ordinary
desktop session flip the setting without `sudo`, and UPower's is a boolean
against a hwdb-configured pair rather than an arbitrary percentage.
