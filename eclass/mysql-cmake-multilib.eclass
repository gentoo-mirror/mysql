# Copyright 1999-2013 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header: $

# @ECLASS: mysql-cmake-multilib.eclass
# @MAINTAINER:
# Maintainers:
#	- MySQL Team <mysql-bugs@gentoo.org>
#	- Robin H. Johnson <robbat2@gentoo.org>
#	- Jorge Manuel B. S. Vicetto <jmbsvicetto@gentoo.org>
# @BLURB: This eclass provides the support for cmake based mysql releases
# @DESCRIPTION:
# The mysql-cmake-multilib.eclass provides the support to build the mysql
# ebuilds using the cmake build system. This eclass provides
# the src_prepare, src_configure, src_compile and src_install
# phase hooks.

inherit cmake-utils multilib-build flag-o-matic mysql-cmake

#
# HELPER FUNCTIONS:
#

# @FUNCTION: mysql_cmake_disable_test
# @DESCRIPTION:
# Helper function to disable specific tests.
mysql-cmake-multilib_disable_test() {
	mysql-cmake_disable_test "$@"
}

#
# EBUILD FUNCTIONS
#

# @FUNCTION: mysql-cmake-multilib_src_prepare
# @DESCRIPTION:
# Apply patches to the source code and remove unneeded bundled libs.
mysql-cmake-multilib_src_prepare() {

	debug-print-function ${FUNCNAME} "$@"

	mysql-cmake_src_prepare "$@"
}

_mysql-multilib_src_configure() {

	debug-print-function ${FUNCNAME} "$@"

	CMAKE_BUILD_TYPE="RelWithDebInfo"

	mycmakeargs=(
		-DCMAKE_INSTALL_PREFIX=${EPREFIX}/usr
		-DMYSQL_DATADIR=${EPREFIX}/var/lib/mysql
		-DSYSCONFDIR=${EPREFIX}/etc/mysql
		-DINSTALL_BINDIR=bin
		-DINSTALL_DOCDIR=share/doc/${P}
		-DINSTALL_DOCREADMEDIR=share/doc/${P}
		-DINSTALL_INCLUDEDIR=include/mysql
		-DINSTALL_INFODIR=share/info
		-DINSTALL_LIBDIR=$(get_libdir)/mysql
		-DINSTALL_MANDIR=share/man
		-DINSTALL_MYSQLDATADIR=${EPREFIX}/var/lib/mysql
		-DINSTALL_MYSQLSHAREDIR=share/mysql
		-DINSTALL_MYSQLTESTDIR=share/mysql/mysql-test
		-DINSTALL_PLUGINDIR=$(get_libdir)/mysql/plugin
		-DINSTALL_SBINDIR=sbin
		-DINSTALL_SCRIPTDIR=share/mysql/scripts
		-DINSTALL_SQLBENCHDIR=share/mysql
		-DINSTALL_SUPPORTFILESDIR=${EPREFIX}/usr/share/mysql
		-DWITH_COMMENT="Gentoo Linux ${PF}"
		$(cmake-utils_use_with test UNIT_TESTS)
	)

	# Bug 412851
	# MariaDB requires this flag to compile with GPLv3 readline linked
	# Adds a warning about redistribution to configure
	if [[ ${PN} == "mariadb" || ${PN} == "mariadb-galera" ]] ; then
		mycmakeargs+=( -DNOT_FOR_DISTRIBUTION=1 )
	fi

	configure_cmake_locale

	if multilib_build_binaries ; then
		if use minimal ; then
			configure_cmake_minimal
		else
			configure_cmake_standard
		fi
	else
		configure_cmake_minimal
	fi

	# Bug #114895, bug #110149
	filter-flags "-O" "-O[01]"

	CXXFLAGS="${CXXFLAGS} -fno-strict-aliasing"
	CXXFLAGS="${CXXFLAGS} -felide-constructors -fno-rtti"
	# Causes linkage failures.  Upstream bug #59607 removes it
	if ! mysql_version_is_at_least "5.6" ; then
		CXXFLAGS="${CXXFLAGS} -fno-implicit-templates"
	fi
	# As of 5.7, exceptions are used!
	if ! mysql_version_is_at_least "5.7" ; then
		CXXFLAGS="${CXXFLAGS} -fno-exceptions"
	fi
	export CXXFLAGS

	# bug #283926, with GCC4.4, this is required to get correct behavior.
	append-flags -fno-strict-aliasing

	cmake-utils_src_configure
}


# @FUNCTION: mysql-cmake-multilib_src_configure
# @DESCRIPTION:
# Configure mysql to build the code for Gentoo respecting the use flags.
mysql-cmake-multilib_src_configure() {
	multilib_parallel_foreach_abi _mysql-multilib_src_configure "${@}"
}

_mysql-multilib_src_compile() {

	if ! multilib_build_binaries ; then
		BUILD_DIR="${BUILD_DIR}/libmysql" cmake-utils_src_compile
	else
		cmake-utils_src_compile
	fi
}

# @FUNCTION: mysql-cmake-multilib_src_compile
# @DESCRIPTION:
# Compile the mysql code.
mysql-cmake-multilib_src_compile() {

	debug-print-function ${FUNCNAME} "$@"

	multilib_foreach_abi _mysql-multilib_src_compile "${@}"
}

_mysql-multilib_src_install() {
	debug-print-function ${FUNCNAME} "$@"

	if multilib_build_binaries; then
		mysql-cmake_src_install
	else
		BUILD_DIR="${BUILD_DIR}/libmysql" cmake-utils_src_install
	fi
}

# @FUNCTION: mysql-cmake-multilib_src_install
# @DESCRIPTION:
# Install mysql.
mysql-cmake-multilib_src_install() {
	multilib_foreach_abi _mysql-multilib_src_install "${@}"
}
