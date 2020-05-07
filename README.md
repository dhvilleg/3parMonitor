Script que saca estadisticas/monitora elementos de storages 3par:
**eval_checkhealth** - Chequea el estado de salud del almacenamiento editar el archivo de  configuracion monitor.conf con formato(ver catalogo errores 3par): 

 - id_unico:checkhealth:Componente:DetalleError:ErrorLevel
	 - id1:checkhealth:Node:Expired Batteries:medium
	- eval_shownode - Mira errores de nodo
	- eval_statpd   - Estadisticas de uso de physicalDisk
	- eval_freespace- Chequea el espacio libre por tipo de disco ver archivo de configuracion diskspace.conf
- IdentificadorStorage:WarningLevel:TipoDisco:VelocidadDisco
	- 3PAR_ECBPSTG01:85:NL
	- 3PAR_ECBPSTG01:85:FC:10
	- 3PAR_ECBPSTG01:85:FC:15
- eval_availability - Reporte de estado Storage

El archivo de configuración conection.conf tiene los siguientes parámetros

 - IdentificadorUnicoStg:usuarioConecion:dirIP:IOP_HihLevelxDisk:MonitoreadoSI/NO:SERIAL_NUMBER:CLIENT_NAME_OR_COMPANY:Environment:model
	- 3PAR_ECBPSTG01:usuario:10.151.16.142:200:NO:SERIAL_NUMBER:CLIENT_NAME_OR_COMPANY:PRODUCCION_TEST:10400
	- 3PAR_ECBPSTG02:usuario:10.32.116.142:200:SI:SERIAL_NUMBER:CLIENT_NAME_OR_COMPANY:CONTINGENCIA:10800
	- 3PAR_ECBPSTG03:usuario:10.151.16.152:200:NO:SERIAL_NUMBER:CLIENT_NAME_OR_COMPANY:PRODUCCION:10800

*usuario - debe compartir llaves con el cli de 3par


> Written with [StackEdit](https://stackedit.io/).
