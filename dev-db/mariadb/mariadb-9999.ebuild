# Copyright 1999-2017 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2

EAPI="6"
MY_EXTRAS_VER="none"
SERVER_URI=" "
EGIT_REPO_URI="https://github.com/MariaDB/server.git"
# The wsrep API version must match between upstream WSREP and sys-cluster/galera major number
WSREP_REVISION="25"
SUBSLOT="18"
MYSQL_PV_MAJOR="5.6"

inherit toolchain-funcs mysql-multilib-r1 git-r3
HOMEPAGE="http://mariadb.org/"
DESCRIPTION="An enhanced, drop-in replacement for MySQL"

IUSE="bindist cracklib galera kerberos innodb-lz4 innodb-lzo innodb-snappy mroonga odbc oqgraph pam sphinx sst-rsync sst-xtrabackup tokudb systemd xml"
RESTRICT="!bindist? ( bindist )"

REQUIRED_USE="server? ( tokudb? ( jemalloc ) ) static? ( !pam ) "

KEYWORDS=""

COMMON_DEPEND="
	mroonga? ( app-text/groonga-normalizer-mysql )
	kerberos? ( virtual/krb5[${MULTILIB_USEDEP}] )
	systemd? ( sys-apps/systemd:= )
	!bindist? (
		sys-libs/binutils-libs:0=
		>=sys-libs/readline-4.1:0=
	)
	server? (
		cracklib? ( sys-libs/cracklib:0= )
		extraengine? (
			odbc? ( dev-db/unixODBC:0= )
			xml? ( dev-libs/libxml2:2= )
		)
		innodb-lz4? ( app-arch/lz4 )
		innodb-lzo? ( dev-libs/lzo )
		innodb-snappy? ( app-arch/snappy )
		oqgraph? ( >=dev-libs/boost-1.40.0:0= dev-libs/judy:0= )
		pam? ( virtual/pam:0= )
		tokudb? ( app-arch/snappy )
	)
	>=dev-libs/libpcre-8.35:3=
"
DEPEND="|| ( >=sys-devel/gcc-3.4.6 >=sys-devel/gcc-apple-4.0 )
	${COMMON_DEPEND}"
RDEPEND="${RDEPEND} ${COMMON_DEPEND}
	galera? (
		sys-apps/iproute2
		=sys-cluster/galera-${WSREP_REVISION}*
		sst-rsync? ( sys-process/lsof )
		sst-xtrabackup? ( net-misc/socat[ssl] )
	)
	perl? ( !dev-db/mytop
		virtual/perl-Getopt-Long
		dev-perl/TermReadKey
		virtual/perl-Term-ANSIColor
		virtual/perl-Time-HiRes )
"
# xtrabackup-bin causes a circular dependency if DBD-mysql is not already installed
PDEPEND="galera? ( sst-xtrabackup? ( >=dev-db/xtrabackup-bin-2.2.4 ) )"

MULTILIB_WRAPPED_HEADERS+=( /usr/include/mysql/mysql_version.h )

# This is a special unpack for the VCS version
src_unpack() {
	git-r3_src_unpack

	mv -f "${WORKDIR}/${P}" "${S}"
}

src_configure(){
	# bug 508724 mariadb cannot use ld.gold
	tc-ld-disable-gold

	local MYSQL_CMAKE_NATIVE_DEFINES=(
			-DWITH_JEMALLOC=$(usex jemalloc system)
			-DWITH_PCRE=system
	)
	local MYSQL_CMAKE_EXTRA_DEFINES=(
			-DPLUGIN_AUTH_GSSAPI_CLIENT=$(usex kerberos YES NO)
	)
	if use server ; then
		# Federated{,X} must be treated special otherwise they will not be built as plugins
		if ! use extraengine ; then
			MYSQL_CMAKE_NATIVE_DEFINES+=(
				-DPLUGIN_FEDERATED=NO
				-DPLUGIN_FEDERATEDX=NO )
		fi

		MYSQL_CMAKE_NATIVE_DEFINES+=(
			-DPLUGIN_OQGRAPH=$(usex oqgraph YES NO)
			-DPLUGIN_SPHINX=$(usex sphinx YES NO)
			-DPLUGIN_TOKUDB=$(usex tokudb YES NO)
			-DPLUGIN_AUTH_PAM=$(usex pam YES NO)
			-DPLUGIN_CRACKLIB_PASSWORD_CHECK=$(usex cracklib YES NO)
			-DPLUGIN_CASSANDRA=NO
			-DPLUGIN_SEQUENCE=$(usex extraengine YES NO)
			-DPLUGIN_SPIDER=$(usex extraengine YES NO)
			-DPLUGIN_CONNECT=$(usex extraengine YES NO)
			-DCONNECT_WITH_MYSQL=1
			-DCONNECT_WITH_LIBXML2=$(usex xml)
			-DCONNECT_WITH_ODBC=$(usex odbc)
			-DWITH_WSREP=$(usex galera)
			-DWITH_INNODB_LZ4=$(usex innodb-lz4)
			-DWITH_INNODB_LZO=$(usex innodb-lzo)
			-DWITH_INNODB_SNAPPY=$(usex innodb-snappy)
			-DPLUGIN_MROONGA=$(usex mroonga YES NO)
			-DPLUGIN_AUTH_GSSAPI=$(usex kerberos YES NO)
		)
	fi
	mysql-multilib-r1_src_configure
}

