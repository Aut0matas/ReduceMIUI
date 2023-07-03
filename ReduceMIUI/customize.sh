#!/bin/bash
SKIPUNZIP=0

# 禁用miui日志，如果您需要抓取log，请不要开启！
is_clean_logs=true
# 禁用非必要调试服务！
is_reduce_test_services=true
# 使用hosts屏蔽小米某些ad域名
# 注意：使用该功能会导致主题商店在线加载图片出现问题
is_use_hosts=false
# 默认dex2oat优化编译模式
dex2oat_mode="everything"

if [[ $KSU == true ]]; then
  ui_print "- KernelSU 用户空间当前的版本号: $KSU_VER_CODE"
  ui_print "- KernelSU 内核空间当前的版本号: $KSU_KERNEL_VER_CODE"
else
  ui_print "- Magisk 版本: $MAGISK_VER_CODE"
  if [ "$MAGISK_VER_CODE" -lt 26000 ]; then
    ui_print "*********************************************"
    ui_print "! 请安装 Magisk 26.0+"
    abort "*********************************************"
  fi
fi

rm -rf /data/system/package_cache

# 获取已安装应用信息
echo "$(pm list packages -f -a)" >$MODPATH/packages.log
sed -i -e 's/\ /\\\n/g' -e 's/\\//g' -e 's/package://g' $MODPATH/packages.log

# ReduceMIUI自定义配置文件目录
mkdir -p /storage/emulated/0/Android/ReduceMIUI
[ ! -f /storage/emulated/0/Android/ReduceMIUI/包名精简.prop ] && cp ${MODPATH}/包名精简.prop /storage/emulated/0/Android/ReduceMIUI
[ ! -f /storage/emulated/0/Android/ReduceMIUI/dex2oat.prop ] && cp ${MODPATH}/dex2oat.prop /storage/emulated/0/Android/ReduceMIUI
Package_Name_Reduction="$(cat /storage/emulated/0/Android/ReduceMIUI/包名精简.prop | grep -v '#')"
dex2oat_list="$(cat /storage/emulated/0/Android/ReduceMIUI/dex2oat.prop | grep -v '#')"
if [[ ! -f /storage/emulated/0/Android/ReduceMIUI/history.prop ]]; then
  touch /storage/emulated/0/Android/ReduceMIUI/history.prop
else
  sort -u /storage/emulated/0/Android/ReduceMIUI/history.prop >/storage/emulated/0/Android/ReduceMIUI/history_new.prop
  rm -rf /storage/emulated/0/Android/ReduceMIUI/history.prop
  mv /storage/emulated/0/Android/ReduceMIUI/history_new.prop /storage/emulated/0/Android/ReduceMIUI/history.prop
  history_list="$(cat /storage/emulated/0/Android/ReduceMIUI/history.prop)"
fi

if [[ $KSU == true ]]; then
  touch_replace() {
    if [[ "$1" != system ]]; then
      if [[ "$1" == odm ]]; then
        mkdir -p "$MODPATH"/system/vendor"$2"
        rm -rf "$MODPATH"/system/vendor"$2"
        mknod "$MODPATH"/system/vendor"$2" c 0 0
      else
        mkdir -p "$MODPATH"/system"$2"
        rm -rf "$MODPATH"/system"$2"
        mknod "$MODPATH"/system"$2" c 0 0
      fi
    else
      mkdir -p "$MODPATH""$2"
      rm -rf "$MODPATH""$2"
      mknod "$MODPATH""$2" c 0 0
    fi
    echo "$2" >>/storage/emulated/0/Android/ReduceMIUI/history.prop
  }
else
  touch_replace() {
    if [[ "$1" != system ]]; then
      if [[ "$1" == odm ]]; then
        mkdir -p "$MODPATH"/system/vendor"$2"
        touch "$MODPATH"/system/vendor"$2"/.replace
        chown root:root "$MODPATH"/system/vendor"$2"/.replace
        chmod 0644 "$MODPATH"/system/vendor"$2"/.replace
      else
        mkdir -p "$MODPATH"/system"$2"
        touch "$MODPATH"/system"$2"/.replace
        chown root:root "$MODPATH"/system"$2"/.replace
        chmod 0644 "$MODPATH"/system"$2"/.replace
      fi
    else
      mkdir -p "$MODPATH""$2"
      touch "$MODPATH""$2"/.replace
      chown root:root "$MODPATH""$2"/.replace
      chmod 0644 "$MODPATH""$2"/.replace
    fi
    echo "$2" >>/storage/emulated/0/Android/ReduceMIUI/history.prop

  }
