#!/bin/sh

#作者：康林
#参数:
#    $1:编译目标(android、windows_msvc、windows_mingw、unix)
#    $2:源码的位置 

#运行本脚本前,先运行 build_$1_envsetup.sh 进行环境变量设置,需要先设置下面变量:
#   RABBITIM_BUILD_TARGERT   编译目标（android、windows_msvc、windows_mingw、unix)
#   RABBITIM_BUILD_PREFIX=`pwd`/../${RABBITIM_BUILD_TARGERT}  #修改这里为安装前缀
#   RABBITIM_BUILD_SOURCE_CODE    #源码目录
#   RABBITIM_BUILD_CROSS_PREFIX     #交叉编译前缀
#   RABBITIM_BUILD_CROSS_SYSROOT  #交叉编译平台的 sysroot

set -e
QT_CLEAN="clean"
HELP_STRING="Usage $0 PLATFORM (android|windows_msvc|windows_mingw|unix) [SOURCE_CODE_ROOT_DIRECTORY]"

case $1 in
    android|windows_msvc|windows_mingw|unix)
    RABBITIM_BUILD_TARGERT=$1
    ;;
    *)
    echo "${HELP_STRING}"
    exit 1
    ;;
esac

if [ -z "${RABBITIM_BUILD_PREFIX}" ]; then
    echo ". `pwd`/build_envsetup_${RABBITIM_BUILD_TARGERT}.sh"
    . `pwd`/build_envsetup_${RABBITIM_BUILD_TARGERT}.sh
fi

if [ -n "$2" ]; then
    RABBITIM_BUILD_SOURCE_CODE=$2
else
    RABBITIM_BUILD_SOURCE_CODE=${RABBITIM_BUILD_PREFIX}/../src/qt5
fi

CUR_DIR=`pwd`

#下载源码:
if [ ! -d ${RABBITIM_BUILD_SOURCE_CODE} ]; then
    QT_VERSION=5.4.1
    cd ${RABBITIM_BUILD_SOURCE_CODE}
    if [ -n "$RABBITIM_USE_REPOSITORIES" ]; then
        echo "git clone https://git.gitorious.org/qt/qt5.git ${RABBITIM_BUILD_SOURCE_CODE}"
        git clone https://git.gitorious.org/qt/qt5.git ${RABBITIM_BUILD_SOURCE_CODE}
        git checkout ${QT_VERSION}
        perl init-repository -f --branch -no-qtcanvas3d -no-qt3d
        cd ${CUR_DIR}
    else
        wget http://ftp.jaist.ac.jp/pub/qtproject/archive/qt/5.4/${QT_VERSION}/single/qt-everywhere-opensource-src-${QT_VERSION}.tar.gz
        tar xzf qt-everywhere-opensource-src-${QT_VERSION}.tar.gz
        RABBITIM_BUILD_SOURCE_CODE=${RABBITIM_BUILD_SOURCE_CODE}/qt-everywhere-opensource-src-${QT_VERSION} 
    fi
fi

cd ${RABBITIM_BUILD_SOURCE_CODE}

#清理
if [ -n "$QT_CLEAN" ]; then
    if [ -d ".git" ]; then
        qtrepotools/bin/qt5_tool -c

        #git clean -xdf
        #git submodule foreach --recursive "git clean -dfx"
        #echo $1
        #for i in `ls $1`;
        #do
        #    	if [ -d $1/${i} ]; then
        #            	echo "$1/${i}"
        #                cd $1/${i}
        #    	        git clean -xdf
        #        fi
        #done
    else
        if [ -f Makefile ]; then
            make distclean
            rm -f Makefile
        fi
    fi
    rm -fr ${RABBITIM_BUILD_PREFIX}/qt
fi

echo "RABBITIM_BUILD_SOURCE_CODE:$RABBITIM_BUILD_SOURCE_CODE"
echo "CUR_DIR:`pwd`"
echo "RABBITIM_BUILD_PREFIX:$RABBITIM_BUILD_PREFIX"
echo "RABBITIM_BUILD_HOST:$RABBITIM_BUILD_HOST"
echo "RABBITIM_BUILD_CROSS_HOST:$RABBITIM_BUILD_CROSS_HOST"
echo "RABBITIM_BUILD_CROSS_PREFIX:$RABBITIM_BUILD_CROSS_PREFIX"
echo "RABBITIM_BUILD_CROSS_SYSROOT:$RABBITIM_BUILD_CROSS_SYSROOT"
echo ""

echo "configure ..."

CONFIG_PARA="-opensource -confirm-license -nomake examples -nomake tests -no-compile-examples"
CONFIG_PARA="${CONFIG_PARA} -no-sql-sqlite -no-sql-odbc"
CONFIG_PARA="${CONFIG_PARA} -skip qtdoc -skip qtwebkit-examples -skip qt3d -skip qtcanvas3d"
CONFIG_PARA="${CONFIG_PARA} -prefix ${RABBITIM_BUILD_PREFIX}/qt -shared -release"
CONFIG_PARA="${CONFIG_PARA} -I ${RABBITIM_BUILD_PREFIX}/include -L ${RABBITIM_BUILD_PREFIX}/lib"

