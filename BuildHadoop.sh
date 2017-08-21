#bin/bash

kubectl run hadoop-nn --image=hash14/hadoop-nn --port=50070 --replicas=1

kubectl run hadoop-sl --image=hash14/hadoop-sl --replicas=4

sleep 1

getPods="$(exec kubectl get pods)"
IPmaster = "master"
echo "Pods " $getPods
master="hadoop-nn"
isRunningMaster=0
isRunningWorkers=0
runningWorkers=()
workers=()
IPs=()
for word in $getPods
do
    if [[ $word == hadoop-nn* ]] ; 
    then
	master=$word
    elif [[ $word == hadoop-sl* ]] ;
    then
	workers+=("$word") 
    fi
done
echo "Workers ${workers[@]}"
while :
do
masterStat="$(kubectl describe pod $master | grep 'Status')"
workerStat=()

for worker in ${workers[@]}
do
workerStat+=("$(kubectl describe pod $worker | grep 'Status')")
done

for stat in $masterStat
do
	if [[ $stat == Running ]] ;
	then
		isRunningMaster=1
		echo "Master " $stat
		break
	elif [[ $stat == Pending ]]
	then
		echo "Master " $stat
		isRunning=0
	fi
done
let "i=0"
for stat in ${workerStat[@]}
do
        if [[ $stat == Running ]] ;
        then
                runningWorkers[$i]=1
                echo $i " " $stat
		let "i++"
        elif [[ $stat == Pending ]]
	then
                echo "Worker $i " $stat
                runningWorkers[$i]=0
		let "i++"
        fi
done
for i in "${runningWorkers[@]}"
do
if [[ $i -eq 0 ]] ;
then
	isRunningWorkers=0
	break
else
	isRunningWorkers=1
fi
done

if [[ $isRunningMaster -eq 1 && $isRunningWorkers -eq 1 ]] ;
then
	break
fi
sleep 2
done

IPmaster=("$(kubectl describe pod $master | grep IP | sed -E 's/IP:[[:space:]]+//')")

for ip in ${workers[@]}
do
	IPs+=("$(kubectl describe pod $ip | grep IP | sed -E 's/IP:[[:space:]]+//')")
done
echo ${IPs[@]}
echo "Workers  ${workers[@]}"
echo "Master  $IPmaster"

ssh root@$IPmaster "echo -ne '<configuration>\n\t<property>\n\t\t<name>fs.defaultFS</name>\n\t\t<value>hdfs://$IPmaster:9000/</value>\n\t</property>\n</configuration>\n' > /usr/local/hadoop/etc/hadoop/core-site.xml"
let "i=0"
for IPworkers in ${IPs[@]}
do
echo "Writing into master"
echo "adding slave$i to slaves file"
ssh root@$IPmaster "echo $IPworkers >> /usr/local/hadoop/etc/hadoop/slaves"
echo "adding to /etc/hosts"
ssh root@$IPmaster "echo $IPworkers    ${workers[$i]} >> /etc/hosts"

echo "writing into slave$i"
echo "writing master into /etc/hosts"
ssh root@$IPworkers "echo $IPmaster    $master >> /etc/hosts"
echo "writing into core-site.xml"
ssh root@$IPworkers "echo -ne '<configuration>\n\t<property>\n\t\t<name>fs.defaultFS</name>\n\t\t<value>hdfs://$IPmaster:9000/</value>\n\t</property>\n</configuration>\n' > /usr/local/hadoop/etc/hadoop/core-site.xml"
let "i++"
done

kubectl exec -it $master sbin/start-dfs.sh

