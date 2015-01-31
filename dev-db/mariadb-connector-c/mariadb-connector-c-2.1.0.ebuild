# Copyright 1999-2015 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header: $

EAPI=5

VCS_INHERIT=""
if [[ "${PV}" == 9999 ]] ; then
	VCS_INHERIT="git-r3"
	EGIT_REPO_URI="https://github.com/MariaDB/connector-c.git"
	KEYWORDS=""
else
	MY_PN=${PN#mariadb-}
	SRC_URI="
	http://ftp.osuosl.org/pub/mariadb/${MY_PN}-${PV}/source-tgz/${P}-src.tar.gz
	http://mirrors.fe.up.pt/pub/mariadb/${MY_PN}-${PV}/source-tgz/${P}-src.tar.gz
	http://ftp-stud.hs-esslingen.de/pub/Mirrors/mariadb/${MY_PN}-${PV}/source-tgz/${P}-src.tar.gz
	"
	S="${WORKDIR}/${P}-src"
	KEYWORDS="~amd64 ~x86"
fi

inherit cmake-multilib eutils "${VCS_INHERIT}"

MULTILIB_CHOST_TOOLS=( /usr/bin/mariadb_config )

MULTILIB_WRAPPED_HEADERS+=(
	/usr/include/mariadb/my_config.h
)

DESCRIPTION="C client library for MariaDB/MySQL"
HOMEPAGE="http://mariadb.org/"
LICENSE="LGPL-2.1"

SLOT="0/2"
IUSE="mysqlcompat +ssl static-libs"

DEPEND="sys-libs/zlib:=[${MULTILIB_USEDEP}]
	virtual/libiconv:=[${MULTILIB_USEDEP}]
	ssl? ( dev-libs/openssl:=[${MULTILIB_USEDEP}] )
	"
# Block server packages due to /usr/bin/mariadb_config symlink there
# TODO: make server package block only when mysqlcompat is enabled
RDEPEND="${DEPEND}
	!dev-db/mysql
	!dev-db/mysql-cluster
	!dev-db/mariadb
	!dev-db/mariadb-galera
	!dev-db/percona-server
	mysqlcompat? ( !dev-db/mysql-connector-c )
	"

src_prepare() {
	epatch 	"${FILESDIR}/fix-mariadb_config-2.1.0.patch"
	epatch_user
}

multilib_src_configure() {
	mycmakeargs+=(
		-DMYSQL_UNIX_ADDR="${EPREFIX}/var/run/mysqld/mysqld.sock"
		-DWITH_EXTERNAL_ZLIB=ON
		$(cmake-utils_use_with ssl OPENSSL)
		$(cmake-utils_use_with mysqlcompat MYSQLCOMPAT)
		-DLIB_INSTALL_DIR=$(get_libdir)
		-DPLUGIN_INSTALL_DIR=$(get_libdir)/mariadb/plugin
	)
	cmake-utils_src_configure
}

multilib_src_install_all() {
	if ! use static-libs ; then
		find "${D}" -name "*.a" -delete || die
	fi
	if use mysqlcompat ; then
		dosym mariadb_config /usr/bin/mysql_config
		dosym mariadb /usr/include/mysql
	fi
}
