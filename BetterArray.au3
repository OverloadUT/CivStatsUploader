;===============================================================================
;
; Function Name:  _BetterArrayDisplay()
; Description:    Displays an array of any dimensions in a message box.
; Author(s):      Greg Laabs <gl-autoit at apartment167 dot com>
;
;===============================================================================
Func _BetterArrayDisplay(Const ByRef $avArray, $sTitle = "Array")
	Local $iCounter = 0, $sMsg = ""
	
	If (Not IsArray($avArray)) Then
		SetError(1)
		Return 0
	EndIf
	
	$sMsg = _BetterArrayDisplayFormat(0, $avArray)
	
	MsgBox(4096, $sTitle, $sMsg)
	SetError(0)
	Return 1
EndFunc   ;==>_BetterArrayDisplay

;===============================================================================
;
; Function Name:  _BetterArrayConsoleDump()
; Description:    Displays an array of any dimensions in the console.
; Author(s):      Greg Laabs <gl-autoit at apartment167 dot com>
;
;===============================================================================
Func _BetterArrayConsoleDump(Const ByRef $avArray, $sTitle = "Array Dump")
	Local $iCounter = 0, $sMsg = ""
	
	If (Not IsArray($avArray)) Then
		SetError(1)
		Return 0
	EndIf
	
	$sMsg = _BetterArrayDisplayFormat(0, $avArray)
	
	ConsoleWrite($sTitle & @CRLF)
	ConsoleWrite($sMsg)
	SetError(0)
	Return 1
EndFunc   ;==>_BetterArrayConsoleDump

;===============================================================================
;
; Function Name:  _BetterArrayDisplayFormat()
; Description:    Formats the string displayed in _BetterArrayConsoleDump and
;                 _BetterArrayDisplay()
; Author(s):      Greg Laabs <gl-autoit at apartment167 dot com>
;
;===============================================================================
Func _BetterArrayDisplayFormat($deep, Const ByRef $avArray)
	Local $iCounter = 0, $jCounter = 0, $kCounter, $lCounter, $sCounter
	Local $sMsg = ""
	
	$sMsg &= UBound($avArray, 0) & " Dimensional Array" & @CRLF
	
	If UBound($avArray, 0) > 1 Then
		;FIRST DIMENSION (I) RECURSIVE
		For $iCounter = 0 To UBound($avArray) - 1
			For $sCounter = 1 To $deep
				If $sCounter = $deep + 1 Then
					$sMsg &= " |--"
				ElseIf $sCounter > $deep + 1 Then
					$sMsg &= "-+--"
				Else
					$sMsg &= "    "
				EndIf
			Next
			$sMsg &= "[" & $iCounter & "]" & @CR
			If UBound($avArray, 0) > 2 Then
				; SECOND DIMENSION (J) RECURSIVE
				For $jCounter = 0 To UBound($avArray, 2) - 1
					For $sCounter = 1 To $deep + 1
						If $sCounter = $deep + 1 Then
							$sMsg &= " |--"
						ElseIf $sCounter > $deep + 1 Then
							$sMsg &= "-+--"
						Else
							$sMsg &= "    "
						EndIf
					Next
					$sMsg &= "[" & $jCounter & "]" & @CR
					If UBound($avArray, 0) > 3 Then
						; THIRD DIMENSION (K) RECURSIVE
						For $kCounter = 0 To UBound($avArray, 2) - 1
							For $sCounter = 1 To $deep + 2
								If $sCounter = $deep + 1 Then
									$sMsg &= " |--"
								ElseIf $sCounter > $deep + 1 Then
									$sMsg &= "-+--"
								Else
									$sMsg &= "    "
								EndIf
							Next
							$sMsg &= "[" & $kCounter & "]" & @CR
							If UBound($avArray, 0) > 4 Then
								; FOURTH DIMENSION (L) RECURSIVE
								SetError(1)
								Return "Cannot display arrays deeper than 3 dimensions"
							Else
								; FOURTH DIMENSION (L) DISPLAY
								For $lCounter = 0 To UBound($avArray, 4) - 1
									For $sCounter = 1 To $deep + 3
										If $sCounter = $deep + 1 Then
											$sMsg &= " |--"
										ElseIf $sCounter > $deep + 1 Then
											$sMsg &= "-+--"
										Else
											$sMsg &= "    "
										EndIf
									Next
									$sMsg &= "[" & $lCounter & "]  = "
									If IsArray($avArray[$iCounter][$jCounter][$kCounter][$lCounter]) Then
										$sMsg &= _BetterArrayDisplayFormat($deep + 5, $avArray[$iCounter][$jCounter][$kCounter][$lCounter])
									Else
										$sMsg &= $avArray[$iCounter][$jCounter][$kCounter][$lCounter] & @CR
									EndIf
								Next
							EndIf
						Next
					Else
						; THIRD DIMENSION (K) DISPLAY
						For $kCounter = 0 To UBound($avArray, 3) - 1
							For $sCounter = 1 To $deep + 2
								If $sCounter = $deep + 1 Then
									$sMsg &= " |--"
								ElseIf $sCounter > $deep + 1 Then
									$sMsg &= "-+--"
								Else
									$sMsg &= "    "
								EndIf
							Next
							$sMsg &= "[" & $kCounter & "]  = "
							If IsArray($avArray[$iCounter][$jCounter][$kCounter]) Then
								$sMsg &= _BetterArrayDisplayFormat($deep + 4, $avArray[$iCounter][$jCounter][$kCounter])
							Else
								$sMsg &= $avArray[$iCounter][$jCounter][$kCounter] & @CR
							EndIf
						Next
					EndIf
				Next
			Else
				; SECOND DIMENSION (J) DISPLAY
				For $jCounter = 0 To UBound($avArray, 2) - 1
					For $sCounter = 1 To $deep + 1
						If $sCounter = $deep + 1 Then
							$sMsg &= " |--"
						ElseIf $sCounter > $deep + 1 Then
							$sMsg &= "-+--"
						Else
							$sMsg &= "    "
						EndIf
					Next
					$sMsg &= "[" & $jCounter & "]  = "
					If IsArray($avArray[$iCounter][$jCounter]) Then
						$sMsg &= _BetterArrayDisplayFormat($deep + 3, $avArray[$iCounter][$jCounter])
					Else
						$sMsg &= $avArray[$iCounter][$jCounter] & @CR
					EndIf
				Next
			EndIf
		Next
	Else
		; FIRST DIMENSION (I) DISPLAY
		For $iCounter = 0 To UBound($avArray) - 1
			For $sCounter = 1 To $deep
				If $sCounter = $deep + 1 Then
					$sMsg &= " |--"
				ElseIf $sCounter > $deep + 1 Then
					$sMsg &= "-+--"
				Else
					$sMsg &= "    "
				EndIf
			Next
			$sMsg &= "[" & $iCounter & "]  = "
			If IsArray($avArray[$iCounter]) Then
				$sMsg &= _BetterArrayDisplayFormat($deep + 2, $avArray[$iCounter])
			Else
				$sMsg &= $avArray[$iCounter] & @CR
			EndIf
		Next
	EndIf
	Return $sMsg
EndFunc   ;==>_BetterArrayDisplayFormat