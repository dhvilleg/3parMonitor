#!/bin/sh
#
#  Script %name:        3parMonitor.sh%
#  %version:            1 %
#  Description:
# =========================================================================================================
#  %created_by:         Diego Villegas %
#  %date_created:       Thu Apr 20 14:22:02 SAT 2017 %
# =========================================================================================================
# change log
# =========================================================================================================
# Mod.ID         Who                            When                                    Description
# =================================================================================================== ======
# 1             dhvilleg                        Thu, Apr 5, 2018 11:23:42 AM    Se grega funciones para
#                                                                               disponibilidad y capacidad
# USO
# =================================================================================================== ======
# Script que saca estadisticas/monitora elementos de storages 3par:
#				eval_checkhealth - Chequea el estado de salud del almacenamiento editar el archivo de 
#									configuracion monitor.conf con formato(ver catalogo errores 3par): 
#									id_unico:checkhealth:Componente:DetalleError:ErrorLevel
#									id1:checkhealth:Node:Expired Batteries:medium
#				eval_shownode - Mira errores de nodo
#				eval_statpd   - Estadisticas de uso de physicalDisk
#				eval_freespace- Chequea el espacio libre por tipo de disco
#								ver archivo de configuracion diskspace.conf
#								IdentificadorStorage:WarningLevel:TipoDisco:VelocidadDisco
#								3PAR_ECBPSTG01:85:NL
#								3PAR_ECBPSTG01:85:FC:10
#								3PAR_ECBPSTG01:85:FC:15
#				eval_availability - Reporte de estado Storage
#
# El archivo de configuración conection.conf tiene los siguientes parametros
# 	IdentificadorUnicoStg:usuarioConecion:dirIP:IOP_HihLevelxDisk:MonitoreadoSI/NO:SERIAL_NUMBER:CLIENT_NAME_OR_COMPANY:Environment:model
# 	3PAR_ECBPSTG01:usuario:10.151.16.142:200:NO:SERIAL_NUMBER:CLIENT_NAME_OR_COMPANY:PRODUCCION_TEST:10400
# 	3PAR_ECBPSTG02:usuario:10.32.116.142:200:SI:SERIAL_NUMBER:CLIENT_NAME_OR_COMPANY:CONTINGENCIA:10800
# 	3PAR_ECBPSTG03:usuario:10.151.16.152:200:NO:SERIAL_NUMBER:CLIENT_NAME_OR_COMPANY:PRODUCCION:10800
# 
# *usuario - debe compartir llaves con el cli de 3par
#                                                                               
# =========================================================================================================
#Definicion de variables.
HOME="/opt/OV/3parmonitor"
HOSTNAME=`uname -n`
OSTYPE=`uname -s`
CONECT_FILE="$HOME/etc/conection.conf"
CONFFILE="$HOME/etc/monitor.conf"
DISKFILE="$HOME/etc/diskspace.conf"
INITFILE="$HOME/etc/initiators.conf"
LOGDIR="$HOME/log"
LOGFILETEM="$LOGDIR/temporal_$1.log"
REPORTFILETEM="/opt/OV/reportes/temporalSTG.log"
REPORTFILEDIR="/opt/OV/reportes/"
LOGFILE="$LOGDIR/output.log"

#funcion para evaluar la salida del check
eval_checkhealth () {
        STORAGE="$1"
        USER="$2"
        TARGET=`cat $CONFFILE| grep "checkhealth"|awk -F: '{print $1}'`
        ssh $USER@$STORAGE checkhealth -svc -detail > $LOGFILETEM
        for e in `echo $TARGET`;
        do
                ERRSTING=`cat $CONFFILE| grep $e |awk -F: '{print $4}'`
                cat $LOGFILETEM |grep -i "$ERRSTING" > /dev/null
                if [ $? -eq  0 ]
                then
                        COMPONENT=`cat $CONFFILE| grep "$e"|awk -F: '{print $3}'`
                        SEVERITY=`cat $CONFFILE| grep "$e"|awk -F: '{print $5}'`
                        echo `date "+%d-%m-%Y"`","`date +%H:%M:%S"`",$STORAGE,$COMPONENT,$ERRSTING,$SEVERITY,checkhealth">>$LOGDIR/output.log
                fi
        done

}

