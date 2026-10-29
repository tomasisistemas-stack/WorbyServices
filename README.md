# WorbyServices

Solucao Delphi para gerenciar os executaveis Worby/Orbi.

## Projetos

- `WorbyServicesLib.dll`: biblioteca compartilhada com toda a logica.
- `WorbyService.exe`: servico do Windows, com inicio automatico.
- `WorbyServicesUI.exe`: interface FireMonkey para iniciar, parar e reiniciar.

## Compilacao

Abra `WorbyServices.groupproj` no Delphi e compile os tres projetos. Para instalar
no servidor, copie os arquivos abaixo para uma unica pasta, por exemplo
`C:\WorbyService`:

- `WorbyService.exe`
- `WorbyServicesLib.dll`
- `WorbyServicesUI.exe`
- `WorbyServices.ini`
- `InstalarServico.cmd`
- `RemoverServico.cmd`

O EXE do servico, a DLL e o INI devem permanecer na mesma pasta.

## Instalacao

Abra o Prompt de Comando como Administrador na pasta dos binarios e execute:

    WorbyService.exe /install
    net start WorbyServices

Para remover:

    WorbyService.exe /uninstall

Os executaveis iniciados por um servico rodam na sessao 0 do Windows e, por
seguranca, nao exibem interface no desktop do usuario.
