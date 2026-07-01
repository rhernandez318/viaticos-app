; ════════════════════════════════════════════════════════════════════
;   Custom NSIS script para wizard de configuración inicial
;   Pide al usuario URL del servidor Supabase y guarda en config
; ════════════════════════════════════════════════════════════════════

!include "MUI2.nsh"
!include "nsDialogs.nsh"

Var SupabaseUrl
Var SupabaseUrlInput
Var SupabaseKey
Var SupabaseKeyInput
Var ConfigDialog

!macro customWelcomePage
  !insertmacro MUI_PAGE_WELCOME
!macroend

; Página personalizada: configuración de conexión a Supabase
Function PageConfigSupabase
  !insertmacro MUI_HEADER_TEXT "Configuración del servidor" "Indica dónde está el servidor de Viáticos"

  nsDialogs::Create 1018
  Pop $ConfigDialog

  ${If} $ConfigDialog == error
    Abort
  ${EndIf}

  ${NSD_CreateLabel} 0 0 100% 24u "URL del servidor Supabase:"
  Pop $0

  ${NSD_CreateText} 0 26u 100% 14u "https://tu-proyecto.supabase.co"
  Pop $SupabaseUrlInput

  ${NSD_CreateLabel} 0 50u 100% 24u "Clave anónima (anon key):"
  Pop $0

  ${NSD_CreateText} 0 76u 100% 14u "eyJ..."
  Pop $SupabaseKeyInput

  ${NSD_CreateLabel} 0 100u 100% 36u "Puedes obtener estos valores desde tu panel de Supabase → Settings → API. Tu administrador de IT debe proporcionártelos."
  Pop $0

  nsDialogs::Show
FunctionEnd

Function PageConfigSupabaseLeave
  ${NSD_GetText} $SupabaseUrlInput $SupabaseUrl
  ${NSD_GetText} $SupabaseKeyInput $SupabaseKey

  ; Validar que se haya ingresado algo
  ${If} $SupabaseUrl == ""
    MessageBox MB_ICONEXCLAMATION "Debes ingresar la URL del servidor"
    Abort
  ${EndIf}

  ; Guardar en archivo .env del usuario
  FileOpen $0 "$APPDATA\Viaticos\.env" w
  FileWrite $0 "NEXT_PUBLIC_SUPABASE_URL=$SupabaseUrl$\r$\n"
  FileWrite $0 "NEXT_PUBLIC_SUPABASE_ANON_KEY=$SupabaseKey$\r$\n"
  FileClose $0
FunctionEnd

; Crear carpeta de configuración al instalar
!macro customInstall
  CreateDirectory "$APPDATA\Viaticos"
!macroend

