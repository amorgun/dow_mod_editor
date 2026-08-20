-- Screen editor configuration.

-- Screen aspect ratio used in fixed-ratio mode when the .screen data
-- declares no ScreenInfo.AspectRatio of its own.
aspect_ratio = 4 / 3

-- Simulated viewport pixel height: fonts and pixel sizes are authored for
-- this height; the canvas renders at it and is scaled to fit.
viewport_height = 768

-- Default grid step in virtual pixels for the Snap option of the drag/resize
-- gizmo and guide dragging; the step stays adjustable in the editor UI.
snap_step = 8

-- Half-width in virtual pixels of the drag area around a guide line.
guide_grab_margin = 4

-- Display shapes offered by the editor's View selector, in order;
-- the first entry is the default. "Responsive" is always appended last.
preview_ratios = {
	{ name = "4:3", value = 4 / 3 },
	{ name = "16:9", value = 16 / 9 },
	{ name = "16:10", value = 16 / 10 },
}
