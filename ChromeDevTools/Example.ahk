#Requires AutoHotkey v2.0
#Include Chrome.ahk

try {
    ; Connect to the first available tab
    chromes := Chrome("http://localhost", 9222)

    MsgBox("Connected to Chrome!`nPage ID: " chromes.PageID)

    ; Navigate to a URL
    chromes.Send("Page.navigate", Map("url", "https://example.com"))

    ; Wait a bit for page load (simple wait, better ways exist via events)
    Sleep(2000)

    ; Get the document title
    ; Note: Runtime.evaluate is a powerful method to run JS
    result := chromes.SendWait("Runtime.evaluate", Map("expression", "document.title"))

    if (result.Has("result") && result["result"].Has("value")) {
        title := result["result"]["value"]
        MsgBox("Current Page Title: " title)
    } else {
        MsgBox("Failed to get title.")
    }

    ; Take a screenshot (this returns binary data, handling it requires Base64 decoding usually,
    ; but here we just show we can call the method)
    ; chrome.Send("Page.captureScreenshot")

} catch as e {
    MsgBox("Error: " e.Message)
}

ExitApp