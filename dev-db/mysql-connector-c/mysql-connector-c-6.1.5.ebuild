# Copyright 1999-2014 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header: $

EAPI=5

inherit cmake-multilib eutils

MULTILIB_WRAPPED_HEADERS+=(
	/usr/include/mysql/my_config.h
)

DESCRIPTION="C client library for MariaDB/MySQL"
HOMEPAGE="https://dev.mysql.com/downloads/connector/c/"
LICENSE="GPL-2"

SRC_URI="mirror://mysql/Downloads/Connector-C/${P}-src.tar.gz"
S="${WORKDIR}/${P}-src"
KEYWORDS="~amd64 ~x86"

SLOT="0/18"
IUSE="+ssl static-libs"

CDEPEND="
	sys-libs/zlib:=[${MULTILIB_USEDEP}]
	ssl? ( dev-libs/openssl:=[${MULTILIB_USEDEP}] )
	"
RDEPEND="${CDEPEND}
	!dev-db/mysql
	!dev-db/mysql-cluster
	!dev-db/mariadb
	!dev-db/mariadb-connector-c
	!dev-db/mariadb-galera
	!dev-db/percona-server
	"
DEPEND="${CDEPEND}
	>=dev-util/cmake-2.8.9
	"

DOCS=( README Docs/ChangeLog )

multilib_src_configure() {
	mycmakeargs+=(
		-DINSTALL_LAYOUT=RPM
		-DINSTALL_LIBDIR=$(get_libdir)
		-DWITH_DEFAULT_COMPILER_OPTIONS=OFF
		-DWITH_DEFAULT_FEATURE_SET=OFF
		-DENABLED_LOCAL_INFILE=ON
		-DMYSQL_UNIX_ADDR="${EPREFIX}/var/run/mysqld/mysqld.sock"
		-DWITH_ZLIB=system
		-DENABLE_DTRACE=OFF
		-DWITH_SSL=$(usex ssl system bundled)
	)
	cmake-utils_src_configure
}

multilib_src_install_all() {
	if ! use static-libs ; then
		find "${ED}" -name "*.a" -delete || die
	fi
}
