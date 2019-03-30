#!/bin/bash
#############################################################
# Author : Suman Adhikari                                  ##
# Company : 		                                   ##
# Description : 					   ##
# 							   ##
# This script is developed for flashback of database to    ##
# specific restore point				   ##
#############################################################

##
## Fundamental Env's
##
ORACLE_HOME="/u01/app/oracle/product/11.2.0/db_home1"
ORACLE_SID=""
LOG_BASE_DIR="/archive/logs"
FB_USER=`whoami`
FB_LOG_FILE=${LOG_BASE_DIR}/alertFB.log
FB_START_TIME=`date -d now`
FB_END_TIME=""
DATE_TIME=`date -d now`
FB_RESTORE_POINT=""
FB_RESTORE_POINT_TMP=""
DBNAME=""
IGNORE_VALIDATION=""

##
## Env for locating full path of the script being executed
##
#CURSCRIPT=`realpath $0`
CURSCRIPT=`readlink -f $0`

##
## For Warning and Text manupulation
##
bold=$(tput bold)
reset=$(tput sgr0)
bell=$(tput bel)
underline=$(tput smul)

#############################################################
# Functions to handle exceptions and erros                  #
#############################################################

###
### Handling error while running script
###
### B : for both logfile and standard output
### L : for only standard output
###
### $1 : Error Code
### $2 : Error message in detail
###

ReportError(){
if [ "${3}" = "B" ]
   then
       echo "" >> ${FB_LOG_FILE}
       echo ""
       echo "+-------------------------------------------------------+" >> ${FB_LOG_FILE}
       echo "+-------------------------------------------------------+" 
       echo -e "==> Error during Running Script :\n===> $CURSCRIPT" >> ${FB_LOG_FILE}
       echo -e "==> Error during Running Script :\n===> $CURSCRIPT" 
       echo -e "====> $1: $2" >> ${FB_LOG_FILE}
       echo -e "====> $1: $2" 
       echo "+-------------------------------------------------------+" >> ${FB_LOG_FILE}
       echo "+-------------------------------------------------------+" 
   exit 1

elif [ "${3}" = "L" ]
   then
       echo "+-------------------------------------------------------+" >> ${FB_LOG_FILE}
       echo -e "==> Error during Running Script :\n===> $CURSCRIPT" >> ${FB_LOG_FILE}
       echo -e "====> $1: $2" >> ${FB_LOG_FILE}
       echo "+-------------------------------------------------------+" >> ${FB_LOG_FILE}
   exit 1;

else
      echo "+--------------------------------------------------------+"
      echo -e "==> Error during Running Script :\n===> $CURSCRIPT"
      echo -e "====> $1: $2"
      echo "+--------------------------------------------------------+"
   exit 1;
fi
}

###
### Dispalying information based on input of user 
### OR
### Status of script while running.
###
### B : for both logfile and standard output
### L : for only standard output
###


ReportInfo(){
if [ "${2}" = "B" ]
   then
      echo "" >> ${FB_LOG_FILE}
      echo "+-------------------------------------------------------+" >> ${FB_LOG_FILE}
      echo "+-------------------------------------------------------+" 
      echo -e "==> Information by the script :\n===> $CURSCRIPT" >> ${FB_LOG_FILE}
      echo -e "==> Information by the script :\n===> $CURSCRIPT"
      echo -e "====> INFO : $1 " >> ${FB_LOG_FILE}
      echo -e "====> INFO : $1 " 
      echo "+-------------------------------------------------------+" >> ${FB_LOG_FILE}
      echo "+-------------------------------------------------------+" 
      #echo "" >> ${FB_LOG_FILE}

elif [ "${2}" = "L" ]
   then
      echo "" >> ${FB_LOG_FILE}
      echo "+-------------------------------------------------------+" >> ${FB_LOG_FILE}
      echo -e "==> Information by the script :\n===> $CURSCRIPT" >> ${FB_LOG_FILE}
      echo -e "====> INFO : $1 " >> ${FB_LOG_FILE}
      echo "+-------------------------------------------------------+" >> ${FB_LOG_FILE}
      echo "" >> ${FB_LOG_FILE}
else 
     echo "+--------------------------------------------------------+"
     echo -e "==> Information by the script :\n===> $CURSCRIPT"
     echo -e "====> INFO : $1 "
     echo "+--------------------------------------------------------+"
fi
}