#funcion para evaluar alertas de componentes degradados
eval_showalert () {
        STORAGE="$1"
        USER="$2"
        ssh $USER@$STORAGE showalert -n -oneline -wide > $LOGFILETEM
        TARGET=`cat $LOGFILETEM |grep -i Degraded| awk '{print $1}'`
        echo $TARGET
        for e in `echo $TARGET`;
        do
                ERRSTING=`cat $LOGFILETEM |grep -i $e |awk -F "     " '{print $e}'`
                if [ $? -eq  0 ]
                then
                        COMPONENT="Alert"
                        SEVERITY="High"
                        echo `date "+%d-%m-%Y"`","`date +%H:%M:%S"`",$STORAGE,$COMPONENT,$ERRSTING,$SEVERITY,showalert">>$LOGDIR/output.log
                fi
        done
}

eval_shownode () {
        STORAGE="$1"
        USER="$2"
        ssh $USER@$STORAGE shownode -s > $LOGFILETEM
        TARGET=`cat $LOGFILETEM |grep -v "Detailed_State" |grep -v OK | awk '{print $1}'`
        for e in `echo $TARGET`;
        do
                ERRSTING=`cat $LOGFILETEM |grep -i $e |awk '{print "Node state: "$2" - detail: ",$3}'`
                if [ $? -eq  0 ]
                then
                        COMPONENT="NODE $e"
                        SEVERITY="High"
                        echo `date "+%d-%m-%Y"`","`date +%H:%M:%S"`",$STORAGE,$COMPONENT,$ERRSTING,$SEVERITY,shownode">>$LOGDIR/output.log
                fi
        done
}

eval_showrcopy () {
        STORAGE="$1"
        USER="$2"
        ssh $USER@$STORAGE showrcopy > $LOGFILETEM
        TARGET=`cat $LOGFILETEM |grep -i failsafe | awk '{print $1}'`
        for e in `echo $TARGET`;
        do
                ERRSTING=`cat $LOGFILETEM |grep -i $e |awk '{print "Virtual Remote Volume "$1,"state detail ",$3}'`
                if [ $? -eq  0 ]
                then
                        COMPONENT="RCOPY"
                        SEVERITY="High"
                        echo `date "+%d-%m-%Y"`","`date +%H:%M:%S"`",$STORAGE,$COMPONENT,$ERRSTING,$SEVERITY,showrcopy">>$LOGDIR/output.log
                fi
        done
}

eval_statpd () {
        STORAGE="$1"
        USER="$2"
        CONTADOR=0
        AVGDISK="$3"
        ssh $USER@$STORAGE statpd -iter 1 -p -devtype FC > $LOGFILETEM
        TARGET=`cat $LOGFILETEM |sed '/^$/d' | sed '/-/d' | sed '$d' | grep -v "I/O per second" |grep -v "Cur     Avg  Max" |grep -v Max |awk '{print $5}'`
        for e in `echo $TARGET`;
        do
                if [ $e -gt  200 ]
                then
                        let CONTADOR=CONTADOR+1
                fi
        done
                if [ $CONTADOR -gt  $AVGDISK ]
                        then
                        COMPONENT="DISK"
                        SEVERITY="High"
                        echo `date "+%d-%m-%Y"`","`date +%H:%M:%S"`",$STORAGE,$COMPONENT,"Disk experiencing a high level of I/O per second $CONTADOR",$SEVERITY,statpd">>$LOGDIR/output.log
                fi


}


eval_statvv () {
        STORAGE="$1"
        USER="$2"
        CONTADOR=0
        AVGDISK=$3
        ssh $USER@$STORAGE statvv -iter 1 > $LOGFILETEM
        TARGET=`cat $LOGFILETEM |sed '/^$/d' | sed '/-/d' | sed '$d' | grep -v "I/O per second" |grep -v "Cur     Avg  Max" |grep -v "rcpy" | grep -v Cur| awk '{print $10}'`
        for e in `echo $TARGET`;
        do
                if [ $e -gt 20 ]
                then
                        let CONTADOR=CONTADOR+1
                fi
        done
                if [ $CONTADOR -gt  $AVGDISK ]
                then
                        COMPONENT="LUN"
                        SEVERITY="High"
                        echo `date "+%d-%m-%Y"`","`date +%H:%M:%S"`",$STORAGE,$COMPONENT,"LUNs experiencing a high level of service time $CONTADOR",$SEVERITY,statvv">>$LOGDIR/output.log
                fi


}

