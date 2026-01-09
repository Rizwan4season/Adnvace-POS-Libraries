#Requires AutoHotkey v2.0
#SingleInstance Force

; Global Variables
global UserCode := ""
global UserKey := ""
global ExpiryDate := ""
global EncryptionKey := "MySecretKey2025" ; Change this to your own secret key

; Create GUI with better styling
MyGui := Gui("-Resize +MinSize500x380", "Web-R Registration")
MyGui.SetFont("s10", "Segoe UI")
MyGui.BackColor := "White"

; Add nice header with icon
MyGui.SetFont("s12 bold", "Segoe UI")
MyGui.Add("Text", "x20 y15 w460 Center c0066CC", "🔐 Web-R Registration System")

; Reset font
MyGui.SetFont("s10 norm", "Segoe UI")

; Instruction Box
MyGui.Add("GroupBox", "x20 y50 w460 h120", "Step 1: Get Your User Code")
MyGui.Add("Text", "x35 y75 w430 c333333", "Your unique User Code is generated below. Please copy and send it to our team to receive your registration key.")

; User Code Section with highlight
MyGui.Add("Text", "x35 y105 w80 c333333", "User Code:")
UserCodeEdit := MyGui.Add("Edit", "x35 y125 w350 h30 ReadOnly Background0xF0F8FF vUserCode")

; Copy User Code Button
CopyCodeBtn := MyGui.Add("Button", "x395 y125 w65 h30", "📋 Copy")
CopyCodeBtn.OnEvent("Click", CopyUserCode)

; Contact Information Box
MyGui.Add("GroupBox", "x20 y180 w460 h90", "📧 Contact Information")
MyGui.SetFont("s9", "Segoe UI")
MyGui.Add("Text", "x35 y205 w430 c0066CC", "Email: Webprogram@gmail.com")
MyGui.Add("Text", "x35 y225 w430 c0066CC", "WhatsApp/Phone: 0345-6069257")
MyGui.Add("Text", "x35 y245 w430 c666666", "Send your User Code to get your registration key within 24 hours.")

; Reset font
MyGui.SetFont("s10", "Segoe UI")

; Registration Box
MyGui.Add("GroupBox", "x20 y280 w460 h125", "Step 2: Enter Your Registration Key")

; User Key Section
MyGui.Add("Text", "x35 y305 w80 c333333", "User Key:")
UserKeyEdit := MyGui.Add("Edit", "x35 y325 w425 h30 vUserKey", "")

; Date Section (Disabled - Auto set from key)
MyGui.Add("Text", "x35 y365 w80 c333333", "Valid Until:")
DateEdit := MyGui.Add("DateTime", "x125 y362 w130 vExpiryDate Disabled ", "dd-MM-yyyy")
MyGui.Add("Text", "x265 y365 w200 c999999", "(Auto-set from key)")

; Buttons Section with better styling
MyGui.Add("Button", "x20 y415 w100 h35", "ℹ️ Contact Us").OnEvent("Click", ContactUs)
MyGui.Add("Button", "x130 y415 w100 h35", "🔄 Reload").OnEvent("Click", ReloadApp)
MyGui.Add("Button", "x240 y415 w100 h35", "🗑️ Del Reg Key").OnEvent("Click", DeleteRegKey)

; Main Apply button (highlighted)
ApplyBtn := MyGui.Add("Button", "x350 y415 w130 h35 Default", "✓ Apply License")
ApplyBtn.OnEvent("Click", ApplyRegistration)

; Show GUI
MyGui.Show("w500 h465")

; Auto-generate and highlight User Code on startup
AutoGenerateCode()

; Select/Highlight User Code automatically
UserCodeEdit.Focus()
Send("^a")  ; Select all text

; Copy User Code to Clipboard
CopyUserCode(*) {
    global UserCode
    
    A_Clipboard := UserCodeEdit.Value
    
    ; Visual feedback
    OriginalText := CopyCodeBtn.Text
    CopyCodeBtn.Text := "✓ Copied!"
    
    ; Show tooltip
    ToolTip("User Code copied to clipboard!`nNow send it to our team.", , , 1)
    SetTimer(() => ToolTip("", , , 1), 2000)
    
    ; Reset button text after 2 seconds
    SetTimer(() => CopyCodeBtn.Text := OriginalText, 2000)
}

