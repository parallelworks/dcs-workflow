# Delete unmerged results
rm -f Results/${in_name}_*.hst Results/${in_name}_*.hlm

# Delete input files to prevent the controller from running out of space
cat downloaded_files.txt | xargs rm -rf