###
### Function to update date and time
###
FunUpdateDateTime(){
  FB_START_TIME=`date -d now`
}

###
### FUNCTION TO CHECK FUNDAMENTAL VARIABLES
###
CheckVars(){
if [ "${1}" = "" ]
   then
      ReportError  "RERR-101" "LOG_BASE_DIR ENV error:\n=====> Environmental variable not Set. Aborting....\n======> Please select/provide valid LOG_BASE_DIR"
elif [ ! -d ${1} ]
   then
      ReportError "RERR-102" "Directory \"${bell}${bold}${underline}${1}${reset}\" not found\n=====> LOG_BASE_DIR Env invalid. Aborting...."
elif [ "${2}" = "" ]
   then
      ReportError "RERR-103" "ORACLE_HOME ENV error:\n=====> Environmental variable not Set. Aborting....\n======> Please select/provide valid ORACLE_HOME"
elif [ ! -d ${2} ]
   then
      ReportError "RERR-002" "Directory \"${bell}${bold}${underline}${1}${reset}\" not found or ORACLE_HOME Env invalid. Aborting...." 
elif [ ! -x ${2}/bin/sqlplus ]
   then
       ReportError  "RERR-003" "Executable \"${bell}${bold}${underline}${1}/bin/sqlplus${reset}\" not found; Aborting..."
elif [ "${3}" != "oracle" ]
   then
      ReportError  "RERR-004" "User "${bell}${bold}${underline}${2}${reset}" not valid for running script; Aborting..."
else
   return 0;
fi
}

###
### Function to check valid SID
###
checkSidValid(){
  param1=("${!1}")
  check=${2}  
  statusSID=0
  for i in ${param1[@]}
    do
     if [ ${i} == $2 ];
      then
	 statusSID=1
	 break
     esle
        echo $i; 
     fi 
  done
return $statusSID;
}

###
### Get Oracle SID env 
###
FunGetOraInstance(){
if [ "${ORACLE_SID}" = "" ]
   then
      printf 'Select Instance For Flashback : '
      read -r ORACLE_SID
else
   return 0;
fi
echo ""
myarr=($(ps -ef | grep ora_smon| grep -v grep | awk -F' ' '{print $NF}' | cut -c 10-))
checkSidValid myarr[@] ${ORACLE_SID}
if [ $? -eq 0 ]
   then
	ReportError  "RERR-001" "ORACLE_SID : ${bell}${bold}${underline}${ORACLE_SID}${reset}\n=====> ORACLE_SID Env is invalid\n======> No instance is running. Aborting...\n=======> Please select/provide valid ORACLE_SID"
else
   FB_LOG_FILE=${LOG_BASE_DIR}/diagFB${ORACLE_SID}.log 
   FunListOraInstance >> ${FB_LOG_FILE} 
fi

ReportInfo "Checking for validness for ORACLE_SID\n=====> Check passed..... for ${bold}${underline}${ORACLE_SID}${reset}\n======> Your session is logged in logfile:\n=======> ${FB_LOG_FILE}" "B"
}


###
### Start the database
###
FunStartDB(){
case ${2} in
    n|N )
	ReportInfo "${3}" "B"
        $1/bin/sqlplus -s /nolog <<EOF >> ${FB_LOG_FILE} 
        set pagesize 0 feedback off verify off echo off;
        connect / as sysdba
        startup nomount;
EOF
        ;;

        m|M )
	ReportInfo "${3}" "B"
        echo ""
        echo "==> Sarting DB instance in Mounted Mode.."
        echo ""
        echo "" >> ${FB_LOG_FILE}
        $1/bin/sqlplus -s /nolog <<EOF >> ${FB_LOG_FILE}
        set pagesize 0 feedback off verify off echo off;
        connect / as sysdba
        startup mount;
