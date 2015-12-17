#!/bin/bash

### Make sure that nodes are exclusive for you
### ntasks-per-node is irrelevant

#SBATCH --exclusive
#SBATCH --ntasks-per-node=8
##SBATCH --constraint=CPU-E5-2660
#SBATCH --partition=debug

#SBATCH --mem=24000
####SBATCH --mem-per-cpu=4000           default is 3000MB


### Customize this section for your job
#SBATCH --nodes=2
#SBATCH --time=01:00:00

#SBATCH --job-name="set_job_name_here"
#SBATCH --output=%j-quasicliq-30M-20nodes-8exe-2cores.stdout
#SBATCH --error=%j-quasicliq-30M-20nodes-8exe-6cores.stderr

echo "SLURM_JOBID="$SLURM_JOBID
echo "Running on hosts: $SLURM_NODELIST"
echo "SLURM_JOB_NODELIST"=$SLURM_JOB_NODELIST
echo "Running on $SLURM_NNODES nodes."
echo "Running on $SLURM_NPROCS processors."
echo "SLURM_JOB_NUM_NODES"=$SLURM_JOB_NUM_NODES

# MAKE SURE THAT SPARK_LOG_DIR AND SPARK_WORKER_DIR
# ARE SET IN YOUR BASHRC, FOR EXAMPLE:
# export SPARK_LOG_DIR=/tmp
# export SPARK_WORKER_DIR=/scratch/dnazaret

# Add extra modules here

# Set your command and arguments
###PROG="pyspark-core.py"
PROG="quac.py"



####### DO NOT EDIT THIS PART
module load java/1.8.0_45
module load hadoop/2.6.0
module load spark/1.4.1-hadoop

# GET LIST OF NODES
NODES=(`srun hostname | sort | uniq`)

NUM_NODES=${#NODES[@]}
LAST=$((NUM_NODES - 1))


echo $MASTER
echo $NODES

# FIRST NODE IS MASTER
ssh ${NODES[0]} "cd $SPARK_HOME; ./sbin/start-master.sh"
MASTER="spark://${NODES[0]}:7077"

# ALL OTHER NODES ARE WORKERS
mkdir -p $SLURM_SUBMIT_DIR/$SLURM_JOB_ID

for i in `seq 1 $LAST`; do
ssh ${NODES[$i]} "cd $SPARK_HOME; nohup ./bin/spark-class org.apache.spark.deploy.worker.Worker $MASTER &> $SLURM_SUBMIT_DIR/$SLURM_JOB_ID/nohup-${NODES[$i]}.out" &
done


# SUBMIT PYSPARK JOB
$SPARK_HOME/bin/spark-submit --num-executors 4  --executor-cores 4 --executor-memory 2G --master $MASTER $PROG


# CLEAN SPARK JOB
ssh ${NODES[0]} "cd $SPARK_HOME; ./sbin/stop-master.sh"

for i in `seq 1 $LAST`; do
ssh ${NODES[$i]} "killall java"
done
