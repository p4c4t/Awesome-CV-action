#!/bin/bash

set -e

main() {
  echo "" # see https://github.com/actions/toolkit/issues/168

  sanitize "${GITHUB_TOKEN}" "GITHUB_TOKEN"
  # INPUT_FILE_NAME is now optional - if not provided, we'll compile all .tex files in root

  arrBRANCH_NAME=(${GITHUB_REF//// })
  BRANCH_NAME=${arrBRANCH_NAME[@]:(-1)} 
  IS_MASTER=false
  if [ "$BRANCH_NAME" = "master" ] || [ "$BRANCH_NAME" = "main" ]; then
    IS_MASTER=true
  fi

  TAG_NAME=v$(date +%m-%d-%Y.%H.%M)
  if [ $IS_MASTER = false ]; then
    TAG_NAME=${BRANCH_NAME}_${TAG_NAME}
  fi

  # Determine which .tex files to process
  if [ ! -z "${INPUT_FILE_NAME}" ]; then
    # Single file mode (backward compatibility)
    TEX_FILES=("$INPUT_FILE_NAME")
    echo "Single file mode: processing $INPUT_FILE_NAME"
  else
    # Multi-file mode: find all .tex files in root directory
    mapfile -t TEX_FILES < <(find . -maxdepth 1 -name "*.tex" -type f | sed 's|^\./||')
    if [ ${#TEX_FILES[@]} -eq 0 ]; then
      echo "ERROR: No .tex files found in repository root"
      exit 1
    fi
    echo "Multi-file mode: found ${#TEX_FILES[@]} .tex files: ${TEX_FILES[*]}"
  fi

  INPUT_EXTENSION="tex"
  OUTPUT_EXTENSION="pdf"

  if ! uses "${INPUT_LATEST_TAG}"; then
    INPUT_LATEST_TAG="true"
  fi

  echo "=====> INPUTS <====="
  if [ ! -z "${INPUT_FILE_NAME}" ]; then
    echo "FILE_NAME: $INPUT_FILE_NAME"
  else
    echo "TEX_FILES: ${TEX_FILES[*]}"
  fi
  echo "GENERATED TAG_NAME: $TAG_NAME"
  echo "GITHUB REPOSITORY: $GITHUB_REPOSITORY"
  echo "BRANCH: $BRANCH_NAME"
  echo "IS_MASTER: $IS_MASTER"
  echo "INPUT_EXTENSION: $INPUT_EXTENSION"
  echo "OUTPUT_EXTENSION: $OUTPUT_EXTENSION"
  echo "GITHUB_EVENT_NAME: ${GITHUB_EVENT_NAME:-'not set'}"
  echo "GITHUB_WORKFLOW: ${GITHUB_WORKFLOW:-'not set'}"
  echo "GITHUB_HEAD_REF: ${GITHUB_HEAD_REF:-'not set'}"
  echo "GITHUB_BASE_REF: ${GITHUB_BASE_REF:-'not set'}"
  echo "=====> / INPUTS <====="
  echo ""

  # Run chktex validation first
  echo "==> RUNNING CHKTEX VALIDATION"
  set +e
  for tex_file in "${TEX_FILES[@]}"; do
    echo "Validating $tex_file..."
    chktex -q "$tex_file"
    if [ ! $? -eq 0 ]; then
      echo "ERROR : ❌ > CHKTEX VALIDATION FAILED FOR $tex_file ‼️"
      exit 1
    else
      echo "✅   chktex validation passed for $tex_file"
    fi
  done
  set -e

  # Process resume/* files and create .tex artifacts
  echo "==> PROCESSING RESUME INCLUDES AND CREATING .TEX ARTIFACTS"
  
  declare -a TEX_ARTIFACTS=()
  
  for tex_file in "${TEX_FILES[@]}"; do
    TEX_ARTIFACT=${tex_file/.tex/_artifact.tex}
    TEX_ARTIFACTS+=("$TEX_ARTIFACT")
    
    # Copy the main file as the base for the artifact
    cp "$tex_file" "$TEX_ARTIFACT"
    
    # If resume/ directory exists, process all .tex files in it
    if [ -d "resume" ]; then
      echo "Found resume/ directory, processing includes for $tex_file..."
      
      # Create a temporary directory for processing
      mkdir -p temp_resume_processing
      
      # Copy all resume files to temp directory for processing
      cp -r resume/* temp_resume_processing/ 2>/dev/null || true
      
      # Find all .tex files in resume/ directory and append them to artifact
      find resume -name "*.tex" -type f | while read -r resume_file; do
        echo "% === Content from $resume_file ===" >> "$TEX_ARTIFACT"
        cat "$resume_file" >> "$TEX_ARTIFACT"
        echo "" >> "$TEX_ARTIFACT"
      done
      
      echo "✅   Created .tex artifact: $TEX_ARTIFACT"
    else
      echo "No resume/ directory found, artifact for $tex_file is copy of main file"
    fi
  done

  # Compile all .tex files
  echo "==> TRYING TO GENERATE THE DOCUMENTS"
  
  declare -a OUTPUT_FILES=()
  
  set +e
  for tex_file in "${TEX_FILES[@]}"; do
    OUTPUT_FILE=${tex_file/$INPUT_EXTENSION/$OUTPUT_EXTENSION}
    OUTPUT_FILES+=("$OUTPUT_FILE")
    
    echo "Compiling $tex_file to $OUTPUT_FILE..."
    xelatex -file-line-error -halt-on-error -interaction=nonstopmode "$tex_file"
    if [ ! $? -eq 0 ]; then
      echo "ERROR : ❌ > THE PDF DOCUMENT $OUTPUT_FILE CAN'T BE GENERATED‼️"
      exit 1
    else
      echo "✅   $OUTPUT_FILE was successfully generated"
    fi
  done
  set -e


  createRelease $GITHUB_REPOSITORY $GITHUB_TOKEN $TAG_NAME "${OUTPUT_FILES[@]}" "${TEX_ARTIFACTS[@]}"

  if usesBoolean "${INPUT_LATEST_TAG}" && usesBoolean "${IS_MASTER}"; then
    cleanLatest $GITHUB_REPOSITORY $GITHUB_TOKEN
    createRelease $GITHUB_REPOSITORY $GITHUB_TOKEN "latest" "${OUTPUT_FILES[@]}" "${TEX_ARTIFACTS[@]}"
  fi

   echo "TAG_NAME=${TAG_NAME}" >> $GITHUB_OUTPUT 

}

cleanLatest() {
  echo "====> CLEANING LATEST RELEASE <===="
  LATEST_RELEASE_ID=$(curl -s -X GET --url https://api.github.com/repos/$1/releases/tags/latest --header "authorization: token $2" | jq -r ".id")
  if [ ! -z "${LATEST_RELEASE_ID}" ]; then
    echo "-> DELETE latest tag"
    curl -sS -X DELETE --url https://api.github.com/repos/$1/git/refs/tags/latest --header "authorization: token $2" 
    echo "-> DELETE latest release $LATEST_RELEASE_ID"
    curl -sS -X DELETE --url https://api.github.com/repos/$1/releases/$LATEST_RELEASE_ID --header "authorization: token $2" 
  fi
}

createRelease() {
  local repo="$1"
  local token="$2"
  local tag_name="$3"
  shift 3
  
  # Collect all remaining arguments as files
  local all_args=("$@")
  local num_args=${#all_args[@]}
  local mid_point=$((num_args / 2))
  
  # Split args into PDF files and TEX artifacts
  local pdf_files=("${all_args[@]:0:$mid_point}")
  local tex_files=("${all_args[@]:$mid_point}")
  
  echo "==> CREATE TAG $tag_name"
  OUTPUT_TAG="$(curl -sS -X POST --url https://api.github.com/repos/$repo/git/refs --header "authorization: token $token" --header 'content-type: application/json' \
  --data '{
    "ref": "refs/tags/'"$tag_name"'",
    "sha": "'"$GITHUB_SHA"'"
  }')"
  responseHandler "$OUTPUT_TAG" 

  # Gather comprehensive release information
  COMMIT_MESSAGE=$(git log -1 --pretty=format:"%s" 2>/dev/null || echo "No commit message available")
  COMMIT_AUTHOR=$(git log -1 --pretty=format:"%an" 2>/dev/null || echo "Unknown author")
  COMMIT_SHA_SHORT=$(echo $GITHUB_SHA | cut -c1-7)
  
  # Build comprehensive release body
  RELEASE_BODY="📄 **Resume Build Information**

**Generated:** $(date +%m-%d-%Y\ at\ %H:%M\ UTC)
**Branch:** $BRANCH_NAME
**Commit:** [\`$COMMIT_SHA_SHORT\`](https://github.com/$repo/commit/$GITHUB_SHA)
**Author:** $COMMIT_AUTHOR
**Files processed:** ${#pdf_files[@]}

**Latest Changes:**
\`$COMMIT_MESSAGE\`"

  # Add additional context if available from GitHub event
  if [ ! -z "$GITHUB_EVENT_NAME" ]; then
    RELEASE_BODY="$RELEASE_BODY

**Trigger:** $GITHUB_EVENT_NAME"
  fi

  # Add pull request information if available
  if [ ! -z "$GITHUB_HEAD_REF" ] && [ ! -z "$GITHUB_BASE_REF" ]; then
    RELEASE_BODY="$RELEASE_BODY
**Pull Request:** $GITHUB_HEAD_REF → $GITHUB_BASE_REF"
  fi

  # Add workflow information
  if [ ! -z "$GITHUB_WORKFLOW" ]; then
    RELEASE_BODY="$RELEASE_BODY
**Workflow:** $GITHUB_WORKFLOW"
  fi

  echo "===> CREATE RELEASE $tag_name"
  OUTPUT_RELEASE="$(curl -sS -X POST --url https://api.github.com/repos/$repo/releases --header "authorization: token $token" --header 'content-type: application/json' \
  --data '{
    "tag_name": "'"$tag_name"'",
    "name": "'"$tag_name"'",
    "body": "'"$(echo "$RELEASE_BODY" | sed 's/"/\\"/g' | tr '\n' '\\' | sed 's/\\/\\n/g')"'"
  }')"
  responseHandler "$OUTPUT_RELEASE" 
  RELEASE_ID=$(echo $OUTPUT_RELEASE | jq -r '.id')

  # Upload all PDF files
  for pdf_file in "${pdf_files[@]}"; do
    echo "====> UPLOAD PDF ASSET TO RELEASE $RELEASE_ID ($tag_name): $pdf_file"
    UPLOAD_URL="https://uploads.github.com/repos/$repo/releases/$RELEASE_ID/assets?name=$pdf_file"
    OUTPUT_UPLOAD=$(curl -sS -X POST --header "authorization: token $token" --header 'content-type: application/pdf' --url $UPLOAD_URL -F "data=@$pdf_file")
    responseHandler "$OUTPUT_UPLOAD" 
    
    PDF_ASSET_URL="https://github.com/$repo/releases/download/$tag_name/$pdf_file"
    echo -e "=====> 🚀 -> Your PDF $pdf_file is available at $PDF_ASSET_URL"
  done

  # Upload all TEX artifact files
  for tex_file in "${tex_files[@]}"; do
    if [ ! -z "${tex_file}" ] && [ -f "${tex_file}" ]; then
      echo "====> UPLOAD TEX ARTIFACT TO RELEASE $RELEASE_ID ($tag_name): $tex_file"
      TEX_UPLOAD_URL="https://uploads.github.com/repos/$repo/releases/$RELEASE_ID/assets?name=$tex_file"
      TEX_OUTPUT_UPLOAD=$(curl -sS -X POST --header "authorization: token $token" --header 'content-type: application/x-tex' --url $TEX_UPLOAD_URL -F "data=@$tex_file")
      responseHandler "$TEX_OUTPUT_UPLOAD" 
      
      TEX_ASSET_URL="https://github.com/$repo/releases/download/$tag_name/$tex_file"
      echo -e "=====> 🚀 -> Your TEX artifact $tex_file is available at $TEX_ASSET_URL"
    fi
  done
}

responseHandler() {
  if echo "${1}" | jq -e 'has("message")' > /dev/null; then
    MSG=$(echo ${1} | jq -r '.message')
    >&2 echo -e "-> ERROR the receive message is : \\n ${MSG}"
    exit 1
  fi
}

uses() {
  [ ! -z "${1}" ]
}

usesBoolean() {
  [ ! -z "${1}" ] && [ "${1}" = "true" ]
}

sanitize() {
  if [ -z "${1}" ]; then
    >&2 echo "Unable to find the ${2}. Did you set with.${2}?"
    exit 1
  fi
}

main
