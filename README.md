# Windows Installation Script

Este script automatiza la instalación y configuración de mi dotfiles.
Siga las instrucciones a continuación para ejecutarlo correctamente.

## Requisitos

- Windows PowerShell 5.1+
- Permisos de administrador

## Instrucciones de uso

1. **Abrir PowerShell como administrador:**
   - Presione `Win + S`, busque "PowerShell".
   - Haga clic derecho sobre "Windows PowerShell" y seleccione "Ejecutar como administrador".

2. **Ejecutar el comando:**

   Copie y pegue el siguiente comando en la ventana de PowerShell y presione `Enter`:

   ```powershell
   Invoke-Expression (Invoke-RestMethod -Uri "https://raw.githubusercontent.com/overnight10/dotfiles/windows/install.ps1");
   ```

3. **Seguir las instrucciones del script:**
   - El script descargará y aplicará configuraciones en su sistema.
   - Asegúrese de seguir cualquier indicación que aparezca durante el proceso.

## Notas importantes

- Si la carpeta dotfiles está en uso, ciérrela.
- Este script realiza cambios en el sistema. Asegúrese de revisarlo antes de ejecutarlo si desea comprender los cambios que realiza.
- Ejecute el script únicamente desde fuentes confiables.
- Si encuentra algún problema, revise los permisos de administrador o consulte los registros generados por el script.

---

¡Gracias por usar este script!
