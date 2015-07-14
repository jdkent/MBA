#!/bin/bash -x

function printCommandLine {
  echo "Usage: MBA.sh -i input directory -o output directory -s subject list (.txt) -a algorithm directory"
  echo " where"
  echo "   -s The subjects T1 structural scan"
  echo "   -o Where the output brain masks will be placed"
  echo "   -a the directory where the output of MBA_train.sh resides"
  echo "   -b a prior probability map for the brain"


 
  exit 1
}
SUBMIT=0
#List all the options and get them, all options are necessary
while getopts “s:a:b:o:h” OPTION
do
  case $OPTION in
    s)
      subjectT1=${OPTARG}
      ;;
    a)
      algorDir=${OPTARG}
      ;;
    o)
      outputDir=${OPTARG}
      ;;
    b)
      brainPrior=${OPTARG}
      ;;
    h)
      printCommandLine
      ;;
    ?)
      echo "ERROR: Invalid option"
      printCommandLine
      ;;
     esac
done
 
#check if outputDir is made
if [ "${outputDir}" == "" ]; then
    outputDir=$(dirname ${subjectT1})
    echo "outputDir is: ${outputDir}"
fi

subjectT1_Name=$(basename ${subjectT1} | awk -F"." '{print $1}')
#data record keeping
echo "${subjectT1_Name} initialized" >> ${outputDir}/MBA_progress.log
start_time=$(date +%s)


    #directory where all processing takes place
    mkdir -p ${outputDir}/MBA_intermediate_files_${subjectT1_Name}

    #copy the T1 into the processing directory
    cp ${subjectT1} ${outputDir}/MBA_intermediate_files_${subjectT1_Name}
    cd ${outputDir}/MBA_intermediate_files_${subjectT1_Name}
    #change the orientation for FSL (RPI)
    #replace with function
    #ORIENTATION CODE HERE
         ############################################################
         infile=${outputDir}/MBA_intermediate_files_${subjectT1_Name}/${subjectT1_Name}
         #Determine qform-orientation to properly reorient file to RPI (MNI) orientation
      xorient=`fslhd ${infile} | grep "^qform_xorient" | awk '{print $2}' | cut -c1`
      yorient=`fslhd ${infile} | grep "^qform_yorient" | awk '{print $2}' | cut -c1`
      zorient=`fslhd ${infile} | grep "^qform_zorient" | awk '{print $2}' | cut -c1`


      native_orient=${xorient}${yorient}${zorient}


      echo "native orientation = ${native_orient}"


      if [ "${native_orient}" != "RPI" ]; then
        
        case ${native_orient} in

        #L PA IS
        LPI) 
          flipFlag="-x y z"
          ;;
        LPS) 
          flipFlag="-x y -z"
              ;;
        LAI) 
          flipFlag="-x -y z"
              ;;
        LAS) 
          flipFlag="-x -y -z"
              ;;

        #R PA IS
        RPS) 
          flipFlag="x y -z"
              ;;
        RAI) 
          flipFlag="x -y z"
              ;;
        RAS) 
          flipFlag="x -y -z"
              ;;

        #L IS PA
        LIP) 
          flipFlag="-x z y"
              ;;
        LIA) 
          flipFlag="-x -z y"
              ;;
        LSP) 
          flipFlag="-x z -y"
              ;;
        LSA) 
          flipFlag="-x -z -y"
              ;;

        #R IS PA
        RIP) 
          flipFlag="x z y"
              ;;
        RIA) 
          flipFlag="x -z y"
              ;;
        RSP) 
          flipFlag="x z -y"
              ;;
        RSA) 
          flipFlag="x -z -y"
              ;;

        #P IS LR
        PIL) 
          flipFlag="-z x y"
              ;;
        PIR) 
          flipFlag="z x y"
              ;;
        PSL) 
          flipFlag="-z x -y"
              ;;
        PSR) 
          flipFlag="z x -y"
              ;;

        #A IS LR
        AIL) 
          flipFlag="-z -x y"
              ;;
        AIR) 
          flipFlag="z -x y"
              ;;
        ASL) 
          flipFlag="-z -x -y"
              ;;
        ASR) 
          flipFlag="z -x -y"
              ;;

        #P LR IS
        PLI) 
          flipFlag="-y x z"
              ;;
        PLS) 
          flipFlag="-y x -z"
              ;;
        PRI) 
          flipFlag="y x z"
              ;;
        PRS) 
          flipFlag="y x -z"
              ;;

        #A LR IS
        ALI) 
          flipFlag="-y -x z"
              ;;
        ALS) 
          flipFlag="-y -x -z"
              ;;
        ARI) 
          flipFlag="y -x z"
              ;;
        ARS) 
          flipFlag="y -x -z"
              ;;

        #I LR PA
        ILP) 
          flipFlag="-y z x"
              ;;
        ILA) 
          flipFlag="-y -z x"
              ;;
        IRP) 
          flipFlag="y z x"
              ;;
        IRA) 
          flipFlag="y -z x"
              ;;

        #S LR PA
        SLP) 
          flipFlag="-y z -x"
              ;;
        SLA) 
          flipFlag="-y -z -x"
              ;;
        SRP) 
          flipFlag="y z -x"
              ;;
        SRA) 
          flipFlag="y -z -x"
              ;;

        #I PA LR
        IPL) 
          flipFlag="-z y x"
              ;;
        IPR) 
          flipFlag="z y x"
              ;;
        IAL) 
          flipFlag="-z -y x"
              ;;
        IAR) 
          flipFlag="z -y x"
              ;;

        #S PA LR
        SPL) 
          flipFlag="-z y -x"
              ;;
        SPR) 
          flipFlag="z y -x"
              ;;
        SAL) 
          flipFlag="-z -y -x"
              ;;
        SAR) 
          flipFlag="z -y -x"
              ;;
        esac

        echo "flipping by ${flipFlag}"


        #Reorienting image and checking for warning messages
        warnFlag=`fslswapdim ${infile} ${flipFlag} ${infile%.nii.gz}_MNI.nii.gz`
        warnFlagCut=`echo ${warnFlag} | awk -F":" '{print $1}'`


        #Reorienting the file may require swapping out the flag orientation to match the .img block
        if [[ $warnFlagCut == "WARNING" ]]; then
        fslorient -swaporient ${infile}
        fi

      else

        echo "No need to reorient.  Dataset already in RPI orientation."
      fi

    echo "the working directory is:$(pwd)" 

   
