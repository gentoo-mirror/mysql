# Copyright 1999-2017 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2

EAPI="6"

inherit multilib-build

DESCRIPTION="Virtual for MySQL client libraries"
HOMEPAGE=""
SRC_URI=""

LICENSE=""
SLOT="0/${PV}"
KEYWORDS="~alpha ~amd64 ~arm ~arm64 ~hppa ~ia64 ~mips ~ppc ~ppc64 ~s390 ~sh ~sparc ~x86 ~sparc-fbsd ~x86-fbsd ~amd64-linux ~x86-linux ~ppc-macos ~x64-macos ~x86-macos ~x64-solaris ~x86-solaris"
IUSE="ssl static-libs"

DEPEND="|| (
		dev-db/mariadb:${SLOT}[client-libs(+),static-libs?,${MULTILIB_USEDEP}]
)"
#		dev-db/mariadb-connector-c:${SLOT}[ssl?,static-libs?,${MULTILIB_USEDEP}]
RDEPEND="${DEPEND}
	!virtual/libmysqlclient:0"
