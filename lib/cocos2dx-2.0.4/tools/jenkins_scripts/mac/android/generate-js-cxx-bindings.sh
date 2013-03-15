#!/bin/bash

# Generate JS bindings for Cocos2D-X
# ... using Android NDK system headers
# ... and automatically update submodule references
# ... and push these changes to remote repos

# Dependencies
#
# For bindings generator:
# (see ../../../tojs/genbindings.sh
# ... for the defaults used if the environment is not customized)
#
#  * $PYTHON_BIN
#  * $CLANG_ROOT
#  * $NDK_ROOT
#
# For automatically pushing changes:
#
#  * REMOTE_AUTOGEN_BINDINGS_REPOSITORY
#  * REMOTE_COCOS2DX_REPOSITORY
#  * Note : Ensure you have commit access to above repositories
#  * COCOS2DX_PULL_BASE
#  * hub
#     * see http://defunkt.io/hub/
#  * Ensure that hub has an OAuth token to REMOTE_COCOS2DX_REPOSITORY
#     * see http://defunkt.io/hub/hub.1.html#CONFIGURATION

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
COCOS2DX_ROOT="$DIR"/../../../..
GENERATED_WORKTREE="$COCOS2DX_ROOT"/scripting/javascript/bindings/generated

if [ -z "${HUB+aaa}" ]; then
# ... if HUB is not set, use "$HOME/bin/hub"
    HUB="$HOME/bin/hub"
fi

# Update cocos2d-x repo
# It needs to be updated in Jenkins command before executing this script.
#pushd "$COCOS2DX_ROOT"

#git checkout -f
#git checkout gles20
#git pull upstream gles20
#rm -rf "$GENERATED_WORKTREE"
#git submodule update --init

#popd

# Update submodule of auto-gen JSBinding repo.
pushd "$GENERATED_WORKTREE"

git checkout -f
git checkout master
git pull origin master

popd

# Exit on error
set -e

# 1. Generate JS bindings
COCOS2DX_ROOT="$COCOS2DX_ROOT" /bin/bash ../../../tojs/genbindings.sh

echo
echo Bindings generated successfully
echo

if [ -z "${REMOTE_AUTOGEN_BINDINGS_REPOSITORY+aaa}" ]; then
    echo
    echo Environment variable must be set REMOTE_AUTOGEN_BINDINGS_REPOSITORY
    echo This script expects to automatically push changes
    echo to this repo
    echo example
    echo  REMOTE_AUTOGEN_BINDINGS_REPOSITORY=\"git@github.com:folecr/cocos2dx-autogen-bindings.git\"
    echo  REMOTE_AUTOGEN_BINDINGS_REPOSITORY=\"\$HOME/test/cocos2dx-autogen-bindings\"
    echo
    echo Exiting with failure.
    echo
    exit 1
fi

if [ -z "${COMMITTAG+aaa}" ]; then
# ... if COMMITTAG is not set, use this machine's hostname
    COMMITTAG=`hostname -s`
fi

echo
echo Using "'$COMMITTAG'" in the commit messages
echo

ELAPSEDSECS=`date +%s`
echo Using "$ELAPSEDSECS" in the branch names for pseudo-uniqueness

GENERATED_BRANCH=autogeneratedbindings_"$ELAPSEDSECS"


# 2. In JSBindings repo, Check if there are any files that are different from the index

pushd "$GENERATED_WORKTREE"

# Run status to record the output in the log
git status

echo
echo Comparing with origin/master ...
echo

# Don't exit on non-zero return value
set +e

git diff --stat --exit-code origin/master

DIFF_RETVAL=$?
if [ $DIFF_RETVAL -eq 0 ]
then
    echo
    echo "No differences in generated files"
    echo "Exiting with success."
    echo
    exit 0
else
    echo
    echo "Generated files differ from origin/master. Continuing."
    echo
fi

# Exit on error
set -e

# 3. In JSBindings repo, Check out a branch named "autogeneratedbindings" and commit the auto generated bindings to it
git checkout -b "$GENERATED_BRANCH"
git add --verbose README cocos2dx.cpp cocos2dx.hpp cocos2dxapi.js
git commit --verbose -m "$COMMITTAG : autogenerated bindings"

# 4. In JSBindings repo, Push the commit with generated bindings to "master" of the auto generated bindings repository
git push --verbose "$REMOTE_AUTOGEN_BINDINGS_REPOSITORY" "$GENERATED_BRANCH":master

popd

if [ -z "${REMOTE_COCOS2DX_REPOSITORY+aaa}" ]; then
    echo
    echo Environment variable is not set REMOTE_COCOS2DX_REPOSITORY
    echo This script will NOT automatically push changes
    echo unless this variable is set.
    echo example
    echo  REMOTE_COCOS2DX_REPOSITORY=\"git@github.com:cocos2d/cocos2d-x.git\"
    echo  REMOTE_COCOS2DX_REPOSITORY=\"\$HOME/test/cocos2d-x\"
    echo
    echo Exiting with success.
    echo
    exit 0
fi

COCOS_BRANCH=updategeneratedsubmodule_"$ELAPSEDSECS"

pushd "${DIR}"

# 5. In Cocos2D-X repo, Checkout a branch named "updategeneratedsubmodule" Update the submodule reference to point to the commit with generated bindings
cd "${COCOS2DX_ROOT}"
git add scripting/javascript/bindings/generated
git checkout -b "$COCOS_BRANCH"
git commit -m "$COMMITTAG : updating submodule reference to latest autogenerated bindings"

# 6. In Cocos2D-X repo, Push the commit with updated submodule to "gles20" of the cocos2d-x repository
git push "$REMOTE_COCOS2DX_REPOSITORY" "$COCOS_BRANCH"

if [ -z "${COCOS2DX_PULL_BASE+aaa}" ]; then
    echo
    echo Environment variable is not set COCOS2DX_PULL_BASE
    echo This script will NOT automatically generate pull requests
    echo unless this variable is set.
    echo example
    echo  COCOS2DX_PULL_BASE=\"cocos2d/cocos2d-x:gles20\"
    echo  COCOS2DX_PULL_BASE=\"username/repository:branch\"
    echo
    echo Exiting with success.
    echo
    exit 0
fi

# 7. 
${HUB} pull-request "$COMMITTAG : updating submodule reference to latest autogenerated bindings" -b "$COCOS2DX_PULL_BASE" -h "$COCOS_BRANCH"

popd