#!/bin/bash -x

#place input where you would put the input image
#place output where you would put the output image/prefix


declare -a parameter_arr
clobber=0
p_index=0
while getopts “p:g:t:o:ch” OPTION
do
  case $OPTION in
    p)
       parameter_arr[${p_index}]=${OPTARG}
      #parameter_arr[${p_index}]=$(echo $OPTARG | sed 's/"//g')
      echo "Assigning parameter_arr[${p_index}] this string: ${parameter_arr[${p_index}]}"
      p_index=$((${p_index} + 1))
      ;;
    g)
      Gold_Standard_Mask=$OPTARG
      ;;
    t)
      Training_Brain=$OPTARG
      ;;
    o)
      outputDir=$OPTARG
      ;;
    h)
      printCommandLine
      ;;
    c)
      clobber=1
      ;;
    ?)
      echo "ERROR: Invalid option"
      printCommandLine
      ;;
     esac
done

workingDir=$(pwd)
declare -a algorithm_arr
Training_Brain_Name=$(basename ${Training_Brain} | awk -F"." '{print $1}')



 if [ ! -d "${outputDir}" ]; then
     outputDir=$(pwd)
 fi


 

for algorithm_num in $(seq 0 $((${#parameter_arr[@]} - 1))); do
    algorithm_arr[${algorithm_num}]=$(echo ${parameter_arr[${algorithm_num}]} | awk -F"," '{print $1}')
    if [[ ${algorithm_arr[@]} =~ ${algorithm_arr[${algorithm_num}]}* ]]; then
      a_count=0
      for algorithm in ${algorithm_arr[@]}; do
        if [[ ${algorithm} == ${algorithm_arr[${algorithm_num}]}* ]]; then
          a_count=$((${a_count} + 1))
        fi
      done
      algorithm_arr[${algorithm_num}]="${algorithm_arr[${algorithm_num}]}_${a_count}"
    fi
    a_index=$((${a_index} + 1 ))
done

echo "${Training_Brain_Name} initialized" >> MBA_${Training_Brain_Name}_progress.log
start_time=$(date +%s)

mkdir -p ${outputDir}/${Training_Brain_Name}/{Transforms,Brain}

############################################################   
#step 1: transform manual brain into MNI space
############################################################

     if [ ! -e ${outputDir}/${Training_Brain_Name}/Brain/Gold_${Training_Brain_Name}.nii.gz ] || [ ${clobber} -eq 1 ]; then
     fslmaths ${Training_Brain} -mas ${Gold_Standard_Mask} ${outputDir}/${Training_Brain_Name}/Brain/Gold_${Training_Brain_Name}.nii.gz
     fi

     if [ ! -e ${outputDir}/${Training_Brain_Name}/Transforms/${Training_Brain_Name}_coef_T1_to_MNI.nii.gz ] || [ ${clobber} -eq 1 ]; then
       echo -e "flirting ${Training_Brain_Name}"
       flirt -in ${outputDir}/${Training_Brain_Name}/Brain/Gold_${Training_Brain_Name}.nii.gz \
             -ref /usr/local/fsl/data/standard/MNI152_T1_2mm_brain.nii.gz \
             -omat ${outputDir}/${Training_Brain_Name}/Transforms/${Training_Brain_Name}_T1toMNI.mat
       

       echo -e "fnirting ${Training_Brain_Name}"
       fnirt --in=${Training_Brain} \
             --ref=/usr/local/fsl/data/standard/MNI152_T1_2mm_brain.nii.gz \
             --aff=${outputDir}/${Training_Brain_Name}/Transforms/${Training_Brain_Name}_T1toMNI.mat \
             --config=T1_2_MNI152_2mm.cnf \
             --cout=${outputDir}/${Training_Brain_Name}/Transforms/${Training_Brain_Name}_coef_T1_to_MNI \
             --iout=${outputDir}/${Training_Brain_Name}/Transforms/${Training_Brain_Name}_T1_to_MNI.nii.gz \
             --jout=${outputDir}/${Training_Brain_Name}/Transforms/${Training_Brain_Name}_T1_to_MNI \
             --jacrange=0.1,10
      fi

      if [ ! -e ${outputDir}/${Training_Brain_Name}/Brain/MNI_$(basename ${Gold_Standard_Mask}) ] || [ ${clobber} -eq 1 ]; then
     #this gives a mask we can average across the training data set
     echo -e "applying warp to ${Training_Brain_Name}"
     applywarp --ref=/usr/local/fsl/data/standard/MNI152_T1_2mm_brain.nii.gz \
               --in=${Gold_Standard_Mask} \
               --out=${outputDir}/${Training_Brain_Name}/Brain/MNI_$(basename ${Gold_Standard_Mask}) \
               --warp=${outputDir}/${Training_Brain_Name}/Transforms/${Training_Brain_Name}_coef_T1_to_MNI.nii.gz
     fi

############################################################   
#step 2: run brain extraction algorithms
############################################################
loop_index=0
declare -a output_arr

while [ ${loop_index} -lt ${#algorithm_arr[@]} ]; do
    algorithm=${algorithm_arr[${loop_index}]}
    mkdir -p ${outputDir}/${algorithm}/{False_Positives,False_Negatives,Junk}
    #important to recognize output later on
    output_arr[${loop_index}]=$(echo ${parameter_arr[${loop_index}]} | tr ',' '\n' | grep output | awk -F"." '{print $1}')

    if [ ! -e ${outputDir}/${algorithm}/Junk/${Training_Brain_Name}_${algorithm}_${output_arr[${output_index}]}.nii.gz ] || [ ${clobber} -eq 1 ]; then
    
      echo -e "\n${output_arr[${loop_index}]} is for algorithm ${algorithm}\n"
      output_file=${output_arr[${loop_index}]}
      echo "parameter_arr is ${parameter_arr[${loop_index}]}"
      if [[ "${output_file}" == *.* ]]; then
         output_ext=${output_arr[${loop_index}]#*.}
         clean_param=$(echo ${parameter_arr[${loop_index}]} | sed -e 's|,input|\ '"${Training_Brain}"'|' -e 's|,'"${output_file}"'|\ '"${Training_Brain_Name}"'_'"${algorithm}"'_output\.'"${output_ext}"'|' -e 's|,| |g')
      else
         clean_param=$(echo ${parameter_arr[${loop_index}]} | sed -e 's|,input|\ '"${Training_Brain}"'|' -e 's|,'"${output_file}"'|\ '"${Training_Brain_Name}"'_'"${algorithm}"'_output|' -e 's|,| |g')
      fi
      #This
      echo "clean param is ${clean_param}"
      sh -c "${clean_param}"
      
      mv *${Training_Brain_Name}_${algorithm}* ${outputDir}/${algorithm}/Junk/
    fi
    loop_index=$((${loop_index} + 1 ))
done


############################################################   
#step 3: Get false positive and false negative maps into standard space
############################################################
 output_index=0
 for algorithm in ${algorithm_arr[@]}; do
    echo -e "\nThe brain mask should be named this: ${Training_Brain_Name}_${algorithm}_${output_arr[${output_index}]}.nii.gz\n"
    algorithm_brain_mask=$(ls ${outputDir}/${algorithm}/Junk/${Training_Brain_Name}_${algorithm}_${output_arr[${output_index}]}.nii.gz)
    if [ $(echo ${algorithm_brain_mask} | wc -w) -gt 1 ];then
      echo -e "please specify a more specific outputfile in your call\nContinuing to next algorithm"
      continue 1
    fi
    #if [ ! -e ${outputDir}/${algorithm}/False_Positives/${Training_Brain_Name}_${algorithm}_false_pos_MNI.nii.gz ] || \
    #   [ ! -e ${outputDir}/${algorithm}/False_Negatives/${Training_Brain_Name}_${algorithm}_false_neg_MNI.nii.gz ] || [ ${clobber} -eq 1 ]; then
    #make sure the output is a mask
    fslmaths ${algorithm_brain_mask} -bin ${algorithm_brain_mask}

    #use the mask to create the brain
    algorithm_brain=${outputDir}/${algorithm}/Junk/${Training_Brain_Name}_${algorithm}_brain.nii.gz
    fslmaths ${Training_Brain} -mas ${algorithm_brain_mask} ${algorithm_brain}
    

    
      #creation of false positives (1) and false negatives (-1)
     fslmaths ${algorithm_brain_mask} -sub ${Gold_Standard_Mask} ${outputDir}/${algorithm}/Junk/${Training_Brain_Name}_difference_map.nii.gz

      #isolate false postives
       fslmaths ${outputDir}/${algorithm}/Junk/${Training_Brain_Name}_difference_map.nii.gz -thr 1 -bin ${outputDir}/${algorithm}/Junk/${Training_Brain_Name}_${algorithm}_false_pos.nii.gz
      #transform false_positives to standard space 
       applywarp --ref=/usr/local/fsl/data/standard/MNI152_T1_2mm_brain.nii.gz \
                 --in=${outputDir}/${algorithm}/Junk/${Training_Brain_Name}_${algorithm}_false_pos.nii.gz \
                 --out=${outputDir}/${algorithm}/False_Positives/${Training_Brain_Name}_${algorithm}_false_pos_MNI.nii.gz \
                 --warp=${outputDir}/${Training_Brain_Name}/Transforms/${Training_Brain_Name}_coef_T1_to_MNI.nii.gz
 
      #isolate false negatives
     fslmaths ${outputDir}/${algorithm}/Junk/${Training_Brain_Name}_difference_map.nii.gz -add 2 -uthr 1 -bin ${outputDir}/${algorithm}/Junk/${Training_Brain_Name}_${algorithm}_false_neg.nii.gz
      #transform false negatives to standard space
       applywarp --ref=/usr/local/fsl/data/standard/MNI152_T1_2mm_brain.nii.gz \
                 --in=${outputDir}/${algorithm}/Junk/${Training_Brain_Name}_${algorithm}_false_neg.nii.gz \
                 --out=${outputDir}/${algorithm}/False_Negatives/${Training_Brain_Name}_${algorithm}_false_neg_MNI.nii.gz \
                 --warp=${outputDir}/${Training_Brain_Name}/Transforms/${Training_Brain_Name}_coef_T1_to_MNI.nii.gz
     # fi
    output_index=$((${output_index} + 1))
done

############################################################   
#step 4: Default organization of false positives and false negatives
############################################################
 

param_index=0
for algorithm in ${algorithm_arr[@]}; do 
  
  
  # echo "this is the outputDir: ${outputDir}"
  # mkdir -p ${outputDir}/${algorithm}/{False_Positives,False_Negatives,Junk,Transforms}
  # mv ${Training_Brain_Name}_${algorithm}_false_neg_MNI.nii.gz ${outputDir}/${algorithm}/False_Negatives
  # mv ${Training_Brain_Name}_${algorithm}_false_pos_MNI.nii.gz ${outputDir}/${algorithm}/False_Positives
  # mv *${Training_Brain_Name}*${algorithm}* ${outputDir}/${algorithm}/Junk
  # mv ${Training_Brain_Name}_coef_T1_to_MNI.nii.gz ${outputDir}/${algorithm}/Transforms
  # mv ${Training_Brain_Name}_T1toMNI.mat ${outputDir}/${algorithm}/Transforms

  #Put parameters for algorithm in txt file in algorithm directory
  if [ ! -e ${outputDir}/${algorithm}/algorithm_parameters.txt ];then
  echo "${parameter_arr[${param_index}]}" >> ${outputDir}/${algorithm}/algorithm_parameters.txt
  fi
  param_index=$((${param_index} + 1))
done 

#do some inefficient calculations and report into log.
finish_time=$(date +%s)
time_diff_sec=$((${finish_time}-${start_time}))
time_diff_min=$((${time_diff_sec}/60))
echo "${Training_Brain_Name} completed, time: ${time_diff_min} minutes" >> MBA_${Training_Brain_Name}_progress.log