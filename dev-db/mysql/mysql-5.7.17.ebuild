# Copyright 1999-2018 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2

EAPI="6"

MY_EXTRAS_VER="live"
MY_PV="${PV//_alpha_pre/-m}"
MY_PV="${MY_PV//_/-}"
SUBSLOT="20"
SERVER_URI="https://cdn.mysql.com/archives/${PN}-5.7/${PN}-boost-${MY_PV}.tar.gz"
MY_SOURCEDIR="${PN}-${MY_PV}"
inherit mysql-multilib-r1

IUSE="cjk"

# REMEMBER: also update eclass/mysql*.eclass before committing!
KEYWORDS="~alpha ~amd64 ~arm ~hppa ~ia64 ~mips ~ppc ~ppc64 ~s390 ~sh ~sparc ~x86 ~x86-fbsd ~amd64-linux ~x86-linux ~ppc-macos ~x64-macos ~x86-macos ~x64-solaris ~x86-solaris"

# When MY_EXTRAS is bumped, the index should be revised to exclude these.
EPATCH_EXCLUDE=''

DEPEND="|| ( >=sys-devel/gcc-3.4.6 >=sys-devel/gcc-apple-4.0 )
	>=app-arch/lz4-0_p131:=
	>=dev-libs/protobuf-2.5.0:=
	cjk? ( app-text/mecab )"
RDEPEND="${RDEPEND}"

MY_PATCH_DIR="${WORKDIR}/mysql-extras"

PATCHES=(
	"${MY_PATCH_DIR}"/02040_all_embedded-library-shared-5.5.10.patch
	"${MY_PATCH_DIR}"/20001_all_fix-minimal-build-cmake-mysql-5.7.patch
	"${MY_PATCH_DIR}"/20006_all_cmake_elib-mysql-5.7.patch
	"${MY_PATCH_DIR}"/20007_all_cmake-debug-werror-5.7.patch
	"${MY_PATCH_DIR}"/20008_all_mysql-tzinfo-symlink-5.7.6.patch
	"${MY_PATCH_DIR}"/20009_all_mysql_myodbc_symbol_fix-5.7.10.patch
	"${MY_PATCH_DIR}"/20018_all_mysql-5.7-without-clientlibs-tools.patch
)

# Please do not add a naive src_unpack to this ebuild
# If you want to add a single patch, copy the ebuild to an overlay
# and create your own mysql-extras tarball, looking at 000_index.txt

src_prepare() {
	mysql-multilib-r1_src_prepare
	if use libressl ; then
		sed -i 's/OPENSSL_MAJOR_VERSION STREQUAL "1"/OPENSSL_MAJOR_VERSION STREQUAL "2"/' \
			"${S}/cmake/ssl.cmake" || die
	fi
	# Remove dozens of test only plugins by deleting them
	if ! use test ; then
		rm -r "${S}"/plugin/{test_service_sql_api,test_services,udf_services} || die
	fi
	# Remove CJK Fulltext plugin
	if ! use cjk ; then
		rm -r "${S}"/plugin/fulltext || die
	fi
}

src_configure() {
	local MYSQL_CMAKE_NATIVE_DEFINES=(
		-DWITH_LZ4=system
		-DWITH_NUMA=OFF
		-DWITH_BOOST="${S}/boost/boost_1_59_0"
		-DWITH_PROTOBUF=system
	)
	# This is the CJK fulltext plugin, not related to the complete fulltext indexing
	if use cjk ; then
		MYSQL_CMAKE_NATIVE_DEFINES+=( -DWITH_MECAB=system  )
	else
		MYSQL_CMAKE_NATIVE_DEFINES+=( -DWITHOUT_FULLTEXT=1  )
	fi
	mysql-multilib-r1_src_configure
}

