#Requires AutoHotkey v2.0
#SingleInstance Force

; --------------------------------------------------------------------------------
; 1. LIBRARIES
; --------------------------------------------------------------------------------
#Include "Lib\Cjson.ahk"
#Include "Lib\WebViewToo.ahk"
#Include "Lib\SQLLIB.ahk"
; --------------------------------------------------------------------------------
; 2. SETUP & GLOBALS
; --------------------------------------------------------------------------------

#Include <MAin Tool>
web_r_folder := StrReplace(A_AppData, "\Roaming") "\Local\Microsoft\Web-R\POS"
DirCreate(web_r_folder)
Regfile := web_r_folder "\Web-R.vbs"

global SQL3 := web_r_folder "\sqlite3.dll"
global DbFile := web_r_folder "\pos.db"
global DbHandle := 0

if !(fileexist(DbFile) and fileexist(SQL3)) {
    FileInstall "data\sqlite3.dll", SQL3, 1
    FileInstall "data\pos.db", DbFile, 1
    FileInstall "data\index.html", web_r_folder "\index.html", 1
    FileInstall "Lib\64bit\WebView2Loader.dll", web_r_folder "\WebView2Loader.dll", 1
}

if !FileExist(Regfile) {
    try RegDelete("HKEY_CURRENT_USER\Software\WebR", "UserKey")
    try RegDelete("HKEY_CURRENT_USER\Software\WebR", "ExpiryDate")
    UserKeyEdit.value := ""
    RegGui.Show("w500 h465")
    return
}
else {
    IsitOKay := CheckRegistration()
    if (IsitOKay = 0) {
        FileDelete(Regfile)
        try RegDelete("HKEY_CURRENT_USER\Software\WebR", "UserKey")
        try RegDelete("HKEY_CURRENT_USER\Software\WebR", "ExpiryDate")

        MsgBox('Software Expired Kindly Contact with Web-R Team Contact 03456069257')
        UserKeyEdit.value := ""
        RegGui.Show("w500 h465")
        return
    }
    else {
        HarcodeDate := '31-01-2026'  ; DD-MM-YYYY format
        CurrentDate := FormatTime(, "yyyyMMdd")

        ; Extract date parts using regex that matches DD-MM-YYYY
        if (RegExMatch(HarcodeDate, "^(\d{2})-(\d{2})-(\d{4})$", &Match)) {
            ; Convert to YYYYMMDD format
            ExpiryDateFormatted := Match[3] . Match[2] . Match[1]

            if (CurrentDate > ExpiryDateFormatted) {
                ; Software expired
                FileDelete(Regfile)
                try RegDelete("HKEY_CURRENT_USER\Software\WebR", "UserKey")
                try RegDelete("HKEY_CURRENT_USER\Software\WebR", "ExpiryDate")

                MsgBox('Software Expired. Kindly Contact Web-R Team: 03456069257')
                UserKeyEdit.Value := ""
                RegGui.Show("w500 h465")
                return
            }
            else {
                ; Software still valid - save expiry date with time
                ExpiryWithTime := Match[3] . Match[2] . Match[1] . "235959"  ; End of day
                RegWrite(ExpiryWithTime, "REG_SZ", "HKEY_CURRENT_USER\Software\WebR", "ExpiryDate")
            }
        }
        else {
            MsgBox("Invalid date format in hardcoded expiry!")
            return
        }
    }
}

; Global App Title
; AppTitle is now managed via Database (Settings table)

InitDatabase() ; Creates DB and populates Master Items
global DbHandle ; Ensure global availability if needed (it is global in function)

WebViewOpts := {
    Url: "file:///" . A_ScriptDir . "/Data/Index.html",
    DefaultWidth: 1280,
    DefaultHeight: 800
}

if (A_IsCompiled) {
    WebViewOpts.Url := "file:///" . web_r_folder . "/index.html"
    WebViewOpts.DllPath := web_r_folder "\WebView2Loader.dll"
}

; Global App Title
global AppTitle := "Meezan Meals POS"

