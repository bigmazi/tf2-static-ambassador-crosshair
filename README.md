Disables the feature that resizes the crosshair of the Ambassador after making a shot.

Clients can manifest their preferences via a command that mimic a client-side cvar (`"cl_static_ambassador_crosshair"`).

```
"cl_static_ambassador_crosshair"
 - Command that mimics a client-side cvar. "0" = dynamic Ambassador crosshair, "1" = static Ambassador crosshair, "" = follow server's suggestion (i.e. "sm_static_ambassador_crosshair_by_default")
"sm_static_ambassador_crosshair_plugin_enabled" = "1" min. 0.000000 max. 1.000000
 - If enabled, the "static-ambassador-crosshair" plugin has effect
"sm_static_ambassador_crosshair_by_default" = "1" min. 0.000000 max. 1.000000
 - Whether clients who have not executed "cl_static_ambassador_crosshair" should have the Ambassador crosshair static (1) or dynamic (0)
```

*Requires TF2Attributes (https://github.com/FlaminSarge/tf2attributes).*
