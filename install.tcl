package require tin 0.4
set dir [tin mkdir -force wob 0.2.1]
file copy README.md $dir 
file copy LICENSE $dir 
file copy wob.tcl $dir 
file copy pkgIndex.tcl $dir
