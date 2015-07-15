# MBA

Tutorial for using MBA.sh:
Purpose: To provide better/more reliable skull stripped outputs of T1-weighted MRI head images

Prerequisites: 
	Only used/tested on MAC OSX
	fsl is installed and defined in your $PATH variable http://fsl.fmrib.ox.ac.uk/fsldownloads/fsldownloadmain.html
	afni is installed and defined in your $PATH variable http://afni.nimh.nih.gov/afni/download/afni/releases
	MBA_train.sh has already been ran on a "gold standard" data-set with at least one skull stripping algorithm (tutorial for this to come)
	A brain "Prior" (i.e. a probability map for brain's existance at every point) has been made and is in standard space
	Images are in NIFTI format

Parameters:
	-s The subjects T1 structural scan
	-o Where the output brain masks will be placed
	-a The directory where the output of MBA_train.sh resides
	-b A prior probability map for the brain

Example Calls:

Abstract
MBA.sh -s \<T1\> -o \</output/directory/\> -a \</The/Algorithm/Directory/\> -b \<Brain_Probability_Map\>

Concrete
MBA.sh -s sub1001.nii.gz -o /Volumes/VossLab/Repositories/Bike/FIRST_practice -a /Volumes/VossLab/Repositories/MBA_maps -b /Volumes/VossLab/Repositories/MBA_maps/brainPrior/Ave_brain.nii.gz


Notes for VossLab users:
the flags -a & -b should be the same as the concrete example above for any run of the mill skull stripping.
So -a should always be /Volumes/VossLab/Repositories/MBA_maps.
and -b should always be /Volumes/VossLab/Repositories/MBA_maps/brainPrior/Ave_brain.nii.gz.
This means the only options that should change is the subject being processed (-s) and/or the output directory.

Misc:
This process can be sped up by using it in conjunction with parallel_submit_legacyV1.1.sh,
example call: parallel_submit_legacyV1.1.sh -s "MBA.sh -s sub_MPRAGES.parallel -o /Volumes/VossLab/Repositories/Bike/FIRST_practice -a /Volumes/VossLab/Repositories/MBA_maps -b /Volumes/VossLab/Repositories/MBA_maps/brainPrior/Ave_brain.nii.gz" -j 8 


