Items_NameUniq(*)
{
    SelectSQL := "SELECT DISTINCT Items FROM AddItems;"
    StmtHandle := Buffer(A_PtrSize)
    Result := DllCall(SQL3 "\sqlite3_prepare_v2", "Ptr", DbHandle, "AStr", SelectSQL, "Int", -1, "Ptr", StmtHandle, "Ptr", 0, "Int")

    if (Result != 0) {
        MsgBox "Error preparing query: " . Result ,'SQL' , 0x40040
        return
    }
    StmtHandle := NumGet(StmtHandle, "Ptr")
    
    Itms := []
    while (DllCall(SQL3 "\sqlite3_step", "Ptr", StmtHandle, "Int") = 100)
    {
        ItemsCatagroy := StrGet(DllCall(SQL3 "\sqlite3_column_text", "Ptr", StmtHandle, "Int", 0, "Ptr"), "UTF-8")         
        Itms.Push(ItemsCatagroy)
    }
    DllCall(SQL3 "\sqlite3_finalize", "Ptr", StmtHandle)
    return Itms
}

Item_CategoryUniq(TabelName := "AddItems")
{
    SelectSQL := "SELECT DISTINCT Item_Category FROM " TabelName ";"
    StmtHandle := Buffer(A_PtrSize)
    Result := DllCall(SQL3 "\sqlite3_prepare_v2", "Ptr", DbHandle, "AStr", SelectSQL, "Int", -1, "Ptr", StmtHandle, "Ptr", 0, "Int")

    if (Result != 0) {
        MsgBox "Error preparing query: " . Result ,'SQL' , 0x40040
        return
    }
    StmtHandle := NumGet(StmtHandle, "Ptr")
    
    Itms := []
    while (DllCall(SQL3 "\sqlite3_step", "Ptr", StmtHandle, "Int") = 100)
    {
        ItemsCatagroy := StrGet(DllCall(SQL3 "\sqlite3_column_text", "Ptr", StmtHandle, "Int", 0, "Ptr"), "UTF-8")         
        Itms.Push(ItemsCatagroy)
    }
    DllCall(SQL3 "\sqlite3_finalize", "Ptr", StmtHandle)
    return ArraySort(Itms)
}

ArraySort(Name)
{
    nameStr := ""
    for name in Name {
        nameStr .= name . "`n"
    }
    sortedNameStr := Sort(nameStr)  ; Default alphabetical sort
    sortedNames := StrSplit(Trim(sortedNameStr, "`n"), "`n")
    return sortedNames
}

MaxNumber(TabelName)
{
    SelectSQL := "SELECT MAX(Order_No) FROM " TabelName ";"
    StmtHandle := Buffer(A_PtrSize)
    Result := DllCall(SQL3 "\sqlite3_prepare_v2", "Ptr", DbHandle, "AStr", SelectSQL, "Int", -1, "Ptr", StmtHandle, "Ptr", 0, "Int")
    
    if (Result != 0)
    {
        MsgBox "Error preparing query: " . Result ,'SQL' , 0x40040
        return
    }

    StmtHandle := NumGet(StmtHandle, "Ptr")
    maxVal := ""
    if (DllCall(SQL3 "\sqlite3_step", "Ptr", StmtHandle, "Int") = 100)
    {
        ptr := DllCall(SQL3 "\sqlite3_column_text", "Ptr", StmtHandle, "Int", 0, "Ptr")
        if ptr
            maxVal := StrGet(ptr, "UTF-8")
    }

    DllCall(SQL3 "\sqlite3_finalize", "Ptr", StmtHandle)
    return maxVal
}

OrderWiseTotal(OrderNo,TabelName)
{
    SelectSQL := "SELECT Order_NO, SUM(ItemAmount) AS TotalAmount FROM " TabelName " Where Order_NO ='" OrderNo "';"
    StmtHandle := Buffer(A_PtrSize)
    Result := DllCall(SQL3 "\sqlite3_prepare_v2", "Ptr", DbHandle, "AStr", SelectSQL, "Int", -1, "Ptr", StmtHandle, "Ptr", 0, "Int")

    if (Result != 0)
    {
        MsgBox "Error preparing query: " . Result ,'SQL' , 0x40040
        return
    }

    StmtHandle := NumGet(StmtHandle, "Ptr")
    while (DllCall(SQL3 "\sqlite3_step", "Ptr", StmtHandle, "Int") = 100)
    {
        TotalAmt := StrGet(DllCall(SQL3 "\sqlite3_column_text", "Ptr", StmtHandle, "Int", 1, "Ptr"), "UTF-8")
        return TotalAmt 
    }
    DllCall(SQL3 "\sqlite3_finalize", "Ptr", StmtHandle)
}

