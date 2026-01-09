#Requires AutoHotkey v2.0
#Include ..\lib\WebSocket.ahk
#Include ..\lib\Cjson.ahk

class Chrome {
    static DebugPort := 9222

    __New(url := "http://localhost", port := 9222) {
        this.Host := url
        this.Port := port
        this.ws := ""
        this.PageID := ""
        this.Callbacks := Map()
        this.NextID := 1

        ; Get the WebSocket URL for the first page
        try {
            http := ComObject("WinHttp.WinHttpRequest.5.1")
            http.Open("GET", this.Host ":" this.Port "/json", false)
            http.Send()
            response := http.ResponseText
        } catch as e {
            throw Error("Failed to connect to Chrome at " this.Host ":" this.Port ". Ensure Chrome is running with --remote-debugging-port=" this
                .Port, -1)
        }

        pages := JSON.Parse(response)

        for page in pages {
            if (page["type"] == "page" && page.Has("webSocketDebuggerUrl")) {
                this.wsUrl := page["webSocketDebuggerUrl"]
                this.PageID := page["id"]
                break
            }
        }

        if (!this.wsUrl) {
            throw Error("No accessible page found.", -1)
        }

        ; Connect WebSocket
        this.ws := WebSocket(this.wsUrl, {
            message: this.OnMessage.Bind(this),
            close: this.OnClose.Bind(this)
        })
    }

    Send(method, params := Map(), callback := "") {
        if (!this.ws)
            throw Error("Not connected to Chrome.", -1)

        id := this.NextID++
        msg := Map("id", id, "method", method, "params", params)

        if (callback) {
            this.Callbacks[id] := callback
        }

        this.ws.SendText(JSON.Stringify(msg))
        return id
    }

    ; Synchronous version of Send (waits for response)
    SendWait(method, params := Map(), timeout := 5000) {
        response := ""
        isDone := false

        callback := (res) => (response := res, isDone := true)
        this.Send(method, params, callback)

        startTime := A_TickCount
        while (!isDone) {
            if (A_TickCount - startTime > timeout)
                throw Error("Timeout waiting for response to " method, -1)
            Sleep(10)
        }

        return response
    }

    OnMessage(ws, data) {
        try {
            msg := JSON.Parse(data)

            if (msg.Has("id") && this.Callbacks.Has(msg["id"])) {
                callback := this.Callbacks[msg["id"]]
                this.Callbacks.Delete(msg["id"])

                if (msg.Has("result"))
                    callback(msg["result"])
                else if (msg.Has("error"))
                    callback(msg["error"]) ; You might want to handle errors differently
            }

            ; Handle events (messages without id) here if needed
            ; if (msg.Has("method")) { ... }

        } catch as e {
            ; OutputDebug("Chrome.ahk: Error parsing message: " e.Message "`n")
        }
    }

    OnClose(ws, status, reason) {
        this.ws := ""
        ; OutputDebug("Chrome disconnected: " status " " reason "`n")
    }

    Disconnect() {
        if (this.ws) {
            this.ws.Shutdown()
            this.ws := ""
        }
    }

    __Delete() {
        this.Disconnect()
    }
}
