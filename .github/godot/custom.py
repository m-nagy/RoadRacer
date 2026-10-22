# Build options for the Windows export template used by the release build (see .github/workflows/build.yml).
# A 2D-only, size-optimised, symbol-free release template: it contains only the parts of the engine this game
# uses, which is why the exe is a fraction of the size of the stock template.
# The "smoke test" job runs the exported exe, so a module that is needed but switched off here fails the build.
# If the game starts using something that is missing (a node type, an audio or image format), enable its module.
target = "template_release"
debug_symbols = "no"
optimize = "size"
lto = "full"

disable_3d = "yes"
disable_navigation_2d = "yes"
disable_navigation_3d = "yes"
disable_xr = "yes"

deprecated = "no"
vulkan = "no"
use_volk = "no"
d3d12 = "no"
openxr = "no"
minizip = "no"
graphite = "no"
accesskit = "no"

# Everything off except what the game needs:
modules_enabled_by_default = "no"
module_gdscript_enabled = "yes"
module_godot_physics_2d_enabled = "yes"
module_text_server_fb_enabled = "yes"   # the plain text server is enough for Latin text
module_freetype_enabled = "yes"         # draws the font
module_svg_enabled = "yes"              # the default theme's icons
module_webp_enabled = "yes"             # lossless textures are stored as WebP
module_ogg_enabled = "yes"
module_vorbis_enabled = "yes"           # music and impact sounds (.ogg)
module_minimp3_enabled = "yes"          # siren sounds (.mp3)