DeleteDatabase(TabelName)
{
    global DbHandle, DbFile, SQL3

    DbHandle := Buffer(A_PtrSize)
    Result := DllCall(SQL3 "\sqlite3_open", "AStr", DbFile, "Ptr", DbHandle, "Int")

    if (Result != 0) {
        MsgBox("Error opening database: " . Result ,'SQL' , 0x40040)
        ExitApp()
    }

    DbHandle := NumGet(DbHandle, "Ptr")

    Create_Col_of_Database := "Order_NO INTEGER,CustomerName TEXT,Address TEXT,ItemAmount INTEGER,Item_Category TEXT,ItemKg INTEGER,OrderDate TEXT,ReleaseDate TEXT,ItemName TEXT,ItemRate INTEGER,Advance INTEGER,OrderNO_Plus_lvCount INTEGER,Phone_Number TEXT,Time TEXT,Status TEXT,Discount INTEGER,Person TEXT,PerHead INTEGER"
    Col_of_Database := "Order_NO,CustomerName,Address,ItemAmount,Item_Category,ItemKg,OrderDate,ReleaseDate,ItemName,ItemRate,Advance,OrderNO_Plus_lvCount,Phone_Number,Time,Status,Discount,Person,PerHead"

    CreateTableSQL := "CREATE TABLE IF NOT EXISTS '" TabelName "' (" Create_Col_of_Database ");"
    ExecuteSQL(DbHandle, CreateTableSQL)

    CountSQL := "SELECT COUNT(*) FROM '" TabelName "';"
    Count := GetSingleValue(DbHandle, CountSQL)

    ; if (Count = 0)
    ;     MSGBOX "Delete order Create"
}

InitializeDatabase(TabelName)
{
    
    global DbHandle, DbFile, SQL3

    DbHandle := Buffer(A_PtrSize)
    Result := DllCall(SQL3 "\sqlite3_open", "AStr", DbFile, "Ptr", DbHandle, "Int")

    if (Result != 0) {
        MsgBox("Error opening database: " . Result ,'SQL' , 0x40040)
        ExitApp()
    }

    DbHandle := NumGet(DbHandle, "Ptr")

    Create_Col_of_Database := "Order_NO INTEGER,CustomerName TEXT,Address TEXT,ItemAmount INTEGER,Item_Category TEXT,ItemKg INTEGER,OrderDate TEXT,ReleaseDate TEXT,ItemName TEXT,ItemRate INTEGER,Advance INTEGER,OrderNO_Plus_lvCount INTEGER,Phone_Number TEXT,Time TEXT,Status TEXT,Discount INTEGER,Person TEXT,PerHead INTEGER"
    Col_of_Database := "Order_NO,CustomerName,Address,ItemAmount,Item_Category,ItemKg,OrderDate,ReleaseDate,ItemName,ItemRate,Advance,OrderNO_Plus_lvCount,Phone_Number,Time,Status,Discount,Person,PerHead"

    CreateTableSQL := "CREATE TABLE IF NOT EXISTS '" TabelName "' (" Create_Col_of_Database ");"
    ExecuteSQL(DbHandle, CreateTableSQL)

    CountSQL := "SELECT COUNT(*) FROM '" TabelName "';"
    Count := GetSingleValue(DbHandle, CountSQL)

    if (Count = 0)
    {
        MSGBOX
        Loop read,"E:\Web-R Software\Pakwan-Center\V2\Data\old\orders 12-06-2025.txt"
        {
            txtdata := StrSplit(A_LoopReadLine,A_Tab)
            Oder := Format("{:05}",txtdata[1])
            ExecuteSQL(DbHandle,"INSERT INTO '" TabelName "' (" Col_of_Database ") VALUES ('" Oder "', '" txtdata[2] "', '" txtdata[3] "', '" txtdata[4] "', '" txtdata[5] "', '" txtdata[6] "', '" txtdata[7] "', '" txtdata[8] "', '" txtdata[9] "', '" txtdata[10] "', '" txtdata[11] "', '" txtdata[12] "', '" txtdata[13] "', '" txtdata[14] "', '" txtdata[15] "', '" txtdata[16] "', '" txtdata[17] "', '" txtdata[18] "');")            
        }
        /*
        loop 2
        {
            ItemAmount := a_index * 10
            OrderNO_Plus_lvCount := a_index
            ExecuteSQL(DbHandle,
                "INSERT INTO '" TabelName "' (" Col_of_Database ") VALUES (" 
                "'Rizawn', 'Landhi', " ItemAmount ", 'Biryani', 5, '2025-05-25', '2025-05-26', 'Chicken Biryani', 200, 100, " OrderNO_Plus_lvCount ", '03001234567', '12:00 PM', 'Pending', 0, 'Ali', 10, 'Cash', 'Not Released'"
                ");")
        }
        */
    }
}

