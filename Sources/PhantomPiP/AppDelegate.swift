import AppKit
import WebKit

final class AppDelegate: NSObject, NSApplicationDelegate, WKNavigationDelegate, WKScriptMessageHandler, NSMenuDelegate {

    private var window: OverlayWindow!
    private var webView: WKWebView!
    private var statusItem: NSStatusItem!

    private let userContent = WKUserContentController()

    private let historyStore = HistoryStore()
    private let historyStatusMenu = NSMenu()
    private let historyAppMenu = NSMenu()
    private var titleObservation: NSKeyValueObservation?

    private var clickThroughItem: NSMenuItem!
    private var fillWindowItem: NSMenuItem!
    private var youTubeEmbedItem: NSMenuItem!
    private var adblockItem: NSMenuItem!
    private var opacitySlider: NSSlider!

    private var dragMonitor: Any?

    private let minOpacity: Double = 0.08
    private var fillWindow = true
    private var useYouTubeEmbed = true
    private var lastInput = ""
    private var loadedYouTubeWrapper = false
    private var adblockEnabled = true
    private var adblockRuleList: WKContentRuleList?
    private var adblockListAdded = false
    private var loadedYouTubeID: String?
    private var youTubeFellBack = false

    // MARK: - Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.applicationIconImage = AppIcon.make()
        buildAppMenu()
        buildWindow()
        buildWebView()
        buildStatusMenu()
        registerHotKeys()
        installDragMonitor()
        compileAdblock()

        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        return true
    }

    // MARK: - App menu

    /// A non-bundled `.regular` app has no menu unless we build one. Minimal
    /// menu so ⌘Q / Hide work like a normal Mac app.
    private func buildAppMenu() {
        let main = NSMenu()
        let appItem = NSMenuItem()
        main.addItem(appItem)

        let appMenu = NSMenu()

        let setURL = makeItem("Set Video URL…", #selector(promptForURL))
        setURL.keyEquivalent = "u"
        appMenu.addItem(setURL)
        appMenu.addItem(makeItem("Play URL from Clipboard", #selector(playFromClipboard)))

        appMenu.addItem(.separator())
        appMenu.addItem(makeItem("More Opaque  (⌘⌥⌃↑)", #selector(opacityUpMenu)))
        appMenu.addItem(makeItem("More Transparent  (⌘⌥⌃↓)", #selector(opacityDownMenu)))
        appMenu.addItem(makeItem("Toggle Click-through  (⌘⌥⌃P)", #selector(toggleClickThroughMenu)))
        appMenu.addItem(makeItem("Toggle Ad Blocking  (⌘⌥⌃B)", #selector(toggleAdblockMenu)))
        appMenu.addItem(makeItem("Center / Reset Window  (⌘⌥⌃R)", #selector(panicResetMenu)))

        appMenu.addItem(.separator())
        historyAppMenu.delegate = self
        let historyItem = NSMenuItem(title: "History", action: nil, keyEquivalent: "")
        historyItem.submenu = historyAppMenu
        appMenu.addItem(historyItem)

        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Hide PhantomPiP",
                        action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        appMenu.addItem(withTitle: "Quit PhantomPiP",
                        action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu
        NSApp.mainMenu = main
    }

    // MARK: - Window

    private func buildWindow() {
        window = OverlayWindow(
            contentRect: NSRect(x: 0, y: 0, width: 640, height: 400),
            styleMask: [.borderless, .resizable],
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.level = .floating
        window.isMovableByWindowBackground = true
        window.minSize = NSSize(width: 240, height: 150)
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
    }

    private func buildWebView() {
        let container = NSView()
        container.wantsLayer = true
        container.layer?.borderWidth = 1
        container.layer?.borderColor = NSColor.white.withAlphaComponent(0.16).cgColor
        container.layer?.cornerRadius = 8
        container.layer?.masksToBounds = true
        window.contentView = container

        let config = WKWebViewConfiguration()
        config.mediaTypesRequiringUserActionForPlayback = []
        config.userContentController = userContent
        userContent.add(self, name: "phantom")

        webView = WKWebView(frame: .zero, configuration: config)
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.navigationDelegate = self
        webView.allowsBackForwardNavigationGestures = true
        webView.underPageBackgroundColor = .clear
        webView.layer?.backgroundColor = NSColor.clear.cgColor
        // Without this an empty/loaded WKWebView paints an opaque white
        // backing — defeating the whole see-through point. `drawsBackground`
        // is KVC-accessible on macOS WKWebView and stable for years.
        webView.setValue(false, forKey: "drawsBackground")
        container.addSubview(webView)

        // Capture page titles (including late SPA updates on YouTube's watch
        // page) to label history entries. The embed wrapper has no <title>,
        // so its real title arrives via the IFrame API instead.
        titleObservation = webView.observe(\.title, options: [.new]) { [weak self] _, _ in
            guard let self,
                  !self.loadedYouTubeWrapper,
                  let title = self.webView.title, !title.isEmpty,
                  !self.lastInput.isEmpty
            else { return }
            self.historyStore.setTitle(for: self.lastInput, title: title)
        }

        webView.loadHTMLString(Self.startHTML, baseURL: nil)

        let grip = ResizeGrip()
        grip.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(grip)

        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: container.topAnchor),
            webView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: container.bottomAnchor),

            grip.widthAnchor.constraint(equalToConstant: 18),
            grip.heightAnchor.constraint(equalToConstant: 18),
            grip.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            grip.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])
    }

    // MARK: - Status-bar menu

    private func buildStatusMenu() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            // A plain text title always renders — an SF Symbol that fails to
            // resolve in a non-bundled binary gives a zero-width, invisible
            // item with no way to reach the controls.
            button.title = "👻 PiP"
            button.toolTip = "PhantomPiP — click for controls"
        }

        let menu = NSMenu()

        menu.addItem(makeItem("Set Video URL…", #selector(promptForURL)))
        menu.addItem(makeItem("Play URL from Clipboard", #selector(playFromClipboard)))

        menu.addItem(.separator())

        let opacityItem = NSMenuItem()
        opacityItem.view = makeOpacityView()
        menu.addItem(opacityItem)

        menu.addItem(.separator())

        clickThroughItem = makeItem("Click-through", #selector(toggleClickThroughMenu))
        menu.addItem(clickThroughItem)

        fillWindowItem = makeItem("Fill Window With Video", #selector(toggleFillWindowMenu))
        fillWindowItem.state = fillWindow ? .on : .off
        menu.addItem(fillWindowItem)

        youTubeEmbedItem = makeItem("Use YouTube Embed Player", #selector(toggleYouTubeEmbedMenu))
        youTubeEmbedItem.state = useYouTubeEmbed ? .on : .off
        menu.addItem(youTubeEmbedItem)

        adblockItem = makeItem("Block Ads", #selector(toggleAdblockMenu))
        adblockItem.state = adblockEnabled ? .on : .off
        menu.addItem(adblockItem)

        menu.addItem(.separator())

        historyStatusMenu.delegate = self
        let historyItem = NSMenuItem(title: "History", action: nil, keyEquivalent: "")
        historyItem.submenu = historyStatusMenu
        menu.addItem(historyItem)

        menu.addItem(makeItem("Center / Reset Window", #selector(panicResetMenu)))

        let hints = NSMenuItem(
            title: "⌘⌥⌃U URL · ⌘⌥⌃Y embed · ⌘⌥⌃B adblock · ⌘⌥⌃P click-through · ⌘⌥⌃↑↓ opacity · ⌘⌥⌃R reset · ⌘-drag move",
            action: nil, keyEquivalent: "")
        hints.isEnabled = false
        menu.addItem(hints)

        menu.addItem(.separator())
        menu.addItem(makeItem("Quit PhantomPiP", #selector(quit)))

        statusItem.menu = menu
    }

    private func makeItem(_ title: String, _ action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        return item
    }

    private func makeOpacityView() -> NSView {
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 240, height: 32))

        let label = NSTextField(labelWithString: "Opacity")
        label.frame = NSRect(x: 14, y: 7, width: 54, height: 18)
        label.font = .menuFont(ofSize: 13)
        view.addSubview(label)

        opacitySlider = NSSlider(value: 1.0,
                                 minValue: minOpacity,
                                 maxValue: 1.0,
                                 target: self,
                                 action: #selector(opacityChanged))
        opacitySlider.isContinuous = true
        opacitySlider.frame = NSRect(x: 72, y: 6, width: 152, height: 20)
        view.addSubview(opacitySlider)

        return view
    }

    // MARK: - Hot keys

    private func registerHotKeys() {
        let center = HotKeyCenter.shared
        center.register(keyCode: Key.p, modifiers: Mod.all) { [weak self] in
            self?.toggleClickThrough()
        }
        center.register(keyCode: Key.u, modifiers: Mod.all) { [weak self] in
            self?.promptForURL()
        }
        center.register(keyCode: Key.y, modifiers: Mod.all) { [weak self] in
            self?.toggleYouTubeEmbedMenu()
        }
        center.register(keyCode: Key.b, modifiers: Mod.all) { [weak self] in
            self?.toggleAdblockMenu()
        }
        center.register(keyCode: Key.c, modifiers: Mod.all) { [weak self] in
            self?.toggleFillWindow()
        }
        center.register(keyCode: Key.r, modifiers: Mod.all) { [weak self] in
            self?.panicReset()
        }
        center.register(keyCode: Key.up, modifiers: Mod.all) { [weak self] in
            self?.nudgeOpacity(by: 0.1)
        }
        center.register(keyCode: Key.down, modifiers: Mod.all) { [weak self] in
            self?.nudgeOpacity(by: -0.1)
        }
    }

    /// No control strip to grab anymore, and the web view eats background
    /// drags — so ⌘-drag anywhere moves the window.
    private func installDragMonitor() {
        dragMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
            guard let self,
                  event.window === self.window,
                  event.modifierFlags.contains(.command) else { return event }
            self.window.performDrag(with: event)
            return nil
        }
    }

    // MARK: - Menu actions

    @objc private func promptForURL() {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "Video URL"
        alert.informativeText = "Paste a video page URL (YouTube, Twitch, a recorded talk…)."

        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 340, height: 24))
        field.stringValue = lastInput
        field.placeholderString = "https://www.youtube.com/watch?v=…"
        alert.accessoryView = field
        alert.addButton(withTitle: "Play")
        alert.addButton(withTitle: "Cancel")
        alert.window.initialFirstResponder = field

        if alert.runModal() == .alertFirstButtonReturn {
            load(field.stringValue)
        }
    }

    @objc private func playFromClipboard() {
        if let text = NSPasteboard.general.string(forType: .string) {
            load(text)
        } else {
            NSSound.beep()
        }
    }

    @objc private func opacityChanged() {
        applyOpacity(opacitySlider.doubleValue)
    }

    @objc private func toggleClickThroughMenu() { toggleClickThrough() }
    @objc private func toggleFillWindowMenu() { toggleFillWindow() }
    @objc private func opacityUpMenu() { nudgeOpacity(by: 0.1) }
    @objc private func opacityDownMenu() { nudgeOpacity(by: -0.1) }
    @objc private func toggleAdblockMenu() { setAdblock(!adblockEnabled) }

    @objc private func toggleYouTubeEmbedMenu() {
        useYouTubeEmbed.toggle()
        youTubeEmbedItem.state = useYouTubeEmbed ? .on : .off
        if !lastInput.isEmpty { load(lastInput) }
    }

    @objc private func panicResetMenu() { panicReset() }

    @objc private func quit() { NSApp.terminate(nil) }

    @objc private func historyItemClicked(_ sender: NSMenuItem) {
        if let url = sender.representedObject as? String { load(url) }
    }

    @objc private func clearHistory() { historyStore.clear() }

    // MARK: - NSMenuDelegate (lazy History submenu)

    func menuNeedsUpdate(_ menu: NSMenu) {
        guard menu === historyStatusMenu || menu === historyAppMenu else { return }
        menu.removeAllItems()

        let items = historyStore.items
        if items.isEmpty {
            let empty = NSMenuItem(title: "No history yet", action: nil, keyEquivalent: "")
            empty.isEnabled = false
            menu.addItem(empty)
            return
        }
        for entry in items.prefix(25) {
            let item = NSMenuItem(title: entry.displayTitle,
                                  action: #selector(historyItemClicked(_:)),
                                  keyEquivalent: "")
            item.target = self
            item.representedObject = entry.url
            item.toolTip = entry.url
            menu.addItem(item)
        }
        menu.addItem(.separator())
        let clear = NSMenuItem(title: "Clear History",
                               action: #selector(clearHistory), keyEquivalent: "")
        clear.target = self
        menu.addItem(clear)
    }

    // MARK: - Behavior

    private func load(_ raw: String) {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        lastInput = trimmed

        if useYouTubeEmbed, let id = youTubeID(from: trimmed) {
            // The embed player must run inside an <iframe> on a page with a
            // real https origin, or YouTube rejects it (Error 150/153).
            loadedYouTubeWrapper = true
            loadedYouTubeID = id
            youTubeFellBack = false
            historyStore.add(url: trimmed)
            webView.loadHTMLString(Self.youTubeWrapperHTML(id: id),
                                   baseURL: URL(string: "https://www.youtube.com"))
            return
        }

        loadedYouTubeWrapper = false
        loadedYouTubeID = nil
        let target = trimmed.contains("://") ? trimmed : "https://\(trimmed)"
        guard let url = URL(string: target) else {
            NSSound.beep()
            return
        }
        historyStore.add(url: trimmed)
        webView.load(URLRequest(url: url))
    }

    private func toggleClickThrough() {
        setClickThrough(!window.ignoresMouseEvents)
    }

    private func setClickThrough(_ on: Bool) {
        window.ignoresMouseEvents = on
        clickThroughItem?.state = on ? .on : .off
    }

    private func toggleFillWindow() {
        fillWindow.toggle()
        fillWindowItem?.state = fillWindow ? .on : .off
        if fillWindow {
            applyFillWindow()
        } else if !lastInput.isEmpty {
            load(lastInput) // reload to restore the full page
        }
    }

    private func nudgeOpacity(by delta: Double) {
        applyOpacity((opacitySlider?.doubleValue ?? 1.0) + delta)
    }

    private func applyOpacity(_ value: Double) {
        let clamped = min(1.0, max(minOpacity, value))
        opacitySlider?.doubleValue = clamped
        // Must be the WINDOW's alpha: WKWebView renders out-of-process in a
        // hosted layer that ignores the NSView's alphaValue, so the page
        // would stay fully opaque. Window alpha is applied by the window
        // server over the whole surface, web content included.
        window.alphaValue = CGFloat(clamped)
    }

    private func panicReset() {
        setClickThrough(false)
        applyOpacity(1.0)
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - WKNavigationDelegate

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        let host = webView.url?.host?.lowercased() ?? ""

        // Network ad/tracker domains are killed by the content rule list.
        // YouTube's in-stream video ads aren't (same infra as the video), so
        // the watch-page fallback gets a JS auto-skipper too. The embed
        // iframe is cross-origin — we can't inject into it.
        if adblockEnabled, !loadedYouTubeWrapper, host.contains("youtube.com") {
            webView.evaluateJavaScript(Self.youTubeAdSkipJS, completionHandler: nil)
        }

        // The YouTube wrapper's iframe already fills the window, and its
        // <video> lives in a cross-origin frame we can't (and shouldn't)
        // touch. Only generic pages need the "zoom the video" pass.
        guard fillWindow, !loadedYouTubeWrapper else { return }
        applyFillWindow()
    }

    private func applyFillWindow() {
        webView.evaluateJavaScript(Self.maximizeVideoJS, completionHandler: nil)
    }

    /// Fills the window with the video. On a YouTube watch page it pins
    /// YouTube's own `#movie_player` (keeps native controls); elsewhere it
    /// finds the largest <video> and lifts it to cover the viewport, hiding
    /// its ancestor siblings. Retries ~10s as players build asynchronously.
    private static let maximizeVideoJS = """
    (function () {
      function lockScroll() {
        document.documentElement.style.setProperty('overflow', 'hidden', 'important');
        if (document.body) {
          document.body.style.setProperty('overflow', 'hidden', 'important');
          document.body.style.setProperty('background', '#000', 'important');
        }
      }
      function cover(node) {
        node.style.setProperty('position', 'fixed', 'important');
        node.style.setProperty('top', '0', 'important');
        node.style.setProperty('left', '0', 'important');
        node.style.setProperty('width', '100vw', 'important');
        node.style.setProperty('height', '100vh', 'important');
        node.style.setProperty('z-index', '2147483647', 'important');
        node.style.setProperty('margin', '0', 'important');
        node.style.setProperty('background', '#000', 'important');
      }
      function maximize() {
        var yt = document.getElementById('movie_player');
        if (yt && yt.querySelector('video')) {
          lockScroll();
          cover(yt);
          var yv = yt.querySelector('video');
          yv.style.setProperty('width', '100%', 'important');
          yv.style.setProperty('height', '100%', 'important');
          try { yv.play(); } catch (e) {}
          return;
        }
        var vs = Array.prototype.slice.call(document.querySelectorAll('video'));
        vs = vs.filter(function (v) { return v.offsetWidth > 0 && v.offsetHeight > 0; });
        vs.sort(function (a, b) {
          return b.offsetWidth * b.offsetHeight - a.offsetWidth * a.offsetHeight;
        });
        var v = vs[0];
        if (!v) return;
        lockScroll();
        var el = v;
        while (el && el.parentElement && el !== document.body) {
          var p = el.parentElement;
          for (var i = 0; i < p.children.length; i++) {
            if (p.children[i] !== el) {
              p.children[i].style.setProperty('display', 'none', 'important');
            }
          }
          el = p;
        }
        cover(v);
        v.style.setProperty('object-fit', 'contain', 'important');
        try { v.play(); } catch (e) {}
      }
      maximize();
      var n = 0;
      var iv = setInterval(function () {
        maximize();
        if (++n > 20) clearInterval(iv);
      }, 500);
    })();
    """

    // MARK: - WKScriptMessageHandler (start-page URL box)

    func userContentController(_ controller: WKUserContentController,
                               didReceive message: WKScriptMessage) {
        guard message.name == "phantom", let body = message.body as? String else { return }
        if body.hasPrefix("yterror:") {
            handleYouTubeEmbedError()
        } else if body.hasPrefix("yttitle:") {
            historyStore.setTitle(for: lastInput,
                                  title: String(body.dropFirst("yttitle:".count)))
        } else {
            load(body)
        }
    }

    /// The IFrame player reported an error (usually 101/150 — embedding
    /// disabled by the uploader). Fall back to the full watch page, which
    /// always plays; the maximize pass then pins YouTube's own player.
    private func handleYouTubeEmbedError() {
        guard let id = loadedYouTubeID, !youTubeFellBack else { return }
        youTubeFellBack = true
        loadedYouTubeWrapper = false
        if let url = URL(string: "https://www.youtube.com/watch?v=\(id)") {
            webView.load(URLRequest(url: url))
        }
    }

    // MARK: - Ad blocking

    private func compileAdblock() {
        guard let store = WKContentRuleListStore.default() else { return }
        store.compileContentRuleList(forIdentifier: "phantom-adblock",
                                     encodedContentRuleList: Self.adblockJSON) { [weak self] list, error in
            guard let self else { return }
            if let error {
                NSLog("PhantomPiP: adblock compile failed: \(error.localizedDescription)")
                return
            }
            self.adblockRuleList = list
            if self.adblockEnabled, let list {
                self.userContent.add(list)
                self.adblockListAdded = true
            }
        }
    }

    private func setAdblock(_ on: Bool) {
        adblockEnabled = on
        adblockItem?.state = on ? .on : .off
        if let list = adblockRuleList {
            if on, !adblockListAdded {
                userContent.add(list)
                adblockListAdded = true
            } else if !on, adblockListAdded {
                userContent.remove(list)
                adblockListAdded = false
            }
        }
        // Reload so network rules apply/clear and the YouTube skipper is
        // (re-)installed or stops being injected.
        if !lastInput.isEmpty { load(lastInput) }
    }

    /// YouTube serves in-stream video ads from the same infra as the video,
    /// so the content blocker can't strip them. This clicks Skip, fast-
    /// forwards unskippable ads, and hides ad surfaces. Best-effort and
    /// inherently brittle to YouTube markup changes.
    private static let youTubeAdSkipJS = """
    (function () {
      if (window.__phantomAdSkip) return;
      window.__phantomAdSkip = true;
      function tick() {
        try {
          var mp = document.getElementById('movie_player');
          var adShowing = mp && (mp.classList.contains('ad-showing') ||
                                 mp.classList.contains('ad-interrupting'));
          var skip = document.querySelector(
            '.ytp-ad-skip-button, .ytp-ad-skip-button-modern, .ytp-skip-ad-button');
          if (skip) skip.click();
          var close = document.querySelector(
            '.ytp-ad-overlay-close-button, .ytp-ad-overlay-close-container');
          if (close) close.click();
          if (adShowing) {
            var v = document.querySelector('#movie_player video');
            if (v && isFinite(v.duration) && v.duration > 0) {
              v.muted = true;
              v.currentTime = v.duration;
            }
          }
          ['.video-ads', '.ytp-ad-module', '#player-ads', '#masthead-ad',
           'ytd-promoted-video-renderer', 'ytd-display-ad-renderer',
           'ytd-in-feed-ad-layout-renderer', 'ytd-ad-slot-renderer',
           '.ytd-companion-slot-renderer'].forEach(function (s) {
            document.querySelectorAll(s).forEach(function (e) {
              e.style.setProperty('display', 'none', 'important');
            });
          });
        } catch (e) {}
      }
      tick();
      setInterval(tick, 400);
    })();
    """

    /// Compact WKContentRuleList: blocks well-known third-party ad/tracker
    /// hosts and hides common ad containers. Deliberately excludes
    /// googlevideo/youtube/ytimg so video playback is never broken.
    private static let adblockJSON = #"""
    [
     {"trigger":{"url-filter":"^https?://([^/]*\\.)?doubleclick\\.net"},"action":{"type":"block"}},
     {"trigger":{"url-filter":"^https?://([^/]*\\.)?googlesyndication\\.com"},"action":{"type":"block"}},
     {"trigger":{"url-filter":"^https?://([^/]*\\.)?googleadservices\\.com"},"action":{"type":"block"}},
     {"trigger":{"url-filter":"^https?://([^/]*\\.)?google-analytics\\.com"},"action":{"type":"block"}},
     {"trigger":{"url-filter":"^https?://([^/]*\\.)?googletagmanager\\.com"},"action":{"type":"block"}},
     {"trigger":{"url-filter":"^https?://([^/]*\\.)?googletagservices\\.com"},"action":{"type":"block"}},
     {"trigger":{"url-filter":"^https?://([^/]*\\.)?adservice\\.google\\."},"action":{"type":"block"}},
     {"trigger":{"url-filter":"^https?://([^/]*\\.)?2mdn\\.net"},"action":{"type":"block"}},
     {"trigger":{"url-filter":"^https?://([^/]*\\.)?adnxs\\.com"},"action":{"type":"block"}},
     {"trigger":{"url-filter":"^https?://([^/]*\\.)?amazon-adsystem\\.com"},"action":{"type":"block"}},
     {"trigger":{"url-filter":"^https?://([^/]*\\.)?adsafeprotected\\.com"},"action":{"type":"block"}},
     {"trigger":{"url-filter":"^https?://([^/]*\\.)?doubleverify\\.com"},"action":{"type":"block"}},
     {"trigger":{"url-filter":"^https?://([^/]*\\.)?scorecardresearch\\.com"},"action":{"type":"block"}},
     {"trigger":{"url-filter":"^https?://([^/]*\\.)?quantserve\\.com"},"action":{"type":"block"}},
     {"trigger":{"url-filter":"^https?://([^/]*\\.)?moatads\\.com"},"action":{"type":"block"}},
     {"trigger":{"url-filter":"^https?://([^/]*\\.)?taboola\\.com"},"action":{"type":"block"}},
     {"trigger":{"url-filter":"^https?://([^/]*\\.)?outbrain\\.com"},"action":{"type":"block"}},
     {"trigger":{"url-filter":"^https?://([^/]*\\.)?criteo\\.com"},"action":{"type":"block"}},
     {"trigger":{"url-filter":"^https?://([^/]*\\.)?criteo\\.net"},"action":{"type":"block"}},
     {"trigger":{"url-filter":"^https?://([^/]*\\.)?pubmatic\\.com"},"action":{"type":"block"}},
     {"trigger":{"url-filter":"^https?://([^/]*\\.)?rubiconproject\\.com"},"action":{"type":"block"}},
     {"trigger":{"url-filter":"^https?://([^/]*\\.)?casalemedia\\.com"},"action":{"type":"block"}},
     {"trigger":{"url-filter":"^https?://([^/]*\\.)?bidswitch\\.net"},"action":{"type":"block"}},
     {"trigger":{"url-filter":"^https?://([^/]*\\.)?serving-sys\\.com"},"action":{"type":"block"}},
     {"trigger":{"url-filter":"^https?://([^/]*\\.)?adform\\.net"},"action":{"type":"block"}},
     {"trigger":{"url-filter":"^https?://([^/]*\\.)?smartadserver\\.com"},"action":{"type":"block"}},
     {"trigger":{"url-filter":"^https?://([^/]*\\.)?teads\\.tv"},"action":{"type":"block"}},
     {"trigger":{"url-filter":"^https?://([^/]*\\.)?demdex\\.net"},"action":{"type":"block"}},
     {"trigger":{"url-filter":"^https?://([^/]*\\.)?bluekai\\.com"},"action":{"type":"block"}},
     {"trigger":{"url-filter":".*"},"action":{"type":"css-display-none","selector":".adsbygoogle, ins.adsbygoogle, iframe[id^=\"google_ads_\"], iframe[src*=\"doubleclick\"], [id^=\"div-gpt-ad\"], .trc_related_container, #taboola-below-article, [data-ad-slot]"}}
    ]
    """#

    /// First screen shown in the window: a translucent card with a URL box,
    /// so the app is fully usable even if the menu-bar item is hidden behind
    /// a notch or menu-bar overflow.
    private static let startHTML = """
    <!doctype html><html><head><meta charset="utf-8">
    <style>
      html,body{margin:0;height:100%;background:transparent;
        font:14px -apple-system,BlinkMacSystemFont,sans-serif;color:#eee;
        display:flex;align-items:center;justify-content:center;}
      .card{background:rgba(18,18,20,.88);border:1px solid rgba(255,255,255,.14);
        border-radius:14px;padding:22px 24px;width:min(440px,82vw);
        box-shadow:0 10px 40px rgba(0,0,0,.5);}
      h1{font-size:15px;margin:0 0 4px;font-weight:600;}
      p{margin:0 0 14px;color:#9a9a9f;font-size:12px;line-height:1.5;}
      .row{display:flex;gap:8px;}
      input{flex:1;padding:9px 11px;border-radius:8px;border:1px solid #3a3a40;
        background:#0e0e10;color:#fff;font-size:13px;outline:none;}
      input:focus{border-color:#6a8cff;}
      button{padding:9px 16px;border-radius:8px;border:0;cursor:pointer;
        background:#3257d6;color:#fff;font-size:13px;font-weight:600;}
      button:hover{background:#3e63ec;}
      kbd{background:#26262b;border:1px solid #3a3a40;border-radius:4px;
        padding:1px 5px;font-size:11px;}
      .keys{margin-top:14px;color:#7d7d83;font-size:11px;line-height:1.9;}
    </style></head><body>
      <div class="card">
        <h1>PhantomPiP</h1>
        <p>Paste a video URL — it plays here, see-through, on top of your editor.</p>
        <div class="row">
          <input id="u" placeholder="https://www.youtube.com/watch?v=…" autofocus>
          <button onclick="go()">Play</button>
        </div>
        <div class="keys">
          <kbd>⌘⌥⌃U</kbd> set URL &nbsp; <kbd>⌘⌥⌃P</kbd> click-through &nbsp;
          <kbd>⌘⌥⌃↑↓</kbd> opacity &nbsp; <kbd>⌘⌥⌃R</kbd> reset<br>
          <kbd>⌘</kbd>-drag to move &nbsp;·&nbsp; drag the corner to resize
        </div>
      </div>
      <script>
        function go(){var v=document.getElementById('u').value.trim();
          if(v)window.webkit.messageHandlers.phantom.postMessage(v);}
        document.getElementById('u').addEventListener('keydown',function(e){
          if(e.key==='Enter')go();});
      </script>
    </body></html>
    """

    // MARK: - YouTube

    private func youTubeID(from raw: String) -> String? {
        let normalized = raw.contains("://") ? raw : "https://\(raw)"
        guard let comps = URLComponents(string: normalized),
              let host = comps.host?.lowercased() else { return nil }

        var id: String?
        if host.contains("youtu.be") {
            id = comps.path.split(separator: "/").first.map(String.init)
        } else if host.contains("youtube.com") {
            let parts = comps.path.split(separator: "/").map(String.init)
            if comps.path.hasPrefix("/watch") {
                id = comps.queryItems?.first(where: { $0.name == "v" })?.value
            } else if let kind = parts.first,
                      kind == "shorts" || kind == "embed" || kind == "live",
                      parts.count > 1 {
                id = parts[1]
            }
        }
        guard let videoID = id,
              !videoID.isEmpty,
              videoID.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" })
        else { return nil }
        return videoID
    }

    /// Hosts the embed in an <iframe> on a page whose origin is
    /// `https://www.youtube.com` (set via the load's baseURL). That, plus the
    /// `youtube-nocookie.com` embed host and a matching `origin` param, is
    /// what makes YouTube's player accept us (no Error 150/153).
    private static func youTubeWrapperHTML(id: String) -> String {
        """
        <!doctype html><html><head><meta charset="utf-8">
        <style>
          html,body{margin:0;height:100%;background:transparent;overflow:hidden;}
          #p,#p iframe{position:fixed;top:0;left:0;width:100vw;height:100vh;border:0;}
        </style></head><body>
          <div id="p"></div>
          <script src="https://www.youtube.com/iframe_api"></script>
          <script>
            function onYouTubeIframeAPIReady(){
              new YT.Player('p',{
                videoId:'\(id)',
                playerVars:{autoplay:1,playsinline:1,rel:0,modestbranding:1,
                  origin:'https://www.youtube.com'},
                events:{
                  onReady:function(e){
                    try{
                      var t=e.target.getVideoData().title;
                      if(t) window.webkit.messageHandlers.phantom.postMessage('yttitle:'+t);
                    }catch(_){}
                  },
                  onError:function(e){
                    window.webkit.messageHandlers.phantom.postMessage('yterror:'+e.data);
                  }
                }
              });
            }
          </script>
        </body></html>
        """
    }
}