EOF
        echo "" >> ${FB_LOG_FILE}
        ;;

	o|O )
	ReportInfo "${3}" "B"
        echo ""
        echo "==> Starting DB instance in Read/Write Mode.."
        echo ""
        echo "" >> ${FB_LOG_FILE}
        $1/bin/sqlplus -s /nolog <<EOF >> ${FB_LOG_FILE}
        set pagesize 0 feedback off verify off echo off;
        connect / as sysdba
        startup;
EOF
        echo >> ${FB_LOG_FILE}
        ;;

        r|R )
	ReportInfo "${3}" "B" 
        $1/bin/sqlplus /nolog <<EOF >> ${FB_LOG_FILE}
        set pagesize 0 verify off echo off;
        connect / as sysdba
        startup mount;
	alter database open read only;
	select name, open_mode, database_role from v\$database;
EOF
        ;;

    * )
        ReportInfo "Startup of instance skipped......." "Y"
    ;;
esac
}


###
### Shutdown the instance
###
FunShutdownDB(){
case ${2} in
    I|i )
	ReportInfo "${3}" "B"
        echo ""
        echo "==> Shutting DB instance in immediate Mode.."
        echo ""
        echo "" >> ${FB_LOG_FILE}
        $1/bin/sqlplus -s /nolog <<EOF >> ${FB_LOG_FILE}
        set pagesize 0 feedback off verify off echo off;
        connect / as sysdba
        shutdown immediate;
EOF
        ;;

        A|a )
	ReportInfo "${3}" "B"
        $1/bin/sqlplus -s /nolog <<EOF
        set pagesize 0 feedback off verify off echo off;
        connect / as sysdba
        shutdown abort;
EOF
        ;;

    * )
        ReportInfo "${3}" "B"
    ;;
esac
}

###
### Fun to get Oracle Instance running on Box.
###
FunListOraInstance(){
echo "+-------------------------------------------------------+"
echo "| Starting Flashback Database ...............           |"
echo "+-------------------------------------------------------+"
echo ""
FunUpdateDateTime
echo "==> Flashback Start Time: ${FB_START_TIME}"
echo ""
echo "+-------------------------------------------------------+"
myarr=($(ps -ef | grep ora_smon | awk -F' ' '{print $NF}' | cut -c 10-))
echo "==> DB Instances running on box: ${bold}${underline}`hostname`${reset}"
for i in "${myarr[@]}"
  do :
   echo "===> "${bold}${underline}$i${reset} 
  done
echo "+-------------------------------------------------------+"
}

###
### Function to get Database Name
###
FunGetDBname(){
DBNAME=$($1/bin/sqlplus -s /nolog <<END
set pagesize 0 feedback off verify off echo off;
connect / as sysdba
select name from v\$database;
END
)
}

###
### Fun to get Restore point and time
###
FunListRestorePoint(){
FB_RESTORE_POINT_TMP=$($1/bin/sqlplus -s /nolog <<END
set pagesize 0 feedback off verify off echo off;
connect / as sysdba
select 'Time / RP Name : '||TO_CHAR(time, 'DD-MON-YYYY HH:MI:SS')||' / '||name from v\$restore_point;
END
)
ReportInfo "Restore Points For Database ${DBNAME}
=====> --------------------------------------------------\n${bold}${FB_RESTORE_POINT_TMP}${reset} " "B"
}

###
### Fun to check valid restore point
###
FunCheckFBRPValid(){
count=`echo "$FB_RESTORE_POINT_TMP" | grep -c "\b${FB_RESTORE_POINT}\b"`
return $count;
}


###
### Get Oracle SID env 
###
FunGetFBRestorePoint(){
if [ "${FB_RESTORE_POINT}" = "" ]
   then
      FunListRestorePoint ${1}
      echo "";
      printf 'Select Restore For Flashback : '
      read -r FB_RESTORE_POINT
      FunCheckFBRPValid ${FB_RESTORE_POINT_TMP} ${FB_RESTORE_POINT}
      if [ $? -eq 1 ]
       then
          echo ""
	  ReportInfo "Checking for validness for Restore Point ...\n=====> Check passed..... for ${bold}${underline}${FB_RESTORE_POINT}${reset} " "B"
      else
          ReportError  "RERR-005" "Restore Point : ${bell}${bold}${underline}${FB_RESTORE_POINT}${reset}\n=====> ${FB_RESTORE_POINT} is invalid Restore point.\n======> Please select/provide valid Restore point" "B"
      fi 
else
FunDoFlashBK   return 0;
fi
}

