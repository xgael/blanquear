-- Ventana de progreso de la Acción Rápida (barra nativa de los applets de AppleScript, con botón Detener).
-- blanquear-finder escribe en ~/Library/Caches/blanquear-progreso una línea «hechos<TAB>total<TAB>pid<TAB>archivo»
-- y «fin» al terminar. Detener mata la corrida y deja la marca «.cancelado» para que el aviso final lo diga.
on run
	set est to (POSIX path of (path to library folder from user domain)) & "Caches/blanquear-progreso"
	set progress description to "Blanqueando…"
	set progress additional description to "Contando archivos…"
	set pid to ""
	try
		repeat
			set s to ""
			try
				set s to do shell script "cat " & quoted form of est
			end try
			if s starts with "fin" then exit repeat
			set AppleScript's text item delimiters to tab
			set partes to text items of s
			set AppleScript's text item delimiters to ""
			if (count of partes) ≥ 4 then
				set hechos to (item 1 of partes) as integer
				set total to (item 2 of partes) as integer
				set pid to item 3 of partes
				set pct to 0
				if total > 0 then set pct to round (hechos * 100 / total) rounding down
				set progress total steps to total
				set progress completed steps to hechos
				set progress description to "Blanqueando… " & pct & " %"
				set progress additional description to (hechos as text) & " de " & total & " archivos · " & (item 4 of partes)
			end if
			delay 0.3
		end repeat
	on error number -128
		-- Detener: la corrida y sus procesos hijos (fontTools, exiftool…)
		if pid is not "" then do shell script "touch " & quoted form of (est & ".cancelado") & "; pkill -P " & pid & "; kill " & pid & " 2>/dev/null; true"
	end try
end run
