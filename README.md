Run arm64/aarch64 Linux Alpine virtualized on macOS x86_64 with QEMU.

Requires `qemu-system-aarch64` to be installed, which you can get from Homebrew:

```
brew install qemu
```

Run:

```
./qemu-arm64.sh
```

The first time you run this it will copy `user-data-init.qcow2` to `user-data.qcow2` and boot
up Alpine Linux via `qemu-system-aarch64`. The only user is `root` and has no password.

**DO NOT USE THIS OVER THE INTERNET!** There is no password for root and no firewall.
This is intended to be used locally only.

What you should do next is to save the VM state after logging in.
This makes qemu able to start up instantly and also allows you to resume where you left off.
With your vm running, open a second terminal and...

```
rlwrap socat -,echo=0,icanon=0 unix-connect:monitor.sock
```

This enters interactive qemu monitor control. Type `savevm NAME` where NAME is some descriptive name like "init", "checkpoint" or "before-i-fuck-it-all-up". This causes the VM's entire state to be saved (into `user-data.qcow2`) and can later be restored.

- To restore a state while running: issue `loadvm NAME` in the monitor
- To cold start directly into a saved state: run the script with `./qemu-arm64.sh NAME`

You can get socat from Homebrew with `brew install socat`

[See the QEMU documentation on VM states for more details](https://qemu.readthedocs.io/en/latest/system/images.html#vm-snapshots)

It's strongly recommended to always save a VM state before shutting down as startup is so much faster from a snapshot than it is by booting clean. A normal boot can take up to a minute while starting from a VM snapshot usually only takes a few hundred milliseconds.

Instead of shutting down with `reboot` in the guest, use the monitor:

```
$ rlwrap socat -,echo=0,icanon=0 unix-connect:monitor.sock
(qemu) savevm start
(qemu) quit
$
```

This saves the VM state and then simply terminates qemu.

To resume where you left off:

```
./qemu-arm64.sh start
```

(Note that you need to press RETURN once to see a shell prompt.)

If you make changes to the qemu configuration (like changing memory, cpu type or cpu count) your VM snapshots may not work correctly anymore. Instead you'll boot into whatever state you last shut down at.


## SSH from host to guest

openssh server is running by default and listening to local (host) port 10022.
Connect _from the host_ like this:

```
ssh root@localhost -p10022
```


## Etc

### Creating a new "initial" disk

1. remove any snapshots you might have (or delete `user-data.qcow2` and start clean)
2. boot up and sign in
3. make changes to the system
4. when you are ready, `reboot` and wait for qemu to shut down cleanly
5. `qemu-img convert -O qcow2 -c user-data.qcow2 user-data-init.qcow2`
6. Optional: to test, `rm user-data.qcow2 && ./qemu-arm64.sh`

`user-data-init.qcow2` is now a compact image.


### Creating an image from scratch

Remove the init image and run the script:

```
rm user-data-init.qcow2
./qemu-arm64.sh
```

A new blank disk image is created and an alpine ISO image is used for CD-ROM.

Boot up and log in as root (no password.)

Once signed in, you may need to set the date manually:

```
date -s "2021-04-05 16:03:00"
```

Install `linux-virt` and reboot:

```
apk add linux-virt
reboot
```

Start again and choose "virt" in the boot menu when asked: (be quick to select!)

```
./qemu-arm64.sh
```

When signed in, remove the LTS package which is huge: (no longer needed)

```
apk del linux-lts
```

Next, run `setup-alpine`:

```
setup-alpine
# answer all the questions
# choose /dev/vdc as the disk, choose Y to erase, partition & format it
# choose "sys" when asked what layout you want
```

Note that you have to choose a (strong) password for root.
If you'd like to have no password for root, edit `/etc/shadow` to look like this for root's entry:
`root::12345:0:::::` (the second field, in between `:` and `:` should be empty.)

Now `reboot` and wait for qemu to exit.

Finally you'll want to compact the disk image and save a copy of it for the future:

```
qemu-img convert -O qcow2 -c user-data.qcow2 user-data-init.qcow2
rm user-data.qcow2
```

Done!

To try it, just start; the script will make a copy of `user-data-init.qcow2` at `user-data.qcow2`
for you and use that:

```
./qemu-arm64.sh
```