CONFIGURE="./configure"
MAKE="make"
MAKE_PARA="${RABBITIM_MAKE_JOB_PARA}"
case ${RABBITIM_BUILD_TARGERT} in
    android)
        #export PKG_CONFIG_SYSROOT_DIR=${RABBITIM_BUILD_PREFIX} #qt编译时需要
        #export PKG_CONFIG_LIBDIR=${RABBITIM_BUILD_PREFIX}/lib/pkgconfig
        #platform:本机工具链(configure工具会自动检测)；xplatform：目标机工具链
        #qt工具和库分为本机工具和目标机工具、库两部分
        #qmake、uic、rcc、lrelease、lupdate 均为本机工具，需要用本机工具链编译
        #库都是目标机的库，所以需要目标机的工具链
        TARGET_OS=`uname -s`
        case $TARGET_OS in
            MINGW* | CYGWIN* | MSYS*)
                CONFIG_PARA="${CONFIG_PARA} -platform win32-g++"
                MAKE="mingw32-make"
                ;;
            Linux* | Unix*)
                ;;
            *)
                echo "Please see build_qt.sh"
                exit 2
                ;;
        esac
        CONFIG_PARA="${CONFIG_PARA} -xplatform android-g++" 
        CONFIG_PARA="${CONFIG_PARA} -android-sdk ${ANDROID_SDK_ROOT} -android-ndk ${ANDROID_NDK_ROOT}"
        CONFIG_PARA="${CONFIG_PARA} -android-ndk-host ${RABBITIM_BUILD_HOST}"
        CONFIG_PARA="${CONFIG_PARA} -android-toolchain-version ${RABBITIM_BUILD_TOOLCHAIN_VERSION}"
        CONFIG_PARA="${CONFIG_PARA} -android-ndk-platform android-${RABBITIM_BUILD_PLATFORMS_VERSION}"
        MODULE_PARA="${MODULE_PARA} module-qtandroidextras"
        ;;
    unix)
        CONFIG_PARA="${CONFIG_PARA} -skip qtandroidextras -skip qtandroidextras -skip qtmacextras -skip qtwinextras"
        ;;
    windows_msvc)
        CONFIGURE="./configure.bat"
        CONFIG_PARA="${CONFIG_PARA} -platform win32-msvc2013"
        MAKE_PARA=""
        MAKE="nmake"
        ;;
    windows_mingw)
        #platform:本机工具链(configure工具会自动检测)；xplatform：目标机工具链
        #qt工具和库分为本机工具和目标机工具、库两部分
        #qmake、uic、rcc、lrelease、lupdate 均为本机工具，需要用本机工具链编译
        #库都是目标机的库，所以需要目标机的工具链
        case `uname -s` in
            MINGW*|MSYS*)
                CONFIG_PARA="${CONFIG_PARA} -platform win32-g++"
                MAKE="mingw32-make"
                ;;
            CYGWIN*)
                CONFIG_PARA="${CONFIG_PARA} -platform win32-g++ -device-option CROSS_COMPILE=${RABBITIM_BUILD_CROSS_PREFIX}"
                CONFIG_PARA="${CONFIG_PARA} -xplatform win32-g++ -device-option CROSS_COMPILE=${RABBITIM_BUILD_CROSS_PREFIX}"
                ;;
            Linux*|Unix*|*)
                #export PKG_CONFIG_SYSROOT_DIR=${RABBITIM_BUILD_PREFIX} #qt编译时需要
                #export PKG_CONFIG_LIBDIR=${RABBITIM_BUILD_PREFIX}/lib/pkgconfig
                CONFIG_PARA="${CONFIG_PARA} -xplatform win32-g++"
                CONFIG_PARA="${CONFIG_PARA} -device-option CROSS_COMPILE=${RABBITIM_BUILD_CROSS_PREFIX}"
                CONFIG_PARA="${CONFIG_PARA} -skip qtwebkit"
                ;;
        esac
        CONFIG_PARA="${CONFIG_PARA} -skip qtandroidextras -skip qtx11extras -skip qtmacextras"
        ;;
    *)
        echo "${HELP_STRING}"
        exit 3
        ;;
esac

echo "$CONFIGURE ${CONFIG_PARA}" 
$CONFIGURE ${CONFIG_PARA}

echo "$MAKE install"
$MAKE ${MAKE_PARA} \
    && $MAKE install \
    && cp qtbase/bin/qt.conf ${RABBITIM_BUILD_PREFIX}/qt/bin/qt.conf

cd $CUR_DIR