NewOrderTableCreate(TabelName)
{
    global DbHandle, DbFile, SQL3

    DbHandle := Buffer(A_PtrSize)
    Result := DllCall(SQL3 "\sqlite3_open", "AStr", DbFile, "Ptr", DbHandle, "Int")

    if (Result != 0) {
        MsgBox("Error opening database: " . Result ,'SQL' , 0x40040)
        ExitApp()
    }

    DbHandle := NumGet(DbHandle, "Ptr")

    Create_Col_of_Database := "Item_Category TEXT,Items TEXT,AmountPerKg TEXT,Person50,Person100,Person150,Person200,Person250,Person300,Person350,Person400,Person450,Person500,Person550,Person600,Person650,Person700,Person750,Person800,Person850,Person900,Person950,Person1000"
    Col_of_Database := "Item_Category,Items,AmountPerKg,Person50,Person100,Person150,Person200,Person250,Person300,Person350,Person400,Person450,Person500,Person550,Person600,Person650,Person700,Person750,Person800,Person850,Person900,Person950,Person1000"

    
    CreateTableSQL := "CREATE TABLE IF NOT EXISTS '" TabelName "' (" Create_Col_of_Database ");"
    ExecuteSQL(DbHandle, CreateTableSQL)

    CountSQL := "SELECT COUNT(*) FROM '" TabelName "';"
    Count := GetSingleValue(DbHandle, CountSQL)

    if (Count = 0)
    {
        Loop read, "E:\Web-R Software\Pakwan-Center\V2\Data\old\AddedItems.txt"
        {
            txtdata := StrSplit(A_LoopReadLine,A_Tab)
            if A_Index = 1
                continue
            ExecuteSQL(DbHandle,"INSERT INTO '" TabelName "' (" Col_of_Database ") VALUES ('" txtdata[1] "', '" txtdata[2] "','" txtdata[3] "','" txtdata[4] "','" txtdata[5] "','" txtdata[6] "','" txtdata[7] "','" txtdata[8] "','" txtdata[9] "','" txtdata[10] "','" txtdata[11] "','" txtdata[12] "','" txtdata[13] "','" txtdata[14] "','" txtdata[15] "','" txtdata[16] "','" txtdata[17] "','" txtdata[18] "','" txtdata[19] "','" txtdata[20] "','" txtdata[21] "','" txtdata[22] "','" txtdata[23] "');")
            ;ExecuteSQL(DbHandle,"INSERT INTO '" TabelName "' (" Col_of_Database ") VALUES ('" txtdata[1] "', '" txtdata[2] "','" txtdata[3] "','" txtdata[4] "','" txtdata[5] "','" txtdata[6] "','" txtdata[7] "','" txtdata[8] "','" txtdata[9] "','" txtdata[10] "','" txtdata[11] "','" txtdata[12] "','" txtdata[13] "','" txtdata[14] "','" txtdata[15] "','" txtdata[16] "','" txtdata[17] "','" txtdata[18] "','" txtdata[19] "','" txtdata[20] "');")
        }
    }
}


