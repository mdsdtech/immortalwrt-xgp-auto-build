#!/bin/bash
id
df -h
free -h
cat /proc/cpuinfo

echo "update submodules"
git submodule update --init --recursive --remote || { echo "submodule update failed"; exit 1; }

if [ -d "immortalwrt" ]; then
    echo "repo dir exists"
    cd immortalwrt
    git pull || { echo "git pull failed"; exit 1; }
    git reset --hard HEAD
    git clean -fd
else
    echo "repo dir not exists"
    git clone -b openwrt-24.10 --single-branch --filter=blob:none "https://github.com/immortalwrt/immortalwrt" || { echo "git clone failed"; exit 1; }
    cd immortalwrt
fi

# reset to 8f6bf3907696dc7de78d1da5e25e0fda223497e8 due to framebuffer compatibility issue
git reset --hard 8f6bf3907696dc7de78d1da5e25e0fda223497e8

echo "add feeds"
cat feeds.conf.default > feeds.conf
echo "" >> feeds.conf
# echo "src-git qmodem https://github.com/FUjr/QModem.git;main" >> feeds.conf
echo "src-git qmodem https://github.com/zzzz0317/QModem.git;v2.8.11" >> feeds.conf
echo "src-git istore https://github.com/linkease/istore;main" >> feeds.conf
echo "src-git passwall2 https://github.com/Openwrt-Passwall/openwrt-passwall2.git;main" >> feeds.conf
echo "src-git atcommands https://github.com/mdsdtech/luci-app-atcommands.git;custom" >> feeds.conf
echo "src-git bypassk https://github.com/siropboy/luci-app-bypass.git;main" >> feeds.conf
echo "update files"
rm -rf files
cp -r ../files .

# WLAN Compatibility Fix
mkdir -p ./files/lib/wifi/
cp package/network/config/wifi-scripts/files/lib/wifi/mac80211.uc ./files/lib/wifi/mac80211.uc
sed -i 's/const bands_order = \[ "6G", "5G", "2G" \];/const bands_order = [ "2G", "5G", "6G" ];/' ./files/lib/wifi/mac80211.uc
echo "diff lib/wifi/mac80211.uc with builder repo:"
diff ../files/lib/wifi/mac80211.uc ./files/lib/wifi/mac80211.uc
echo "diff lib/wifi/mac80211.uc with immortalwrt repo:"
diff package/network/config/wifi-scripts/files/lib/wifi/mac80211.uc ./files/lib/wifi/mac80211.uc

# Add TD-TECH option id patch
echo "add TD-TECH option id patch"
cp ../999-add-TD-TECH-option-id.patch ./target/linux/rockchip/patches-6.6/999-add-TD-TECH-option-id.patch
ls -lah ./target/linux/rockchip/patches-6.6/999-add-TD-TECH-option-id.patch

# =================================================================
# FIXED: Direct Clone for Custom Packages
# =================================================================
echo "Adding Custom Packages..."

# 1. Define destination directories
THEME_DIR="package/custom/luci-theme-alpha-reborn"
APP_DIR="package/custom/luci-app-arwi-dashboard"

# 2. Clean up old versions
rm -rf "$THEME_DIR"
rm -rf "$APP_DIR"

# 3. Create parent directory
mkdir -p "package/custom"

# 4. Clone directly
# Theme
git clone --depth=1 https://github.com/derisamedia/luci-theme-alpha-reborn.git "$THEME_DIR" || { echo "Theme clone failed"; exit 1; }

# Dashboard App
git clone --depth=1 https://github.com/derisamedia/luci-app-arwi-dashboard.git "$APP_DIR" || { echo "Dashboard clone failed"; exit 1; }

echo "Custom packages added successfully."
# =================================================================

echo "update feeds"
./scripts/feeds update -a || { echo "update feeds failed"; exit 1; }
echo "install feeds"
./scripts/feeds install -a || { echo "install feeds failed"; exit 1; }
./scripts/feeds install -a -f -p qmodem || { echo "install qmodem feeds failed"; exit 1; }

if [ -L "package/zz-packages" ]; then
    echo "package/zz-packages is already a symlink"
else
    if [ -d "package/zz-packages" ]; then
        echo "package/zz-packages directory exists, removing it"
        rm -rf package/zz-packages
    fi
    ln -s ../../zz-packages package/zz-packages
    echo "Created symlink package/zz-packages -> ../../zz-packages"
fi

echo "Fix Rust build remove CI LLVM download"
if [ -f "feeds/packages/lang/rust/Makefile" ]; then
    sed -i 's/download-ci-llvm=true/download-ci-llvm=false/g' "feeds/packages/lang/rust/Makefile"
fi