fi

reduce_test_services() {
  if [ "$is_reduce_test_services" == "true" ]; then
    if [ "$API" -le 30 ]; then
      ui_print "- 正在停止ipacm-diag"
      stop ipacm-diag
      echo "stop ipacm-diag" >>$MODPATH/service.sh
    fi
    if [ "$API" -ge 31 ]; then
      ui_print "- 正在停止ipacm-diag"
      stop vendor.ipacm-diag
      echo "stop vendor.ipacm-diag" >>$MODPATH/service.sh
    fi
  fi
  if [ "$is_clean_logs" == "true" ]; then
    if [ "$API" -le 30 ]; then
      ui_print "- 正在停止tcpdump"
      stop tcpdump
      echo "stop tcpdump" >>$MODPATH/service.sh
      ui_print "- 正在停止cnss_diag"
      stop cnss_diag
      echo "stop cnss_diag" >>$MODPATH/service.sh
    elif [ "$API" -ge 31 ]; then
      ui_print "- 正在停止tcpdump"
      stop vendor.tcpdump
      echo "stop vendor.tcpdump" >>$MODPATH/service.sh
      ui_print "- 正在停止cnss_diag"
      stop vendor.cnss_diag
      echo "stop vendor.cnss_diag" >>$MODPATH/service.sh
      ui_print "- 正在停止logd"
      stop logd
      echo "stop logd" >>$MODPATH/service.sh
    fi
    ui_print "- 正在清除MIUI WiFi log"
    rm -rf /data/vendor/wlan_logs/*
    echo "rm -rf /data/vendor/wlan_logs/*" >>$MODPATH/service.sh
    ui_print "- 正在清除MIUI 充电 log"
    rm -rf /data/vendor/charge_logger/*
    echo "rm -rf /data/vendor/charge_logger/*" >>$MODPATH/service.sh
  fi
}

uninstall_useless_app() {
  ui_print "- 正在禁用智能服务"
  if [ "$(pm list package | grep 'com.miui.systemAdSolution')" != "" ]; then
    pm disable com.miui.systemAdSolution >/dev/null
    echo "pm disable com.miui.systemAdSolution" >>$MODPATH/service.sh
    ui_print "- 成功禁用智能服务"
  else
    ui_print "- 智能服务不存在或已被精简"
  fi
  ui_print "- 正在移除Analytics"
  if [ "$(pm list package | grep 'com.miui.analytics')" != "" ]; then
    rm -rf /data/user/0/com.xiaomi.market/app_analytics/*
    chown -R root:root /data/user/0/com.xiaomi.market/app_analytics/
    chmod -R 000 /data/user/0/com.xiaomi.market/app_analytics/
    pm uninstall --user 0 com.miui.analytics >/dev/null
    echo "pm uninstall --user 0 com.miui.analytics >/dev/null" >>$MODPATH/service.sh
    if [ -d "/data/user/999/com.xiaomi.market/app_analytics/" ]; then
      rm -rf /data/user/999/com.xiaomi.market/app_analytics/*
      chown -R root:root /data/user/999/com.xiaomi.market/app_analytics/
      chmod -R 000 /data/user/999/com.xiaomi.market/app_analytics/
      pm uninstall --user 999 com.miui.analytics >/dev/null
    fi
    ui_print "- Analytics移除成功"
  else
    ui_print "- Analytics不存在"
  fi
}

dex2oat_app() {
  ui_print "- 为保障流畅，执行dex2oat ($dex2oat_mode)优化，需要一点时间..."
  for app_list in ${dex2oat_list}; do
    var=$app_list
    record="$(eval cat $MODPATH/packages.log | grep "$var"$)"
    apk_path="${record%=*}"
    apk_dir="${apk_path%/*}"
    apk_name="${apk_path##*/}"
    apk_name="${apk_name%.*}"
    apk_source="$(echo $apk_dir | cut -d"/" -f2)"
    if [[ "$(unzip -l $apk_path | grep lib/)" == "" ]] || [[ "$(unzip -l $apk_path | grep lib/arm64)" != "" ]]; then
      apk_abi=arm64
    else
      apk_abi=arm
    fi
    if [ -n "$apk_source" ]; then
      if [[ "$apk_source" == "data" ]]; then
        if [ "$(unzip -l $apk_path | grep classes.dex)" != "" ]; then
          rm -rf "$apk_dir"/oat/$apk_abi/*
          dex2oat --dex-file="$apk_path" --compiler-filter=$dex2oat_mode --instruction-set=$apk_abi --oat-file="$apk_dir"/oat/$apk_abi/base.odex
          ui_print "- ${app_list}: 成功"
        fi
      else
        if [ "$(unzip -l $apk_path | grep classes.dex)" != "" ]; then
          if [[ "$apk_source" != system ]]; then
            if [[ "$apk_source" == odm ]]; then
              target_path=$MODPATH/system/vendor$apk_dir/oat/$apk_abi
            else
              target_path=$MODPATH/system$apk_dir/oat/$apk_abi
            fi
          else
            target_path="$MODPATH""$apk_dir"/oat/$apk_abi
          fi
          mkdir -p "$target_path"
          dex2oat --dex-file="$apk_path" --compiler-filter=$dex2oat_mode --instruction-set=$apk_abi --oat-file="$target_path"/"$apk_name".odex
          ui_print "- ${app_list}: 成功"
        fi
      fi
    else
      ui_print "- ${app_list}: 不存在"
    fi
  done
  ui_print "- 优化完成"
}

package_replace() {
  for app_list in ${Package_Name_Reduction}; do
    var=$app_list
    record="$(eval cat $MODPATH/packages.log | grep "$var"$)"
    apk_path="${record%=*}"
    apk_dir="${apk_path%/*}"
    apk_source="$(echo $apk_dir | cut -d"/" -f2)"
    if [ -n "$apk_source" ]; then
      if [[ "$apk_source" == "data" ]]; then
        ui_print "- ${app_list}为手动安装的应用或已被精简"
      else
        ui_print "- 正在精简${app_list}"
        touch_replace "$apk_source" "$apk_dir"
      fi
    fi
  done
  for history in ${history_list}; do
    if [ -n "$history" ]; then
      history_source="$(echo $history | cut -d"/" -f2)"
      ui_print "- 正在精简${history##*/}"
      touch_replace "$history_source" "$history"
    fi
  done
}