# Official test instructions:
# USE='-cluster embedded extraengine perl ssl static-libs community' \
# FEATURES='test userpriv -usersandbox' \
# ebuild mariadb-X.X.XX.ebuild \
# digest clean package
multilib_src_test() {

	local TESTDIR="${BUILD_DIR}/mysql-test"
	local retstatus_unit
	local retstatus_tests

	multilib_is_native_abi || return

	# Bug #213475 - MySQL _will_ object strenously if your machine is named
	# localhost. Also causes weird failures.
	[[ "${HOSTNAME}" == "localhost" ]] && die "Your machine must NOT be named localhost"

	if ! use "minimal" ; then

		if [[ $UID -eq 0 ]]; then
			die "Testing with FEATURES=-userpriv is no longer supported by upstream. Tests MUST be run as non-root."
		fi
		has usersandbox $FEATURES && eerror "Some tests may fail with FEATURES=usersandbox"

		einfo ">>> Test phase [test]: ${CATEGORY}/${PF}"
		addpredict /this-dir-does-not-exist/t9.MYI

		# Run CTest (test-units)
		cmake-utils_src_test
		retstatus_unit=$?
		[[ $retstatus_unit -eq 0 ]] || eerror "test-unit failed"

		# Ensure that parallel runs don't die
		export MTR_BUILD_THREAD="$((${RANDOM} % 100))"

		# create directories because mysqladmin might right out of order
		mkdir -p "${S}"/mysql-test/var-tests{,/log}

		# These are failing in MariaDB 10.0 for now and are believed to be
		# false positives:
		#
		# main.information_schema, binlog.binlog_statement_insert_delayed,
		# main.mysqld--help, funcs_1.is_triggers, funcs_1.is_tables_mysql,
		# funcs_1.is_columns_mysql
		# fails due to USE=-latin1 / utf8 default
		#
		# main.mysql_client_test, main.mysql_client_test_nonblock:
		# segfaults at random under Portage only, suspect resource limits.
		#
		# plugins.unix_socket
		# fails because portage strips out the USER enviornment variable
		#

		for t in main.mysql_client_test main.mysql_client_test_nonblock \
			binlog.binlog_statement_insert_delayed main.information_schema \
			main.mysqld--help plugins.unix_socket \
			funcs_1.is_triggers funcs_1.is_tables_mysql funcs_1.is_columns_mysql ; do
				mysql-multilib_disable_test  "$t" "False positives in Gentoo"
		done

		# Run mysql tests
		pushd "${TESTDIR}" || die

		# run mysql-test tests
		# Skip all CONNECT engine tests until upstream respondes to how to reference data files
		perl mysql-test-run.pl --force --vardir="${S}/mysql-test/var-tests" --skip-test=connect
		retstatus_tests=$?
		[[ $retstatus_tests -eq 0 ]] || eerror "tests failed"
		has usersandbox $FEATURES && eerror "Some tests may fail with FEATURES=usersandbox"

		popd || die

		# Cleanup is important for these testcases.
		pkill -9 -f "${S}/ndb" 2>/dev/null
		pkill -9 -f "${S}/sql" 2>/dev/null

		failures=""
		[[ $retstatus_unit -eq 0 ]] || failures="${failures} test-unit"
		[[ $retstatus_tests -eq 0 ]] || failures="${failures} tests"
		has usersandbox $FEATURES && eerror "Some tests may fail with FEATURES=usersandbox"

		[[ -z "$failures" ]] || die "Test failures: $failures"
		einfo "Tests successfully completed"

		# Cleanup test data after a successful run
		rm -r "${S}/mysql-test/var-tests"
	else

		einfo "Skipping server tests due to minimal build."
	fi
}
