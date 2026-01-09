#Requires AutoHotkey v2.0
#SingleInstance Force

; Global Variables
global EncryptionKey := "MySecretKey2025" ; Must match the main tool's key

; Create GUI
KeyGenGui := Gui("+Resize", "Web-R Key Generator (Admin Tool)")
KeyGenGui.SetFont("s10", "Segoe UI")

; User Code Input (from customer)
KeyGenGui.Add("Text", "x20 y20 w100", "User Code:")
KeyGenGui.Add("Text", "x20 y40 w400 cGray", "(Paste the encrypted code from customer)")
UserCodeInput := KeyGenGui.Add("Edit", "x20 y65 w440 h80 vUserCode")

; Decrypted Hardware ID (for verification)
KeyGenGui.Add("Text", "x20 y155 w150", "Decrypted Hardware ID:")
DecryptedIDText := KeyGenGui.Add("Edit", "x20 y175 w440 h25 ReadOnly vDecryptedID")

; Expiry Date Selection
KeyGenGui.Add("Text", "x20 y215 w100", "Valid Until:")
ExpiryDatePicker := KeyGenGui.Add("DateTime", "x120 y212 w150 vExpiryDate", "dd-MM-yyyy")

; Generated User Key (to send to customer)
KeyGenGui.Add("Text", "x20 y255 w150", "Generated User Key:")
KeyGenGui.Add("Text", "x20 y275 w400 cGray", "(Send this key to customer)")
GeneratedKeyEdit := KeyGenGui.Add("Edit", "x20 y295 w440 h80 ReadOnly vGeneratedKey")

; Buttons
KeyGenGui.Add("Button", "x20 y390 w100 h35", "Decrypt Code").OnEvent("Click", DecryptUserCode)
KeyGenGui.Add("Button", "x130 y390 w130 h35", "Generate Key").OnEvent("Click", GenerateUserKey)
KeyGenGui.Add("Button", "x270 y390 w100 h35", "Copy Key").OnEvent("Click", CopyGeneratedKey)
KeyGenGui.Add("Button", "x380 y390 w80 h35", "Clear").OnEvent("Click", ClearAll)

; Information Text
KeyGenGui.Add("Text", "x20 y435 w440 cBlue", "Instructions: 1) Get User Code from customer → 2) Decrypt to verify → 3) Set expiry date → 4) Generate Key → 5) Send to customer")

; Show GUI
KeyGenGui.Show("w480 h480")

; Decrypt User Code to see Hardware ID
DecryptUserCode(*) {
    global EncryptionKey
    
    UserCode := UserCodeInput.Value
    
    if (UserCode = "") {
        MsgBox("Please enter User Code from customer!", "Error", "Icon!")
        return
    }
    
    try {
        DecryptedID := DecryptString(UserCode, EncryptionKey)
        DecryptedIDText.Value := DecryptedID
        MsgBox("User Code decrypted successfully!`n`nHardware ID: " DecryptedID, "Success", "Icon!")
    } catch as err {
        MsgBox("Error decrypting code: " err.Message, "Error", "Icon!")
    }
}

; Generate User Key for customer
GenerateUserKey(*) {
    global EncryptionKey
    
    UserCode := UserCodeInput.Value
    
    if (UserCode = "") {
        MsgBox("Please enter and decrypt User Code first!", "Error", "Icon!")
        return
    }
    
    try {
        ; Decrypt to get Hardware ID
        HardwareID := DecryptString(UserCode, EncryptionKey)
        
        ; Get selected expiry date
        ExpiryDate := ExpiryDatePicker.Value
        
        ; Combine Hardware ID with Expiry Date
        CombinedData := HardwareID . "|" . ExpiryDate
        
        ; Encrypt combined data to create User Key
        UserKey := EncryptString(CombinedData, EncryptionKey)
        
        ; Display generated key
        GeneratedKeyEdit.Value := UserKey
        
        ; Show information
        MsgBox("User Key generated successfully!`n`nHardware ID: " HardwareID "`nValid Until: " ExpiryDate "`n`nSend the User Key to customer.", "Success", "Icon!")
        
    } catch as err {
        MsgBox("Error generating key: " err.Message, "Error", "Icon!")
    }
}

; Copy Generated Key to Clipboard
CopyGeneratedKey(*) {
    GeneratedKey := GeneratedKeyEdit.Value
    
    if (GeneratedKey = "") {
        MsgBox("Please generate a key first!", "Error", "Icon!")
        return
    }
    
    A_Clipboard := GeneratedKey
    MsgBox("User Key copied to clipboard!`n`nYou can now send it to the customer.", "Success", "Icon!")
}

; Clear All Fields
ClearAll(*) {
    UserCodeInput.Value := ""
    DecryptedIDText.Value := ""
    GeneratedKeyEdit.Value := ""
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