hosts_file() {
  # hosts文件判断
  if [[ $is_use_hosts == true ]]; then
    find_hosts="$(find /data/adb/modules*/*/system/etc -name 'hosts')"
    if [ "$(echo "$find_hosts" | grep -v "Reducemiui")" != "" ]; then
      echo "$find_hosts" | grep "Reducemiui" | xargs rm -rf
      find_hosts="$(find /data/adb/modules*/*/system/etc -name 'hosts')"
      have_an_effect_hosts="$(echo $find_hosts | awk '{print $NF}')"
      if [ "$(cat "${have_an_effect_hosts}" | grep '# Start Reducemiui hosts')" == "" ]; then
        cat "${MODPATH}/hosts.txt" >>${have_an_effect_hosts}
      fi
    else
      mkdir -p ${MODPATH}/system/etc/
      find_hosts="$(find /data/adb/modules*/Reducemiui/system/etc -name 'hosts')"
      if [ ! -f "${find_hosts}" ]; then
        cp -r /system/etc/hosts ${MODPATH}/system/etc/
        cat ${MODPATH}/hosts.txt >>${MODPATH}/system/etc/hosts
      else
        cp -r ${find_hosts} ${MODPATH}/system/etc/
      fi
    fi
  else
    ui_print "- hosts文件未启用"
  fi
}

remove_files() {
  rm -rf $MODPATH/hosts.txt
  rm -rf $MODPATH/包名精简.prop
  rm -rf $MODPATH/dex2oat.prop
  rm -rf $MODPATH/packages.log
}

reduce_test_services
uninstall_useless_app
dex2oat_app
package_replace
hosts_file
remove_files