###
###
###
FunDoFlashBK(){
        ReportInfo "${2}" "B"
        echo ""
        echo "==> Flashback database to restore point ${FB_RESTORE_POINT} ...."
        echo ""
        echo "" >> ${FB_LOG_FILE}
        $1/bin/sqlplus -s /nolog <<EOF >> ${FB_LOG_FILE}
        set pagesize 0 feedback off verify off echo off;
        connect / as sysdba
        FLASHBACK DATABASE TO RESTORE POINT ${FB_RESTORE_POINT};
        ALTER DATABASE OPEN RESETLOGS;
EOF
}

###
### Function to display final flashback message
###
FunFinFBMessage(){
FunUpdateDateTime
echo "" >> ${FB_LOG_FILE}
echo "==> Flashback End Time: ${FB_START_TIME}" >> ${FB_LOG_FILE}
echo "==> Flashback End Time: ${FB_START_TIME}"
echo "" >> ${FB_LOG_FILE}
echo ""
echo "+-------------------------------------------------------+" >> ${FB_LOG_FILE}
echo "+-------------------------------------------------------+"
echo "|  Flashback Database Completed..............           |" >> ${FB_LOG_FILE}
echo "|  Flashback Database Completed..............           |"
echo "+-------------------------------------------------------+" >> ${FB_LOG_FILE}
echo "+-------------------------------------------------------+" 
echo "" >> ${FB_LOG_FILE}
echo ""
}


###
### Perform Flashback Database
###
FunFlashBackDB2RP(){
echo ""
ReportInfo "Parameters Provided for Flashback Database..\n=====> Database Name : ${bold}${underline}${DBNAME}${reset}\n======> Instance Name : ${bold}${underline}${ORACLE_SID}${reset}\n=======> Database Restore Point : ${bold}${underline}${FB_RESTORE_POINT}${reset} " "B"
echo ""
if [ "${IGNORE_VALIDATION}" = "" ]
   then
      printf "Continue with above parameters [Y|N] : "
      read -r CONFIRM
      if [ "${CONFIRM}" = "Y" ]
       then
          echo ""
          ReportInfo "User confirmed Flashback parameters ...\n=====> with option : ${bold}${underline}${CONFIRM}${reset} " "L"
       else
	  ReportError  "RERR-006" "User confirmed Flashback parametes....\n=====> with option ${bell}${bold}${underline}${CONFIRM}${reset}\n=====> Aborting Flashback Database..." "B"
       fi
else
   echo ""
   ReportInfo "Flashback parameters confirmation...\n=====> skipped by as IGNORE_VALIDATION set to : ${bold}${underline}${IGNORE_VALIDATION}${reset} " "L"
fi
FunShutdownDB ${ORACLE_HOME} "I" "Start Instance shutdwon\n=====> Shutdown Mode : Immediate"
FunStartDB ${ORACLE_HOME} "M" "Starting DB Instance \n=====> Sart Mode : Mount"
FunDoFlashBK ${ORACLE_HOME} "Database is being flashbacked....."
ReportInfo "Flashback database complete ...\n=====> Starting clean shudwon/startup..." "B"
echo ""
FunShutdownDB ${ORACLE_HOME} "I" "Start Instance shutdwon\n=====> Shutdown Mode : Immediate"
FunStartDB ${ORACLE_HOME} "O" "Starting DB Instance \n=====> Sart Mode : Read/Write"
FunFinFBMessage
}

###
### Start Script Execution
###

##
## Clear Screen
##
clear
CheckVars ${LOG_BASE_DIR} ${ORACLE_HOME} ${FB_USER}
FunListOraInstance
echo "";
FunGetOraInstance
echo "";
FunGetDBname ${ORACLE_HOME}
FunGetFBRestorePoint ${ORACLE_HOME}
FunFlashBackDB2RP