# Official test instructions:
# USE='server embedded extraengine perl openssl static-libs' \
# FEATURES='test userpriv -usersandbox' \
# ebuild mysql-X.X.XX.ebuild \
# digest clean package
multilib_src_test() {

	if ! multilib_is_native_abi ; then
		einfo "Server tests not available on non-native abi".
		return 0;
	fi

	local TESTDIR="${BUILD_DIR}/mysql-test"
	local retstatus_unit
	local retstatus_tests

	# Bug #213475 - MySQL _will_ object strenously if your machine is named
	# localhost. Also causes weird failures.
	[[ "${HOSTNAME}" == "localhost" ]] && die "Your machine must NOT be named localhost"

	if use server ; then

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
		# Enable parallel testing, auto will try to detect number of cores
		# You may set this by hand.
		# The default maximum is 8 unless MTR_MAX_PARALLEL is increased
		export MTR_PARALLEL="${MTR_PARALLEL:-auto}"

		# create directories because mysqladmin might right out of order
		mkdir -p "${T}"/var-tests{,/log}

		# create symlink for the tests to find mysql_tzinfo_to_sql
		ln -s "${BUILD_DIR}/sql/mysql_tzinfo_to_sql" "${S}/sql/"

		# These are failing in MySQL 5.5/5.6 for now and are believed to be
		# false positives:
		#
		# main.information_schema, binlog.binlog_statement_insert_delayed,
		# funcs_1.is_triggers funcs_1.is_tables_mysql,
		# funcs_1.is_columns_mysql, binlog.binlog_mysqlbinlog_filter,
		# perfschema.binlog_edge_mix, perfschema.binlog_edge_stmt,
		# mysqld--help-notwin, funcs_1.is_triggers, funcs_1.is_tables_mysql, funcs_1.is_columns_mysql
		# perfschema.binlog_edge_stmt, perfschema.binlog_edge_mix, binlog.binlog_mysqlbinlog_filter
		# fails due to USE=-latin1 / utf8 default
		#
		# main.mysql_client_test:
		# segfaults at random under Portage only, suspect resource limits.
		#
		# rpl.rpl_plugin_load
		# fails due to included file not listed in expected result
		# appears to be poor planning
		#
		# main.mysqlhotcopy_archive main.mysqlhotcopy_myisam
		# fails due to bad cleanup of previous tests when run in parallel
		# The tool is deprecated anyway
		# Bug 532288
		#
		# main.events2
		# Event creation is in the past and automatically dropped
		for t in \
			binlog.binlog_mysqlbinlog_filter \
			binlog.binlog_statement_insert_delayed \
			funcs_1.is_columns_mysql \
			funcs_1.is_tables_mysql \
			funcs_1.is_triggers \
			main.information_schema \
			main.mysql_client_test \
			main.mysqld--help-notwin \
			perfschema.binlog_edge_mix \
			perfschema.binlog_edge_stmt \
			rpl.rpl_plugin_load \
			main.mysqlhotcopy_archive main.mysqlhotcopy_myisam \
			main.events_2 \
		; do
				mysql-multilib-r1_disable_test  "$t" "False positives in Gentoo"
		done

		if ! use extraengine ; then
			# bug 401673, 530766
			for t in federated.federated_plugin ; do
				mysql-multilib-r1_disable_test  "$t" "Test $t requires USE=extraengine (Need federated engine)"
			done
		fi

		if ! use cjk ; then
			for t in innodb_fts.ngram_2 innodb_fts.ngram_1 innodb_fts.ngram ; do
				mysql-multilib-r1_disable_test  "$t" "Test $t requires USE=cjk"
			done
		fi

		# Run mysql tests
		pushd "${TESTDIR}"

		# Set file limits higher so tests run
#		ulimit -n 3000

		# run mysql-test tests
		perl mysql-test-run.pl --force --vardir="${T}/var-tests" \
			--suite-timeout=5000 --reorder
		retstatus_tests=$?
		[[ $retstatus_tests -eq 0 ]] || eerror "tests failed"
		has usersandbox $FEATURES && eerror "Some tests may fail with FEATURES=usersandbox"

		popd

		# Cleanup is important for these testcases.
		pkill -9 -f "${S}/ndb" 2>/dev/null
		pkill -9 -f "${S}/sql" 2>/dev/null

		failures=""
		[[ $retstatus_unit -eq 0 ]] || failures="${failures} test-unit"
		[[ $retstatus_tests -eq 0 ]] || failures="${failures} tests"
		has usersandbox $FEATURES && eerror "Some tests may fail with FEATURES=usersandbox"

		[[ -z "$failures" ]] || die "Test failures: $failures"
		einfo "Tests successfully completed"

	else
		einfo "Skipping server tests due to minimal build."
	fi
}
