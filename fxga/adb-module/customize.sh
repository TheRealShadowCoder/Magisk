#!/system/bin/sh
SKIPMOUNT=true
PROPFILE=false
POSTFSDATA=false
LATESTARTSERVICE=true
ui_print "- FXGA Android 17 root-authorized ADB diagnostics"
ui_print "- No ADB authorization bypass, network listener, or automatic uploads"
set_perm_recursive "$MODPATH" 0 0 0755 0644
set_perm "$MODPATH/service.sh" 0 0 0755
set_perm "$MODPATH/action.sh" 0 0 0755
set_perm "$MODPATH/fxga_diag.sh" 0 0 0755
set_perm "$MODPATH/fxga_log_service.sh" 0 0 0755
