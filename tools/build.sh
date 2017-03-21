#!/usr/bin/env bash

if [ "$REPO_ROOT" == "" ] ; then REPO_ROOT="$(readlink -f $(dirname $(readlink -f $0))/../)" ; fi

# check for build environment, tools and libraries

if [ "$(command -v cmake)" == "" ] ; 
then 
	echo "error: cmake not found." 1>&2
	exit -1
fi

if [ ! -e /etc/os-release ] ;
then
	echo "error: cannot determine distro." 1>&2
	exit -1
else
	source /etc/os-release
	echo "current distro: $ID $VERSION_ID"
fi

# check if we have dotnet sdk
if [ ! -e "$REPO_ROOT/tools/dotnet" ];
then
	echo "dotnet sdk not found, downloading."
	case "$ID $VERSION_ID" in
	"ubuntu 16.04")
		dotnet_url="https://dotnetcli.blob.core.windows.net/dotnet/Sdk/master/dotnet-dev-ubuntu.16.04-x64.latest.tar.gz"
		;;
	*)
		echo "error: unsupported distro." 1>&2
		exit -1
		;;
	esac
	mkdir "$REPO_ROOT/tools/dotnet"
	wget $dotnet_url -O - | tar -xz -C "$REPO_ROOT/tools/dotnet"
fi
export PATH="$REPO_ROOT/tools/dotnet":$PATH

# build Trinity.C
build_trinity_c()
{
	echo "Building Trinity.C"
	mkdir -p "$REPO_ROOT/bin/coreclr" && pushd "$_" || exit -1
	cmake "$REPO_ROOT/src/Trinity.C" || exit -1
	make || exit -1
	# copy native Trinity.C for Windows-CoreCLR
	cp "$REPO_ROOT/lib/Trinity.dll" "$REPO_ROOT/bin/coreclr/Trinity.dll" || exit -1
	popd
}

# build Trinity.TSL
build_trinity_tsl()
{
	echo "Building Trinity.TSL"
	mkdir -p "$REPO_ROOT/bin/tsl" && pushd "$_" || exit -1
	cmake "$REPO_ROOT/src/Trinity.TSL" || exit -1
	make || exit -1
	# copy native Trinity.C for Windows-CoreCLR
	cp "Trinity.TSL.CodeGen" "$REPO_ROOT/bin/coreclr/" || exit -1
	popd
}

# build Trinity.Core
build_trinity_core()
{
	echo "Building Trinity.Core"
	pushd "$REPO_ROOT/src/Trinity.Core"
	dotnet restore Trinity.Core.NETStandard.sln || exit -1
	dotnet build Trinity.Core.NETStandard.sln || exit -1
	dotnet pack Trinity.Core.NETStandard.sln || exit -1
	popd
}

# register local nuget repo, remove GraphEngine.CoreCLR packages in the cache.
setup_nuget_repo()
{
	nuget_repo_name="Graph Engine OSS Local" 
	if [ "$(grep "$nuget_repo_name" ~/.nuget/NuGet/NuGet.Config)" == "" ];
	then
		echo "registering NuGet local repository '$nuget_repo_name'."
		nuget_repo_location=$(printf "%q" "$REPO_ROOT/bin/coreclr")
		sed -i "s#  </packageSources>#    <add key=\"$nuget_repo_name\" value=\"$nuget_repo_location\" \/>\n  <\/packageSources>#g" ~/.nuget/NuGet/NuGet.Config
	fi
	echo "remove local package cache."
	rm -rf ~/.nuget/packages/graphengine.coreclr
}

build_trinity_c
build_trinity_tsl
build_trinity_core
setup_nuget_repo