eval_freespace () {
        STORAGE="$1"
        USER="$2"
        CONTADOR=0
        for i in `cat $DISKFILE| grep $STORAGE`;
        do
            UMBRAL=`echo $i |awk -F: '{print $2}'`
            DISKTYPE=`echo $i|awk -F: '{print $3}'`
            ssh $USER@$STORAGE showpd -p -devtype $DISKTYPE > $LOGFILETEM
            TOTAL=`cat $LOGFILETEM | grep total |sed '/^$/d' |awk '{print $3}'`
            USED=`cat $LOGFILETEM | grep total |sed '/^$/d' |awk '{print $4}'`
            AUX=`echo "$USED*100" | bc `
            AUX2=`echo "scale=3; $AUX/$TOTAL" | bc`
            PORCENTAJE=`echo "100-$AUX2" | bc `
            if [ $PORCENTAJE -gt  $UMBRAL ]
                    then
                    COMPONENT="DISK"
                    SEVERITY="High"
                    echo `date "+%d-%m-%Y"`","`date +%H:%M:%S"`",$STORAGE,$COMPONENT,"Se ha sobrepasado el umbral del $UMBRAL de uso del tipo de disco $DISKTYPE total $PORCENTAJE",$SEVERITY,showpd">>$LOGDIR/output.log
            fi
        done
}

eval_initiators () {
        STORAGE="$1"
        USER="$2"
        CONTADOR=0
        UMBRAL=70
		PORT=`cat $INITFILE |grep $STORAGE | awk '{print $2}'`
        ssh $USER@$STORAGE showhost > $LOGFILETEM
                for e in `echo $PORT`;
        do
            CONTADOR=`cat $LOGFILETEM | grep $e | wc -l`
            if [ $CONTADOR -gt  $UMBRAL ]
            then
                COMPONENT="PORT"
                SEVERITY="High"
                echo `date "+%d-%m-%Y"`","`date +%H:%M:%S"`",$STORAGE,$COMPONENT,"ATENCION se ha sobrepasado el umbral de $UMBRAL del numero de iniciatores en el puerto $e total $CONTADOR",$SEVERITY,showhost">>$LOGDIR/output.log
            fi
        done
}

eval_availability () {
        STORAGE="$1"
        USER="$2"
        CONTADOR=0
        DATE=`date "+%d%m%Y"`
        SERIAL=`cat $CONECT_FILE | grep $STORAGE |awk -F: '{print $6}' `
        CLIENT=`cat $CONECT_FILE | grep $STORAGE |awk -F: '{print $7}' `
        AMBIENTE=`cat $CONECT_FILE | grep $STORAGE |awk -F: '{print $8}' `
        MODELO=`cat $CONECT_FILE | grep $STORAGE |awk -F: '{print $9}' `
        REPORTFILE="$REPORTFILEDIR/3par_$DATE.csv"
        if [ -e $REPORTFILE ]
        then
                echo "exist"
        else
                echo "FECHA;MODELO;NOMBRE;AMBIENTE;TIPO.DISCO;ESPACIO.TOTAL.GB;CAPACIDAD.USADA;CAPACIDAD.LIBRE">$REPORTFILE
        fi
        for i in `cat $DISKFILE| grep $STORAGE`;
        do
            UMBRAL=`echo $i |awk -F: '{print $2}'`
            DISKTYPE=`echo $i|awk -F: '{print $3}'`
            if [ $DISKTYPE =  "FC" ]
                then
                    DISKRPM=`echo $i|awk -F: '{print $4}'`
                    ssh $USER@$STORAGE showpd -space -p -devtype $DISKTYPE -rpm $DISKRPM > $REPORTFILETEM
                    TOTAL=`cat $REPORTFILETEM | grep total |sed '/^$/d' |awk '{print $3}'`
                    FREE=`cat $REPORTFILETEM | grep total |sed '/^$/d' |awk '{print $6}'`
                        echo $FREE
                        echo $TOTAL
                    USED=`echo "$TOTAL-$FREE" | bc `
                    echo "$DATE;$MODELO;$STORAGE;$AMBIENTE;$DISKTYPE $DISKRPM RPM;$TOTAL;$USED;$FREE">>$REPORTFILE
                else
                    ssh $USER@$STORAGE showpd -space -p -devtype $DISKTYPE > $REPORTFILETEM
                    TOTAL=`cat $REPORTFILETEM | grep total |sed '/^$/d' |awk '{print $3}'`
                    FREE=`cat $REPORTFILETEM | grep total |sed '/^$/d' |awk '{print $6}'`
                    USED=`echo "$TOTAL-$FREE" | bc `
                    echo "$DATE;$MODELO;$STORAGE;$AMBIENTE;$DISKTYPE;$TOTAL;$USED;$FREE">>$REPORTFILE
            fi
        done
}

