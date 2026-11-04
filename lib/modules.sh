# Each module has mod_<id>_install, mod_<id>_remove and mod_<id>_status (on, off or unavailable).
# The launcher is a choice: mod_launcher_status prints it and mod_launcher_set <choice> applies it.

# apply order: installs run in this order, removes in reverse
MODULES=(theme wallpaper dock blur corners hidetopbar coverflow wobbly launcher switch gtk4 ghostty gdm plymouth nvidia)
LAUNCHER_CHOICES=(searchlight ulauncher none)
# modules that read the variant or the images, reinstalled when those change
VARIANT_MODULES=(theme wallpaper ghostty gdm plymouth)
# a remove that stops before changing anything returns this, so the engine doesn't roll it back
REFUSED=3
