#!/bin/bash

#run as root
function cleanup()
{
    echo stopping
    pkill -f experiment.py
    pkill -f evaluate.py

    #pkill -P $(pgrep -f experiment.py)  
    #pkill -P $(pgrep -f evaluate.py)    
    
    sudo rm -r results_temp
    end=false
    echo $end
    pkill -f run_and_evaluate.sh
    exit
}


trap cleanup SIGINT
run=$2
output_dir=$1
end=true

while $end
do
    echo "Starting Run $run"
    sudo ./experiment.py --output-dir results_temp all-kem all-sig all-kem-scenarios all-sig-scenarios level1 level3 level5 &  # Run experiment.py in background
    exp_pid=$!  
    wait $exp_pid
    
    sudo ./evaluate.py --output-dir $1/evaluate_output$run results_temp/* &  
    eval_pid=$!  
    
    wait $eval_pid
    sudo rm -r results_temp
    let "run+=1"
done





