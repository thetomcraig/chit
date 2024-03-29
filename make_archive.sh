# For making a new archive of the entire project
# To do a release: 
# 1. ./make_release.sh <VERSION_NUMBER>
# 2. "homebrew-tap" repo -> chit.rb -> update url string -> "...archive/chit.<VERSION_NUMBER>.tar.gz?raw=true"
# 3. "homebrew-tap" repo -> chit.rb -> update url string -> "sha256 <SHA_FROM_GIT>"

version="${1}"
archive_name="chit.${version}.tar.gz"

tar -zcvf "${archive_name}" chit.sh iterm example_theme_definitions kitty_themes
mv "${archive_name}" archive

echo "${version}" > version

git add archive
git add version
git commit -m "Add version ${version} archive"
git push

echo "\n"
echo "\n"
echo "PUSHED VERSION: ${version}"
echo "COPY BELOW CHECKSUM TO CLIPBOARD:"
echo $(shasum -a 256 archive/"${archive_name}" | awk '{print $1}')
