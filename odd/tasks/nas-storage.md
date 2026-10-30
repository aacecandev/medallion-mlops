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
- [ ] T2 ZFS event mail (`zed`) and scrub schedule.
- [ ] T3 SMART alerts with `smartd` (mail on failures, periodic self-tests).
- [ ] T4 NFS export on nas + Proxmox storage on beelink.
- [ ] T5 Proxmox backup jobs (vzdump) to the NAS storage, with retention.

## Progress

- Old pool inspected read-only (`zpool import -o readonly=on -N`), then exported unchanged.

## Next step

T2 (zed mail, scrub), then T3 (smartd).
