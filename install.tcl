package require tin 2.0
set dir [tin mkdir -force wob 1.1]
file copy README.md LICENSE wob.tcl pkgIndex.tcl $dir
