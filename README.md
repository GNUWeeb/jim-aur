# Jim AUR Repository Scripts

Scripts for adding Jim AUR Repositories into your Arch systems [(hosted on openSUSE Build Service)](https://build.opensuse.org/project/show/home:jimedrand).

## Why use `curl`?
We recommend using `curl` rather than `wget` because:
1. **Pre-installed**: `curl` is standard on Arch Linux, meaning you do not need to install extra utilities like `wget`.
2. **Internal Dependency**: The setup scripts themselves rely internally on `curl` to fetch repository GPG keys.

### Installation

### 1. Primary Jim AUR Repository
Adds the `home_jimedrand_Arch` repository:
```bash
curl -fsSL https://raw.githubusercontent.com/GNUWeeb/jim-aur/refs/heads/master/jim-aur.sh | sudo bash
```

### 2. Secondary Jim AUR Repository
Adds the `home_jimed-rand_archlinux_Arch` repository:
```bash
curl -fsSL https://raw.githubusercontent.com/GNUWeeb/jim-aur/refs/heads/master/jim-aur-second.sh | sudo bash
```