; Auto-generate User Code function
AutoGenerateCode() {
    global UserCode, EncryptionKey
    
    ; Get Processor ID (Hardware ID)
    ProcessorID := GetProcessorID()
    
    ; Encrypt the Processor ID
    UserCode := EncryptString(ProcessorID, EncryptionKey)
    
    ; Display in User Code field
    UserCodeEdit.Value := UserCode
    
    ; Set default date as disabled (will be set from User Key)
    
    DateEdit.Value := a_now
    ;DateEdit.Value := FormatTime(, "dd-MM-yyyy")
}

; Apply Registration - New Function
ApplyRegistration(*) {
    global UserCode, UserKey, ExpiryDate, EncryptionKey
    
    UserKey := UserKeyEdit.Value
    
    if (UserKey = "") {
        MsgBox("❌ Please enter your User Key first!`n`nIf you haven't received it yet, please contact our team.", "Registration Required", "IconX 0x1000")
        UserKeyEdit.Focus()
        return
    }
    
    ; Show processing
    ApplyBtn.Enabled := false
    ApplyBtn.Text := "⏳ Validating..."
    
    ; Decrypt the User Key to get Hardware ID and Date
    try {
        DecryptedData := DecryptString(UserKey, EncryptionKey)
        
        ; Split Hardware ID and Expiry Date
        Parts := StrSplit(DecryptedData, "|")
        
        if (Parts.Length < 2) {
            throw Error("Invalid key format")
        }
        
        DecryptedHardwareID := Parts[1]
        DecryptedExpiryDate := Parts[2]
        CurrentHardwareID := GetProcessorID()
        
        ; Check if Hardware ID matches
        if (DecryptedHardwareID != CurrentHardwareID) {
            ApplyBtn.Enabled := true
            ApplyBtn.Text := "✓ Apply License"
            MsgBox("❌ Invalid User Key!`n`nThis registration key is not valid for this computer.`n`nPlease contact our support team.", "Registration Failed", "IconX 0x1000")
            return
        }
        
        ; Set the expiry date from User Key
        DateEdit.Value := DecryptedExpiryDate
        
        ; Check expiry date
        CurrentDate := FormatTime(, "yyyyMMdd")
        ExpiryDateFormatted := FormatTime(DecryptedExpiryDate, "yyyyMMdd")
        
        if (CurrentDate > ExpiryDateFormatted) {
            ApplyBtn.Enabled := true
            ApplyBtn.Text := "✓ Apply License"
            MsgBox("❌ Registration Expired!`n`nYour license expired on: " DecryptedExpiryDate "`n`nPlease contact our team for license renewal.", "Registration Expired", "IconX 0x1000")
            return
        }
        
        ; Save registration to registry
        RegWrite(UserKey, "REG_SZ", "HKEY_CURRENT_USER\Software\WebR", "UserKey")
        RegWrite(DecryptedExpiryDate, "REG_SZ", "HKEY_CURRENT_USER\Software\WebR", "ExpiryDate")
        
        ApplyBtn.Enabled := true
        ApplyBtn.Text := "✓ Applied"
        
        MsgBox("✅ Registration Successful!`n`nYour Web-R tool is now activated.`n`n📅 Valid until: " DecryptedExpiryDate "`n`nThank you for registering!", "Success", "Iconi 0x1000")
        
    } catch as err {
        ApplyBtn.Enabled := true
        ApplyBtn.Text := "✓ Apply License"
        MsgBox("❌ Invalid User Key!`n`nPlease check your key and try again.`n`nIf the problem persists, contact our support team.", "Validation Error", "IconX 0x1000")
    }
}

; Get Processor ID
GetProcessorID() {
    try {
        objWMI := ComObject("WbemScripting.SWbemLocator")
        objService := objWMI.ConnectServer(".", "root\cimv2")
        colItems := objService.ExecQuery("SELECT ProcessorId FROM Win32_Processor")
        
        for objItem in colItems {
            if (objItem.ProcessorId != "") {
                return objItem.ProcessorId
            }
        }
    }
    
    ; Fallback: Use ComputerName + UUID
    return A_ComputerName . "-" . CreateGUID()
}

; Create a simple GUID for unique identification
CreateGUID() {
    guid := ""
    Loop 32 {
        guid .= Format("{:X}", Random(0, 15))
    }
    return guid
}

; Encrypt String using simple XOR cipher
EncryptString(str, key) {
    result := ""
    keyLen := StrLen(key)
    
    Loop Parse str {
        charCode := Ord(A_LoopField)
        keyChar := Ord(SubStr(key, Mod(A_Index - 1, keyLen) + 1, 1))
        encryptedChar := charCode ^ keyChar
        result .= Format("{:02X}", encryptedChar)
    }
    
    return result
}

