# /etc/inputrc is shipped by base-files, so bash keeps its key bindings
# on images without readline (GPL-3.0-or-later)
do_install:append () {
	rm -f ${D}${sysconfdir}/inputrc
}
CONFFILES:${PN}:remove = "${sysconfdir}/inputrc"
