#!/bin/bash
# Usa la toolchain della ROM (NO toolchain Motorola)
CLANG_BIN=$HOME/BACKUP-FOLDER/kernel_workspace/clang-r547379/bin


if [ ! -d "$CLANG_BIN" ]; then
  echo "ERROR: clang bin not found: $CLANG_BIN"
  exit 1
fi

export PATH=$CLANG_BIN:$PATH
export PATH=$PWD/scripts:$PATH # chmod +x scripts/mkdtimg or create a wrapper first 
#cat > scripts/mkdtimg << 'EOF'
#!/bin/sh
#exec python3 $(dirname "$0")/mkdtboimg.py "$@"
#EOF
export LLVM_DIR=$CLANG_BIN


SECONDS=0
export KBUILD_BUILD_USER=yama
export LLVM=1
export AnyKernel3=AnyKernel3
export TIME="$(date "+%Y%m%d")"
export modpath=${AnyKernel3}/modules/vendor/lib/modules
export ARCH=arm64





# ===============================
# AnyKernel pre-clean (auto)
# ===============================

ANYKERNEL_DIR="AnyKernel3"

if [ -d "$ANYKERNEL_DIR" ]; then
  echo "[*] Cleaning AnyKernel directory..."

  # Remove directories
  rm -rf "$ANYKERNEL_DIR/modules"
  rm -rf "$ANYKERNEL_DIR/config"

  # Remove kernel artifacts
  rm -f "$ANYKERNEL_DIR/dtb"
  rm -f "$ANYKERNEL_DIR/dtbo.img"
  rm -f "$ANYKERNEL_DIR/Image.gz"

  # Remove old KernelSU zip (date-independent)
  rm -f "$ANYKERNEL_DIR"/KernelSU_*.zip

  echo "[*] AnyKernel cleaned"
else
  echo "[!] AnyKernel directory not found, skipping cleanup"
fi

# ===============================
# Build environment
# ===============================

ARGS='
CC=clang
LD='${LLVM_DIR}/ld.lld'
ARCH=arm64
AR='${LLVM_DIR}/llvm-ar'
NM='${LLVM_DIR}/llvm-nm'
AS='${LLVM_DIR}/llvm-as'
CROSS_COMPILE='${LLVM_DIR}/aarch64-linux-gnu'
CROSS_COMPILE_COMPAT='${LLVM_DIR}/arm-linux-gnueabi'
OBJCOPY='${LLVM_DIR}/llvm-objcopy'
OBJDUMP='${LLVM_DIR}/llvm-objdump'
READELF='${LLVM_DIR}/llvm-readelf'
OBJSIZE='${LLVM_DIR}/llvm-size'
STRIP='${LLVM_DIR}/llvm-strip'
LLVM_AR='${LLVM_DIR}/llvm-ar'
LLVM_DIS='${LLVM_DIR}/llvm-dis'
LLVM_NM='${LLVM_DIR}/llvm-nm'
LLVM=1
LLVM_IAS=1
'
rm -rf out
make ${ARGS} O=out bangkk_defconfig
#make O=out menuconfig
make ${ARGS} O=out -j$(nproc)

[ ! -e "out/arch/arm64/boot/Image.gz" ] && \
echo "  ERROR : image binary not found in any of the specified locations , fix compile!" && \
exit 1

make O=out ${ARGS} -j$(nproc) INSTALL_MOD_PATH=modules INSTALL_MOD_STRIP=1 modules_install

#Clean Up
rm -rf ${modpath}/*
rm -rf ${AnyKernel3}/{Image, dtb, dtbo.img}
rm -rf ${AnyKernel3}/*.zip

#Setup
mkdir -p ${modpath}
kver=$(make kernelversion)
kmod=$(echo ${kver} | awk -F'.' '{print $3}')

#Copy stuff
cp out/.config ${AnyKernel3}/config
cp out/arch/arm64/boot/Image.gz ${AnyKernel3}/Image.gz
cp out/arch/arm64/boot/dtb.img ${AnyKernel3}/dtb
cp out/arch/arm64/boot/dtbo.img ${AnyKernel3}/dtbo.img
#cp build.sta/${DEVICE}_modules.blocklist ${modpath}/modules.blocklist
cp $(find out/modules/lib/modules/5.4* -name '*.ko') ${modpath}/
cp out/modules/lib/modules/5.4*/modules.{alias,dep,softdep} ${modpath}/
cp out/modules/lib/modules/5.4*/modules.order ${modpath}/modules.load

#Edit
sed -i 's/\(kernel\/[^: ]*\/\)\([^: ]*\.ko\)/\/vendor\/lib\/modules\/\2/g' ${modpath}/modules.dep
#sed -i 's/.*\//.ko/g' ${AnyKernel3}/modules/vendor/lib/modules/modules.load
#sed -i 's#.*/##; s/\.ko$//' ${AnyKernel3}/modules/vendor/lib/modules/modules.load
sed -i 's/.*\///; s/\.ko$//' ${modpath}/modules.load

#source build.sta/${DEVICE}_mdconf
#for useles_modules in "${modules_to_nuke[@]}"; do
#  grep -vE "$useles_modules" ${modpath}/modules.load > /tmp/templd && mv /tmp/templd ${modpath}/modules.load
#done

#Zip
cd ${AnyKernel3}
zip -r9 KernelSU_${DEVICE}${KSUSTAT}-${TIME}.zip * -x .git README.md *placeholder
echo -e "\nCompleted in $((SECONDS / 60))m $((SECONDS % 60))s"