AddMorePaymentTableCreate(TabelName)
{
    global DbHandle, DbFile, SQL3

    DbHandle := Buffer(A_PtrSize)
    Result := DllCall(SQL3 "\sqlite3_open", "AStr", DbFile, "Ptr", DbHandle, "Int")

    if (Result != 0) {
        MsgBox("Error opening database: " . Result ,'SQL' , 0x40040)
        ExitApp()
    }

    DbHandle := NumGet(DbHandle, "Ptr")

    Create_Col_of_Database := "OrderNO,Trams,Receiveby,Amount,Date,CheqNO,Banks"
    
    CreateTableSQL := "CREATE TABLE IF NOT EXISTS '" TabelName "' (" Create_Col_of_Database ");"
    ExecuteSQL(DbHandle, CreateTableSQL)

    CountSQL := "SELECT COUNT(*) FROM '" TabelName "';"
    Count := GetSingleValue(DbHandle, CountSQL)

    if (Count = 0)
    {
        ;ExecuteSQL(DbHandle,"INSERT INTO '" TabelName "' (" Create_Col_of_Database ") VALUES ('" "Order" "', '" "Order" "','" "Order" "','" "Order" "','" "Order" "','" "Order" "','" "Order" "');")
    }
}

ExecuteSQL(DbHandle, SQL)
{
    global SQL3
    ErrMsg := Buffer(A_PtrSize)
    Result := DllCall(SQL3 "\sqlite3_exec", "Ptr", DbHandle, "AStr", SQL, "Ptr", 0, "Ptr", 0, "Ptr", ErrMsg, "Int")

    if (Result != 0) {
        ErrorMsg := StrGet(NumGet(ErrMsg, "Ptr"), "UTF-8")
        MsgBox("SQL Error: " . ErrorMsg ,'SQL' , 0x40040)
        DllCall(SQL3 "\sqlite3_free", "Ptr", NumGet(ErrMsg, "Ptr"))
        return false
    }
    return true
}

GetSingleValue(DbHandle, SQL) {
    global SQL3
    StmtHandle := Buffer(A_PtrSize)
    Result := DllCall(SQL3 "\sqlite3_prepare_v2", "Ptr", DbHandle, "AStr", SQL, "Int", -1, "Ptr", StmtHandle, "Ptr", 0, "Int")

    if (Result != 0)
        return ""

    StmtHandle := NumGet(StmtHandle, "Ptr")
    Value := ""

    if (DllCall(SQL3 "\sqlite3_step", "Ptr", StmtHandle, "Int") = 100)
        Value := StrGet(DllCall(SQL3 "\sqlite3_column_text", "Ptr", StmtHandle, "Int", 0, "Ptr"), "UTF-8")

    DllCall(SQL3 "\sqlite3_finalize", "Ptr", StmtHandle)
    return Value
}



DataofTableforCustomar(TableName, StatusofRecord := "Active", SearchText := "") {
    global SQL3, DbHandle
    
    ;--------------------------- 
    ; SQL query build
    ;---------------------------
    ; Build LIKE clause based on SearchText
    if (SearchText = "") {
        likeClause := ""
    } else {
        likeClause := " AND CustomerName LIKE '%" SearchText "%'"
    }
    
    ; Complete SQL query
    SelectSQL := "SELECT DISTINCT CustomerName FROM " TableName 
                . " WHERE Status = '" StatusofRecord "'" 
                . likeClause ";"
    
    ;--------------------------- 
    ; Prepare statement
    ;---------------------------
    stmtBuf := Buffer(A_PtrSize)
    Result := DllCall(
        SQL3 "\sqlite3_prepare_v2",
        "Ptr", DbHandle,
        "AStr", SelectSQL,
        "Int", -1,
        "Ptr", stmtBuf,
        "Ptr", 0,
        "Int"
    )
    
    if (Result != 0) {
        errMsg := StrGet(DllCall(SQL3 "\sqlite3_errmsg", "Ptr", DbHandle, "Ptr"))
        MsgBox "Error preparing query:`n" errMsg "`n`nSQL:`n" SelectSQL, "SQLite", 0x40040
        return [] ; empty array
    }
    
    StmtHandle := NumGet(stmtBuf, 0, "Ptr")
    
    ;--------------------------- 
    ; Read rows (only CustomerName column)
    ;---------------------------
    Rows := []
    
    ; 100 = SQLITE_ROW
    while (DllCall(SQL3 "\sqlite3_step", "Ptr", StmtHandle, "Int") = 100) {
        namePtr := DllCall(SQL3 "\sqlite3_column_text", "Ptr", StmtHandle, "Int", 0, "Ptr")
        Rows.Push(StrGet(namePtr, "UTF-8"))
    }
    
    ;--------------------------- 
    ; Cleanup
    ;---------------------------
    DllCall(SQL3 "\sqlite3_finalize", "Ptr", StmtHandle)
    
    return Rows
}