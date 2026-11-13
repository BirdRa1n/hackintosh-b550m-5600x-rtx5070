// Prints the current display mode and the public CoreGraphics mode list.
// Run: osascript -l JavaScript list-modes.js
// Note: the public API does not list HiDPI modes from a display override; check the current mode.
ObjC.import('CoreGraphics'); ObjC.import('Foundation');
const d = $.CGMainDisplayID(), cur = $.CGDisplayCopyDisplayMode(d);
const f = m => $.CGDisplayModeGetWidth(m)+"x"+$.CGDisplayModeGetHeight(m)+" px "+$.CGDisplayModeGetPixelWidth(m)+"x"+$.CGDisplayModeGetPixelHeight(m);
let out = ["Current: "+f(cur)+" @"+Math.round($.CGDisplayModeGetRefreshRate(cur))+"Hz"];
const opts = $.NSDictionary.dictionaryWithObjectForKey($.NSNumber.numberWithBool(true), $('kCGDisplayShowDuplicateLowResolutionModes'));
const arr = ObjC.castRefToObject($.CGDisplayCopyAllDisplayModes(d, opts)); const seen = {};
for (let i = 0; i < arr.count; i++) { const m = arr.objectAtIndex(i);
  const k = f(m)+($.CGDisplayModeGetPixelWidth(m) > $.CGDisplayModeGetWidth(m) ? " HiDPI" : "");
  seen[k] = (seen[k]||[]); const hz = Math.round($.CGDisplayModeGetRefreshRate(m)); if (!seen[k].includes(hz)) seen[k].push(hz); }
for (const k in seen) out.push(k+"  ["+seen[k].sort((a,b)=>b-a).join(",")+" Hz]");
out.join("\n");
