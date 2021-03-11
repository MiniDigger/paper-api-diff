#!/usr/bin/env bash

set -euo pipefail

jdiff_version='1.1.0'
set -x

get_maven_sources() {
  local -r host="${1?Missing host}"
  local -r nexus_version="${2?Missing nexus_version}"
  local -r group_id="${3?Missing group_id}"
  local -r artifact_id="${4?Missing artifact_id}"
  local -r destination="${5?Missing destination}"
  if [ "${nexus_version}" -eq 2 ]; then
    local -r url="${host}/service/local/artifact/maven/content?r=snapshots&g=${group_id}&a=${artifact_id}&v=LATEST&c=sources"
  elif [ "${nexus_version}" -eq 3 ]; then
    local -r url="${host}/service/rest/v1/search/assets/download?sort=version&repository=maven-snapshots&maven.groupId=${group_id}&maven.artifactId=${artifact_id}&maven.classifier=sources"
  else
    printf 'Wrong nexus version specified: %s\n' "${nexus_version}"
    return 1
  fi

  local -r curl_args=(
    -s # Silent
    -X GET
    -L # Follow location redirects - important for v3!
    "${url}"
    -o "${destination}"
  )
  curl "${curl_args[@]}"
}



# download requirements
curl -L -o jdiff.zip https://pilotfiber.dl.sourceforge.net/project/javadiff/javadiff/jdiff%20"${jdiff_version}"/jdiff-"${jdiff_version}".zip
unzip jdiff.zip

# gen xml for paper
get_maven_sources 'https://papermc.io/repo' 3 'com.destroystokyo.paper' 'paper-api' paper-sources.jar
unzip paper-sources.jar -d paper-sources
mkdir paper
javadoc -doclet jdiff.JDiff -docletpath jdiff-"${jdiff_version}"/jdiff.jar -apiname Paper -apidir paper -sourcepath paper-sources io.papermc.paper org.bukkit org.spigotmc com.destroystokyo.paper
sed -i 's/\& org.bukkit.Keyed/\&amp; org.bukkit.Keyed/g' paper/Paper.xml
# gen xml for spigot
get_maven_sources 'https://hub.spigotmc.org/nexus' 2 'org.spigotmc' 'spigot-api' spigot-sources.jar
unzip spigot-sources.jar -d spigot-sources
mkdir spigot
javadoc -doclet jdiff.JDiff -docletpath jdiff-"${jdiff_version}"/jdiff.jar -apiname Spigot -apidir spigot -sourcepath spigot-sources org.bukkit org.spigotmc
sed -i 's/\& org.bukkit.Keyed/\&amp; org.bukkit.Keyed/g' spigot/Spigot.xml
# diff
mkdir output
javadoc -doclet jdiff.JDiff -docletpath jdiff-"${jdiff_version}"/jdiff.jar:jdiff-"${jdiff_version}"/xerces.jar -oldapi Spigot -oldapidir spigot -newapi Paper -newapidir paper -javadocold https://hub.spigotmc.org/javadocs/bukkit/ -javadocnew https://papermc.io/javadocs/paper/1.16/ -doctitle "PAPER TEST" -stats -d output -sourcepath paper-sources io.papermc.paper org.bukkit org.spigotmc com.destroystokyo.paper

