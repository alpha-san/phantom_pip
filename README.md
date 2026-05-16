# PhantomPiP

A see-through, always-on-top video window for macOS — so you can watch a
tutorial, stream, or talk *through* your code editor while you work.

Chrome's native Picture-in-Picture window is drawn by the OS compositor and
cannot be made translucent or click-through by any browser extension. So this
is a small native macOS app instead: a borderless, transparent `NSWindow`
hosting a `WKWebView`, which plays **any HTML5 video on any page** (YouTube,
Twitch, docs, recorded talks) as a translucent ghost over VS Code, a terminal,
or anything else.

The window is pure video. On launch it shows a small translucent card with a
**URL box right in the window**, so you can start without hunting for anything.
There's also a Dock icon, a **👻 PiP** item in the menu bar, and global
hot keys — three independent ways in, so you're never locked out.

## Requirements

- macOS 13+
- Swift toolchain (Xcode or Command Line Tools)

No Accessibility or Input Monitoring permission is needed — global hot keys use
Carbon, which works on first launch with zero prompts.

## Run

```sh
swift run
```

Build a release binary if you'd rather launch it directly:

```sh
swift build -c release
.build/release/PhantomPiP
```

## Use

On launch, the window itself shows a **URL box** — paste a link, press Play,
done. After that, change the URL anytime with **⌘⌥⌃U**, the Dock app menu, or
the **👻 PiP** menu-bar item (top-right of the screen), which also has:

- **Set Video URL…** — paste a video page URL; press Play.
- **Play URL from Clipboard** — one click if the link is already copied.
- **Opacity** slider — drag down and your editor shows through the video.
- **Click-through** — mouse clicks pass straight to the editor behind it.
- **Fill Window With Video** — auto-zooms the video to fill the window.
- **Use YouTube Embed Player** — rewrites YouTube links to the bare player.
- **Center / Reset Window** — recover a lost or pass-through window.

Move the window with **⌘-drag anywhere**; resize from the grip in the
bottom-right corner.

### Auto-maximize

By default the video fills the whole window — no page chrome:

- **YouTube** links (`watch`, `youtu.be`, `shorts`, `live`) are rewritten to
  `youtube.com/embed/…?autoplay=1`, which is just the player and autoplays.
- **Any other site**: a script finds the largest `<video>`, lifts it to cover
  the viewport, and hides the rest (retried for ~10s as the player loads).

If a YouTube video has **embedding disabled by its uploader** (Error
150/152/101 — common for Comedy Central / full episodes), the app detects it
automatically via the player's error event and **falls back to the full watch
page**, pinning YouTube's own player to fill the window (its controls stay).
You can also force embed mode on/off yourself with **⌘⌥⌃Y** or the menu.

### Ad blocking

This is **WebKit (Safari engine), not Chrome** — Chrome extensions like uBlock
Origin can't be installed. Ad blocking uses WebKit's native mechanisms instead,
on by default (toggle with **⌘⌥⌃B** or *Block Ads* in the menus):

- **Network blocker** — a `WKContentRuleList` blocks well-known third-party
  ad/tracker hosts and hides common ad containers across all sites. It
  deliberately never touches `googlevideo`/`youtube`/`ytimg`, so video
  playback is never broken.
- **YouTube ad-skipper** — YouTube serves in-stream ads from the same infra as
  the video, so a network blocker can't strip them. On the watch-page
  fallback, injected JS clicks *Skip Ad*, fast-forwards unskippable pre/mid-
  rolls, and hides ad surfaces.

Honest limits: the skipper is best-effort and brittle when YouTube changes its
markup; the embed iframe is cross-origin so JS can't reach inside it (the
content blocker still applies there); this is not as thorough as uBlock Origin.

### Global hot keys

Work from any app, even when the window is transparent or click-through:

| Shortcut    | Action                                                         |
|-------------|----------------------------------------------------------------|
| ⌘⌥⌃U        | Open the Set-URL dialog                                          |
| ⌘⌥⌃Y        | Toggle YouTube embed mode (embed ↔ full watch page)              |
| ⌘⌥⌃B        | Toggle ad blocking                                               |
| ⌘⌥⌃P        | Toggle click-through                                            |
| ⌘⌥⌃↑ / ↓    | Opacity up / down (10%)                                         |
| ⌘⌥⌃C        | Toggle Fill Window With Video                                   |
| ⌘⌥⌃R        | **Panic reset** — opacity 100%, click-through off, recenter, focus |

If you ever lose the window (transparent + click-through), press **⌘⌥⌃R**.

## How the see-through works

The opacity slider sets the **window's** `alphaValue`. `WKWebView` renders its
content out-of-process in a hosted compositing layer that *ignores* the
NSView's `alphaValue`, so fading the web view does nothing. Window alpha is
applied by the window server over the entire window surface — web content
included — so the whole video genuinely composites over your editor, even on
opaque pages like YouTube. Controls live in the menu bar and global hot keys,
which are outside the window, so they stay fully usable at any opacity.

## Notes & limitations

- Some sites block autoplay; click play once with click-through off.
- The window floats above normal windows and over full-screen apps
  (`fullScreenAuxiliary`) and follows you across Spaces.
- Quit with **⌘Q**, the Dock icon, or **Quit PhantomPiP** in either menu.
- The window is borderless (no close button by design); quitting closes it.
