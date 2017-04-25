# Copyright 1999-2017 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2

EAPI=6

VCS_INHERIT=""
if [[ "${PV}" == 9999 ]] ; then
	VCS_INHERIT="git-r3"
	EGIT_REPO_URI="https://github.com/MariaDB/connector-c.git"
	KEYWORDS=""
else
	MY_PN=${PN#mariadb-}
	MY_PV=${PV/_b/-b}
	SRC_URI="https://downloads.mariadb.org/f/${MY_PN}-${PV%_beta}/${PN}-${MY_PV}-src.tar.gz?serve -> ${P}-src.tar.gz"
	S="${WORKDIR}/${PN}-${MY_PV}-src"
	KEYWORDS="~amd64 ~x86"
fi

inherit cmake-utils multilib-minimal ${VCS_INHERIT}

MULTILIB_CHOST_TOOLS=( /usr/bin/mariadb_config )

MULTILIB_WRAPPED_HEADERS+=(
	/usr/include/mariadb/mariadb_version.h
)

DESCRIPTION="C client library for MariaDB/MySQL"
HOMEPAGE="http://mariadb.org/"
LICENSE="LGPL-2.1"

SLOT="0/2"
IUSE="+curl gnutls kerberos libressl mysqlcompat +ssl static-libs"

DEPEND="sys-libs/zlib:=[${MULTILIB_USEDEP}]
	virtual/libiconv:=[${MULTILIB_USEDEP}]
	curl? ( net-misc/curl:0=[${MULTILIB_USEDEP}] )
	kerberos? ( || ( app-crypt/mit-krb5[${MULTILIB_USEDEP}]
			app-crypt/heimdal[${MULTILIB_USEDEP}] ) )
	ssl? (
		gnutls? ( >=net-libs/gnutls-3.3.24:0=[${MULTILIB_USEDEP}] )
		!gnutls? (
			libressl? ( dev-libs/libressl:0=[${MULTILIB_USEDEP}] )
			!libressl? ( dev-libs/openssl:0=[${MULTILIB_USEDEP}] )
		)
	)
	"
RDEPEND="${DEPEND}
	mysqlcompat? (
	!dev-db/mysql
	!dev-db/mysql-cluster
	!dev-db/mariadb
	!dev-db/mariadb-galera
	!dev-db/percona-server
	!dev-db/mysql-connector-c )
	"
PATCHES=(
	"${FILESDIR}/gentoo-layout-3.0.patch" )

src_prepare() {
	local gpluginconf="${T}/gentoo-plugins.cmake"
	touch "${gpluginconf}" || die
	# Plugins cannot be disabled by a build switch, redefine them in our own file to be included
	if ! use kerberos ; then
		echo 'REGISTER_PLUGIN("AUTH_GSSAPI" "" "auth_gssapi_plugin" "OFF" "auth_gssapi_client" 1)' \
			>> "${gpluginconf}" || die
	fi
	if ! use curl ; then
		echo 'REGISTER_PLUGIN("REMOTEIO" "" "remote_io_plugin" "OFF" "remote_io" 1)' \
			>> "${gpluginconf}" || die
	fi
	default
}

multilib_src_configure() {
	local mycmakeargs=(
		-DWITH_EXTERNAL_ZLIB=ON
		-DWITH_SSL:STRING=$(usex ssl $(usex gnutls GNUTLS OPENSSL) OFF)
		-DWITH_MYSQLCOMPAT=$(usex mysqlcompat ON OFF)
		-DWITH_CURL=$(usex curl ON OFF)
		-DAUTH_GSSAPI_PLUGIN_TYPE:STRING=$(usex kerberos ON OFF)
		-DINSTALL_LIBDIR="$(get_libdir)"
		-DINSTALL_PLUGINDIR="$(get_libdir)/mariadb/plugin"
		-DINSTALL_BINDIR=bin
		-DPLUGIN_CONF_FILE:STRING="${T}/gentoo-plugins.cmake"
	)
	cmake-utils_src_configure
}

multilib_src_install_all() {
	if ! use static-libs ; then
		find "${D}" -name "*.a" -delete || die
	fi
	if use mysqlcompat ; then
		dosym /usr/bin/mariadb_config /usr/bin/mysql_config
		dosym mariadb /usr/include/mysql
	fi
}