#################################################################################################
#1) GENERATE brain masks
#################################################################################################

#find relevant algorithms by finding algorithm_parameters.txt
declare -a algorithm_arr
declare -a parameter_arr
algor_index=0
for algorithm in $(find ${algorDir} -name algorithm_parameters.txt); do
  algorithm_arr[${algor_index}]=$(echo ${algorithm} | xargs -I {} dirname {} | xargs -I {} basename {})
  parameter_arr[${algor_index}]=$(cat ${algorithm})
  algor_index=$((${algor_index} + 1))
done

loop_index=0
declare -a output_arr

while [ ${loop_index} -lt ${#algorithm_arr[@]} ]; do
    algorithm=${algorithm_arr[${loop_index}]}
    #important to recognize output later on
    output_arr[${loop_index}]=$(echo ${parameter_arr[${loop_index}]} | tr ',' '\n' | grep output | awk -F"." '{print $1}')

      echo -e "\n${output_arr[${loop_index}]} is for algorithm ${algorithm}\n"
      output_file=${output_arr[${loop_index}]}
      echo "parameter_arr is ${parameter_arr[${loop_index}]}"
      if [[ "${output_file}" == *.* ]]; then
         output_ext=${output_arr[${loop_index}]#*.}
         clean_param=$(echo ${parameter_arr[${loop_index}]} | sed -e 's|,input|\ '"${subjectT1}"'|' -e 's|,'"${output_file}"'|\ '"${subjectT1_Name}"'_'"${algorithm}"'_output\.'"${output_ext}"'|' -e 's|,| |g')
      else
         clean_param=$(echo ${parameter_arr[${loop_index}]} | sed -e 's|,input|\ '"${subjectT1}"'|' -e 's|,'"${output_file}"'|\ '"${subjectT1_Name}"'_'"${algorithm}"'_output|' -e 's|,| |g')
      fi

      #This is how we call the algorithm
     echo "clean param is ${clean_param}"
     sh -c "${clean_param}"
      
     loop_index=$((${loop_index} + 1 ))
done


output_index=0
 for algorithm in ${algorithm_arr[@]}; do
    echo -e "\nThe brain mask should be named this: ${subjectT1_Name}_${algorithm}_${output_arr[${output_index}]}.nii.gz\n"
    algorithm_brain_mask=$(ls ${outputDir}/MBA_intermediate_files_${subjectT1_Name}/${subjectT1_Name}_${algorithm}_${output_arr[${output_index}]}.nii.gz)
    if [ $(echo ${algorithm_brain_mask} | wc -w) -gt 1 ];then
      echo -e "please specify a more specific outputfile in your call\nContinuing to next algorithm"
      continue 1
    fi

    #make sure the output is a mask
    fslmaths ${algorithm_brain_mask} -bin ${algorithm_brain_mask}

    #collect mask output in an array
    brain_mask_arr[${output_index}]=${algorithm_brain_mask}

    #prep false positives and false negative maps
    if [ ! -e ${algorDir}/${algorithm}/False_Positives/Ave_${algorithm}_False_Positive.nii.gz ]; then
      3dMean -prefix ${algorDir}/${algorithm}/False_Positives/Ave_${algorithm}_False_Positive.nii.gz $(ls ${algorDir}/${algorithm}/False_Positives/*false_pos_MNI.nii.gz)
    fi

     if [ ! -e ${algorDir}/${algorithm}/False_Negatives/Ave_${algorithm}_False_Negative.nii.gz ]; then
      3dMean -prefix ${algorDir}/${algorithm}/False_Negatives/Ave_${algorithm}_False_Negative.nii.gz $(ls ${algorDir}/${algorithm}/False_Negatives/*false_neg_MNI.nii.gz)
    fi

    output_index=$((${output_index} + 1))
  done

3dMean -prefix ${subjectT1_Name}_uncorrected_mask_mean.nii.gz ${brain_mask_arr[@]}
fslmaths ${subjectT1_Name}_uncorrected_mask_mean.nii.gz -thr 0.75 ${subjectT1_Name}_uncorrected_mask_mean_thresh.nii.gz

#use the mask to create the brain
fslmaths ${subjectT1} -mas ${subjectT1_Name}_uncorrected_mask_mean_thresh.nii.gz ${subjectT1_Name}_uncorrected_brain.nii.gz

#push the averaged brain into MNI space
flirt -in ${subjectT1_Name}_uncorrected_brain.nii.gz \
           -ref /usr/local/fsl/data/standard/MNI152_T1_2mm_brain.nii.gz \
           -omat ${subjectT1_Name}_T1toMNI.mat
     
echo -e "fnirting ${subjectT1_Name}"
fnirt --in=${subjectT1} \
      --ref=/usr/local/fsl/data/standard/MNI152_T1_2mm.nii.gz \
      --aff=${subjectT1_Name}_T1toMNI.mat \
      --config=T1_2_MNI152_2mm.cnf \
      --cout=${subjectT1_Name}_coef_T1_to_MNI \
      --iout=${subjectT1_Name}_T1_to_MNI.nii.gz \
      --jout=${subjectT1_Name}_T1_to_MNI \
      --jacrange=0.1,10


 #inverse the non-linear transform
    invwarp --warp=${subjectT1_Name}_coef_T1_to_MNI.nii.gz --ref=${subjectT1} --out=${subjectT1_Name}_coef_MNI_to_T1 
 #inverse the linear transform
    convert_xfm -omat ${subjectT1_Name}_MNItoT1.mat -inverse ${subjectT1_Name}_T1toMNI.mat


#I don't know why the warps don't need a postmat
#when I tried it, the images were severely off point
 #average brain
    applywarp -i ${brainPrior} \
              -r ${subjectT1} \
              -o ${subjectT1_Name}_P_of_B.nii.gz \
              -w ${subjectT1_Name}_coef_MNI_to_T1.nii.gz 
              #--postmat=${subjectT1_Name}_MNItoT1.mat 

output_index=0
for algorithm in ${algorithm_arr[@]}; do
    #false positives
    echo "warping false positives"
    applywarp -i ${algorDir}/${algorithm}/False_Positives/Ave_${algorithm}_False_Positive.nii.gz \
              -r ${subjectT1} \
              -o ${algorithm}_P_of_A_given_not_B.nii.gz \
              -w ${subjectT1_Name}_coef_MNI_to_T1.nii.gz 
              #--postmat=${subjectT1_Name}_MNItoT1.mat 
             
    #false negatives
    applywarp -i ${algorDir}/${algorithm}/False_Negatives/Ave_${algorithm}_False_Negative.nii.gz \
              -r ${subjectT1} \
              -o ${algorithm}_P_of_not_A_given_B.nii.gz \
              -w ${subjectT1_Name}_coef_MNI_to_T1.nii.gz 
              #--postmat=${subjectT1_Name}_MNItoT1.mat 
             
   



#correct the masks for any gross errors (assuming P_of_B contains at least the entire brain)
    fslmaths ${subjectT1_Name}_P_of_B.nii.gz -bin ${algorithm}_mask_corrector.nii.gz
    fslmaths ${brain_mask_arr[${output_index}]} -mul ${algorithm}_mask_corrector.nii.gz bayes_${algorithm}_brain_mask.nii.gz
 
    #make an image of all ones
    fslmaths bayes_${algorithm}_brain_mask.nii.gz -add 2 -bin ${algorithm}_white_sheet.nii.gz

    #create the probilities to satisfy the equations:
    #A=probability the voxel is included in the atlas
    #B=probability the voxel is included in the brain
    #-=symbol for "not"
    #Baye's Theorem using false positives.
    #P(-B|A)=(P(A|-B) * P(-B)) / ((P(A|-B) * P(-B)) + (P(A|B) * P(B)))
    #Baye's Theorem using false negatives
    #P(B|-A)=(P(-A|B) * P(B)) / ((P(-A|B) * P(B)) + (P(-A|-B) * P(-B)))

    #set up terms

    #P(-B)
    fslmaths ${algorithm}_white_sheet.nii.gz -sub ${subjectT1_Name}_P_of_B.nii.gz ${algorithm}_P_of_not_B.nii.gz
    #P(A|B):true positives
    fslmaths ${algorithm}_white_sheet.nii.gz -sub ${algorithm}_P_of_A_given_not_B.nii.gz ${algorithm}_P_of_A_given_B.nii.gz

    #P(-A|-B):true negative
    fslmaths ${algorithm}_white_sheet.nii.gz -sub ${algorithm}_P_of_not_A_given_B.nii.gz ${algorithm}_P_of_not_A_given_not_B.nii.gz
    
    
    #solve for false positives: P(-B|A)
    #P(A|-B) * P(-B)
    fslmaths ${algorithm}_P_of_A_given_not_B.nii.gz -mul ${algorithm}_P_of_not_B.nii.gz ${algorithm}_false_pos_event.nii.gz
    
    #P(A|B) * P(B)
    fslmaths ${algorithm}_P_of_A_given_B.nii.gz -mul ${subjectT1_Name}_P_of_B.nii.gz ${algorithm}_true_pos_event.nii.gz

    #((P(A|-B) * P(-B)) + (P(A|B) * P(B)))
    fslmaths ${algorithm}_false_pos_event.nii.gz -add ${algorithm}_true_pos_event.nii.gz ${algorithm}_pos_event_space.nii.gz

    #(P(A|-B) * P(-B)) / ((P(A|-B) * P(-B)) + (P(A|B) * P(B)))
    fslmaths ${algorithm}_false_pos_event.nii.gz -div ${algorithm}_pos_event_space.nii.gz ${algorithm}_pos_posterior.nii.gz


    #solve for false negatives
    #P(-A|B) * P(B)
    fslmaths ${algorithm}_P_of_not_A_given_B.nii.gz -mul ${subjectT1_Name}_P_of_B.nii.gz ${algorithm}_false_neg_event.nii.gz

    #P(-A|-B) * P(-B)
    fslmaths ${algorithm}_P_of_not_A_given_not_B.nii.gz -mul ${algorithm}_P_of_not_B.nii.gz ${algorithm}_true_neg_event.nii.gz

    #((P(-A|B) * P(B)) + (P(-A|-B) * P(-B)))
    fslmaths ${algorithm}_false_neg_event.nii.gz -add ${algorithm}_true_neg_event.nii.gz ${algorithm}_neg_event_space.nii.gz

    #(P(-A|B) * P(B)) / ((P(-A|B) * P(B)) + (P(-A|-B) * P(-B)))
    fslmaths ${algorithm}_false_neg_event.nii.gz -div ${algorithm}_neg_event_space.nii.gz ${algorithm}_neg_posterior.nii.gz


    #applying corrections to the algorithm's mask.

    #correct the false negative voxels that are not in the subject brain mask (correcting for false positive rate)
    fslmaths ${algorithm}_pos_posterior.nii.gz -sub bayes_${algorithm}_brain_mask.nii.gz -thr 0 ${algorithm}_pos_posterior_nonoverlap.nii.gz
    fslmaths ${algorithm}_neg_posterior.nii.gz -sub bayes_${algorithm}_brain_mask.nii.gz -thr 0 ${algorithm}_neg_posterior_nonoverlap.nii.gz
    fslmaths ${algorithm}_neg_posterior_nonoverlap.nii.gz -sub ${algorithm}_pos_posterior_nonoverlap.nii.gz ${algorithm}_neg_posterior_raw_corrected.nii.gz
    fslmaths ${algorithm}_neg_posterior_raw_corrected.nii.gz -thr 0 ${algorithm}_applied_false_negatives.nii.gz

    #get the false positives that are included in the brain mask (correcting for false negative rate)
    fslmaths ${algorithm}_neg_posterior.nii.gz -mul -1 ${algorithm}_minus_neg.nii.gz
    fslmaths ${algorithm}_pos_posterior.nii.gz -add ${algorithm}_minus_neg.nii.gz ${algorithm}_false_pos_and_neg.nii.gz
    fslmaths ${algorithm}_false_pos_and_neg.nii.gz -mul bayes_${algorithm}_brain_mask.nii.gz ${algorithm}_false_pos_and_neg_overlap.nii.gz
    fslmaths ${algorithm}_false_pos_and_neg_overlap.nii.gz -thr 0 -add 1 ${algorithm}_applied_false_positives.nii.gz

    #apply the final corrections to the brain mask
    fslmaths bayes_${algorithm}_brain_mask.nii.gz -div ${algorithm}_applied_false_positives.nii.gz bayes_${algorithm}_brain_mask_pos_corrected.nii.gz
    fslmaths bayes_${algorithm}_brain_mask_pos_corrected.nii.gz -add ${algorithm}_applied_false_negatives.nii.gz ${subjectT1}_${algorithm}_brain_mask_corrected.nii.gz
    
    output_index=$((${output_index} + 1))
done

#################################################################################################
#3) AVERAGE brain masks
#################################################################################################


#combine and threshold the images, may need to do some post-hoc smoothing
fslmerge -t corrected_masks.nii.gz ${subjectT1}_*_brain_mask_corrected.nii.gz
fslmaths corrected_masks.nii.gz -Tmean raw_ave_masks_corrected.nii.gz

#some thresholds for the data, have a smoothed version as well (generally better looking)
fslmaths raw_ave_masks_corrected.nii.gz -thr 1.0 -bin ${subjectT1_Name}_mask_100.nii.gz
fslmaths ${subjectT1_Name}_mask_100.nii.gz -kernel boxv 5x5x5 -fmedian ${subjectT1_Name}_mask_100_smooth.nii.gz
fslmaths raw_ave_masks_corrected.nii.gz -thr 0.9 -bin ${subjectT1_Name}_mask_90.nii.gz
fslmaths ${subjectT1_Name}_mask_90.nii.gz -kernel boxv 5x5x5 -fmedian ${subjectT1_Name}_mask_90_smooth.nii.gz
fslmaths raw_ave_masks_corrected.nii.gz -thr 0.8 -bin ${subjectT1_Name}_mask_80.nii.gz
fslmaths ${subjectT1_Name}_mask_80.nii.gz -kernel boxv 5x5x5 -fmedian ${subjectT1_Name}_mask_80_smooth.nii.gz
fslmaths raw_ave_masks_corrected.nii.gz -thr 0.7 -bin ${subjectT1_Name}_mask_70.nii.gz
fslmaths ${subjectT1_Name}_mask_70.nii.gz -kernel boxv 5x5x5 -fmedian ${subjectT1_Name}_mask_70_smooth.nii.gz
fslmaths raw_ave_masks_corrected.nii.gz -thr 0.6 -bin ${subjectT1_Name}_mask_60.nii.gz
fslmaths ${subjectT1_Name}_mask_60.nii.gz -kernel boxv 5x5x5 -fmedian ${subjectT1_Name}_mask_60_smooth.nii.gz
fslmaths raw_ave_masks_corrected.nii.gz -thr 0.5 -bin ${subjectT1_Name}_mask_50.nii.gz
fslmaths ${subjectT1_Name}_mask_50.nii.gz -kernel boxv 5x5x5 -fmedian ${subjectT1_Name}_mask_50_smooth.nii.gz
fslmaths raw_ave_masks_corrected.nii.gz -thr 0.4 -bin ${subjectT1_Name}_mask_40.nii.gz
fslmaths ${subjectT1_Name}_mask_40.nii.gz -kernel boxv 5x5x5 -fmedian ${subjectT1_Name}_mask_40_smooth.nii.gz
fslmaths raw_ave_masks_corrected.nii.gz -thr 0.3 -bin ${subjectT1_Name}_mask_30.nii.gz
fslmaths ${subjectT1_Name}_mask_30.nii.gz -kernel boxv 5x5x5 -fmedian ${subjectT1_Name}_mask_30_smooth.nii.gz
fslmaths raw_ave_masks_corrected.nii.gz -thr 0.2 -bin ${subjectT1_Name}_mask_20.nii.gz
fslmaths ${subjectT1_Name}_mask_20.nii.gz -kernel boxv 5x5x5 -fmedian ${subjectT1_Name}_mask_20_smooth.nii.gz

#A place to put the above results

mv ${subjectT1}_mask_* ${outputDir}

#this was moved to beginning in order to minimally affect other files not a part of this script
#mkdir -p MBA_junk
#mv \`ls *.* | grep -v MPRAGE\` ${inDir}/sub${sub}/MBA_junk


#do some inefficient calculations and report into log.
finish_time=$(date +%s)
time_diff_sec=$((${finish_time}-${start_time}))
time_diff_min=$((${time_diff_sec}/60))
echo "${subjectT1_Name} completed, time: ${time_diff_min} minutes" >> ${outputDir}/MBA_progress.log


















#############################################################################
# loop_index=0
# declare -a output_arr

# while [ ${loop_index} -lt ${#algorithm_arr[@]} ]; do
#     algorithm=$(basename ${algorithm_arr[${loop_index}]})
#     parameter_arr[${param_index}]=$(cat ${algorDir}/${algorithm}/algorithm_parameters.txt)

#     #important to recognize output later on
#     output_arr[${loop_index}]=$(echo ${parameter_arr[${loop_index}]} | tr ' ' '\n' | grep output | awk -F"." '{print $1}')
   
#     output_file=${output_arr[${loop_index}]}
#     if [[ "${output_file}" == *.* ]]; then
#        output_ext=${output_arr[${loop_index}]#*.}
#        clean_param=$(echo ${parameter_arr[${loop_index}]} | sed -e 's|\ input|\ '"${Training_Brain}"'|' -e 's|\ '"${output_file}"'|\ '"${Training_Brain_Name}"'_'"${algorithm}"'_output\.'"${output_ext}"'|')
#     else
#        clean_param=$(echo ${parameter_arr[${loop_index}]} | sed -e 's|\ input|\ '"${Training_Brain}"'|' -e 's|\ '"${output_file}"'|\ '"${Training_Brain_Name}"'_'"${algorithm}"'_output|')
#     fi

#     #This
#     ${clean_param}
    
#     loop_index=$((${loop_index} + 1 ))
# done




# #find the algorithms in the algorithm directory

# # #read the param file in the algor directory
# # declare -a parameter_arr
# # param_index=0
# # for algorithm in ${algorithm_arr[@]}; do
# #     parameter_arr[${param_index}]=$(cat ${algorDir}/${algorithm}/algorithm_parameters.txt)

# #     clean_param=$(echo ${parameter_arr[${param_index}]} | sed -e 's|\ input|\ '"${subjectT1}"'|' -e 's|\ output|\ '"${subjectT1_Name}"'_'"${algorithm}"'_output|')
# #     #This calls the skull stripping command
# #     ${clean_param}

# #     param_index=$((${param_index} + 1 ))
# # done

# # #for index in $(seq 0 $((${#parameter_arr[@]} - 1))); do


    
# # done
# #################################################################################################
# #3) Take average of brain masks
# #################################################################################################
# output_index=0
# declare -a brain_mask_arr
#  for algorithm in ${algorithm_arr[@]}; do
#     algorithm_brain_mask=$(ls ${Training_Brain_Name}_${algorithm}_${output_arr[${output_index}]}*.nii.gz)
#     if [ $(echo ${algorithm_brain_mask} | wc -w) -gt 1 ];then
#       echo -e "please specify a more specific outputfile in your call\n Continuing to next algorithm"
#       continue 1
#     fi
#     #make sure the output is a mask
#     fslmaths ${algorithm_brain_mask} -bin ${algorithm_brain_mask}

#     brain_mask_arr[${output_index}]=${algorithm_brain_mask}]
#     output_index=$((${output_index} + 1 ))
#  done

# 3dMean -prefix ${subjectT1_Name}_uncorrected_mask_mean.nii.gz ${brain_mask_arr[@]}
# fslmaths ${subjectT1_Name}_uncorrected_mask_mean.nii.gz -thr 0.75 ${subjectT1_Name}_uncorrected_mask_mean_thresh.nii.gz

# #use the mask to create the brain
# fslmaths ${subjectT1} -mas ${subjectT1_Name}_uncorrected_mask_mean_thresh.nii.gz ${subjectT1_Name}_uncorrected_brain.nii.gz

# #push the averaged brain into MNI space
# flirt -in${subjectT1_Name}_uncorrected_brain.nii.gz \
#            -ref /usr/local/fsl/data/standard/MNI152_T1_2mm_brain.nii.gz \
#            -out tmp_${Training_Brain_Name}_T1toMNI.nii.gz \
#            -omat ${Training_Brain_Name}_T1toMNI.mat
     
#      echo -e "fnirting ${Training_Brain_Name}"
#      fnirt --in=${Training_Brain} \
#            --aff=${Training_Brain_Name}_T1toMNI.mat \
#            --config=T1_2_MNI152_2mm.cnf \
#            --cout=${Training_Brain_Name}_coef_T1_to_MNI \
#            --iout=${Training_Brain_Name}_T1_to_MNI.nii.gz \
#            --jout=${Training_Brain_Name}_T1_to_MNI \
#            --jacrange=0.1,10

# #################################################################################################
# #2) CORRECT brain masks
# #################################################################################################

# #For each algorithm output, correct that output 
# for algor in bet afni mbwss fs; do
# echo "the algorithm used: ${algor}"
# #outdated variables, changed freesurfer to fs generally, make more efficient when possible.
# algorDirName=${algor}
# echo "the algorithm dir name is: ${algorDirName}"

#     #transform the training data into subject space
#      #step 1: flirt
#      flirt -in ${sub}_${algor}_brain.nii.gz -ref /usr/local/fsl/data/standard/MNI152_T1_2mm_brain.nii.gz -out aff_${algor}_T1_to_MNI.nii.gz -omat aff_${algor}_T1_to_MNI.mat

#     #step 2: fnirt
#     fnirt --in=MPRAGE.nii.gz --aff=aff_${algor}_T1_to_MNI.mat --config=T1_2_MNI152_2mm.cnf --cout=${algor}_coef_T1_to_MNI --iout=${algor}_T1_to_MNI.nii.gz --jout=j${algor}_T1_to_MNI --jacrange=0.1,10
   
#     #inverse the non-linear transform
#     invwarp --warp=${algor}_coef_T1_to_MNI.nii.gz --ref=MPRAGE.nii.gz --out=${algor}_MNI_to_T1 
    
#     #inverse the linear transform
#     convert_xfm -omat aff_${algor}_MNI_to_T1.mat -inverse aff_${algor}_T1_to_MNI.mat

#     #apply the warp to false positives, false negatives, and the brain average
#     #false positives
#     applywarp --ref=MPRAGE.nii.gz --in=${algorDir}/${algorDirName}_prob_map/false_pos/${algor}_ave_false_pos.nii.gz --out=${algor}_P_of_A_given_not_B.nii.gz --postmat=aff_${algor}_MNI_to_T1.mat
#     #false negatives
#     applywarp --ref=MPRAGE.nii.gz --in=${algorDir}/${algorDirName}_prob_map/false_neg/${algor}_ave_false_neg.nii.gz --out=${algor}_P_of_not_A_given_B.nii.gz --postmat=aff_${algor}_MNI_to_T1.mat
#     #average brain
#     applywarp --ref=MPRAGE.nii.gz --in=${algorDir}/sub_mask_MNI/ave_brain.nii.gz --out=${algor}_P_of_B.nii.gz --postmat=aff_${algor}_MNI_to_T1.mat

#     #correct the masks for any gross errors (assuming P_of_B contains at least the entire brain)
#     fslmaths ${algor}_P_of_B.nii.gz -bin ${algor}_mask_corrector.nii.gz
#     fslmaths ${sub}_${algor}_brain_mask.nii.gz -mul ${algor}_mask_corrector.nii.gz bayes_${algor}_brain_mask.nii.gz
 
#     #make an image of all ones
#     fslmaths bayes_${algor}_brain_mask.nii.gz -add 2 -bin ${algor}_white_sheet.nii.gz

#     #create the probilities to satisfy the equations:
#     #A=probability the voxel is included in the atlas
#     #B=probability the voxel is included in the brain
#     #-=symbol for "not"
#     #Baye's Theorem using false positives.
#     #P(-B|A)=(P(A|-B) * P(-B)) / ((P(A|-B) * P(-B)) + (P(A|B) * P(B)))
#     #Baye's Theorem using false negatives
#     #P(B|-A)=(P(-A|B) * P(B)) / ((P(-A|B) * P(B)) + (P(-A|-B) * P(-B)))

#     #set up terms

#     #P(-B)
#     fslmaths ${algor}_white_sheet.nii.gz -sub ${algor}_P_of_B.nii.gz ${algor}_P_of_not_B.nii.gz
#     #P(A|B):true positives
#     fslmaths ${algor}_white_sheet.nii.gz -sub ${algor}_P_of_A_given_not_B.nii.gz ${algor}_P_of_A_given_B.nii.gz

#     #P(-A|-B):true negative
#     fslmaths ${algor}_white_sheet.nii.gz -sub ${algor}_P_of_not_A_given_B.nii.gz ${algor}_P_of_not_A_given_not_B.nii.gz
    
    
#     #solve for false positives: P(-B|A)
#     #P(A|-B) * P(-B)
#     fslmaths ${algor}_P_of_A_given_not_B.nii.gz -mul ${algor}_P_of_not_B.nii.gz ${algor}_false_pos_event.nii.gz
    
#     #P(A|B) * P(B)
#     fslmaths ${algor}_P_of_A_given_B.nii.gz -mul ${algor}_P_of_B.nii.gz ${algor}_true_pos_event.nii.gz

#     #((P(A|-B) * P(-B)) + (P(A|B) * P(B)))
#     fslmaths ${algor}_false_pos_event.nii.gz -add ${algor}_true_pos_event.nii.gz ${algor}_pos_event_space.nii.gz

#     #(P(A|-B) * P(-B)) / ((P(A|-B) * P(-B)) + (P(A|B) * P(B)))
#     fslmaths ${algor}_false_pos_event.nii.gz -div ${algor}_pos_event_space.nii.gz ${algor}_pos_posterior.nii.gz


#     #solve for false negatives
#     #P(-A|B) * P(B)
#     fslmaths ${algor}_P_of_not_A_given_B.nii.gz -mul ${algor}_P_of_B.nii.gz ${algor}_false_neg_event.nii.gz

#     #P(-A|-B) * P(-B)
#     fslmaths ${algor}_P_of_not_A_given_not_B.nii.gz -mul ${algor}_P_of_not_B.nii.gz ${algor}_true_neg_event.nii.gz

#     #((P(-A|B) * P(B)) + (P(-A|-B) * P(-B)))
#     fslmaths ${algor}_false_neg_event.nii.gz -add ${algor}_true_neg_event.nii.gz ${algor}_neg_event_space.nii.gz

#     #(P(-A|B) * P(B)) / ((P(-A|B) * P(B)) + (P(-A|-B) * P(-B)))
#     fslmaths ${algor}_false_neg_event.nii.gz -div ${algor}_neg_event_space.nii.gz ${algor}_neg_posterior.nii.gz



#     #applying corrections to the algorithm's mask.

#     #correct the false negative voxels that are not in the subject brain mask (correcting for false positive rate)
#     fslmaths ${algor}_pos_posterior.nii.gz -sub bayes_${algor}_brain_mask.nii.gz -thr 0 ${algor}_pos_posterior_nonoverlap.nii.gz
#     fslmaths ${algor}_neg_posterior.nii.gz -sub bayes_${algor}_brain_mask.nii.gz -thr 0 ${algor}_neg_posterior_nonoverlap.nii.gz
#     fslmaths ${algor}_neg_posterior_nonoverlap.nii.gz -sub ${algor}_pos_posterior_nonoverlap.nii.gz ${algor}_neg_posterior_raw_corrected.nii.gz
#     fslmaths ${algor}_neg_posterior_raw_corrected.nii.gz -thr 0 ${algor}_applied_false_negatives.nii.gz

#     #get the false positives that are included in the brain mask (correcting for false negative rate)
#     fslmaths ${algor}_neg_posterior.nii.gz -mul -1 ${algor}_minus_neg.nii.gz
#     fslmaths ${algor}_pos_posterior.nii.gz -add ${algor}_minus_neg.nii.gz ${algor}_false_pos_and_neg.nii.gz
#     fslmaths ${algor}_false_pos_and_neg.nii.gz -mul bayes_${algor}_brain_mask.nii.gz ${algor}_false_pos_and_neg_overlap.nii.gz
#     fslmaths ${algor}_false_pos_and_neg_overlap.nii.gz -thr 0 -add 1 ${algor}_applied_false_positives.nii.gz

#     #apply the final corrections to the brain mask
#     fslmaths bayes_${algor}_brain_mask.nii.gz -div ${algor}_applied_false_positives.nii.gz bayes_${algor}_brain_mask_pos_corrected.nii.gz
#     fslmaths bayes_${algor}_brain_mask_pos_corrected.nii.gz -add ${algor}_applied_false_negatives.nii.gz ${sub}_${algor}_brain_mask_corrected.nii.gz
    
# done

# #################################################################################################
# #3) AVERAGE brain masks
# #################################################################################################


# #combine and threshold the images, may need to do some post-hoc smoothing
# fslmerge -t corrected_masks.nii.gz ${sub}_*_brain_mask_corrected.nii.gz
# fslmaths corrected_masks.nii.gz -Tmean raw_ave_masks_corrected.nii.gz

# #some thresholds for the data, have a smoothed version as well (generally better looking)
# fslmaths raw_ave_masks_corrected.nii.gz -thr 1.0 -bin mask_100.nii.gz
# fslmaths mask_100.nii.gz -kernel boxv 5x5x5 -fmedian mask_100_smooth.nii.gz
# fslmaths raw_ave_masks_corrected.nii.gz -thr 0.9 -bin mask_90.nii.gz
# fslmaths mask_90.nii.gz -kernel boxv 5x5x5 -fmedian mask_90_smooth.nii.gz
# fslmaths raw_ave_masks_corrected.nii.gz -thr 0.8 -bin mask_80.nii.gz
# fslmaths mask_80.nii.gz -kernel boxv 5x5x5 -fmedian mask_80_smooth.nii.gz
# fslmaths raw_ave_masks_corrected.nii.gz -thr 0.7 -bin mask_70.nii.gz
# fslmaths mask_70.nii.gz -kernel boxv 5x5x5 -fmedian mask_70_smooth.nii.gz
# fslmaths raw_ave_masks_corrected.nii.gz -thr 0.6 -bin mask_60.nii.gz
# fslmaths mask_60.nii.gz -kernel boxv 5x5x5 -fmedian mask_60_smooth.nii.gz
# fslmaths raw_ave_masks_corrected.nii.gz -thr 0.5 -bin mask_50.nii.gz
# fslmaths mask_50.nii.gz -kernel boxv 5x5x5 -fmedian mask_50_smooth.nii.gz
# fslmaths raw_ave_masks_corrected.nii.gz -thr 0.4 -bin mask_40.nii.gz
# fslmaths mask_40.nii.gz -kernel boxv 5x5x5 -fmedian mask_40_smooth.nii.gz
# fslmaths raw_ave_masks_corrected.nii.gz -thr 0.3 -bin mask_30.nii.gz
# fslmaths mask_30.nii.gz -kernel boxv 5x5x5 -fmedian mask_30_smooth.nii.gz
# fslmaths raw_ave_masks_corrected.nii.gz -thr 0.2 -bin mask_20.nii.gz
# fslmaths mask_20.nii.gz -kernel boxv 5x5x5 -fmedian mask_20_smooth.nii.gz

# #A place to put the above results
# mkdir -p ${inDir}/sub${sub}/MBA_results
# mv mask_* ${inDir}/sub${sub}/MBA_results

# #this was moved to beginning in order to minimally affect other files not a part of this script
# #mkdir -p MBA_junk
# #mv \`ls *.* | grep -v MPRAGE\` ${inDir}/sub${sub}/MBA_junk


# #do some inefficient calculations and report into log.
# finish_time=$(date +%s)
# time_diff_sec=$((${finish_time}-${start_time}))
# time_diff_min=$((${time_diff_sec}/60))
# echo "${sub} completed, time: ${time_diff_min} minutes" >> ${outDir}/MBA_SH_Files/MBA_progress.log