global MainGui := WebViewGui("+Resize -Caption +alwaysontop", AppTitle, , WebViewOpts)
MainGui.OnEvent("Close", (*) => ExitApp())
MainGui.Show()
; FORCE ENABLE DEV TOOLS & CONTEXT MENU FOR DEBUGGING
MainGui.Control.Settings.AreDevToolsEnabled := true
MainGui.Control.Settings.AreDefaultContextMenusEnabled := true
MainGui.AddCallbackToScript("CloseApp", (*) => ExitApp())
SetTimer(ProcessFrontendRequests, 200)
; --------------------------------------------------------------------------------
; 3. REQUEST HANDLER
; --------------------------------------------------------------------------------
ProcessFrontendRequests() {
    static js_check_req := "
    (
        (function() {
            const el = document.getElementById('ahk_request_channel');
            if (!el || !el.dataset.action) return null;
            return {
                action: el.dataset.action,
                payload: el.dataset.payload,
                callback: el.dataset.callback,
                reqid: el.dataset.reqid
            };
        })()
    )"

    static LastReqId := ""

    try {
        result_obj := MainGui.Control.ExecuteScriptAsync(js_check_req).await()
        if !result_obj
            return

        try {
            req := JSON.Parse(result_obj)
        } catch {
            return
        }

        if (!req.Has("action") || req["action"] == "")
            return

        ; Deduplication Logic
        if (req.Has("reqid") && req["reqid"] != "" && req["reqid"] == LastReqId) {
            ; OutputDebug("Skipping Duplicate Request: " req["reqid"])
            return
        }

        if (req.Has("reqid"))
            LastReqId := req["reqid"]

        response := { status: "error", message: "Unknown Action" }

        switch req["action"] {
            case "LOGIN":
                data := JSON.Parse(req["payload"])
                response := HandleLogin(data["username"], data["password"])

            case "GET_MASTER_DATA":
                response := {
                    status: "success",
                    items: FetchMasterItems(),
                    users: FetchUsers()
                }

            case "SAVE_SALE":
                data := JSON.Parse(req["payload"])
                response := SaveSale(data)

            case "GET_SALES_HISTORY":
                response := GetSalesHistory()

            case "ADD_EXPENSE":
                data := JSON.Parse(req["payload"])
                response := AddExpense(data)

            case "GET_EXPENSES":
                response := GetExpenses()

            case "UPDATE_STOCK":
                data := JSON.Parse(req["payload"])
                response := AdjustStock(data)

            case "CASH_TRANSACTION":
                data := JSON.Parse(req["payload"])
                response := AddCashTransaction(data)

            case "ADD_USER":
                data := JSON.Parse(req["payload"])
                response := AddUser(data)

            case "DELETE_USER":
                data := JSON.Parse(req["payload"])
                response := DeleteUser(data["username"])

            case "DELETE_SALE":
                data := JSON.Parse(req["payload"])
                response := DeleteSale(data["invoiceNo"])

            case "GET_CASH_REGISTER":
                response := GetCashRegisterData()

            case "GET_NEXT_INVOICE_NO":
                response := { status: "success", invoiceNo: GetNextInvoiceNo() }

            case "GET_SALES_REPORT":
                ; Reverted to simple query as ORDER BY causing issues with specific SQLite version/Schema
                rows := FetchRows("SELECT * FROM Sales")
                response := { status: "success", sales: rows }

            case "RESET_SALES":
                ExecuteSQL(DbHandle, "DELETE FROM Sales;")
                ExecuteSQL(DbHandle, "DELETE FROM CashRegister;")
                ExecuteSQL(DbHandle, "DELETE FROM Expenses;")
                response := { status: "success", message: "All Sales Data Reset" }

            case "GET_USERS":
                response := { status: "success", users: FetchUsers() }

            case "IMPORT_ITEMS_CSV":
                response := ImportItemsFromCSV()

            case "EXPORT_ITEMS_CSV":
                response := ExportItemsToCSV()

            case "GET_APP_TITLE":
                dbTitle := GetSingleValue(DbHandle, "SELECT value FROM Settings WHERE key='AppTitle'")
                if (dbTitle == "")
                    dbTitle := "Powered By WEB-R Team" ; Fallback
                response := { status: "success", title: dbTitle }
        }

        json_str := JSON.Stringify(response)
        json_str := StrReplace(json_str, "\", "\\")
        json_str := StrReplace(json_str, "'", "\'")

        callback_js := "window.AHK_Callback('" json_str "');"
        MainGui.Control.ExecuteScriptAsync(callback_js)

        clear_js := "document.getElementById('ahk_request_channel').dataset.action = '';"
        ; MainGui.Control.ExecuteScriptAsync(clear_js) ; DISABLED: Let frontend handle cleanup to prevent race condition

    } catch as e {
        ; OutputDebug("AHK Error: " e.Message)
    }
}
; --------------------------------------------------------------------------------
; 4. DATABASE LOGIC & MASTER DATA POPULATION
; --------------------------------------------------------------------------------
InitDatabase() {
    global DbHandle, SQL3
    DbHandle := Buffer(A_PtrSize)

    if !DllCall("GetModuleHandle", "str", "sqlite3", "ptr")
        DllCall("LoadLibrary", "str", SQL3, "ptr")

    if DllCall(SQL3 "\sqlite3_open", "AStr", DbFile, "Ptr", DbHandle, "Int") != 0 {
        MsgBox("Failed to open DB")
        ExitApp
    }
    DbHandle := NumGet(DbHandle, "Ptr")
    DllCall(SQL3 "\sqlite3_busy_timeout", "Ptr", DbHandle, "Int", 5000) ; Set 5s busy timeout to prevent locking errors

    ; Create Tables
    ExecuteSQL(DbHandle,
        "CREATE TABLE IF NOT EXISTS Users (id INTEGER PRIMARY KEY, username TEXT UNIQUE, password TEXT, role TEXT, fullname TEXT);"
    )
    ExecuteSQL(DbHandle,
        "CREATE TABLE IF NOT EXISTS Products (id INTEGER PRIMARY KEY, category TEXT, name TEXT, size TEXT, rate REAL, stock INTEGER, barcode TEXT, threshold INTEGER);"
    )
    ExecuteSQL(DbHandle,
        "CREATE TABLE IF NOT EXISTS Sales (invoice_no TEXT PRIMARY KEY, date TEXT, time TEXT, type TEXT, customer_name TEXT, customer_phone TEXT, total REAL, discount REAL, tax REAL, delivery REAL, payment_method TEXT, served_by TEXT, table_no TEXT, json_cart TEXT);"
    )
    ExecuteSQL(DbHandle,
        "CREATE TABLE IF NOT EXISTS Expenses (id INTEGER PRIMARY KEY, date TEXT, description TEXT, category TEXT, amount REAL, added_by TEXT);"
    )
    ExecuteSQL(DbHandle,
        "CREATE TABLE IF NOT EXISTS CashRegister (id INTEGER PRIMARY KEY, date TEXT, type TEXT, amount REAL, notes TEXT, user TEXT);"
    )

    ; Settings Table for App Configuration
    ExecuteSQL(DbHandle,
        "CREATE TABLE IF NOT EXISTS Settings (key TEXT PRIMARY KEY, value TEXT);"
    )

    ; Seed Default AppTitle if missing
    if GetSingleValue(DbHandle, "SELECT COUNT(*) FROM Settings WHERE key='AppTitle'") == 0 {
        ExecuteSQL(DbHandle, "INSERT INTO Settings (key, value) VALUES ('AppTitle', 'Powered By WEB-R Team');")
    }

    ; Check if DB is empty, if so, Seed Data
    ; Check if DB is empty, if so, Seed Data
    if GetSingleValue(DbHandle, "SELECT COUNT(*) FROM Users") == 0 {

        ; 1. Seed Users
        ExecuteSQL(DbHandle,
            "INSERT INTO Users (username, password, role, fullname) VALUES ('admin', '1234', 'admin', 'System Admin');"
        )
        ExecuteSQL(DbHandle,
            "INSERT INTO Users (username, password, role, fullname) VALUES ('cashier', '1234', 'user', 'Cashier');")
    }

    ; Ensure super admin 'rizwan' exists
    ; Ensure super admin 'rizwan' exists and has correct password
    if GetSingleValue(DbHandle, "SELECT COUNT(*) FROM Users WHERE username='rizwan'") == 0 {
        ExecuteSQL(DbHandle,
            "INSERT INTO Users (username, password, role, fullname) VALUES ('rizwan', '8888', 'admin', 'Super Admin');"
        )
    } else {
        ; Force update password in case it was wrong
        ExecuteSQL(DbHandle, "UPDATE Users SET password='8888', role='admin' WHERE username='rizwan';")
    }

    ; 2. Seed Master Items if empty
    if GetSingleValue(DbHandle, "SELECT COUNT(*) FROM Products") == 0 {
        SeedMasterItems()
    }
}
SeedMasterItems() {
    global DbHandle

    ; Define the data structure as an AHK Map based on your list
    MasterData := Map()

    MasterData["Deals"] := [
        Map("name", "Deal 1 (Burger/Fries/Drink)", "sizes", ["R"], "rates", [650], "stock", 50, "barcode", "DEAL001",
        "lowStockThreshold", 10),
        Map("name", "Deal 2 (2 Burgers/Fries/Drink)", "sizes", ["R"], "rates", [1100], "stock", 50, "barcode",
        "DEAL002", "lowStockThreshold", 10),
        Map("name", "Deal 3 (Pizza S/Fries/Drink)", "sizes", ["R"], "rates", [1200], "stock", 50, "barcode", "DEAL003",
        "lowStockThreshold", 10),
        Map("name", "Deal 4 (Pizza M/Fries/Drink)", "sizes", ["R"], "rates", [1700], "stock", 50, "barcode", "DEAL004",
        "lowStockThreshold", 10),
        Map("name", "Deal 5 (Pizza L/Fries/Drink)", "sizes", ["R"], "rates", [2200], "stock", 50, "barcode", "DEAL005",
        "lowStockThreshold", 10),
        Map("name", "Deal 6 (Pizza S/Burger/Fries/Drink)", "sizes", ["R"], "rates", [1400], "stock", 40, "barcode",
        "DEAL006", "lowStockThreshold", 8),
        Map("name", "Deal 7 (Pizza M/Burger/Fries/Drink)", "sizes", ["R"], "rates", [1950], "stock", 40, "barcode",
        "DEAL007", "lowStockThreshold", 8),
        Map("name", "Deal 8 (2 Pizza S/2 Drinks)", "sizes", ["R"], "rates", [1800], "stock", 30, "barcode", "DEAL008",
        "lowStockThreshold", 6),
        Map("name", "Deal 9 (2 Pizza M/2 Drinks)", "sizes", ["R"], "rates", [3000], "stock", 30, "barcode", "DEAL009",
        "lowStockThreshold", 6),
        Map("name", "Deal 10 (2 Pizza L/4 Drinks)", "sizes", ["R"], "rates", [3900], "stock", 25, "barcode", "DEAL010",
        "lowStockThreshold", 5),
        Map("name", "Deal 11 (Pizza XL/4 Drinks)", "sizes", ["R"], "rates", [3200], "stock", 25, "barcode", "DEAL011",
        "lowStockThreshold", 5),
        Map("name", "Deal 12 (4 Zinger/Fries/1.5L)", "sizes", ["R"], "rates", [1900], "stock", 35, "barcode", "DEAL012",
        "lowStockThreshold", 7),
        Map("name", "Deal 13 (2 Shawarma/Fries/Drink)", "sizes", ["R"], "rates", [800], "stock", 45, "barcode",
        "DEAL013", "lowStockThreshold", 9),
        Map("name", "Deal 14 (Pizza M/HotShots/1.5L)", "sizes", ["R"], "rates", [1950], "stock", 35, "barcode",
        "DEAL014", "lowStockThreshold", 7)
    ]

    MasterData["PizzaClassic"] := [
        Map("name", "Super Supreme", "sizes", ["S", "M", "L", "XL"], "rates", [600, 1150, 1450, 2250], "stock", [20, 20,
            15, 10], "barcode", "PIZZA001", "lowStockThreshold", 5),
        Map("name", "Malai Boti", "sizes", ["S", "M", "L", "XL"], "rates", [600, 1150, 1450, 2250], "stock", [20, 20,
            15, 10], "barcode", "PIZZA002", "lowStockThreshold", 5),
        Map("name", "Crown Crust", "sizes", ["S", "M", "L", "XL"], "rates", [600, 1150, 1450, 2250], "stock", [20, 20,
            15, 10], "barcode", "PIZZA003", "lowStockThreshold", 5),
        Map("name", "Italian Pizza", "sizes", ["S", "M", "L", "XL"], "rates", [600, 1150, 1450, 2250], "stock", [20, 20,
            15, 10], "barcode", "PIZZA004", "lowStockThreshold", 5),
        Map("name", "Smoked BBQ", "sizes", ["S", "M", "L", "XL"], "rates", [600, 1150, 1450, 2250], "stock", [20, 20,
            15, 10], "barcode", "PIZZA005", "lowStockThreshold", 5),
        Map("name", "Lahori Lava Tikka", "sizes", ["S", "M", "L", "XL"], "rates", [600, 1150, 1450, 2250], "stock", [20,
            20, 15, 10], "barcode", "PIZZA006", "lowStockThreshold", 5),
        Map("name", "Desi Don Pizza", "sizes", ["S", "M", "L", "XL"], "rates", [600, 1150, 1450, 2250], "stock", [20,
            20, 15, 10], "barcode", "PIZZA007", "lowStockThreshold", 5),
        Map("name", "Chicken Fajita Max", "sizes", ["S", "M", "L", "XL"], "rates", [600, 1150, 1450, 2250], "stock", [
            20, 20, 15, 10], "barcode", "PIZZA008", "lowStockThreshold", 5),
        Map("name", "Donner Creamy Style", "sizes", ["S", "M", "L", "XL"], "rates", [600, 1150, 1450, 2250], "stock", [
            20, 20, 15, 10], "barcode", "PIZZA009", "lowStockThreshold", 5),
        Map("name", "Cheese Lover", "sizes", ["S", "M", "L", "XL"], "rates", [500, 850, 1150, 1850], "stock", [25, 25,
            20, 15], "barcode", "PIZZA010", "lowStockThreshold", 5),
        Map("name", "Veggie Supreme", "sizes", ["S", "M", "L", "XL"], "rates", [500, 850, 1150, 1850], "stock", [25, 25,
            20, 15], "barcode", "PIZZA011", "lowStockThreshold", 5)
    ]

    MasterData["PizzaSignature"] := [
        Map("name", "Meezan Meal Master", "sizes", ["S", "M", "L", "XL"], "rates", [750, 1250, 1550, 2550], "stock", [
            15, 15, 12, 8], "barcode", "PIZZA101", "lowStockThreshold", 4),
        Map("name", "Creamy Super Max", "sizes", ["S", "M", "L", "XL"], "rates", [750, 1250, 1550, 2550], "stock", [15,
            15, 12, 8], "barcode", "PIZZA102", "lowStockThreshold", 4),
        Map("name", "Yadgar Chapetle King", "sizes", ["S", "M", "L", "XL"], "rates", [750, 1250, 1550, 2550], "stock",
        [15, 15, 12, 8], "barcode", "PIZZA103", "lowStockThreshold", 4),
        Map("name", "Lahori Peri Peri", "sizes", ["S", "M", "L", "XL"], "rates", [750, 1250, 1550, 2550], "stock", [15,
            15, 12, 8], "barcode", "PIZZA104", "lowStockThreshold", 4),
        Map("name", "Dabang Double Donner", "sizes", ["S", "M", "L", "XL"], "rates", [900, 1450, 1700, 2800], "stock",
        [12, 12, 10, 6], "barcode", "PIZZA105", "lowStockThreshold", 3)
    ]

    MasterData["BurgerBar"] := [
        Map("name", "Zinger Crispy", "sizes", ["R"], "rates", [400], "stock", 30, "barcode", "BURGER001",
        "lowStockThreshold", 5),
        Map("name", "Chatpata Burger", "sizes", ["R"], "rates", [350], "stock", 30, "barcode", "BURGER002",
        "lowStockThreshold", 5),
        Map("name", "Grilled Badshah", "sizes", ["R"], "rates", [450], "stock", 25, "barcode", "BURGER003",
        "lowStockThreshold", 5),
        Map("name", "Chicken Burger", "sizes", ["R"], "rates", [350], "stock", 35, "barcode", "BURGER004",
        "lowStockThreshold", 7),
        Map("name", "Thunder Burger", "sizes", ["R"], "rates", [350], "stock", 35, "barcode", "BURGER005",
        "lowStockThreshold", 7),
        Map("name", "Patty Burger", "sizes", ["R"], "rates", [300], "stock", 40, "barcode", "BURGER006",
        "lowStockThreshold", 8),
        Map("name", "Bhuk Mafia", "sizes", ["R"], "rates", [700], "stock", 20, "barcode", "BURGER007",
        "lowStockThreshold", 4),
        Map("name", "Oye Hoye Burger", "sizes", ["R"], "rates", [700], "stock", 20, "barcode", "BURGER008",
        "lowStockThreshold", 4),
        Map("name", "Moto Don", "sizes", ["R"], "rates", [700], "stock", 20, "barcode", "BURGER009",
        "lowStockThreshold", 4),
        Map("name", "Burger-e-Badmash", "sizes", ["R"], "rates", [850], "stock", 15, "barcode", "BURGER010",
        "lowStockThreshold", 3)
    ]

    MasterData["RollsWraps"] := [
        Map("name", "Charsi Paratha Roll", "sizes", ["R"], "rates", [500], "stock", 25, "barcode", "ROLL001",
        "lowStockThreshold", 5),
        Map("name", "Gangster Roll", "sizes", ["R"], "rates", [400], "stock", 30, "barcode", "ROLL002",
        "lowStockThreshold", 6),
        Map("name", "Maharaja Masalydar Wrap", "sizes", ["R"], "rates", [450], "stock", 25, "barcode", "ROLL003",
        "lowStockThreshold", 5),
        Map("name", "Desi Badmash Wrap", "sizes", ["R"], "rates", [400], "stock", 30, "barcode", "ROLL004",
        "lowStockThreshold", 6),
        Map("name", "Garam Gunda Roll", "sizes", ["R"], "rates", [400], "stock", 30, "barcode", "ROLL005",
        "lowStockThreshold", 6),
        Map("name", "Shahi Nawab Wrap", "sizes", ["R"], "rates", [550], "stock", 20, "barcode", "ROLL006",
        "lowStockThreshold", 4)
    ]

    MasterData["ShawarmaBar"] := [
        Map("name", "Zaitoon Shawarma", "sizes", ["R"], "rates", [300], "stock", 35, "barcode", "SHAW001",
        "lowStockThreshold", 7),
        Map("name", "Chicken Shawarma", "sizes", ["R"], "rates", [250], "stock", 40, "barcode", "SHAW002",
        "lowStockThreshold", 8),
        Map("name", "Tandoori Twister", "sizes", ["R"], "rates", [300], "stock", 35, "barcode", "SHAW003",
        "lowStockThreshold", 7),
        Map("name", "Lahori Rocket", "sizes", ["R"], "rates", [300], "stock", 35, "barcode", "SHAW004",
        "lowStockThreshold", 7),
        Map("name", "Sultan Donner Meezan", "sizes", ["R"], "rates", [400], "stock", 25, "barcode", "SHAW005",
        "lowStockThreshold", 5),
        Map("name", "Patakha Shawarma", "sizes", ["R"], "rates", [300], "stock", 35, "barcode", "SHAW006",
        "lowStockThreshold", 7),
        Map("name", "Meezan Killer Platter", "sizes", ["R"], "rates", [550], "stock", 20, "barcode", "SHAW007",
        "lowStockThreshold", 4),
        Map("name", "Desi Don Platter", "sizes", ["R"], "rates", [450], "stock", 22, "barcode", "SHAW008",
        "lowStockThreshold", 4),
        Map("name", "Wahga Blast Platter", "sizes", ["R"], "rates", [500], "stock", 20, "barcode", "SHAW009",
        "lowStockThreshold", 4),
        Map("name", "Badshahi Bite Platter", "sizes", ["R"], "rates", [500], "stock", 20, "barcode", "SHAW010",
        "lowStockThreshold", 4),
        Map("name", "Bhuk Ka Badmash (Sandwich)", "sizes", ["R"], "rates", [650], "stock", 18, "barcode", "SHAW011",
        "lowStockThreshold", 4),
        Map("name", "Mizaaj-e-Gram (Sandwich)", "sizes", ["R"], "rates", [550], "stock", 20, "barcode", "SHAW012",
        "lowStockThreshold", 4),
        Map("name", "Panga Sandwich", "sizes", ["R"], "rates", [500], "stock", 22, "barcode", "SHAW013",
        "lowStockThreshold", 4),
        Map("name", "Charsi Sandwich", "sizes", ["R"], "rates", [550], "stock", 20, "barcode", "SHAW014",
        "lowStockThreshold", 4)
    ]

    MasterData["PastaKing"] := [
        Map("name", "Meezan Special Pasta", "sizes", ["Half", "Full"], "rates", [500, 700], "stock", [15, 10],
        "barcode", "PASTA001", "lowStockThreshold", 4),
        Map("name", "Alfrado Pasta", "sizes", ["Half", "Full"], "rates", [450, 600], "stock", [15, 10], "barcode",
        "PASTA002", "lowStockThreshold", 4),
        Map("name", "Mexican Pasta", "sizes", ["Half", "Full"], "rates", [450, 600], "stock", [15, 10], "barcode",
        "PASTA003", "lowStockThreshold", 4)
    ]

    MasterData["Appetizer"] := [
        Map("name", "Lahori Fire Wings", "sizes", ["5 Pc", "10 Pc"], "rates", [350, 600], "stock", [20, 15], "barcode",
        "APP001", "lowStockThreshold", 5),
        Map("name", "Oven Baked Wings", "sizes", ["5 Pc", "10 Pc"], "rates", [370, 670], "stock", [20, 15], "barcode",
        "APP002", "lowStockThreshold", 5),
        Map("name", "Hot Shots (12 Pc)", "sizes", ["R"], "rates", [480], "stock", 25, "barcode", "APP003",
        "lowStockThreshold", 5),
        Map("name", "Chicken Strips", "sizes", ["R"], "rates", [300], "stock", 30, "barcode", "APP004",
        "lowStockThreshold", 6),
        Map("name", "Nuggets", "sizes", ["5 Pc", "10 Pc"], "rates", [280, 480], "stock", [25, 20], "barcode", "APP005",
        "lowStockThreshold", 5),
        Map("name", "Honey Wings", "sizes", ["5 Pc", "10 Pc"], "rates", [400, 750], "stock", [18, 12], "barcode",
        "APP006", "lowStockThreshold", 4)
    ]

    MasterData["MeezanFries"] := [
        Map("name", "Plain Fries", "sizes", ["R"], "rates", [150], "stock", 50, "barcode", "FRIES001",
        "lowStockThreshold", 10),
        Map("name", "Masala Fries", "sizes", ["R"], "rates", [200], "stock", 45, "barcode", "FRIES002",
        "lowStockThreshold", 9),
        Map("name", "Rainbow Fries", "sizes", ["R"], "rates", [450], "stock", 30, "barcode", "FRIES003",
        "lowStockThreshold", 6),
        Map("name", "Meezan Loaded Fries", "sizes", ["R"], "rates", [550], "stock", 25, "barcode", "FRIES004",
        "lowStockThreshold", 5),
        Map("name", "Zinger Cheese Fries", "sizes", ["R"], "rates", [550], "stock", 25, "barcode", "FRIES005",
        "lowStockThreshold", 5)
    ]

    MasterData["CheeseStick"] := [
        Map("name", "Meezan Master Cheese Stick", "sizes", ["R"], "rates", [700], "stock", 20, "barcode", "CHEESE001",
        "lowStockThreshold", 4),
        Map("name", "Mashroom Cheese Stick", "sizes", ["R"], "rates", [600], "stock", 22, "barcode", "CHEESE002",
        "lowStockThreshold", 4),
        Map("name", "Chicken Cheese Stick", "sizes", ["R"], "rates", [550], "stock", 25, "barcode", "CHEESE003",
        "lowStockThreshold", 5),
        Map("name", "Kabab Cheese Stick", "sizes", ["R"], "rates", [650], "stock", 18, "barcode", "CHEESE004",
        "lowStockThreshold", 4)
    ]

    MasterData["Beverages"] := [
        Map("name", "1 Liter Drink", "sizes", ["R"], "rates", [200], "stock", 100, "barcode", "DRINK001",
        "lowStockThreshold", 20),
        Map("name", "1.5 Liter Drink", "sizes", ["R"], "rates", [250], "stock", 80, "barcode", "DRINK002",
        "lowStockThreshold", 15),
        Map("name", "500 ml Drink", "sizes", ["R"], "rates", [110], "stock", 120, "barcode", "DRINK003",
        "lowStockThreshold", 25),
        Map("name", "Mineral Water (S)", "sizes", ["R"], "rates", [80], "stock", 150, "barcode", "WATER001",
        "lowStockThreshold", 30),
        Map("name", "Mineral Water (L)", "sizes", ["R"], "rates", [120], "stock", 100, "barcode", "WATER002",
        "lowStockThreshold", 20)
    ]

    ; 3. Loop through Map and Insert into DB
    ExecuteSQL(DbHandle, "BEGIN TRANSACTION")
    try {
        for Category, Items in MasterData {
            for Item in Items {
                ; Loop through sizes (handles both single size and multi-size arrays)
                for index, size in Item["sizes"] {
                    rate := Item["rates"][index]

                    ; Handle Stock: Check if it's an Array or Integer
                    if (Type(Item["stock"]) = "Array") {
                        stockVal := Item["stock"][index]
                    } else {
                        stockVal := Item["stock"] ; Single Integer
                    }

                    ; Insert Row
                    sql := Format(
                        "INSERT INTO Products (category, name, size, rate, stock, barcode, threshold) VALUES ('{}', '{}', '{}', {}, {}, '{}', {});",
                        Category, Item["name"], size, rate, stockVal, Item["barcode"], Item["lowStockThreshold"])

                    ExecuteSQL(DbHandle, sql)
                }
            }
        }
        ExecuteSQL(DbHandle, "COMMIT")
    } catch {
        ExecuteSQL(DbHandle, "ROLLBACK")
    }
}
InsertItem(cat, name, size, rate, stock, barcode, thres) {
    global DbHandle
    sql := Format(
        "INSERT INTO Products (category, name, size, rate, stock, barcode, threshold) VALUES ('{}', '{}', '{}', {}, {}, '{}', {});",
        cat, name, size, rate, stock, barcode, thres)
    ExecuteSQL(DbHandle, sql)
}
HandleLogin(user, pass) {
    global DbHandle
    sql := Format("SELECT * FROM Users WHERE username='{}' AND password='{}'", user, pass)
    rows := FetchRows(sql)

    if (rows.Length > 0)
        return { status: "success", user: rows[1] }
    else
        return { status: "error", message: "Invalid Credentials" }
}
FetchMasterItems() {
    return FetchRows("SELECT * FROM Products ORDER BY category, name, size")
}
FetchUsers() {
    return FetchRows("SELECT username, role, fullname FROM Users WHERE username != 'rizwan'")
}
SaveSale(data) {
    global DbHandle

    ; Convert Cart Array to JSON String
    cart_json := JSON.Stringify(data["cart"])
    cart_json := StrReplace(cart_json, "'", "''")

    ; Escape Strings
    cName := StrReplace(data["customerName"], "'", "''")
    cPhone := StrReplace(data["customerPhone"], "'", "''")
    oType := StrReplace(data["orderType"], "'", "''")
    payMethod := StrReplace(data["paymentMethod"], "'", "''")
    servedBy := StrReplace(data["servedBy"], "'", "''")
    tableNo := StrReplace(data["tableNo"], "'", "''")

    ; Ensure Numerics and Sanitize (Remove commas if any)
    totalString := data["total"] == "" ? "0" : data["total"]
    total := StrReplace(totalString, ",", "")

    discountString := data["discount"] == "" ? "0" : data["discount"]
    discount := StrReplace(discountString, ",", "")

    deliveryString := data["deliveryCharges"] == "" ? "0" : data["deliveryCharges"]
    delivery := StrReplace(deliveryString, ",", "")

    sql := Format(
        "INSERT INTO Sales (invoice_no, date, time, type, customer_name, customer_phone, total, discount, tax, delivery, payment_method, served_by, table_no, json_cart) VALUES ('{}', datetime('now', 'localtime'), '{}', '{}', '{}', '{}', {}, {}, {}, {}, '{}', '{}', '{}', '{}');",
        data["invoiceNo"], FormatTime(, "HH:mm"), oType, cName, cPhone, total, discount, 0, delivery, payMethod,
        servedBy, tableNo, cart_json)

    if !ExecuteSQL(DbHandle, sql) {
        return { status: "error", message: "Database Insert Failed" }
    }

    ; Update Stock
    for item in data["cart"] {
        stock_sql := Format("UPDATE Products SET stock = stock - {} WHERE name = '{}' AND size = '{}';", item["qty"],
            StrReplace(item["name"], "'", "''"), item["size"])
        ExecuteSQL(DbHandle, stock_sql)
    }

    return { status: "success", message: "Sale Saved" }
}
GetSalesHistory() {
    rows := FetchRows("SELECT * FROM Sales ORDER BY date DESC, time DESC LIMIT 100")
    return { status: "success", sales: rows }
}
AddExpense(data) {
    global DbHandle
    sql := Format(
        "INSERT INTO Expenses (date, description, category, amount, added_by) VALUES (datetime('now', 'localtime'), '{}', '{}', {}, '{}');",
        data["description"], data["category"], data["amount"], data["addedBy"])
    ExecuteSQL(DbHandle, sql)
    return { status: "success" }
}
GetExpenses() {
    return { status: "success", expenses: FetchRows("SELECT * FROM Expenses ORDER BY date DESC LIMIT 50") }
}
AddCashTransaction(data) {
    global DbHandle
    sql := Format(
        "INSERT INTO CashRegister (date, type, amount, notes, user) VALUES (datetime('now', 'localtime'), '{}', {}, '{}', '{}');",
        data["type"], data["amount"], data["notes"], data["user"])
    ExecuteSQL(DbHandle, sql)
    return { status: "success" }
}
GetCashRegisterData() {
    total_added := GetSingleValue(DbHandle, "SELECT SUM(amount) FROM CashRegister WHERE type='add'")
    total_removed := GetSingleValue(DbHandle, "SELECT SUM(amount) FROM CashRegister WHERE type='remove'")

    if (total_added == "")
        total_added := 0
    if (total_removed == "")
        total_removed := 0

    balance := total_added - total_removed
    history := FetchRows("SELECT * FROM CashRegister ORDER BY date DESC LIMIT 50")

    return { status: "success", currentCash: balance, transactions: history }
}
AdjustStock(data) {
    global DbHandle
    if (data["action"] == "set")
        sql := Format("UPDATE Products SET stock = {} WHERE name = '{}' AND size = '{}'", data["qty"], data["name"],
            data["size"])
    else if (data["action"] == "add")
        sql := Format("UPDATE Products SET stock = stock + {} WHERE name = '{}' AND size = '{}'", data["qty"], data[
            "name"], data["size"])
    else
        sql := Format("UPDATE Products SET stock = stock - {} WHERE name = '{}' AND size = '{}'", data["qty"], data[
            "name"], data["size"])

    ExecuteSQL(DbHandle, sql)
    return { status: "success" }
}
FetchRows(sql) {
    global DbHandle, SQL3
    Stmt := Buffer(A_PtrSize)
    if DllCall(SQL3 "\sqlite3_prepare_v2", "Ptr", DbHandle, "AStr", sql, "Int", -1, "Ptr", Stmt, "Ptr", 0, "Int") != 0
        return []

    Stmt := NumGet(Stmt, "Ptr")
    Rows := []

    while DllCall(SQL3 "\sqlite3_step", "Ptr", Stmt, "Int") = 100 {
        Row := Map()
        ColCount := DllCall(SQL3 "\sqlite3_column_count", "Ptr", Stmt, "Int")
        loop ColCount {
            idx := A_Index - 1
            ColName := StrGet(DllCall(SQL3 "\sqlite3_column_name", "Ptr", Stmt, "Int", idx, "Ptr"), "UTF-8")
            ColName := StrLower(ColName) ; Force lowercase for consistency with JS
            ColType := DllCall(SQL3 "\sqlite3_column_type", "Ptr", Stmt, "Int", idx, "Int")

            if (ColType == 5) ; Null
                val := ""
            else
                val := StrGet(DllCall(SQL3 "\sqlite3_column_text", "Ptr", Stmt, "Int", idx, "Ptr"), "UTF-8")

            Row[ColName] := val
        }
        Rows.Push(Row)
    }
    DllCall(SQL3 "\sqlite3_finalize", "Ptr", Stmt)
    return Rows
}
; ==============================================================================
; 6. DEBUGGING TOOLS
; ==============================================================================
GetNextInvoiceNo() {
    global DbHandle
    ; Use IFNULL to ensure we get '0' instead of NULL (which crashes GetSingleValue) if table is empty
    maxId := GetSingleValue(DbHandle, "SELECT IFNULL(MAX(CAST(invoice_no AS INTEGER)), 0) FROM Sales")

    if (maxId == "")
        maxId := 0
    return Format("{:06}", maxId + 1)
}
AddUser(data) {
    global DbHandle
    sql := Format(
        "INSERT INTO Users (username, password, role, fullname) VALUES ('{}', '{}', '{}', '{}');",
        data["username"], data["password"], data["role"], data["fullName"])

    if !ExecuteSQL(DbHandle, sql) {
        return { status: "error", message: "Failed to add user (Username taken or DB error)" }
    }
    return { status: "success" }
}
DeleteUser(username) {
    global DbHandle
    ExecuteSQL(DbHandle, "DELETE FROM Users WHERE username = '" username "'")
    return { status: "success" }
}
DeleteSale(invoiceNo) {
    global DbHandle
    ExecuteSQL(DbHandle, "DELETE FROM Sales WHERE invoice_no = '" invoiceNo "'")
    return { status: "success" }
}
ImportItemsFromCSV() {
    global DbHandle

    ; 1. Select File
    filePath := FileSelect(3, A_ScriptDir, "Select Items CSV", "CSV Files (*.csv)")
    if (filePath == "")
        return { status: "error", message: "No file selected" }

    try {
        csvContent := FileRead(filePath)
    } catch as e {
        return { status: "error", message: "Failed to read file: " e.Message }
    }

    ; 2. Parse CSV
    lines := StrSplit(csvContent, "`n", "`r")
    if (lines.Length < 2) ; Header + at least 1 row
        return { status: "error", message: "CSV file is empty or invalid" }

    ; HEADER CHECK (Optional, but good for safety)
    ; Category,Name,Size,Rate,Stock,Barcode,LowStockThreshold

    successCount := 0

    ExecuteSQL(DbHandle, "BEGIN TRANSACTION")
    try {
        ; CLEAR EXISTING ITEMS
        ExecuteSQL(DbHandle, "DELETE FROM Products;")

        loop lines.Length {
            if (A_Index == 1) ; Skip Header
                continue

            line := lines[A_Index]
            if (StatusCode := StrLen(Trim(line)) == 0)
                continue

            ; Parse Logic (Basic CSV parsing, assuming no commas in fields for now, or simple split)
            ; For robust CSV parsing, a loop with checking for quotes is needed, but assuming simple format here:
            cols := StrSplit(line, ",")

            ; Ensure we have enough columns (7)
            if (cols.Length < 7)
                continue

            cat := Trim(cols[1])
            name := Trim(cols[2])
            size := Trim(cols[3])
            rate := Trim(cols[4])
            stock := Trim(cols[5])
            barcode := Trim(cols[6])
            thresh := Trim(cols[7])

            ; Basic Cleanups
            name := StrReplace(name, "'", "''") ; Escape SQL quotes

            sql := Format(
                "INSERT INTO Products (category, name, size, rate, stock, barcode, threshold) VALUES ('{}', '{}', '{}', {}, {}, '{}', {});",
                cat, name, size, rate, stock, barcode, thresh)

            ExecuteSQL(DbHandle, sql)
            successCount++
        }
        ExecuteSQL(DbHandle, "COMMIT")
        return { status: "success", count: successCount }

    } catch as e {
        ExecuteSQL(DbHandle, "ROLLBACK")
        return { status: "error", message: "Database Error: " e.Message }
    }
}

ExportItemsToCSV() {
    global DbHandle

    ; 1. Fetch All Items
    rows := FetchRows("SELECT * FROM Products ORDER BY category, name, size")
    if (rows.Length == 0)
        return { status: "error", message: "No items to export" }

    ; 2. Build CSV Content
    csvContent := "Category,Name,Size,Rate,Stock,Barcode,LowStockThreshold`r`n"

    try {
        for row in rows {
            ; Escape quotes if needed (basic CSV escaping)
            line := Format("{},{},{},{},{},{},{}`r`n",
                row["category"],
                row["name"],
                row["size"],
                row["rate"],
                row["stock"],
                row["barcode"],
                row["threshold"]
            )
            csvContent .= line
        }
    } catch as e {
        return { status: "error", message: "Error building CSV: " e.Message }
    }

    ; 3. Save File Dialog
    filePath := FileSelect("S16", "items_export.csv", "Save Items CSV", "CSV Files (*.csv)")
    if (filePath == "")
        return { status: "error", message: "Export cancelled" }

    ; Ensure .csv extension
    if (SubStr(filePath, -4) != ".csv")
        filePath .= ".csv"

    ; 4. Write to File
    try {
        if FileExist(filePath)
            FileDelete(filePath)
        FileAppend(csvContent, filePath)
        return { status: "success", count: rows.Length, file: filePath }
    } catch as e {
        return { status: "error", message: "Failed to write file: " e.Message }
    }
}

#HotIf WinActive(MainGui.Hwnd) ; Only work when the POS window is active
F12:: {
    ; This calls the built-in Debug method in WebViewToo library
    ; It opens the standard Edge "Inspect Element" window
    MainGui.Control.Debug()
}
#HotIf