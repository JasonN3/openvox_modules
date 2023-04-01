#!/bin/bash

## Usage
## From the root of the git repo, call `./gen_readme.sh` 
## followed by the module name you updated
## Example: `./gen_readme.sh domain_join`

if [[ $1 != "" ]]
then
  modules=$1
else
  modules=$(ls -d */)
fi

currdir=$(realpath $(dirname $0))

for module in $modules
do
  module=$(echo $module | tr -d '/')
  readme_file="${module}/README.md"

  cd $currdir/${module}
  puppet strings generate --format markdown --out README.md
done

cd $currdir

if [[ $1 == "" ]]
then
  readme_file="README.md"
  echo -n > ${readme_file}
  if [[ -f .readme/header.md ]]
  then
    cat .readme/header.md >> ${readme_file}
    echo '---' >> ${readme_file}
  fi
  echo "## Modules list" >> ${readme_file}
  for module in $(ls -d */)
  do
    module=$(echo $module | tr -d '/')
    echo "1. [${module}](${module}/README.md)  " >> ${readme_file}
    cat ${module}/description >> ${readme_file}
    echo >> ${readme_file}
  done
  if [[ -f .readme/footer.md ]]
  then
    echo '---' >> ${readme_file}
    cat .readme/footer.md >> ${readme_file}
  fi
fi