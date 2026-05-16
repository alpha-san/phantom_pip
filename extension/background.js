// PhantomPiP extension — hands a URL to the native app via the
// phantompip:// scheme. macOS routes it to PhantomPiP, launching it if
// it isn't already running.

function sendToPhantom(targetUrl) {
  if (!targetUrl || !/^https?:\/\//i.test(targetUrl)) return;
  const deepLink = "phantompip://play?u=" + encodeURIComponent(targetUrl);

  // Opening a custom scheme needs a navigation. Use a throwaway background
  // tab; the OS protocol handler fires, then we discard the blank tab.
  chrome.tabs.create({ url: deepLink, active: false }, (tab) => {
    if (chrome.runtime.lastError || !tab) return;
    setTimeout(() => chrome.tabs.remove(tab.id).catch(() => {}), 1200);
  });
}

// Toolbar button → send the active tab.
chrome.action.onClicked.addListener((tab) => sendToPhantom(tab && tab.url));

// Right-click menu.
chrome.runtime.onInstalled.addListener(() => {
  chrome.contextMenus.removeAll(() => {
    chrome.contextMenus.create({
      id: "phantompip-page",
      title: "Open in PhantomPiP",
      contexts: ["page", "video", "selection"],
    });
    chrome.contextMenus.create({
      id: "phantompip-link",
      title: "Open link in PhantomPiP",
      contexts: ["link"],
    });
  });
});

chrome.contextMenus.onClicked.addListener((info, tab) => {
  const url =
    info.menuItemId === "phantompip-link"
      ? info.linkUrl
      : info.pageUrl || (tab && tab.url);
  sendToPhantom(url);
});
