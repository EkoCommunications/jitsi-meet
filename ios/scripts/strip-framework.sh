# Strip framework script copy from ImmglyKit.framework strip-framework.sh
# with some modification

cd "${BUILT_PRODUCTS_DIR}/${FRAMEWORKS_FOLDER_PATH}"

frameworks=("JitsiMeet" "WebRTC")
input_files=("${SCRIPT_INPUT_FILE_0}" "${SCRIPT_INPUT_FILE_1}")

# Signs a binary with the provided identity
codesign() {
  echo "Code Signing ${1} with Identity ${EXPANDED_CODE_SIGN_IDENTITY_NAME}"
  /usr/bin/codesign --force --sign ${EXPANDED_CODE_SIGN_IDENTITY} --preserve-metadata=identifier,entitlements "${1}"
}

# Strips a binary of any architecture not specified in ${VALID_ARCHS}
strip_binary() {
  binary=${1}

  # Get architectures of binary
  archs="$(lipo -info "${binary}" | rev | cut -d ':' -f1 | rev)"
  stripped_archs=""

  for arch in ${archs}; do
    if ! [[ "${VALID_ARCHS}" == *"${arch}"* ]]; then
      # Strip non-valid architecture in-place
      lipo -remove "${arch}" -output "${binary}" "${binary}" || exit 1
      stripped_archs="${stripped_archs} ${arch}"
    fi
  done

  echo "${stripped_archs}"
}

for framework in "${frameworks[@]}"; do
  framework_folder="./${framework}.framework"

  if ! [ -d "$framework_folder" ]; then
    continue
  fi

  if [[ "${ACTION}" == "install" ]]; then
    # Removing files that are not needed in the final product
    for file in strip-framework.sh; do
      if [[ -e "${framework_folder}/${file}" ]]; then
        echo "Removing ${file} from product"
        rm -f "${framework_folder}/${file}"
      fi
    done

    # Move BCSymbolMaps to product's folder
    echo "Copying BCSymbolMaps to product's folder"
    find "${framework_folder}/BCSymbolMaps" -name '*.bcsymbolmap' -type f -exec mv {} "${CONFIGURATION_BUILD_DIR}" \;
  fi

  # BCSymbolMaps are not needed at this point because they have either been moved to the archive
  # or we're not creating an archive and thus don't need them anyway
  rm -rf "${framework_folder}/BCSymbolMaps"

  # Xcode currently does not support uploading binaries that contain non-device architectures,
  # so we are removing them from the framework's binary here
  framework_binary="${framework_folder}/${framework}"

  echo "Stripping ${framework_binary} of unwanted architectures"
  stripped_archs="$(strip_binary "${framework_binary}")"

  if [[ -n "${stripped_archs}" ]]; then
    echo "Stripped the framework of the following architectures: ${stripped_archs}"

    # We now have to codesign the binary again
    if [[ "${CODE_SIGNING_REQUIRED}" == "YES" ]]; then
      codesign "${framework_binary}"
    fi
  fi
done

# Check if input file was specified for script
for input_file in "${input_files[@]}"; do
  if [[ -n "${input_file}" ]]; then
    dSYM="${input_file}"
    dSYM_folder=$(basename "${dSYM}")
    framework=${dSYM_folder%".framework.dSYM"}
    dSYM_binary="${dSYM}/Contents/Resources/DWARF/${framework}"

    # Check if file exists and is actually a dSYM
    if [[ "$(file "${dSYM_binary}")" == *"dSYM companion file"* ]]; then
      # Copy dSYM to product's folder
      echo "Copying ${dSYM} to product's directory"
      cp -rf "${dSYM}" "${BUILT_PRODUCTS_DIR}"

      # Strip dSYM binary
      dSYM_binary="${BUILT_PRODUCTS_DIR}/${dSYM_folder}/Contents/Resources/DWARF/${framework}"

      echo "Stripping ${dSYM_binary} of unwanted architectures"
      stripped_archs_dSYM="$(strip_binary "${dSYM_binary}")"

      if [[ -n "${stripped_archs_dSYM}" ]]; then
        echo "Stripped the dSYM of the following architectures: ${stripped_archs_dSYM}"
      fi
    fi
  fi
done
