package require tin 2a0
set dir [tin mkdir -force wob 1.1a0]
file copy README.md LICENSE wob.tcl pkgIndex.tcl $dir