case $1 in
        "checkhealth")
            CONECTION=`cat $CONECT_FILE| awk -F: '{print $1}'`
            for e in `echo $CONECTION`;
            do
                    STG=`cat $CONECT_FILE| grep $e |awk -F: '{print $1}'`
                    USER=`cat $CONECT_FILE| grep $e |awk -F: '{print $2}'`
                    AVGDISK=`cat $CONECT_FILE| grep $e |awk -F: '{print $4}'`
                eval_checkhealth $STG $USER
            done
            ;;
        "showalert")
            CONECTION=`cat $CONECT_FILE| awk -F: '{print $1}'`
            for e in `echo $CONECTION`;
            do
                        STG=`cat $CONECT_FILE| grep $e |awk -F: '{print $1}'`
                        USER=`cat $CONECT_FILE| grep $e |awk -F: '{print $2}'`
                        AVGDISK=`cat $CONECT_FILE| grep $e |awk -F: '{print $4}'`
                eval_showalert $STG $USER
            done
            ;;
        "shownode")
            CONECTION=`cat $CONECT_FILE| awk -F: '{print $1}'`
            for e in `echo $CONECTION`;
            do
                        STG=`cat $CONECT_FILE| grep $e |awk -F: '{print $1}'`
                        USER=`cat $CONECT_FILE| grep $e |awk -F: '{print $2}'`
                        AVGDISK=`cat $CONECT_FILE| grep $e |awk -F: '{print $4}'`
                eval_shownode $STG $USER
            done
            ;;
        "showrcopy")
            CONECTION=`cat $CONECT_FILE| awk -F: '{print $1}'`
            for e in `echo $CONECTION`;
            do
                        STG=`cat $CONECT_FILE| grep $e |awk -F: '{print $1}'`
                        USER=`cat $CONECT_FILE| grep $e |awk -F: '{print $2}'`
                        AVGDISK=`cat $CONECT_FILE| grep $e |awk -F: '{print $4}'`
                        RCENAB=`cat $CONECT_FILE| grep $e |awk -F: '{print $5}'`
                        if [ "$RCENAB" != "NO" ]
                        then
                              eval_showrcopy $STG $USER
                        fi

            done
            ;;
        "statpd")
            CONECTION=`cat $CONECT_FILE| awk -F: '{print $1}'`
            for e in `echo $CONECTION`;
            do
                        STG=`cat $CONECT_FILE| grep $e |awk -F: '{print $1}'`
                        USER=`cat $CONECT_FILE| grep $e |awk -F: '{print $2}'`
                        AVGDISK=`cat $CONECT_FILE| grep $e |awk -F: '{print $4}'`
                eval_statpd $STG $USER $AVGDISK
            done
            ;;
        "statvv")
            CONECTION=`cat $CONECT_FILE| awk -F: '{print $1}'`
            for e in `echo $CONECTION`;
            do
                        STG=`cat $CONECT_FILE| grep $e |awk -F: '{print $1}'`
                        USER=`cat $CONECT_FILE| grep $e |awk -F: '{print $2}'`
                        AVGDISK=`cat $CONECT_FILE| grep $e |awk -F: '{print $4}'`
                eval_statvv $STG $USER $AVGDISK
            done
            ;;
        "freespace")
            CONECTION=`cat $CONECT_FILE| awk -F: '{print $1}'`
            for e in `echo $CONECTION`;
            do
                STG=`cat $CONECT_FILE| grep $e |awk -F: '{print $1}'`
                USER=`cat $CONECT_FILE| grep $e |awk -F: '{print $2}'`
                eval_freespace $STG $USER
            done
            ;;
        "availability")
            CONECTION=`cat $CONECT_FILE| awk -F: '{print $1}'`
            for e in `echo $CONECTION`;
            do
                STG=`cat $CONECT_FILE| grep $e |awk -F: '{print $1}'`
                USER=`cat $CONECT_FILE| grep $e |awk -F: '{print $2}'`
                eval_availability $STG $USER
            done
            ;;

        *) echo invalid option;;
esac
