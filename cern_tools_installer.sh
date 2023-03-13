#!/usr/bin/env bash

declare root_dir
declare required_packages_command
declare OS
declare VER
declare root_url
declare file_name
declare root_src_url="https://github.com/root-project/root/archive/refs/tags/v6-26-10.tar.gz"
declare geant_src_url="https://github.com/Geant4/geant4/archive/refs/tags/v11.1.1.tar.gz"
declare clhep_src_url="https://proj-clhep.web.cern.ch/proj-clhep/dist1/clhep-2.4.6.4.tgz"
declare xcerces_c_url="https://dlcdn.apache.org//xerces/c/3/sources/xerces-c-3.2.4.tar.gz"

declare root_install_time
declare geant_install_time
declare clhep_install_time
declare xercesc_install_time

CPU_COUNT=$(nproc --all)

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
ROOT_PKG_DIR="root"
GEANT_PKG_DIR="geant"
CLHEP_PKG_DIR="clhep"
XERCESC_PKG_DIR="xercesc"

clean_pkg_dirs() {
	if [ -d "$ROOT_PKG_DIR" ]; then
		rm -rf "$ROOT_PKG_DIR"
	fi

	if [ -d "$GEANT_PKG_DIR" ]; then
		rm -rf "$GEANT_PKG_DIR"
	fi

	if [ -d "$CLHEP_PKG_DIR" ]; then
		rm -rf "$CLHEP_PKG_DIR"
	fi

	if [ -d "$XERCESC_PKG_DIR" ]; then
		rm -rf "$XERCESC_PKG_DIR"
	fi
}

get_os_and_version() {
	if [ -f /etc/os-release ]; then
		# freedesktop.org and systemd
		. /etc/os-release
		OS=$NAME
		VER=$VERSION_ID
	elif type lsb_release >/dev/null 2>&1; then
		# linuxbase.org
		OS=$(lsb_release -si)
		VER=$(lsb_release -sr)
	elif [ -f /etc/lsb-release ]; then
		# For some versions of Debian/Ubuntu without lsb_release command
		. /etc/lsb-release
		OS=$DISTRIB_ID
		VER=$DISTRIB_RELEASE
	elif [ -f /etc/debian_version ]; then
		# Older Debian/Ubuntu/etc.
		OS=Debian
		VER=$(cat /etc/debian_version)
	elif [ -f /etc/SuSe-release ]; then
		echo "OS not supported"
	elif [ -f /etc/redhat-release ]; then
		echo "OS not supported yet"
	else
		# Fall back to uname, e.g. "Linux <version>", also works for BSD, etc.
		OS=$(uname -s)
		VER=$(uname -r)
	fi
	# echo $OS
	# echo $VER
}

get_filename_from_url() {
	file_name=$(echo "$1" | rev | cut -d/ -f1 | rev)
}

check_ubuntu_version() {
	if [[ $VER == "18."* ]]; then
		root_url="https://root.cern/download/root_v6.28.00.Linux-ubuntu18-x86_64-gcc7.5.tar.gz"
	elif [[ $VER == "20."* ]]; then
		root_url="https://root.cern/download/root_v6.28.00.Linux-ubuntu20-x86_64-gcc9.4.tar.gz"
	elif [[ $VER == "22."* ]]; then
		root_url="https://root.cern/download/root_v6.28.00.Linux-ubuntu22-x86_64-gcc11.3.tar.gz"
	else
		echo "Found incompatible version: '$VER'"
		exit -1
	fi

	echo "Found compatible version: '$VER'"
	required_packages_command="apt-get -y install gfortran libpcre3-dev doxygen \
								xlibmesa-glu-dev libglew-dev libftgl-dev \
								libmysqlclient-dev libfftw3-dev libcfitsio-dev \
								graphviz-dev libavahi-compat-libdnssd-dev \
								libldap2-dev python3-dev libxml2-dev libkrb5-dev \
								libgsl0-dev qtwebengine5-dev dpkg-dev cmake libx11-dev libxpm-dev \
								libxft-dev libxext-dev python3 libssl-dev binutils gcc g++ libxmu-dev"
	eval $required_packages_command
}

check_os() {
	get_os_and_version
	case $OS in
		Ubuntu) 
			echo "Found compatible OS: '$OS'"
			check_ubuntu_version
			;;
		*) 
			echo "'$OS' not supported"
			exit -1
			;; 
	esac
}

clean_up() {
	echo "Cleaning up..."
	rm $file_name
	echo "Done"
}

install_root() {
	start=`date +%s.%N`
	if ! mkdir -p "$ROOT_PKG_DIR" ; then
		echo "Can not create directory for Root files"
		exit -1
	fi

	cd $ROOT_PKG_DIR

	if wget "$root_url"; then
		get_filename_from_url $root_url
	else
		echo "Failed to download CERN Root binaries"
		exit -1
	fi

	if ! tar -xzf "$file_name"; then
		echo "Failed to extract CERN Root binaries"
		clean_up
		exit -1
	fi

	get_src_dir

	DIR="/opt/root"
	if [ -d "$DIR" ]; then
		rm -rf "$DIR"
	fi

	if ! mv -f -T "$file_name" /opt/root; then
		echo "Failed to install CERN Root binaries"
		exit -1
	fi

	if ! grep -q "source /opt/root/bin/thisroot.sh" /etc/bash.bashrc; then
		#Add root dir to path
		echo 'source /opt/root/bin/thisroot.sh' >> /etc/bash.bashrc
	fi
	# Source root for this session, maybe it is required later
	source /opt/root/bin/thisroot.sh
	clean_up
	cd $SCRIPT_DIR
	end=`date +%s.%N`
	root_install_time=$( echo "$end - $start" | bc -l )
}