; Decrypt String using simple XOR cipher
DecryptString(encStr, key) {
    result := ""
    keyLen := StrLen(key)
    
    Loop (StrLen(encStr) / 2) {
        hexPair := SubStr(encStr, (A_Index - 1) * 2 + 1, 2)
        charCode := Integer("0x" hexPair)
        keyChar := Ord(SubStr(key, Mod(A_Index - 1, keyLen) + 1, 1))
        decryptedChar := charCode ^ keyChar
        result .= Chr(decryptedChar)
    }
    
    return result
}

; Validate Registration
ValidateRegistration() {
    global UserCode, UserKey, ExpiryDate, EncryptionKey
    
    UserKey := UserKeyEdit.Value
    ExpiryDate := DateEdit.Value
    
    if (UserKey = "") {
        return false
    }
    
    ; Decrypt the User Key to get original Hardware ID
    try {
        DecryptedData := DecryptString(UserKey, EncryptionKey)
        Parts := StrSplit(DecryptedData, "|")
        
        if (Parts.Length < 2) {
            return false
        }
        
        DecryptedHardwareID := Parts[1]
        CurrentHardwareID := GetProcessorID()
        
        ; Check if Hardware ID matches
        if (DecryptedHardwareID != CurrentHardwareID) {
            return false
        }
        
        ; Check expiry date
        ExpiryDateStr := DateEdit.Value
        CurrentDate := FormatTime(, "yyyyMMdd")
        ExpiryDateFormatted := FormatTime(ExpiryDateStr, "yyyyMMdd")
        
        if (CurrentDate > ExpiryDateFormatted) {
            return false
        }
        
        return true
        
    } catch {
        return false
    }
}

; Delete Registration Key
DeleteRegKey(*) {
    Result := MsgBox("Are you sure you want to delete the registration?`n`nYou will need to register again.", "Confirm Delete", "YesNo Icon? 0x1000")
    
    if (Result = "Yes") {
        try {
            RegDelete("HKEY_CURRENT_USER\Software\WebR", "UserKey")
            RegDelete("HKEY_CURRENT_USER\Software\WebR", "ExpiryDate")
            MsgBox("✓ Registration deleted successfully!`n`nThe application will now reload.", "Success", "Iconi 0x1000")
            Sleep(1000)
            ReloadApp()
        } catch {
            MsgBox("ℹ️ No registration found to delete.", "Information", "Iconi 0x1000")
        }
    }
}

; Contact Us
ContactUs(*) {
    MsgBox("📧 Contact Web-R Team`n`n" 
        . "━━━━━━━━━━━━━━━━━━━━━━━━━━━`n`n"
        . "📧 Email: Webprogram@gmail.com`n`n"
        . "📱 WhatsApp/Phone: 0345-6069257`n`n"
        . "━━━━━━━━━━━━━━━━━━━━━━━━━━━`n`n"
        . "Send your User Code to get your registration key!`n`n"
        . "We typically respond within 24 hours.", 
        "Contact Information", "Iconi 0x1000")
}

; Reload Application
ReloadApp(*) {
    Reload()
}

; Check registration on startup
CheckRegistration() {
    try {
        SavedKey := RegRead("HKEY_CURRENT_USER\Software\WebR", "UserKey")
        SavedDate := RegRead("HKEY_CURRENT_USER\Software\WebR", "ExpiryDate")
        
        UserKeyEdit.Value := SavedKey
        DateEdit.Value := SavedDate
        
        ; Validate automatically
        DecryptedData := DecryptString(SavedKey, EncryptionKey)
        Parts := StrSplit(DecryptedData, "|")
        
        if (Parts.Length >= 2) {
            DecryptedHardwareID := Parts[1]
            DecryptedExpiryDate := Parts[2]
            CurrentHardwareID := GetProcessorID()
            
            if (DecryptedHardwareID = CurrentHardwareID) {
                CurrentDate := FormatTime(, "yyyyMMdd")
                ExpiryDateFormatted := FormatTime(DecryptedExpiryDate, "yyyyMMdd")
                
                if (CurrentDate <= ExpiryDateFormatted) {
                    return true
                }
            }
        }
        return false
    } catch {
        return false
    }
}

; Run registration check on startup
; Uncomment the line below to enable automatic registration check
 IsitOKay := CheckRegistration()

 MsgBox IsitOKay