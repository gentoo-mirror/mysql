# Copyright 1999-2014 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header: $

EAPI=5

PYTHON_COMPAT=( python{2_7,3_3,3_4} )
inherit distutils-r1

DESCRIPTION="Python client library for MariaDB/MySQL"
HOMEPAGE="https://dev.mysql.com/downloads/connector/python/"
LICENSE="GPL-2"

SRC_URI="mirror://mysql/Downloads/Connector-Python/${P}.tar.gz"
KEYWORDS="~amd64 ~x86"
SLOT="0"
IUSE=""

DOCS=( README.txt CHANGES.txt )
EXAMPLES=( examples/. )
