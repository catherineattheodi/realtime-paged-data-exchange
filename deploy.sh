#!/bin/bash
set -e # exit with nonzero exit code if anything fails

# squash messages
git config --global push.default matching

# prepare respec build

# clear the respec directory
rm -rf respec || exit 0;

# get existing gh-pages
git clone -b develop "https://github.com/openactive/respec.git"

cd respec

npm install #note: not required for phantom

cd ..


# clear and re-create the out directory
rm -rf out || exit 0;
mkdir out;

# go to the out directory and create a *new* Git repo
cd out
git init

# inside this git repo we'll pretend to be a new user
git config user.name "Travis CI"
git config user.email "travis@openactive.org"

# compile using respec2html (handling each version separately)
function respec2html {
  rm $2
  echo Running respec2html Nightmare for $3
  DEBUG=nightmare xvfb-run --server-args="-screen 0 1024x768x24" node respec/tools/respec2html.js --haltonerror --haltonwarn --src $1 --out $2
  {
  if [ ! -f $2 ]; then
      echo "respect2html Nightmare failed to generate index.html for $3"
      exit 2
  fi
  }
}

# old version using phantom still available in case of issues
function respec2htmlPhantom {
  rm $2
  echo Running respec2html Phantom for $3
  xvfb-run --server-args="-screen 0 1024x768x24" phantomjs --ssl-protocol=any respec/tools/respec2html-phantom.js -e -w $1 $2 15000
  {
  if [ ! -f $2 ]; then
      echo "respect2html Phantom failed to generate index.html for $3"
      exit 2
  fi
  }
}



echo Copying static files
cp -r ../0.1.0 .
cp -r ../0.2.0 .
cp -r ../0.2.1 .
cp -r ../0.2.2 .
cp -r ../0.2.3 .
cp -r ../0.2.4 .
cp -r ../0.3.0 .
cp -r ../EditorsDraft .
cp -r ../1.0 .
cp -r ../1.0/* .

cd ..

respec2html "file://$PWD/0.2.3/index.html" "$PWD/out/0.2.3/index.html" "0.2.3"
respec2html "file://$PWD/0.2.4/index.html" "$PWD/out/0.2.4/index.html" "0.2.4"
respec2html "file://$PWD/0.3.0/index.html" "$PWD/out/0.3.0/index.html" "0.3.0"
respec2html "file://$PWD/EditorsDraft/index.html" "$PWD/out/EditorsDraft/index.html" "EditorsDraft"
respec2html "file://$PWD/1.0/index.html" "$PWD/out/1.0/index.html" "1.0"

cp "$PWD/out/1.0/index.html" out/index.html

cd out

# curl "https://labs.w3.org/spec-generator/?type=respec&url=http://openactive.github.io/spec-template/index.html" > index.static.html;

# The first and only commit to this new Git repo contains all the
# files present with the commit message "Deploy to GitHub Pages".
git add .
git commit -m "Deploy to GitHub Pages - Static"


# Get the deploy key by using Travis's stored variables to decrypt deploy_key.enc
ENCRYPTED_KEY_VAR="encrypted_${ENCRYPTION_LABEL}_key"
ENCRYPTED_IV_VAR="encrypted_${ENCRYPTION_LABEL}_iv"
ENCRYPTED_KEY=${!ENCRYPTED_KEY_VAR}
ENCRYPTED_IV=${!ENCRYPTED_IV_VAR}
openssl aes-256-cbc -K $ENCRYPTED_KEY -iv $ENCRYPTED_IV -in ../deploy_key.enc -out ../deploy_key -d
chmod 600 ../deploy_key
eval `ssh-agent -s`
ssh-add ../deploy_key

# Force push from the current repo's master branch to the remote
# repo's gh-pages branch. (All previous history on the gh-pages branch
# will be lost, since we are overwriting it.) We redirect any output to
# /dev/null to hide any sensitive credential data that might otherwise be exposed.
git push --force --quiet ${GH_REF} master:gh-pages

cd ..
