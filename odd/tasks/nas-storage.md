# Feature: nas-storage

## Objective

Give the homelab real storage on the NAS, managed by Ansible: a ZFS pool on the
4 HDDs, alerts for pool and disk health, an NFS share for beelink, and Proxmox
backup jobs that write there. Prerequisite for backups (the reference clone's
`27_backup_automation` only writes to the same host and is replaced by this).

## Decisions

- Pool `datapool`: RAIDZ1 over the 4x 3.6 TB HDDs (user decision; ~10.9 TB usable, tolerates 1 disk).
- Recreated by Ansible (user decision), wiping the previous `datapool` (~40 GB: `minio`, `nas`,
  `subvol-104-disk-0`, no snapshots; user confirmed deletion).
- Disks referenced by `/dev/disk/by-id`. `zpool create -f` only with an explicit `-e zfs_pool_force=true`.
- Known risk: `WDC WD40EFAX` is SMR; resilvers are slow. Watch SMART, replace with CMR when due.

## Constraints

- Everything through Ansible roles in `ansible/`; per-host values in `host_vars/nas/main.yml`.
- No personal data in plaintext (public repo); secrets in sops.
- TDD: off. Checks: `ansible-lint`, `--check`, real run, rerun `changed=0`, observed pool state.

## Delivery

Strategy: `ask-on-risk`. Branch `feat/nas-storage` from `origin/main`.

## Tasks

- [x] T1 `10_zfs_storage`: `community.general.zpool` creates missing pools only (on an existing pool the
      module misreads by-id disks and attempts `zpool add` of the same disks, so creation is gated on
      `zpool list`); `-f` only with `-e zfs_pool_force=true`. `datapool` RAIDZ1 by-id, ashift 12, lz4,
      atime off, xattr sa, posixacl, dnodesize auto; datasets `backups` (recordsize 1M) and `data`;
      ARC max 3 GiB in `/etc/modprobe.d/zfs.conf` (+ initramfs) and live. beelink: empty vars, all
      changing tasks skipped. Proof: guard refused without force (old labels); forced run created the
      pool; `zpool status` ONLINE, 10.4T avail, properties inherited, ARC 3221225472, zfs.conf in initramfs,
      full playbook rerun `changed=0` on both. Known: `community.general.zfs` reports `changed` in
      `--check` for `datapool/backups` while real runs report none. Route: inline.
- [x] T2 ZFS event mail and scrubs (both hosts, in `10_zfs_storage`): zed already mailed `root` (aliased by
      `22_mail`) on faults; set `ZED_NOTIFY_VERBOSE=1` so finished scrubs are reported too. Scrubs stay on
      Debian's `/etc/cron.d/zfsutils-linux` (2nd Sunday, all pools); `zfs-scrub-*` timers left disabled to
      avoid double scrubs. Proof: rerun `changed=0`; manual scrub of `datapool` and `rpool` (0 errors) ->
      zed `scrub_finish` -> Postfix `status=sent (250` via smtp.gmail.com on both. Route: inline.
- [x] T3 `29_smartd` (both hosts; user-approved schedule): `/etc/smartd.conf` DEVICESCAN `-a -n standby,q`,
      self-tests short every Sunday 03:00 and long on day 1 04:00, `-W 4,45,55`, mail via Debian's
      `smartd-runner` to root; template validated with `smartd -q showtests`. Before: already mailed on SMART
      failures but scheduled no self-tests and watched no temperature. Proof: monitors beelink 2 NVMe, nas
      4 SATA + 1 NVMe; `showtests` lists S and L tests per device; one-off `-M test` mail per host
      `status=sent (250`; rerun `changed=0`. Route: inline.
- [x] T4 `26_nfs_storage` (user-approved design): nas exports only `/datapool/backups` to 192.168.1.200
      (`rw,sync,no_subtree_check,no_root_squash`, root needed by vzdump) from `/etc/exports.d/ansible.exports`
      (dir created by the role; the package does not), `exportfs -ra` on change, flushed before client tasks;
      beelink adds Proxmox storage `nas-backups` (NFS 4.2, content `backup` only) when missing. Proof:
      `exportfs -v` shows one client; beelink `pvesm status` active 10.4T, `findmnt` nfs4 from the NAS, root
      write test owned by root; rerun `changed=0`. Note: first run failed on the missing exports dir and
      `pvesm add` then failed (nothing added). Route: inline.
- [ ] T5 Proxmox backup jobs (vzdump) to the NAS storage, with retention (beelink guests only; small).
- [x] T6 Workstation backup (user decision: rsync + ZFS snapshots, not vzdump/PBS; data 7.4 TB on NTFS,
      rarely changing): inventory groups `proxmox`, `workstations` (asuspc, local connection),
      `pc_backup_target` (nas); `proxmox.yml` now targets `proxmox` only. `pc-backup.yml` + `40_pc_backup`:
      dedicated ed25519 key on the PC; NAS user `pc-backup` owns `datapool/data/pc` (recordsize 1M), key
      restricted to `rrsync -wo` (write-only, no shell); sanoid daily 7 / weekly 4 / monthly 6; systemd user
      service + timer 01:30 (`Persistent`, `ConditionPathIsMountPoint` so an unmounted disk never syncs an
      empty tree with `--delete`), `rsync -rt --delete` (NTFS: no POSIX owners), NAS host key pinned from
      `ansible/known_hosts`, linger for logged-out runs. Run by the user (auto-mode classifier blocks
      persistence on the workstation); first run failed on missing `/etc/sanoid` (`00c91f7` creates it).
      Proof: timer enabled/active, next 01:30, linger yes; key 0600; NAS `authorized_keys` has
      `restrict,command="/usr/bin/rrsync -wo ..."`, dataset `pc-backup:pc-backup 750`, sanoid.conf
      7/4/6, sanoid.timer active. Restriction tests with the key: `id` -> "rrsync error: SSH_ORIGINAL_COMMAND
      does not run rsync"; PTY refused; reading from the NAS and writing outside the dir fail; dry-run
      write OK. Pending: first full sync (~7.4 TB, ~20 h at 1 Gbit/s), then first sanoid snapshot.

## Progress

- Old pool inspected read-only (`zpool import -o readonly=on -N`), then exported unchanged.

## Next step

T5 (vzdump backup job to `nas-backups` with retention).