get_src_dir() {
	for file in $(ls -d */ | grep -v build) 
	do 
		file_name=$file 
	done
}

install_clhep() {
	start=`date +%s.%N`
	if ! mkdir -p "$CLHEP_PKG_DIR" ; then
		echo "Can not create directory for CLHEP files"
		exit -1
	fi

	cd $CLHEP_PKG_DIR

	if wget "$clhep_src_url"; then
		get_filename_from_url $clhep_src_url
	else
		echo "Failed to download CLHEP source files"
		exit -1
	fi

	if ! tar -xzf "$file_name"; then
		echo "Failed to extract CLHEP source files"
		clean_up
		exit -1
	fi

	if ! mkdir -p build ; then
		echo "Can not create build directory for CLHEP files"
		exit -1
	fi

	# get source files directory
	get_src_dir

	cd build

	if ! cmake -DCMAKE_INSTALL_PREFIX=/opt/CLHEP/ -DCLHEP_BUILD_DOCS=ON "../$file_name/CLHEP"; then
		echo "Failed to execute cmake command"
		exit -1
	fi

	if ! make -j"$CPU_COUNT"; then
		echo "Failed to execute make command"
		exit -1
	fi

	if ! make test; then
		echo "Failed to execute make test command"
		exit -1
	fi

	if ! make install; then
		echo "Failed to execute make command"
		exit -1
	fi

	cd $SCRIPT_DIR
	end=`date +%s.%N`
	clhep_install_time=$( echo "$end - $start" | bc -l )
}

install_xerces_c() {
	start=`date +%s.%N`
	if ! mkdir -p "$XERCESC_PKG_DIR" ; then
		echo "Can not create directory for XERCES-C files"
		exit -1
	fi

	cd $XERCESC_PKG_DIR

	if wget "$xcerces_c_url"; then
		get_filename_from_url $xcerces_c_url
	else
		echo "Failed to download Xerces-C source files"
		exit -1
	fi

	if ! tar -xzf "$file_name"; then
		echo "Failed to extract Xerces-C source files"
		clean_up
		exit -1
	fi

	get_src_dir
	cd $file_name

	if ! ./configure --prefix=/opt/xerces-c; then
		echo "Failed to execute configure command"
		exit -1
	fi

	if ! make -j"$CPU_COUNT"; then
		echo "Failed to execute make command"
		exit -1
	fi

	if ! make install; then
		echo "Failed to execute make command"
		exit -1
	fi

	cd $SCRIPT_DIR
	end=`date +%s.%N`
	xercesc_install_time=$( echo "$end - $start" | bc -l )
}

install_geant() {
	start=`date +%s.%N`
	if ! mkdir -p "$GEANT_PKG_DIR" ; then
		echo "Can not create directory for CLHEP files"
		exit -1
	fi

	cd $GEANT_PKG_DIR

	if wget "$geant_src_url"; then
		get_filename_from_url $geant_src_url
	else
		echo "Failed to download CLHEP source files"
		exit -1
	fi

	if ! tar -xzf "$file_name"; then
		echo "Failed to extract Geant4 source files"
		clean_up
		exit -1
	fi

	if ! mkdir -p build ; then
		echo "Can not create build directory for Geant4 files"
		exit -1
	fi

	# get source files directory
	get_src_dir

	cd build

	if ! cmake -DCMAKE_INSTALL_PREFIX=/opt/geant4/ -DGEANT4_USE_GDML=ON -DXERCESC_ROOT_DIR=/opt/xerces-c/ -DGEANT4_INSTALL_DATA=ON -DGEANT4_USE_QT=ON -DGEANT4_USE_OPENGL_X11=ON -DGEANT4_USE_RAYTRACER_X11=ON -DGEANT4_USE_SYSTEM_CLHEP=ON -DCLHEP_INCLUDE_DIR=/opt/CLHEP/include/ -DCLHEP_LIBRARY=/opt/CLHEP/lib/ -DGEANT4_INSTALL_EXAMPLES=ON -DCLHEP_ROOT_DIR=/opt/CLHEP/ -DGEANT4_BUILD_MULTITHREADED=ON "../$file_name/"; then
		echo "Failed to execute cmake command"
		exit -1
	fi

	if ! make -j"$CPU_COUNT"; then
		echo "Failed to execute make command"
		exit -1
	fi

	if ! make install; then
		echo "Failed to execute make command"
		exit -1
	fi

	if ! grep -q "source /opt/geant4/bin/geant4.sh" /etc/bash.bashrc; then
		#Add geant dir to path
		echo 'source /opt/geant4/bin/geant4.sh' >> /etc/bash.bashrc
	fi

	cd $SCRIPT_DIR
	end=`date +%s.%N`
	geant_install_time=$( echo "$end - $start" | bc -l )
}

check_os
clean_pkg_dirs

# script needs sudo rights
if [ $EUID != 0 ]; then
    sudo "$0" "$@"
    exit $?
fi

if [ -z ${ROOTSYS+x} ]; then 
	echo "ROOTSYS variable not set. Assuming CERN Root is not installed"; 
else 
	root_dir=$ROOTSYS
	echo "CERN Root found in directory '$ROOTSYS'"; 
fi

if [ -d "$ROOTSYS" ]; then
	echo "Root files found"
else
	echo "Root files not found"
	install_root
fi

install_clhep
install_xerces_c
install_geant

echo "Root install time: $root_install_time"
echo "Geant install time: $geant_install_time"
echo "CLHEP install time: $clhep_install_time"
echo "Xerces-C install time: $xercesc_install_time"

echo "Installing done"