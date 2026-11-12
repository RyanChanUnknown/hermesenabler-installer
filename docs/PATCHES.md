# Patches applied to isideload

Vendored at `vendor/isideload/`, based on `isideload 0.3.17`
(<https://github.com/nab138/isideload>), as shipped inside iloader's Watch
community branch.

Two behavioural changes, both required for HermesEnabler to work on a free
Apple ID.

---

## 1. `anisette/remote_v3/mod.rs` — client_info from the server

**Problem.** `get_client_info()` returned a hardcoded macOS string:

```rust
async fn get_client_info(&self) -> Result<AnisetteClientInfo, Report> {
    Ok(AnisetteClientInfo {
        client_info:
            "<Mac15,7> <macOS;27.0;26A5378j> <com.apple.AuthKit/1 (com.apple.akd/1.0)>"
                .to_string(),
        user_agent: "akd/1.0 CFNetwork/808.1.4".to_string(),
    })
}
```

Apple started rejecting anisette data whose `client_info` does not match the
machine that minted it (2026-10-12). Login then fails before any request is
signed.

**Fix.** Fetch `/v3/client_info` from the configured anisette server and fall
back to the hardcoded value only if that request fails:

```rust
let path = format!("{}/v3/client_info", url.path().trim_end_matches('/'));
url.set_path(&path);
match self.client.get(url).send().await {
    Ok(r) if r.status().is_success() => match r.json::<AnisetteClientInfo>().await {
        Ok(ci) => return Ok(ci),
        Err(e) => warn!("anisette /v3/client_info decode failed: {e}"),
    },
    ...
}
```

---

## 2. `sideload/sideloader.rs` — App Group for the Watch app

**Problem.** The App Group association loop skipped the Watch app entirely:

```rust
for app_id in app_ids.iter_mut() {
    if watch_bundle_ids.contains(&app_id.identifier) {
        continue;                                   // ← watch app never gets a group
    }
    app_id.ensure_group_feature(&mut self.dev_session, &team).await?;
    self.dev_session
        .assign_app_group(&team, &app_group, app_id, None)
        .await?;
```

Consequence, verified against a real profile dump:

```
main app  : group.com.example.HermesEnabler...   ← present
watch app : None                                  ← missing
```

The Watch app then starts and immediately reports
`MobileGestalt 访问失败 / App Group ID 可能丢失`, because `BQGroupRoot()`
returns nil and every MobileGestalt read/write path depends on it.

**Fix.** Drop the `continue` and pass the device type:

```rust
let device_type = if watch_bundle_ids.contains(&app_id.identifier) {
    Some(DeveloperDeviceType::Watchos)
} else {
    None
};
app_id.ensure_group_feature(&mut self.dev_session, &team).await?;
self.dev_session.assign_app_group(&team, &app_group, app_id, device_type).await?;
```

`assign_app_group` already accepted `impl Into<Option<DeveloperDeviceType>>`;
the upstream code simply passed `None`.

After the patch the Watch profile contains:

```
AppGroups : ['group.com.example.HermesEnabler.2VFT29JNQ4.2VFT29JNQ4']
Devices   : ['00008150-00154C290CD8C01C', '00008310-000A4A103A88E01E']
```

---

## 3. `Cargo.toml` — pinned apple-codesign revision

Upstream points at a branch whose HEAD no longer resolves:

```
error: no matching package named `apple-codesign` found
location searched: Git repository https://github.com/nab138/apple-crates
```

Pinned to the revision iloader's own lockfile uses:

```toml
apple-codesign = { git = "https://github.com/nab138/apple-crates",
                   rev = "5da0b8df9b202434b1eff2700059b1ee142592ac",
                   version = "0.1.0", package = "apple-codesign" }
```

---

## Additional runtime handling in the CLI (not upstream changes)

- `MaxCertsBehavior::Revoke` — a free account may hold one development
  certificate; hitting `7460` revokes the old one instead of aborting.
- Paired-watch registration — the phone does not always expose the legacy
  companion proxy, so the Watch UDID is registered through the developer API
  directly (`ensure_device_registered` with `DeveloperDeviceType::Watchos`).
- Watch install — `install_watch_apps` (legacy lockdown forward) fails on such
  phones; the CLI falls back to `xcrun devicectl device install app`, which is
  the same CoreDevice path Xcode uses.
